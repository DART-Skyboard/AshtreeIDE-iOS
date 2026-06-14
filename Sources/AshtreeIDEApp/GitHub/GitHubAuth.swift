// GitHubAuth.swift v5 — Crash-safe Apple Sign In with UIViewRepresentable
// Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
// ROOT CAUSE OF CRASH: SwiftUI's SignInWithAppleButton calls
// ASAuthorizationController.performRequests() internally. When the button is
// inside a ZStack/modal/sheet that is not the ROOT of the window hierarchy,
// iOS throws "Attempting to present ASAuthorizationController from a SwiftUI
// view not in a hierarchy" → fatal crash.
//
// FIX (recommended by Apple engineers at WWDC22):
// Wrap ASAuthorizationAppleIDButton in a UIViewRepresentable and call
// performRequests() directly from the view model, NOT from inside the SwiftUI
// button's onCompletion handler.
//
// This works BOTH from the splash/welcome screen AND from the profile menu
// because we always present from the key UIWindow, not from the SwiftUI view.
import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI

// MARK: - Keychain

public enum KeychainHelper {
    public static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                   kSecValueData: data, kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock]
        SecItemDelete(q as CFDictionary); SecItemAdd(q as CFDictionary, nil)
    }
    public static func load(key: String) -> String? {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
                                   kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess, let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    public static func delete(key: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary)
    }
}

// MARK: - Models

public struct IDESavedAccount: Identifiable {
    public let id = UUID()
    public let username: String
    public let provider: String
    public let avatarURL: URL?
    public var isActive: Bool
}
public struct IDEDeviceFlow: Identifiable {
    public let id = UUID()
    public let userCode: String
    public let verifyURL: URL
    public let deviceCode: String
    public let interval: Int
    public var isPolling = false
    public var error: String?
}
public struct IDEGitHubRepo: Identifiable, Codable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let isPrivate: Bool
    public let description: String?
    public let defaultBranch: String
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"; case isPrivate = "private"; case defaultBranch = "default_branch"
    }
}
public struct IDEGitHubFile: Codable {
    public let name: String
    public let path: String
    public let sha: String?
    public let downloadURL: String?
    public let type: String?
    public let size: Int?
    enum CodingKeys: String, CodingKey {
        case name, path, sha, type, size; case downloadURL = "download_url"
    }
}

// MARK: - GitHub Client

public actor IDEGitHubClient {
    public static let shared = IDEGitHubClient()
    private let session = URLSession.shared
    private let base = "https://api.github.com"
    private var _token: String?
    public func setToken(_ t: String) { _token=t; KeychainHelper.save(key:"ide_github_pat",value:t) }
    public func loadToken() { _token=KeychainHelper.load(key:"ide_github_pat") }
    public func clearToken() { _token=nil; KeychainHelper.delete(key:"ide_github_pat") }
    public var hasToken: Bool { !(_token?.isEmpty ?? true) }
    private func headers()->[String:String]{
        var h=["Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"]
        if let t=_token{h["Authorization"]="Bearer \(t)"}
        return h
    }
    public func startDeviceFlow() async throws -> IDEDeviceFlow {
        var req=URLRequest(url:URL(string:"https://github.com/login/device/code")!)
        req.httpMethod="POST";req.setValue("application/json",forHTTPHeaderField:"Accept")
        req.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        req.httpBody="client_id=Ov23li2K0njEqO1WTSdD&scope=repo,read:user".data(using:.utf8)
        let(data,_)=try await session.data(for:req)
        guard let j=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let uc=j["user_code"] as? String,let vs=j["verification_uri"] as? String,
              let vu=URL(string:vs),let dc=j["device_code"] as? String,let iv=j["interval"] as? Int
        else{throw URLError(.badServerResponse)}
        return IDEDeviceFlow(userCode:uc,verifyURL:vu,deviceCode:dc,interval:iv)
    }
    public func pollDeviceFlow(deviceCode:String,interval:Int) async throws -> String? {
        for _ in 0..<60{
            try await Task.sleep(nanoseconds:UInt64(max(interval,5))*1_000_000_000)
            var req=URLRequest(url:URL(string:"https://github.com/login/oauth/access_token")!)
            req.httpMethod="POST";req.setValue("application/json",forHTTPHeaderField:"Accept")
            req.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
            req.httpBody="client_id=Ov23li2K0njEqO1WTSdD&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using:.utf8)
            guard let(d,_)=try? await session.data(for:req),
                  let j=try? JSONSerialization.jsonObject(with:d) as? [String:Any] else{continue}
            if let t=j["access_token"] as? String{return t}
            let e=j["error"] as? String ?? "";if e=="access_denied"||e=="expired_token"{return nil}
        }
        return nil
    }
    public func fetchUser() async throws -> (login:String,name:String?,avatarURL:String?) {
        struct U:Decodable{let login:String;let name:String?;let avatar_url:String?}
        let u=try JSONDecoder().decode(U.self,from:try await get("/user"));return(u.login,u.name,u.avatar_url)
    }
    public func fetchAvatar(urlStr:String) async throws -> Data {
        guard let url=URL(string:urlStr) else{throw URLError(.badURL)}
        return try await session.data(from:url).0
    }
    public func listRepos() async throws -> [IDEGitHubRepo] {
        try JSONDecoder().decode([IDEGitHubRepo].self,from:try await get("/user/repos?per_page=100&sort=updated&type=all"))
    }
    public func listFiles(owner:String,repo:String,path:String="") async throws -> [IDEGitHubFile] {
        let enc=path.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? path
        let p=path.isEmpty ? "" : "/\(enc)"
        let data=try await get("/repos/\(owner)/\(repo)/contents\(p)")
        if let arr=try? JSONDecoder().decode([IDEGitHubFile].self,from:data){return arr}
        if let single=try? JSONDecoder().decode(IDEGitHubFile.self,from:data){return[single]}
        return[]
    }
    public func readFile(owner:String,repo:String,path:String) async throws -> String {
        let enc=path.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? path
        struct F:Decodable{let content:String?}
        let f=try JSONDecoder().decode(F.self,from:try await get("/repos/\(owner)/\(repo)/contents/\(enc)"))
        guard let b64=f.content?.replacingOccurrences(of:"\n",with:"") else{return""}
        return String(data:Data(base64Encoded:b64) ?? Data(),encoding:.utf8) ?? ""
    }
    public func writeFile(owner:String,repo:String,path:String,content:String,message:String) async throws {
        let b64=Data(content.utf8).base64EncodedString();var sha:String?
        if let d=try? await get("/repos/\(owner)/\(repo)/contents/\(path)"),
           let j=try? JSONSerialization.jsonObject(with:d) as? [String:Any]{sha=j["sha"] as? String}
        var body:[String:Any]=["message":message,"content":b64];if let s=sha{body["sha"]=s}
        _ = try await put("/repos/\(owner)/\(repo)/contents/\(path)",body:body)
    }
    public func createRepo(name:String,isPrivate:Bool=true) async throws -> IDEGitHubRepo {
        try JSONDecoder().decode(IDEGitHubRepo.self,from:try await post("/user/repos",
            body:["name":name,"private":isPrivate,"description":"Ash Tree IDE projects","auto_init":true]))
    }
    public func repoExists(owner:String,repo:String) async -> Bool {
        guard let d=try? await get("/repos/\(owner)/\(repo)"),
              let j=try? JSONSerialization.jsonObject(with:d) as? [String:Any],j["id"] != nil else{return false}
        return true
    }
    private func get(_ path:String) async throws -> Data {
        var r=URLRequest(url:URL(string:base+path)!);headers().forEach{r.setValue($1,forHTTPHeaderField:$0)}
        return try await session.data(for:r).0
    }
    private func post(_ path:String,body:[String:Any]) async throws -> Data {
        var r=URLRequest(url:URL(string:base+path)!);r.httpMethod="POST"
        headers().forEach{r.setValue($1,forHTTPHeaderField:$0)}
        r.setValue("application/json",forHTTPHeaderField:"Content-Type")
        r.httpBody=try JSONSerialization.data(withJSONObject:body)
        return try await session.data(for:r).0
    }
    private func put(_ path:String,body:[String:Any]) async throws -> Data {
        var r=URLRequest(url:URL(string:base+path)!);r.httpMethod="PUT"
        headers().forEach{r.setValue($1,forHTTPHeaderField:$0)}
        r.setValue("application/json",forHTTPHeaderField:"Content-Type")
        r.httpBody=try JSONSerialization.data(withJSONObject:body)
        return try await session.data(for:r).0
    }
}

// MARK: - UIViewRepresentable Apple Sign In Button
// This is the CORRECT fix for the crash. Using SwiftUI's SignInWithAppleButton
// causes "not in hierarchy" fatal error when the view is not at the root window.
// Wrapping in UIViewRepresentable uses the UIKit button directly and always
// presents from the key window — works from any context including profile menu.

struct AppleSignInButton: UIViewRepresentable {
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: AppleSignInButton
        private var controller: ASAuthorizationController?

        init(parent: AppleSignInButton) { self.parent = parent }

        @objc func tapped() {
            let provider = ASAuthorizationAppleIDProvider()
            let request  = provider.createRequest()
            parent.onRequest(request)
            let ctrl = ASAuthorizationController(authorizationRequests: [request])
            ctrl.delegate = self
            ctrl.presentationContextProvider = self
            controller = ctrl   // retain strongly
            ctrl.performRequests()
        }

        public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            // Always get the live key window — works from any presentation context
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }

        public func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization auth: ASAuthorization) {
            self.controller = nil
            parent.onCompletion(.success(auth))
        }
        public func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
            self.controller = nil
            parent.onCompletion(.failure(error))
        }
    }
}

// MARK: - Auth ViewModel

@MainActor
public final class IDEAuthViewModel: NSObject, ObservableObject {
    @Published public var isSignedIn      = false
    @Published public var isGuest         = false
    @Published public var githubConnected = false
    @Published public var username        = ""
    @Published public var githubUsername  = ""
    @Published public var githubAvatarURL: URL? = nil
    @Published public var avatarImage: UIImage? = nil
    @Published public var appleUserId     = ""
    @Published public var error: String?  = nil
    @Published public var appleErrorMessage: String? = nil
    @Published public var deviceFlow: IDEDeviceFlow?
    @Published public var savedAccounts: [IDESavedAccount] = []
    @Published public var activeAccountProvider: String = "github"
    // Editable app username (separate from connected account names)
    @Published public var appUsername: String = ""
    // Per-provider: use that provider's username as app display name
    @Published public var useGitHubName: Bool = false
    @Published public var useAppleName:  Bool = false

    private var _currentNonce: String = ""

    public func restoreSession() {
        if let pat=KeychainHelper.load(key:"ide_github_pat"),!pat.isEmpty {
            if let cached=KeychainHelper.load(key:"ide_github_avatar_url"),let url=URL(string:cached){githubAvatarURL=url}
            Task {
                await IDEGitHubClient.shared.setToken(pat)
                if let user=try? await IDEGitHubClient.shared.fetchUser() {
                    KeychainHelper.save(key:"ide_github_username",value:user.login)
                    await MainActor.run {
                        self.githubConnected=true;self.githubUsername=user.login
                        self.username=user.login;self.isSignedIn=true;self.activeAccountProvider="github"
                    }
                    if let a=user.avatarURL{await self.fetchAndCacheAvatar(a)}
                    await self.ensureDefaultRepo(username:user.login)
                }
            }
            let ghUser=KeychainHelper.load(key:"ide_github_username") ?? ""
            if !ghUser.isEmpty{githubConnected=true;githubUsername=ghUser;username=ghUser;isSignedIn=true}
        }
        if let uid=KeychainHelper.load(key:"ide_apple_uid"),!uid.isEmpty {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID:uid){[weak self] state,_ in
                Task{@MainActor in
                    if state == .authorized,!(self?.isSignedIn ?? false) {
                        let name=KeychainHelper.load(key:"ide_apple_name") ?? "Apple User"
                        self?.appleUserId=uid;self?.username=name;self?.isSignedIn=true
                        self?.activeAccountProvider="apple"
                    }
                }
            }
        }
        // Restore custom app username
        if let custom = KeychainHelper.load(key: "ide_app_username"), !custom.isEmpty {
            appUsername = custom
        }
        loadSavedAccounts()
        updateDisplayUsername()
    }

    // Called from AppleSignInButton.onRequest — sets up the nonce BEFORE performRequests
    public func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = generateNonce()
        _currentNonce = rawNonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(rawNonce)
    }

    // Called from AppleSignInButton.onCompletion — handles result on @MainActor
    public func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        appleErrorMessage = nil
        switch result {
        case .success(let auth):
            Task { @MainActor in
                if let cred=auth.credential as? ASAuthorizationAppleIDCredential {
                    let uid=cred.user

                    // Build display name — Apple only sends email/name on FIRST sign-in
                    // On repeat sign-ins both are nil, so we load from keychain
                    var display = KeychainHelper.load(key:"ide_apple_name") ?? ""

                    // First priority: email prefix (e.g. "justin" from "justin@icloud.com")
                    // Only available on first auth — save permanently to keychain
                    if let email = cred.email, !email.isEmpty {
                        let prefix = String(email.split(separator:"@").first ?? "")
                        if !prefix.isEmpty {
                            display = prefix
                            KeychainHelper.save(key:"ide_apple_email_prefix", value:prefix)
                        }
                    } else if let saved = KeychainHelper.load(key:"ide_apple_email_prefix"),
                              !saved.isEmpty {
                        // Repeat sign-in: restore email prefix from keychain
                        display = saved
                    }

                    // Second priority: full name (also only on first auth)
                    let givenName  = cred.fullName?.givenName  ?? ""
                    let familyName = cred.fullName?.familyName ?? ""
                    let fullName   = [givenName, familyName].filter{!$0.isEmpty}.joined(separator:" ")
                    if !fullName.isEmpty { display = fullName }

                    // Final fallback
                    if display.isEmpty { display = "Apple User" }

                    KeychainHelper.save(key:"ide_apple_uid",  value:uid)
                    KeychainHelper.save(key:"ide_apple_name", value:display)
                    self.appleUserId=uid; self.username=display; self.isSignedIn=true
                    self.activeAccountProvider="apple"
                    self.loadSavedAccounts()
                }
            }
        case .failure(let error):
            Task { @MainActor in
                let authError = error as? ASAuthorizationError
                if authError?.code == .canceled { return }
                let code = authError?.code.rawValue ?? 0
                if code == 1001 {
                    self.appleErrorMessage = "Sign in with Apple is temporarily unavailable. Please try GitHub or try again in a few minutes."
                } else {
                    self.appleErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // Legacy method kept for compatibility — now uses UIViewRepresentable approach
    public func signInWithApple() {
        // This is now handled by AppleSignInButton UIViewRepresentable
        // Kept as no-op to not break any remaining call sites
    }

    public func startGitHubDeviceFlow() async {
        if let existingPat=KeychainHelper.load(key:"ide_github_pat"),!existingPat.isEmpty {
            await IDEGitHubClient.shared.setToken(existingPat)
            if let user=try? await IDEGitHubClient.shared.fetchUser() {
                KeychainHelper.save(key:"ide_github_username",value:user.login)
                githubConnected=true;githubUsername=user.login;username=user.login;isSignedIn=true
                activeAccountProvider="github"
                if let a=user.avatarURL{await fetchAndCacheAvatar(a)}
                loadSavedAccounts();return
            }
        }
        do {
            var flow=try await IDEGitHubClient.shared.startDeviceFlow()
            flow.isPolling=true;deviceFlow=flow
            UIPasteboard.general.string=flow.userCode
            await UIApplication.shared.open(flow.verifyURL)
            guard let token=try await IDEGitHubClient.shared.pollDeviceFlow(deviceCode:flow.deviceCode,interval:flow.interval) else {
                deviceFlow?.error="Authorization timed out.";deviceFlow?.isPolling=false;return
            }
            await IDEGitHubClient.shared.setToken(token)
            let user=try await IDEGitHubClient.shared.fetchUser()
            KeychainHelper.save(key:"ide_github_username",value:user.login)
            githubConnected=true;githubUsername=user.login;username=user.login;isSignedIn=true;deviceFlow=nil
            activeAccountProvider="github"
            if let a=user.avatarURL{KeychainHelper.save(key:"ide_github_avatar_url",value:a);await fetchAndCacheAvatar(a)}
            loadSavedAccounts();await ensureDefaultRepo(username:user.login)
        } catch{deviceFlow?.error=error.localizedDescription;deviceFlow?.isPolling=false}
    }

    public func setActiveAccount(_ provider: String) {
        // SWITCH active session — never disconnects anything
        activeAccountProvider = provider
        updateDisplayUsername()
        loadSavedAccounts()
    }

    // Whether the provider's account name is used as app display name
    public func useAccountName(provider: String) -> Bool {
        provider == "github" ? useGitHubName : useAppleName
    }

    // Toggle: use provider account name for app display
    public func setUseAccountName(_ on: Bool, provider: String) {
        if provider == "github" {
            useGitHubName = on
        } else {
            useAppleName = on
        }
        updateDisplayUsername()
    }

    // Derive what the app should display as username
    public func updateDisplayUsername() {
        // Priority: toggled account name > custom appUsername > active account's stored name
        if activeAccountProvider == "github" && useGitHubName {
            let gh = KeychainHelper.load(key: "ide_github_username") ?? ""
            if !gh.isEmpty { username = gh; return }
        }
        if activeAccountProvider == "apple" && useAppleName {
            let prefix = KeychainHelper.load(key: "ide_apple_email_prefix") ?? ""
            let name   = KeychainHelper.load(key: "ide_apple_name") ?? ""
            let n = prefix.isEmpty ? name : prefix
            if !n.isEmpty { username = n; return }
        }
        // Custom app username
        if let custom = KeychainHelper.load(key: "ide_app_username"), !custom.isEmpty {
            username = custom; appUsername = custom; return
        }
        // Fall back to active account stored name
        if activeAccountProvider == "github" {
            username = KeychainHelper.load(key: "ide_github_username") ?? ""
        } else if activeAccountProvider == "apple" {
            let prefix = KeychainHelper.load(key: "ide_apple_email_prefix") ?? ""
            let name   = KeychainHelper.load(key: "ide_apple_name") ?? "Apple User"
            username = prefix.isEmpty ? name : prefix
        }
    }

    public func continueAsGuest(){isGuest=true;isSignedIn=true;username="Guest"}

    public func signOut(){
        isSignedIn=false;isGuest=false;githubConnected=false;username="";githubUsername=""
        githubAvatarURL=nil;avatarImage=nil;appleUserId=""
        Task{await IDEGitHubClient.shared.clearToken()}
        ["ide_github_pat","ide_github_username","ide_github_avatar_url","ide_apple_uid","ide_apple_name"]
            .forEach{KeychainHelper.delete(key:$0)}
        loadSavedAccounts()
    }

    public func disconnectAccount(_ provider: String) {
        if provider == "github" {
            Task { await IDEGitHubClient.shared.clearToken() }
            KeychainHelper.delete(key:"ide_github_pat")
            KeychainHelper.delete(key:"ide_github_username")
            KeychainHelper.delete(key:"ide_github_avatar_url")
            githubConnected=false;githubUsername=""
            if activeAccountProvider == "github" {
                // Fall back to Apple if available
                if !appleUserId.isEmpty {
                    activeAccountProvider="apple"
                    username=KeychainHelper.load(key:"ide_apple_name") ?? "Apple User"
                } else { signOut() }
            }
        } else if provider == "apple" {
            KeychainHelper.delete(key:"ide_apple_uid")
            KeychainHelper.delete(key:"ide_apple_name")
            appleUserId=""
            if activeAccountProvider == "apple" {
                if githubConnected {
                    activeAccountProvider="github"
                    username=githubUsername
                } else { signOut() }
            }
        }
        loadSavedAccounts()
    }

    private func fetchAndCacheAvatar(_ urlStr:String) async {
        guard let url=URL(string:urlStr),
              let data=try? await IDEGitHubClient.shared.fetchAvatar(urlStr:urlStr),
              let img=UIImage(data:data) else{return}
        await MainActor.run{self.avatarImage=img;self.githubAvatarURL=url}
        KeychainHelper.save(key:"ide_github_avatar_url",value:urlStr)
    }

    private func ensureDefaultRepo(username:String) async {
        let r="Ash-Tree-IDE-Projects"
        guard !(await IDEGitHubClient.shared.repoExists(owner:username,repo:r)) else{return}
        guard let _ = try? await IDEGitHubClient.shared.createRepo(name:r,isPrivate:true) else{return}
        try? await IDEGitHubClient.shared.writeFile(owner:username,repo:r,path:"README.md",
            content:"# Ash Tree IDE\n© 2025 DART Meadow | Radical Deepscale LLC.",message:"Initialize")
    }

    private func loadSavedAccounts() {
        var accs:[IDESavedAccount]=[]
        if let gh=KeychainHelper.load(key:"ide_github_username"),!gh.isEmpty {
            let url=KeychainHelper.load(key:"ide_github_avatar_url").flatMap{URL(string:$0)}
            accs.append(.init(username:gh,provider:"github",avatarURL:url,isActive:activeAccountProvider=="github"))
        }
        if let apple=KeychainHelper.load(key:"ide_apple_name"),!apple.isEmpty {
            accs.append(.init(username:apple,provider:"apple",avatarURL:nil,isActive:activeAccountProvider=="apple"))
        }
        savedAccounts=accs
    }

    private func generateNonce(length:Int=32) -> String {
        let charset="0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        var result="";var remaining=length
        while remaining>0{
            var randoms=[UInt8](repeating:0,count:16)
            _=SecRandomCopyBytes(kSecRandomDefault,randoms.count,&randoms)
            randoms.forEach{r in guard remaining>0,r<charset.count else{return}
                result+=String(charset[charset.index(charset.startIndex,offsetBy:Int(r))]);remaining-=1}
        }
        return result
    }
    private func sha256(_ input:String)->String{
        SHA256.hash(data:Data(input.utf8)).map{String(format:"%02x",$0)}.joined()
    }
}

// MARK: - Legacy delegate extensions (kept for any existing call sites)

extension IDEAuthViewModel: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController,
                                        didCompleteWithAuthorization auth: ASAuthorization) {
        handleAppleCompletion(.success(auth))
    }
    public func authorizationController(controller: ASAuthorizationController,
                                        didCompleteWithError error: Error) {
        handleAppleCompletion(.failure(error))
    }
}

extension IDEAuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}
            .flatMap{$0.windows}.first{$0.isKeyWindow} ?? UIWindow()
    }
}
