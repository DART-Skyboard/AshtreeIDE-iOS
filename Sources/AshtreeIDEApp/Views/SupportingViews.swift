// ============================================================
//  SupportingViews.swift — Terminal, Files, Docs, Settings
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

// MARK: - Terminal View (LEATR App Runtime)

struct TerminalView: View {
    @EnvironmentObject var ide: IDEState
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack {
                Circle().fill(Color(hex: "#ff5f57")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "#febc2e")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "#28c840")).frame(width: 10, height: 10)
                Text("▶ LEATR APP RUNTIME")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00ffcc"))
                    .kerning(2)
                    .padding(.leading, 8)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#0d1117"))

            // Output area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        // Boot messages
                        TerminalLineView(text: "[SYS] ─────────────────────────────────────────", color: "#4a8a7a")
                        TerminalLineView(text: "[SYS] LEATR App Runtime v2.0", color: "#00ffcc")
                        TerminalLineView(text: "[SYS] © 2025 DART Meadow | Radical Deepscale LLC.", color: "#4a8a7a")
                        TerminalLineView(text: "[SYS] ─────────────────────────────────────────", color: "#4a8a7a")

                        ForEach(ide.terminalLines) { line in
                            TerminalLineView(text: line.text, color: line.color)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color(hex: "#0d1117"))
                .onChange(of: ide.terminalLines.count) { _ in
                    if let last = ide.terminalLines.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Input bar
            HStack(spacing: 0) {
                Text("ash ▸")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00ffcc"))
                    .padding(.leading, 12)
                TextField("type a command…", text: $input)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .accentColor(Color(hex: "#00ffcc"))
                    .focused($inputFocused)
                    .padding(.leading, 8)
                    .onSubmit { handleCommand(input); input = "" }
                Spacer()
                Button("⏎") { handleCommand(input); input = "" }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#00ffcc"))
                    .padding(.trailing, 12)
            }
            .frame(height: 44)
            .background(Color(hex: "#161b22"))
            .overlay(Divider().background(Color(hex: "#30363d")), alignment: .top)
        }
        .background(Color(hex: "#0d1117"))
    }

    func handleCommand(_ cmd: String) {
        let c = cmd.trimmingCharacters(in: .whitespaces).lowercased()
        ide.terminalLines.append(TerminalLine(text: "ash ▸ \(cmd)", color: "#00ffcc"))
        switch c {
        case "run":
            Task { await ide.buildAndRun() }
        case "clear":
            ide.terminalLines = []
        case "info":
            ide.terminalLines.append(TerminalLine(text: "  LEATR v2 · Ash Tree IDE · DART Meadow", color: "#8ab4cc"))
            ide.terminalLines.append(TerminalLine(text: "  Compiler Standard: (xa²√xa)±1 algebra", color: "#8ab4cc"))
        case "help":
            ide.terminalLines.append(TerminalLine(text: "  Commands: run · info · clear · exit · help", color: "#8ab4cc"))
        case "exit":
            ide.terminalLines.append(TerminalLine(text: "  Session ended.", color: "#4a8a7a"))
        default:
            ide.terminalLines.append(TerminalLine(text: "  Unknown command. Type 'help' for options.", color: "#ff9500"))
        }
    }
}

struct TerminalLineView: View {
    let text: String
    let color: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Color(hex: color))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Files Browser

struct FilesBrowserView: View {
    @EnvironmentObject var ide: IDEState
    @EnvironmentObject var github: GitHubService
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PROJECT FILES")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color("AshMid"))
                    .kerning(2)
                Spacer()
                Button { Task { isLoading = true; await github.loadFiles(); isLoading = false } } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                        .foregroundColor(Color("AshMid"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("AshLight"))
            .overlay(Divider(), alignment: .bottom)

            if isLoading {
                ProgressView("Loading…").padding()
            } else if github.files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36))
                        .foregroundColor(Color("AshMid").opacity(0.3))
                    Text("No .ash files yet")
                        .font(.system(size: 13))
                        .foregroundColor(Color("AshMid"))
                    Text("Save a script from the editor\nto see it here.")
                        .font(.system(size: 11))
                        .foregroundColor(Color("AshMid").opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(github.files) { file in
                    Button {
                        Task {
                            if let content = await github.readFile(path: file.path) {
                                ide.sourceCode = content
                                ide.currentFile = file.name
                                ide.selectedTab = .editor
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13))
                                .foregroundColor(Color("InnerCyan"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color("AshDark"))
                                Text(file.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color("AshMid").opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(Color("AshMid").opacity(0.3))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Docs View

struct DocsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("LEATR v2 COMPILER STANDARD")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("AshDark"))
                        .kerning(2)
                    Text("Lead Edge Ash Tree Reflex · © 2025 DART Meadow | Radical Deepscale LLC.")
                        .font(.system(size: 10))
                        .foregroundColor(Color("AshMid"))
                }

                DocSection(title: "SWITCH EQUATIONS", content: """
                    All syntax is wrapped in algebra that encodes/decodes each syntax pattern:

                    Encode (switch OPEN  0→1):  (xa²√xa) - 1
                    Decode (switch CLOSE 1→0):  (xa²√xa) + 1

                    This makes the algebra itself a variable placeholder that can be assigned
                    true/false when checking syntax for compilation.
                    """)

                DocSection(title: "NODE STRUCTURE", content: """
                    (NodeName):-: {           // Switch OPEN
                      {{env:MyProject}}       // Outer tag — environment isolation shell
                      [[owner:username]]      // Inner tag — script ownership identity
                      [poly: data-matrix]     // Poly container — math/physics isolated
                      [net: network-layer]    // Net tag — network syntax (log-iterative)
                      with
                        var (s)  // Data Set
                      {
                        irin ("Data: my input")
                        Maze                  // OOO Natural Tool #1
                        thenplace var (s) with var (s)
                      }
                      irout ("Result: " placeto (s))
                    }|';'|                    // Switch CLOSE
                    """)

                DocSection(title: "TAG SYSTEM", content: """
                    {{outer-tag}}   — Environment isolation shell (hardware frame)
                    [[inner-tag]]   — User script ownership. Double-tagging prevents
                                      cross-compilation between users on the same system.
                    [poly:...]      — Polynomial/physics container. Isolated from syntax —
                                      math/physics data cannot interfere with network code.
                    [net:...]       — Network syntax layer. Logarithmic iterative form.
                    """)

                DocSection(title: "ORDER OF OPERATIONS (OOO)", content: """
                    Natural Tools (1-7):
                    Maze · Puzzle · Envelope · Hammer · Stick · Knife · Scissors

                    Math/Physics (8-19):
                    Parentheses · Exponents · Multiplication · Division · Addition
                    Subtraction · Logarithm · Trigonometry · Temperature · Velocity
                    Pressure · Mass · Photosynthesis

                    Senses (AI):
                    Touch · Taste · Vision · Smell · Hear
                    """)

                DocSection(title: "PENDULUM NODE / BRPN", content: """
                    After compile, the Buoyancy Reflex Pendulum Node routes the result:

                    f = formation   (1.0 if outer-tags present, else 0.5)
                    r = reflex      (1.0 if inner-tags present, else 0.4)
                    p = performance (node_count / 5, capped 0.1–1.0)
                    frp = f × r × p
                    buoyancy = frp × √|frp|

                    Shell routing:
                    ≥ 0.76 → GEOLOGICAL  (high-formation)
                    ≥ 0.44 → MARITIME    (medium)
                    < 0.44 → AEROSPACE   (sparse)
                    """)

                DocSection(title: "KEYWORDS", content: """
                    irin · irout · thenplace · place · with · when · where
                    and · or · not · for · else · is · if · end
                    var · import · return · Research · Report
                    """)

                DocSection(title: "IMPORT SYNTAX", content: """
                    import (GLDrivers)         // Load 3D GL driver runtime
                    import (SentienceJournal)  // Load sentience journal module
                    import (NetworkLayer)      // Load network compiler layer
                    """)

                DocSection(title: "EXAMPLE — HELLO WORLD", content: """
                    {{env:HelloWorld}}
                    [[script:hello-v1]]

                    (HelloWorldNode):-: {
                      with
                        var (s)
                      {
                        irin ("Data: Hello, World!")
                        Maze
                        thenplace var (s) with var (s)
                      }
                      irout ("Result: " placeto (s))
                    }|';'|
                    """)
            }
            .padding(20)
        }
    }
}

struct DocSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color("AshMid"))
                .kerning(1.5)
            Text(content)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color("AshDark").opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(Color("AshLight"))
                .cornerRadius(8)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var github: GitHubService

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ACCOUNT").font(.system(size: 10, design: .monospaced))) {
                    if let s = github.session {
                        HStack {
                            Label(s.username, systemImage: "person.fill")
                            Spacer()
                            if s.accessToken.hasPrefix("apple-") {
                                Text("Apple").font(.caption).foregroundColor(.secondary)
                            } else if s.accessToken == "guest" {
                                Text("Guest").font(.caption).foregroundColor(.secondary)
                            } else {
                                Text("GitHub").font(.caption).foregroundColor(Color("InnerCyan"))
                            }
                        }
                        if github.repoReady {
                            Label("Ash-Tree-IDE-Projects created", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                        Button("Sign Out", role: .destructive) {
                            github.signOut(); dismiss()
                        }
                    }
                }

                Section(header: Text("COMPILER").font(.system(size: 10, design: .monospaced))) {
                    LabeledContent("Version", value: "LEATR v2.0")
                    LabeledContent("Switch Eq.", value: "(xa²√xa) ± 1")
                    LabeledContent("OOO Tools", value: "19 orders")
                    LabeledContent("Shell Types", value: "GEO · MAR · AERO")
                }

                Section(header: Text("ABOUT").font(.system(size: 10, design: .monospaced))) {
                    LabeledContent("App", value: "Ash Tree IDE")
                    LabeledContent("Standard", value: "Lead Edge Ash Tree Reflex")
                    LabeledContent("Author", value: "Justin Craig Venable")
                    LabeledContent("Company", value: "DART Meadow | Radical Deepscale LLC.")
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Color(hex:) extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 3:  (r,g,b,a) = ((int>>8)*17, (int>>4&0xF)*17, (int&0xF)*17, 255)
        case 6:  (r,g,b,a) = (int>>16, int>>8&0xFF, int&0xFF, 255)
        case 8:  (r,g,b,a) = (int>>24, int>>16&0xFF, int>>8&0xFF, int&0xFF)
        default: (r,g,b,a) = (0,0,0,255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
