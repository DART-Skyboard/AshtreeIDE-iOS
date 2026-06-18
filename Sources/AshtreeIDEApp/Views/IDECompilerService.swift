// IDECompilerService.swift
// Language execution engine for Ash Tree IDE
// © 2025 DART Meadow | Radical Deepscale LLC.
//
// Execution strategies:
//   WKWebView  — HTML, CSS, JS, TS, Three.js, React, Vue, PHP (via PHP-WASM), Python (Pyodide)
//   Judge0 API — C++, Java, Go, Rust, Swift, C, C#, Kotlin, Ruby, Bash, SQL, R
//   Piston API — fallback for any language Judge0 doesn't handle
//
// Judge0 public endpoint (no auth required for CE): https://judge0-ce.p.rapidapi.com
// Piston public endpoint (free, no auth): https://emkc.org/api/v2/piston/execute
//
// NOTE on C++/Java graphical output:
//   C++ and Java programs that produce TEXT output work fully via Judge0.
//   Programs requiring a GUI/window (OpenGL, X11, Swing) cannot render on iOS.
//   We capture stdout/stderr and display as terminal-style output.
//   For visual C++, use the Three.js or WebGL environment instead.

import SwiftUI
import WebKit

// MARK: - Language Execution Strategy

public enum ExecutionStrategy {
    case webView     // Renders in WKWebView (HTML, JS, Python/Pyodide, PHP-WASM)
    case judge0      // Remote compilation + execution via Judge0 API
    case piston      // Remote execution via Piston API (fallback)
    case notSupported(String)
}

// MARK: - Judge0 Language IDs (CE edition)

public enum Judge0Language: Int {
    case c          = 50
    case cpp        = 54   // C++ (GCC 9.2.0)
    case java       = 62   // Java (OpenJDK 13.0.1)
    case python     = 71   // Python (3.8.1)
    case go         = 60   // Go (1.13.5)
    case rust       = 73   // Rust (1.40.0)
    case swift      = 83   // Swift (5.2.3)
    case csharp     = 51   // C# (Mono 6.6.0)
    case kotlin     = 78   // Kotlin (1.3.70)
    case ruby       = 72   // Ruby (2.7.0)
    case bash       = 46   // Bash (5.0.0)
    case r          = 80   // R (4.0.0)
    case typescript = 74   // TypeScript (3.7.4) — text output only
    case sql        = 82   // SQL (SQLite 3.27.2)
    case php        = 68   // PHP (7.4.1)

    static func from(languageId: String) -> Judge0Language? {
        switch languageId {
        case "c":          return .c
        case "cpp":        return .cpp
        case "java":       return .java
        case "python","python_ml": return .python
        case "go":         return .go
        case "rust":       return .rust
        case "swift":      return .swift
        case "csharp":     return .csharp
        case "kotlin":     return .kotlin
        case "ruby":       return .ruby
        case "bash":       return .bash
        case "r":          return .r
        case "sql":        return .sql
        case "php":        return .php
        default:           return nil
        }
    }
}

// MARK: - Execution Result

public struct ExecutionResult {
    public var stdout:    String
    public var stderr:    String
    public var compileError: String
    public var exitCode:  Int
    public var time:      String
    public var memory:    String
    public var webHTML:   String?  // set when rendering in WKWebView
    public var language:  String
    public var success:   Bool { exitCode == 0 && compileError.isEmpty }
}

// MARK: - Compiler Service

@MainActor
public final class IDECompilerService: ObservableObject {
    public static let shared = IDECompilerService()

    @Published public var result: ExecutionResult? = nil
    @Published public var isRunning = false
    @Published public var showWebView = false

    // Judge0 Community Edition — free public endpoint
    // No API key needed for basic use (rate limited to ~50 req/day)
    // For production: get a free key at rapidapi.com/judge0-official/api/judge0-ce
    private let judge0Base  = "https://ce.judge0.com"
    private let pistonBase  = "https://emkc.org/api/v2/piston"

    // MARK: - Main entry point

    public func execute(code: String, language: String, stdin: String = "",
                        projectFiles: [String: String] = [:]) async {
        isRunning   = true
        showWebView = false
        result      = nil
        defer { isRunning = false }

        let strategy = executionStrategy(for: language)
        switch strategy {
        case .webView:
            let html = buildWebHTML(code: code, language: language, projectFiles: projectFiles)
            result = ExecutionResult(stdout: "", stderr: "", compileError: "",
                                     exitCode: 0, time: "–", memory: "–",
                                     webHTML: html, language: language)
            showWebView = true

        case .judge0:
            await executeJudge0(code: code, language: language, stdin: stdin)

        case .piston:
            await executePiston(code: code, language: language, stdin: stdin)

        case .notSupported(let msg):
            result = ExecutionResult(stdout: "", stderr: msg, compileError: "",
                                     exitCode: 1, time: "–", memory: "–",
                                     webHTML: nil, language: language)
        }
    }

    // MARK: - Strategy routing

    private func executionStrategy(for language: String) -> ExecutionStrategy {
        switch language {
        // WebView-rendered languages
        case "html", "css":           return .webView
        case "javascript", "typescript": return .webView
        case "threejs", "react", "vue": return .webView
        case "python", "python_ml":   return .webView  // Pyodide WASM
        case "php":                   return .webView  // PHP-WASM
        case "sql":                   return .webView  // SQL.js WASM

        // Remote compilation via Judge0 CE (free, no auth required)
        case "cpp", "c", "csharp":   return .judge0
        case "java", "kotlin":        return .judge0
        case "go", "rust":            return .judge0
        case "ruby", "bash":          return .judge0
        case "r":                     return .judge0
        case "swift":                 return .judge0
        case "dart":                  return .piston   // Judge0 CE lacks Dart
        case "typescript":            return .judge0

        default:                      return .notSupported("Language '\(language)' is not yet supported.")
        }
    }

    // MARK: - WKWebView HTML builder

    private func buildWebHTML(code: String, language: String,
                               projectFiles: [String: String] = [:]) -> String {
        switch language {

        case "html":
            // Inline referenced CSS and JS files from project
            var html = code
            // Find all <link rel="stylesheet" href="..."> and inline CSS
            let cssPattern = #"<link[^>]+rel=["']stylesheet["'][^>]+href=["']([^"']+)["'][^>]*>"#
            if let cssRegex = try? NSRegularExpression(pattern: cssPattern, options: .caseInsensitive) {
                let matches = cssRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches.reversed() {
                    guard let fullRange = Range(match.range, in: html),
                          let hrefRange = Range(match.range(at: 1), in: html) else { continue }
                    let filename = String(html[hrefRange])
                    let basename = URL(fileURLWithPath: filename).lastPathComponent
                    if let css = projectFiles[basename] ?? projectFiles[filename] {
                        html = html.replacingCharacters(in: fullRange,
                            with: "<style>\(css)</style>")
                    }
                }
            }
            // Find all <script src="..."> and inline JS
            let jsPattern = #"<script[^>]+src=["']([^"']+)["'][^>]*></script>"#
            if let jsRegex = try? NSRegularExpression(pattern: jsPattern, options: .caseInsensitive) {
                let matches = jsRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches.reversed() {
                    guard let fullRange = Range(match.range, in: html),
                          let srcRange = Range(match.range(at: 1), in: html) else { continue }
                    let filename = String(html[srcRange])
                    let basename = URL(fileURLWithPath: filename).lastPathComponent
                    // Only inline local references (not https:// CDN links)
                    if !filename.hasPrefix("http"), let js = projectFiles[basename] ?? projectFiles[filename] {
                        html = html.replacingCharacters(in: fullRange,
                            with: "<script>\(js)</script>")
                    }
                }
            }
            return html

        case "css":
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body { background:#0d1117; color:#c9d1d9; font-family:sans-serif; padding:20px; }
h1,h2,h3 { color:#58a6ff; }
button { background:#21262d; color:#c9d1d9; border:1px solid #30363d; padding:8px 16px; border-radius:6px; cursor:pointer; }
.box { background:#161b22; border:1px solid #30363d; padding:16px; border-radius:8px; margin:10px 0; }
\(code)
</style>
</head><body>
<h1>CSS Preview</h1>
<p>Your stylesheet is applied to this page.</p>
<div class="box">Box Element</div>
<button onclick="this.textContent='Clicked!'">Button</button>
</body></html>
"""

        case "javascript", "typescript":
            let escaped = code
                .replacingOccurrences(of: "\\", with: "\\\\")
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
* { box-sizing: border-box; margin:0; padding:0; }
body { background:#0d1117; color:#c9d1d9; font-family:monospace; padding:12px; }
#output { white-space:pre-wrap; font-size:12px; line-height:1.6; }
.log { color:#00ffcc; } .err { color:#ff6b6b; } .warn { color:#e5c07b; }
#status { font-size:9px; color:#4a5568; margin-bottom:8px; letter-spacing:1px; }
</style>
</head><body>
<div id="status">▶ EXECUTING</div>
<div id="output"></div>
<script>
const out = document.getElementById("output");
const status = document.getElementById("status");
const _fmt = a => typeof a==="object" ? JSON.stringify(a,null,2) : String(a);
console.log = (...a) => { out.innerHTML += `<div class="log">${a.map(_fmt).join(" ")}</div>`; };
console.warn = (...a) => { out.innerHTML += `<div class="warn">⚠ ${a.map(_fmt).join(" ")}</div>`; };
console.error = (...a) => { out.innerHTML += `<div class="err">✗ ${a.map(_fmt).join(" ")}</div>`; };
window.onerror = (m,s,l,c,e) => {
  out.innerHTML += `<div class="err">Error (line ${l}): ${m}</div>`;
  status.textContent = "✗ ERROR"; return true;
};
try {
  \(escaped)
  status.textContent = "✓ COMPLETE";
} catch(e) {
  out.innerHTML += `<div class="err">Error: ${e}</div>`;
  status.textContent = "✗ ERROR";
}
</script></body></html>
"""

        case "threejs":
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>* { margin:0; padding:0; } body { background:#000; overflow:hidden; }
#err { position:fixed;top:8px;left:8px;color:#ff6b6b;font:11px monospace;white-space:pre; }</style>
</head><body>
<div id="err"></div>
<script src="https://cdn.skypack.dev/three@0.152.0/build/three.module.js" type="module"></script>
<script type="module">
window.onerror = (m,s,l) => { document.getElementById("err").textContent = `L${l}: ${m}`; };
try {
  import * as THREE from "https://cdn.skypack.dev/three@0.152.0";
  window.THREE = THREE;
  \(code)
} catch(e) { document.getElementById("err").textContent = e.toString(); }
</script></body></html>
"""

        case "react":
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{margin:0;background:#0d1117;color:#c9d1d9;font-family:sans-serif;}
#err{position:fixed;top:8px;left:8px;color:#ff6b6b;font:11px monospace;}</style>
</head><body>
<div id="root"></div><div id="err"></div>
<script crossorigin src="https://unpkg.com/react@18/umd/react.development.js"></script>
<script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
<script crossorigin src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
<script type="text/babel">
\(code)
try {
  const root = ReactDOM.createRoot(document.getElementById("root"));
  root.render(React.createElement(typeof App !== "undefined" ? App : () => React.createElement("p", null, "No App component exported")));
} catch(e) { document.getElementById("err").textContent = e.toString(); }
</script></body></html>
"""

        case "vue":
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{margin:0;background:#0d1117;color:#c9d1d9;font-family:sans-serif;padding:16px;}</style>
</head><body>
<div id="app"></div>
<script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
<script>
try {
  const { createApp } = Vue;
  \(code)
  const app = typeof App !== "undefined" ? createApp(App) : createApp({ template: "<p>No App exported</p>" });
  app.mount("#app");
} catch(e) { document.body.innerHTML += `<p style="color:#ff6b6b">${e}</p>`; }
</script></body></html>
"""

        case "python", "python_ml":
            let escaped = code
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://cdn.jsdelivr.net/pyodide/v0.26.2/full/pyodide.js"></script>
<style>
* { box-sizing:border-box; }
body { background:#0d1117; color:#c9d1d9; font-family:monospace; padding:12px; margin:0; }
#status { font-size:9px; color:#4a5568; margin-bottom:8px; letter-spacing:1px; }
#output { white-space:pre-wrap; font-size:12px; line-height:1.6; }
.err { color:#ff6b6b; } .log { color:#00ffcc; }
</style>
</head><body>
<div id="status">⏳ LOADING PYTHON…</div>
<div id="output"></div>
<script>
const out = document.getElementById("output");
const status = document.getElementById("status");
async function main() {
  try {
    const py = await loadPyodide({
      stdout: (s) => { out.innerHTML += `<span class="log">${s}</span>\n`; },
      stderr: (s) => { out.innerHTML += `<span class="err">${s}</span>\n`; }
    });
    status.textContent = "▶ RUNNING…";
    await py.runPythonAsync(`\(escaped)`);
    status.textContent = "✓ COMPLETE";
  } catch(e) {
    out.innerHTML += `<span class="err">Error: ${e}</span>\n`;
    status.textContent = "✗ ERROR";
  }
}
main();
</script></body></html>
"""

        case "php":
            let escaped = code.replacingOccurrences(of: "`", with:"\\`")
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body { background:#0d1117; color:#c9d1d9; font-family:monospace; padding:12px; }
#status { font-size:9px; color:#4a5568; margin-bottom:8px; letter-spacing:1px; }
#output { white-space:pre-wrap; font-size:12px; }
.err { color:#ff6b6b; }
</style>
</head><body>
<div id="status">⏳ LOADING PHP…</div>
<div id="output"></div>
<script>
const status = document.getElementById("status");
const out    = document.getElementById("output");
// PHP-WASM via official CDN
async function runPHP() {
  try {
    const { PhpWasm } = await import("https://cdn.jsdelivr.net/npm/@php-wasm/node@0.0.9/build/php-8.2.js");
    status.textContent = "▶ RUNNING PHP…";
    const result = await PhpWasm.run(`\(escaped)`);
    out.textContent = result.stdout;
    if (result.stderr) out.innerHTML += `<span class="err">${result.stderr}</span>`;
    status.textContent = "✓ COMPLETE";
  } catch(e) {
    // Fallback: show PHP source with syntax highlighting note
    out.innerHTML = `<span class="err">PHP-WASM unavailable in this environment.<br>Your PHP code is ready — export and run on a PHP server.</span>\n\n` + `\(escaped.replacingOccurrences(of:"<",with:"&lt;"))`;
    status.textContent = "✗ PHP-WASM NOT AVAILABLE";
  }
}
runPHP();
</script></body></html>
"""

        case "sql":
            let escaped = code.replacingOccurrences(of: "`", with:"\\`")
            return """
<!DOCTYPE html><html><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://cdn.jsdelivr.net/npm/sql.js@1.10.2/dist/sql-wasm.js"></script>
<style>
body { background:#0d1117; color:#c9d1d9; font-family:monospace; padding:12px; }
#status { font-size:9px; color:#4a5568; margin-bottom:8px; letter-spacing:1px; }
table { border-collapse:collapse; margin:8px 0; width:100%; }
th { background:#161b22; color:#58a6ff; padding:6px 12px; border:1px solid #30363d; text-align:left; font-size:11px; }
td { padding:6px 12px; border:1px solid #21262d; font-size:11px; }
.err { color:#ff6b6b; } .ok { color:#3fb950; }
</style>
</head><body>
<div id="status">⏳ LOADING SQL.js…</div>
<div id="output"></div>
<script>
const status = document.getElementById("status");
const out    = document.getElementById("output");
initSqlJs({ locateFile: f => `https://cdn.jsdelivr.net/npm/sql.js@1.10.2/dist/${f}` }).then(SQL => {
  status.textContent = "▶ EXECUTING SQL…";
  const db = new SQL.Database();
  try {
    const stmts = db.exec(`\(escaped)`);
    if (!stmts.length) {
      out.innerHTML = `<div class="ok">✓ Query executed successfully (no rows returned)</div>`;
    } else {
      stmts.forEach(stmt => {
        const tbl = document.createElement("table");
        const hdr = tbl.createTHead().insertRow();
        stmt.columns.forEach(c => { const th = document.createElement("th"); th.textContent=c; hdr.appendChild(th); });
        const body = tbl.createTBody();
        stmt.values.forEach(row => {
          const tr = body.insertRow();
          row.forEach(v => { const td = tr.insertCell(); td.textContent = v===null?"NULL":v; });
        });
        out.appendChild(tbl);
        out.innerHTML += `<div class="ok" style="font-size:9px;margin:4px 0">${stmt.values.length} row(s)</div>`;
      });
    }
    status.textContent = "✓ COMPLETE";
  } catch(e) {
    out.innerHTML = `<div class="err">SQL Error: ${e.message}</div>`;
    status.textContent = "✗ ERROR";
  }
});
</script></body></html>
"""
        default:
            return "<html><body style='background:#0d1117;color:#c9d1d9;font-family:monospace;padding:16px'><p>Cannot render \(language) in browser.</p></body></html>"
        }
    }

    // MARK: - Judge0 Remote Compiler (secondary — requires RapidAPI key)

    private func executeJudge0(code: String, language: String, stdin: String) async {
        // Judge0 CE requires a RapidAPI key. Without it returns 401.
        // We try it but fall back to Piston immediately on auth failure.
        guard let langId = Judge0Language.from(languageId: language) else {
            await executePiston(code: code, language: language, stdin: stdin)
            return
        }

        // ce.judge0.com — free public Judge0 instance, no API key required
        let submitURL = URL(string: "\(judge0Base)/submissions/?base64_encoded=false&wait=true")!
        var req = URLRequest(url: submitURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "language_id":    langId.rawValue,
            "source_code":    code,
            "stdin":          stdin,
            "cpu_time_limit": 10,
            "memory_limit":   262144
        ] as [String: Any])

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode >= 400 {
                // Judge0 unavailable — try Piston
                await executePiston(code: code, language: language, stdin: stdin)
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                await executePiston(code: code, language: language, stdin: stdin)
                return
            }
            await parseJudge0Response(json, language: language)
        } catch {
            await executePiston(code: code, language: language, stdin: stdin)
        }
    }

    private func parseJudge0Response(_ json: [String: Any], language: String) async {
        // ce.judge0.com returns plain strings (not base64)
        let stdout     = (json["stdout"]         as? String) ?? ""
        let stderr     = (json["stderr"]         as? String) ?? ""
        let compileErr = (json["compile_output"] as? String) ?? ""
        let time       = (json["time"]           as? String) ?? "–"
        let mem        = json["memory"] != nil ? "\(json["memory"]!) KB" : "–"
        let statusId   = (json["status"] as? [String: Any])?["id"] as? Int ?? 3
        // Status 3 = Accepted, anything else = error
        let exitCode   = (statusId == 3) ? 0 : 1

        result = ExecutionResult(
            stdout: stdout.trimmingCharacters(in: .newlines),
            stderr: stderr.trimmingCharacters(in: .newlines),
            compileError: compileErr.trimmingCharacters(in: .newlines),
            exitCode: exitCode, time: "\(time)s", memory: mem,
            webHTML: nil, language: language
        )
    }

    // MARK: - Piston Remote Executor (fallback)

    private func executePiston(code: String, language: String, stdin: String) async {
        // Map language ID to Piston language name + version
        // Piston API — free, no auth required, primary for compiled languages
        // Versions sourced from: https://emkc.org/api/v2/piston/runtimes
        let pistonMap: [String: (String, String)] = [
            "cpp":       ("c++",    "*"),   // latest
            "c":         ("c",      "*"),
            "java":      ("java",   "*"),
            "python":    ("python", "*"),
            "python_ml": ("python", "*"),
            "go":        ("go",     "*"),
            "rust":      ("rust",   "*"),
            "swift":     ("swift",  "*"),
            "kotlin":    ("kotlin", "*"),
            "ruby":      ("ruby",   "*"),
            "bash":      ("bash",   "*"),
            "dart":      ("dart",   "*"),
            "r":         ("r",      "*"),
            "php":       ("php",    "*"),
            "csharp":    ("mono",   "*"),   // C# on Piston uses "mono"
            "typescript":("typescript","*"),
        ]

        guard let (pistonLang, version) = pistonMap[language] else {
            result = ExecutionResult(
                stdout: "", stderr: "Language '\(language)' not supported by remote compiler.",
                compileError: "", exitCode: 1, time: "–", memory: "–",
                webHTML: nil, language: language
            )
            return
        }

        let url = URL(string: "\(pistonBase)/execute")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let ext: String
        switch language {
        case "cpp": ext = "cpp"
        case "c": ext = "c"
        case "java": ext = "java"
        case "python","python_ml": ext = "py"
        case "go": ext = "go"
        case "rust": ext = "rs"
        case "swift": ext = "swift"
        case "kotlin": ext = "kt"
        case "ruby": ext = "rb"
        case "bash": ext = "sh"
        case "dart": ext = "dart"
        case "r": ext = "r"
        case "php": ext = "php"
        case "csharp": ext = "cs"
        default: ext = "txt"
        }

        let body: [String: Any] = [
            "language": pistonLang,
            "version": version,
            "files": [["name": "main.\(ext)", "content": code]],
            "stdin": stdin
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let run    = json["run"] as? [String: Any]
                let comp   = json["compile"] as? [String: Any]
                let stdout = run?["stdout"] as? String ?? ""
                let stderr = run?["stderr"] as? String ?? ""
                let compErr = comp?["stderr"] as? String ?? ""
                let exit   = run?["code"] as? Int ?? 0

                result = ExecutionResult(
                    stdout: stdout, stderr: stderr, compileError: compErr,
                    exitCode: exit, time: "–", memory: "–",
                    webHTML: nil, language: language
                )
            } else {
                result = ExecutionResult(
                    stdout: "", stderr: "Remote compiler unavailable. Check your connection.",
                    compileError: "", exitCode: 1, time: "–", memory: "–",
                    webHTML: nil, language: language
                )
            }
        } catch {
            result = ExecutionResult(
                stdout: "", stderr: "Network error: \(error.localizedDescription)",
                compileError: "", exitCode: 1, time: "–", memory: "–",
                webHTML: nil, language: language
            )
        }
    }
}

// MARK: - Execution Output View

struct IDEExecutionOutputView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @StateObject private var service = IDECompilerService.shared
    @State private var webLoading  = false
    @State private var desktopMode = false  // mobile/desktop view toggle

    // Viewport widths: mobile=390pt, desktop=1280pt (scales inside WKWebView)
    private let mobileWidth:  CGFloat = 390
    private let desktopWidth: CGFloat = 1280

    var body: some View {
        VStack(spacing: 0) {
            // ── Output header ──────────────────────────────────
            HStack(spacing: 8) {
                if service.isRunning {
                    ProgressView().scaleEffect(0.7).tint(themeVM.accent)
                    Text("COMPILING…")
                        .font(.system(size:9,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.accent).kerning(1.5)
                } else if let r = service.result {
                    Image(systemName: r.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size:12))
                        .foregroundColor(r.success ? Color(hex:"#3fb950") : .red)
                    Text(outputHeader(r))
                        .font(.system(size:9,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.dim).kerning(1.5)
                } else {
                    Text("◈ OUTPUT")
                        .font(.system(size:9,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.dim).kerning(2)
                }
                Spacer()

                // Mobile / Desktop toggle (only for web output)
                if service.result?.webHTML != nil {
                    HStack(spacing: 0) {
                        Button {
                            withAnimation(.spring(response:0.25,dampingFraction:0.85)) {
                                desktopMode = false
                            }
                        } label: {
                            Image(systemName: "iphone")
                                .font(.system(size:11))
                                .foregroundColor(!desktopMode ? .black : themeVM.dim)
                                .padding(.horizontal,8).padding(.vertical,5)
                                .background(!desktopMode
                                    ? Color(hex: IDELanguageStore.shared.activeEnv.color)
                                    : Color.clear)
                                .cornerRadius(6)
                        }
                        Button {
                            withAnimation(.spring(response:0.25,dampingFraction:0.85)) {
                                desktopMode = true
                            }
                        } label: {
                            Image(systemName: "desktopcomputer")
                                .font(.system(size:11))
                                .foregroundColor(desktopMode ? .black : themeVM.dim)
                                .padding(.horizontal,8).padding(.vertical,5)
                                .background(desktopMode
                                    ? Color(hex: IDELanguageStore.shared.activeEnv.color)
                                    : Color.clear)
                                .cornerRadius(6)
                        }
                    }
                    .background(Color(hex:"#161b22"))
                    .cornerRadius(7)
                    .overlay(RoundedRectangle(cornerRadius:7)
                        .stroke(Color(hex:"#30363d"),lineWidth:0.5))
                }

                if let r = service.result, !r.time.isEmpty && r.time != "–" {
                    Text(r.time)
                        .font(.system(size:8,design:.monospaced))
                        .foregroundColor(themeVM.dim)
                }

                Button {
                    IDELanguageStore.shared.setEnvFromFilename(ideVM.currentFile)
                    let lang = IDELanguageStore.shared.activeEnv.id
                    let projFiles = gatherProjectFiles()
                    Task { await service.execute(code: ideVM.sourceCode, language: lang,
                                                 projectFiles: projFiles) }
                } label: {
                    HStack(spacing:4) {
                        Image(systemName:"play.fill").font(.system(size:9))
                        Text("RUN").font(.system(size:9,weight:.semibold,design:.monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal,10).padding(.vertical,5)
                    .background(Color(hex: IDELanguageStore.shared.activeEnv.color))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal,14).padding(.vertical,8)
            .background(themeVM.bg)
            .overlay(Divider().background(themeVM.accent.opacity(0.15)), alignment:.bottom)

            // ── Output body ────────────────────────────────────
            if service.isRunning {
                Spacer()
                VStack(spacing:8) {
                    ProgressView().tint(themeVM.accent)
                    Text("Running \(IDELanguageStore.shared.activeEnv.name)…")
                        .font(.system(size:11,design:.monospaced)).foregroundColor(themeVM.dim)
                }
                Spacer()
            } else if let r = service.result {
                if let html = r.webHTML {
                    // Web render with mobile/desktop viewport injection
                    IDEWebOutputView(
                        html: injectViewport(html: html, desktop: desktopMode),
                        isLoading: $webLoading
                    )
                    .id(desktopMode) // forces WKWebView reload on mode change
                } else {
                    // Terminal-style text output
                    ScrollView {
                        VStack(alignment:.leading, spacing:0) {
                            if !r.compileError.isEmpty {
                                outputBlock(r.compileError, label:"COMPILE ERROR", color:"#ff6b6b")
                            }
                            if !r.stdout.isEmpty {
                                outputBlock(r.stdout, label:"STDOUT", color:"#00ffcc")
                            }
                            if !r.stderr.isEmpty {
                                outputBlock(r.stderr, label:"STDERR", color:"#ff6b6b")
                            }
                            if r.stdout.isEmpty && r.stderr.isEmpty && r.compileError.isEmpty {
                                Text("(No output)")
                                    .font(.system(size:11,design:.monospaced))
                                    .foregroundColor(themeVM.dim).padding(14)
                            }
                        }
                    }
                    .background(themeVM.bg)
                }
            } else {
                // Empty state
                VStack(spacing:12) {
                    let env = IDELanguageStore.shared.activeEnv
                    Image(systemName: env.icon)
                        .font(.system(size:36))
                        .foregroundColor(Color(hex:env.color).opacity(0.3))
                    Text("Press RUN to execute \(env.name)")
                        .font(.system(size:11,design:.monospaced))
                        .foregroundColor(themeVM.dim)
                    Text("⟳ Compiled via Piston (C++, Java, Go, Rust…) or WebView (HTML, Python, JS)")
                        .font(.system(size:9,design:.monospaced))
                        .foregroundColor(themeVM.dim.opacity(0.5))
                        .multilineTextAlignment(.center).padding(.horizontal,20)
                }
                .frame(maxWidth:.infinity,maxHeight:.infinity)
                .background(themeVM.bg)
            }
        }
    }

    private func outputHeader(_ r: ExecutionResult) -> String {
        if !r.compileError.isEmpty { return "COMPILE ERROR" }
        if r.exitCode != 0 { return "RUNTIME ERROR (exit \(r.exitCode))" }
        return "✓ COMPLETE"
    }

    // Gather all files in the active project for HTML inlining
    private func gatherProjectFiles() -> [String: String] {
        guard let proj = IDEProjectStore.shared.activeProject else { return [:] }
        var files: [String: String] = [:]
        for path in proj.allFilePaths {
            let content = IDEProjectStore.shared.readFile(in: proj.id, path: path)
            let name = URL(fileURLWithPath: path).lastPathComponent
            files[name] = content
            files[path] = content
        }
        return files
    }

    // Inject correct viewport meta for mobile/desktop mode
    private func injectViewport(html: String, desktop: Bool) -> String {
        let meta = desktop
            ? "<meta name=\"viewport\" content=\"width=1280\">"
            : "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        // Replace existing viewport meta if present
        if html.range(of: "<meta[^>]+viewport[^>]*>", options: .regularExpression) != nil {
            return html.replacingOccurrences(
                of: "<meta[^>]+viewport[^>]*>", with: meta, options: .regularExpression)
        } else if html.contains("<head>") {
            return html.replacingOccurrences(of: "<head>", with: "<head>" + meta)
        } else {
            return meta + html
        }
    }

    @ViewBuilder
    private func outputBlock(_ text: String, label: String, color: String) -> some View {
        VStack(alignment:.leading, spacing:4) {
            Text(label)
                .font(.system(size:7,weight:.bold,design:.monospaced))
                .foregroundColor(Color(hex:color)).kerning(1.5)
                .padding(.horizontal,14).padding(.top,10)
            Text(text)
                .font(.system(size:11,design:.monospaced))
                .foregroundColor(Color(hex:color))
                .textSelection(.enabled)
                .padding(.horizontal,14).padding(.bottom,10)
        }
    }
}

// Reuse the WKWebView wrapper from IDECodeRunner
// IDEWebOutputView is already defined there
