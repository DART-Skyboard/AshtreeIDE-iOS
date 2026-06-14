// ============================================================
//  GitHubAuth.swift — GitHub Device Flow OAuth + Keychain
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Exact same pattern as ArcLake-iOS ArcAuthViewModel + ArcGitHubClient.
//  GitHub OAuth App: Ov23li2K0njEqO1WTSdD (shared with ArcLake)
// ============================================================

import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Keychain Helper

public enum KeychainHelper {
    public static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    public static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Saved Account

public struct IDESavedAccount: Identifiable {
    public let id = UUID()
    public let username: String
    public let provider: String  // "github" | "apple" | "guest"
    public let avatarURL: URL?
}

// MARK: - Device Flow Display

public struct IDEDeviceFlow: Identifiable {
    public let id = UUID()
    public let userCode: String
    public let verifyURL: URL
    public let deviceCode: String
    public let interval: Int
    public var isPolling = false
    public var error: String?
}

// MARK: - GitHub Models

public struct IDEGitHubRepo: Identifiable, Codable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let isPrivate: Bool
    public let description: String?
    public let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case fullName    = "full_name"
        case isPrivate   = "private"
        case defaultBranch = "default_branch"
    }
}

public struct IDEGitHubFile: Codable {
    public let name: String
    public let path: String
    public let sha: String?
    public let downloadURL: String?
    public let type: String
    public let size: Int?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, type, size
        case downloadURL = "download_url"
    }
}

// MARK: - GitHub Client (ArcLake actor pattern)

public actor IDEGitHubClient {
    public static let shared = IDEGitHubClient()
    private let session = URLSession.shared
    private let base = "https://api.github.com"
    private var _token: String?

    public func setToken(_ token: String) {
        _token = token
        KeychainHelper.save(key: "ide_github_pat", value: token)
    }
    public func loadToken() { _token = KeychainHelper.load(key: "ide_github_pat") }
    public func clearToken() { _token = nil; KeychainHelper.delete(key: "ide_github_pat") }
    public var hasToken: Bool { _token != nil }

    private func headers() -> [String: String] {
        var h = ["Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28"]
        if let t = _token { h["Authorization"] = "Bearer \(t)" }
        return h
    }

    // Device flow
    public func startDeviceFlow() async throws -> IDEDeviceFlow {
        var req = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=Ov23li2K0njEqO1WTSdD&scope=repo,read:user".data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userCode   = json["user_code"]    as? String,
              let verifyStr  = json["verification_uri"] as? String,
              let verifyURL  = URL(string: verifyStr),
              let deviceCode = json["device_code"]  as? String,
              let interval   = json["interval"]     as? Int else {
            throw URLError(.badServerResponse)
        }
        return IDEDeviceFlow(userCode: userCode, verifyURL: verifyURL,
                             deviceCode: deviceCode, interval: interval)
    }

    public func pollDeviceFlow(deviceCode: String, interval: Int) async throws -> String? {
        for _ in 0..<60 {
            try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            var req = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = "client_id=Ov23li2K0njEqO1WTSdD&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)
            guard let (data, _) = try? await session.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let token = json["access_token"] as? String { return token }
            let err = json["error"] as? String ?? ""
            if err == "access_denied" || err == "expired_token" { return nil }
        }
        return nil
    }

    public func fetchUser() async throws -> (login: String, name: String?, avatarURL: String?) {
        struct GHUser: Decodable {
            let login: String; let name: String?
            let avatar_url: String?
        }
        let data = try await get("/user")
        let u = try JSONDecoder().decode(GHUser.self, from: data)
        return (u.login, u.name, u.avatar_url)
    }

    public func fetchAvatar(urlStr: String) async throws -> Data {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        return try await session.data(from: url).0
    }

    public func listRepos() async throws -> [IDEGitHubRepo] {
        let data = try await get("/user/repos?per_page=100&sort=updated&type=all")
        return try JSONDecoder().decode([IDEGitHubRepo].self, from: data)
    }

    public func listFiles(owner: String, repo: String, path: String = "") async throws -> [IDEGitHubFile] {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let p = path.isEmpty ? "" : "/\(encoded)"
        let data = try await get("/repos/\(owner)/\(repo)/contents\(p)")
        return try JSONDecoder().decode([IDEGitHubFile].self, from: data)
    }

    public func readFile(owner: String, repo: String, path: String) async throws -> String {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let data = try await get("/repos/\(owner)/\(repo)/contents/\(encoded)")
        struct F: Decodable { let content: String? }
        let f = try JSONDecoder().decode(F.self, from: data)
        guard let b64 = f.content?.replacingOccurrences(of: "\n", with: "") else { return "" }
        return String(data: Data(base64Encoded: b64) ?? Data(), encoding: .utf8) ?? ""
    }

    public func writeFile(owner: String, repo: String, path: String, content: String, message: String) async throws {
        let b64 = Data(content.utf8).base64EncodedString()
        // Get existing SHA if any
        var sha: String?
        if let data = try? await get("/repos/\(owner)/\(repo)/contents/\(path)"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sha = json["sha"] as? String
        }
        var body: [String: Any] = ["message": message, "content": b64]
        if let sha { body["sha"] = sha }
        _ = try await put("/repos/\(owner)/\(repo)/contents/\(path)", body: body)
    }

    public func createRepo(name: String, isPrivate: Bool = true) async throws -> IDEGitHubRepo {
        let body: [String: Any] = ["name": name, "private": isPrivate,
                                   "description": "Ash Tree IDE projects — DART Meadow | Radical Deepscale LLC.",
                                   "auto_init": true]
        let data = try await post("/user/repos", body: body)
        return try JSONDecoder().decode(IDEGitHubRepo.self, from: data)
    }

    public func repoExists(owner: String, repo: String) async -> Bool {
        guard let data = try? await get("/repos/\(owner)/\(repo)"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["id"] != nil else { return false }
        return true
    }

    // Private HTTP helpers
    private func get(_ path: String) async throws -> Data {
        var req = URLRequest(url: URL(string: base + path)!)
        headers().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        return try await session.data(for: req).0
    }
    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "POST"
        headers().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await session.data(for: req).0
    }
    private func put(_ path: String, body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "PUT"
        headers().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await session.data(for: req).0
    }
}

// MARK: - Auth ViewModel (ArcLake Fruta pattern)

@MainActor
public final class IDEAuthViewModel: NSObject, ObservableObject {

    private var appleAuthController: ASAuthorizationController?

    @Published public var isSignedIn      = false
    @Published public var isGuest         = false
    @Published public var githubConnected = false
    @Published public var username        = ""
    @Published public var githubUsername  = ""
    @Published public var githubAvatarURL: URL? = nil
    @Published public var avatarImage: UIImage?  = nil
    @Published public var appleUserId     = ""
    @Published public var error: String?  = nil
    @Published public var deviceFlow: IDEDeviceFlow?
    @Published public var savedAccounts: [IDESavedAccount] = []

    private let githubClientId = "Ov23li2K0njEqO1WTSdD"

    // ── Launch restore (Fruta pattern — same as ArcLake) ─────────
    public func restoreSession() {
        // Try GitHub first
        if let pat = KeychainHelper.load(key: "ide_github_pat"), !pat.isEmpty {
            if let cached = KeychainHelper.load(key: "ide_github_avatar_url"),
               let url = URL(string: cached) {
                githubAvatarURL = url
            }
            Task {
                await IDEGitHubClient.shared.setToken(pat)
                if let user = try? await IDEGitHubClient.shared.fetchUser() {
                    KeychainHelper.save(key: "ide_github_username", value: user.login)
                    await MainActor.run {
                        self.githubConnected = true
                        self.githubUsername  = user.login
                        self.username        = user.login
                        self.isSignedIn      = true
                    }
                    if let avatarStr = user.avatarURL {
                        await fetchAndCacheAvatar(avatarStr)
                    }
                    await ensureDefaultRepo(username: user.login)
                }
            }
            let ghUser = KeychainHelper.load(key: "ide_github_username") ?? ""
            if !ghUser.isEmpty {
                githubConnected = true; githubUsername = ghUser
                username = ghUser; isSignedIn = true
            }
        }

        // Check Apple
        if let uid = KeychainHelper.load(key: "ide_apple_uid"), !uid.isEmpty {
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: uid) { [weak self] state, _ in
                DispatchQueue.main.async {
                    if state == .authorized && !(self?.isSignedIn ?? false) {
                        let name = KeychainHelper.load(key: "ide_apple_name") ?? "Apple User"
                        self?.appleUserId = uid
                        self?.username    = name
                        self?.isSignedIn  = true
                    }
                }
            }
        }

        loadSavedAccounts()
    }

    // ── Sign in with Apple ────────────────────────────────────────
    public func signInWithApple() {
        let provider  = ASAuthorizationAppleIDProvider()
        let request   = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        request.nonce = nonce

        let ctrl = ASAuthorizationController(authorizationRequests: [request])
        ctrl.delegate             = self
        ctrl.presentationContextProvider = self
        ctrl.performRequests()
        appleAuthController = ctrl
    }

    public func performExistingAccountSetup() {
        let apple = ASAuthorizationAppleIDProvider().createRequest()
        let pw    = ASAuthorizationPasswordProvider().createRequest()
        let ctrl  = ASAuthorizationController(authorizationRequests: [apple, pw])
        ctrl.delegate             = self
        ctrl.presentationContextProvider = self
        ctrl.performRequests()
        appleAuthController = ctrl
    }

    // ── GitHub Device Flow ────────────────────────────────────────
    public func startGitHubDeviceFlow() async {
        do {
            var flow = try await IDEGitHubClient.shared.startDeviceFlow()
            flow.isPolling = true
            deviceFlow = flow

            // Copy code + open browser
            UIPasteboard.general.string = flow.userCode
            await UIApplication.shared.open(flow.verifyURL)

            guard let token = try await IDEGitHubClient.shared.pollDeviceFlow(
                deviceCode: flow.deviceCode, interval: flow.interval) else {
                deviceFlow?.error = "Authorization expired. Please try again."
                deviceFlow?.isPolling = false
                return
            }

            await IDEGitHubClient.shared.setToken(token)
            let user = try await IDEGitHubClient.shared.fetchUser()
            KeychainHelper.save(key: "ide_github_username", value: user.login)

            githubConnected = true
            githubUsername  = user.login
            username        = user.login
            isSignedIn      = true
            deviceFlow      = nil

            if let avatarStr = user.avatarURL {
                KeychainHelper.save(key: "ide_github_avatar_url", value: avatarStr)
                await fetchAndCacheAvatar(avatarStr)
            }
            loadSavedAccounts()
            await ensureDefaultRepo(username: user.login)

        } catch {
            deviceFlow?.error = error.localizedDescription
            deviceFlow?.isPolling = false
        }
    }

    // ── Guest ─────────────────────────────────────────────────────
    public func continueAsGuest() {
        isGuest    = true
        isSignedIn = true
        username   = "Guest"
    }

    // ── Sign out ──────────────────────────────────────────────────
    public func signOut() {
        isSignedIn      = false
        isGuest         = false
        githubConnected = false
        username        = ""
        githubUsername  = ""
        githubAvatarURL = nil
        avatarImage     = nil
        appleUserId     = ""
        Task { await IDEGitHubClient.shared.clearToken() }
        ["ide_github_pat","ide_github_username","ide_github_avatar_url",
         "ide_apple_uid","ide_apple_name"].forEach { KeychainHelper.delete(key: $0) }
        loadSavedAccounts()
    }

    // ── Avatar ────────────────────────────────────────────────────
    private func fetchAndCacheAvatar(_ urlStr: String) async {
        guard let url = URL(string: urlStr),
              let data = try? await IDEGitHubClient.shared.fetchAvatar(urlStr: urlStr),
              let img  = UIImage(data: data) else { return }
        await MainActor.run {
            self.avatarImage     = img
            self.githubAvatarURL = url
        }
        KeychainHelper.save(key: "ide_github_avatar_url", value: urlStr)
    }

    // ── Auto-create private IDE repo on first sign-in ─────────────
    private func ensureDefaultRepo(username: String) async {
        let repoName = "Ash-Tree-IDE-Projects"
        let exists = await IDEGitHubClient.shared.repoExists(owner: username, repo: repoName)
        guard !exists else { return }
        guard let _ = try? await IDEGitHubClient.shared.createRepo(name: repoName, isPrivate: true) else { return }
        // Seed README
        let readme = """
        # Ash Tree IDE — Project Files
        **Owner:** @\(username)  ·  © 2025 DART Meadow | Radical Deepscale LLC.

        Ash language scripts created with **Ash Tree IDE** on iOS.

        ## LEATR v2 Syntax
        ```ash
        {{env:MyProject}}
        [[script:hello-v1]]

        (HelloNode):-: {
          with var (s) {
            irin ("Data: Hello from Ash!")
            Maze
            thenplace var (s) with var (s)
          }
          irout ("Result: " placeto (s))
        }|';'|
        ```
        """
        try? await IDEGitHubClient.shared.writeFile(
            owner: username, repo: repoName,
            path: "README.md", content: readme,
            message: "Initialize Ash Tree IDE repository")
    }

    // ── Saved accounts ────────────────────────────────────────────
    private func loadSavedAccounts() {
        var accounts: [IDESavedAccount] = []
        if let gh = KeychainHelper.load(key: "ide_github_username"), !gh.isEmpty {
            let avatarStr = KeychainHelper.load(key: "ide_github_avatar_url")
            let avatarURL = avatarStr.flatMap { URL(string: $0) }
            accounts.append(IDESavedAccount(username: gh, provider: "github", avatarURL: avatarURL))
        }
        if let apple = KeychainHelper.load(key: "ide_apple_name"), !apple.isEmpty {
            accounts.append(IDESavedAccount(username: apple, provider: "apple", avatarURL: nil))
        }
        savedAccounts = accounts
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension IDEAuthViewModel: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController,
                                        didCompleteWithAuthorization authorization: ASAuthorization) {
        if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
            let uid = cred.user
            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            let displayName = name.isEmpty ? (KeychainHelper.load(key: "ide_apple_name") ?? "Apple User") : name
            KeychainHelper.save(key: "ide_apple_uid",  value: uid)
            KeychainHelper.save(key: "ide_apple_name", value: displayName)
            appleUserId = uid
            username    = displayName
            isSignedIn  = true
            if !githubConnected { loadSavedAccounts() }
        }
    }

    public func authorizationController(controller: ASAuthorizationController,
                                        didCompleteWithError error: Error) {
        if (error as? ASAuthorizationError)?.code != .canceled {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Presentation context

extension IDEAuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
