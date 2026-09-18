//
//  MashImport.swift — Mind map import: MASH, FreeMind, OPML
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Direct Swift port of mash-import.js from the web app: real
//  parsers for the same three genuinely well-specified formats.
//  MindNode's own file format is proprietary and undocumented, so
//  it isn't handled here — a MindNode user exports to OPML or
//  FreeMind from within MindNode itself, and that file imports
//  correctly through this module. See mash-import.js for the full
//  rationale (this file mirrors it exactly, format-for-format).
//

import Foundation
import CoreGraphics

public enum MashImportError: LocalizedError {
    case unrecognizedFormat(String)
    case malformedXML(String)
    case missingRoot(String)
    case malformedMash(String)

    public var errorDescription: String? {
        switch self {
        case .unrecognizedFormat(let name):
            return "Unrecognized file type \"\(name)\" — expected .mash, .mm, or .opml"
        case .malformedXML(let detail):
            return "Malformed XML: \(detail)"
        case .missingRoot(let detail):
            return detail
        case .malformedMash(let detail):
            return "Not a valid MASH document: \(detail)"
        }
    }
}

public enum MashImport {

    /// Detects format from filename extension, falling back to
    /// content sniffing when the extension is missing or generic.
    public static func fromFile(filename: String, data: Data) throws -> MashDocument {
        let ext = "." + (filename.split(separator: ".").last.map(String.init) ?? "").lowercased()
        switch ext {
        case ".mash", ".json":
            return try fromMash(data: data)
        case ".mm":
            guard let text = String(data: data, encoding: .utf8) else {
                throw MashImportError.malformedXML("could not decode file as UTF-8")
            }
            return try fromFreeMind(text: text)
        case ".opml":
            guard let text = String(data: data, encoding: .utf8) else {
                throw MashImportError.malformedXML("could not decode file as UTF-8")
            }
            return try fromOpml(text: text)
        default:
            break
        }

        // Content sniffing fallback.
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") { return try fromMash(data: data) }
            if trimmed.range(of: "<map\\b", options: .regularExpression) != nil {
                return try fromFreeMind(text: text)
            }
            if trimmed.range(of: "<opml\\b", options: .regularExpression) != nil {
                return try fromOpml(text: text)
            }
        }
        throw MashImportError.unrecognizedFormat(filename)
    }

    // MARK: - MASH (.mash / .json) — already the right shape

    public static func fromMash(data: Data) throws -> MashDocument {
        let doc: MashDocument
        do {
            doc = try JSONDecoder().decode(MashDocument.self, from: data)
        } catch {
            throw MashImportError.malformedMash(error.localizedDescription)
        }
        return rekeyed(doc)
    }

    // MARK: - FreeMind (.mm): <node TEXT="..."> tree

    public static func fromFreeMind(text: String) throws -> MashDocument {
        let parser = FreeMindParser()
        guard let xmlData = text.data(using: .utf8) else {
            throw MashImportError.malformedXML("could not encode text as UTF-8")
        }
        let xmlParser = XMLParser(data: xmlData)
        xmlParser.delegate = parser
        guard xmlParser.parse(), let rootElement = parser.root else {
            let msg = parser.parseErrorMessage ?? xmlParser.parserError?.localizedDescription ?? "unknown error"
            throw MashImportError.malformedXML(msg)
        }

        var doc = MashDocument.new(title: rootElement.attr("TEXT") ?? "Imported Mind Map")
        doc.nodes = [:]
        let rootId = UUID().uuidString
        doc.rootId = rootId

        let levelRadius: CGFloat = 220

        @discardableResult
        func walk(_ el: FMNode, parentId: String?, depth: Int, angleStart: Double, angleEnd: Double) -> String {
            let isRoot = parentId == nil
            let text = el.attr("TEXT") ?? ""
            let type: MashNodeType = isRoot ? .root : (depth == 1 ? .main : .subtitle)
            var node = MashNodeData(id: isRoot ? rootId : UUID().uuidString, type: type, text: text,
                                     detail: "", url: "", imageData: nil,
                                     x: 0, y: 0, width: type == .root ? 180 : type == .main ? 130 : 110,
                                     children: [], parentId: parentId, collapsed: false,
                                     fillColor: nil, borderColor: nil, textColor: nil,
                                     cornerStyle: nil, fontSize: nil, bold: isRoot, italic: false)
            doc.nodes[node.id] = node
            if let pid = parentId { doc.nodes[pid]?.children.append(node.id) }

            let childEls = el.children.filter { $0.name == "node" }
            let span = (angleEnd - angleStart) / Double(max(1, childEls.count))
            for (i, childEl) in childEls.enumerated() {
                let a = angleStart + span * (Double(i) + 0.5)
                let r = levelRadius * CGFloat(depth)
                let cx = node.x + CGFloat(cos(a)) * r * 0.4
                let cy = node.y + CGFloat(sin(a)) * r * 0.4
                let childId = walk(childEl, parentId: node.id, depth: depth + 1, angleStart: a - span / 2, angleEnd: a + span / 2)
                doc.nodes[childId]?.x = cx
                doc.nodes[childId]?.y = cy
            }
            return node.id
        }

        walk(rootElement, parentId: nil, depth: 1, angleStart: 0, angleEnd: 2 * .pi)
        return doc
    }

    // MARK: - OPML (.opml): <outline text="..."> nested tree

    public static func fromOpml(text: String) throws -> MashDocument {
        let parser = OpmlParser()
        guard let xmlData = text.data(using: .utf8) else {
            throw MashImportError.malformedXML("could not encode text as UTF-8")
        }
        let xmlParser = XMLParser(data: xmlData)
        xmlParser.delegate = parser
        guard xmlParser.parse(), !parser.topOutlines.isEmpty else {
            let msg = parser.parseErrorMessage ?? xmlParser.parserError?.localizedDescription
                ?? "No <outline> elements found in OPML body"
            throw MashImportError.malformedXML(msg)
        }

        let docTitle = parser.title ?? "Imported Outline"
        var doc = MashDocument.new(title: docTitle)
        doc.nodes = [:]
        let rootId = UUID().uuidString
        doc.rootId = rootId
        let root = MashNodeData(id: rootId, type: .root, text: docTitle,
                                 detail: "", url: "", imageData: nil,
                                 x: 0, y: 0, width: 180,
                                 children: [], parentId: nil, collapsed: false,
                                 fillColor: nil, borderColor: nil, textColor: nil,
                                 cornerStyle: nil, fontSize: nil, bold: true, italic: false)
        doc.nodes[rootId] = root

        let levelRadius: CGFloat = 220

        @discardableResult
        func walk(_ el: FMNode, parentId: String, depth: Int, angleStart: Double, angleEnd: Double) -> String {
            let text = el.attr("text") ?? el.attr("title") ?? el.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let type: MashNodeType = depth == 1 ? .main : .subtitle
            let node = MashNodeData(id: UUID().uuidString, type: type, text: text,
                                     detail: "", url: "", imageData: nil,
                                     x: 0, y: 0, width: type == .main ? 130 : 110,
                                     children: [], parentId: parentId, collapsed: false,
                                     fillColor: nil, borderColor: nil, textColor: nil,
                                     cornerStyle: nil, fontSize: nil, bold: false, italic: false)
            doc.nodes[node.id] = node
            doc.nodes[parentId]?.children.append(node.id)

            let childEls = el.children.filter { $0.name == "outline" }
            let span = (angleEnd - angleStart) / Double(max(1, childEls.count))
            for (i, childEl) in childEls.enumerated() {
                let a = angleStart + span * (Double(i) + 0.5)
                let r = levelRadius * CGFloat(depth)
                let cx = node.x + CGFloat(cos(a)) * r * 0.4
                let cy = node.y + CGFloat(sin(a)) * r * 0.4
                let childId = walk(childEl, parentId: node.id, depth: depth + 1, angleStart: a - span / 2, angleEnd: a + span / 2)
                doc.nodes[childId]?.x = cx
                doc.nodes[childId]?.y = cy
            }
            return node.id
        }

        let span = (2 * Double.pi) / Double(parser.topOutlines.count)
        for (i, el) in parser.topOutlines.enumerated() {
            let a = span * (Double(i) + 0.5)
            let r = levelRadius
            let childId = walk(el, parentId: rootId, depth: 1, angleStart: a - span / 2, angleEnd: a + span / 2)
            doc.nodes[childId]?.x = CGFloat(cos(a)) * r
            doc.nodes[childId]?.y = CGFloat(sin(a)) * r
        }

        return doc
    }

    // MARK: - Re-key every node ID to avoid collisions with open documents

    private static func rekeyed(_ original: MashDocument) -> MashDocument {
        var doc = original
        var idMap: [String: String] = [:]
        for oldId in doc.nodes.keys { idMap[oldId] = UUID().uuidString }

        var newNodes: [String: MashNodeData] = [:]
        for (oldId, node) in doc.nodes {
            var newNode = node
            newNode.id = idMap[oldId] ?? oldId
            newNode.parentId = node.parentId.flatMap { idMap[$0] }
            newNode.children = node.children.compactMap { idMap[$0] }
            newNodes[newNode.id] = newNode
        }
        doc.nodes = newNodes
        doc.rootId = idMap[doc.rootId] ?? doc.rootId
        doc.id = UUID().uuidString
        doc.connections = doc.connections.map { conn in
            var c = conn
            c.fromId = idMap[conn.fromId] ?? conn.fromId
            c.toId = idMap[conn.toId] ?? conn.toId
            return c
        }
        return doc
    }
}

// MARK: - Minimal generic XML tree (shared by the FreeMind and OPML parsers)

final class FMNode {
    let name: String
    var attributes: [String: String]
    var children: [FMNode] = []
    var textContent: String = ""
    weak var parent: FMNode?

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func attr(_ key: String) -> String? {
        attributes[key] ?? attributes[key.lowercased()] ?? attributes[key.uppercased()]
    }
}

/// Parses a FreeMind .mm file into a generic FMNode tree rooted at
/// the first <node> found under <map>.
final class FreeMindParser: NSObject, XMLParserDelegate {
    var root: FMNode?
    var parseErrorMessage: String?
    private var stack: [FMNode] = []
    private var inMap = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName == "map" { inMap = true; return }
        guard inMap else { return }
        let node = FMNode(name: elementName, attributes: attributeDict)
        if elementName == "node" {
            node.parent = stack.last
            stack.last?.children.append(node)
            if root == nil { root = node }
            stack.append(node)
        } else {
            // Non-node elements (e.g. <richcontent>) are skipped for
            // structure purposes but their text still contributes if
            // a TEXT attribute is absent — not needed for this format
            // in practice, so just ignore other element types.
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "node", !stack.isEmpty { stack.removeLast() }
        if elementName == "map" { inMap = false }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parseErrorMessage = parseError.localizedDescription
    }
}

/// Parses an OPML file: collects <head><title>, and the top-level
/// <outline> children of <body> as an FMNode tree (reusing the same
/// generic node type as the FreeMind parser).
final class OpmlParser: NSObject, XMLParserDelegate {
    var title: String?
    var topOutlines: [FMNode] = []
    var parseErrorMessage: String?

    private var stack: [FMNode] = []
    private var inHead = false
    private var inTitle = false
    private var inBody = false
    private var titleBuffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        switch elementName {
        case "head": inHead = true
        case "title" where inHead: inTitle = true; titleBuffer = ""
        case "body": inBody = true
        case "outline":
            guard inBody else { break }
            let node = FMNode(name: elementName, attributes: attributeDict)
            node.parent = stack.last
            if let parentNode = stack.last {
                parentNode.children.append(node)
            } else {
                topOutlines.append(node)
            }
            stack.append(node)
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTitle { titleBuffer += string }
        else if let top = stack.last { top.textContent += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "head": inHead = false
        case "title":
            if inTitle { title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines) }
            inTitle = false
        case "body": inBody = false
        case "outline":
            if !stack.isEmpty { stack.removeLast() }
        default: break
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parseErrorMessage = parseError.localizedDescription
    }
}
