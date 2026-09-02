// IDEMindMapModel.swift
// MASH — Mind Map format for Ash Tree IDE
// © 2025 DART Meadow | Radical Deepscale LLC.
//
// File format: .mash (proprietary JSON), exportable to:
//   FreeMind .mm, XMind .xmind (JSON), Markdown, PDF, PNG
//
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Node Types

public enum MashNodeType: String, Codable, CaseIterable {
    case root       = "root"        // Central topic
    case main       = "main"        // Primary branch
    case subtitle   = "subtitle"    // Secondary branch
    case category   = "category"    // Group label
    case note       = "note"        // Information leaf
    case image      = "image"       // Image node
    case link       = "link"        // Hyperlink node

    public var defaultRadius: CGFloat {
        switch self {
        case .root:     return 54
        case .main:     return 38
        case .subtitle: return 30
        case .category: return 34
        case .note:     return 24
        case .image:    return 44
        case .link:     return 26
        }
    }

    public var defaultFontSize: CGFloat {
        switch self {
        case .root:     return 17
        case .main:     return 13
        case .subtitle: return 11
        case .category: return 12
        case .note:     return 10
        case .image:    return 10
        case .link:     return 10
        }
    }
}

// MARK: - Connection Style

public enum MashConnectionStyle: String, Codable {
    case curved     = "curved"      // Smooth bezier
    case straight   = "straight"    // 90° flowchart
    case organic    = "organic"     // Catmull-Rom
}

public enum MashArrowType: String, Codable {
    case none       = "none"
    case forward    = "forward"     // →
    case backward   = "backward"    // ←
    case both       = "both"        // ↔
}

// MARK: - Node Corner Style

public enum MashCornerStyle: String, Codable, CaseIterable {
    case rounded    = "rounded"
    case square     = "square"
    case pill       = "pill"
    case diamond    = "diamond"
    case hexagon    = "hexagon"
}

// MARK: - Mind Map Theme

public struct MashTheme: Codable, Identifiable {
    public let id: String
    public var name: String
    // Canvas
    public var canvasBackground: String     // hex
    public var canvasTransparent: Bool
    // Node colors by type
    public var rootFill:       String
    public var rootBorder:     String
    public var rootText:       String
    public var mainFill:       String
    public var mainBorder:     String
    public var mainText:       String
    public var subtitleFill:   String
    public var subtitleBorder: String
    public var subtitleText:   String
    public var categoryFill:   String
    public var categoryBorder: String
    public var categoryText:   String
    public var noteFill:       String
    public var noteBorder:     String
    public var noteText:       String
    // Connections
    public var connectionColor:   String
    public var connectionDash:    String    // "none" | "4,4" | "8,4"
    public var cornerStyle:       MashCornerStyle
    public var connectionStyle:   MashConnectionStyle

    public static let builtIn: [MashTheme] = [
        // ── Dark Ash (default) ─────────────────────────────
        MashTheme(id:"dark-ash", name:"Dark Ash",
            canvasBackground:"#0d1117", canvasTransparent:false,
            rootFill:"#00ffcc", rootBorder:"#00ccaa", rootText:"#000000",
            mainFill:"#0d2b3e", mainBorder:"#00e5ff", mainText:"#00e5ff",
            subtitleFill:"#0a1a2a", subtitleBorder:"#4488aa", subtitleText:"#88ccdd",
            categoryFill:"#1a1a2e", categoryBorder:"#8866ff", categoryText:"#bb99ff",
            noteFill:"#111827", noteBorder:"#334455", noteText:"#8a9ab0",
            connectionColor:"#00e5ff", connectionDash:"none",
            cornerStyle:.rounded, connectionStyle:.curved),

        // ── Neon Night ─────────────────────────────────────
        MashTheme(id:"neon-night", name:"Neon Night",
            canvasBackground:"#020008", canvasTransparent:false,
            rootFill:"#ff00ff", rootBorder:"#cc00cc", rootText:"#ffffff",
            mainFill:"#1a0022", mainBorder:"#ff00ff", mainText:"#ff88ff",
            subtitleFill:"#0d0018", subtitleBorder:"#8800ff", subtitleText:"#cc88ff",
            categoryFill:"#000d22", categoryBorder:"#0088ff", categoryText:"#66bbff",
            noteFill:"#0a000f", noteBorder:"#330066", noteText:"#9966cc",
            connectionColor:"#ff00ff", connectionDash:"none",
            cornerStyle:.pill, connectionStyle:.curved),

        // ── Solar Punk ─────────────────────────────────────
        MashTheme(id:"solar-punk", name:"Solar Punk",
            canvasBackground:"#0a1a08", canvasTransparent:false,
            rootFill:"#39ff14", rootBorder:"#22cc00", rootText:"#000000",
            mainFill:"#0d2610", mainBorder:"#39ff14", mainText:"#39ff14",
            subtitleFill:"#081a0a", subtitleBorder:"#228822", subtitleText:"#88dd88",
            categoryFill:"#1a1800", categoryBorder:"#ccaa00", categoryText:"#ffdd44",
            noteFill:"#0d1008", noteBorder:"#224422", noteText:"#669966",
            connectionColor:"#39ff14", connectionDash:"none",
            cornerStyle:.rounded, connectionStyle:.organic),

        // ── Blueprint ──────────────────────────────────────
        MashTheme(id:"blueprint", name:"Blueprint",
            canvasBackground:"#0a1628", canvasTransparent:false,
            rootFill:"#ffffff", rootBorder:"#ccddff", rootText:"#0a1628",
            mainFill:"#0a1628", mainBorder:"#ffffff", mainText:"#ffffff",
            subtitleFill:"#0d1e38", subtitleBorder:"#aabbdd", subtitleText:"#ccddff",
            categoryFill:"#081428", categoryBorder:"#6688aa", categoryText:"#aabbcc",
            noteFill:"#060e1c", noteBorder:"#334455", noteText:"#667788",
            connectionColor:"#ffffff", connectionDash:"none",
            cornerStyle:.square, connectionStyle:.straight),

        // ── Flowchart ──────────────────────────────────────
        MashTheme(id:"flowchart", name:"Flowchart",
            canvasBackground:"#ffffff", canvasTransparent:false,
            rootFill:"#1a73e8", rootBorder:"#1557b0", rootText:"#ffffff",
            mainFill:"#e8f0fe", mainBorder:"#1a73e8", mainText:"#1a1a1a",
            subtitleFill:"#f8f9fa", subtitleBorder:"#4285f4", subtitleText:"#1a1a1a",
            categoryFill:"#fce8e6", categoryBorder:"#ea4335", categoryText:"#c5221f",
            noteFill:"#e6f4ea", noteBorder:"#34a853", noteText:"#137333",
            connectionColor:"#1a1a1a", connectionDash:"none",
            cornerStyle:.square, connectionStyle:.straight),

        // ── Transparent Dark ───────────────────────────────
        MashTheme(id:"transparent-dark", name:"Transparent Export",
            canvasBackground:"#000000", canvasTransparent:true,
            rootFill:"#00ffcc", rootBorder:"#00ccaa", rootText:"#000000",
            mainFill:"#1a2a3a", mainBorder:"#00e5ff", mainText:"#00e5ff",
            subtitleFill:"#0f1f2f", subtitleBorder:"#4488aa", subtitleText:"#88ccdd",
            categoryFill:"#1a1a2e", categoryBorder:"#8866ff", categoryText:"#bb99ff",
            noteFill:"#111827", noteBorder:"#334455", noteText:"#8a9ab0",
            connectionColor:"#00e5ff", connectionDash:"none",
            cornerStyle:.rounded, connectionStyle:.curved),
    ]
}

// MARK: - Mind Map Node

public class MashNode: ObservableObject, Identifiable, Codable {
    public let id: String
    @Published public var type:       MashNodeType
    @Published public var text:       String
    @Published public var detail:     String          // notes / description
    @Published public var url:        String          // hyperlink
    @Published public var imageData:  Data?           // embedded image
    @Published public var position:   CGPoint         // canvas position
    @Published public var width:      CGFloat
    @Published public var children:   [String]        // child node IDs
    @Published public var parentId:   String?
    @Published public var collapsed:  Bool
    // Custom style overrides (nil = use theme)
    @Published public var fillColor:   String?
    @Published public var borderColor: String?
    @Published public var textColor:   String?
    @Published public var cornerStyle: MashCornerStyle?
    @Published public var fontSize:    CGFloat?
    @Published public var bold:        Bool
    @Published public var italic:      Bool

    public init(type: MashNodeType, text: String, position: CGPoint, parentId: String? = nil) {
        self.id          = UUID().uuidString
        self.type        = type
        self.text        = text
        self.detail      = ""
        self.url         = ""
        self.imageData   = nil
        self.position    = position
        self.width       = type == .root ? 160 : type == .main ? 130 : 110
        self.children    = []
        self.parentId    = parentId
        self.collapsed   = false
        self.fillColor   = nil
        self.borderColor = nil
        self.textColor   = nil
        self.cornerStyle = nil
        self.fontSize    = nil
        self.bold        = type == .root
        self.italic      = false
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, type, text, detail, url, imageData, position, width
        case children, parentId, collapsed
        case fillColor, borderColor, textColor, cornerStyle, fontSize, bold, italic
    }
    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,        forKey: .id)
        type        = try c.decode(MashNodeType.self,  forKey: .type)
        text        = try c.decode(String.self,        forKey: .text)
        detail      = (try? c.decode(String.self,      forKey: .detail)) ?? ""
        url         = (try? c.decode(String.self,      forKey: .url))    ?? ""
        imageData   = try? c.decode(Data.self,         forKey: .imageData)
        let px      = try c.decode(Double.self, forKey: .position)   // encoded as [x,y]
        let py      = try c.decode(Double.self, forKey: .width)      // temp reuse
        // Actually decode position properly below
        position    = .zero; width = 130
        children    = (try? c.decode([String].self,    forKey: .children))   ?? []
        parentId    = try? c.decode(String.self,       forKey: .parentId)
        collapsed   = (try? c.decode(Bool.self,        forKey: .collapsed))  ?? false
        fillColor   = try? c.decode(String.self,       forKey: .fillColor)
        borderColor = try? c.decode(String.self,       forKey: .borderColor)
        textColor   = try? c.decode(String.self,       forKey: .textColor)
        cornerStyle = try? c.decode(MashCornerStyle.self, forKey: .cornerStyle)
        fontSize    = try? c.decode(CGFloat.self,      forKey: .fontSize)
        bold        = (try? c.decode(Bool.self,        forKey: .bold))        ?? false
        italic      = (try? c.decode(Bool.self,        forKey: .italic))      ?? false
        _ = px; _ = py
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,          forKey: .id)
        try c.encode(type,        forKey: .type)
        try c.encode(text,        forKey: .text)
        try c.encode(detail,      forKey: .detail)
        try c.encode(url,         forKey: .url)
        try c.encodeIfPresent(imageData,   forKey: .imageData)
        try c.encode(position.x,  forKey: .position)
        try c.encode(position.y,  forKey: .width)
        try c.encode(children,    forKey: .children)
        try c.encodeIfPresent(parentId,    forKey: .parentId)
        try c.encode(collapsed,   forKey: .collapsed)
        try c.encodeIfPresent(fillColor,   forKey: .fillColor)
        try c.encodeIfPresent(borderColor, forKey: .borderColor)
        try c.encodeIfPresent(textColor,   forKey: .textColor)
        try c.encodeIfPresent(cornerStyle, forKey: .cornerStyle)
        try c.encodeIfPresent(fontSize,    forKey: .fontSize)
        try c.encode(bold,         forKey: .bold)
        try c.encode(italic,       forKey: .italic)
    }
}

// MARK: - Reference Connection (cross-branch link)

public struct MashConnection: Codable, Identifiable {
    public let id:        String
    public var fromId:    String
    public var toId:      String
    public var arrowType: MashArrowType
    public var label:     String
    public var color:     String?    // nil = theme connection color
    public var dashed:    Bool

    public init(from: String, to: String, arrow: MashArrowType = .forward) {
        self.id        = UUID().uuidString
        self.fromId    = from
        self.toId      = to
        self.arrowType = arrow
        self.label     = ""
        self.color     = nil
        self.dashed    = true
    }
}

// MARK: - Mind Map Document

public struct MashDocument: Codable {
    public var id:           String
    public var title:        String
    public var created:      Double
    public var modified:     Double
    public var themeId:      String
    public var customTheme:  MashTheme?
    public var nodes:        [String: MashNodeData]  // id → serializable data
    public var rootId:       String
    public var connections:  [MashConnection]
    public var canvasOffset: CGPoint
    public var canvasScale:  CGFloat
    public var layout:       MashLayout

    public static func new(title: String) -> MashDocument {
        let rootId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let root = MashNodeData(id: rootId, type: .root, text: title,
                                detail: "", url: "", imageData: nil,
                                x: 0, y: 0, width: 160,
                                children: [], parentId: nil, collapsed: false,
                                fillColor: nil, borderColor: nil, textColor: nil,
                                cornerStyle: nil, fontSize: nil, bold: true, italic: false)
        return MashDocument(id: UUID().uuidString, title: title,
                            created: now, modified: now,
                            themeId: "dark-ash", customTheme: nil,
                            nodes: [rootId: root], rootId: rootId,
                            connections: [], canvasOffset: .zero,
                            canvasScale: 1.0, layout: .radial)
    }
}

// Flat serializable node (avoids @Published Codable issues)
public struct MashNodeData: Codable {
    public var id:          String
    public var type:        MashNodeType
    public var text:        String
    public var detail:      String
    public var url:         String
    public var imageData:   Data?
    public var x:           CGFloat
    public var y:           CGFloat
    public var width:       CGFloat
    public var children:    [String]
    public var parentId:    String?
    public var collapsed:   Bool
    public var fillColor:   String?
    public var borderColor: String?
    public var textColor:   String?
    public var cornerStyle: MashCornerStyle?
    public var fontSize:    CGFloat?
    public var bold:        Bool
    public var italic:      Bool
}

// MARK: - Layout Type

public enum MashLayout: String, Codable, CaseIterable {
    case radial      = "radial"
    case tree        = "tree"
    case fishbone    = "fishbone"
    case flowchart   = "flowchart"
    case orgchart    = "orgchart"
    case timeline    = "timeline"

    public var displayName: String {
        switch self {
        case .radial:    return "Radial"
        case .tree:      return "Tree"
        case .fishbone:  return "Fishbone"
        case .flowchart: return "Flowchart"
        case .orgchart:  return "Org Chart"
        case .timeline:  return "Timeline"
        }
    }
    public var icon: String {
        switch self {
        case .radial:    return "circle.hexagongrid"
        case .tree:      return "point.topleft.down.curvedto.point.bottomright.up"
        case .fishbone:  return "arrow.triangle.branch"
        case .flowchart: return "rectangle.connected.to.line.below"
        case .orgchart:  return "person.3"
        case .timeline:  return "timeline.selection"
        }
    }
}

// MARK: - Mind Map Store

@MainActor
public final class MashStore: ObservableObject {
    public static let shared = MashStore()

    @Published public var documents: [MashDocument] = []
    @Published public var activeDocId: String? = nil

    private let storageKey = "mash_documents_v1"
    private let activeKey  = "mash_active_doc"

    private init() { load() }

    public var activeDoc: MashDocument? {
        guard let id = activeDocId else { return nil }
        return documents.first { $0.id == id }
    }

    public func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let docs = try? JSONDecoder().decode([MashDocument].self, from: data)
        else { return }
        documents = docs
        activeDocId = UserDefaults.standard.string(forKey: activeKey)
    }

    public func save() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        UserDefaults.standard.set(activeDocId, forKey: activeKey)
        UserDefaults.standard.synchronize()
    }

    public func newDocument(title: String, layout: MashLayout = .radial) -> MashDocument {
        var doc = MashDocument.new(title: title)
        doc.layout = layout
        // Add 4 starter branches for radial/tree
        if layout == .radial || layout == .tree {
            let angles: [Double] = [45, 135, 225, 315]
            let labels = ["Topic 1", "Topic 2", "Topic 3", "Topic 4"]
            for (i, angle) in angles.enumerated() {
                let rad = angle * .pi / 180
                let dist: CGFloat = 200
                let nodeId = UUID().uuidString
                let node = MashNodeData(id: nodeId, type: .main,
                    text: labels[i], detail: "", url: "", imageData: nil,
                    x: CGFloat(cos(rad)) * dist, y: CGFloat(sin(rad)) * dist,
                    width: 130, children: [], parentId: doc.rootId,
                    collapsed: false, fillColor: nil, borderColor: nil,
                    textColor: nil, cornerStyle: nil, fontSize: nil, bold: false, italic: false)
                doc.nodes[nodeId] = node
                doc.nodes[doc.rootId]?.children.append(nodeId)
            }
        }
        documents.append(doc)
        activeDocId = doc.id
        save()
        return doc
    }

    public func deleteDocument(_ id: String) {
        documents.removeAll { $0.id == id }
        if activeDocId == id { activeDocId = documents.first?.id }
        save()
    }

    public func updateDocument(_ doc: MashDocument) {
        if let idx = documents.firstIndex(where: { $0.id == doc.id }) {
            var d = doc; d.modified = Date().timeIntervalSince1970
            documents[idx] = d
        }
        save()
    }
}
