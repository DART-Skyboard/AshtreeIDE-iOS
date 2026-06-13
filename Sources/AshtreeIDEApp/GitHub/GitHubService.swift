// ============================================================
//  GitHubService.swift — GitHub OAuth Device Flow + Repo Management
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  On first sign-in, automatically creates:
//    {username}/Ash-Tree-IDE-Projects  (private)
//  with a pre-seeded README and example .ash file.
// ============================================================

import Foundation
import AuthenticationServices

// MARK: - GitHub User

struct GitHubUser: Codable {
    let login: String
    let name: String?
    let avatarUrl: String?
    enum CodingKeys: String, CodingKey {
        case login; case name; case avatarUrl = "avatar_url"
    }
}

// MARK: - GitHub File

struct GitHubFile: Identifiable, Codable {
    var id: String { path }
    let name: String
    let path: String
    let sha: String?
    let downloadUrl: String?
    enum CodingKeys: String, CodingKey {
        case name; case path; case sha
        case downloadUrl = "download_url"
    }
}

// MARK: - Session

struct GitHubSession: Codable {
    let accessToken: String
    let username: String
    let name: String?
    let avatarUrl: String?
}

// MARK: - GitHubService

@MainActor
final class GitHubService: ObservableObject {

    static let shared = GitHubService()

    // GitHub OAuth App credentials (Device Flow — no redirect URL needed on iOS)
    private let clientID = "Ov23li2K0njEqO1WTSdD"     // reuse Autumn app client
    private let scopes   = "repo,read:user"
    private let repoName = "Ash-Tree-IDE-Projects"

    @Published var session: GitHubSession?
    @Published var isSigningIn = false
    @Published var error: String?
    @Published var files: [GitHubFile] = []
    @Published var repoReady = false

    private let sessionKey = "ashtree_gh_session"

    init() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let stored = try? JSONDecoder().decode(GitHubSession.self, from: data) {
            self.session = stored
        }
    }

    // MARK: - Device Flow Sign-In

    func startDeviceFlow() async -> (userCode: String, verifyUrl: String, deviceCode: String, interval: Int)? {
        guard let url = URL(string: "https://github.com/login/device/code") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(clientID)&scope=\(scopes)".data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userCode   = json["user_code"]   as? String,
              let verifyUri  = json["verification_uri"] as? String,
              let deviceCode = json["device_code"] as? String,
              let interval   = json["interval"]   as? Int else { return nil }
        return (userCode, verifyUri, deviceCode, interval)
    }

    func pollDeviceFlow(deviceCode: String, interval: Int) async -> String? {
        let body = "client_id=\(clientID)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        for _ in 0..<60 {      // max 5 min
            try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            guard let url = URL(string: "https://github.com/login/oauth/access_token") else { break }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = body.data(using: .utf8)
            guard let (data, _) = try? await URLSession.shared.data(for: req),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let token = json["access_token"] as? String { return token }
            let err = json["error"] as? String ?? ""
            if err == "access_denied" || err == "expired_token" { return nil }
            // authorization_pending — keep polling
        }
        return nil
    }

    func completeSignIn(token: String) async {
        guard let user = await fetchUser(token: token) else {
            error = "Could not fetch GitHub user"; return
        }
        let s = GitHubSession(accessToken: token, username: user.login,
                              name: user.name, avatarUrl: user.avatarUrl)
        session = s
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
        await ensureRepo(session: s)
    }

    func signOut() {
        session = nil
        repoReady = false
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: - GitHub API Helpers

    private func fetchUser(token: String) async -> GitHubUser? {
        guard let url = URL(string: "https://api.github.com/user") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let user = try? JSONDecoder().decode(GitHubUser.self, from: data) else { return nil }
        return user
    }

    // MARK: - Auto-Create Private Repo on First Sign-In

    func ensureRepo(session: GitHubSession) async {
        let token = session.accessToken
        let username = session.username
        // Check if repo exists
        let checkURL = URL(string: "https://api.github.com/repos/\(username)/\(repoName)")!
        var checkReq = URLRequest(url: checkURL)
        checkReq.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        checkReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        if let (_, resp) = try? await URLSession.shared.data(for: checkReq),
           (resp as? HTTPURLResponse)?.statusCode == 200 {
            repoReady = true; return
        }
        // Create repo
        let createURL = URL(string: "https://api.github.com/user/repos")!
        var createReq = URLRequest(url: createURL)
        createReq.httpMethod = "POST"
        createReq.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        createReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        createReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": repoName,
            "description": "Ash Language projects — Ash Tree IDE · DART Meadow | Radical Deepscale LLC.",
            "private": true,
            "auto_init": false
        ]
        createReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, createResp) = try? await URLSession.shared.data(for: createReq),
              (createResp as? HTTPURLResponse)?.statusCode == 201 else { return }

        // Seed README.md
        await writeFile(
            path: "README.md",
            content: seedReadme(username: username),
            message: "Initialize Ash Tree IDE project repository",
            token: token, username: username
        )
        // Seed example .ash file
        await writeFile(
            path: "examples/hello_world.ash",
            content: helloWorldAsh,
            message: "Add Hello World Ash example",
            token: token, username: username
        )
        repoReady = true
    }

    // MARK: - File Operations

    func loadFiles() async {
        guard let s = session else { return }
        guard let url = URL(string: "https://api.github.com/repos/\(s.username)/\(repoName)/git/trees/main?recursive=1") else { return }
        var req = URLRequest(url: url)
        req.setValue("token \(s.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tree = json["tree"] as? [[String: Any]] else { return }
        files = tree.compactMap { item -> GitHubFile? in
            guard let path = item["path"] as? String,
                  path.hasSuffix(".ash") else { return nil }
            let sha = item["sha"] as? String
            let name = URL(fileURLWithPath: path).lastPathComponent
            return GitHubFile(name: name, path: path, sha: sha, downloadUrl: nil)
        }
    }

    func readFile(path: String) async -> String? {
        guard let s = session else { return nil }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let url = URL(string: "https://api.github.com/repos/\(s.username)/\(repoName)/contents/\(encoded)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("token \(s.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3.raw", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveFile(path: String, content: String, message: String) async -> Bool {
        guard let s = session else { return false }
        // Get current SHA for update
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let metaURL = URL(string: "https://api.github.com/repos/\(s.username)/\(repoName)/contents/\(encoded)") else { return false }
        var metaReq = URLRequest(url: metaURL)
        metaReq.setValue("token \(s.accessToken)", forHTTPHeaderField: "Authorization")
        metaReq.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        let sha: String?
        if let (data, _) = try? await URLSession.shared.data(for: metaReq),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sha = json["sha"] as? String
        } else { sha = nil }

        return await writeFile(path: path, content: content, message: message,
                               token: s.accessToken, username: s.username, sha: sha)
    }

    @discardableResult
    private func writeFile(path: String, content: String, message: String,
                           token: String, username: String, sha: String? = nil) async -> Bool {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        guard let url = URL(string: "https://api.github.com/repos/\(username)/\(repoName)/contents/\(encoded)") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["message": message, "content": Data(content.utf8).base64EncodedString()]
        if let sha { body["sha"] = sha }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let code = (resp as? HTTPURLResponse)?.statusCode else { return false }
        return code == 200 || code == 201
    }

    // MARK: - Seed Content

    private func seedReadme(username: String) -> String {
        """
        # Ash Tree IDE — Project Repository
        **Owner:** @\(username)  ·  © 2025 DART Meadow | Radical Deepscale LLC.

        This repository stores your Ash language scripts created in the **Ash Tree IDE** iOS app.

        ## Language Overview
        Ash is a custom language built on the **LEATR v2** compiler standard (Lead Edge Ash Tree Reflex).

        ```ash
        // Switch OPEN  (xa²√xa) - 1  (0→1)
        (MyNode):-: {
          {{env:MyProject}}
          [[owner:\(username)]]
          with
            var (s)  // Data Set
          {
            irin ("Hello from Ash!")
            thenplace var (s) with var (s)
          }
          irout ("Result: " placeto (s))
        }|';'|
        ```

        ## Compiler Standard
        - `{{outer}}` — environment isolation shell
        - `[[inner]]` — script ownership identity
        - `[poly:]` — math/physics container (isolated from syntax)
        - `[net:]` — network syntax layer
        - `(Node):-:{` / `}|';'|` — switch open/close algebra

        Built with the Ash Tree IDE · DART Meadow | Radical Deepscale LLC.
        """
    }

    private var helloWorldAsh: String { """
        // Ash Tree IDE · LEATR v2 · Hello World
        // © 2025 DART Meadow | Radical Deepscale LLC.

        {{env:HelloWorld}}
        [[script:hello-world-v1]]

        (HelloWorldNode):-: {
          {{env:HelloWorld}}
          [[owner:user]]
          with
            var (s)  // Data Set
          {
            irin ("Data: Hello, World!")
            Maze
            thenplace var (s) with var (s)
          }
          irout ("Result: " placeto (s))
        }|';'|
        """ }
}
