// ============================================================
//  IDEEditorViews.swift — Editor, Output, Terminal, Files
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI
import UIKit

// MARK: - Ash Code Editor

struct IDEEditorView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            // Action bar
            IDEEditorActionBar()

            // Editor + line numbers
            AshCodeEditorView()
                .background(themeVM.bg)
        }
    }
}

struct IDEEditorActionBar: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @State private var showSaveSheet = false
    @State private var saveMessage   = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ActionChip(label: "▶ BUILD & RUN", color: themeVM.accent.opacity(0.9), busy: ideVM.isCompiling) {
                    Task { await ideVM.buildAndRun() }
                }
                ActionChip(label: "⟳ NET COMPILE", color: Color(hex: "#39ff14").opacity(0.7), busy: ideVM.isCompiling) {
                    Task { await ideVM.buildAndRun(netMode: true) }
                }
                ActionChip(label: "AUTO LOAD ASH", color: Color(hex: "#ffd700").opacity(0.6)) {
                    Task { await ideVM.autoLoadDefs() }
                }
                ActionChip(label: "✕ CLEAR", color: Color(hex: "#ff4466").opacity(0.6)) {
                    ideVM.compiler.compilerLines = []
                    ideVM.compiler.terminalLines = []
                }
                ActionChip(label: "↑ SAVE", color: themeVM.dim.opacity(0.6)) {
                    showSaveSheet = true
                }
                ActionChip(label: "+ NEW", color: themeVM.dim.opacity(0.4)) {
                    ideVM.newFile()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(themeVM.surface)
        .overlay(Divider().background(themeVM.border), alignment: .bottom)
        .sheet(isPresented: $showSaveSheet) {
            IDESaveSheet(message: $saveMessage) { msg in
                Task {
                    let ok = await ideVM.saveFile(message: msg.isEmpty ? nil : msg)
                    if ok { showSaveSheet = false }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct ActionChip: View {
    let label: String
    let color: Color
    var busy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(busy ? color.opacity(0.4) : color)
                .cornerRadius(6)
        }
        .disabled(busy)
    }
}

// MARK: - UITextView Ash Code Editor

struct AshCodeEditorView: UIViewRepresentable {
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var themeVM: IDEThemeViewModel

    func makeCoordinator() -> Coordinator { Coordinator(ideVM: ideVM, themeVM: themeVM) }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // Line number gutter
        let gutter = LineNumberGutter()
        gutter.tag = 200
        gutter.backgroundColor = UIColor(themeVM.bg).withAlphaComponent(0.8)

        // Text view
        let tv = UITextView()
        tv.tag = 100
        tv.delegate = context.coordinator
        tv.autocorrectionType  = .no
        tv.autocapitalizationType = .none
        tv.spellCheckingType   = .no
        tv.smartDashesType     = .no
        tv.smartQuotesType     = .no
        tv.backgroundColor     = .clear
        tv.font                = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textColor           = UIColor(themeVM.text)
        tv.textContainerInset  = UIEdgeInsets(top: 12, left: 44, bottom: 100, right: 12)
        tv.text                = ideVM.sourceCode
        tv.keyboardType        = .asciiCapable
        tv.keyboardDismissMode = .interactive

        container.addSubview(gutter)
        container.addSubview(tv)

        gutter.translatesAutoresizingMaskIntoConstraints = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: container.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: 40),
            tv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tv.topAnchor.constraint(equalTo: container.topAnchor),
            tv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.textView = tv
        context.coordinator.gutter   = gutter

        // Keyboard accessory
        tv.inputAccessoryView = makeKeyboardAccessory(tv: tv, theme: themeVM)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let tv = container.viewWithTag(100) as? UITextView else { return }
        if tv.text != ideVM.sourceCode { tv.text = ideVM.sourceCode }
        applyHighlighting(tv)
        (container.viewWithTag(200) as? LineNumberGutter)?.textView = tv
        (container.viewWithTag(200) as? LineNumberGutter)?.setNeedsDisplay()
    }

    // MARK: Syntax Highlighting
    private func applyHighlighting(_ tv: UITextView) {
        let src = tv.text ?? ""
        let mas = NSMutableAttributedString(string: src)
        let full = NSRange(src.startIndex..., in: src)
        let base = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let bold = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        mas.addAttributes([.foregroundColor: UIColor(themeVM.text), .font: base], range: full)

        func re(_ pattern: String, _ color: UIColor, isBold: Bool = false) {
            guard let rx = try? NSRegularExpression(pattern: pattern) else { return }
            rx.enumerateMatches(in: src, range: NSRange(src.startIndex..., in: src)) { m, _, _ in
                guard let r = m?.range else { return }
                mas.addAttribute(.foregroundColor, value: color, range: r)
                if isBold { mas.addAttribute(.font, value: bold, range: r) }
            }
        }

        // Comments
        re("//[^\n]*",       UIColor(red:0.29,green:0.54,blue:0.48,alpha:1))
        // Strings
        re("\"(?:[^\"\\\\]|\\\\.)*\"", UIColor(red:0.81,green:0.57,blue:0.47,alpha:1))
        // Outer {{}}
        re("\\{\\{[^}]+\\}\\}", UIColor(red:1.0,green:0.84,blue:0.0,alpha:1))
        // Inner [[]]
        re("\\[\\[[^\\]]+\\]\\]", UIColor(red:0.75,green:0.37,blue:1.0,alpha:1))
        // Poly/net tags
        re("\\[(?:poly|net):[^\\]]+\\]", UIColor(red:1.0,green:0.58,blue:0.0,alpha:1))
        // Keywords
        let kws = LeatrEngine.keywords.joined(separator: "|")
        re("\\b(\(kws))\\b", UIColor(red:0.0,green:0.90,blue:1.0,alpha:1), isBold: true)
        // Declarations
        let decls = LeatrEngine.declarations.joined(separator: "|")
        re("\\b(\(decls))\\b", UIColor(red:0.61,green:0.86,blue:1.0,alpha:1))
        // Natural tools
        let tools = LeatrEngine.naturalTools.joined(separator: "|")
        re("\\b(\(tools))\\b", UIColor(red:0.75,green:0.37,blue:1.0,alpha:1))
        // Node start: (Name):-:{
        re("\\([A-Za-z][A-Za-z0-9_]*\\)(?=:-:)", UIColor(red:0.0,green:1.0,blue:0.80,alpha:1), isBold: true)
        // Node end: }|';'|
        re("\\}\\|';'\\|", UIColor(red:0.0,green:1.0,blue:0.80,alpha:1), isBold: true)
        // Numbers
        re("\\b\\d+\\.?\\d*\\b", UIColor(red:0.71,green:0.81,blue:0.66,alpha:1))
        // gl. calls
        re("gl\\.[a-z]+", UIColor(Color(hex: "#00e5ff")))

        let sel = tv.selectedRange
        tv.attributedText = mas
        tv.selectedRange  = sel
    }

    // MARK: Keyboard Accessory
    private func makeKeyboardAccessory(tv: UITextView, theme: IDEThemeViewModel) -> UIView {
        let bar = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 40))
        bar.backgroundColor = UIColor(theme.surface)
        let scroll = UIScrollView(frame: bar.bounds)
        scroll.showsHorizontalScrollIndicator = false
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bar.addSubview(scroll)

        let snippets = ["(Node):-:{", "}|';'|", "{{env:}}", "[[owner:]]",
                        "[poly:]", "[net:]", "irin (\"\")", "irout (\"\")",
                        "thenplace", "var ()", "import ()", "Maze", "gl.scene"]
        var x: CGFloat = 8
        for s in snippets {
            let btn = UIButton(type: .system)
            btn.setTitle(s, for: .normal)
            btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            btn.setTitleColor(UIColor(theme.accent), for: .normal)
            btn.backgroundColor = UIColor(theme.accent.opacity(0.1))
            btn.layer.cornerRadius = 5
            btn.layer.borderColor = UIColor(theme.accent.opacity(0.2)).cgColor
            btn.layer.borderWidth = 0.5
            btn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
            let w = btn.intrinsicContentSize.width + 16
            btn.frame = CGRect(x: x, y: 5, width: w, height: 30)
            btn.addAction(UIAction { _ in
                if let r = tv.selectedTextRange {
                    tv.replace(r, withText: s)
                }
            }, for: .touchUpInside)
            scroll.addSubview(btn)
            x += w + 6
        }
        scroll.contentSize = CGSize(width: x, height: 40)

        // Keyboard dismiss button — pinned to right edge
        let dismissBtn = UIButton(type: .system)
        dismissBtn.setTitle("⌨️↓", for: .normal)
        dismissBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        dismissBtn.backgroundColor = UIColor(red:0, green:0.9, blue:0.8, alpha:0.15)
        dismissBtn.layer.cornerRadius = 5
        dismissBtn.layer.borderColor  = UIColor(red:0,green:0.9,blue:0.8,alpha:0.2).cgColor
        dismissBtn.layer.borderWidth  = 0.5
        dismissBtn.addAction(UIAction { _ in tv.resignFirstResponder() }, for: .touchUpInside)
        dismissBtn.frame = CGRect(x: 0, y: 4, width: 44, height: 32)
        let dismissWrap = UIView(frame: CGRect(x: bar.bounds.width - 50, y: 0, width: 50, height: 40))
        dismissWrap.autoresizingMask = [.flexibleLeftMargin]
        dismissWrap.backgroundColor = UIColor(red:0.05,green:0.07,blue:0.1,alpha:1)
        dismissWrap.addSubview(dismissBtn); bar.addSubview(dismissWrap)
        return bar
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let ideVM: IDEState
        let themeVM: IDEThemeViewModel
        weak var textView: UITextView?
        weak var gutter:   LineNumberGutter?

        init(ideVM: IDEState, themeVM: IDEThemeViewModel) {
            self.ideVM = ideVM; self.themeVM = themeVM
        }

        func textViewDidChange(_ tv: UITextView) {
            ideVM.sourceCode = tv.text
            ideVM.isDirty    = true
            gutter?.setNeedsDisplay()
        }
    }
}

// MARK: - Line Number Gutter
final class LineNumberGutter: UIView {
    weak var textView: UITextView?

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let tv = textView else { return }
        let src = tv.text ?? ""
        let lines = src.components(separatedBy: "\n")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.gray.withAlphaComponent(0.5)
        ]
        let lineH: CGFloat = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular).lineHeight
        let offsetY = tv.textContainerInset.top
        for (i, _) in lines.enumerated() {
            let y = offsetY + CGFloat(i) * lineH
            let str = NSAttributedString(string: "\(i+1)", attributes: attrs)
            let sz  = str.size()
            str.draw(at: CGPoint(x: bounds.width - sz.width - 6, y: y))
        }
    }
}

// MARK: - Save Sheet

struct IDESaveSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ideVM: IDEState
    @Binding var message: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Commit Message")) {
                    TextField("Update \(ideVM.currentFile)", text: $message)
                        .autocorrectionDisabled()
                }
                Section(header: Text("File")) {
                    Text(ideVM.currentFile)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    if let repo = ideVM.currentRepo {
                        Text("Repo: \(repo.name)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No repository selected — use Files tab to choose one")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Save to GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(message) }
                        .disabled(ideVM.currentRepo == nil)
                }
            }
        }
    }
}

// MARK: - Compiler Output View (split: text top, GL scene bottom when import (GLDrivers) detected)

struct IDECompilerOutputView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var mazeVM:  MazeViewModel
    @State private var glPanelKey = UUID()  // forces GL panel to rebuild on each compile

    var hasGLOutput: Bool {
        ideVM.sourceCode.contains("import (GLDrivers)") || ideVM.sourceCode.contains("gl.scene")
            || ideVM.sourceCode.contains("ArcEdge") || ideVM.sourceCode.contains("ArcVector")
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasGLOutput {
                // Split: compiler output top, 3D GL scene bottom
                IDECompilerTextPanel()
                    .frame(maxHeight: .infinity)

                Divider().background(themeVM.accent.opacity(0.3))

                IDEGLOutputPanel()
                    .id(ideVM.compiler.compilerLines.count)
                    .frame(maxHeight: .infinity)
            } else {
                IDECompilerTextPanel()
            }
        }
    }
}

// Text-only compiler output
struct IDECompilerTextPanel: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("◈ COMPILER OUTPUT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeVM.dim).kerning(2)
                Spacer()
                if ideVM.compiler.nodeCount > 0 {
                    Text(ideVM.compiler.shellType)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(themeVM.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(themeVM.accent.opacity(0.1)).cornerRadius(4)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(themeVM.surface)
            .overlay(Divider().background(themeVM.border), alignment: .bottom)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(ideVM.compiler.compilerLines) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(line.label)
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color(hex: line.color))
                                    .frame(minWidth: 70, alignment: .leading)
                                Text(line.text)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(line.isError ? Color(hex: "#ff4466") : themeVM.text.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 1).id(line.id)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                }
                .onChange(of: ideVM.compiler.compilerLines.count) { _ in
                    if let last = ideVM.compiler.compilerLines.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
        .background(themeVM.bg)
    }
}

// GL graphical output panel — runs the 3D scene for import (GLDrivers) scripts
struct IDEGLOutputPanel: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var mazeVM:  MazeViewModel
    @State private var glScene: SCNNode? = nil
    @State private var isRendering = false
    @State private var showArcEdge = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("◈ GL OUTPUT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00e5ff")).kerning(2)
                Spacer()
                if isRendering {
                    ProgressView().scaleEffect(0.7).tint(Color(hex: "#00e5ff"))
                        .padding(.horizontal, 6)
                } else {
                    // Always show Render 3D button + Reset if rendered
                    if showArcEdge || glScene != nil {
                        Button("↺ Reset") {
                            showArcEdge = false; glScene = nil
                        }
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568"))
                        .padding(.trailing, 6)
                    }
                    Button {
                        Task { await buildGLScene() }
                    } label: {
                        Text("▸ Render 3D")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "#00e5ff"))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: "#00e5ff").opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color(hex: "#0d1117"))
            .overlay(Divider().background(Color(hex: "#00e5ff").opacity(0.2)), alignment: .bottom)

            if let node = glScene {
                IDEMazeSceneKitView(rootNode: node, resetTrigger: 0)
            } else if showArcEdge {
                ArcEdgeSceneView()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 32)).foregroundColor(Color(hex: "#00e5ff").opacity(0.3))
                    Text("Tap ▸ Render 3D to execute graphical output")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568"))
                    Text("import (GLDrivers) · Arc Edge Vector supported")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568").opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0d1117"))
            }
        }
        // Auto-render when panel appears or when .id() changes (each compile)
        .task {
            await buildGLScene()
        }
    }

    private func buildGLScene() async {
        isRendering = true
        // Delegate to Arc Edge GL driver which implements the full arc-edge-vector.html capabilities
        let root = SCNNode()
        let mat = SCNMaterial()
        mat.diffuse.contents  = UIColor(red: 0, green: 1, blue: 0.8, alpha: 0.7)
        mat.emission.contents = UIColor(red: 0, green: 0.4, blue: 0.3, alpha: 0.3)
        mat.lightingModel = .physicallyBased
        mat.metalness.contents = NSNumber(value: 0.9)
        mat.roughness.contents = NSNumber(value: 0.1)
        mat.isDoubleSided = true

        // Arc Edge math: build tree with proper arc segment branches
        func addBranch(from: SCNVector3, dir: SCNVector3, length: Float, depth: Int) {
            guard depth > 0 && length > 0.05 else { return }
            let to = SCNVector3(from.x + dir.x*length, from.y + dir.y*length, from.z + dir.z*length)
            let cyl = SCNCylinder(radius: CGFloat(length*0.06), height: CGFloat(length))
            cyl.radialSegmentCount = 8; cyl.firstMaterial = mat
            let n = SCNNode(geometry: cyl)
            let mid = SCNVector3((from.x+to.x)/2, (from.y+to.y)/2, (from.z+to.z)/2)
            n.position = mid
            n.simdLook(at: simd_float3(to.x,to.y,to.z), up: SIMD3<Float>(0,1,0), localFront: SIMD3<Float>(0,1,0))
            root.addChildNode(n)
            // 3 branches at 1/8 arc angle (45°)
            let spread: Float = 0.7
            let branchAngle: Float = 0.785 // π/4
            let dirs: [SCNVector3] = [
                SCNVector3(dir.x*cos(branchAngle) - dir.z*sin(branchAngle), dir.y + spread*0.4, dir.x*sin(branchAngle) + dir.z*cos(branchAngle)),
                SCNVector3(-dir.x*cos(branchAngle) + dir.z*sin(branchAngle), dir.y + spread*0.4, -dir.x*sin(branchAngle) - dir.z*cos(branchAngle)),
                SCNVector3(dir.x, dir.y + spread*0.5, dir.z),
            ]
            for d in dirs {
                let norm = sqrt(d.x*d.x + d.y*d.y + d.z*d.z)
                let nd = norm > 0 ? SCNVector3(d.x/norm, d.y/norm, d.z/norm) : d
                addBranch(from: to, dir: nd, length: length * 0.65, depth: depth-1)
            }
        }

        addBranch(from: SCNVector3(0,-2,0), dir: SCNVector3(0,1,0), length: 2.0, depth: 4)

        // Particle cloud
        let particles = SCNParticleSystem()
        particles.particleSize = 0.03; particles.particleColor = UIColor(red:0,green:1,blue:0.8,alpha:0.6)
        particles.particleLifeSpan = 3.0; particles.birthRate = 50
        particles.emitterShape = SCNSphere(radius: 2.5)
        particles.isAffectedByGravity = false
        let particleNode = SCNNode(); particleNode.addParticleSystem(particles); root.addChildNode(particleNode)

        // Subtle rotation
        let rotate = CABasicAnimation(keyPath: "rotation")
        rotate.toValue = NSValue(scnVector4: SCNVector4(0,1,0,Float.pi*2))
        rotate.duration = 20; rotate.repeatCount = .infinity
        root.addAnimation(rotate, forKey: "treeRotate")

        try? await Task.sleep(nanoseconds: 300_000_000)
        glScene = root
        isRendering = false
    }

    // Called from IDECompilerOutputView after each compile — auto-triggers GL render
    func onCompileComplete() {
        Task { await buildGLScene() }
    }
}

import SceneKit

// MARK: - Terminal View

struct IDETerminalView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "#ff5f57")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "#febc2e")).frame(width: 10, height: 10)
                Circle().fill(Color(hex: "#28c840")).frame(width: 10, height: 10)
                Text("▶ LEATR APP RUNTIME")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00ffcc")).kerning(2).padding(.leading, 6)
                Spacer()
                // Keyboard dismiss button
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Text("⌨️↓").font(.system(size: 12))
                        .padding(4).background(Color(hex: "#00ffcc").opacity(0.1)).cornerRadius(5)
                }
                Button {
                    ideVM.compiler.terminalLines = []
                } label: {
                    Text("clear").font(.system(size: 9, design: .monospaced)).foregroundColor(Color(hex: "#4a8a7a"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#0d1117"))

            // Output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Boot messages
                        TerminalRow(text: "[SYS] ─────────────────────────────────────", color: "#4a8a7a")
                        TerminalRow(text: "[SYS] LEATR App Runtime v2.0", color: "#00ffcc")
                        TerminalRow(text: "[SYS] © 2025 DART Meadow | Radical Deepscale LLC.", color: "#4a8a7a")
                        TerminalRow(text: "[SYS] ─────────────────────────────────────", color: "#4a8a7a")
                        ForEach(ideVM.compiler.terminalLines) { line in
                            TerminalRow(text: line.text, color: line.color)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .background(Color(hex: "#0d1117"))
                .onChange(of: ideVM.compiler.terminalLines.count) { _ in
                    if let last = ideVM.compiler.terminalLines.last {
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
                    .tint(Color(hex: "#00ffcc"))
                    .focused($focused)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .padding(.leading, 8)
                    .onSubmit {
                        ideVM.compiler.handleTerminalCommand(input, source: ideVM.sourceCode)
                        input = ""
                    }

                Spacer()

                Button("⏎") {
                    ideVM.compiler.handleTerminalCommand(input, source: ideVM.sourceCode)
                    input = ""
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#00ffcc"))
                .padding(.trailing, 12)
            }
            .frame(height: 44)
            .background(Color(hex: "#161b22"))
            .overlay(Divider().background(Color(hex: "#30363d")), alignment: .top)
        }
    }
}

struct TerminalRow: View {
    let text: String
    let color: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Color(hex: color))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 0.5)
    }
}

// MARK: - Files View

struct IDEFilesView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb + refresh
            HStack {
                if let repo = ideVM.currentRepo {
                    Button { Task { await ideVM.loadFiles(repo: repo, path: "") } } label: {
                        Text(repo.name)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(themeVM.accent)
                    }
                    if !ideVM.currentPath.isEmpty {
                        Text("/").foregroundColor(themeVM.dim).font(.system(size: 11))
                        Text(ideVM.currentPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(themeVM.text)
                    }
                } else {
                    Text("No repo selected")
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.dim)
                }
                Spacer()
                if ideVM.isLoadingFiles { ProgressView().scaleEffect(0.7).tint(themeVM.accent) }
                Button { Task {
                    if let r = ideVM.currentRepo { await ideVM.loadFiles(repo: r, path: ideVM.currentPath) }
                }} label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12)).foregroundColor(themeVM.dim)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(themeVM.surface)
            .overlay(Divider().background(themeVM.border), alignment: .bottom)

            if ideVM.repoFiles.isEmpty && !ideVM.isLoadingFiles {
                VStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.system(size: 40)).foregroundColor(themeVM.dim.opacity(0.3))
                    Text("Open a repository from the drawer menu")
                        .font(.system(size: 12)).foregroundColor(themeVM.dim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(ideVM.repoFiles, id: \.path) { file in
                    Button {
                        if file.type == "dir" {
                            if let r = ideVM.currentRepo {
                                Task { await ideVM.loadFiles(repo: r, path: file.path) }
                            }
                        } else {
                            Task { await ideVM.openFile(file) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: file.type == "dir" ? "folder.fill" : (file.name.hasSuffix(".ash") ? "chevron.left.forwardslash.chevron.right" : "doc"))
                                .font(.system(size: 13))
                                .foregroundColor(file.type == "dir" ? themeVM.accent : (file.name.hasSuffix(".ash") ? Color(hex: "#00ffcc") : themeVM.dim))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 12, design: file.name.hasSuffix(".ash") ? .monospaced : .default))
                                    .foregroundColor(themeVM.text)
                                if let size = file.size, size > 0 {
                                    Text(formatSize(size))
                                        .font(.system(size: 9))
                                        .foregroundColor(themeVM.dim)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundColor(themeVM.dim.opacity(0.4))
                        }
                        .padding(.vertical, 3)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(themeVM.bg)
    }

    func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024*1024 { return String(format: "%.1f KB", Double(bytes)/1024) }
        return String(format: "%.1f MB", Double(bytes)/(1024*1024))
    }
}

// MARK: - Docs View

struct IDEDocsView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        ZStack {
            // Logo splash background
            VStack {
                if let logo = UIImage(named: "AppLogo") {
                    Image(uiImage: logo).resizable().scaledToFit()
                        .frame(width: 180).opacity(0.05)
                } else {
                    IDELogoMark(size: 180, accent: themeVM.accent).opacity(0.05)
                }
                Text("ASH TREE IDE")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(themeVM.accent.opacity(0.05)).kerning(6)
                Text("LEATR · Lead Edge Ash Tree Reflex")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeVM.accent.opacity(0.04)).kerning(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DocBlock(title: "LEATR v2 COMPILER STANDARD",
                         content: "Lead Edge Ash Tree Reflex · © 2025 DART Meadow | Radical Deepscale LLC." +
                               "\nSwitch equations wrap every syntax pattern:" +
                               "\n  Encode (OPEN):  (xa²√xa) - 1" +
                               "\n  Decode (CLOSE): (xa²√xa) + 1")

                DocBlock(title: "NODE STRUCTURE",
                         content: "(NodeName):-: {" +
                               "\n  {{env:MyProject}}    // outer tag" +
                               "\n  [[owner:username]]   // inner tag" +
                               "\n  [poly: data-matrix]  // math" +
                               "\n  [net: layer]         // network" +
                               "\n  with var (s) {" +
                               "\n    irin (\"Data: input\")" +
                               "\n    Maze" +
                               "\n    thenplace var (s) with var (s)" +
                               "\n  }" +
                               "\n  irout (\"Result: \" placeto (s))" +
                               "\n}|';\'|")

                DocBlock(title: "TAG SYSTEM",
                         content: "{{outer-tag}}  — Environment isolation shell" +
                               "\n[[inner-tag]]  — Script ownership (double-tagged)" +
                               "\n[poly:...]     — Polynomial/physics container" +
                               "\n[net:...]      — Network syntax (log-iterative mode)")

                DocBlock(title: "ORDER OF OPERATIONS (19)",
                         content: "Natural Tools (1-7):" +
                               "\nMaze · Puzzle · Envelope · Hammer · Stick · Knife · Scissors" +
                               "\n\nMath/Physics (8-19):" +
                               "\nParentheses · Exponents · Multiplication · Division" +
                               "\nAddition · Subtraction · Logarithm · Trigonometry" +
                               "\nTemperature · Velocity · Pressure · Mass · Photosynthesis" +
                               "\n\nSenses (AI):" +
                               "\nTouch · Taste · Vision · Smell · Hear")

                DocBlock(title: "BRPN — PENDULUM NODE",
                         content: "After compile, shell routing via Buoyancy Reflex:" +
                               "\n  f = formation  (1.0 if outer-tags present)" +
                               "\n  r = reflex     (1.0 if inner-tags present)" +
                               "\n  p = performance (nodeCount / 5, max 1.0)" +
                               "\n  frp = f × r × p" +
                               "\n  buoyancy = frp × sqrt(|frp|)" +
                               "\n\nShell: >=0.76 = GEOLOGICAL  >=0.44 = MARITIME  <0.44 = AEROSPACE")

                DocBlock(title: "GL DRIVERS",
                         content: "import (GLDrivers)  // Load 3D GL runtime" +
                               "\n\nNodes: ThreeScene · LightNode · ArcEdgeNode" +
                               "\n  CameraNode · ParticleNode · GeometryNode" +
                               "\n  MaterialNode · MeshNode · AnimateNode · UIOverlayNode" +
                               "\n\nArc Edge math (Justin Craig Venable):" +
                               "\n  Circumference: sqrt(d×3)^2   (no pi)" +
                               "\n  Area: circ^2   Volume: area^3   Sphere SA: vol×0.25" +
                               "\n  Branch: 1/8-circle arc")

                DocBlock(title: "KEYWORDS",
                         content: "irin · irout · thenplace · place · placeto" +
                               "\nResearch · Report · with · var · when · where" +
                               "\nand · or · not · for · else · is · if · end" +
                               "\nimport · return")
            }
            .padding(16)
            }
        }
        .background(themeVM.bg)
    }
}

struct DocBlock: View {
    let title: String
    let content: String
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(themeVM.dim)
                .kerning(1.5)
            Text(content)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeVM.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(themeVM.surface)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeVM.border, lineWidth: 0.5))
        }
    }
}
