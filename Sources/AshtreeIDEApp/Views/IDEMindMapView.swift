// IDEMindMapView.swift
// Ash Map — mind map module for Ash Tree IDE
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Tool Enum

enum MashTool { case select, connect, connectSingle, mainLink, pan, marquee }
enum MashToolbarSide { case left, right, top, bottom }

// MARK: - Canvas ViewModel

@MainActor
class MashCanvasVM: ObservableObject {
    // Viewport
    @Published var scale:           CGFloat = 1.0
    @Published var offset:          CGPoint = .zero
    var baseScale:                  CGFloat = 1.0
    // Selection
    @Published var selectedId:      String? = nil
    @Published var selectedIds:     Set<String> = []
    // Tool
    @Published var tool:            MashTool = .select
    @Published var connectionFirst: String? = nil
    // Drag — tracked from drag-start to avoid drift
    @Published var isDraggingNode:  Bool = false
    @Published var draggingId:      String? = nil
    @Published var dragStartWorld:  CGPoint = .zero
    // Marquee
    @Published var marqueeStart:    CGPoint? = nil
    @Published var marqueeEnd:      CGPoint? = nil
    @Published var isMarqueeActive: Bool = false
    // Context menu
    @Published var contextNodeId:   String? = nil
    @Published var showContextMenu: Bool = false
    // Node editor — drive directly from VM so onChange isn't needed
    @Published var showNodeEditor:  Bool = false
    @Published var editorNodeId:    String? = nil
    // Connection selection + editing
    @Published var selectedConnId:  String? = nil
    @Published var showConnMenu:    Bool = false
    // Toolbar snap
    @Published var toolbarSide:     MashToolbarSide = .left
    // Image picker trigger
    @Published var showImagePickerForNode: String? = nil
    // Pan accumulator
    var lastPanTranslation:         CGPoint = .zero
    // Zoom
    let minScale: CGFloat = 0.05
    let maxScale: CGFloat = 20.0

    private let store = MashStore.shared

    // Coordinate transforms
    func worldToScreen(_ world: CGPoint, sz: CGSize) -> CGPoint {
        CGPoint(
            x: sz.width  / 2 + (world.x + offset.x) * scale,
            y: sz.height / 2 + (world.y + offset.y) * scale
        )
    }
    func screenToWorld(_ screen: CGPoint, sz: CGSize) -> CGPoint {
        CGPoint(
            x: (screen.x - sz.width  / 2) / scale - offset.x,
            y: (screen.y - sz.height / 2) / scale - offset.y
        )
    }

    func addChildToSelected(doc: MashDocument) {
        let parentId = selectedId ?? doc.rootId
        guard let parent = doc.nodes[parentId] else { return }
        var d = doc
        let count = parent.children.count
        let divisor = Double(max(1, count + 1))
        let angle = Double(count) * (2.0 * Double.pi / divisor)
        let dist: CGFloat = 200
        let newId = UUID().uuidString
        let node = MashNodeData(id:newId,
            type: parent.type == .root ? .main : .subtitle,
            text:"New Node", detail:"", url:"", imageData:nil,
            x: parent.x + CGFloat(cos(angle)) * dist,
            y: parent.y + CGFloat(sin(angle)) * dist,
            width:120, children:[], parentId:parentId,
            collapsed:false, fillColor:nil, borderColor:nil,
            textColor:nil, cornerStyle:nil, fontSize:nil, bold:false, italic:false)
        d.nodes[newId] = node
        d.nodes[parentId]?.children.append(newId)
        store.updateDocument(d)
        selectedId = newId
    }

    func addImageNode(doc: MashDocument) {
        let parentId = selectedId ?? doc.rootId
        guard let parent = doc.nodes[parentId] else { return }
        var d = doc
        let newId = UUID().uuidString
        let node = MashNodeData(id:newId, type:.image, text:"Image",
            detail:"", url:"", imageData:nil,
            x:parent.x+80, y:parent.y+80, width:140,
            children:[], parentId:parentId, collapsed:false,
            fillColor:nil, borderColor:nil, textColor:nil,
            cornerStyle:nil, fontSize:nil, bold:false, italic:false)
        d.nodes[newId] = node
        d.nodes[parentId]?.children.append(newId)
        store.updateDocument(d)
        selectedId = newId; contextNodeId = newId; showContextMenu = true
    }

    func deleteSelected(doc: MashDocument) {
        let ids = selectedIds.isEmpty ? (selectedId.map { Set([$0]) } ?? []) : selectedIds
        guard !ids.isEmpty else { return }
        var d = doc
        for nid in ids {
            guard nid != doc.rootId, let node = d.nodes[nid] else { continue }
            let grandParentId = node.parentId ?? doc.rootId
            // Re-parent children to grandparent (don't delete them)
            for childId in node.children {
                d.nodes[childId]?.parentId = grandParentId
                if !(d.nodes[grandParentId]?.children.contains(childId) ?? false) {
                    d.nodes[grandParentId]?.children.append(childId)
                }
            }
            // Remove from parent's children list
            if let pid = node.parentId {
                d.nodes[pid]?.children.removeAll { $0 == nid }
            }
            d.nodes.removeValue(forKey: nid)
        }
        // Remove reference connections to deleted nodes (tree edges auto-heal above)
        d.connections.removeAll { ids.contains($0.fromId) || ids.contains($0.toId) }
        store.updateDocument(d)
        selectedId = nil; selectedIds = []
    }

    // Delete a specific reference connection
    func deleteConnection(_ id: String, doc: MashDocument) {
        var d = doc
        d.connections.removeAll { $0.id == id }
        store.updateDocument(d)
        selectedConnId = nil; showConnMenu = false
    }

    // Add a free-standing node (no parent link — user links manually)
    func addFreeNode(doc: MashDocument) {
        var d = doc
        let newId = UUID().uuidString
        let cx = (d.nodes.values.map { $0.x }.reduce(0,+) / CGFloat(max(1, d.nodes.count))) + 120
        let cy = (d.nodes.values.map { $0.y }.reduce(0,+) / CGFloat(max(1, d.nodes.count))) + 120
        let node = MashNodeData(id:newId, type:.main, text:"New Node",
            detail:"", url:"", imageData:nil,
            x:cx, y:cy, width:130, children:[], parentId:nil,
            collapsed:false, fillColor:nil, borderColor:nil,
            textColor:nil, cornerStyle:nil, fontSize:nil, bold:false, italic:false)
        d.nodes[newId] = node
        store.updateDocument(d)
        selectedId = newId
    }

    func handleNodeTap(_ id: String, doc: MashDocument) {
        showContextMenu = false; showConnMenu = false; selectedConnId = nil
        switch tool {
        case .select:
            selectedId  = (selectedId == id) ? nil : id
            selectedIds = selectedId != nil ? [selectedId!] : []
        case .connect:
            // Bidirectional dashed reference curve (↔)
            if connectionFirst == nil {
                connectionFirst = id
            } else if connectionFirst != id {
                var d = doc
                var c = MashConnection(from:connectionFirst!, to:id, arrow:.both)
                c.dashed = true
                d.connections.append(c)
                store.updateDocument(d)
                connectionFirst = nil; tool = .select
            }
        case .connectSingle:
            // Single-direction dashed curve (→)
            if connectionFirst == nil {
                connectionFirst = id
            } else if connectionFirst != id {
                var d = doc
                var c = MashConnection(from:connectionFirst!, to:id, arrow:.forward)
                c.dashed = true
                d.connections.append(c)
                store.updateDocument(d)
                connectionFirst = nil; tool = .select
            }
        case .mainLink:
            // Solid main tree-edge between two nodes (reparents second to first)
            if connectionFirst == nil {
                connectionFirst = id
            } else if connectionFirst != id {
                var d = doc
                // Remove old parent link for target
                if let oldPid = d.nodes[id]?.parentId {
                    d.nodes[oldPid]?.children.removeAll { $0 == id }
                }
                d.nodes[id]?.parentId = connectionFirst!
                d.nodes[connectionFirst!]?.children.append(id)
                store.updateDocument(d)
                connectionFirst = nil; tool = .select
            }
        case .pan, .marquee: break
        }
    }

    func cycleLayout(doc: MashDocument) {
        let all = MashLayout.allCases
        if let idx = all.firstIndex(of: doc.layout) {
            var d = doc; d.layout = all[(idx+1) % all.count]
            applyAutoLayout(doc: &d)
            store.updateDocument(d)
        }
    }

    func applyAutoLayout(doc: inout MashDocument) {
        switch doc.layout {
        case .radial:   radial(doc:&doc, id:doc.rootId, cx:0, cy:0, sa:0, ea:2 * .pi, depth:0)
        case .tree:     tree(doc:&doc, id:doc.rootId, x:0, y:0)
        case .fishbone: fishbone(doc:&doc)
        case .flowchart,.orgchart: org(doc:&doc, id:doc.rootId, x:0, y:0)
        case .timeline: timeline(doc:&doc)
        }
    }
    private func radial(doc:inout MashDocument,id:String,cx:CGFloat,cy:CGFloat,sa:Double,ea:Double,depth:Int) {
        doc.nodes[id]?.x=cx; doc.nodes[id]?.y=cy
        let ch=doc.nodes[id]?.children ?? []; guard !ch.isEmpty else{return}
        let span=(ea-sa)/Double(ch.count); let r:CGFloat=depth==0 ? 220:160
        for(i,cid)in ch.enumerated(){let a=sa+span*(Double(i)+0.5); radial(doc:&doc,id:cid,cx:cx+CGFloat(cos(a))*r,cy:cy+CGFloat(sin(a))*r,sa:a-span/2,ea:a+span/2,depth:depth+1)}
    }
    private func tree(doc:inout MashDocument,id:String,x:CGFloat,y:CGFloat) {
        doc.nodes[id]?.x=x; doc.nodes[id]?.y=y
        let ch=doc.nodes[id]?.children ?? []; let sp:CGFloat=160
        let sx=x-CGFloat(ch.count-1)*sp/2
        for(i,cid)in ch.enumerated(){tree(doc:&doc,id:cid,x:sx+CGFloat(i)*sp,y:y+180)}
    }
    private func fishbone(doc:inout MashDocument) {
        let ch=doc.nodes[doc.rootId]?.children ?? []
        doc.nodes[doc.rootId]?.x=0; doc.nodes[doc.rootId]?.y=0
        for(i,cid)in ch.enumerated(){doc.nodes[cid]?.x=CGFloat(i)*180-CGFloat(ch.count-1)*90; doc.nodes[cid]?.y=i.isMultiple(of:2) ? -150:150}
    }
    private func org(doc:inout MashDocument,id:String,x:CGFloat,y:CGFloat) {
        doc.nodes[id]?.x=x; doc.nodes[id]?.y=y
        let ch=doc.nodes[id]?.children ?? []; let sp:CGFloat=160
        let sx=x-CGFloat(ch.count-1)*sp/2
        for(i,cid)in ch.enumerated(){org(doc:&doc,id:cid,x:sx+CGFloat(i)*sp,y:y+140)}
    }
    private func timeline(doc:inout MashDocument) {
        let ch=doc.nodes[doc.rootId]?.children ?? []
        doc.nodes[doc.rootId]?.x=0; doc.nodes[doc.rootId]?.y=0
        for(i,cid)in ch.enumerated(){doc.nodes[cid]?.x=CGFloat(i)*200-CGFloat(ch.count-1)*100; doc.nodes[cid]?.y=0}
    }
}

// MARK: - Main Entry

struct IDEMindMapView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store  = MashStore.shared
    @State private var showNewDoc   = false
    @State private var showDocList  = false

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
            MashNewDocSheet(isPresented: $showNewDoc).environmentObject(themeVM)
        }
        .sheet(isPresented: $showDocList) {
            MashDocListSheet(isPresented: $showDocList).environmentObject(themeVM)
        }
    }
}

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
                        // ASH coding template shortcut
                        Button {
                            layout = .flowchart
                        } label: {
                            HStack(spacing:6) {
                                Image(systemName:"chevron.left.forwardslash.chevron.right").font(.system(size:14))
                                    .foregroundColor(layout == .flowchart ? .black : Color(hex:"#00ffcc"))
                                Text("ASH Language Map")
                                    .font(.system(size:10,weight:.semibold,design:.monospaced))
                                    .foregroundColor(layout == .flowchart ? .black : Color(hex:"#00ffcc"))
                            }
                            .frame(maxWidth:.infinity).padding(.vertical,10)
                            .background(layout == .flowchart ? Color(hex:"#00ffcc") : Color(hex:"#00ffcc").opacity(0.08))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius:8).stroke(Color(hex:"#00ffcc").opacity(0.4),lineWidth:0.5))
                        }
                        .buttonStyle(.plain).padding(.bottom,6)
                        Text("or choose a layout:").font(.system(size:8,design:.monospaced)).foregroundColor(themeVM.dim)
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


// MARK: - Canvas Host View

struct MashCanvasView: View {
    let doc: MashDocument
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @StateObject private var store  = MashStore.shared
    @StateObject private var vm     = MashCanvasVM()
    @EnvironmentObject var ideVM:    IDEState
    @State private var showNodeEditor     = false
    @State private var showThemePicker    = false
    @State private var showExport         = false
    @State private var showDocList        = false
    @State private var showNewDoc         = false
    @State private var showLoadFromEditor = false

    var body: some View {
        ZStack {
            MashCanvas(doc: doc, vm: vm)
                .environmentObject(themeVM)

            MashSideToolbar(doc: doc, vm: vm,
                showThemePicker:    $showThemePicker,
                showExport:         $showExport,
                showDocList:        $showDocList,
                showNewDoc:         $showNewDoc,
                showLoadFromEditor: $showLoadFromEditor,
                onBuildRun:         { buildAndRunMash() })
                .environmentObject(themeVM)

            VStack {
                HStack(spacing:8) {
                    Button { showDocList = true } label: {
                        HStack(spacing:4) {
                            Image(systemName:"brain.head.profile").font(.system(size:10))
                            Text(doc.title).font(.system(size:9,weight:.semibold,design:.monospaced)).lineLimit(1)
                        }
                        .foregroundColor(themeVM.accent).padding(.horizontal,8).padding(.vertical,5)
                        .background(Color(hex:"#161b22").opacity(0.92)).cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius:6).stroke(themeVM.accent.opacity(0.3),lineWidth:0.5))
                    }
                    Spacer()
                    if vm.tool == .connect || vm.tool == .connectSingle || vm.tool == .mainLink {
                        let arrow = vm.tool == .connect ? "↔" : vm.tool == .mainLink ? "—" : "→"
                        let lbl   = vm.connectionFirst == nil ? "\(arrow) Tap source" : "\(arrow) Tap target"
                        Text(lbl)
                            .font(.system(size:8,weight:.semibold,design:.monospaced)).foregroundColor(.orange)
                            .padding(.horizontal,8).padding(.vertical,4).background(Color.orange.opacity(0.15)).cornerRadius(6)
                    }
                    // Curve style toggle: bezier ↔ flowchart
                    Button {
                        var d = doc
                        d.customTheme = d.customTheme ?? MashTheme.builtIn.first{$0.id==d.themeId} ?? MashTheme.builtIn[0]
                        d.customTheme!.connectionStyle = d.customTheme!.connectionStyle == .straight ? .curved : .straight
                        MashStore.shared.updateDocument(d)
                    } label: {
                        let isFlowchart = (doc.customTheme?.connectionStyle ?? (MashTheme.builtIn.first{$0.id==doc.themeId} ?? MashTheme.builtIn[0]).connectionStyle) == .straight
                        Image(systemName: isFlowchart ? "arrow.turn.right.down" : "bezier")
                            .font(.system(size:11)).foregroundColor(isFlowchart ? .orange : themeVM.accent)
                            .padding(5).background((isFlowchart ? Color.orange : themeVM.accent).opacity(0.1))
                            .cornerRadius(6)
                    }
                    Button { vm.cycleLayout(doc:doc) } label: {
                        Text(doc.layout.displayName).font(.system(size:8,design:.monospaced)).foregroundColor(themeVM.accent)
                            .padding(.horizontal,6).padding(.vertical,4).background(themeVM.accent.opacity(0.1)).cornerRadius(5)
                    }
                    Button { vm.scale=1.0; vm.offset = .zero; vm.baseScale=1.0 } label: {
                        Image(systemName:"arrow.up.left.and.arrow.down.right").font(.system(size:11)).foregroundColor(themeVM.dim)
                    }
                    if vm.selectedId != nil || !vm.selectedIds.isEmpty {
                        Button { vm.deleteSelected(doc:doc) } label: {
                            Image(systemName:"trash").font(.system(size:11)).foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal,12).padding(.vertical,8)
                .background(.ultraThinMaterial)
                Spacer()
                HStack {
                    Spacer()
                    Text("\(Int(vm.scale*100))%")
                        .font(.system(size:8,design:.monospaced)).foregroundColor(themeVM.dim.opacity(0.6))
                        .padding(.horizontal,8).padding(.vertical,4)
                        .background(Color(hex:"#0d1117").opacity(0.6)).cornerRadius(5)
                    Spacer()
                }.padding(.bottom,8)
            }
        }
        .ignoresSafeArea(edges:.bottom)
        .sheet(isPresented: $showThemePicker) {
            MashThemeSheet(doc:doc,isPresented:$showThemePicker).environmentObject(themeVM)
        }
        .sheet(isPresented: $showExport) {
            MashExportSheet(doc:doc,isPresented:$showExport).environmentObject(themeVM)
        }
        .sheet(isPresented: $showDocList) {
            MashDocListSheet(isPresented:$showDocList).environmentObject(themeVM)
        }
        .sheet(isPresented: $showNewDoc) {
            MashNewDocSheet(isPresented:$showNewDoc).environmentObject(themeVM)
        }
        .sheet(isPresented: $showLoadFromEditor) {
            MashLoadFromEditorSheet(isPresented:$showLoadFromEditor)
                .environmentObject(themeVM).environmentObject(ideVM)
        }
        // Image picker triggered from context menu "Attach Image"
        .sheet(item: Binding(
            get: { vm.showImagePickerForNode.map { NodeImageTarget(id:$0) } },
            set: { vm.showImagePickerForNode = $0?.id }
        )) { target in
            NodeImagePickerSheet(nodeId: target.id, doc: doc)
                .environmentObject(themeVM)
        }
        // Node editor — driven by vm.showNodeEditor (set from context menu or double-tap)
        .sheet(isPresented: Binding(
            get: { vm.showNodeEditor },
            set: { vm.showNodeEditor = $0 }
        )) {
            if let id = vm.editorNodeId ?? vm.selectedId, let n = doc.nodes[id] {
                MashNodeEditorSheet(nodeData:n, doc:doc,
                    onDismiss: { vm.showNodeEditor = false })
                    .environmentObject(themeVM)
            }
        }
    }

    private func buildAndRunMash() {
        let code = MashAshCodeGenerator.toAshSource(doc)
        ideVM.sourceCode  = code
        ideVM.currentFile = doc.title.replacingOccurrences(of:" ",with:"_") + ".ash"
        IDELanguageStore.shared.setEnvFromFilename(ideVM.currentFile)
        Task { await ideVM.buildAndRun() }
    }
}

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

    struct ToolItem: Identifiable {
        let id = UUID()
        let icon: String
        let action: () -> Void
    }

    var items: [ToolItem] { [
        // Add child node (linked to selected)
        ToolItem(icon:"plus.circle.fill")            { vm.addChildToSelected(doc:doc) },
        // Add free node (no auto-link)
        ToolItem(icon:"plus.square")                 { vm.addFreeNode(doc:doc) },
        // Select
        ToolItem(icon:"cursorarrow")                  { vm.tool = .select },
        // Main solid link (reparents — solid tree edge)
        ToolItem(icon:"line.diagonal")               { vm.tool = vm.tool == .mainLink ? .select : .mainLink },
        // Bidirectional dashed reference link (↔)
        ToolItem(icon:"arrow.left.and.right")        { vm.tool = vm.tool == .connect ? .select : .connect },
        // Single-direction dashed reference link (→)
        ToolItem(icon:"arrow.right")                 { vm.tool = vm.tool == .connectSingle ? .select : .connectSingle },
        // Marquee select
        ToolItem(icon:"rectangle.dashed.badge.plus") { vm.tool = vm.tool == .marquee ? .select : .marquee },
        // Theme
        ToolItem(icon:"paintpalette.fill")           { showThemePicker = true },
        // Image node
        ToolItem(icon:"photo.badge.plus")            { vm.addImageNode(doc:doc) },
        // Export
        ToolItem(icon:"square.and.arrow.up")         { showExport = true },
        // Load code into map
        ToolItem(icon:"square.and.arrow.down.on.square"){ showLoadFromEditor = true },
        // Build & Run
        ToolItem(icon:"play.fill")                   { onBuildRun() },
        // New map / Open map
        ToolItem(icon:"plus.square.on.square")       { showNewDoc = true },
        ToolItem(icon:"folder.fill")                 { showDocList = true },
    ]}

    var body: some View {
        GeometryReader { geo in
            let isVertical = vm.toolbarSide == .left || vm.toolbarSide == .right
            Group {
                if isVertical {
                    VStack(spacing:2) { toolItems() }
                } else {
                    HStack(spacing:2) { toolItems() }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius:14)
                    .fill(Color(hex:"#0d1117").opacity(0.93))
                    .shadow(color:.black.opacity(0.5),radius:12)
            )
            .overlay(RoundedRectangle(cornerRadius:14).stroke(Color(hex:"#21262d"),lineWidth:0.5))
            .gesture(
                LongPressGesture(minimumDuration:0.4)
                    .sequenced(before:DragGesture(minimumDistance:4,coordinateSpace:.global))
                    .onEnded { val in
                        if case .second(true, let drag?)=val {
                            let loc=drag.location; let w=geo.size.width; let h=geo.size.height
                            let dl=loc.x; let dr=w-loc.x; let dt=loc.y; let db=h-loc.y
                            let mn=min(dl,dr,dt,db)
                            if mn==dl { vm.toolbarSide = .left }
                            else if mn==dr { vm.toolbarSide = .right }
                            else if mn==dt { vm.toolbarSide = .top }
                            else           { vm.toolbarSide = .bottom }
                        }
                    }
            )
            .position(toolbarPos(in:geo.size))
        }
    }

    private func toolbarPos(in sz: CGSize) -> CGPoint {
        let pad: CGFloat = 30
        switch vm.toolbarSide {
        case .left:   return CGPoint(x:pad,       y:sz.height/2)
        case .right:  return CGPoint(x:sz.width-pad, y:sz.height/2)
        case .top:    return CGPoint(x:sz.width/2, y:80)
        case .bottom: return CGPoint(x:sz.width/2, y:sz.height-50)
        }
    }

    @ViewBuilder
    private func toolItems() -> some View {
        ForEach(items) { item in
            Button(action:item.action) {
                Image(systemName:item.icon).font(.system(size:16))
                    .foregroundColor(isActive(item.icon) ? .black : themeVM.dim)
                    .frame(width:38,height:38)
                    .background(isActive(item.icon) ? themeVM.accent : themeVM.accent.opacity(0.06))
                    .cornerRadius(9)
            }.buttonStyle(.plain)
        }
    }

    private func isActive(_ icon: String) -> Bool {
        switch icon {
        case "cursorarrow":                return vm.tool == .select
        case "line.diagonal":              return vm.tool == .mainLink
        case "arrow.left.and.right":       return vm.tool == .connect
        case "arrow.right":                return vm.tool == .connectSingle
        case "rectangle.dashed.badge.plus": return vm.tool == .marquee
        default: return false
        }
    }
}

// MARK: - UIKit Pan Gesture Bridge
// SwiftUI gesture arbitration is unreliable when nodes have their own gestures.
// This UIViewRepresentable injects a raw UIPanGestureRecognizer that always fires.

struct CanvasPanBridge: UIViewRepresentable {
    @ObservedObject var vm: MashCanvasVM

    func makeCoordinator() -> Coordinator { Coordinator(vm: vm) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false  // this view itself doesn't intercept touches
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Add pan to superview (the full canvas) on first layout
        guard let superview = uiView.superview else { return }
        // Only add once — check if pan already attached
        let alreadyHasPan = superview.gestureRecognizers?.contains(where: { $0 is UIPanGestureRecognizer }) ?? false
        guard !alreadyHasPan else { return }
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        superview.addGestureRecognizer(pan)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let vm: MashCanvasVM
        init(vm: MashCanvasVM) { self.vm = vm }

        @objc func handlePan(_ gr: UIPanGestureRecognizer) {
            switch gr.state {
            case .began:
                // Cancel immediately if node drag starts
                if vm.isDraggingNode || vm.tool == .marquee {
                    gr.state = .cancelled
                    return
                }
            case .changed:
                if vm.isDraggingNode || vm.tool == .marquee {
                    gr.setTranslation(.zero, in: gr.view)
                    return
                }
                let t = gr.translation(in: gr.view)
                DispatchQueue.main.async {
                    self.vm.offset = CGPoint(
                        x: self.vm.offset.x + t.x / self.vm.scale,
                        y: self.vm.offset.y + t.y / self.vm.scale)
                }
                gr.setTranslation(.zero, in: gr.view)
            case .ended, .cancelled, .failed:
                break
            default: break
            }
        }

        // Don't begin pan when marquee tool is active — let SwiftUI handle it
        func gestureRecognizerShouldBegin(_ gr: UIGestureRecognizer) -> Bool {
            return !vm.isDraggingNode && vm.tool != .marquee
        }
        // Allow simultaneous recognition with pinch and other gestures
        func gestureRecognizer(_ gr: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

// MARK: - Canvas Renderer

struct MashCanvas: View {
    let doc: MashDocument
    @ObservedObject var vm: MashCanvasVM
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var theme: MashTheme {
        doc.customTheme ?? MashTheme.builtIn.first{$0.id==doc.themeId} ?? MashTheme.builtIn[0]
    }

    var body: some View {
        GeometryReader { geo in
            let sz = geo.size
            ZStack(alignment:.topLeading) {
                // Background — pan gesture lives here so it only fires on empty canvas
                (theme.canvasTransparent ? Color.clear : Color(hex:theme.canvasBackground))
                    .ignoresSafeArea()
                // Dot grid
                if !theme.canvasTransparent {
                    Canvas { ctx, size in
                        let sp = max(16, 40 * vm.scale)
                        let ox = (sz.width/2 + vm.offset.x * vm.scale).truncatingRemainder(dividingBy:sp)
                        let oy = (sz.height/2 + vm.offset.y * vm.scale).truncatingRemainder(dividingBy:sp)
                        var x=ox; while x<size.width {
                            var y=oy; while y<size.height {
                                ctx.fill(Path(ellipseIn:CGRect(x:x-0.8,y:y-0.8,width:1.6,height:1.6)),
                                         with:.color(Color(hex:theme.connectionColor).opacity(0.12)))
                                y+=sp }; x+=sp }
                    }.allowsHitTesting(false)
                }
                // World content — clipped
                ZStack(alignment:.topLeading) {
                    // Tap targets for reference connections (invisible, for selection)
                    ForEach(doc.connections, id:\.id) { conn in
                        if let fn = doc.nodes[conn.fromId], let tn = doc.nodes[conn.toId] {
                            let fsp = vm.worldToScreen(CGPoint(x:fn.x,y:fn.y),sz:sz)
                            let tsp = vm.worldToScreen(CGPoint(x:tn.x,y:tn.y),sz:sz)
                            let mx = (fsp.x+tsp.x)/2; let my = (fsp.y+tsp.y)/2
                            Circle()
                                .fill(Color.clear)
                                .frame(width:32,height:32)
                                .contentShape(Circle())
                                .position(CGPoint(x:mx,y:my))
                                .onTapGesture {
                                    vm.selectedConnId  = conn.id
                                    vm.showConnMenu    = true
                                    vm.showContextMenu = false
                                }
                        }
                    }

                    // Connections
                    Canvas { ctx, _ in
                        for (_,node) in doc.nodes {
                            for cid in node.children {
                                guard let child=doc.nodes[cid] else{continue}
                                drawEdge(ctx:ctx,sz:sz,
                                    from:CGPoint(x:node.x,y:node.y),
                                    to:CGPoint(x:child.x,y:child.y),
                                    style:theme.connectionStyle,
                                    color:Color(hex:theme.connectionColor),
                                    dashed:false,arrow:.none,lw:2.5)
                            }
                        }
                        for conn in doc.connections {
                            guard let fn=doc.nodes[conn.fromId],let tn=doc.nodes[conn.toId] else{continue}
                            let col=conn.color.map{Color(hex:$0)} ?? Color(hex:theme.connectionColor)
                            drawEdge(ctx:ctx,sz:sz,
                                from:CGPoint(x:fn.x,y:fn.y),
                                to:CGPoint(x:tn.x,y:tn.y),
                                style:theme.connectionStyle,color:col.opacity(0.75),
                                dashed:conn.dashed,arrow:conn.arrowType,lw:1.8)
                        }
                        // Marquee
                        if let ms=vm.marqueeStart, let me=vm.marqueeEnd {
                            let r=CGRect(x:min(ms.x,me.x),y:min(ms.y,me.y),width:abs(me.x-ms.x),height:abs(me.y-ms.y))
                            ctx.fill(Path(r),with:.color(Color(hex:theme.connectionColor).opacity(0.07)))
                            ctx.stroke(Path(r),with:.color(Color(hex:theme.connectionColor).opacity(0.8)),
                                       style:StrokeStyle(lineWidth:1.5,dash:[6,4]))
                        }
                    }.allowsHitTesting(false)
                    // Nodes
                    ForEach(Array(doc.nodes.values),id:\.id) { n in
                        let sp = vm.worldToScreen(CGPoint(x:n.x,y:n.y),sz:sz)
                        MashNodeView(nodeData:n,theme:theme,
                            isSelected:vm.selectedId==n.id||vm.selectedIds.contains(n.id),
                            isConnectFirst:vm.connectionFirst==n.id)
                        .scaleEffect(vm.scale)
                        .position(sp)
                        .gesture(nodeDrag(n,sz:sz))
                        .onTapGesture(count:2) {
                            vm.selectedId     = n.id
                            vm.editorNodeId   = n.id
                            vm.showNodeEditor = true
                            vm.showContextMenu = false
                        }
                        .onTapGesture(count:1) { vm.handleNodeTap(n.id, doc:doc) }
                        .onLongPressGesture(minimumDuration:0.4) {
                            vm.selectedId    = n.id
                            vm.contextNodeId = n.id
                            vm.showContextMenu = true
                        }
                    }
                }
                .frame(width:sz.width,height:sz.height)
                .clipped()
                // Marquee selection — SwiftUI gesture, UIKit pan handles actual panning
                .simultaneousGesture(
                    DragGesture(minimumDistance:8, coordinateSpace:.local)
                        .onChanged { val in
                            guard !vm.isDraggingNode, vm.tool == .marquee else { return }
                            if vm.marqueeStart == nil {
                                vm.marqueeStart = val.startLocation; vm.isMarqueeActive = true
                            }
                            vm.marqueeEnd = val.location
                        }
                        .onEnded { _ in
                            if vm.isMarqueeActive,
                               let ms = vm.marqueeStart, let me = vm.marqueeEnd {
                                let rect = CGRect(x:Swift.min(ms.x,me.x),
                                                  y:Swift.min(ms.y,me.y),
                                                  width:abs(me.x-ms.x),
                                                  height:abs(me.y-ms.y))
                                var hits = Set<String>()
                                for (_,n) in doc.nodes {
                                    let sp = vm.worldToScreen(CGPoint(x:n.x,y:n.y),sz:sz)
                                    if rect.contains(sp) { hits.insert(n.id) }
                                }
                                vm.selectedIds=hits
                                vm.selectedId=hits.count==1 ? hits.first:nil
                            }
                            vm.marqueeStart=nil; vm.marqueeEnd=nil; vm.isMarqueeActive=false
                        }
                )

                // Connection context menu (tap near midpoint of a ref connection)
                if vm.showConnMenu, let connId = vm.selectedConnId,
                   let conn = doc.connections.first(where:{$0.id==connId}),
                   let fn = doc.nodes[conn.fromId], let tn = doc.nodes[conn.toId] {
                    // Midpoint in screen space
                    let fsp = vm.worldToScreen(CGPoint(x:fn.x,y:fn.y),sz:sz)
                    let tsp = vm.worldToScreen(CGPoint(x:tn.x,y:tn.y),sz:sz)
                    let mx  = (fsp.x+tsp.x)/2
                    let my  = (fsp.y+tsp.y)/2
                    VStack(spacing:0) {
                        Button {
                            vm.deleteConnection(connId, doc:doc)
                        } label: {
                            HStack(spacing:8) {
                                Image(systemName:"trash").font(.system(size:12)).foregroundColor(.red)
                                Text("Delete Link").font(.system(size:11,design:.monospaced)).foregroundColor(.red)
                            }
                            .padding(.horizontal,14).padding(.vertical,10)
                        }.buttonStyle(.plain)
                    }
                    .background(RoundedRectangle(cornerRadius:10).fill(Color(hex:"#161b22").opacity(0.97)).shadow(color:.black.opacity(0.5),radius:12))
                    .overlay(RoundedRectangle(cornerRadius:10).stroke(Color(hex:"#30363d"),lineWidth:0.5))
                    .position(CGPoint(x:Swift.min(Swift.max(mx,60),sz.width-60), y:Swift.min(Swift.max(my-50,40),sz.height-80)))
                }

                // Node context menu (not clipped)
                if vm.showContextMenu, let nid=vm.contextNodeId, let n=doc.nodes[nid] {
                    let sp=vm.worldToScreen(CGPoint(x:n.x,y:n.y),sz:sz)
                    MashContextMenu(nodeId:nid,doc:doc,vm:vm)
                        .environmentObject(themeVM)
                        .position(CGPoint(
                            x:Swift.min(Swift.max(sp.x, 110), sz.width-110),
                            y:Swift.min(Swift.max(sp.y-110, 50), sz.height-240)))
                }
            }
            .frame(width:sz.width,height:sz.height)
            // UIKit pan bridge as background — UIKit layer receives touches
            // but SwiftUI nodes stay on top and handle their own gestures
            .background(
                CanvasPanBridge(vm: vm)
            )
            // Pinch to zoom — 2-finger, doesn't conflict with 1-finger pan
            .gesture(MagnificationGesture()
                .onChanged { v in
                    vm.scale = Swift.min(Swift.max(vm.baseScale * v, vm.minScale), vm.maxScale)
                }
                .onEnded { _ in vm.baseScale = vm.scale })
            // Tap on empty canvas to deselect
            .onTapGesture {
                guard !vm.isDraggingNode else { return }
                vm.selectedId = nil; vm.selectedIds = []
                vm.showContextMenu = false; vm.showConnMenu = false; vm.selectedConnId = nil
            }
        }
    }

    // ── Node drag — start from world pos to avoid drift ──
    private func nodeDrag(_ n:MashNodeData, sz:CGSize) -> some Gesture {
        DragGesture(minimumDistance:5, coordinateSpace:.local)
            .onChanged { val in
                guard vm.tool == .select else { return }
                if !vm.isDraggingNode {
                    vm.isDraggingNode  = true
                    vm.draggingId      = n.id
                    vm.dragStartWorld  = CGPoint(x: n.x, y: n.y)
                    vm.showContextMenu = false
                    vm.showConnMenu    = false
                }
                var d = doc
                d.nodes[n.id]?.x = vm.dragStartWorld.x + val.translation.width  / vm.scale
                d.nodes[n.id]?.y = vm.dragStartWorld.y + val.translation.height / vm.scale
                MashStore.shared.updateDocument(d)
            }
            .onEnded { _ in
                vm.isDraggingNode = false
                vm.draggingId     = nil
                // Snap back if using a strict template layout
                let strictLayouts: [MashLayout] = [.tree, .fishbone, .orgchart, .timeline]
                if strictLayouts.contains(doc.layout) {
                    var d = doc
                    vm.applyAutoLayout(doc: &d)
                    MashStore.shared.updateDocument(d)
                }
            }
    }



    // ── Draw a connection ─────────────────────────────────
    private func drawEdge(ctx:GraphicsContext,sz:CGSize,from:CGPoint,to:CGPoint,
                           style:MashConnectionStyle,color:Color,dashed:Bool,arrow:MashArrowType,lw:CGFloat) {
        let fs=vm.worldToScreen(from,sz:sz), ts=vm.worldToScreen(to,sz:sz)
        var path=Path()
        switch style {
        case .curved,.organic:
            let dx=ts.x-fs.x
            path.move(to:fs); path.addCurve(to:ts,
                control1:CGPoint(x:fs.x+dx*0.5,y:fs.y),
                control2:CGPoint(x:ts.x-dx*0.5,y:ts.y))
        case .straight:
            let mx=fs.x+(ts.x-fs.x)*0.5
            path.move(to:fs); path.addLine(to:CGPoint(x:mx,y:fs.y))
            path.addLine(to:CGPoint(x:mx,y:ts.y)); path.addLine(to:ts)
        }
        let w=lw*min(1.5,vm.scale+0.3)
        ctx.stroke(path,with:.color(color),style:StrokeStyle(lineWidth:w,lineCap:.round,lineJoin:.round,dash:dashed ? [6,4]:[]))
        if arrow != .none {
            let ang=atan2(ts.y-fs.y,ts.x-fs.x); let asz=CGFloat(10)*min(1.5,vm.scale+0.4)
            func tip(_ p:CGPoint,_ a:Double){ var ar=Path()
                ar.move(to:p); ar.addLine(to:CGPoint(x:p.x-CGFloat(cos(a-0.4))*asz,y:p.y-CGFloat(sin(a-0.4))*asz))
                ar.move(to:p); ar.addLine(to:CGPoint(x:p.x-CGFloat(cos(a+0.4))*asz,y:p.y-CGFloat(sin(a+0.4))*asz))
                ctx.stroke(ar,with:.color(color),lineWidth:1.8) }
            if arrow == .forward  || arrow == .both { tip(ts,Double(ang)) }
            if arrow == .backward || arrow == .both { tip(fs,Double(ang) + .pi) }
        }
    }
}

// Clamp helper
extension CGFloat { func clamped(lo:CGFloat,hi:CGFloat)->CGFloat { Swift.min(Swift.max(self,lo),hi) } }

// MARK: - Context Menu
struct MashContextMenu: View {
    let nodeId:String; let doc:MashDocument; @ObservedObject var vm:MashCanvasVM
    @EnvironmentObject var themeVM:IDEThemeViewModel
    var node:MashNodeData? { doc.nodes[nodeId] }
    var body: some View {
        VStack(spacing:0) {
            row("Edit Node",     "pencil")        {
                vm.showContextMenu = false
                vm.editorNodeId    = nodeId
                vm.showNodeEditor  = true
            }
            div()
            row("Add Child",     "plus.circle")   { vm.addChildToSelected(doc:doc); vm.showContextMenu=false }
            div()
            row("Duplicate",     "doc.on.doc")    { dup() }
            div()
            if doc.nodes[nodeId]?.imageData != nil {
                row("Replace Image", "photo.badge.arrow.up") {
                    vm.showImagePickerForNode = nodeId; vm.showContextMenu = false
                }
            } else {
                row("Attach Image",  "photo.badge.plus") {
                    vm.showImagePickerForNode = nodeId; vm.showContextMenu = false
                }
            }
            div()
            row("Copy Label",    "doc.on.clipboard") {
                UIPasteboard.general.string = node?.text ?? ""; vm.showContextMenu=false
            }
            if let u = node?.url, !u.isEmpty {
                div()
                row("Open Link", "link") {
                    if let url=URL(string:u) { UIApplication.shared.open(url) }
                    vm.showContextMenu=false
                }
            }
            div()
            row("Delete Node",   "trash", red:true) {
                vm.deleteSelected(doc:doc); vm.showContextMenu=false
            }
        }
        .frame(width:210)
        .background(RoundedRectangle(cornerRadius:13).fill(Color(hex:"#161b22").opacity(0.97)).shadow(color:.black.opacity(0.55),radius:18,y:8))
        .overlay(RoundedRectangle(cornerRadius:13).stroke(Color(hex:"#30363d"),lineWidth:0.5))
    }
    private func dup(){
        guard let n=doc.nodes[nodeId] else{return}
        var d=doc; let newId=UUID().uuidString
        let c=MashNodeData(id:newId,type:n.type,text:n.text+" (copy)",detail:n.detail,url:n.url,imageData:n.imageData,x:n.x+70,y:n.y+70,width:n.width,children:[],parentId:n.parentId,collapsed:false,fillColor:n.fillColor,borderColor:n.borderColor,textColor:n.textColor,cornerStyle:n.cornerStyle,fontSize:n.fontSize,bold:n.bold,italic:n.italic)
        d.nodes[newId]=c; if let pid=c.parentId{d.nodes[pid]?.children.append(newId)}
        MashStore.shared.updateDocument(d); vm.selectedId=newId; vm.showContextMenu=false
    }
    @ViewBuilder private func row(_ label:String,_ icon:String,red:Bool=false,action:@escaping()->Void)->some View{
        Button(action:action){HStack(spacing:10){Image(systemName:icon).font(.system(size:13)).foregroundColor(red ? .red:themeVM.dim).frame(width:20);Text(label).font(.system(size:12,design:.monospaced)).foregroundColor(red ? .red:themeVM.text);Spacer()}.padding(.horizontal,14).padding(.vertical,10)}.buttonStyle(.plain)
    }
    @ViewBuilder private func div()->some View{Divider().background(Color(hex:"#21262d"))}
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
            // Image thumbnail (tappable to preview)
            if let imgData = nodeData.imageData, let uiImg = UIImage(data: imgData) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()   // fit = full image visible, no cropping
                    .frame(maxWidth: nodeData.width - 8)
                    .cornerRadius(7)
                    .padding(.horizontal, 4).padding(.top, 4)
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

// MARK: - Sheets

struct MashNodeEditorSheet: View {
    let nodeData:   MashNodeData
    let doc:        MashDocument
    let onDismiss:  () -> Void
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
    // FocusState MUST be at this level, not inside NavigationView
    @FocusState private var labelFocused: Bool

    var body: some View {
        // Plain VStack — no NavigationView.
        // NavigationView breaks @FocusState in sheets on iOS 16+.
        ZStack {
            Color(hex:"#0d1117").ignoresSafeArea()
            VStack(spacing:0) {
                // Custom navigation bar
                HStack {
                    Button("Cancel") { onDismiss() }
                        .font(.system(size:13,design:.monospaced))
                        .foregroundColor(themeVM.dim)
                    Spacer()
                    Text("Edit Node")
                        .font(.system(size:13,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.text)
                    Spacer()
                    Button("Save") { saveNode(); onDismiss() }
                        .font(.system(size:13,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.accent)
                }
                .padding(.horizontal,18).padding(.vertical,14)
                .background(Color(hex:"#161b22"))
                .overlay(Divider().background(Color(hex:"#21262d")), alignment:.bottom)

                ScrollView {
                    VStack(alignment:.leading, spacing:16) {
                        // Node type picker
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
                                    }.buttonStyle(.plain)
                                }
                            }
                        }

                        // ── LABEL — primary editable field ──────────────
                        VStack(alignment:.leading, spacing:6) {
                            Text("LABEL")
                                .font(.system(size:7,weight:.bold,design:.monospaced))
                                .foregroundColor(themeVM.dim).kerning(1.5)
                            TextField("Node label", text: $text, axis: .vertical)
                                .font(.system(size:15,design:.monospaced))
                                .foregroundColor(themeVM.accent)
                                .focused($labelFocused)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(hex:"#0d1117"))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius:10)
                                    .stroke(labelFocused
                                            ? themeVM.accent
                                            : Color(hex:"#30363d"),
                                            lineWidth: labelFocused ? 1.5 : 0.5))
                                .submitLabel(.done)
                        }

                        field("Notes / Detail", binding: $detail, mono: false)
                        field("Hyperlink URL",  binding: $url,    mono: true)

                        HStack(spacing:12) {
                            Toggle("Bold",   isOn: $bold).tint(themeVM.accent)
                            Toggle("Italic", isOn: $italic).tint(themeVM.accent)
                        }
                        .font(.system(size:11,design:.monospaced))
                        .foregroundColor(themeVM.dim)

                        Button { showImagePicker = true } label: {
                            Label(pickedImage != nil ? "Change Image" : "Attach Image",
                                  systemImage:"photo.badge.plus")
                                .font(.system(size:11,design:.monospaced))
                                .foregroundColor(themeVM.accent)
                                .frame(maxWidth:.infinity).padding(.vertical,10)
                                .background(themeVM.accent.opacity(0.08)).cornerRadius(8)
                        }
                        if let img = pickedImage {
                            Image(uiImage:img).resizable().scaledToFit()
                                .frame(maxHeight:140).cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
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
            // Focus after the sheet animation finishes (~0.6s on iOS)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.65) {
                labelFocused = true
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
        let exportPxScale: CGFloat = 2.0
        let size  = CGSize(width:1600, height:1200)
        let theme = doc.customTheme ?? MashTheme.builtIn.first{$0.id==doc.themeId} ?? MashTheme.builtIn[0]

        UIGraphicsBeginImageContextWithOptions(size, !transparent, exportPxScale)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        if !transparent {
            ctx.setFillColor(UIColor(Color(hex:theme.canvasBackground)).cgColor)
            ctx.fill(CGRect(origin:.zero,size:size))
        }

        let allNodes = Array(doc.nodes.values)
        guard !allNodes.isEmpty else { UIGraphicsEndImageContext(); return }

        // Auto-fit all node positions into the canvas
        let padX: CGFloat = 140, padY: CGFloat = 100
        let minX = allNodes.map{$0.x}.min()! - padX
        let maxX = allNodes.map{$0.x}.max()! + padX
        let minY = allNodes.map{$0.y}.min()! - padY
        let maxY = allNodes.map{$0.y}.max()! + padY
        let contentW = max(1, maxX-minX), contentH = max(1, maxY-minY)
        let s = min(size.width/contentW, size.height/contentH, 2.5)  // fit scale
        let ox = size.width/2  - (minX+contentW/2)*s   // origin offset x
        let oy = size.height/2 - (minY+contentH/2)*s   // origin offset y
        // world → canvas
        func px(_ x:CGFloat)->CGFloat { ox+x*s }
        func py(_ y:CGFloat)->CGFloat { oy+y*s }
        func ps(_ v:CGFloat)->CGFloat { v*s }

        // Tree edges
        for (_,node) in doc.nodes {
            for cid in node.children {
                guard let ch=doc.nodes[cid] else{continue}
                let fx=px(node.x),fy=py(node.y),tx=px(ch.x),ty=py(ch.y),dx=tx-fx
                ctx.setStrokeColor(UIColor(Color(hex:theme.connectionColor)).withAlphaComponent(0.8).cgColor)
                ctx.setLineWidth(max(1.5,s)); ctx.setLineDash(phase:0,lengths:[])
                ctx.move(to:CGPoint(x:fx,y:fy))
                ctx.addCurve(to:CGPoint(x:tx,y:ty),
                    control1:CGPoint(x:fx+dx*0.5,y:fy),
                    control2:CGPoint(x:tx-dx*0.5,y:ty))
                ctx.strokePath()
            }
        }
        // Reference connections
        for conn in doc.connections {
            guard let fn=doc.nodes[conn.fromId],let tn=doc.nodes[conn.toId] else{continue}
            let fx=px(fn.x),fy=py(fn.y),tx=px(tn.x),ty=py(tn.y),dx=tx-fx
            let col=(conn.color.map{UIColor(Color(hex:$0))} ?? UIColor(Color(hex:theme.connectionColor)))
                .withAlphaComponent(0.6)
            ctx.setStrokeColor(col.cgColor)
            ctx.setLineWidth(max(1,s*0.7))
            ctx.setLineDash(phase:0,lengths:conn.dashed ? [8,5]:[])
            ctx.move(to:CGPoint(x:fx,y:fy))
            ctx.addCurve(to:CGPoint(x:tx,y:ty),
                control1:CGPoint(x:fx+dx*0.5,y:fy),
                control2:CGPoint(x:tx-dx*0.5,y:ty))
            ctx.strokePath()
        }
        ctx.setLineDash(phase:0,lengths:[])

        // Nodes
        for n in allNodes {
            let fillC  = UIColor(Color(hex: n.fillColor   ?? (n.type == .root ? theme.rootFill   : theme.mainFill)))
            let bordC  = UIColor(Color(hex: n.borderColor ?? (n.type == .root ? theme.rootBorder : theme.mainBorder)))
            let txtC   = UIColor(Color(hex: n.textColor   ?? (n.type == .root ? theme.rootText   : theme.mainText)))

            let nw: CGFloat = 180   // fixed export width — no scaling distortion
            let lblH: CGFloat = n.type == .root ? 52 : 38

            // Image: draw at true aspect ratio, max height 120
            var imgH: CGFloat = 0
            var exportImg: UIImage? = nil
            if let dat = n.imageData, let uiImg = UIImage(data: dat) {
                exportImg = uiImg
                let aspect = uiImg.size.width / uiImg.size.height
                // Box width = nw-10; height from aspect, capped at 120
                imgH = Swift.min((nw-10) / aspect, 120)
            }

            let nh = lblH + imgH
            let rect = CGRect(x: px(n.x)-nw/2, y: py(n.y)-nh/2, width: nw, height: nh)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
            fillC.setFill();   path.fill()
            bordC.setStroke(); path.lineWidth = 2; path.stroke()

            if let uiImg = exportImg {
                // Draw at true aspect ratio — no stretch at all
                let m: CGFloat = 5
                let drawW = nw - m*2
                let drawH = imgH - m
                let drawRect = CGRect(x: rect.minX+m, y: rect.minY+m,
                                      width: drawW, height: drawH)
                ctx.saveGState()
                UIBezierPath(roundedRect: drawRect, cornerRadius: 8).addClip()
                uiImg.draw(in: drawRect)   // image fills box at its own aspect
                ctx.restoreGState()
            }

            let fs  = CGFloat(n.type == .root ? 16 : 13)
            let fnt = n.bold ? UIFont.boldSystemFont(ofSize: fs)
                             : UIFont.systemFont(ofSize: fs)
            let atr: [NSAttributedString.Key: Any] = [.font: fnt, .foregroundColor: txtC]
            let str = NSAttributedString(string: n.text, attributes: atr)
            let ssz = str.size()
            let ty  = rect.minY + imgH + (lblH - ssz.height) / 2
            str.draw(at: CGPoint(x: rect.midX - ssz.width/2,
                                 y: Swift.max(ty, rect.minY + imgH + 4)))
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


// MARK: - Node Image Picker

struct NodeImageTarget: Identifiable {
    let id: String
}

struct NodeImagePickerSheet: View {
    let nodeId: String
    let doc:    MashDocument
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var pickedImage: UIImage? = nil
    @State private var showPicker  = true

    var body: some View {
        ZStack {
            Color(hex:"#0d1117").ignoresSafeArea()
            if let img = pickedImage {
                VStack(spacing:16) {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(maxHeight:300).cornerRadius(12)
                    HStack(spacing:16) {
                        Button("Attach to Node") {
                            var d = doc
                            d.nodes[nodeId]?.imageData = img.jpegData(compressionQuality:0.8)
                            if d.nodes[nodeId]?.type == .note || d.nodes[nodeId]?.type == .subtitle {
                                d.nodes[nodeId]?.type = .image  // promote to image node
                            }
                            MashStore.shared.updateDocument(d)
                            dismiss()
                        }
                        .font(.system(size:12,weight:.semibold))
                        .foregroundColor(.black).padding(.horizontal,20).padding(.vertical,10)
                        .background(themeVM.accent).cornerRadius(10)
                        Button("Cancel") { dismiss() }
                            .font(.system(size:12,design:.monospaced))
                            .foregroundColor(themeVM.dim)
                    }
                }
                .padding(20)
            } else {
                VStack(spacing:12) {
                    ProgressView().tint(themeVM.accent)
                    Text("Opening photo library…")
                        .font(.system(size:11,design:.monospaced)).foregroundColor(themeVM.dim)
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePickerView(selectedImage: $pickedImage)
        }
    }
}

// ShareSheet is defined in IDEMainView.swift
