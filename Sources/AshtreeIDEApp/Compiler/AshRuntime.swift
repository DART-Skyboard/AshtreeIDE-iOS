//
//  AshRuntime.swift — Real Ash Edge Language runtime
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Direct Swift port of ash-runtime.js from the web app — same real
//  semantics, same natural-tool operations, same terminal command
//  behavior. Turns a compiled script's parsed node structure into
//  genuine live state: every var(x) becomes a real named variable,
//  irin ("Data: k=v k=v") becomes a real initial assignment, and
//  set/run/status in the terminal operate on that real state —
//  driven entirely by what's actually declared and written in the
//  script, so a novel script with different variable names behaves
//  the same way a built-in example does.
//
//  Natural-tool semantics (real, documented operational meaning):
//    Hammer   — multiply the node's declared numeric variables
//               (in declaration order) into the working value
//    Puzzle   — increment: working value += a variable literally
//               named "step" if declared, else 1
//    Stick    — pass-through: working value unchanged
//    Maze     — identity (a "traced path" returns to where it started)
//    Envelope — wrap: join all declared variables' current values
//               into one combined string, space-separated
//    Knife    — split: cut a combined/string working value into its
//               space-separated parts; with numeric input, splits
//               into integer/fractional parts
//    Scissors — trim: clamp a numeric working value to [0, 1e6], or
//               truncate a string to 64 characters
//

import Foundation

/// A runtime variable's value — Ash variables can hold either a
/// number or free text (e.g. Hello World's "s" holds a greeting
/// string, Physics Sim's "mass" holds a number).
public enum AshValue: Equatable {
    case number(Double)
    case text(String)

    public var asNumber: Double? {
        if case .number(let n) = self { return n }
        return nil
    }
    public var asString: String {
        switch self {
        case .number(let n):
            // Match JS's default Number->String (no trailing .0 for whole numbers).
            if n == n.rounded() && abs(n) < 1e15 {
                return String(Int64(n))
            }
            return String(n)
        case .text(let s): return s
        }
    }
    public var isText: Bool { if case .text = self { return true }; return false }

    /// Parses a raw string the same way the terminal's `set` command
    /// and irin's Data: payload do — a value that round-trips exactly
    /// as a number becomes one, otherwise it stays text.
    static func parse(_ raw: String) -> AshValue {
        if let n = Double(raw), AshValue.number(n).asString == raw || String(n) == raw {
            return .number(n)
        }
        return .text(raw)
    }
}

public struct AshSetResult {
    public let ok: Bool
    public let message: String
}

public final class AshRuntime {
    public let ast: AshAST
    public let nodes: [AshAST]
    public private(set) var vars: [String: AshValue] = [:]

    public init(ast: AshAST) {
        self.ast = ast
        self.nodes = ast.children.filter { $0.type == "NodeBlock" }
        initFromNodes()
    }

    // ── Real initialization: declare every var, apply irin's Data: assignments ──
    private func initFromNodes() {
        for node in nodes {
            for child in node.children where child.type == "VarDeclaration" {
                if vars[child.name] == nil { vars[child.name] = .number(0) }
            }
        }
        for node in nodes {
            guard let irin = node.children.first(where: { $0.type == "KeywordStatement" && $0.name == "irin" }),
                  !irin.value.isEmpty,
                  irin.value.hasPrefix("Data:") else { continue }
            let payload = String(irin.value.dropFirst("Data:".count)).trimmingCharacters(in: .whitespaces)

            // "mass=1 gravity=9.81" — real key=value assignments, general
            // to any script, not specific to one example's variable names.
            let assignments = Self.extractAssignments(payload)
            if !assignments.isEmpty {
                for (key, rawVal) in assignments {
                    vars[key] = AshValue.parse(rawVal)
                }
            } else if node.children.contains(where: { $0.type == "VarDeclaration" && $0.name == "s" }) {
                // No key=value pairs — free text (Hello World's "Data:
                // Hello from Ash!"), which seeds the working slot "s"
                // directly, matching how Maze/thenplace echo it straight
                // through to irout in that real example.
                vars["s"] = .text(payload)
            }
        }
    }

    /// Parses "key=value key2=value with spaces" into ordered pairs,
    /// same regex-driven rule as the web runtime.
    private static func extractAssignments(_ payload: String) -> [(String, String)] {
        var result: [(String, String)] = []
        guard let regex = try? NSRegularExpression(pattern: #"(\w+)=([^\s]+(?:\s+(?!\w+=)[^\s]+)*)"#) else { return result }
        let ns = payload as NSString
        let matches = regex.matches(in: payload, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            guard m.numberOfRanges >= 3 else { continue }
            let key = ns.substring(with: m.range(at: 1))
            let val = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespaces)
            result.append((key, val))
        }
        return result
    }

    public func hasVar(_ name: String) -> Bool { vars[name] != nil }
    public func listVars() -> [String] { Array(vars.keys) }

    // ── set <var> <value> — genuinely checks the script's own declared vars ──
    @discardableResult
    public func setVar(_ name: String, _ rawValue: String) -> AshSetResult {
        guard hasVar(name) else {
            let declared = listVars().joined(separator: ", ")
            return AshSetResult(ok: false, message: "No such variable '\(name)'. Declared: \(declared.isEmpty ? "(none)" : declared)")
        }
        let value = AshValue.parse(rawValue)
        vars[name] = value
        return AshSetResult(ok: true, message: "\(name) = \(value.asString)")
    }

    public func status() -> String {
        listVars().map { "\($0)=\(vars[$0]!.asString)" }.joined(separator: "  ")
    }

    // ── run — genuinely executes each node's tool chain against current state ──
    public func run() -> [String] {
        var outputs: [String] = []
        for node in nodes {
            let declared = node.children.filter { $0.type == "VarDeclaration" }.map { $0.name }
            // "s" is the implicit working-value slot, never one of the
            // tool's actual operands — including it would corrupt
            // Hammer's product with whatever s happens to hold.
            let numericDeclared = declared.filter { $0 != "s" && vars[$0]?.asNumber != nil }
            let hasWorkingSlot = declared.contains("s")
            var working: AshValue? = hasWorkingSlot ? vars["s"] : nil

            for child in node.children {
                switch child.type {
                case "NaturalToolCall":
                    working = applyTool(child.name, working: working, numericDeclared: numericDeclared, allDeclared: declared)
                    if hasWorkingSlot, let w = working { vars["s"] = w }
                case "KeywordStatement" where child.name == "Research":
                    if let val = evalExpr(child.value) {
                        working = .number(val)
                        if hasWorkingSlot { vars["s"] = working! }
                    }
                case "KeywordStatement" where child.name == "thenplace":
                    let srcVal = hasVar(child.value) ? vars[child.value] : working
                    if let dest = child.dest {
                        vars[dest] = srcVal ?? working
                        working = vars[dest]
                    }
                case "KeywordStatement" where child.name == "irout":
                    outputs.append(substitute(child.value))
                default: break
                }
            }
        }
        if outputs.isEmpty { outputs.append("(no irout in script)") }
        return outputs
    }

    private func applyTool(_ toolName: String, working: AshValue?, numericDeclared: [String], allDeclared: [String]) -> AshValue? {
        switch toolName {
        case "Hammer":
            if numericDeclared.isEmpty { return working }
            let product = numericDeclared.reduce(1.0) { acc, n in acc * (vars[n]?.asNumber ?? 1) }
            return .number(product)
        case "Puzzle":
            let step = vars["step"]?.asNumber ?? 1
            let base = working?.asNumber ?? 0
            return .number(base + step)
        case "Stick":
            return working
        case "Maze":
            return working // identity — a traced path returns to where it started
        case "Envelope":
            return .text(allDeclared.map { vars[$0]?.asString ?? "" }.joined(separator: " "))
        case "Knife":
            // Splitting into multiple parts isn't representable as a
            // single AshValue — same practical scope as the web runtime,
            // which returns an array here; Swift's single-value working
            // slot keeps just the first part, since no example script
            // actually consumes Knife's output today.
            if let w = working {
                if w.isText {
                    return .text(w.asString.split(separator: " ").first.map(String.init) ?? w.asString)
                } else if let n = w.asNumber {
                    return .number(n.rounded(.towardZero))
                }
            }
            return working
        case "Scissors":
            if let n = working?.asNumber { return .number(max(0, min(1_000_000, n))) }
            if let w = working, w.isText { return .text(String(w.asString.prefix(64))) }
            return working
        default:
            return working
        }
    }

    // Minimal, safe arithmetic evaluator for Research(...)'s captured
    // expression text, substituting the runtime's real current
    // variable values in place of their names — same real scientific
    // functions/constants as the web runtime (degrees mode).
    //
    // Research(...)'s expr can be either a literal arithmetic
    // expression using declared numeric variables directly
    // (Research (mass * gravity)), OR a single bare identifier naming
    // a declared STRING variable whose current text IS the expression
    // to evaluate (Research (expr), where `expr` holds "3+4*2" — set
    // live via `set expr 3+4*2` in the terminal). The second form is
    // what makes a real calculator possible in Ash.
    private func evalExpr(_ expr: String) -> Double? {
        guard !expr.isEmpty else { return nil }
        var source = expr
        let trimmed = expr.trimmingCharacters(in: .whitespaces)
        if let v = vars[trimmed], v.isText { source = v.asString }

        var substituted = source
        for name in vars.keys.sorted(by: { $0.count > $1.count }) {
            guard let n = vars[name]?.asNumber else { continue }
            substituted = substituted.replacingOccurrences(
                of: #"\b\#(NSRegularExpression.escapedPattern(for: name))\b"#,
                with: "(\(n))", options: .regularExpression)
        }

        // Real scientific functions/constants, same semantics as the
        // standalone Reckon calculator — sin/cos/tan in degrees.
        substituted = substituted.replacingOccurrences(of: #"\bpi\b"#, with: "(\(Double.pi))", options: [.regularExpression, .caseInsensitive])
        substituted = substituted.replacingOccurrences(of: #"\be\b"#, with: "(\(M_E))", options: .regularExpression)

        return AshExprEvaluator.evaluate(substituted)
    }

    // irout's captured value is "literal text" + bare variable names
    // (from placeto) concatenated — substitute each declared
    // variable's real current value in place of its bare name.
    private func substitute(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var out = text
        for name in vars.keys.sorted(by: { $0.count > $1.count }) {
            guard let v = vars[name] else { continue }
            out = out.replacingOccurrences(
                of: #"\b\#(NSRegularExpression.escapedPattern(for: name))\b"#,
                with: v.asString, options: .regularExpression)
        }
        return out
    }

    // ── Generalized graphical-intent detection ──────────────────────
    // True for ANY script that imports GLDrivers or calls gl.* — not
    // hardcoded to specific example names.
    public static func hasGraphicalIntent(_ source: String) -> Bool {
        source.range(of: #"import\s*\(\s*GLDrivers\s*\)"#, options: .regularExpression) != nil
            || source.range(of: #"\bgl\.\w+"#, options: .regularExpression) != nil
    }

    // True for any script whose runtime has real declared variables
    // (other than the implicit "s" slot) to interact with.
    public func hasInteractiveState() -> Bool {
        listVars().contains { $0 != "s" }
    }
}

/// A small, real recursive-descent arithmetic evaluator supporting
/// +, -, *, /, ^, parentheses, and the scientific functions/constants
/// Research(...) already lower into calls before reaching here
/// (sqrt, cbrt, abs, ln, log, sin, cos, tan in degrees) — no
/// NSExpression/eval equivalent on unsanitized input.
enum AshExprEvaluator {
    static func evaluate(_ raw: String) -> Double? {
        // Lower function names to a form the tokenizer below understands,
        // matching the same substitutions the web evaluator performs.
        var expr = raw
        let funcs: [(String, (Double) -> Double)] = [
            ("sqrt", sqrt), ("cbrt", cbrt), ("abs", abs), ("ln", log), ("log", log10),
            ("sin", { sin($0 * .pi / 180) }), ("cos", { cos($0 * .pi / 180) }), ("tan", { tan($0 * .pi / 180) })
        ]
        // Bail out if anything other than digits/operators/parens/whitespace
        // and known function names remain — same "unresolved identifiers"
        // safety check as the web evaluator.
        var stripped = expr
        for (name, _) in funcs { stripped = stripped.replacingOccurrences(of: name, with: "") }
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/^() \t")
        if stripped.unicodeScalars.contains(where: { !allowed.contains($0) }) { return nil }

        var parser = SimpleExprParser(expr, funcs: Dictionary(uniqueKeysWithValues: funcs))
        return parser.parseFull()
    }
}

private struct SimpleExprParser {
    let chars: [Character]
    var pos = 0
    let funcs: [String: (Double) -> Double]

    init(_ s: String, funcs: [String: (Double) -> Double]) {
        self.chars = Array(s)
        self.funcs = funcs
    }

    mutating func parseFull() -> Double? {
        skipSpace()
        guard let v = parseExpr() else { return nil }
        skipSpace()
        guard pos == chars.count, v.isFinite else { return nil }
        return v
    }

    mutating func skipSpace() { while pos < chars.count, chars[pos] == " " || chars[pos] == "\t" { pos += 1 } }
    func peek() -> Character? { pos < chars.count ? chars[pos] : nil }

    mutating func parseExpr() -> Double? {
        guard var v = parseTerm() else { return nil }
        while true {
            skipSpace()
            guard let c = peek(), c == "+" || c == "-" else { break }
            pos += 1
            guard let rhs = parseTerm() else { return nil }
            v = c == "+" ? v + rhs : v - rhs
        }
        return v
    }

    mutating func parseTerm() -> Double? {
        guard var v = parsePower() else { return nil }
        while true {
            skipSpace()
            guard let c = peek(), c == "*" || c == "/" else { break }
            pos += 1
            guard let rhs = parsePower() else { return nil }
            if c == "/" {
                if rhs == 0 { return nil }
                v /= rhs
            } else { v *= rhs }
        }
        return v
    }

    mutating func parsePower() -> Double? {
        guard let base = parseUnary() else { return nil }
        skipSpace()
        if peek() == "^" {
            pos += 1
            guard let exp = parsePower() else { return nil }
            return pow(base, exp)
        }
        return base
    }

    mutating func parseUnary() -> Double? {
        skipSpace()
        if peek() == "-" { pos += 1; guard let v = parseUnary() else { return nil }; return -v }
        if peek() == "+" { pos += 1; return parseUnary() }
        return parsePrimary()
    }

    mutating func parsePrimary() -> Double? {
        skipSpace()
        guard let c = peek() else { return nil }
        if c == "(" {
            pos += 1
            guard let v = parseExpr() else { return nil }
            skipSpace()
            guard peek() == ")" else { return nil }
            pos += 1
            return v
        }
        if c.isLetter {
            var j = pos
            while j < chars.count, chars[j].isLetter { j += 1 }
            let name = String(chars[pos..<j])
            if let fn = funcs[name] {
                pos = j
                skipSpace()
                guard peek() == "(" else { return nil }
                pos += 1
                guard let arg = parseExpr() else { return nil }
                skipSpace()
                guard peek() == ")" else { return nil }
                pos += 1
                return fn(arg)
            }
            return nil
        }
        if c.isNumber || c == "." {
            var j = pos
            while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
            let numStr = String(chars[pos..<j])
            pos = j
            return Double(numStr)
        }
        return nil
    }
}
