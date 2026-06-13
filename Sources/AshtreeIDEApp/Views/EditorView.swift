// ============================================================
//  EditorView.swift — Ash code editor with syntax highlight + actions
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

// MARK: - Editor View

struct EditorView: View {
    @EnvironmentObject var ide: IDEState
    @EnvironmentObject var github: GitHubService
    @State private var showSaveSheet = false
    @State private var saveFilename = ""
    @State private var saveMessage = ""
    @State private var saveSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Editor action bar
            EditorActionBar(
                onBuildRun:  { Task { await ide.buildAndRun() } },
                onNetCompile:{ Task { await ide.buildAndRun(netMode: true) } },
                onClear:     { ide.compilerLogs = []; ide.terminalLines = [] },
                onSave:      { showSaveSheet = true },
                isBusy:      ide.isCompiling
            )

            // Split: editor + compiler output
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                if isLandscape {
                    HStack(spacing: 0) {
                        AshCodeEditor()
                            .frame(width: geo.size.width * 0.55)
                        Divider()
                        CompilerOutputView()
                    }
                } else {
                    VStack(spacing: 0) {
                        AshCodeEditor()
                            .frame(height: geo.size.height * 0.55)
                        Divider()
                        CompilerOutputView()
                    }
                }
            }
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveToGitHubSheet(
                filename: $saveFilename,
                message:  $saveMessage,
                success:  $saveSuccess,
                onSave: { path, msg in
                    Task {
                        ide.isSaving = true
                        let ok = await github.saveFile(path: path, content: ide.sourceCode, message: msg)
                        saveSuccess = ok
                        if ok { ide.currentFile = URL(fileURLWithPath: path).lastPathComponent }
                        ide.isSaving = false
                    }
                }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Action Bar

struct EditorActionBar: View {
    let onBuildRun:   () -> Void
    let onNetCompile: () -> Void
    let onClear:      () -> Void
    let onSave:       () -> Void
    let isBusy:       Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ActionBtn(label: "▶ BUILD & RUN", color: Color("AshDark"), action: onBuildRun, busy: isBusy)
                ActionBtn(label: "⟳ NET COMPILE", color: Color("InnerCyan"), action: onNetCompile, busy: isBusy)
                ActionBtn(label: "✕ CLEAR",       color: Color("AshMid").opacity(0.4), action: onClear)
                ActionBtn(label: "↑ SAVE",        color: Color("FrameRed").opacity(0.8), action: onSave)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color("AshLight"))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct ActionBtn: View {
    let label: String
    let color: Color
    let action: () -> Void
    var busy: Bool = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(busy ? color.opacity(0.5) : color)
                .cornerRadius(6)
        }
        .disabled(busy)
    }
}

// MARK: - Ash Code Editor (UITextView wrapper with line numbers)

struct AshCodeEditor: UIViewRepresentable {
    @EnvironmentObject var ide: IDEState

    func makeCoordinator() -> Coordinator { Coordinator(ide: ide) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = true
        scroll.backgroundColor = .white

        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.spellCheckingType = .no
        tv.backgroundColor = .clear
        tv.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textColor = UIColor(named: "AshDark") ?? .black
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 44, bottom: 14, right: 14)
        tv.text = ide.sourceCode
        tv.tag = 100

        let lineNumbers = LineNumberView(textView: tv)
        lineNumbers.tag = 200

        scroll.addSubview(lineNumbers)
        scroll.addSubview(tv)

        context.coordinator.textView = tv
        context.coordinator.lineView = lineNumbers
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        guard let tv = scroll.viewWithTag(100) as? UITextView else { return }
        if tv.text != ide.sourceCode { tv.text = ide.sourceCode }
        tv.frame = CGRect(x: 0, y: 0, width: scroll.bounds.width, height: max(scroll.bounds.height, tv.contentSize.height))
        scroll.contentSize = tv.contentSize
        applyHighlighting(tv)
    }

    private func applyHighlighting(_ tv: UITextView) {
        let source = tv.text ?? ""
        let mas = NSMutableAttributedString(string: source)
        let full = NSRange(source.startIndex..., in: source)

        // Base color
        mas.addAttribute(.foregroundColor, value: UIColor(named: "AshDark") ?? .black, range: full)
        mas.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: full)

        // Comments — ash mid color
        applyRegex(mas, pattern: "//[^\n]*", color: UIColor(named: "AshMid") ?? .gray)
        // Strings — frame red
        applyRegex(mas, pattern: "\"[^\"]*\"", color: UIColor(named: "FrameRed") ?? .red)
        // Keywords
        let kws = LeatrCompiler.keywords.joined(separator: "|")
        applyRegex(mas, pattern: "\\b(\(kws))\\b", color: UIColor(named: "InnerCyan") ?? .cyan, bold: true)
        // Natural tools
        let tools = LeatrCompiler.naturalTools.joined(separator: "|")
        applyRegex(mas, pattern: "\\b(\(tools))\\b", color: UIColor(systemPurple: 0.6) ?? .purple)
        // Outer tags {{}}
        applyRegex(mas, pattern: "\\{\\{[^}]+\\}\\}", color: UIColor(named: "OrangeTag") ?? .orange)
        // Inner tags [[]]
        applyRegex(mas, pattern: "\\[\\[[^\\]]+\\]\\]", color: UIColor(systemYellow: 0.7) ?? .systemYellow)
        // Poly/net tags
        applyRegex(mas, pattern: "\\[(?:poly|net):[^\\]]+\\]", color: UIColor(systemPurple: 0.5) ?? .purple)
        // Node names (NodeName):-:{
        applyRegex(mas, pattern: "\\([A-Za-z][A-Za-z0-9_]*\\)(?=:-:)", color: UIColor(named: "AshDark") ?? .black, bold: true)
        // Switch close
        applyRegex(mas, pattern: "\\}\\|';'\\|", color: UIColor(named: "InnerCyan") ?? .cyan, bold: true)

        let selectedRange = tv.selectedRange
        tv.attributedText = mas
        tv.selectedRange = selectedRange
    }

    private func applyRegex(_ mas: NSMutableAttributedString, pattern: String, color: UIColor, bold: Bool = false) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let str = mas.string
        regex.enumerateMatches(in: str, range: NSRange(str.startIndex..., in: str)) { m, _, _ in
            guard let r = m?.range else { return }
            mas.addAttribute(.foregroundColor, value: color, range: r)
            if bold { mas.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold), range: r) }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let ide: IDEState
        weak var textView: UITextView?
        weak var lineView: LineNumberView?

        init(ide: IDEState) { self.ide = ide }

        func textViewDidChange(_ textView: UITextView) {
            ide.sourceCode = textView.text
            lineView?.setNeedsDisplay()
        }
    }
}

// MARK: - Line number view

final class LineNumberView: UIView {
    weak var textView: UITextView?

    init(textView: UITextView) {
        self.textView = textView
        super.init(frame: .zero)
        backgroundColor = UIColor(named: "AshLight") ?? UIColor(white: 0.97, alpha: 1)
        frame = CGRect(x: 0, y: 0, width: 40, height: 10000)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let tv = textView else { return }
        let text = tv.text ?? ""
        let lines = text.components(separatedBy: "\n")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor(named: "AshMid") ?? UIColor.gray
        ]
        for (i, _) in lines.enumerated() {
            let y = CGFloat(i) * 19 + 14
            let str = NSAttributedString(string: "\(i+1)", attributes: attrs)
            let size = str.size()
            str.draw(at: CGPoint(x: 40 - size.width - 6, y: y))
        }
    }
}

// MARK: - Compiler Output

struct CompilerOutputView: View {
    @EnvironmentObject var ide: IDEState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("◈ COMPILER OUTPUT")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color("AshMid"))
                    .kerning(2)
                Spacer()
                if let b = ide.brpnResult {
                    Text(b.shell)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(shellColor(b.shell))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(shellColor(b.shell).opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color("AshLight"))
            .overlay(Divider(), alignment: .bottom)

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(ide.compilerLogs) { entry in
                            CompilerLogRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .onChange(of: ide.compilerLogs.count) { _ in
                    if let last = ide.compilerLogs.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
        .background(Color.white)
    }

    func shellColor(_ shell: String) -> Color {
        switch shell {
        case "GEOLOGICAL": return .brown
        case "MARITIME":   return Color("InnerCyan")
        case "AEROSPACE":  return .purple
        default:           return Color("AshMid")
        }
    }
}

struct CompilerLogRow: View {
    let entry: CompilerLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.type)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: entry.color))
                .frame(minWidth: 72, alignment: .leading)
            Text(entry.message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color("AshDark").opacity(0.8))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Save to GitHub Sheet

struct SaveToGitHubSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var filename: String
    @Binding var message: String
    @Binding var success: Bool
    let onSave: (String, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("File Path").font(.system(size: 10, design: .monospaced))) {
                    TextField("e.g. projects/my_app.ash", text: $filename)
                        .font(.system(size: 13, design: .monospaced))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                Section(header: Text("Commit Message").font(.system(size: 10, design: .monospaced))) {
                    TextField("Update my script", text: $message)
                        .font(.system(size: 13))
                }
                if success {
                    Section {
                        Label("Saved to GitHub", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Save to GitHub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let path = filename.isEmpty ? "untitled.ash" : filename
                        let msg = message.isEmpty ? "Update \(path)" : message
                        if !path.hasSuffix(".ash") { filename = path + ".ash" }
                        onSave(filename.isEmpty ? "untitled.ash" : filename, msg)
                    }
                    .disabled(filename.isEmpty)
                }
            }
        }
    }
}

// MARK: - UIColor helpers

extension UIColor {
    convenience init?(systemPurple alpha: CGFloat) {
        self.init(red: 0.5, green: 0.1, blue: 0.9, alpha: alpha)
    }
    convenience init?(systemYellow alpha: CGFloat) {
        self.init(red: 1.0, green: 0.8, blue: 0.0, alpha: alpha)
    }
}
