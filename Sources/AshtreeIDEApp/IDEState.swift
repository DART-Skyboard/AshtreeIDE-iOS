// IDEState.swift v2 — Fixed repo→files nav, 25 OOO, BRPN per-tool shells
// Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import Combine

public enum IDETab: String, CaseIterable {
    case editor = "Editor", output = "Output", terminal = "Terminal"
    case files = "Files", maze = "Maze", docs = "Docs"
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

@MainActor
public final class IDEState: ObservableObject {
    @Published public var sourceCode = IDEDefaults.defaultScript
    @Published public var currentFile = "untitled.ash"
    @Published public var isDirty = false
    @Published public var exportFileToDevice = false
    @Published public var selectedTab: IDETab = .editor
    @Published public var isCompiling = false
    @Published public var isSaving = false
    @Published public var showDrawer = false
    @Published public var drawerTab: DrawerTab = .files

    // File source switcher
    public enum FileSource: String, CaseIterable {
        case examples = "Examples", repository = "Repository", local = "Local"
        public var icon: String {
            switch self { case .examples: return "sparkles"; case .repository: return "chevron.left.forwardslash.chevron.right"; case .local: return "iphone" }
        }
    }
    @Published public var fileSource: FileSource = .examples

    public enum DrawerTab: String, CaseIterable {
        case files = "Projects", repos = "Repos", settings = "Settings"
        case profile = "Profile", about = "About"
        public var icon: String {
            switch self {
            case .files: return "doc.text"; case .repos: return "folder.badge.gearshape"
            case .settings: return "gearshape"; case .profile: return "person.circle"; case .about: return "info.circle"
            }
        }
    }

    @Published public var repos: [IDEGitHubRepo] = []
    @Published public var currentRepo: IDEGitHubRepo?
    @Published public var repoFiles: [IDEGitHubFile] = []
    @Published public var currentPath = ""
    @Published public var isLoadingFiles = false
    @Published public var localFiles: [String] = []  // filenames saved locally

    public let compiler = LeatrEngine()
    public let examples: [(name: String, icon: String, code: String)] = IDEDefaults.examples

    // MARK: - Compile

    public func buildAndRun(netMode: Bool = false) async {
        isCompiling = true
        compiler.compile(source: sourceCode, netMode: netMode)
        try? await Task.sleep(nanoseconds: 100_000_000)
        isCompiling = false
        selectedTab = .output
    }

    public func autoLoadDefs() async { await compiler.autoLoadDefs() }

    // MARK: - File operations

    public func loadExample(_ code: String, name: String) {
        sourceCode = code; currentFile = name + ".ash"; isDirty = false; selectedTab = .editor
    }

    public func newFile() {
        sourceCode = "// New Ash script\n{{env:MyProject}}\n[[script:new-script]]\n\n"
        currentFile = "untitled.ash"; isDirty = false
    }

    // MARK: - GitHub

    public func loadRepos() async {
        guard let _ = KeychainHelper.load(key: "ide_github_pat") else { return }
        isLoadingFiles = true
        repos = (try? await IDEGitHubClient.shared.listRepos()) ?? []
        isLoadingFiles = false
    }

    // Fixed: after selecting repo, switch to Files tab and show repo files
    public func selectRepo(_ repo: IDEGitHubRepo) async {
        currentRepo = repo
        currentPath = ""
        fileSource = .repository  // Switch file source to repository view
        selectedTab = .editor     // Keep editor open but update file panel
        showDrawer = false
        await loadFiles(repo: repo, path: "")
    }

    public func loadFiles(repo: IDEGitHubRepo, path: String = "") async {
        isLoadingFiles = true
        currentRepo = repo; currentPath = path
        let username = KeychainHelper.load(key: "ide_github_username") ?? ""
        let owner = String(repo.fullName.split(separator: "/").first ?? Substring(username))
        repoFiles = (try? await IDEGitHubClient.shared.listFiles(owner: owner, repo: repo.name, path: path)) ?? []
        isLoadingFiles = false
    }

    public func openFile(_ file: IDEGitHubFile) async {
        guard file.type == "file" else { return }
        let username = KeychainHelper.load(key: "ide_github_username") ?? ""
        let repo = currentRepo?.name ?? ""
        let owner = currentRepo.map { String($0.fullName.split(separator: "/").first ?? Substring(username)) } ?? username
        let content = (try? await IDEGitHubClient.shared.readFile(owner: owner, repo: repo, path: file.path)) ?? ""
        sourceCode = content; currentFile = file.name; isDirty = false; selectedTab = .editor
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
        isSaving = false; if success { isDirty = false }; return success
    }

    // MARK: - Local file storage

    public func saveLocally() {
        let key = "ide_local_\(currentFile)"
        UserDefaults.standard.set(sourceCode, forKey: key)
        if !localFiles.contains(currentFile) { localFiles.append(currentFile) }
        UserDefaults.standard.set(localFiles, forKey: "ide_local_file_list")
        UserDefaults.standard.synchronize()  // force immediate write
        isDirty = false
        // Reload to confirm persistence
        loadLocalFiles()
    }

    /// Delete a local file
    public func deleteLocalFile(_ name: String) {
        UserDefaults.standard.removeObject(forKey: "ide_local_\(name)")
        localFiles.removeAll { $0 == name }
        UserDefaults.standard.set(localFiles, forKey: "ide_local_file_list")
        UserDefaults.standard.synchronize()
    }

    /// New file name dialog helper
    public func renameCurrentFile(to name: String) {
        let trimmed = name.hasSuffix(".ash") ? name : name + ".ash"
        // If saving a new file under new name, delete old placeholder
        if currentFile == "untitled.ash" || currentFile.isEmpty {
            currentFile = trimmed
        } else {
            currentFile = trimmed
        }
    }

    public func loadLocalFiles() {
        localFiles = UserDefaults.standard.stringArray(forKey: "ide_local_file_list") ?? []
    }

    public func openLocalFile(_ name: String) {
        if let content = UserDefaults.standard.string(forKey: "ide_local_\(name)") {
            sourceCode = content; currentFile = name; isDirty = false; selectedTab = .editor
        }
    }
}

// MARK: - Default Scripts

public enum IDEDefaults {
    public static let defaultScript = """
// Ash Tree IDE · LEATR v2 · © 2025 DART Meadow | Radical Deepscale LLC.
{{env:MyProject}}
[[script:hello-world-v1]]

(CoreParameterNode):-: {
  {{env:MyProject}}
  [[owner:user]]
  with var (s) var (c) {
    irin ("Data: Hello from Ash!")
    Maze
    thenplace var (s) with var (c)
  }
  irout ("Result: " placeto (s))
}|';'|
"""
    public static let examples: [(name: String, icon: String, code: String)] = [
        ("Hello World",   "hand.wave",   helloWorld),
        ("Counter App",   "plusminus",   counterApp),
        ("Physics Sim",   "atom",        physicsSim),
        ("Network Node",  "network",     networkNode),
        ("Autumn Core",   "leaf",        autumnCore),
        ("3D Animation",  "cube",        ash3D),
        ("Neural Scene",  "brain.head.profile", neuralScene),
        ("Arc Edge Vector","waveform",          arcEdgeVector),
    ]

    static let helloWorld = """
{{env:HelloWorld}}
[[script:hello-world-v1]]
(HelloWorldNode):-: {
  with var (s) {
    irin ("Data: Hello, World!")
    Maze
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';'|
"""
    static let counterApp = """
{{env:CounterApp}}
[[script:counter-v1]]
(CounterNode):-: {
  with var (count) var (step) var (s) {
    irin ("Data: count=0 step=1")
    Puzzle
    thenplace var (count) with var (step)
    thenplace var (s) with var (count)
  }
  irout ("Result: count=" placeto (count))
}|';'|
"""
    static let physicsSim = """
{{env:PhysicsSim}}
[[script:gravity-node-v1]]
[poly: gravity-math]
(GravityNode):-: {
  {{env:PhysicsSim}}
  [poly: mass-velocity-pressure]
  with var (mass) var (gravity) var (velocity) var (s) {
    irin ("Data: mass=1 gravity=9.81")
    Hammer
    Research (mass * gravity)
    thenplace var (velocity) with var (s)
  }
  irout ("Result: F=" placeto (velocity))
}|';'|
"""
    static let networkNode = """
{{env:NetworkLayer}}
[[script:network-sync-v1]]
[net: log-iter-mode]
(NetworkSyncNode):-: {
  [net: payload-router]
  with var (payload) var (iter) var (s) {
    irin ("Data: payload=sync iter=0")
    Stick
    thenplace var (iter) with var (s)
  }
  irout ("Result: " placeto (payload))
}|';'|
"""
    static let autumnCore = """
{{env:AutumnCore}}
[[script:autumn-core-logic-v1]]
(AutumnCoreLogicNode):-: {
  with var (s) var (c) {
    irin ("Data: Maze Puzzle Envelope Hammer Stick Knife Scissors")
    thenplace var (s) with var (c)
  }
  irout ("Result: " placeto (s))
}|';'|
"""
    static let ash3D = """
// ASH TREE 3D — Arc Edge Geometry · LEATR v2
// Arc Edge math: Circumference=sqrt(d*3)^2  Area=circ^2
// Volume=area^3  Sphere SA=vol*0.25  Branch=1/8 arc
import (GLDrivers)

{{env:AshTree-3D}}
[[script:ash-tree-arcedge-v1]]
[net: webgl-runtime]
[poly: arc-edge-geometry]

(ThreeScene):-: {
  {{env:AshTree-3D}}
  with var (scene) var (s) {
    irin ("background:0x000814 fov:55 py:3 pz:14 fog:true")
    gl.scene
    gl.render
    thenplace var (scene) with var (s)
  }
  irout ("Result: " placeto (scene))
}|';'|

(ArcEdgeNode):-: {
  [poly: arc-edge-geometry]
  with var (d) var (levels) var (s) {
    irin ("name:ashTree d:1.8 levels:5 segs:18 color:0x00ffcc emissive:0x003322 ry:0.0025")
    thenplace var (s) with var (d)
  }
  irout ("Result: " placeto (s))
}|';'|

(AnimateNode):-: {
  with var (s) {
    irin ("target:ashTree ry:0.0025")
    gl.animate
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';'|
"""
    static let neuralScene = """
// NEURAL BRPN SCENE — 3D animated brain nodes · LEATR v2
// Visualizes the Lead Edge Ash Tree Reflex neural network
// Each node: 3-shell BRPN (Aerospace/Maritime/Geological)
import (GLDrivers)

{{env:NeuralScene}}
[[script:brpn-neural-v1]]
[poly: neural-geometry]
[net: reflex-signal]

(ThreeScene):-: {
  {{env:NeuralScene}}
  with var (scene) var (s) {
    irin ("background:0x000814 fov:60 py:0 pz:20 fog:true")
    gl.scene
    gl.render
    thenplace var (scene) with var (s)
  }
  irout ("Result: " placeto (scene))
}|';'|

(NeuralNode):-: {
  [poly: brpn-shell-geometry]
  with var (nodeId) var (shells) var (s) {
    irin ("count:12 aerospace:true maritime:true geological:true pulse:true")
    gl.mesh
    thenplace var (shells) with var (nodeId)
    thenplace var (s) with var (shells)
  }
  irout ("Result: " placeto (s))
}|';'|

(SynapseNode):-: {
  [net: signal-propagation]
  with var (from) var (to) var (signal) var (s) {
    irin ("speed:0.8 color:0x00ffcc emissive:0x003322")
    gl.animate
    thenplace var (signal) with var (from)
    thenplace var (s) with var (to)
  }
  irout ("Result: " placeto (s))
}|';'|

(AnimateNode):-: {
  with var (s) {
    irin ("target:neural pulse:true freq:1.2")
    gl.animate
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';'|
"""
    static let arcEdgeVector = """
// ARC EDGE VECTOR — Three-axis tangent spline system · LEATR v2
// Port of arc-edge-vector.html to Ash syntax
// Arc Edge math (Justin Craig Venable, doc=3.0 replaces π):
//   Circumference: sqrt(d × 3)²
//   Area: circ²    Volume: area³    Sphere SA: vol × 0.25
//   Branch arc: circ / 8  (every branch = 1/8-circle arc)
import (GLDrivers)

{{env:ArcEdgeVector}}
[[script:arc-edge-v1]]
[poly: arc-edge-geometry]
[net: vector-physics]

(ArcEdgeScene):-: {
  {{env:ArcEdgeVector}}
  [[owner:DART-Meadow]]
  with var (scene) var (s) {
    irin ("background:0x060a10 fov:60 doc:3.0")
    gl.scene
    gl.render
    thenplace var (scene) with var (s)
  }
  irout ("Result: " placeto (scene))
}|';\'|

(ArcVectorNode):-: {
  [poly: arc-edge-spline]
  with var (d) var (s) {
    irin ("axis:X influence:0.5 phase:0.0 smooth:true phys:true")
    thenplace var (s) with var (d)
  }
  irout ("Result: " placeto (s))
}|';\'|

(ArcVectorNode):-: {
  [poly: arc-edge-spline]
  with var (d) var (s) {
    irin ("axis:Y influence:0.4 phase:1.047 smooth:true phys:true")
    thenplace var (s) with var (d)
  }
  irout ("Result: " placeto (s))
}|';\'|

(ArcVectorNode):-: {
  [poly: arc-edge-spline]
  with var (d) var (s) {
    irin ("axis:Z influence:0.6 phase:2.094 smooth:true phys:true")
    thenplace var (s) with var (d)
  }
  irout ("Result: " placeto (s))
}|';\'|

(ArcPhysicsNode):-: {
  [net: physics-environment]
  with var (s) {
    irin ("gravity:9.81 wind:15 temp:72 humidity:60 pressure:14.7")
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';\'|

(ArcGridNode):-: {
  [poly: grid-integration]
  with var (s) {
    irin ("enabled:true xz:true xy:true zy:true arcToGrid:true")
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';\'|
"""

}

// MARK: - AshDocument for fileExporter
import UniformTypeIdentifiers

struct AshDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var content: String
    var filename: String

    init(content: String, filename: String) {
        self.content = content
        self.filename = filename
    }
    init(configuration: ReadConfiguration) throws {
        content = (try? String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8)) ?? ""
        filename = "untitled.ash"
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}
