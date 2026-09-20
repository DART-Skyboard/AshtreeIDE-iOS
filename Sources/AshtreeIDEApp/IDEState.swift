// IDEState.swift v2 — Fixed repo→files nav, 25 OOO, BRPN per-tool shells
// Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import Combine

public enum IDETab: String, CaseIterable {
    case editor = "Editor", output = "Output", terminal = "Terminal", interface = "Interface"
    case files = "Files", maze = "Maze", mindmap = "Ash Map", docs = "Docs", help = "Help"
    public var icon: String {
        switch self {
        case .editor:    return "chevron.left.forwardslash.chevron.right"
        case .output:    return "text.alignleft"
        case .terminal:  return "terminal"
        case .interface: return "macwindow"
        case .files:     return "folder"
        case .maze:      return "puzzlepiece"
        case .mindmap:   return "brain.head.profile"
        case .docs:      return "book"
        case .help:      return "questionmark.circle"
        }
    }
}

@MainActor
public final class IDEState: ObservableObject {
    @Published public var sourceCode = IDEDefaults.defaultScript
    @Published public var currentFile = "untitled.ash"
    @Published public var isDirty = false
    @Published public var exportFileToDevice = false

    // ── Open-file tabs — every file loaded via openTab() gets a real
    // tab; switching is instant with buffers kept in memory. sourceCode/
    // currentFile above stay in sync with the ACTIVE tab, so every
    // existing call site that reads them keeps working unmodified. ──
    public struct OpenTab: Identifiable, Equatable {
        public let id = UUID()
        public var name: String
        public var content: String
        public var isDirty: Bool = false
    }
    @Published public var openTabs: [OpenTab] = []
    @Published public var activeTabId: UUID? = nil

    /// Opens (or switches to, if already open) a file as a real tab.
    /// This is the one place all file-load call sites should route
    /// through so the tab strip always reflects what's actually open.
    public func openTab(name: String, content: String) {
        saveActiveTabContent()
        if let idx = openTabs.firstIndex(where: { $0.name == name }) {
            activeTabId = openTabs[idx].id
        } else {
            let tab = OpenTab(name: name, content: content)
            openTabs.append(tab)
            activeTabId = tab.id
        }
        sourceCode = content
        currentFile = name
        isDirty = false
        selectedTab = .editor
        IDELanguageStore.shared.setEnvFromFilename(name)
    }

    public func switchTab(to id: UUID) {
        guard id != activeTabId, let tab = openTabs.first(where: { $0.id == id }) else { return }
        saveActiveTabContent()
        activeTabId = id
        sourceCode = tab.content
        currentFile = tab.name
        isDirty = tab.isDirty
        IDELanguageStore.shared.setEnvFromFilename(tab.name)
    }

    public func closeTab(_ id: UUID) {
        guard let idx = openTabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeTabId == id
        openTabs.remove(at: idx)
        if openTabs.isEmpty {
            activeTabId = nil
            return
        }
        if wasActive {
            let nextIdx = min(idx, openTabs.count - 1)
            switchTab(to: openTabs[nextIdx].id)
        }
    }

    /// Call before switching away from the active tab so in-progress
    /// edits aren't lost — mirrors the web app's saveActiveTabContent.
    public func saveActiveTabContent() {
        guard let id = activeTabId, let idx = openTabs.firstIndex(where: { $0.id == id }) else { return }
        openTabs[idx].content = sourceCode
        openTabs[idx].isDirty = isDirty
    }

    // Files synced to repo — paths that auto-push on every save
    @Published public var syncedFiles: Set<String> = []
    // Repo context for sync
    public var syncRepoOwner: String = ""
    public var syncRepoName:  String = ""
    @Published public var selectedTab: IDETab = .editor
    @Published public var isCompiling = false
    @Published public var isSaving = false
    @Published public var showDrawer = false
    @Published public var drawerTab: DrawerTab = .files

    // File source switcher
    public enum FileSource: String, CaseIterable {
        case examples = "Examples", repository = "Repo Files", local = "Local"
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
    public let examples: [(name: String, icon: String, code: String, lang: String)] = IDEDefaults.examples

    // MARK: - Compile

    public func buildAndRun(netMode: Bool = false) async {
        isCompiling = true
        compiler.compile(source: sourceCode, netMode: netMode)
        // Build & Run genuinely runs the program, not just compiles it —
        // same as typing "run" in the terminal — so Terminal always
        // reflects a program that has actually executed by the time the
        // build finishes.
        compiler.handleTerminalCommand("run", source: sourceCode)
        try? await Task.sleep(nanoseconds: 100_000_000)
        isCompiling = false
        selectedTab = .output
    }

    public func autoLoadDefs() async { await compiler.autoLoadDefs() }

    // MARK: - File operations

    public func loadExample(_ code: String, name: String, lang: String = "ash") {
        let ext = IDELanguageEnv.find(id: lang).ext
        let fname = name.hasSuffix(ext) ? name : name + ext
        openTab(name: fname, content: code)
    }

    public func newFile() {
        // Generate unique filename — check saved files AND currently
        // open-but-unsaved tabs, so a fresh tab never collides with
        // one already open (e.g. the very first untitled.ash).
        var n = 1; var fname = "untitled.ash"
        while localFiles.contains(fname) || openTabs.contains(where: { $0.name == fname }) {
            fname = "untitled_\(n).ash"; n += 1
        }
        let initialContent = "// \(fname)\n// Ash Edge Language · LEATR v2\n{{env:MyProject}}\n[[script:new-script]]\n\n"
        openTab(name: fname, content: initialContent)
        // Persist immediately — guaranteed unique name
        UserDefaults.standard.set(initialContent, forKey: "ide_local_\(fname)")
        localFiles.append(fname)
        UserDefaults.standard.set(localFiles, forKey: "ide_local_file_list")
        UserDefaults.standard.synchronize()
        // Don't close drawer — user stays in local tab to see their new file
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
        await MainActor.run { IDELanguageStore.shared.setEnvFromFilename(file.name) }
        let username = KeychainHelper.load(key: "ide_github_username") ?? ""
        let repo = currentRepo?.name ?? ""
        let owner = currentRepo.map { String($0.fullName.split(separator: "/").first ?? Substring(username)) } ?? username
        let content = (try? await IDEGitHubClient.shared.readFile(owner: owner, repo: repo, path: file.path)) ?? ""
        openTab(name: file.name, content: content)
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
        guard !currentFile.isEmpty else { return }
        let key = "ide_local_\(currentFile)"
        UserDefaults.standard.set(sourceCode, forKey: key)
        if !localFiles.contains(currentFile) { localFiles.append(currentFile) }
        UserDefaults.standard.set(localFiles, forKey: "ide_local_file_list")
        UserDefaults.standard.synchronize()
        isDirty = false
        loadLocalFiles()
        // Auto-sync to repo if this file is toggled for sync
        let matchedSync = syncedFiles.first { $0.hasSuffix(currentFile) }
        if let syncPath = matchedSync, !syncRepoOwner.isEmpty, !syncRepoName.isEmpty {
            let owner = syncRepoOwner; let repo = syncRepoName; let path = syncPath; let src = sourceCode
            Task {
                try? await IDEGitHubClient.shared.writeFile(
                    owner: owner, repo: repo, path: path,
                    content: src, message: "Ash Tree IDE: auto-sync \(path)")
            }
        }
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
            openTab(name: name, content: content)
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
    public static let examples: [(name: String, icon: String, code: String, lang: String)] = [
        ("Hello World",   "hand.wave",   helloWorld, "ash"),
        ("Counter App",   "plusminus",   counterApp, "ash"),
        ("Physics Sim",   "atom",        physicsSim, "ash"),
        ("Network Node",  "network",     networkNode, "ash"),
        ("Autumn Core",   "leaf",        autumnCore, "ash"),
        ("3D Animation",  "cube",        ash3D, "ash"),
        ("Neural Scene",  "brain.head.profile", neuralScene, "ash"),
        ("Arc Edge Vector","waveform",          arcEdgeVector, "ash"),
        ("Reckon Calculator (Ash)", "function", reckonCalculatorAsh, "ash"),
        ("Reckon Calculator (C++)", "chevron.left.forwardslash.chevron.right", reckonCalculatorConsoleCpp, "cpp"),
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

    // ── Reckon Calculator (Ash) — a real, working calculator using the
    // real Ash runtime's Research(expr) capability: set expr <formula> in
    // the terminal (or tap the real keypad in the Interface tab) then run
    // to genuinely evaluate it. Matches the web app's example exactly. ──
    static let reckonCalculatorAsh = """
// RECKON CALCULATOR — a real, working calculator in Ash Edge Language
// Build & Run, then in the Terminal:
//   set expr 3+4*2       (set the formula - any + - * / ^ expression,
//                          plus sin(x) cos(x) tan(x) sqrt(x) ln(x)
//                          log(x) pi e - angles in degrees)
//   run                  (evaluates expr for real and prints the result)
// Or open the Interface tab for a real keypad - tap digits/operators,
// press "=" to evaluate. Both the terminal and the Interface keypad
// drive the SAME real evaluator (Research below), so anything you can
// type in one, you can tap in the other.
{{env:ReckonCalculator}}
[[script:reckon-calc-v1]]
[poly: expression-tree]

(CalculatorNode):-: {
  {{env:ReckonCalculator}}
  with var (expr) var (s) {
    irin ("Data: expr=0")
    Research (expr)
    thenplace var (s) with var (s)
  }
  irout ("Result: " placeto (s))
}|';\'|
"""

    // ── Reckon Calculator (C++, console) — genuinely compiles and runs
    // in the real Judge0/Piston-backed C++ path (which, unlike the web
    // app's local WASM compiler, has real exception-handling support —
    // this is the same real recursive-descent evaluator, just written
    // with its original try/catch/throw error handling since iOS's C++
    // execution doesn't hit the wall the browser compiler does). ──
    static let reckonCalculatorConsoleCpp = #"""
#include <cctype>
#include <cmath>
#include <cstdio>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

static const double PI = std::acos(-1.0);
static const double EULER = std::exp(1.0);

enum class Kind { Num, Op, Lp, Rp, Fn, Const, Post };
struct Tok { Kind kind; std::string v; };
struct CalcError : std::runtime_error { using std::runtime_error::runtime_error; };

static double tidy(double n) {
    if (!std::isfinite(n) || n == 0.0) return n;
    const double nearest = std::round(n);
    if (std::fabs(n - nearest) <= std::fabs(n) * 1e-12) return nearest;
    return n;
}
static std::string fmt(double n) {
    if (!std::isfinite(n)) return "Error";
    n = tidy(n);
    if (n == 0.0) return "0";
    char buf[64];
    std::snprintf(buf, sizeof(buf), "%.12g", n);
    return std::string(buf);
}
static double factorial(double n) {
    if (n < 0.0 || std::floor(n) != n) return std::numeric_limits<double>::quiet_NaN();
    if (n > 170.0) return std::numeric_limits<double>::infinity();
    double r = 1.0;
    for (int i = 2; i <= (int)n; ++i) r *= i;
    return r;
}
static double nthRoot(double n, double x) {
    if (n == 0.0) return std::numeric_limits<double>::quiet_NaN();
    if (x < 0.0) {
        if (std::floor(n) == n && std::fmod(std::fabs(n), 2.0) == 1.0) return -std::pow(-x, 1.0 / n);
        return std::numeric_limits<double>::quiet_NaN();
    }
    return std::pow(x, 1.0 / n);
}
static double applyFn(const std::string& name, double n, bool deg) {
    const double rad = deg ? n * PI / 180.0 : n;
    if (name == "sin") return std::sin(rad);
    if (name == "cos") return std::cos(rad);
    if (name == "tan") return std::tan(rad);
    if (name == "ln") return std::log(n);
    if (name == "exp") return std::exp(n);
    if (name == "log") return std::log10(n);
    if (name == "sqrt") return std::sqrt(n);
    if (name == "cbrt") return std::cbrt(n);
    if (name == "abs") return std::fabs(n);
    return std::numeric_limits<double>::quiet_NaN();
}
static bool isFnName(const std::string& w) {
    static const char* names[] = {"sin","cos","tan","ln","exp","log","sqrt","cbrt","abs"};
    for (auto n : names) if (w == n) return true;
    return false;
}
static std::vector<Tok> tokenize(const std::string& src) {
    std::vector<Tok> out;
    size_t i = 0;
    while (i < src.size()) {
        char c = src[i];
        if (std::isspace((unsigned char)c)) { ++i; continue; }
        if (std::isdigit((unsigned char)c) || c == '.') {
            size_t j = i;
            while (j < src.size() && (std::isdigit((unsigned char)src[j]) || src[j] == '.')) ++j;
            out.push_back({Kind::Num, src.substr(i, j - i)});
            i = j; continue;
        }
        if (c == '(') { out.push_back({Kind::Lp, "("}); ++i; continue; }
        if (c == ')') { out.push_back({Kind::Rp, ")"}); ++i; continue; }
        if (c == '+' || c == '-' || c == '*' || c == '/' || c == '^') { out.push_back({Kind::Op, std::string(1, c)}); ++i; continue; }
        if (c == '!' || c == '%') { out.push_back({Kind::Post, std::string(1, c)}); ++i; continue; }
        if (std::isalpha((unsigned char)c)) {
            size_t j = i;
            while (j < src.size() && std::isalnum((unsigned char)src[j])) ++j;
            std::string word = src.substr(i, j - i);
            if (word == "pi" || word == "e") { out.push_back({Kind::Const, word}); i = j; continue; }
            if (word == "nrt") { out.push_back({Kind::Op, "r"}); i = j; continue; }
            if (isFnName(word)) { out.push_back({Kind::Fn, word}); i = j; continue; }
            throw CalcError("Unknown token '" + word + "'");
        }
        throw CalcError(std::string("Unexpected character '") + c + "'");
    }
    return out;
}
class Parser {
public:
    const std::vector<Tok>& tokens;
    bool deg; size_t i = 0;
    Parser(const std::vector<Tok>& t, bool d) : tokens(t), deg(d) {}
    const Tok* peek() const { return i < tokens.size() ? &tokens[i] : nullptr; }
    bool isOp(const char* v) const { const Tok* t = peek(); return t && t->kind == Kind::Op && t->v == v; }
    bool isPrimaryStart() const {
        const Tok* t = peek(); if (!t) return false;
        return t->kind == Kind::Num || t->kind == Kind::Const || t->kind == Kind::Fn || t->kind == Kind::Lp;
    }
    const Tok& consume() { if (i >= tokens.size()) throw CalcError("Syntax error"); return tokens[i++]; }
    double parseExpr() {
        double v = parseTerm();
        while (isOp("+") || isOp("-")) { const std::string o = consume().v; const double r = parseTerm(); v = (o == "+") ? v + r : v - r; }
        return v;
    }
    double parseTerm() {
        double v = parsePower();
        for (;;) {
            if (isOp("*") || isOp("/")) {
                const std::string o = consume().v; const double r = parsePower();
                if (o == "/") { if (r == 0.0) throw CalcError("Cannot divide by zero"); v /= r; } else v *= r;
            } else if (isPrimaryStart()) { v *= parsePower(); } else break;
        }
        return v;
    }
    double parsePower() {
        const double v = parseUnary();
        if (isOp("^")) { consume(); return std::pow(v, parsePower()); }
        if (isOp("r")) { consume(); return nthRoot(v, parsePower()); }
        return v;
    }
    double parseUnary() {
        if (isOp("-")) { consume(); return -parseUnary(); }
        if (isOp("+")) { consume(); return parseUnary(); }
        return parsePostfix();
    }
    double parsePostfix() {
        double v = parsePrimary();
        while (peek() && peek()->kind == Kind::Post) {
            const std::string p = consume().v;
            if (p == "!") { v = factorial(v); if (std::isnan(v)) throw CalcError("Invalid input"); } else v = v / 100.0;
        }
        return v;
    }
    double parsePrimary() {
        const Tok* t = peek();
        if (!t) throw CalcError("Syntax error");
        if (t->kind == Kind::Num) { consume(); return std::stod(t->v); }
        if (t->kind == Kind::Const) { consume(); return t->v == "pi" ? PI : EULER; }
        if (t->kind == Kind::Fn) {
            const std::string name = consume().v;
            double arg;
            if (peek() && peek()->kind == Kind::Lp) {
                consume(); arg = parseExpr();
                if (!peek() || peek()->kind != Kind::Rp) throw CalcError("Mismatched parentheses");
                consume();
            } else arg = parseUnary();
            const double r = applyFn(name, arg, deg);
            if (std::isnan(r)) throw CalcError("Invalid input");
            return r;
        }
        if (t->kind == Kind::Lp) {
            consume(); const double v = parseExpr();
            if (!peek() || peek()->kind != Kind::Rp) throw CalcError("Mismatched parentheses");
            consume(); return v;
        }
        throw CalcError("Syntax error");
    }
};
static double evaluate(const std::vector<Tok>& tokens, bool deg) {
    Parser p(tokens, deg);
    const double v = p.parseExpr();
    if (p.i != tokens.size()) throw CalcError("Syntax error");
    return tidy(v);
}
int main() {
    std::cout << "Reckon (console)\n";
    std::cout << "Real tokenizer -> recursive-descent parser -> evaluator.\n\n";
    const char* demo[] = { "2^8", "3 nrt (8+19)", "(1+2)*(3+4)^2", "sqrt(49)", "sin(30)", "5!", "10/0" };
    for (const char* expr : demo) {
        std::cout << expr << " = ";
        try {
            auto tokens = tokenize(expr);
            std::cout << fmt(evaluate(tokens, true)) << "\n";
        } catch (const std::exception& ex) {
            std::cout << "Error: " << ex.what() << "\n";
        }
    }
    return 0;
}
"""#

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
