// ============================================================
//  IDEState.swift — Global IDE State
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI
import Combine

// MARK: - App Tab

public enum IDETab: String, CaseIterable {
    case editor   = "Editor"
    case output   = "Output"
    case terminal = "Terminal"
    case files    = "Files"
    case maze     = "Maze"
    case docs     = "Docs"

    public var icon: String {
        switch self {
        case .editor:   return "chevron.left.forwardslash.chevron.right"
        case .output:   return "text.alignleft"
        case .terminal: return "terminal"
        case .files:    return "folder"
        case .maze:     return "puzzlepiece"
        case .docs:     return "book"
        }
    }
}

// MARK: - IDE State

@MainActor
public final class IDEState: ObservableObject {

    // ── Editor ────────────────────────────────────────────────────
    @Published public var sourceCode: String = IDEDefaults.defaultScript
    @Published public var currentFile  = "untitled.ash"
    @Published public var isDirty      = false
    @Published public var selectedTab: IDETab = .editor
    @Published public var isCompiling  = false
    @Published public var isSaving     = false

    // ── Side drawer ────────────────────────────────────────────────
    @Published public var showDrawer   = false
    @Published public var drawerTab: DrawerTab = .files

    public enum DrawerTab: String, CaseIterable {
        case files    = "Files"
        case repos    = "Repos"
        case settings = "Settings"
        case profile  = "Profile"
        case about    = "About"

        public var icon: String {
            switch self {
            case .files:    return "doc.text"
            case .repos:    return "folder.badge.gearshape"
            case .settings: return "gearshape"
            case .profile:  return "person.circle"
            case .about:    return "info.circle"
            }
        }
    }

    // ── GitHub ────────────────────────────────────────────────────
    @Published public var repos: [IDEGitHubRepo] = []
    @Published public var currentRepo: IDEGitHubRepo?
    @Published public var repoFiles: [IDEGitHubFile] = []
    @Published public var currentPath = ""
    @Published public var isLoadingFiles = false

    // ── Compiler ──────────────────────────────────────────────────
    public let compiler = LeatrEngine()

    // ── Examples ──────────────────────────────────────────────────
    public let examples: [(name: String, icon: String, code: String)] = IDEDefaults.examples

    // ── Compile + run ─────────────────────────────────────────────
    public func buildAndRun(netMode: Bool = false) async {
        isCompiling = true
        compiler.compile(source: sourceCode, netMode: netMode)
        try? await Task.sleep(nanoseconds: 100_000_000)
        isCompiling = false
        selectedTab = .output
    }

    public func autoLoadDefs() async {
        await compiler.autoLoadDefs()
    }

    // ── File operations ───────────────────────────────────────────
    public func loadExample(_ code: String, name: String) {
        sourceCode   = code
        currentFile  = name + ".ash"
        isDirty      = false
        selectedTab  = .editor
    }

    public func newFile() {
        sourceCode  = "// New Ash script\n{{env:MyProject}}\n[[script:new-script]]\n\n"
        currentFile = "untitled.ash"
        isDirty     = false
    }

    public func loadRepos() async {
        guard let _ = KeychainHelper.load(key: "ide_github_pat") else { return }
        isLoadingFiles = true
        repos = (try? await IDEGitHubClient.shared.listRepos()) ?? []
        isLoadingFiles = false
    }

    public func loadFiles(repo: IDEGitHubRepo, path: String = "") async {
        isLoadingFiles = true
        currentRepo  = repo
        currentPath  = path
        let username = KeychainHelper.load(key: "ide_github_username") ?? ""
        let owner = String(repo.fullName.split(separator: "/").first ?? Substring(username))
        repoFiles = (try? await IDEGitHubClient.shared.listFiles(
            owner: owner, repo: repo.name, path: path)) ?? []
        isLoadingFiles = false
    }

    public func openFile(_ file: IDEGitHubFile) async {
        guard file.type == "file", file.name.hasSuffix(".ash") else { return }
        let username = KeychainHelper.load(key: "ide_github_username") ?? ""
        let repo = currentRepo?.name ?? ""
        let owner = currentRepo.map { String($0.fullName.split(separator: "/").first ?? Substring(username)) } ?? username
        let content = (try? await IDEGitHubClient.shared.readFile(
            owner: owner, repo: repo, path: file.path)) ?? ""
        sourceCode   = content
        currentFile  = file.name
        isDirty      = false
        selectedTab  = .editor
    }

    public func saveFile(message: String? = nil) async -> Bool {
        guard let repo = currentRepo else { return false }
        let username = KeychainHelper.load(key: "ide_github_username") ?? ""
        let owner = String(repo.fullName.split(separator: "/").first ?? Substring(username))
        let msg = message ?? "Update \(currentFile) via Ash Tree IDE"
        isSaving = true
        let success = (try? await IDEGitHubClient.shared.writeFile(
            owner: owner, repo: repo.name,
            path: currentPath.isEmpty ? currentFile : "\(currentPath)/\(currentFile)",
            content: sourceCode, message: msg)) != nil
        isSaving = false
        if success { isDirty = false }
        return success
    }
}

// MARK: - Default Scripts

public enum IDEDefaults {
    public static let defaultScript = """
// Ash Tree IDE · LEATR v2 · © 2025 DART Meadow | Radical Deepscale LLC.
// Compiler Standard: (xa²√xa)±1 wraps every syntax pattern.
// ════════════════════════════════════════════════════════════

{{env:MyProject}}
[[script:hello-world-v1]]

(CoreParameterNode):-: {

  {{env:MyProject}}
  [[owner:user]]

  with
    var (s)   // Data Set
    var (c)   // Cognition
  {
    irin ("Data: Hello from Ash!")
    Maze
    thenplace var (s) with var (c)
  }

  irout ("Result: " placeto (s))

}|';'|
"""

    public static let examples: [(name: String, icon: String, code: String)] = [
        ("Hello World", "hand.wave", helloWorld),
        ("Counter App", "plusminus", counterApp),
        ("Physics Sim", "atom", physicsSim),
        ("Network Node", "network", networkNode),
        ("Autumn Core", "leaf", autumnCore),
        ("3D Animation", "cube", ash3D),
    ]

    static let helloWorld = """
// HELLO WORLD — Ash Language · LEATR v2
{{env:HelloWorld}}
[[script:hello-world-v1]]

(HelloWorldNode):-: {
  with
    var (s)   // Data Set
  {
    irin ("Data: Hello, World!")
    Maze
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';'|
"""

    static let counterApp = """
// COUNTER APP — Ash Language · LEATR v2
{{env:CounterApp}}
[[script:counter-v1]]

(CounterNode):-: {
  with
    var (count)   // counter
    var (step)    // increment
    var (s)       // data set
  {
    irin ("Data: count=0 step=1")
    Puzzle
    thenplace var (count) with var (step)
    thenplace var (s) with var (count)
  }
  irout ("Result: count=" placeto (count))
}|';'|
"""

    static let physicsSim = """
// PHYSICS SIM — Ash Language · LEATR v2
{{env:PhysicsSim}}
[[script:gravity-node-v1]]
[poly: gravity-math]

(GravityNode):-: {
  {{env:PhysicsSim}}
  [[owner:user]]
  [poly: mass-velocity-pressure]
  with
    var (mass)     // kg
    var (gravity)  // m/s²
    var (velocity) // m/s
    var (s)        // data set
  {
    irin ("Data: mass=1 gravity=9.81")
    Hammer
    Research (mass * gravity)
    thenplace var (velocity) with var (s)
  }
  irout ("Result: F=" placeto (velocity))
}|';'|
"""

    static let networkNode = """
// NETWORK NODE — Ash Language · LEATR v2
{{env:NetworkLayer}}
[[script:network-sync-v1]]
[net: log-iter-mode]

(NetworkSyncNode):-: {
  {{env:NetworkLayer}}
  [[owner:user]]
  [net: payload-router]
  with
    var (payload)  // data
    var (iter)     // iteration
    var (s)        // data set
  {
    irin ("Data: payload=sync iter=0")
    Stick
    thenplace var (iter) with var (s)
    thenplace var (s) with var (payload)
  }
  irout ("Result: " placeto (payload))
}|';'|
"""

    static let autumnCore = """
// AUTUMN CORE — Ash Language · LEATR v2
{{env:AutumnCore}}
[[script:autumn-core-logic-v1]]

(AutumnCoreLogicNode):-: {
  {{env:AutumnCore}}
  [[owner:user]]
  with
    var (s)   // Data Set
    var (c)   // Cognition
  {
    irin ("Data: Maze Puzzle Envelope Hammer Stick Knife Scissors")
    thenplace var (s) with var (c)
  }
  irout ("Result: " placeto (s))
}|';'|
"""

    static let ash3D = """
// ASH TREE 3D — Arc Edge Geometry · LEATR v2
// © 2025 DART Meadow | Radical Deepscale LLC.
// Arc Edge math (Justin Craig Venable):
//   Circumference: sqrt(d*3)^2   (no π)
//   Area:          circ^2
//   Volume:        area^3
//   Sphere SA:     vol * 0.25
//   Branch:        1/8 circle arc

import (GLDrivers)

{{env:AshTree-3D}}
[[script:ash-tree-arcedge-v1]]
[net: webgl-runtime]
[poly: arc-edge-geometry]

(ThreeScene):-: {
  {{env:AshTree-3D}}
  [[owner:DART-Meadow]]
  [poly: render-pipeline]
  with
    var (scene)
    var (s)
  {
    irin ("background:0x000814 fov:55 py:3 pz:14 fog:true")
    gl.scene
    gl.render
    thenplace var (scene) with var (s)
  }
  irout ("Result: " placeto (scene))
}|';'|

(ArcEdgeNode):-: {
  {{env:AshTree-3D}}
  [[owner:DART-Meadow]]
  [poly: arc-edge-geometry]
  with
    var (d)
    var (levels)
    var (s)
  {
    irin ("name:ashTree d:1.8 levels:5 segs:18 color:0x00ffcc emissive:0x003322 ry:0.0025")
    thenplace var (s) with var (d)
  }
  irout ("Result: " placeto (s))
}|';'|

(AnimateNode):-: {
  {{env:AshTree-3D}}
  with var (s) {
    irin ("target:ashTree ry:0.0025")
    gl.animate
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';'|
"""
}
