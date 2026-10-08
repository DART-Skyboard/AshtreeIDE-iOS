// AshExt.swift — Ash 2.1 extension runtime for iOS (port of ash-shell64.js + ash-exec.js).
// Shell 64 reflexive state (bl, rbli, tool, anchor, shell) and the net./shell64./journal. statements.
// Pure logic; every outside effect goes through AshExecHost closures.
import Foundation

public struct Shell64Record {
    public var index: Int
    public var pre: String
    public var key: String
    public var bl: Int
    public var rbli: Int
    public var tool: String
    public var anchor: String
    public var shell: String
    public var rest: String
    public var post: String

    public var kind: String { bl == 0 ? "data" : (rbli >= 1 ? "buildable" : "sequence") }
}

public final class Shell64State {
    public private(set) var lines: [String]
    public private(set) var records: [Shell64Record] = []
    private var byKey: [String: Int] = [:]

    private static let lineRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(\s*irin \("Data: )k=(\S+) bl=(\d+) rbli=(\d+) t=(\S+) a=(\S+) shell=(\S+) (kind=[^"]*)("\)\s*)$"#)

    public init?(text: String) {
        lines = text.components(separatedBy: "\n")
        guard let re = Shell64State.lineRegex else { return nil }
        for (i, ln) in lines.enumerated() {
            let ns = ln as NSString
            guard let m = re.firstMatch(in: ln, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges == 10 else { continue }
            func g(_ n: Int) -> String { ns.substring(with: m.range(at: n)) }
            let rec = Shell64Record(index: i, pre: g(1), key: g(2), bl: Int(g(3)) ?? 0, rbli: Int(g(4)) ?? 0,
                                    tool: g(5), anchor: g(6), shell: g(7), rest: g(8), post: g(9))
            byKey[rec.key] = records.count
            records.append(rec)
        }
        if records.isEmpty { return nil }
    }

    public func read(_ key: String) -> Shell64Record? {
        guard let i = byKey[key] else { return nil }
        return records[i]
    }

    public func counts() -> (data: Int, sequence: Int, buildable: Int) {
        var d = 0, s = 0, b = 0
        for r in records {
            switch r.kind { case "data": d += 1; case "sequence": s += 1; default: b += 1 }
        }
        return (d, s, b)
    }
}

public struct AshExecHost {
    public var read: (String) -> Shell64Record?
    public var journal: (String, String) -> Void          // (type, text)
    public var listen: (String, @escaping () -> Void) -> Void
    public var log: (String) -> Void
}

public enum AshExecutor {
    static func groups(_ pattern: String, _ s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var out: [String] = []
        for i in 0..<m.numberOfRanges {
            let r = m.range(at: i)
            out.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        return out
    }

    public static func hasExtensions(_ source: String) -> Bool {
        for raw in source.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.hasPrefix("net.") || l.hasPrefix("shell64.") || l.hasPrefix("journal.") { return true }
        }
        return false
    }

    public static func run(source: String, host: AshExecHost) {
        var vars: [String: String] = [:]
        var body: [String] = []
        var inNode = false
        var listenEvent: String? = nil

        for raw in source.components(separatedBy: "\n") {
            let l = raw.trimmingCharacters(in: .whitespaces)
            if l.isEmpty || l.hasPrefix("//") || l.hasPrefix("import ") { continue }
            if groups(#"^\([A-Za-z0-9_]+\):-:\s*\{"#, l) != nil { inNode = true; continue }
            if l.hasPrefix("}|';") || l.hasPrefix("}::::") { inNode = false; continue }
            if !inNode { continue }
            if let g = groups(#"^var \((\w+)\)"#, l) { if vars[g[1]] == nil { vars[g[1]] = "" }; continue }
            if let g = groups(#"^irin\s*\("Data:\s*([^"]*)"\)"#, l) {
                for tok in g[1].split(separator: " ") {
                    if let eq = tok.firstIndex(of: "=") {
                        vars[String(tok[tok.startIndex..<eq])] = String(tok[tok.index(after: eq)...])
                    }
                }
                continue
            }
            if let g = groups(#"^net\.listen \((\w+)\)\s*(\[net:[^\]]+\])?\s*\{\s*when \((\w+)\)\s*=\s*(\S+)\s*\}"#, l) {
                listenEvent = g[4]; continue
            }
            body.append(l)
        }

        func exec(_ stmts: [String], _ v0: [String: String]) {
            var v = v0
            for l in stmts {
                if let g = groups(#"^shell64\.read \((\w+)\) placeto \((\w+)\)"#, l) {
                    if let r = host.read(v[g[1]] ?? "") {
                        v[g[2]] = "\(r.key) bl=\(r.bl) rbli=\(r.rbli) t=\(r.tool) \(r.kind)"
                    } else { v[g[2]] = "" }
                    continue
                }
                if let g = groups(#"^journal\.write \((\w+)\) with var \((\w+)\)"#, l) {
                    host.journal(v["type"] ?? "ash_journal", v[g[2]] ?? "")
                    continue
                }
                if let g = groups(#"^irout \("([^"]*)"placeto \((\w+)\)\)"#, l) {
                    host.log((g[1]) + (v[g[2]] ?? ""))
                    continue
                }
            }
        }

        if let ev = listenEvent {
            let snapshot = vars
            let stmts = body
            host.listen(ev) { exec(stmts, snapshot) }
        } else {
            exec(body, vars)
        }
    }
}
