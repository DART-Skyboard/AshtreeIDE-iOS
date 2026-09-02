// IDEMindMapView.swift
// Full mind map canvas editor for Ash Tree IDE
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Entry (document picker + canvas)

struct IDEMindMapView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store  = MashStore.shared
    @State private var showNewDoc   = false
    @State private var showDocList  = false
    @State private var editingDoc:  MashDocument? = nil

    var body: some View {
        Group {
            if let doc = store.activeDoc {
                MashCanvasView(doc: doc)
                    .environmentObject(themeVM)
            } else {
                MashWelcomeView(showNew: $showNewDoc, showList: $showDocList)
                    .environmentObject(themeVM)
            }
        }
        .sheet(isPresented: $showNewDoc) {
            MashNewDocSheet(isPresented: $showNewDoc)
                .environmentObject(themeVM)
        }
        .sheet(isPresented: $showDocList) {
            MashDocListSheet(isPresented: $showDocList)
                .environmentObject(themeVM)
        }
    }
}

// MARK: - Welcome Screen

struct MashWelcomeView: View {
    @Binding var showNew:  Bool
    @Binding var showList: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        ZStack {
            Color(hex:"#0d1117").ignoresSafeArea()
            VStack(spacing:20) {
                Image(systemName:"brain.head.profile")
                    .font(.system(size:52)).foregroundColor(themeVM.accent.opacity(0.6))
                Text("MIND MAP").font(.system(size:11,weight:.bold,design:.monospaced))
                    .foregroundColor(themeVM.dim).kerning(4)
                Text("Create and edit .mash mind maps")
                    .font(.system(size:11,design:.monospaced)).foregroundColor(themeVM.dim)

                HStack(spacing:12) {
                    Button { showNew = true } label: {
                        Label("New Map", systemImage:"plus.circle.fill")
                            .font(.system(size:11,weight:.semibold,design:.monospaced))
                            .foregroundColor(.black).padding(.horizontal,18).padding(.vertical,10)
                            .background(themeVM.accent).cornerRadius(10)
                    }
                    Button { showList = true } label: {
                        Label("Open", systemImage:"folder")
                            .font(.system(size:11,weight:.semibold,design:.monospaced))
                            .foregroundColor(themeVM.accent).padding(.horizontal,18).padding(.vertical,10)
                            .background(themeVM.accent.opacity(0.1)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius:10).stroke(themeVM.accent.opacity(0.3),lineWidth:0.5))
                    }
                }
            }
        }
    }
}

// MARK: - New Doc Sheet

struct MashNewDocSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store = MashStore.shared
    @State private var title  = ""
    @State private var layout: MashLayout = .radial
    @State private var themeId = "dark-ash"

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex:"#0d1117").ignoresSafeArea()
                VStack(alignment:.leading, spacing:20) {
                    // Title
                    VStack(alignment:.leading, spacing:6) {
                        Text("TITLE").font(.system(size:8,weight:.bold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(1.5)
                        TextField("My Mind Map", text: $title)
                            .font(.system(size:13,design:.monospaced))
                            .foregroundColor(themeVM.accent)
                            .padding(10).background(Color(hex:"#161b22")).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius:8)
                                .stroke(themeVM.accent.opacity(0.3),lineWidth:0.5))
                    }

                    // Layout
                    VStack(alignment:.leading, spacing:8) {
                        Text("LAYOUT").font(.system(size:8,weight:.bold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(1.5)
                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                            ForEach(MashLayout.allCases, id:\.self) { l in
                                Button { layout = l } label: {
                                    VStack(spacing:4) {
                                        Image(systemName:l.icon).font(.system(size:18))
                                            .foregroundColor(layout==l ? .black : themeVM.accent)
                                        Text(l.displayName).font(.system(size:8,design:.monospaced))
                                            .foregroundColor(layout==l ? .black : themeVM.dim)
                                    }
                                    .frame(maxWidth:.infinity).padding(.vertical,10)
                                    .background(layout==l ? themeVM.accent : themeVM.accent.opacity(0.05))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius:8)
                                        .stroke(layout==l ? themeVM.accent : Color(hex:"#21262d"),lineWidth:0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Theme
                    VStack(alignment:.leading, spacing:8) {
                        Text("THEME").font(.system(size:8,weight:.bold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(1.5)
                        ScrollView(.horizontal, showsIndicators:false) {
                            HStack(spacing:8) {
                                ForEach(MashTheme.builtIn) { theme in
                                    Button { themeId = theme.id } label: {
                                        VStack(spacing:4) {
                                            RoundedRectangle(cornerRadius:6)
                                                .fill(Color(hex:theme.canvasBackground))
                                                .overlay(Circle().fill(Color(hex:theme.rootFill))
                                                    .frame(width:20,height:20))
                                                .frame(width:56,height:40)
                                                .overlay(RoundedRectangle(cornerRadius:6)
                                                    .stroke(themeId==theme.id ? themeVM.accent : Color(hex:"#21262d"),lineWidth:themeId==theme.id ? 2 : 0.5))
                                            Text(theme.name).font(.system(size:8,design:.monospaced))
                                                .foregroundColor(themeId==theme.id ? themeVM.accent : themeVM.dim)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }.padding(.horizontal,2)
                        }
                    }

                    Spacer()

                    Button {
                        let t = title.isEmpty ? "New Mind Map" : title
                        var doc = store.newDocument(title: t, layout: layout)
                        doc.themeId = themeId
                        store.updateDocument(doc)
                        isPresented = false
                    } label: {
                        Text("Create Mind Map")
                            .font(.system(size:13,weight:.semibold))
                            .foregroundColor(.black).frame(maxWidth:.infinity)
                            .padding(.vertical,14).background(themeVM.accent).cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Mind Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Cancel") { isPresented = false }.foregroundColor(themeVM.dim)
                }
            }
        }
    }
}

// MARK: - Doc List Sheet

struct MashDocListSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store = MashStore.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex:"#0d1117").ignoresSafeArea()
                if store.documents.isEmpty {
                    VStack(spacing:12) {
                        Image(systemName:"doc.badge.plus").font(.system(size:36))
                            .foregroundColor(themeVM.dim.opacity(0.4))
                        Text("No mind maps yet").font(.system(size:11,design:.monospaced))
                            .foregroundColor(themeVM.dim)
                    }
                } else {
                    List {
                        ForEach(store.documents, id:\.id) { doc in
                            Button {
                                store.activeDocId = doc.id
                                isPresented = false
                            } label: {
                                HStack(spacing:12) {
                                    let theme = MashTheme.builtIn.first { $0.id == doc.themeId } ?? MashTheme.builtIn[0]
                                    RoundedRectangle(cornerRadius:6)
                                        .fill(Color(hex:theme.canvasBackground))
                                        .overlay(Circle().fill(Color(hex:theme.rootFill)).frame(width:14,height:14))
                                        .frame(width:40,height:32)
                                        .overlay(RoundedRectangle(cornerRadius:6)
                                            .stroke(Color(hex:"#21262d"),lineWidth:0.5))
                                    VStack(alignment:.leading, spacing:2) {
                                        Text(doc.title).font(.system(size:12,weight:.semibold))
                                            .foregroundColor(themeVM.text)
                                        Text("\(doc.nodes.count) nodes · \(doc.layout.displayName)")
                                            .font(.system(size:9,design:.monospaced))
                                            .foregroundColor(themeVM.dim)
                                    }
                                    Spacer()
                                    if store.activeDocId == doc.id {
                                        Image(systemName:"checkmark.circle.fill")
                                            .foregroundColor(themeVM.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for i in offsets { store.deleteDocument(store.documents[i].id) }
                        }
                    }
                    .listStyle(.plain).scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Mind Maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Done") { isPresented = false }.foregroundColor(themeVM.accent)
                }
            }
        }
    }
}

// MARK: - Canvas View (main editor)

struct MashCanvasView: View {
    let doc: MashDocument
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store  = MashStore.shared
    @StateObject private var vm     = MashCanvasVM()
    @State private var showNodeEditor = false
    @State private var showThemePicker = false
    @State private var showExport     = false
    @State private var showDocList    = false
    @State private var showNewDoc         = false
    @State private var showLoadFromEditor = false
    @State private var showRunOutput      = false
    @State private var mashRunOutput      = ""
    @EnvironmentObject var ideVM: IDEState

    var body: some View {
        ZStack {
            // ── Canvas fills everything ─────────────────────
            MashCanvas(doc: doc, vm: vm)
                .environmentObject(themeVM)

            // ── Floating side toolbar (default: left) ────────
            MashSideToolbar(doc: doc, vm: vm,
                            showThemePicker: $showThemePicker,
                            showExport:      $showExport,
                            showDocList:     $showDocList,
                            showNewDoc:      $showNewDoc,
                            showLoadFromEditor: $showLoadFromEditor,
                            onBuildRun:      { buildAndRunMash() })
                .environmentObject(themeVM)

            // ── Mini header bar (just title + layout label) ──
            VStack {
                HStack(spacing: 8) {
                    Button { showDocList = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName:"brain.head.profile").font(.system(size:10))
                            Text(doc.title)
                                .font(.system(size:9, weight:.semibold, design:.monospaced))
                                .lineLimit(1)
                        }
                        .foregroundColor(themeVM.accent)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(hex:"#161b22").opacity(0.92))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius:6)
                            .stroke(themeVM.accent.opacity(0.3), lineWidth:0.5))
                    }
                    Spacer()
                    // Connect mode banner
                    if vm.tool == .connect {
                        Text(vm.connectionFirst == nil ? "Tap first node" : "Tap second node")
                            .font(.system(size:8, weight:.semibold, design:.monospaced))
                            .foregroundColor(.orange)
                            .padding(.horizontal,8).padding(.vertical,4)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(6)
                    }
                    Button { vm.tool = .connect == vm.tool ? .select : .connect } label: {
                        Image(systemName:"arrow.triangle.2.circlepath")
                            .font(.system(size:11))
                            .foregroundColor(vm.tool == .connect ? .orange : themeVM.dim)
                    }
                    // Layout label
                    Button { vm.cycleLayout(doc: doc) } label: {
                        Text(doc.layout.displayName)
                            .font(.system(size:8, design:.monospaced))
                            .foregroundColor(themeVM.accent)
                            .padding(.horizontal,6).padding(.vertical,4)
                            .background(themeVM.accent.opacity(0.1))
                            .cornerRadius(5)
                    }
                    // Zoom reset
                    Button { vm.scale = 1.0; vm.offset = .zero; vm.baseScale = 1.0 } label: {
                        Image(systemName:"arrow.up.left.and.arrow.down.right")
                            .font(.system(size:11)).foregroundColor(themeVM.dim)
                    }
                    // Delete selected
                    if vm.selectedId != nil || !vm.selectedIds.isEmpty {
                        Button { vm.deleteSelected(doc: doc) } label: {
                            Image(systemName:"trash").font(.system(size:11)).foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                Spacer()
                // Bottom zoom indicator
                HStack {
                    Spacer()
                    Text("\(Int(vm.scale * 100))%")
                        .font(.system(size:8, design:.monospaced))
                        .foregroundColor(themeVM.dim.opacity(0.6))
                        .padding(.horizontal,8).padding(.vertical,4)
                        .background(Color(hex:"#0d1117").opacity(0.6))
                        .cornerRadius(5)
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(edges:.bottom)


// MARK: - Side Toolbar

struct MashSideToolbar: View {
    let doc: MashDocument
    @ObservedObject var vm: MashCanvasVM
    @Binding var showThemePicker:     Bool
    @Binding var showExport:          Bool
    @Binding var showDocList:         Bool
    @Binding var showNewDoc:          Bool
    @Binding var showLoadFromEditor:  Bool
    let onBuildRun: () -> Void
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @GestureState private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    // Toolbar items
    var items: [(String, String, () -> Void)] {[
        ("plus.circle.fill",              "Add Node",    { vm.addChildToSelected(doc: doc) }),
        ("hand.tap.fill",                  "Select",     { vm.tool = .select }),
        ("link",                           "Connect",    { vm.tool = vm.tool == .connect ? .select : .connect }),
        ("rectangle.dashed.badge.plus",   "Marquee",    { vm.tool = vm.tool == .marquee ? .select : .marquee }),
        ("paintpalette.fill",             "Theme",       { showThemePicker = true }),
        ("photo.badge.plus",              "Image Node",  { vm.addImageNode(doc: doc) }),
        ("arrow.up.forward.app.fill",     "Export",      { showExport = true }),
        ("square.and.arrow.down.on.square","Load Code",  { showLoadFromEditor = true }),
        ("play.fill",                     "Build & Run", { onBuildRun() }),
        ("plus.square.on.square",         "New Map",     { showNewDoc = true }),
        ("folder.fill",                   "Open Map",    { showDocList = true }),
    ]}

    var edgeOffset: CGFloat {
        switch vm.toolbarSide {
        case .left:   return 8
        case .right:  return 8
        case .top:    return 48  // below header
        case .bottom: return 8
        }
    }

    var body: some View {
        GeometryReader { geo in
            let barContent = VStack(spacing: 2) {
                ForEach(Array(items.enumerated()), id:\.offset) { _, item in
                    Button(action: item.2) {
                        Image(systemName: item.0)
                            .font(.system(size: 16))
                            .foregroundColor(isActiveItem(item.0) ? .black : themeVM.dim)
                            .frame(width: 38, height: 38)
                            .background(isActiveItem(item.0) ? themeVM.accent : themeVM.accent.opacity(0.06))
                            .cornerRadius(9)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex:"#0d1117").opacity(0.93))
                    .shadow(color: .black.opacity(0.5), radius: 12)
            )
            .overlay(RoundedRectangle(cornerRadius:14).stroke(Color(hex:"#21262d"), lineWidth:0.5))
            // Drag to reposition
            .gesture(
                LongPressGesture(minimumDuration: 0.35)
                    .sequenced(before: DragGesture(minimumDistance: 4, coordinateSpace: .global))
                    .onEnded { value in
                        if case .second(true, let drag?) = value {
                            let loc = drag.location
                            let w   = geo.size.width
                            let h   = geo.size.height
                            // Snap to nearest edge
                            let distLeft   = loc.x
                            let distRight  = w - loc.x
                            let distTop    = loc.y
                            let distBottom = h - loc.y
                            let minDist    = min(distLeft, distRight, distTop, distBottom)
                            if      minDist == distLeft   { vm.toolbarSide = .left }
                            else if minDist == distRight  { vm.toolbarSide = .right }
                            else if minDist == distTop    { vm.toolbarSide = .top }
                            else                          { vm.toolbarSide = .bottom }
                        }
                    }
            )
            // Position based on snapped side
            .position(toolbarPosition(in: geo.size))
        }
    }

    private func toolbarPosition(in sz: CGSize) -> CGPoint {
        let pad: CGFloat = 30
        switch vm.toolbarSide {
        case .left:   return CGPoint(x: pad, y: sz.height / 2)
        case .right:  return CGPoint(x: sz.width - pad, y: sz.height / 2)
        case .top:    return CGPoint(x: sz.width / 2, y: edgeOffset + 30)
        case .bottom: return CGPoint(x: sz.width / 2, y: sz.height - edgeOffset - 30)
        }
    }

    private func isActiveItem(_ icon: String) -> Bool {
        switch icon {
        case "hand.tap.fill":   return vm.tool == .select
        case "link":            return vm.tool == .connect
        case "rectangle.dashed.badge.plus": return vm.tool == .marquee
        default: return false
        }
    }
}

// MARK: - Canvas VM

enum MashTool { case select, connect, pan, marquee }

// MARK: - Side toolbar position
enum MashToolbarSide { case left, right, top, bottom }

// MARK: - Canvas ViewModel
@MainActor
class MashCanvasVM: ObservableObject {
    // Viewport
    @Published var scale:           CGFloat = 1.0
    @Published var offset:          CGPoint = .zero   // pan offset in points
    // Selection
    @Published var selectedId:      String? = nil
    @Published var selectedIds:     Set<String> = []
    // Tool
    @Published var tool:            MashTool = .select
    @Published var connectionFirst: String? = nil
    // Drag state (tracked separately to avoid SwiftUI capture issues)
    @Published var isDraggingNode:  Bool = false
    @Published var draggingId:      String? = nil
    @Published var dragStartWorld:  CGPoint = .zero   // world pos when drag started
    // Marquee
    @Published var marqueeStart:    CGPoint? = nil
    @Published var marqueeEnd:      CGPoint? = nil
    @Published var isMarqueeActive: Bool = false
    // Context menu
    @Published var contextNodeId:   String? = nil
    @Published var showContextMenu: Bool = false
    // Toolbar
    @Published var toolbarSide:     MashToolbarSide = .left
    @Published var isDraggingToolbar: Bool = false
    // Zoom limits
    let minScale: CGFloat = 0.05
    let maxScale: CGFloat = 20.0
    // Pan accumulator
    var lastPanTranslation: CGPoint = .zero
    var baseScale: CGFloat = 1.0

    private let store = MashStore.shared

    // ── Coordinate transforms ─────────────────────────────
    // World → screen: screen = canvasCenter + (world + offset) * scale
    func worldToScreen(_ world: CGPoint, canvasSize: CGSize) -> CGPoint {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        return CGPoint(
            x: cx + (world.x + offset.x) * scale,
            y: cy + (world.y + offset.y) * scale
        )
    }

    // Screen → world: world = (screen - canvasCenter) / scale - offset
    func screenToWorld(_ screen: CGPoint, canvasSize: CGSize) -> CGPoint {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        return CGPoint(
            x: (screen.x - cx) / scale - offset.x,
            y: (screen.y - cy) / scale - offset.y
        )
    }

    // ── Node operations ───────────────────────────────────
    func addChildToSelected(doc: MashDocument) {
        let parentId = selectedId ?? doc.rootId
        guard let parent = doc.nodes[parentId] else { return }
        var d = doc
        let count = parent.children.count
        let angle = Double(count) * (2 * .pi / 6)
        let dist: CGFloat = 200
        let newId = UUID().uuidString
        let node = MashNodeData(
            id: newId,
            type: parent.type == .root ? .main : .subtitle,
            text: "New Node", detail: "", url: "", imageData: nil,
            x: parent.x + CGFloat(cos(angle)) * dist,
            y: parent.y + CGFloat(sin(angle)) * dist,
            width: 120, children: [], parentId: parentId,
            collapsed: false, fillColor: nil, borderColor: nil,
            textColor: nil, cornerStyle: nil, fontSize: nil, bold: false, italic: false)
        d.nodes[newId] = node
        d.nodes[parentId]?.children.append(newId)
        store.updateDocument(d)
        selectedId = newId
    }

    func deleteSelected(doc: MashDocument) {
        let idsToDelete = selectedIds.isEmpty
            ? (selectedId.map { Set([$0]) } ?? [])
            : selectedIds
        guard !idsToDelete.isEmpty else { return }
        var d = doc
        func removeAll(_ nid: String) {
            guard nid != doc.rootId else { return }
            if let pid = d.nodes[nid]?.parentId {
                d.nodes[pid]?.children.removeAll { $0 == nid }
            }
            d.nodes[nid]?.children.forEach { removeAll($0) }
            d.nodes.removeValue(forKey: nid)
        }
        idsToDelete.forEach { removeAll($0) }
        d.connections.removeAll { idsToDelete.contains($0.fromId) || idsToDelete.contains($0.toId) }
        store.updateDocument(d)
        selectedId = nil; selectedIds = []
    }

    func handleNodeTap(_ id: String, doc: MashDocument) {
        showContextMenu = false
        switch tool {
        case .select:
            selectedId   = (selectedId == id) ? nil : id
            selectedIds  = selectedId != nil ? [selectedId!] : []
        case .connect:
            if connectionFirst == nil {
                connectionFirst = id
            } else if connectionFirst != id {
                var d = doc
                d.connections.append(MashConnection(from: connectionFirst!, to: id, arrow: .forward))
                store.updateDocument(d)
                connectionFirst = nil; tool = .select
            }
        case .pan, .marquee: break
        }
    }

    func addImageNode(doc: MashDocument) {
        let parentId = selectedId ?? doc.rootId
        guard let parent = doc.nodes[parentId] else { return }
        var d = doc
        let newId = UUID().uuidString
        let node = MashNodeData(id:newId, type:.image, text:"Image", detail:"", url:"",
            imageData:nil, x:parent.x+80, y:parent.y+80, width:140,
            children:[], parentId:parentId, collapsed:false,
            fillColor:nil, borderColor:nil, textColor:nil,
            cornerStyle:nil, fontSize:nil, bold:false, italic:false)
        d.nodes[newId] = node
        d.nodes[parentId]?.children.append(newId)
        store.updateDocument(d)
        selectedId = newId; contextNodeId = newId; showContextMenu = true
    }

    func cycleLayout(doc: MashDocument) {
        let all = MashLayout.allCases
        if let idx = all.firstIndex(of: doc.layout) {
            var d = doc; d.layout = all[(idx + 1) % all.count]
            applyAutoLayout(doc: &d)
            store.updateDocument(d)
        }
    }

    // ── Auto-layout ───────────────────────────────────────
    func applyAutoLayout(doc: inout MashDocument) {
        switch doc.layout {
        case .radial:    layoutRadial(doc: &doc, id: doc.rootId, cx: 0, cy: 0, sa: 0, ea: 2 * .pi, depth: 0)
        case .tree:      layoutTree(doc: &doc, id: doc.rootId, x: 0, y: 0, depth: 0)
        case .fishbone:  layoutFishbone(doc: &doc)
        case .flowchart, .orgchart: layoutOrg(doc: &doc, id: doc.rootId, x: 0, y: 0, depth: 0)
        case .timeline:  layoutTimeline(doc: &doc)
        }
    }
    private func layoutRadial(doc: inout MashDocument, id: String, cx: CGFloat, cy: CGFloat, sa: Double, ea: Double, depth: Int) {
        doc.nodes[id]?.x = cx; doc.nodes[id]?.y = cy
        let children = doc.nodes[id]?.children ?? []; guard !children.isEmpty else { return }
        let span = (ea - sa) / Double(children.count)
        let r: CGFloat = depth == 0 ? 220 : 160
        for (i, cid) in children.enumerated() {
            let a = sa + span * (Double(i) + 0.5)
            layoutRadial(doc: &doc, id: cid, cx: cx + CGFloat(cos(a))*r, cy: cy + CGFloat(sin(a))*r, sa: a-span/2, ea: a+span/2, depth: depth+1)
        }
    }
    private func layoutTree(doc: inout MashDocument, id: String, x: CGFloat, y: CGFloat, depth: Int) {
        doc.nodes[id]?.x = x; doc.nodes[id]?.y = y
        let ch = doc.nodes[id]?.children ?? []
        let sp: CGFloat = 160
        let sx = x - CGFloat(ch.count - 1) * sp / 2
        for (i, cid) in ch.enumerated() { layoutTree(doc: &doc, id: cid, x: sx + CGFloat(i)*sp, y: y+180, depth: depth+1) }
    }
    private func layoutFishbone(doc: inout MashDocument) {
        let ch = doc.nodes[doc.rootId]?.children ?? []
        doc.nodes[doc.rootId]?.x = 0; doc.nodes[doc.rootId]?.y = 0
        for (i, cid) in ch.enumerated() {
            doc.nodes[cid]?.x = CGFloat(i) * 180 - CGFloat(ch.count-1)*90
            doc.nodes[cid]?.y = i.isMultiple(of: 2) ? -150 : 150
        }
    }
    private func layoutOrg(doc: inout MashDocument, id: String, x: CGFloat, y: CGFloat, depth: Int) {
        doc.nodes[id]?.x = x; doc.nodes[id]?.y = y
        let ch = doc.nodes[id]?.children ?? []
        let sp: CGFloat = 160; let sx = x - CGFloat(ch.count-1)*sp/2
        for (i, cid) in ch.enumerated() { layoutOrg(doc: &doc, id: cid, x: sx+CGFloat(i)*sp, y: y+140, depth: depth+1) }
    }
    private func layoutTimeline(doc: inout MashDocument) {
        let ch = doc.nodes[doc.rootId]?.children ?? []
        doc.nodes[doc.rootId]?.x = 0; doc.nodes[doc.rootId]?.y = 0
        for (i, cid) in ch.enumerated() {
            doc.nodes[cid]?.x = CGFloat(i)*200 - CGFloat(ch.count-1)*100
            doc.nodes[cid]?.y = 0
        }
    }
}

// MARK: - Canvas View (the actual rendered canvas)

struct MashCanvas: View {
    let doc:  MashDocument
    @ObservedObject var vm: MashCanvasVM
    @EnvironmentObject var themeVM: IDEThemeViewModel
    // Track drag start position per-node to avoid accumulated error
    @State private var nodeDragBase: CGPoint = .zero

    var theme: MashTheme {
        doc.customTheme ?? MashTheme.builtIn.first { $0.id == doc.themeId } ?? MashTheme.builtIn[0]
    }

    var body: some View {
        GeometryReader { geo in
            let sz = geo.size
            ZStack(alignment: .topLeading) {
                // ── Background ───────────────────────────────
                (theme.canvasTransparent ? Color.clear : Color(hex: theme.canvasBackground))
                    .ignoresSafeArea()

                // ── Dot grid ─────────────────────────────────
                if !theme.canvasTransparent {
                    Canvas { ctx, size in
                        let sp   = max(20, 40 * vm.scale)
                        let ox   = (sz.width/2 + vm.offset.x * vm.scale).truncatingRemainder(dividingBy: sp)
                        let oy   = (sz.height/2 + vm.offset.y * vm.scale).truncatingRemainder(dividingBy: sp)
                        let col  = Color(hex: theme.connectionColor).opacity(0.12)
                        var x = ox; while x < size.width {
                            var y = oy; while y < size.height {
                                ctx.fill(Path(ellipseIn: CGRect(x:x-0.8, y:y-0.8, width:1.6, height:1.6)), with:.color(col))
                                y += sp
                            }
                            x += sp
                        }
                    }
                    .allowsHitTesting(false)
                }

                // ── World content ─────────────────────────────
                ZStack(alignment: .topLeading) {
                    // Connection lines (bottom layer, no hit-testing)
                    Canvas { ctx, _ in
                        drawAllConnections(ctx: ctx, sz: sz)
                    }
                    .allowsHitTesting(false)

                    // Nodes
                    ForEach(Array(doc.nodes.values), id:\.id) { nodeData in
                        let sp = vm.worldToScreen(CGPoint(x: nodeData.x, y: nodeData.y), canvasSize: sz)
                        MashNodeView(
                            nodeData:       nodeData,
                            theme:          theme,
                            isSelected:     vm.selectedId == nodeData.id || vm.selectedIds.contains(nodeData.id),
                            isConnectFirst: vm.connectionFirst == nodeData.id
                        )
                        .scaleEffect(vm.scale)
                        .position(sp)
                        .gesture(nodeDragGesture(for: nodeData, sz: sz))
                        .onTapGesture      { vm.handleNodeTap(nodeData.id, doc: doc) }
                        .onLongPressGesture(minimumDuration: 0.45) {
                            vm.selectedId      = nodeData.id
                            vm.contextNodeId   = nodeData.id
                            vm.showContextMenu = true
                        }
                    }

                    // Marquee rect
                    if let ms = vm.marqueeStart, let me = vm.marqueeEnd {
                        Canvas { ctx, _ in
                            let r = CGRect(x:min(ms.x,me.x), y:min(ms.y,me.y),
                                           width:abs(me.x-ms.x), height:abs(me.y-ms.y))
                            ctx.fill(Path(r), with:.color(Color(hex:theme.connectionColor).opacity(0.08)))
                            ctx.stroke(Path(r), with:.color(Color(hex:theme.connectionColor).opacity(0.8)),
                                       style:StrokeStyle(lineWidth:1.5, dash:[6,4]))
                        }
                        .allowsHitTesting(false)
                    }
                }
                // CLIP to canvas bounds so nothing bleeds out
                .frame(width: sz.width, height: sz.height)
                .clipped()
                // Canvas pan + marquee gesture (fires on empty space)
                .gesture(canvasPanGesture(sz: sz))
                // Pinch to zoom (centered on pinch location)
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            let newScale = (vm.baseScale * val).clamped(to: vm.minScale...vm.maxScale)
                            vm.scale = newScale
                        }
                        .onEnded { _ in vm.baseScale = vm.scale }
                )
                // Tap on empty canvas → deselect
                .onTapGesture {
                    guard !vm.isDraggingNode else { return }
                    vm.selectedId      = nil
                    vm.selectedIds     = []
                    vm.showContextMenu = false
                }

                // Context menu (overlaid, not clipped)
                if vm.showContextMenu, let nid = vm.contextNodeId,
                   let node = doc.nodes[nid] {
                    let sp = vm.worldToScreen(CGPoint(x: node.x, y: node.y), canvasSize: sz)
                    let mx = sp.x.clamped(to: 110...(sz.width - 110))
                    let my = (sp.y - 110).clamped(to: 40...(sz.height - 240))
                    MashContextMenu(nodeId: nid, doc: doc, vm: vm)
                        .environmentObject(themeVM)
                        .position(CGPoint(x: mx, y: my))
                }
            }
            .frame(width: sz.width, height: sz.height)
        }
    }

    // ── Node drag gesture ──────────────────────────────────
    // KEY FIX: capture the world position at drag START, then on each
    // change compute: newWorld = startWorld + translation/scale
    // This avoids the accumulated-delta drift from the previous approach.
    private func nodeDragGesture(for nodeData: MashNodeData, sz: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { val in
                guard vm.tool == .select else { return }
                if !vm.isDraggingNode {
                    // First frame — record the world position at drag start
                    vm.isDraggingNode   = true
                    vm.draggingId       = nodeData.id
                    vm.dragStartWorld   = CGPoint(x: nodeData.x, y: nodeData.y)
                    vm.showContextMenu  = false
                }
                // Compute new world position from start + delta
                let newX = vm.dragStartWorld.x + val.translation.width  / vm.scale
                let newY = vm.dragStartWorld.y + val.translation.height / vm.scale
                var d = doc
                d.nodes[nodeData.id]?.x = newX
                d.nodes[nodeData.id]?.y = newY
                MashStore.shared.updateDocument(d)
            }
            .onEnded { _ in
                vm.isDraggingNode = false
                vm.draggingId     = nil
            }
    }

    // ── Canvas pan + marquee gesture ──────────────────────
    private func canvasPanGesture(sz: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { val in
                guard !vm.isDraggingNode else { return }
                if vm.tool == .marquee || vm.isMarqueeActive {
                    if vm.marqueeStart == nil {
                        vm.marqueeStart     = val.startLocation
                        vm.isMarqueeActive  = true
                    }
                    vm.marqueeEnd = val.location
                } else {
                    // Pan: offset += delta since last frame
                    let dx = val.translation.width  - vm.lastPanTranslation.x
                    let dy = val.translation.height - vm.lastPanTranslation.y
                    vm.offset = CGPoint(x: vm.offset.x + dx / vm.scale,
                                        y: vm.offset.y + dy / vm.scale)
                    vm.lastPanTranslation = CGPoint(x: val.translation.width, y: val.translation.height)
                }
            }
            .onEnded { val in
                vm.lastPanTranslation = .zero
                if vm.isMarqueeActive {
                    if let ms = vm.marqueeStart, let me = vm.marqueeEnd {
                        let rect = CGRect(x:min(ms.x,me.x), y:min(ms.y,me.y),
                                          width:abs(me.x-ms.x), height:abs(me.y-ms.y))
                        var hits = Set<String>()
                        for (_, n) in doc.nodes {
                            let sp = vm.worldToScreen(CGPoint(x:n.x, y:n.y), canvasSize: sz)
                            if rect.contains(sp) { hits.insert(n.id) }
                        }
                        vm.selectedIds = hits
                        vm.selectedId  = hits.count == 1 ? hits.first : nil
                    }
                    vm.marqueeStart    = nil
                    vm.marqueeEnd      = nil
                    vm.isMarqueeActive = false
                }
            }
    }

    // ── Draw all connections ───────────────────────────────
    private func drawAllConnections(ctx: GraphicsContext, sz: CGSize) {
        // Tree edges
        for (_, node) in doc.nodes {
            for childId in node.children {
                guard let child = doc.nodes[childId] else { continue }
                drawEdge(ctx: ctx, sz: sz,
                         from: CGPoint(x: node.x, y: node.y),
                         to:   CGPoint(x: child.x, y: child.y),
                         style: theme.connectionStyle,
                         color: Color(hex: theme.connectionColor),
                         dashed: false, arrow: .none, lineW: 2.5)
            }
        }
        // Cross-reference links
        for conn in doc.connections {
            guard let fn = doc.nodes[conn.fromId], let tn = doc.nodes[conn.toId] else { continue }
            let col = conn.color.map { Color(hex:$0) } ?? Color(hex: theme.connectionColor)
            drawEdge(ctx: ctx, sz: sz,
                     from: CGPoint(x: fn.x, y: fn.y),
                     to:   CGPoint(x: tn.x, y: tn.y),
                     style: theme.connectionStyle,
                     color: col.opacity(0.75), dashed: conn.dashed,
                     arrow: conn.arrowType, lineW: 1.8)
        }
    }

    private func drawEdge(ctx: GraphicsContext, sz: CGSize,
                           from: CGPoint, to: CGPoint,
                           style: MashConnectionStyle, color: Color,
                           dashed: Bool, arrow: MashArrowType, lineW: CGFloat) {
        let fs = vm.worldToScreen(from, canvasSize: sz)
        let ts = vm.worldToScreen(to,   canvasSize: sz)
        var path = Path()
        switch style {
        case .curved, .organic:
            let dx = ts.x - fs.x
            path.move(to: fs)
            path.addCurve(to: ts,
                          control1: CGPoint(x: fs.x + dx * 0.5, y: fs.y),
                          control2: CGPoint(x: ts.x - dx * 0.5, y: ts.y))
        case .straight:
            let mx = fs.x + (ts.x - fs.x) * 0.5
            path.move(to: fs)
            path.addLine(to: CGPoint(x: mx, y: fs.y))
            path.addLine(to: CGPoint(x: mx, y: ts.y))
            path.addLine(to: ts)
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: lineW * min(1, vm.scale + 0.3),
                                      lineCap: .round, lineJoin: .round,
                                      dash: dashed ? [6, 4] : []))
        // Arrow tips
        if arrow != .none {
            let ang = atan2(ts.y - fs.y, ts.x - fs.x)
            let asz = CGFloat(10) * min(1.5, vm.scale + 0.4)
            func tip(_ p: CGPoint, _ a: Double) {
                var arr = Path()
                arr.move(to: p)
                arr.addLine(to: CGPoint(x: p.x - CGFloat(cos(a-0.4))*asz, y: p.y - CGFloat(sin(a-0.4))*asz))
                arr.move(to: p)
                arr.addLine(to: CGPoint(x: p.x - CGFloat(cos(a+0.4))*asz, y: p.y - CGFloat(sin(a+0.4))*asz))
                ctx.stroke(arr, with: .color(color), lineWidth: 1.8)
            }
            if arrow == .forward  || arrow == .both { tip(ts, Double(ang)) }
            if arrow == .backward || arrow == .both { tip(fs, Double(ang) + .pi) }
        }
    }
}

// ── Comparable clamp helper
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Context Menu Popup
struct MashContextMenu: View {
    let nodeId: String
    let doc:    MashDocument
    @ObservedObject var vm: MashCanvasVM
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var node: MashNodeData? { doc.nodes[nodeId] }

    var body: some View {
        VStack(spacing: 0) {
            row("Edit / Detail",    "pencil")          { vm.contextNodeId = nodeId; vm.showContextMenu = false; vm.selectedId = nodeId }
            div()
            row("Add Child Node",  "plus.circle")      { vm.addChildToSelected(doc: doc); vm.showContextMenu = false }
            div()
            row("Duplicate",       "doc.on.doc")       { duplicate() }
            div()
            row("Copy Label",      "doc.on.clipboard") {
                UIPasteboard.general.string = node?.text ?? ""
                vm.showContextMenu = false
            }
            if let url = node?.url, !url.isEmpty {
                div()
                row("Open Link", "link") {
                    if let u = URL(string: url) { UIApplication.shared.open(u) }
                    vm.showContextMenu = false
                }
            }
            div()
            row("Delete", "trash", red: true) { vm.deleteSelected(doc: doc); vm.showContextMenu = false }
        }
        .frame(width: 210)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color(hex: "#161b22").opacity(0.97))
                .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(hex:"#30363d"), lineWidth: 0.5))
    }

    private func duplicate() {
        guard var n = doc.nodes[nodeId] else { return }
        var d = doc
        let newId = UUID().uuidString
        let copy = MashNodeData(id:newId, type:n.type, text:n.text + " (copy)",
            detail:n.detail, url:n.url, imageData:n.imageData,
            x:n.x+70, y:n.y+70, width:n.width,
            children:[], parentId:n.parentId,
            collapsed:false, fillColor:n.fillColor, borderColor:n.borderColor,
            textColor:n.textColor, cornerStyle:n.cornerStyle,
            fontSize:n.fontSize, bold:n.bold, italic:n.italic)
        d.nodes[newId] = copy
        if let pid = copy.parentId { d.nodes[pid]?.children.append(newId) }
        MashStore.shared.updateDocument(d)
        vm.selectedId = newId
        vm.showContextMenu = false
        _ = n
    }

    @ViewBuilder private func row(_ label: String, _ icon: String, red: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size:13))
                    .foregroundColor(red ? .red : themeVM.dim).frame(width: 20)
                Text(label).font(.system(size:12, design:.monospaced))
                    .foregroundColor(red ? .red : themeVM.text)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }.buttonStyle(.plain)
    }
    @ViewBuilder private func div() -> some View {
        Divider().background(Color(hex:"#21262d"))
    }
}

// MARK: - Node View

struct MashNodeView: View {
    let nodeData:       MashNodeData
    let theme:          MashTheme
    let isSelected:     Bool
    let isConnectFirst: Bool

    var fillHex:   String { nodeData.fillColor   ?? fillForType }
    var borderHex: String { nodeData.borderColor ?? borderForType }
    var textHex:   String { nodeData.textColor   ?? textForType }

    var fillForType: String {
        switch nodeData.type {
        case .root:     return theme.rootFill
        case .main:     return theme.mainFill
        case .subtitle: return theme.subtitleFill
        case .category: return theme.categoryFill
        default:        return theme.noteFill
        }
    }
    var borderForType: String {
        switch nodeData.type {
        case .root:     return theme.rootBorder
        case .main:     return theme.mainBorder
        case .subtitle: return theme.subtitleBorder
        case .category: return theme.categoryBorder
        default:        return theme.noteBorder
        }
    }
    var textForType: String {
        switch nodeData.type {
        case .root:     return theme.rootText
        case .main:     return theme.mainText
        case .subtitle: return theme.subtitleText
        case .category: return theme.categoryText
        default:        return theme.noteText
        }
    }

    var corner: CGFloat {
        let cs = nodeData.cornerStyle ?? theme.cornerStyle
        switch cs {
        case .rounded:  return 12
        case .square:   return 2
        case .pill:     return 50
        case .diamond:  return 0   // handled with rotation
        case .hexagon:  return 6
        }
    }

    var fontSize: CGFloat { nodeData.fontSize ?? nodeData.type.defaultFontSize }

    var body: some View {
        VStack(spacing:4) {
            // Image attachment
            if let imgData = nodeData.imageData, let uiImg = UIImage(data: imgData) {
                Image(uiImage: uiImg)
                    .resizable().scaledToFill()
                    .frame(width: nodeData.width - 16, height: 60)
                    .clipped().cornerRadius(6)
            }

            Text(nodeData.text)
                .font(.system(size: fontSize,
                              weight: nodeData.bold ? .bold : .regular,
                              design: .default))
                .italic(nodeData.italic)
                .foregroundColor(Color(hex: textHex))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8).padding(.vertical, 6)

            // URL indicator
            if !nodeData.url.isEmpty {
                Image(systemName:"link").font(.system(size:8))
                    .foregroundColor(Color(hex: textHex).opacity(0.6))
            }
            // Note indicator
            if !nodeData.detail.isEmpty {
                Image(systemName:"note.text").font(.system(size:7))
                    .foregroundColor(Color(hex: textHex).opacity(0.5))
            }
        }
        .frame(width: nodeData.width)
        .background(Color(hex: fillHex))
        .cornerRadius(corner)
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .stroke(isSelected ? Color.white :
                        isConnectFirst ? Color.orange :
                        Color(hex: borderHex),
                        lineWidth: isSelected ? 2.5 : 1.5)
        )
        .shadow(color: Color(hex: borderHex).opacity(isSelected ? 0.6 : 0.2),
                radius: isSelected ? 8 : 3)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response:0.2, dampingFraction:0.8), value: isSelected)
    }
}

// MARK: - Node Editor Sheet

struct MashNodeEditorSheet: View {
    let nodeData:   MashNodeData
    let doc:        MashDocument
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store = MashStore.shared

    @State private var text:   String = ""
    @State private var detail: String = ""
    @State private var url:    String = ""
    @State private var bold:   Bool   = false
    @State private var italic: Bool   = false
    @State private var type:   MashNodeType = .note
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex:"#0d1117").ignoresSafeArea()
                ScrollView {
                    VStack(alignment:.leading, spacing:16) {
                        // Node type
                        ScrollView(.horizontal, showsIndicators:false) {
                            HStack(spacing:6) {
                                ForEach(MashNodeType.allCases, id:\.self) { t in
                                    Button { type = t } label: {
                                        Text(t.rawValue.capitalized)
                                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                                            .foregroundColor(type==t ? .black : themeVM.dim)
                                            .padding(.horizontal,10).padding(.vertical,5)
                                            .background(type==t ? themeVM.accent : Color(hex:"#161b22"))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Text
                        field("Label", binding: $text, mono: false)
                        field("Notes / Detail", binding: $detail, mono: false)
                        field("Hyperlink URL", binding: $url, mono: true)

                        // Style
                        HStack(spacing:12) {
                            Toggle("Bold", isOn: $bold).tint(themeVM.accent)
                            Toggle("Italic", isOn: $italic).tint(themeVM.accent)
                        }
                        .font(.system(size:11,design:.monospaced))
                        .foregroundColor(themeVM.dim)

                        // Image
                        Button { showImagePicker = true } label: {
                            Label(pickedImage != nil ? "Change Image" : "Attach Image",
                                  systemImage: "photo.badge.plus")
                                .font(.system(size:11,design:.monospaced))
                                .foregroundColor(themeVM.accent)
                                .frame(maxWidth:.infinity).padding(.vertical,10)
                                .background(themeVM.accent.opacity(0.08)).cornerRadius(8)
                        }
                        if let img = pickedImage {
                            Image(uiImage:img).resizable().scaledToFit()
                                .frame(maxHeight:120).cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Cancel") { isPresented = false }.foregroundColor(themeVM.dim)
                }
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button("Save") { saveNode(); isPresented = false }
                        .font(.system(size:11,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.accent)
                }
            }
            .onAppear {
                text   = nodeData.text
                detail = nodeData.detail
                url    = nodeData.url
                bold   = nodeData.bold
                italic = nodeData.italic
                type   = nodeData.type
                if let d = nodeData.imageData { pickedImage = UIImage(data:d) }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $pickedImage)
        }
    }

    private func saveNode() {
        var d = doc
        d.nodes[nodeData.id]?.text      = text
        d.nodes[nodeData.id]?.detail    = detail
        d.nodes[nodeData.id]?.url       = url
        d.nodes[nodeData.id]?.bold      = bold
        d.nodes[nodeData.id]?.italic    = italic
        d.nodes[nodeData.id]?.type      = type
        d.nodes[nodeData.id]?.imageData = pickedImage.flatMap { $0.jpegData(compressionQuality: 0.8) }
        store.updateDocument(d)
    }

    @ViewBuilder
    private func field(_ label: String, binding: Binding<String>, mono: Bool) -> some View {
        VStack(alignment:.leading, spacing:4) {
            Text(label.uppercased())
                .font(.system(size:7,weight:.bold,design:.monospaced))
                .foregroundColor(themeVM.dim).kerning(1.5)
            TextField(label, text: binding, axis: .vertical)
                .font(.system(size:12, design: mono ? .monospaced : .default))
                .foregroundColor(themeVM.accent)
                .lineLimit(1...6)
                .padding(10).background(Color(hex:"#161b22")).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius:8)
                    .stroke(Color(hex:"#21262d"),lineWidth:0.5))
        }
    }
}

// MARK: - Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.delegate = context.coordinator
        p.sourceType = .photoLibrary
        return p
    }
    func updateUIViewController(_: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ p: ImagePickerView) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey:Any]) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// MARK: - Theme Sheet

struct MashThemeSheet: View {
    let doc: MashDocument
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store = MashStore.shared
    @State private var selectedThemeId: String = ""
    @State private var showCustom = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex:"#0d1117").ignoresSafeArea()
                ScrollView {
                    VStack(alignment:.leading, spacing:16) {
                        Text("BUILT-IN THEMES")
                            .font(.system(size:8,weight:.bold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(2)

                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())], spacing:10) {
                            ForEach(MashTheme.builtIn) { theme in
                                Button { selectedThemeId = theme.id } label: {
                                    VStack(alignment:.leading, spacing:8) {
                                        // Mini canvas preview
                                        ZStack {
                                            RoundedRectangle(cornerRadius:8)
                                                .fill(Color(hex:theme.canvasBackground))
                                                .frame(height:70)
                                            // Root node
                                            RoundedRectangle(cornerRadius:6)
                                                .fill(Color(hex:theme.rootFill))
                                                .frame(width:50,height:20)
                                            // Branch nodes
                                            ForEach([-45.0,0.0,45.0], id:\.self) { a in
                                                let r = 40.0
                                                RoundedRectangle(cornerRadius:4)
                                                    .fill(Color(hex:theme.mainFill))
                                                    .frame(width:30,height:14)
                                                    .offset(x:CGFloat(cos(a*(.pi/180)))*CGFloat(r),
                                                            y:CGFloat(sin(a*(.pi/180)))*CGFloat(r))
                                            }
                                        }
                                        .overlay(RoundedRectangle(cornerRadius:8)
                                            .stroke(selectedThemeId==theme.id ? themeVM.accent : Color(hex:"#21262d"),
                                                    lineWidth: selectedThemeId==theme.id ? 2 : 0.5))

                                        Text(theme.name)
                                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                                            .foregroundColor(selectedThemeId==theme.id ? themeVM.accent : themeVM.text)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Cancel") { isPresented = false }.foregroundColor(themeVM.dim)
                }
                ToolbarItem(placement:.navigationBarTrailing) {
                    Button("Apply") {
                        var d = doc; d.themeId = selectedThemeId
                        store.updateDocument(d); isPresented = false
                    }
                    .font(.system(size:11,weight:.semibold,design:.monospaced))
                    .foregroundColor(themeVM.accent)
                }
            }
            .onAppear { selectedThemeId = doc.themeId }
        }
    }
}

// MARK: - Export Sheet

struct MashExportSheet: View {
    let doc: MashDocument
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var exporting = false
    @State private var exportMsg = ""
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex:"#0d1117").ignoresSafeArea()
                VStack(alignment:.leading, spacing:14) {
                    Text("EXPORT FORMAT").font(.system(size:8,weight:.bold,design:.monospaced))
                        .foregroundColor(themeVM.dim).kerning(2)

                    exportRow("MASH — Native Format", icon:"doc.badge.checkmark", color:"#00ffcc") {
                        exportMASH()
                    }
                    exportRow("FreeMind (.mm)", icon:"doc.text", color:"#39ff14") {
                        exportFreeMind()
                    }
                    exportRow("Markdown (.md)", icon:"doc.plaintext", color:"#4488ff") {
                        exportMarkdown()
                    }
                    exportRow("PDF — High Resolution", icon:"doc.richtext", color:"#ff6b6b") {
                        exportPDF()
                    }
                    exportRow("PNG — Transparent", icon:"photo", color:"#ffaa00") {
                        exportPNG(transparent: true)
                    }
                    exportRow("PNG — With Background", icon:"photo.fill", color:"#cc88ff") {
                        exportPNG(transparent: false)
                    }

                    if exporting {
                        HStack { ProgressView().tint(themeVM.accent); Text("Exporting…")
                            .font(.system(size:10,design:.monospaced)).foregroundColor(themeVM.dim) }
                    }
                    if !exportMsg.isEmpty {
                        Text(exportMsg).font(.system(size:10,design:.monospaced))
                            .foregroundColor(exportMsg.contains("✓") ? .green : .orange)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Done") { isPresented = false }.foregroundColor(themeVM.accent)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    @ViewBuilder
    private func exportRow(_ label: String, icon: String, color: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing:12) {
                Image(systemName:icon).font(.system(size:16)).foregroundColor(Color(hex:color))
                    .frame(width:24)
                Text(label).font(.system(size:11,design:.monospaced)).foregroundColor(themeVM.text)
                Spacer()
                Image(systemName:"chevron.right").font(.system(size:10)).foregroundColor(themeVM.dim)
            }
            .padding(12).background(Color(hex:"#161b22")).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius:8).stroke(Color(hex:"#21262d"),lineWidth:0.5))
        }
        .buttonStyle(.plain)
    }

    // ── Export implementations ────────────────────────────

    private func exportMASH() {
        do {
            let data = try JSONEncoder().encode(doc)
            let name = doc.title.replacingOccurrences(of:" ",with:"-").lowercased() + ".mash"
            let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url)
            exportURL = url; showShareSheet = true
            exportMsg = "✓ MASH file ready"
        } catch { exportMsg = "Export failed: \(error.localizedDescription)" }
    }

    private func exportFreeMind() {
        var mm = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<map version=\"1.0.1\">\n"
        func nodeXML(_ id: String, indent: String) {
            guard let n = doc.nodes[id] else { return }
            let text = n.text.replacingOccurrences(of:"\"",with:"&quot;")
            mm += "\(indent)<node TEXT=\"\(text)\">\n"
            for childId in n.children { nodeXML(childId, indent: indent + "  ") }
            mm += "\(indent)</node>\n"
        }
        nodeXML(doc.rootId, indent: "  ")
        mm += "</map>"
        save(content: mm, ext: "mm", msg: "✓ FreeMind .mm exported")
    }

    private func exportMarkdown() {
        var md = "# \(doc.title)\n\n"
        func nodemd(_ id: String, level: Int) {
            guard let n = doc.nodes[id] else { return }
            let prefix = String(repeating: "  ", count: max(0, level - 1))
            let bullet = level == 0 ? "# " : level == 1 ? "## " : prefix + "- "
            md += "\(bullet)\(n.text)\n"
            if !n.detail.isEmpty { md += "\(prefix)  > \(n.detail)\n" }
            if !n.url.isEmpty    { md += "\(prefix)  🔗 [\(n.url)](\(n.url))\n" }
            for childId in n.children { nodemd(childId, level: level + 1) }
        }
        nodemd(doc.rootId, level: 0)
        if !doc.connections.isEmpty {
            md += "\n## Cross References\n"
            for conn in doc.connections {
                let from = doc.nodes[conn.fromId]?.text ?? conn.fromId
                let to   = doc.nodes[conn.toId]?.text   ?? conn.toId
                let arrow = conn.arrowType == .both ? "↔" : conn.arrowType == .backward ? "←" : "→"
                md += "- **\(from)** \(arrow) **\(to)**"
                if !conn.label.isEmpty { md += " (\(conn.label))" }
                md += "\n"
            }
        }
        save(content: md, ext: "md", msg: "✓ Markdown exported")
    }

    private func exportPDF() {
        // PDF using UIGraphicsPDFRenderer
        let pageW: CGFloat = 842, pageH: CGFloat = 595
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x:0,y:0,width:pageW,height:pageH))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            let c = ctx.cgContext
            let theme = doc.customTheme ?? MashTheme.builtIn.first { $0.id == doc.themeId } ?? MashTheme.builtIn[0]
            // Background
            c.setFillColor(UIColor(Color(hex:theme.canvasBackground)).cgColor)
            c.fill(CGRect(x:0,y:0,width:pageW,height:pageH))
            // Title
            let attrs: [NSAttributedString.Key:Any] = [
                .font: UIFont.boldSystemFont(ofSize:18),
                .foregroundColor: UIColor(Color(hex:theme.rootText))
            ]
            NSAttributedString(string: doc.title, attributes: attrs)
                .draw(at: CGPoint(x:40, y:30))
            // Nodes — draw a flat list since PDF canvas positioning is complex
            var y: CGFloat = 70
            func drawNode(_ id: String, indent: CGFloat) {
                guard let n = doc.nodes[id], y < pageH - 30 else { return }
                let nodeAttrs: [NSAttributedString.Key:Any] = [
                    .font: n.bold ? UIFont.boldSystemFont(ofSize:11) : UIFont.systemFont(ofSize:11),
                    .foregroundColor: UIColor(Color(hex: theme.noteText))
                ]
                let bullet = n.type == .root ? "●" : n.type == .main ? "◆" : "  ·"
                NSAttributedString(string:"\(bullet) \(n.text)", attributes:nodeAttrs)
                    .draw(at: CGPoint(x: 40 + indent, y: y))
                y += 18
                if !n.detail.isEmpty {
                    let dAttrs: [NSAttributedString.Key:Any] = [
                        .font: UIFont.italicSystemFont(ofSize:9),
                        .foregroundColor: UIColor(Color(hex:theme.noteText)).withAlphaComponent(0.6)
                    ]
                    NSAttributedString(string:"  \(n.detail)", attributes:dAttrs)
                        .draw(at: CGPoint(x:50+indent, y:y))
                    y += 14
                }
                for childId in n.children { drawNode(childId, indent:indent+20) }
            }
            drawNode(doc.rootId, indent: 0)
        }
        let name = doc.title.lowercased().replacingOccurrences(of:" ",with:"-") + ".pdf"
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        exportURL = url; showShareSheet = true; exportMsg = "✓ PDF exported"
    }

    private func exportPNG(transparent: Bool) {
        let scale: CGFloat = 2.0
        let size  = CGSize(width:1600, height:1200)
        let theme = doc.customTheme ?? MashTheme.builtIn.first { $0.id == doc.themeId } ?? MashTheme.builtIn[0]

        UIGraphicsBeginImageContextWithOptions(size, !transparent, scale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Background
        if !transparent {
            ctx.setFillColor(UIColor(Color(hex:theme.canvasBackground)).cgColor)
            ctx.fill(CGRect(origin:.zero, size:size))
        }

        let cx = size.width / 2, cy = size.height / 2

        // Draw connections
        func drawLine(from: CGPoint, to: CGPoint) {
            ctx.setStrokeColor(UIColor(Color(hex:theme.connectionColor)).withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x:cx+from.x, y:cy+from.y))
            ctx.addCurve(to: CGPoint(x:cx+to.x, y:cy+to.y),
                         control1: CGPoint(x:cx+from.x+(to.x-from.x)*0.5, y:cy+from.y),
                         control2: CGPoint(x:cx+from.x+(to.x-from.x)*0.5, y:cy+to.y))
            ctx.strokePath()
        }
        for (_, node) in doc.nodes {
            for childId in node.children {
                guard let child = doc.nodes[childId] else { continue }
                drawLine(from:CGPoint(x:node.x,y:node.y), to:CGPoint(x:child.x,y:child.y))
            }
        }

        // Draw nodes
        for (_, n) in doc.nodes {
            let fill   = UIColor(Color(hex: n.fillColor   ?? (n.type == .root ? theme.rootFill   : theme.mainFill)))
            let border = UIColor(Color(hex: n.borderColor ?? (n.type == .root ? theme.rootBorder : theme.mainBorder)))
            let text   = UIColor(Color(hex: n.textColor   ?? (n.type == .root ? theme.rootText   : theme.mainText)))
            let nodeW  = n.width
            let nodeH: CGFloat = n.type == .root ? 50 : 36
            let rect   = CGRect(x:cx+n.x-nodeW/2, y:cy+n.y-nodeH/2, width:nodeW, height:nodeH)
            let path   = UIBezierPath(roundedRect:rect, cornerRadius:10)
            fill.setFill(); path.fill()
            border.setStroke(); path.lineWidth = 2; path.stroke()
            let attrs: [NSAttributedString.Key:Any] = [
                .font: n.bold ? UIFont.boldSystemFont(ofSize:n.fontSize ?? 12) : UIFont.systemFont(ofSize:n.fontSize ?? 10),
                .foregroundColor: text
            ]
            let str = NSAttributedString(string:n.text, attributes:attrs)
            let strSize = str.size()
            str.draw(at:CGPoint(x:rect.midX-strSize.width/2, y:rect.midY-strSize.height/2))
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let png = transparent ? img?.pngData() : img?.jpegData(compressionQuality:0.95) else { return }
        let ext  = transparent ? "png" : "png"
        let name = doc.title.lowercased().replacingOccurrences(of:" ",with:"-") + "-mindmap." + ext
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? png.write(to:url)
        exportURL = url; showShareSheet = true
        exportMsg = transparent ? "✓ Transparent PNG exported (2×)" : "✓ PNG exported (2×)"
    }

    private func save(content: String, ext: String, msg: String) {
        let name = doc.title.lowercased().replacingOccurrences(of:" ",with:"-") + "." + ext
        let url  = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? content.write(to:url, atomically:true, encoding:.utf8)
        exportURL = url; showShareSheet = true; exportMsg = msg
    }
}

// ── Load from Editor Sheet ──────────────────────────────────
struct MashLoadFromEditorSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM:  IDEThemeViewModel
    @EnvironmentObject var ideVM:    IDEState
    @StateObject private var store   = MashStore.shared
    @State private var selectedExample: String? = nil

    // All IDE examples that can be loaded
    struct ExampleEntry: Identifiable {
        let id = UUID()
        let name: String
        let code: String
        let icon: String
    }

    var examples: [ExampleEntry] {
        IDEDefaults.examples.map { ex in
            ExampleEntry(name: ex.name, code: ex.code,
                         icon: ex.name.lowercased().contains("3d") || ex.name.lowercased().contains("gl") ? "cube" :
                               ex.name.lowercased().contains("physics") ? "atom" :
                               ex.name.lowercased().contains("network") ? "network" :
                               ex.name.lowercased().contains("autumn") ? "brain" : "doc.text")
        }
    }

    var editorEntry: ExampleEntry {
        ExampleEntry(name: ideVM.currentFile.isEmpty ? "Editor Code" : ideVM.currentFile,
                     code: ideVM.sourceCode,
                     icon: "chevron.left.forwardslash.chevron.right")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex:"#0d1117").ignoresSafeArea()
                ScrollView {
                    VStack(alignment:.leading, spacing:14) {
                        // Current editor content
                        if !ideVM.sourceCode.isEmpty {
                            Text("CURRENT EDITOR").font(.system(size:8,weight:.bold,design:.monospaced))
                                .foregroundColor(themeVM.dim).kerning(2)
                            loadRow(entry: editorEntry)
                        }

                        Text("ASH EXAMPLES").font(.system(size:8,weight:.bold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(2).padding(.top,4)

                        ForEach(examples) { ex in
                            loadRow(entry: ex)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Load into Mind Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Cancel") { isPresented = false }.foregroundColor(themeVM.dim)
                }
            }
        }
    }

    @ViewBuilder
    private func loadRow(entry: ExampleEntry) -> some View {
        Button {
            let doc = MashAshCodeGenerator.fromExample(name: entry.name, code: entry.code)
            store.documents.append(doc)
            store.activeDocId = doc.id
            store.save()
            isPresented = false
        } label: {
            HStack(spacing:12) {
                Image(systemName:entry.icon).font(.system(size:16))
                    .foregroundColor(themeVM.accent).frame(width:24)
                VStack(alignment:.leading, spacing:2) {
                    Text(entry.name).font(.system(size:11,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.text)
                    Text("Parse ASH → mind map nodes")
                        .font(.system(size:9,design:.monospaced)).foregroundColor(themeVM.dim)
                }
                Spacer()
                Image(systemName:"arrow.right.circle.fill").foregroundColor(themeVM.accent)
            }
            .padding(12).background(Color(hex:"#161b22")).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius:8).stroke(Color(hex:"#21262d"),lineWidth:0.5))
        }
        .buttonStyle(.plain)
    }
}

// ShareSheet is defined in IDEMainView.swift
}
}

