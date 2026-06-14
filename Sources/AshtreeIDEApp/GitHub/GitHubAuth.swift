// GitHubAuth.swift v2 — SHA256 nonce fix + silent GitHub re-auth
// Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI

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

public struct IDESavedAccount: Identifiable {
    public let id = UUID(); public let username, provider: String; public let avatarURL: URL?
}
public struct IDEDeviceFlow: Identifiable {
    public let id = UUID(); public let userCode: String; public let verifyURL: URL
    public let deviceCode: String; public let interval: Int
    public var isPolling = false; public var error: String?
}
public struct IDEGitHubRepo: Identifiable, Codable {
    public let id: Int; public let name, fullName: String; public let isPrivate: Bool
    public let description: String?; public let defaultBranch: String
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName = "full_name"; case isPrivate = "private"; case defaultBranch = "default_branch"
    }
}
public struct IDEGitHubFile: Codable {
    public let name, path: String; public let sha, downloadURL, type: String?; public let size: Int?
    enum CodingKeys: String, CodingKey {
        case name, path, sha, type, size; case downloadURL = "download_url"
    }
}

public actor IDEGitHubClient {
    public static let shared = IDEGitHubClient()
    private let session = URLSession.shared
    private let base = "https://api.github.com"
    private var _token: String?
    public func setToken(_ t: String) { _token = t; KeychainHelper.save(key: "ide_github_pat", value: t) }
    public func loadToken() { _token = KeychainHelper.load(key: "ide_github_pat") }
    public func clearToken() { _token = nil; KeychainHelper.delete(key: "ide_github_pat") }
    public var hasToken: Bool { !(_token?.isEmpty ?? true) }
    private func headers() -> [String:String] {
        var h = ["Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"]
        if let t = _token { h["Authorization"] = "Bearer \(t)" }; return h
    }

    public func startDeviceFlow() async throws -> IDEDeviceFlow {
        var req = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=Ov23li2K0njEqO1WTSdD&scope=repo,read:user".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
              let uc = j["user_code"] as? String, let vs = j["verification_uri"] as? String,
              let vu = URL(string: vs), let dc = j["device_code"] as? String,
              let iv = j["interval"] as? Int else { throw URLError(.badServerResponse) }
        return IDEDeviceFlow(userCode: uc, verifyURL: vu, deviceCode: dc, interval: iv)
    }

    public func pollDeviceFlow(deviceCode: String, interval: Int) async throws -> String? {
        for _ in 0..<60 {
            try await Task.sleep(nanoseconds: UInt64(max(interval,5)) * 1_000_000_000)
            var req = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = "client_id=Ov23li2K0njEqO1WTSdD&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)
            guard let (d,_) = try? await session.data(for: req),
                  let j = try? JSONSerialization.jsonObject(with: d) as? [String:Any] else { continue }
            if let t = j["access_token"] as? String { return t }
            let e = j["error"] as? String ?? ""
            if e == "access_denied" || e == "expired_token" { return nil }
        }
        return nil
    }

    public func fetchUser() async throws -> (login: String, name: String?, avatarURL: String?) {
        struct U: Decodable { let login: String; let name: String?; let avatar_url: String? }
        let u = try JSONDecoder().decode(U.self, from: try await get("/user"))
        return (u.login, u.name, u.avatar_url)
    }
    public func fetchAvatar(urlStr: String) async throws -> Data {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        return try await session.data(from: url).0
    }
    public func listRepos() async throws -> [IDEGitHubRepo] {
        try JSONDecoder().decode([IDEGitHubRepo].self, from: try await get("/user/repos?per_page=100&sort=updated&type=all"))
    }
    public func listFiles(owner: String, repo: String, path: String = "") async throws -> [IDEGitHubFile] {
        let enc = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let p = path.isEmpty ? "" : "/\(enc)"
        let data = try await get("/repos/\(owner)/\(repo)/contents\(p)")
        if let arr = try? JSONDecoder().decode([IDEGitHubFile].self, from: data) { return arr }
        if let single = try? JSONDecoder().decode(IDEGitHubFile.self, from: data) { return [single] }
        return []
    }
    public func readFile(owner: String, repo: String, path: String) async throws -> String {
        let enc = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        struct F: Decodable { let content: String? }
        let f = try JSONDecoder().decode(F.self, from: try await get("/repos/\(owner)/\(repo)/contents/\(enc)"))
        guard let b64 = f.content?.replacingOccurrences(of: "\n", with: "") else { return "" }
        return String(data: Data(base64Encoded: b64) ?? Data(), encoding: .utf8) ?? ""
    }
    public func writeFile(owner: String, repo: String, path: String, content: String, message: String) async throws {
        let b64 = Data(content.utf8).base64EncodedString()
        var sha: String?
        if let d = try? await get("/repos/\(owner)/\(repo)/contents/\(path)"),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String:Any] { sha = j["sha"] as? String }
        var body: [String:Any] = ["message": message, "content": b64]
        if let s = sha { body["sha"] = s }
        _ = try await put("/repos/\(owner)/\(repo)/contents/\(path)", body: body)
    }
    public func createRepo(name: String, isPrivate: Bool = true) async throws -> IDEGitHubRepo {
        try JSONDecoder().decode(IDEGitHubRepo.self, from: try await post("/user/repos",
            body: ["name": name, "private": isPrivate, "description": "Ash Tree IDE projects", "auto_init": true]))
    }
    public func repoExists(owner: String, repo: String) async -> Bool {
        guard let d = try? await get("/repos/\(owner)/\(repo)"),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String:Any], j["id"] != nil else { return false }
        return true
    }
    private func get(_ path: String) async throws -> Data {
        var r = URLRequest(url: URL(string: base+path)!); headers().forEach { r.setValue($1, forHTTPHeaderField: $0) }
        return try await session.data(for: r).0
    }
    private func post(_ path: String, body: [String:Any]) async throws -> Data {
        var r = URLRequest(url: URL(string: base+path)!); r.httpMethod = "POST"
        headers().forEach { r.setValue($1, forHTTPHeaderField: $0) }
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await session.data(for: r).0
    }
    private func put(_ path: String, body: [String:Any]) async throws -> Data {
        var r = URLRequest(url: URL(string: base+path)!); r.httpMethod = "PUT"
        headers().forEach { r.setValue($1, forHTTPHeaderField: $0) }
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await session.data(for: r).0
    }
}

@MainActor
public final class IDEAuthViewModel: NSObject, ObservableObject {
    private var appleAuthController: ASAuthorizationController?
    private var currentNonce: String = ""

    @Published public var isSignedIn = false
    @Published public var isGuest = false
    @Published public var githubConnected = false
    @Published public var username = ""
    @Published public var githubUsername = ""
    @Published public var githubAvatarURL: URL? = nil
    @Published public var avatarImage: UIImage? = nil
    @Published public var appleUserId = ""
    @Published public var error: String? = nil
    @Published public var deviceFlow: IDEDeviceFlow?
    @Published public var savedAccounts: [IDESavedAccount] = []

    public func restoreSession() {
        if let pat = KeychainHelper.load(key: "ide_github_pat"), !pat.isEmpty {
            if let cached = KeychainHelper.load(key: "ide_github_avatar_url"), let url = URL(string: cached) {
                githubAvatarURL = url
            }
            Task {
                await IDEGitHubClient.shared.setToken(pat)
                if let user = try? await IDEGitHubClient.shared.fetchUser() {
                    KeychainHelper.save(key: "ide_github_username", value: user.login)
                    await MainActor.run {
                        self.githubConnected = true; self.githubUsername = user.login
                        self.username = user.login; self.isSignedIn = true
                    }
                    if let a = user.avatarURL { await self.fetchAndCacheAvatar(a) }
                    await self.ensureDefaultRepo(username: user.login)
                }
            }
            let ghUser = KeychainHelper.load(key: "ide_github_username") ?? ""
            if !ghUser.isEmpty { githubConnected=true; githubUsername=ghUser; username=ghUser; isSignedIn=true }
        }
        if let uid = KeychainHelper.load(key: "ide_apple_uid"), !uid.isEmpty {
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: uid) { [weak self] state, _ in
                DispatchQueue.main.async {
                    if state == .authorized && !(self?.isSignedIn ?? false) {
                        let name = KeychainHelper.load(key: "ide_apple_name") ?? "Apple User"
                        self?.appleUserId = uid; self?.username = name; self?.isSignedIn = true
                    }
                }
            }
        }
        loadSavedAccounts()
    }

    // Fix: SHA256 hashed nonce — this was the crash cause
    public func signInWithApple() {
        currentNonce = randomNonceString()
        let req = ASAuthorizationAppleIDProvider().createRequest()
        req.requestedScopes = [.fullName, .email]
        req.nonce = sha256(currentNonce)  // MUST be SHA256 of raw nonce
        let ctrl = ASAuthorizationController(authorizationRequests: [req])
        ctrl.delegate = self; ctrl.presentationContextProvider = self; ctrl.performRequests()
        appleAuthController = ctrl
    }

    // Fix: silently re-auth if token exists — no device flow needed
    public func startGitHubDeviceFlow() async {
        if let existingPat = KeychainHelper.load(key: "ide_github_pat"), !existingPat.isEmpty {
            await IDEGitHubClient.shared.setToken(existingPat)
            if let user = try? await IDEGitHubClient.shared.fetchUser() {
                KeychainHelper.save(key: "ide_github_username", value: user.login)
                githubConnected=true; githubUsername=user.login; username=user.login; isSignedIn=true
                if let a = user.avatarURL { await fetchAndCacheAvatar(a) }
                loadSavedAccounts(); return
            }
        }
        // No valid token — run new device flow
        do {
            var flow = try await IDEGitHubClient.shared.startDeviceFlow()
            flow.isPolling = true; deviceFlow = flow
            UIPasteboard.general.string = flow.userCode
            await UIApplication.shared.open(flow.verifyURL)
            guard let token = try await IDEGitHubClient.shared.pollDeviceFlow(deviceCode: flow.deviceCode, interval: flow.interval) else {
                deviceFlow?.error = "Authorization timed out."; deviceFlow?.isPolling = false; return
            }
            await IDEGitHubClient.shared.setToken(token)
            let user = try await IDEGitHubClient.shared.fetchUser()
            KeychainHelper.save(key: "ide_github_username", value: user.login)
            githubConnected=true; githubUsername=user.login; username=user.login; isSignedIn=true; deviceFlow=nil
            if let a = user.avatarURL { KeychainHelper.save(key: "ide_github_avatar_url", value: a); await fetchAndCacheAvatar(a) }
            loadSavedAccounts(); await ensureDefaultRepo(username: user.login)
        } catch { deviceFlow?.error = error.localizedDescription; deviceFlow?.isPolling = false }
    }

    public func forceNewDeviceFlow() async {
        await IDEGitHubClient.shared.clearToken()
        await startGitHubDeviceFlow()
    }

    public func continueAsGuest() { isGuest=true; isSignedIn=true; username="Guest" }

    public func signOut() {
        isSignedIn=false; isGuest=false; githubConnected=false; username=""; githubUsername=""
        githubAvatarURL=nil; avatarImage=nil; appleUserId=""
        Task { await IDEGitHubClient.shared.clearToken() }
        ["ide_github_pat","ide_github_username","ide_github_avatar_url","ide_apple_uid","ide_apple_name"]
            .forEach { KeychainHelper.delete(key: $0) }
        loadSavedAccounts()
    }

    private func fetchAndCacheAvatar(_ urlStr: String) async {
        guard let url = URL(string: urlStr),
              let data = try? await IDEGitHubClient.shared.fetchAvatar(urlStr: urlStr),
              let img = UIImage(data: data) else { return }
        await MainActor.run { self.avatarImage=img; self.githubAvatarURL=url }
        KeychainHelper.save(key: "ide_github_avatar_url", value: urlStr)
    }

    private func ensureDefaultRepo(username: String) async {
        let r = "Ash-Tree-IDE-Projects"
        guard !(await IDEGitHubClient.shared.repoExists(owner: username, repo: r)) else { return }
        guard let _ = try? await IDEGitHubClient.shared.createRepo(name: r, isPrivate: true) else { return }
        try? await IDEGitHubClient.shared.writeFile(owner: username, repo: r, path: "README.md",
            content: "# Ash Tree IDE\n© 2025 DART Meadow | Radical Deepscale LLC.",
            message: "Initialize Ash Tree IDE repository")
    }

    private func loadSavedAccounts() {
        var accounts: [IDESavedAccount] = []
        if let gh = KeychainHelper.load(key: "ide_github_username"), !gh.isEmpty {
            let url = KeychainHelper.load(key: "ide_github_avatar_url").flatMap { URL(string: $0) }
            accounts.append(.init(username: gh, provider: "github", avatarURL: url))
        }
        if let apple = KeychainHelper.load(key: "ide_apple_name"), !apple.isEmpty {
            accounts.append(.init(username: apple, provider: "apple", avatarURL: nil))
        }
        savedAccounts = accounts
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        var result = ""; var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16); _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            randoms.forEach { r in
                guard remaining > 0, r < charset.count else { return }
                result += String(charset[charset.index(charset.startIndex, offsetBy: Int(r))]); remaining -= 1
            }
        }
        return result
    }
    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension IDEAuthViewModel: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization auth: ASAuthorization) {
        if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
            let uid = cred.user
            let name = [cred.fullName?.givenName, cred.fullName?.familyName].compactMap{$0}.joined(separator: " ")
            let display = name.isEmpty ? (KeychainHelper.load(key: "ide_apple_name") ?? "Apple User") : name
            KeychainHelper.save(key: "ide_apple_uid", value: uid)
            KeychainHelper.save(key: "ide_apple_name", value: display)
            appleUserId=uid; username=display; isSignedIn=true; loadSavedAccounts()
        }
    }
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as? ASAuthorizationError)?.code != .canceled { self.error = error.localizedDescription }
    }
}

extension IDEAuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.flatMap{$0.windows}.first{$0.isKeyWindow} ?? UIWindow()
    }
}
