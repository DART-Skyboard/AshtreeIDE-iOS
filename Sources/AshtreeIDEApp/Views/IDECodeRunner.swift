// IDECodeRunner.swift
// Real language execution for Ash Tree IDE
// HTML → WKWebView live preview
// JavaScript → WKWebView execution
// Python → Pyodide (WebAssembly in WKWebView)
// Other languages → formatted output display
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import WebKit

// MARK: - Run Output Model

public enum RunOutput {
    case html(String)         // render in WKWebView
    case javascript(String)   // run in WKWebView
    case python(String)       // run via Pyodide in WKWebView
    case text(String)         // plain compiler/runtime output
    case error(String)        // error output
    case notSupported(String) // "compile on device not supported"
}

// MARK: - Code Runner

@MainActor
public final class IDECodeRunner: ObservableObject {
    public static let shared = IDECodeRunner()
    @Published public var output: RunOutput = .text("")
    @Published public var isRunning = false
    @Published public var showWebView = false

    public func run(code: String, language: String, filename: String) async {
        isRunning = true
        defer { isRunning = false }

        switch language {
        case "html":
            // Direct HTML render
            output = .html(code)
            showWebView = true

        case "javascript", "typescript":
            // Wrap in HTML shell and execute
            let html = """
<!DOCTYPE html><html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body { background:#0d1117; color:#c9d1d9; font-family:monospace; padding:12px; }
  #output { white-space:pre; }
  .error { color:#ff6b6b; }
  .log   { color:#00ffcc; }
</style>
</head><body>
<div id="output"></div>
<script>
const _out = document.getElementById("output");
const _log = (...args) => {
  _out.innerHTML += "<div class=\"log\">" + args.map(a => {
    if (typeof a === "object") return JSON.stringify(a, null, 2);
    return String(a);
  }).join(" ") + "</div>";
};
const _err = (...args) => {
  _out.innerHTML += "<div class=\"error\">ERR: " + args.join(" ") + "</div>";
};
const originalLog   = console.log;
const originalError = console.error;
console.log   = (...a) => { _log(...a);   originalLog(...a); };
console.error = (...a) => { _err(...a);   originalError(...a); };
window.onerror = (msg, src, line, col, err) => {
  _err("Line " + line + ": " + msg);
  return true;
};
try {
  \(code)
} catch(e) {
  _err(e.toString());
}
</script></body></html>
"""
            output = .html(html)
            showWebView = true

        case "python", "python_ml":
            // Use Pyodide (Python in WebAssembly) via CDN
            let escaped = code
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
            let html = """
<!DOCTYPE html><html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<script src="https://cdn.jsdelivr.net/pyodide/v0.26.2/full/pyodide.js"></script>
<style>
  body { background:#0d1117; color:#c9d1d9; font-family:monospace; padding:12px; margin:0; }
  #status { color:#00ffcc; margin-bottom:8px; }
  #output { white-space:pre-wrap; }
  .err { color:#ff6b6b; }
</style>
</head><body>
<div id="status">⏳ Loading Python runtime…</div>
<div id="output"></div>
<script>
const out = document.getElementById("output");
const status = document.getElementById("status");
async function run() {
  try {
    const py = await loadPyodide({ stdout: (s) => { out.textContent += s + "\\n"; } });
    status.textContent = "▶ Running…";
    await py.runPythonAsync(`\(escaped)`);
    status.textContent = "✓ Complete";
  } catch(e) {
    status.textContent = "⚠ Error";
    out.innerHTML += "<span class=\"err\">Error: " + e.toString() + "</span>\\n";
  }
}
run();
</script></body></html>
"""
            output = .html(html)
            showWebView = true

        case "threejs", "react", "vue":
            // Inject CDN + run
            let cdnMap = [
                "threejs": "https://cdn.skypack.dev/three@0.152.0",
                "react":   "https://cdn.jsdelivr.net/npm/react@18/umd/react.development.js",
                "vue":     "https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.js"
            ]
            let cdn = cdnMap[language] ?? ""
            let html = """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>body{margin:0;background:#0d1117;overflow:hidden;}
#error{position:absolute;top:8px;left:8px;color:#ff6b6b;font-family:monospace;font-size:11px;white-space:pre;}</style>
</head><body>
<div id="root"></div><div id="error"></div>
<script src="\(cdn)"></script>
<script>
window.onerror = (m,s,l,c,e) => {
  document.getElementById("error").textContent = "L" + l + ": " + m;
};
try { \(code) } catch(e) {
  document.getElementById("error").textContent = e.toString();
}
</script></body></html>
"""
            output = .html(html)
            showWebView = true

        case "swift":
            output = .notSupported("Swift compilation requires Xcode. Code loaded in editor — use Build & Run for Ash-Swift hybrid scripts.")

        case "cpp", "rust", "go", "kotlin", "dart":
            let env = IDELanguageEnv.find(id: language)
            output = .notSupported("\(env.name) compilation runs natively on a host machine. Export the file and compile with your local \(language) toolchain.")

        case "bash":
            output = .notSupported("Shell scripts require a terminal environment. Export and run on macOS/Linux.")

        case "sql":
            output = .text("SQL query ready — connect to a database to execute.\n\n" + code)

        case "php":
            // PHP via Phorever CDN approach - use a minimal JS PHP interpreter
            output = .notSupported("PHP requires a server environment. Export and run on a web server with PHP installed.")

        case "css":
            // Preview CSS with a sample HTML wrapper
            let html = """
<!DOCTYPE html><html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>\(code)</style>
</head><body>
<h1>CSS Preview</h1>
<p>Your stylesheet is applied to this page.</p>
<button>Button</button>
<div class="box">Box Element</div>
</body></html>
"""
            output = .html(html)
            showWebView = true

        default:
            // Ash or unknown — use LEATR compiler output
            output = .text("Running Ash Edge Language script…")
        }
    }
}

// MARK: - WebView for execution output

struct IDEWebOutputView: UIViewRepresentable {
    let html: String
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let wv = WKWebView(frame:.zero, configuration:config)
        wv.backgroundColor = UIColor(red:0.024,green:0.039,blue:0.063,alpha:1)
        wv.isOpaque = false
        wv.navigationDelegate = context.coordinator
        // Allow loading from CDN
        wv.loadHTMLString(html, baseURL: URL(string:"https://ashtreeide.local"))
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        wv.loadHTMLString(html, baseURL: URL(string:"https://ashtreeide.local"))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: IDEWebOutputView
        init(_ p: IDEWebOutputView) { parent = p }
        func webView(_ wv: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ wv: WKWebView, didFinish _: WKNavigation!) {
            parent.isLoading = false
        }
    }
}

// MARK: - GL/Run Output Panel (replaces tree particle scene for non-Ash)

struct IDERunOutputPanel: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @StateObject private var runner = IDECodeRunner.shared
    @State private var isWebLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("◈ RUN OUTPUT")
                    .font(.system(size:9,weight:.semibold,design:.monospaced))
                    .foregroundColor(themeVM.accent).kerning(2)
                Spacer()
                if runner.isRunning {
                    ProgressView().scaleEffect(0.7).tint(themeVM.accent)
                } else {
                    if case .html = runner.output {
                        Button("↻ Reload") {
                            Task { await runner.run(
                                code: ideVM.sourceCode,
                                language: IDELanguageStore.shared.activeEnv.id,
                                filename: ideVM.currentFile) }
                        }
                        .font(.system(size:9,design:.monospaced))
                        .foregroundColor(themeVM.dim)
                        .padding(.trailing,6)
                    }
                    Button {
                        Task { await runner.run(
                            code: ideVM.sourceCode,
                            language: IDELanguageStore.shared.activeEnv.id,
                            filename: ideVM.currentFile) }
                    } label: {
                        Text("▸ Run")
                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                            .foregroundColor(themeVM.accent)
                            .padding(.horizontal,10).padding(.vertical,5)
                            .background(themeVM.accent.opacity(0.1)).cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal,14).padding(.vertical,8)
            .background(themeVM.bg)
            .overlay(Divider().background(themeVM.accent.opacity(0.2)), alignment:.bottom)

            // Output area
            switch runner.output {
            case .html(let src):
                ZStack {
                    IDEWebOutputView(html: src, isLoading: $isWebLoading)
                    if isWebLoading {
                        VStack {
                            ProgressView()
                            Text("Loading…")
                                .font(.system(size:10,design:.monospaced))
                                .foregroundColor(themeVM.dim)
                        }
                        .frame(maxWidth:.infinity,maxHeight:.infinity)
                        .background(themeVM.bg)
                    }
                }
            case .text(let t):
                ScrollView {
                    Text(t)
                        .font(.system(size:11,design:.monospaced))
                        .foregroundColor(Color(hex:"#00ffcc"))
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .padding(12)
                }
                .background(themeVM.bg)
            case .error(let e):
                ScrollView {
                    Text(e)
                        .font(.system(size:11,design:.monospaced))
                        .foregroundColor(.red)
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .padding(12)
                }
                .background(themeVM.bg)
            case .notSupported(let msg):
                VStack(spacing:10) {
                    Image(systemName:"info.circle")
                        .font(.system(size:28)).foregroundColor(themeVM.dim.opacity(0.5))
                    Text(msg)
                        .font(.system(size:10,design:.monospaced))
                        .foregroundColor(themeVM.dim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal,20)
                }
                .frame(maxWidth:.infinity,maxHeight:.infinity)
                .background(themeVM.bg)
            case .javascript, .python:
                // These get converted to .html(wrappedCode) before display
                EmptyView()
            }
        }
        .task {
            // Auto-run when panel appears if a non-Ash project is active
            let lang = IDELanguageStore.shared.activeEnv.id
            if lang != "ash" && !ideVM.sourceCode.isEmpty {
                await runner.run(code: ideVM.sourceCode, language: lang,
                                  filename: ideVM.currentFile)
            }
        }
    }
}
