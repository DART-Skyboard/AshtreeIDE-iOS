// ============================================================
//  LeatrEngine.swift — Full LEATR v2 Compiler Engine
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Port of the web app's DART_PROCESSOR / leatrCompile() function,
//  syntaxdefinitions.json, instructionset.json, outputdefinitions.json
// ============================================================

import Foundation
import SwiftUI

// MARK: - Token

public struct AshToken {
    public enum Kind: String {
        case comment, nodeBlockStart, nodeBlockEnd, nodeBlockEndChain
        case blockOpen, blockClose
        case outerTag, innerTag, polyTag, netTag
        case importStmt, keyword, declaration, naturalTool
        case pipeSep, chainSep, op
        case nodeRef, varRef, string, number, identifier, whitespace, unknown
    }
    public let kind: Kind
    public let value: String
}

// MARK: - AST

public struct AshAST {
    public var type: String
    public var name: String
    public var children: [AshAST]
    public var value: String

    public init(type: String, name: String = "", value: String = "", children: [AshAST] = []) {
        self.type = type; self.name = name; self.value = value; self.children = children
    }
}

// MARK: - Compiler Output

public struct CompilerLine: Identifiable {
    public let id = UUID()
    public let label: String
    public let text: String
    public let color: String   // hex
    public let isError: Bool
}

public struct TerminalLine: Identifiable {
    public let id = UUID()
    public let text: String
    public let color: String
    public let isSystem: Bool
}

// MARK: - LEATR Engine

@MainActor
public final class LeatrEngine: ObservableObject {

    // ── Published state ─────────────────────────────────────────
    @Published public var compilerLines: [CompilerLine] = []
    @Published public var terminalLines: [TerminalLine] = []
    @Published public var isRunning = false
    @Published public var nodeCount = 0
    @Published public var shellType = "—"
    @Published public var buoyancy: Double = 0

    // Compiler definition data (loaded from GitHub raw)
    public var syntaxDefs: Any?
    public var instructionSet: Any?
    public var outputTemplates: Any?
    public var isDefsLoaded = false

    // ── Keyword/token sets (from syntaxdefinitions.json) ────────
    public static let keywords: Set<String> = ["irin","irout","thenplace","Research","Report"]
    public static let declarations: Set<String> = [
        "with","var","Var","Input","when","where","and","or","not",
        "for","else","is","if","end","import","return","place","placeto"
    ]
    public static let naturalTools: Set<String> = [
        "Maze","Puzzle","Envelope","Hammer","Stick","Knife","Scissors"
    ]

    // Switch equations: (xa²√xa) ±1
    public static func encode(_ x: Double, _ a: Double) -> Double {
        let v = x * a * a * sqrt(abs(x * a)); return v.isNaN ? 0 : v - 1
    }
    public static func decode(_ x: Double, _ a: Double) -> Double {
        let v = x * a * a * sqrt(abs(x * a)); return v.isNaN ? 0 : v + 1
    }

    // ── Lexer ────────────────────────────────────────────────────
    public func lex(_ source: String) -> [AshToken] {
        var tokens: [AshToken] = []
        var i = source.startIndex

        func peek(_ n: Int = 1) -> Character? {
            guard let idx = source.index(i, offsetBy: n, limitedBy: source.endIndex),
                  idx < source.endIndex else { return nil }
            return source[idx]
        }
        func advance() { if i < source.endIndex { i = source.index(after: i) } }
        func current() -> Character { i < source.endIndex ? source[i] : "\0" }
        func rest() -> String { String(source[i...]) }

        while i < source.endIndex {
            let c = current()

            // Comment
            if c == "/" && peek() == "/" {
                var end = i
                while end < source.endIndex && source[end] != "\n" { end = source.index(after: end) }
                tokens.append(AshToken(kind: .comment, value: String(source[i..<end])))
                i = end; continue
            }

            // {{outer-tag}}
            if c == "{" && peek() == "{" {
                var j = source.index(i, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                while j < source.endIndex {
                    if source[j] == "}" && (source.index(after: j) < source.endIndex ? source[source.index(after: j)] == "}" : false) {
                        j = source.index(j, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex; break
                    }
                    j = source.index(after: j)
                }
                tokens.append(AshToken(kind: .outerTag, value: String(source[i..<j])))
                i = j; continue
            }

            // [[inner-tag]]
            if c == "[" && peek() == "[" {
                var j = source.index(i, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                while j < source.endIndex {
                    if source[j] == "]" && (source.index(after: j) < source.endIndex ? source[source.index(after: j)] == "]" : false) {
                        j = source.index(j, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex; break
                    }
                    j = source.index(after: j)
                }
                tokens.append(AshToken(kind: .innerTag, value: String(source[i..<j])))
                i = j; continue
            }

            // [poly:...] or [net:...]
            if c == "[" {
                var j = source.index(after: i)
                while j < source.endIndex && source[j] != "]" { j = source.index(after: j) }
                if j < source.endIndex { j = source.index(after: j) }
                let tag = String(source[i..<j])
                tokens.append(AshToken(kind: tag.hasPrefix("[net:") ? .netTag : .polyTag, value: tag))
                i = j; continue
            }

            // String literal
            if c == "\"" {
                var j = source.index(after: i)
                while j < source.endIndex && source[j] != "\"" {
                    if source[j] == "\\" { j = source.index(after: j) }
                    if j < source.endIndex { j = source.index(after: j) }
                }
                if j < source.endIndex { j = source.index(after: j) }
                tokens.append(AshToken(kind: .string, value: String(source[i..<j])))
                i = j; continue
            }

            // }|';'| — node end
            if c == "}" {
                let r = String(source[i...])
                if r.hasPrefix("}|';'|") {
                    tokens.append(AshToken(kind: .nodeBlockEnd, value: "}|';'|"))
                    i = source.index(i, offsetBy: 6, limitedBy: source.endIndex) ?? source.endIndex
                    continue
                }
                tokens.append(AshToken(kind: .blockClose, value: "}"))
                advance(); continue
            }

            // (NodeName):-:{ or node ref
            if c == "(" {
                var j = source.index(after: i)
                while j < source.endIndex && source[j] != ")" { j = source.index(after: j) }
                if j < source.endIndex { j = source.index(after: j) }
                let inner = String(source[source.index(after: i)..<source.index(before: j)])
                let afterParen = String(source[j...]).trimmingCharacters(in: .whitespaces)
                if afterParen.hasPrefix(":-:") {
                    // Find {
                    var k = j
                    while k < source.endIndex && source[k] != "{" { k = source.index(after: k) }
                    if k < source.endIndex { k = source.index(after: k) }
                    tokens.append(AshToken(kind: .nodeBlockStart, value: inner))
                    i = k; continue
                }
                let firstChar = inner.first ?? "a"
                tokens.append(AshToken(kind: firstChar.isUppercase ? .nodeRef : .varRef,
                                       value: "(\(inner))"))
                i = j; continue
            }

            // |';'| pipe separator
            if c == "|" {
                let r = String(source[i...])
                if r.hasPrefix("|';'|") {
                    tokens.append(AshToken(kind: .pipeSep, value: "|';'|"))
                    i = source.index(i, offsetBy: 5, limitedBy: source.endIndex) ?? source.endIndex
                    continue
                }
            }

            // Number
            if c.isNumber || (c == "-" && peek()?.isNumber == true) {
                var j = source.index(after: i)
                while j < source.endIndex && (source[j].isNumber || source[j] == ".") { j = source.index(after: j) }
                tokens.append(AshToken(kind: .number, value: String(source[i..<j])))
                i = j; continue
            }

            // Word
            if c.isLetter || c == "_" {
                var j = source.index(after: i)
                while j < source.endIndex && (source[j].isLetter || source[j].isNumber || source[j] == "_") {
                    j = source.index(after: j)
                }
                let word = String(source[i..<j])
                let kind: AshToken.Kind
                if word == "import" { kind = .importStmt }
                else if Self.keywords.contains(word) { kind = .keyword }
                else if Self.declarations.contains(word) { kind = .declaration }
                else if Self.naturalTools.contains(word) { kind = .naturalTool }
                else { kind = .identifier }
                tokens.append(AshToken(kind: kind, value: word))
                i = j; continue
            }

            // Operators
            if "=+\\-*/^!<>".contains(c) {
                tokens.append(AshToken(kind: .op, value: String(c)))
                advance(); continue
            }

            advance()
        }
        return tokens
    }

    // ── Parser ───────────────────────────────────────────────────
    public func parse(_ tokens: [AshToken]) -> AshAST {
        var root = AshAST(type: "Program")
        var i = 0

        while i < tokens.count {
            let t = tokens[i]
            switch t.kind {
            case .outerTag, .innerTag, .polyTag, .netTag:
                root.children.append(AshAST(type: "TagAnnotation", value: t.value))
                i += 1

            case .importStmt:
                // import (ModuleName)
                let module = (i+1 < tokens.count) ? tokens[i+1].value : ""
                root.children.append(AshAST(type: "ImportStatement", name: module, value: module))
                i += 2

            case .nodeBlockStart:
                var node = AshAST(type: "NodeBlock", name: t.value)
                i += 1
                var depth = 0
                while i < tokens.count {
                    let inner = tokens[i]
                    if inner.kind == .nodeBlockEnd && depth == 0 { i += 1; break }
                    if inner.kind == .blockOpen { depth += 1 }
                    if inner.kind == .blockClose { depth -= 1 }
                    // Parse child nodes
                    if inner.kind == .outerTag || inner.kind == .innerTag ||
                       inner.kind == .polyTag  || inner.kind == .netTag {
                        node.children.append(AshAST(type: "TagAnnotation", value: inner.value))
                    } else if inner.kind == .keyword {
                        let val = (i+1 < tokens.count && tokens[i+1].kind == .string)
                            ? tokens[i+1].value : ""
                        node.children.append(AshAST(type: "KeywordStatement",
                                                    name: inner.value, value: val))
                        if !val.isEmpty { i += 1 }
                    } else if inner.kind == .naturalTool {
                        node.children.append(AshAST(type: "NaturalToolCall", name: inner.value))
                    } else if inner.kind == .declaration && inner.value == "var" {
                        let vName = (i+1 < tokens.count) ? tokens[i+1].value : ""
                        node.children.append(AshAST(type: "VarDeclaration", name: vName))
                        i += 1
                    } else if inner.kind == .importStmt {
                        let module = (i+1 < tokens.count) ? tokens[i+1].value : ""
                        node.children.append(AshAST(type: "ImportStatement", name: module))
                        i += 1
                    }
                    i += 1
                }
                root.children.append(node)

            default:
                i += 1
            }
        }
        return root
    }

    // ── BRPN — Buoyancy Reflex Pendulum Node ────────────────────
    public struct BRPNResult {
        public let f, r, p, frp, buoyancy: Double
        public let shell: String
        public let qsVal: Double
        public let encodeValue: Double
        public let decodeValue: Double
    }

    public func brpn(nodeCount nc: Int, hasOuter: Bool, hasInner: Bool) -> BRPNResult {
        let f = hasOuter ? 1.0 : 0.5
        let r = hasInner ? 1.0 : 0.4
        let p = nc > 0 ? min(1.0, Double(nc) / 5.0) : 0.1
        let frp = f * r * p
        let b = frp * sqrt(abs(frp))
        let shell = b >= 0.76 ? "GEOLOGICAL" : b >= 0.44 ? "MARITIME" : "AEROSPACE"
        let n = Double(max(nc, 1))
        let qs = f * r * p * log(n + 1)
        return BRPNResult(f: f, r: r, p: p, frp: frp, buoyancy: b, shell: shell,
                          qsVal: qs,
                          encodeValue: Self.encode(n, n),
                          decodeValue: Self.decode(n, n))
    }

    // ── Full Compile ─────────────────────────────────────────────
    public func compile(source: String, netMode: Bool = false) {
        compilerLines = []
        let tokens = lex(source)
        let ast = parse(tokens)
        let nodes = ast.children.filter { $0.type == "NodeBlock" }
        let imports = ast.children.filter { $0.type == "ImportStatement" }
        let outerTags = ast.children.filter { $0.type == "TagAnnotation" && $0.value.hasPrefix("{{") }
        let innerTags = ast.children.filter { $0.type == "TagAnnotation" && $0.value.hasPrefix("[[") }

        func log(_ label: String, _ text: String, _ color: String = "#8ab4cc", err: Bool = false) {
            compilerLines.append(CompilerLine(label: label, text: text, color: color, isError: err))
        }

        log("SYSTEM", "LEATR v2 Compiler · Ash Edge Language", "#00ffcc")
        log("1. LEXER", "\(tokens.count) tokens", "#4a8a7a")

        // Global tags
        for t in outerTags { log("{{OUTER}}", t.value, "#ffd700") }
        for t in innerTags { log("[[INNER]]", t.value, "#bf5fff") }
        ast.children.filter { $0.type == "TagAnnotation" && $0.value.hasPrefix("[poly:") }
            .forEach { log("[POLY]", $0.value, "#ff9500") }
        ast.children.filter { $0.type == "TagAnnotation" && $0.value.hasPrefix("[net:") }
            .forEach { log("[NET]", $0.value, "#39ff14") }

        for imp in imports { log("↑ import", imp.name, "#ce9178") }

        log("2. PARSER", "\(ast.children.count) top-level nodes", "#4a8a7a")

        if netMode {
            log("NET", "⟳ Network compile — log-iterative mode", "#39ff14")
            for (idx, node) in nodes.enumerated() {
                let lv = Foundation.log(Double(idx + 1) + 1)
                log("NET", "[\(idx+1)] \(node.name): log(n)=\(String(format:"%.4f",lv))", "#39ff14")
            }
        } else {
            for (idx, node) in nodes.enumerated() {
                let nc = Double(idx + 1)
                log("SWITCH ON", "\(node.name) encode=\(String(format:"%.4f",Self.encode(nc,nc)))", "#00ffcc")
                for child in node.children {
                    switch child.type {
                    case "TagAnnotation":
                        if child.value.hasPrefix("{{") { log("{{OUTER}}", child.value, "#ffd700") }
                        else if child.value.hasPrefix("[[") { log("[[INNER]]", child.value, "#bf5fff") }
                        else if child.value.hasPrefix("[poly:") { log("[POLY]", child.value, "#ff9500") }
                        else if child.value.hasPrefix("[net:") { log("[NET]", child.value, "#39ff14") }
                    case "KeywordStatement":
                        let icon = child.name == "irin" ? "→" : child.name == "irout" ? "←" : "⟳"
                        log("\(icon) \(child.name)", child.value, "#9cdcfe")
                    case "NaturalToolCall":
                        log("🔧 tool", "\(child.name) [OOO]", "#00ffcc")
                    case "VarDeclaration":
                        log("  var", child.name, "#9cdcfe")
                    case "ImportStatement":
                        log("↑ import", child.name, "#ce9178")
                    default: break
                    }
                }
                log("SWITCH OFF", "\(node.name) decode=\(String(format:"%.4f",Self.decode(nc,nc)))", "#4a8a7a")
                log("✓ NODE", node.name, "#00cc66")
            }
        }

        let result = brpn(nodeCount: nodes.count,
                          hasOuter: !outerTags.isEmpty,
                          hasInner: !innerTags.isEmpty)
        log("PENDULUM", "f=\(String(format:"%.2f",result.f)) r=\(String(format:"%.2f",result.r)) p=\(String(format:"%.3f",result.p))", "#a78bfa")
        log("BUOYANCY", "\(String(format:"%.4f",result.buoyancy)) → \(result.shell)", "#a78bfa")
        log("QS", "QuantumSocket: \(String(format:"%.4f",result.qsVal))", "#a78bfa")
        log("COMPLETE", "\(nodes.count) nodes · \(result.shell) shell", "#00ffcc")

        nodeCount = nodes.count
        shellType = result.shell
        buoyancy  = result.buoyancy

        // Mirror to terminal
        terminalLines.append(TerminalLine(text: "[SYS] ─────────────────────────────", color: "#4a8a7a", isSystem: true))
        terminalLines.append(TerminalLine(text: "[SYS] LEATR App Runtime v2.0", color: "#00ffcc", isSystem: true))
        terminalLines.append(TerminalLine(text: "[SYS] Compiled: \(nodes.count) node(s) · \(result.shell)", color: "#8ab4cc", isSystem: true))
        terminalLines.append(TerminalLine(text: "[SYS] Buoyancy: \(String(format:"%.4f",result.buoyancy))", color: "#a78bfa", isSystem: true))
        for node in nodes {
            terminalLines.append(TerminalLine(text: "ash ▸ run \(node.name)", color: "#00ffcc", isSystem: false))
            let irin = node.children.first { $0.type == "KeywordStatement" && $0.name == "irin" }
            if let v = irin?.value { terminalLines.append(TerminalLine(text: "  → irin: \(v)", color: "#4a8a7a", isSystem: false)) }
            terminalLines.append(TerminalLine(text: "  → \(node.name) executed.", color: "#ffffff", isSystem: false))
        }
    }

    // ── Auto-load LEATR defs from GitHub ─────────────────────────
    public func autoLoadDefs() async {
        let base = "https://raw.githubusercontent.com/DART-Skyboard/Ariel/main/dartide/"
        let urls = [
            ("syntax", "\(base)syntaxdefinitions.json"),
            ("exec",   "\(base)instructionset.json"),
            ("template", "\(base)outputdefinitions.json")
        ]
        for (type, urlStr) in urls {
            guard let url = URL(string: urlStr),
                  let data = try? await URLSession.shared.data(from: url).0,
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            await MainActor.run {
                if type == "syntax" { syntaxDefs = json }
                else if type == "exec" { instructionSet = json }
                else { outputTemplates = json }
                compilerLines.append(CompilerLine(label: "AUTO-LOAD", text: "Loaded \(type) definitions from GitHub", color: "#00cc66", isError: false))
            }
        }
        await MainActor.run { isDefsLoaded = true }
    }

    // ── Terminal command handler ─────────────────────────────────
    public func handleTerminalCommand(_ cmd: String, source: String) {
        let c = cmd.trimmingCharacters(in: .whitespaces).lowercased()
        terminalLines.append(TerminalLine(text: "ash ▸ \(cmd)", color: "#00ffcc", isSystem: false))
        switch c {
        case "run":   compile(source: source)
        case "clear": terminalLines = []; compilerLines = []
        case "info":
            terminalLines.append(TerminalLine(text: "  LEATR v2 · Ash Edge Language · DART Meadow", color: "#8ab4cc", isSystem: true))
            terminalLines.append(TerminalLine(text: "  Compiler Standard: (xa²√xa)±1", color: "#8ab4cc", isSystem: true))
        case "help":
            terminalLines.append(TerminalLine(text: "  Commands: run · info · clear · exit · help", color: "#8ab4cc", isSystem: true))
        case "exit":
            terminalLines.append(TerminalLine(text: "  Session ended.", color: "#4a8a7a", isSystem: true))
        default:
            terminalLines.append(TerminalLine(text: "  Unknown: '\(cmd)' — type 'help'", color: "#ff9500", isSystem: false))
        }
    }
}

// log helper removed — use Foundation.log directly
