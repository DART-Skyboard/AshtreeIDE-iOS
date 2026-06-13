// ============================================================
//  LeatrCompiler.swift — LEATR v2 Compiler Engine
//  Lead Edge Ash Tree Reflex · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Architecture (from compiler standard):
//    {{outer-tag}}   — environment isolation shell
//    [[inner-tag]]   — user script ownership identity
//    [poly:...]      — polynomial/physics/math container (isolated from syntax)
//    [net:...]       — network syntax (logarithmic iterative form)
//    (NodeName):-:{  — switch OPEN  (xa²√xa) - 1  (0→1)
//    }|';'|          — switch CLOSE (xa²√xa) + 1  (1→0)
//    Pendulum Node   — FRP buoyancy + shell routing after compile
// ============================================================

import Foundation

// MARK: - Token Types

enum LeatrTokenType: Equatable {
    case outerTag       // {{env:...}}
    case innerTag       // [[script:...]]
    case polyTag        // [poly:...]
    case netTag         // [net:...]
    case nodeStart      // (NodeName):-:{
    case nodeEnd        // }|';'|
    case keyword        // irin, irout, thenplace, place, with, when, var, import
    case naturalTool    // Maze, Puzzle, Envelope, Hammer, Stick, Knife, Scissors
    case string         // "..."
    case identifier
    case comment
    case whitespace
    case unknown
}

struct LeatrToken {
    let type: LeatrTokenType
    let value: String
    let line: Int
}

// MARK: - AST

struct AshNodeBlock {
    let name: String
    var outerTags: [String]
    var innerTags: [String]
    var polyTags: [String]
    var netTags: [String]
    var body: [LeatrToken]
    var irinValue: String?
    var iroutValue: String?
}

struct AshAST {
    var globalOuter: [String] = []
    var globalInner: [String] = []
    var globalPoly: [String] = []
    var globalNet: [String] = []
    var nodes: [AshNodeBlock] = []
}

// MARK: - Compiler Log

struct CompilerLogEntry: Identifiable {
    let id = UUID()
    let type: String
    let message: String
    let color: String      // hex string for SwiftUI Color(hex:)
    let timestamp: Date
}

// MARK: - BRPN Result

struct BRPNResult {
    let f: Double
    let r: Double
    let p: Double
    let frp: Double
    let buoyancy: Double
    let shell: String   // GEOLOGICAL | MARITIME | AEROSPACE
    let qsVal: Double
    let encodeValue: Double
    let decodeValue: Double
}

// MARK: - LEATR v2 Compiler Engine

final class LeatrCompiler: ObservableObject {

    // Keyword and tool sets (from LEATR compiler standard)
    static let keywords: Set<String> = [
        "irin","irout","thenplace","place","with","when","where",
        "and","or","not","for","else","is","if","end","var","Var",
        "import","return","Research","Report"
    ]
    static let naturalTools: Set<String> = [
        "Maze","Puzzle","Envelope","Hammer","Stick","Knife","Scissors"
    ]
    static let orderOfOperations: [String] = [
        "Maze","Puzzle","Envelope","Hammer","Stick","Knife","Scissors",
        "Parentheses","Exponents","Multiplication","Division","Addition","Subtraction",
        "Logarithm","Trigonometry","Temperature","Velocity","Pressure","Mass",
        "Photosynthesis","Touch","Taste","Vision","Smell","Hear"
    ]

    // Switch equations from LEATR docs:
    // Encode (switch OPEN  0→1): (xa²√xa) - 1
    // Decode (switch CLOSE 1→0): (xa²√xa) + 1
    static func leatrEncode(_ x: Double, _ a: Double) -> Double {
        let v = x * a * a * sqrt(abs(x * a))
        return v.isNaN ? 0 : v - 1
    }
    static func leatrDecode(_ x: Double, _ a: Double) -> Double {
        let v = x * a * a * sqrt(abs(x * a))
        return v.isNaN ? 0 : v + 1
    }

    // Quantum Socket value
    static func quantumSocket(_ f: Double, _ n: Double, _ r: Double, _ p: Double) -> Double {
        return f * r * p * Foundation.log(max(n, 1) + 1)
    }

    // MARK: - Lexer

    func lex(_ source: String) -> [LeatrToken] {
        var tokens: [LeatrToken] = []
        var idx = source.startIndex
        var line = 1

        func peek(_ offset: Int = 1) -> Character? {
            let next = source.index(idx, offsetBy: offset, limitedBy: source.endIndex) ?? source.endIndex
            guard next < source.endIndex else { return nil }
            return source[next]
        }

        while idx < source.endIndex {
            let c = source[idx]

            if c == "\n" {
                line += 1; idx = source.index(after: idx); continue
            }
            if c.isWhitespace { idx = source.index(after: idx); continue }

            // Comment
            if c == "/" && peek() == "/" {
                var end = idx
                while end < source.endIndex && source[end] != "\n" { end = source.index(after: end) }
                tokens.append(LeatrToken(type: .comment, value: String(source[idx..<end]), line: line))
                idx = end; continue
            }

            // {{outer-tag}}
            if c == "{" && peek() == "{" {
                var j = source.index(idx, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                while j < source.endIndex {
                    if source[j] == "}" && (source.index(after: j) < source.endIndex ? source[source.index(after: j)] == "}" : false) {
                        j = source.index(j, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex; break
                    }
                    j = source.index(after: j)
                }
                tokens.append(LeatrToken(type: .outerTag, value: String(source[idx..<j]), line: line))
                idx = j; continue
            }

            // [[inner-tag]]
            if c == "[" && peek() == "[" {
                var j = source.index(idx, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex
                while j < source.endIndex {
                    if source[j] == "]" && (source.index(after: j) < source.endIndex ? source[source.index(after: j)] == "]" : false) {
                        j = source.index(j, offsetBy: 2, limitedBy: source.endIndex) ?? source.endIndex; break
                    }
                    j = source.index(after: j)
                }
                tokens.append(LeatrToken(type: .innerTag, value: String(source[idx..<j]), line: line))
                idx = j; continue
            }

            // [poly:...] or [net:...]
            if c == "[" {
                var j = source.index(after: idx)
                while j < source.endIndex && source[j] != "]" { j = source.index(after: j) }
                if j < source.endIndex { j = source.index(after: j) }
                let tag = String(source[idx..<j])
                let type: LeatrTokenType = tag.hasPrefix("[net:") ? .netTag : .polyTag
                tokens.append(LeatrToken(type: type, value: tag, line: line))
                idx = j; continue
            }

            // String literal
            if c == "\"" {
                var j = source.index(after: idx)
                while j < source.endIndex && source[j] != "\"" { j = source.index(after: j) }
                if j < source.endIndex { j = source.index(after: j) }
                tokens.append(LeatrToken(type: .string, value: String(source[idx..<j]), line: line))
                idx = j; continue
            }

            // }|';'| — node end
            if c == "}" {
                var j = source.index(after: idx)
                while j < source.endIndex && source[j] != "|" && source[j] != "\n" && source[j].isWhitespace {
                    j = source.index(after: j)
                }
                let rest = String(source[j...])
                if rest.hasPrefix("|';'|") {
                    j = source.index(j, offsetBy: 5, limitedBy: source.endIndex) ?? source.endIndex
                    tokens.append(LeatrToken(type: .nodeEnd, value: "}|';'|", line: line))
                    idx = j; continue
                }
                tokens.append(LeatrToken(type: .unknown, value: "}", line: line))
                idx = source.index(after: idx); continue
            }

            // (NodeName):-:{ — node start, or (var) group
            if c == "(" {
                var j = source.index(after: idx)
                while j < source.endIndex && source[j] != ")" { j = source.index(after: j) }
                if j < source.endIndex { j = source.index(after: j) }
                let inner = String(source[source.index(after: idx)..<source.index(before: j)])
                let rest = String(source[j...]).trimmingCharacters(in: .init(charactersIn: " "))
                if rest.hasPrefix(":-:{") || rest.hasPrefix(":-: {") {
                    let advance = rest.hasPrefix(":-: {") ? 5 : 4
                    // skip :-:{ or :-: {
                    var k = j
                    var skipped = 0
                    while k < source.endIndex && skipped < advance {
                        if !source[k].isWhitespace || skipped > 0 { skipped += 1 }
                        k = source.index(after: k)
                        if skipped == 0 && source[k].isWhitespace { continue }
                    }
                    tokens.append(LeatrToken(type: .nodeStart, value: inner, line: line))
                    // jump past :-:{
                    if let range = String(source[j...]).range(of: ":-:") {
                        var kk = source.index(j, offsetBy: String(source[j...]).distance(from: String(source[j...]).startIndex, to: range.upperBound))
                        while kk < source.endIndex && (source[kk] == " " || source[kk] == "{") {
                            if source[kk] == "{" { kk = source.index(after: kk); break }
                            kk = source.index(after: kk)
                        }
                        idx = kk
                    } else {
                        idx = j
                    }
                    continue
                }
                tokens.append(LeatrToken(type: .identifier, value: "(\(inner))", line: line))
                idx = j; continue
            }

            // Identifier / keyword / natural tool
            if c.isLetter || c == "_" {
                var j = source.index(after: idx)
                while j < source.endIndex && (source[j].isLetter || source[j].isNumber || source[j] == "_") {
                    j = source.index(after: j)
                }
                let word = String(source[idx..<j])
                let type: LeatrTokenType
                if Self.keywords.contains(word)     { type = .keyword }
                else if Self.naturalTools.contains(word) { type = .naturalTool }
                else                                { type = .identifier }
                tokens.append(LeatrToken(type: type, value: word, line: line))
                idx = j; continue
            }

            idx = source.index(after: idx)
        }
        return tokens
    }

    // MARK: - Parser

    func parse(_ tokens: [LeatrToken]) -> AshAST {
        var ast = AshAST()
        var i = 0

        while i < tokens.count {
            let tok = tokens[i]
            switch tok.type {
            case .outerTag: ast.globalOuter.append(tok.value); i += 1
            case .innerTag: ast.globalInner.append(tok.value); i += 1
            case .polyTag:  ast.globalPoly.append(tok.value);  i += 1
            case .netTag:   ast.globalNet.append(tok.value);   i += 1
            case .nodeStart:
                var node = AshNodeBlock(name: tok.value, outerTags: [], innerTags: [],
                                        polyTags: [], netTags: [], body: [])
                i += 1
                while i < tokens.count && tokens[i].type != .nodeEnd {
                    let t = tokens[i]
                    switch t.type {
                    case .outerTag: node.outerTags.append(t.value)
                    case .innerTag: node.innerTags.append(t.value)
                    case .polyTag:  node.polyTags.append(t.value)
                    case .netTag:   node.netTags.append(t.value)
                    case .keyword:
                        if t.value == "irin" && i+1 < tokens.count && tokens[i+1].type == .string {
                            node.irinValue = tokens[i+1].value
                        } else if t.value == "irout" && i+1 < tokens.count && tokens[i+1].type == .string {
                            node.iroutValue = tokens[i+1].value
                        }
                        node.body.append(t)
                    default: node.body.append(t)
                    }
                    i += 1
                }
                if i < tokens.count { i += 1 } // consume nodeEnd
                ast.nodes.append(node)
            default: i += 1
            }
        }
        return ast
    }

    // MARK: - BRPN — Buoyancy Reflex Pendulum Node Shell Routing

    func brpn(nodeCount: Int, hasInner: Bool, hasOuter: Bool, hasPoly: Bool, hasNet: Bool) -> BRPNResult {
        let f = hasOuter ? 1.0 : 0.5
        let r = hasInner ? 1.0 : 0.4
        let p = nodeCount > 0 ? min(1.0, Double(nodeCount) / 5.0) : 0.1
        let frp = f * r * p
        let buoyancy = frp * sqrt(abs(frp))
        let shell: String
        if buoyancy >= 0.76      { shell = "GEOLOGICAL" }
        else if buoyancy >= 0.44 { shell = "MARITIME" }
        else                     { shell = "AEROSPACE" }
        let qsVal = Self.quantumSocket(f, Double(max(nodeCount,1)), r, p)
        let enc   = Self.leatrEncode(Double(max(nodeCount,1)), Double(max(nodeCount,1)))
        let dec   = Self.leatrDecode(Double(max(nodeCount,1)), Double(max(nodeCount,1)))
        return BRPNResult(f: f, r: r, p: p, frp: frp, buoyancy: buoyancy,
                          shell: shell, qsVal: qsVal, encodeValue: enc, decodeValue: dec)
    }

    // MARK: - Full Compile

    func compile(source: String, netMode: Bool = false) -> (logs: [CompilerLogEntry], ast: AshAST, brpn: BRPNResult) {
        var logs: [CompilerLogEntry] = []
        func log(_ type: String, _ msg: String, _ color: String = "#8ab4cc") {
            logs.append(CompilerLogEntry(type: type, message: msg, color: color, timestamp: Date()))
        }

        let tokens = lex(source)
        let ast    = parse(tokens)

        if netMode {
            log("NET", "⟳ Network compile — logarithmic iterative mode", "#39ff14")
            for (idx, node) in ast.nodes.enumerated() {
                let iter = Double(idx + 1)
                let lv   = Foundation.log(iter + 1)
                log("NET", "[\(idx+1)] \(node.name): log(n)=\(String(format:"%.4f",lv))", "#39ff14")
            }
            log("NET", "⟳ NET COMPILE COMPLETE — \(ast.nodes.count) nodes", "#39ff14")
        } else {
            ast.globalOuter.forEach { log("{{OUTER}}", $0, "#ff9500") }
            ast.globalInner.forEach { log("[[INNER]]", $0, "#ffd700") }
            ast.globalPoly.forEach  { log("[POLY]",    $0, "#bf5fff") }
            ast.globalNet.forEach   { log("[NET]",     $0, "#39ff14") }

            for (idx, node) in ast.nodes.enumerated() {
                let nc = Double(idx + 1)
                node.outerTags.forEach { log("{{OUTER}}", $0, "#ff9500") }
                node.innerTags.forEach { log("[[INNER]]", $0, "#ffd700") }
                node.polyTags.forEach  { log("[POLY]",    $0, "#bf5fff") }
                node.netTags.forEach   { log("[NET]",     $0, "#39ff14") }

                log("SWITCH ON",  "\(node.name) → encode=\(String(format:"%.4f",Self.leatrEncode(nc,nc)))", "#00ffcc")

                let tools = node.body.filter { $0.type == .naturalTool }.map { $0.value }
                if !tools.isEmpty { log("OOO", "Tools: \(tools.joined(separator:" → "))", "#00ffcc") }
                if !node.polyTags.isEmpty { log("POLY", "Container active — math/physics isolated", "#bf5fff") }
                if let irin  = node.irinValue  { log("→ irin",   irin,  "#4a8a7a") }
                if let irout = node.iroutValue { log("← irout",  irout, "#4a8a7a") }

                log("SWITCH OFF", "\(node.name) → decode=\(String(format:"%.4f",Self.leatrDecode(nc,nc)))", "#4a8a7a")
                log("✓ COMPILED", node.name, "#00cc66")
            }

            let hasInner = !ast.globalInner.isEmpty || ast.nodes.contains { !$0.innerTags.isEmpty }
            let hasOuter = !ast.globalOuter.isEmpty || ast.nodes.contains { !$0.outerTags.isEmpty }
            let hasPoly  = !ast.globalPoly.isEmpty  || ast.nodes.contains { !$0.polyTags.isEmpty }
            let hasNet   = !ast.globalNet.isEmpty   || ast.nodes.contains { !$0.netTags.isEmpty }
            let result   = brpn(nodeCount: ast.nodes.count, hasInner: hasInner, hasOuter: hasOuter,
                                hasPoly: hasPoly, hasNet: hasNet)

            log("PENDULUM", "FRP: f=\(String(format:"%.2f",result.f)) r=\(String(format:"%.2f",result.r)) p=\(String(format:"%.3f",result.p))", "#a78bfa")
            log("BUOYANCY",  "\(String(format:"%.4f",result.buoyancy)) → shell: \(result.shell)", "#a78bfa")
            log("QS",        "Quantum Socket: \(String(format:"%.4f",result.qsVal))", "#a78bfa")
            if ast.nodes.isEmpty {
                log("SYSTEM", "No executable nodes found.", "#4a8a7a")
            } else {
                log("COMPLETE", "\(ast.nodes.count) nodes compiled · \(result.shell) shell routed", "#00ffcc")
            }
            return (logs, ast, result)
        }

        let result = brpn(nodeCount: ast.nodes.count, hasInner: false, hasOuter: false,
                          hasPoly: false, hasNet: false)
        return (logs, ast, result)
    }
}
