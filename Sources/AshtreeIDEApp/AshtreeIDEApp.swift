// ============================================================
//  AshtreeIDEApp.swift — App entry point
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

@main
struct AshtreeIDEApp: App {

    @StateObject private var github  = GitHubService.shared
    @StateObject private var ideState = IDEState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(github)
                .environmentObject(ideState)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - IDE State (global observable)

final class IDEState: ObservableObject {
    @Published var sourceCode: String = defaultAsh
    @Published var compilerLogs: [CompilerLogEntry] = []
    @Published var terminalLines: [TerminalLine] = []
    @Published var currentFile: String = "untitled.ash"
    @Published var isCompiling = false
    @Published var isSaving = false
    @Published var brpnResult: BRPNResult?
    @Published var selectedTab: AppTab = .editor
    @Published var showFileBrowser = false
    @Published var showSettings = false
    @Published var showSplash = true

    let compiler = LeatrCompiler()

    @MainActor
    func buildAndRun(netMode: Bool = false) async {
        isCompiling = true
        terminalLines = []
        compilerLogs = []

        let result = compiler.compile(source: sourceCode, netMode: netMode)
        compilerLogs = result.logs
        brpnResult   = result.brpn

        // Mirror logs to terminal
        terminalLines.append(TerminalLine(text: "[SYS] LEATR Compiler v2.0", color: "#00ffcc"))
        terminalLines.append(TerminalLine(text: "[SYS] Compiled: \(result.ast.nodes.count) node(s) · Env: local", color: "#8ab4cc"))
        terminalLines.append(TerminalLine(text: "[SYS] Shell: \(result.brpn.shell) · Buoyancy: \(String(format:"%.4f", result.brpn.buoyancy))", color: "#a78bfa"))
        for node in result.ast.nodes {
            terminalLines.append(TerminalLine(text: "ash ▸ run", color: "#00ffcc"))
            terminalLines.append(TerminalLine(text: "  → \(node.name) executed.", color: "#ffffff"))
            if let irin = node.irinValue {
                terminalLines.append(TerminalLine(text: "  irin: \(irin)", color: "#4a8a7a"))
            }
            if let irout = node.iroutValue {
                terminalLines.append(TerminalLine(text: "  irout: \(irout)", color: "#4a8a7a"))
            }
        }
        if result.ast.nodes.isEmpty {
            terminalLines.append(TerminalLine(text: "  No executable nodes found.", color: "#8ab4cc"))
        }
        isCompiling = false
    }
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let color: String
}

enum AppTab: String, CaseIterable {
    case editor   = "Editor"
    case terminal = "Terminal"
    case files    = "Files"
    case docs     = "Docs"
}

// MARK: - Default .ash script

let defaultAsh = """
// Ash Tree IDE · LEATR v2 · © 2025 DART Meadow | Radical Deepscale LLC.
// Compiler Standard: Switch equations (xa²√xa)±1 wrap every syntax pattern.
// {{outer}} = env isolation · [[inner]] = script identity
// [poly:] = math/physics · [net:] = network layer

{{env:MyProject}}
[[script:my-first-node]]

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
