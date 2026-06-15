// ============================================================
//  IDEMainView.swift — Main IDE Layout with Side Drawer
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

struct IDEMainView: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var mazeVM:  MazeViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // ── Main content ──────────────────────────────────────
                VStack(spacing: 0) {
                    IDETopBar()
                    IDETabContent()
                    IDEBottomBar()
                }
                .background(themeVM.bg)
                .offset(x: ideVM.showDrawer ? min(geo.size.width * 0.78, 300) : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: ideVM.showDrawer)

                // ── Dim overlay when drawer open ──────────────────────
                if ideVM.showDrawer {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .offset(x: min(geo.size.width * 0.78, 300))
                        .onTapGesture { withAnimation { ideVM.showDrawer = false } }
                }

                // ── Side drawer ───────────────────────────────────────
                IDESideDrawer()
                    .frame(width: min(geo.size.width * 0.78, 300))
                    .offset(x: ideVM.showDrawer ? 0 : -min(geo.size.width * 0.78, 300))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: ideVM.showDrawer)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Top Bar

struct IDETopBar: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        HStack(spacing: 0) {
            // Hamburger / avatar
            Button {
                withAnimation { ideVM.showDrawer.toggle() }
            } label: {
                if let img = authVM.avatarImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(themeVM.accent.opacity(0.4), lineWidth: 1))
                } else {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeVM.text)
                }
            }
            .frame(width: 44, height: 44)
            .padding(.leading, 4)

            Spacer()

            // Wordmark
            VStack(spacing: 1) {
                Text("ASH TREE IDE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(themeVM.text)
                    .kerning(2)
                Text("LEATR v2")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(themeVM.accent.opacity(0.7))
                    .kerning(1)
            }

            Spacer()

            // Build & Run
            Button {
                Task { await ideVM.buildAndRun() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: ideVM.isCompiling ? "ellipsis" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(ideVM.isCompiling ? "…" : "RUN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundColor(themeVM.bg)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(themeVM.accent)
                .cornerRadius(8)
            }
            .disabled(ideVM.isCompiling)
            .padding(.trailing, 10)
        }
        .frame(height: 50)
        .background(themeVM.bg)
        .overlay(Divider().background(themeVM.border), alignment: .bottom)
    }
}

// MARK: - Tab Bar + Content

struct IDETabContent: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            // Compact tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(IDETab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { ideVM.selectedTab = tab }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 10, weight: ideVM.selectedTab == tab ? .semibold : .regular))
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: ideVM.selectedTab == tab ? .semibold : .regular))
                            }
                            .foregroundColor(ideVM.selectedTab == tab ? themeVM.accent : themeVM.dim)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .overlay(
                                Rectangle()
                                    .fill(ideVM.selectedTab == tab ? themeVM.accent : .clear)
                                    .frame(height: 2),
                                alignment: .bottom
                            )
                        }
                    }
                }
            }
            .background(themeVM.bg)
            .overlay(Divider().background(themeVM.border), alignment: .bottom)

            // Content
            Group {
                switch ideVM.selectedTab {
                case .editor:   IDEEditorView()
                case .output:   IDECompilerOutputView()
                case .terminal: IDETerminalView()
                case .files:    IDEFilesView()
                case .maze:     IDEMazeView()
                case .docs:     IDEDocsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Bottom Status Bar

struct IDEBottomBar: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        HStack(spacing: 12) {
            // File name
            Label(ideVM.currentFile + (ideVM.isDirty ? " ●" : ""), systemImage: "doc.text")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(themeVM.dim)

            Spacer()

            // Shell + buoyancy
            if ideVM.compiler.nodeCount > 0 {
                Text("SHELL: \(ideVM.compiler.shellType)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(shellColor(ideVM.compiler.shellType))
                Text("BUOY: \(String(format: "%.4f", ideVM.compiler.buoyancy))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeVM.dim)
                Text("\(ideVM.compiler.nodeCount) nodes")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(themeVM.dim)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(themeVM.surface)
        .overlay(Divider().background(themeVM.border), alignment: .top)
    }

    func shellColor(_ shell: String) -> Color {
        switch shell {
        case "GEOLOGICAL": return .brown
        case "MARITIME":   return themeVM.accent
        case "AEROSPACE":  return .purple
        default:           return themeVM.dim
        }
    }
}

// MARK: - Side Drawer

struct IDESideDrawer: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            // Profile header
            IDEDrawerProfileHeader()

            // Drawer tab pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(IDEState.DrawerTab.allCases, id: \.self) { tab in
                        Button {
                            ideVM.drawerTab = tab
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tab.icon).font(.system(size: 10))
                                Text(tab.rawValue).font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(ideVM.drawerTab == tab ? themeVM.bg : themeVM.dim)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(ideVM.drawerTab == tab ? themeVM.accent : themeVM.surface)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(themeVM.bg)
            .overlay(Divider().background(themeVM.border), alignment: .bottom)

            // Content
            switch ideVM.drawerTab {
            case .files:    IDEDrawerFilesTab()
            case .repos:    IDEDrawerReposTab2()
            case .settings: IDEDrawerSettingsTab()
            case .profile:  IDEDrawerProfileTab()
            case .about:    IDEDrawerAboutTab()
            }

            Spacer()
        }
        .background(Color(hex: "#0d1117"))
        .ignoresSafeArea()
    }
}

// MARK: - Drawer Profile Header

struct IDEDrawerProfileHeader: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        HStack(spacing: 12) {
            // GitHub avatar
            if let img = authVM.avatarImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44).clipShape(Circle())
                    .overlay(Circle().stroke(themeVM.accent.opacity(0.4), lineWidth: 1))
            } else {
                Circle()
                    .fill(themeVM.surface)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(themeVM.dim)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(authVM.username.isEmpty ? "Ash Tree IDE" : authVM.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeVM.text)
                if authVM.githubConnected {
                    Label("@\(authVM.githubUsername)", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(themeVM.accent.opacity(0.7))
                } else if authVM.isGuest {
                    Text("Guest mode")
                        .font(.system(size: 10))
                        .foregroundColor(themeVM.dim)
                }
            }

            Spacer()

            // Close drawer
            Button { withAnimation { IDEStateShared.shared.showDrawer = false } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeVM.dim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60) // safe area
        .padding(.bottom, 14)
        .background(Color(hex: "#161b22"))
    }
}

// Quick access to ideVM without EnvironmentObject threading
final class IDEStateShared {
    static let shared = IDEStateShared()
    var showDrawer = false
}

// MARK: - Drawer Tabs Content

struct IDEDrawerFilesTab: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    // Multi-select state
    @State private var selectMode   = false
    @State private var selectedFiles: Set<String> = []

    // Rename state
    @State private var renamingFile: String? = nil
    @State private var renameText   = ""

    // Export
    @State private var showExportOptions  = false
    @State private var showZipExporter    = false
    @State private var showFolderExporter = false
    @State private var zipData: Data?     = nil

    var body: some View {
        VStack(spacing: 0) {
            // Source picker
            Picker("Source", selection: $ideVM.fileSource) {
                ForEach(IDEState.FileSource.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14).padding(.vertical, 10)

            // Multi-select action bar (visible in select mode)
            if selectMode {
                HStack(spacing: 8) {
                    Button("Cancel") {
                        selectMode = false; selectedFiles = []
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.dim)

                    Spacer()

                    Text("\(selectedFiles.count) selected")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeVM.accent)

                    Spacer()

                    // Export button
                    if !selectedFiles.isEmpty {
                        Button {
                            showExportOptions = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13))
                                .foregroundColor(themeVM.accent)
                        }
                        .confirmationDialog("Export Files", isPresented: $showExportOptions) {
                            Button("Export as ZIP") {
                                buildZip()
                                showZipExporter = true
                            }
                            Button("Export Files Individually") {
                                showFolderExporter = true
                            }
                            Button("Delete Selected", role: .destructive) {
                                for name in selectedFiles { ideVM.deleteLocalFile(name) }
                                selectedFiles = []; selectMode = false
                            }
                            Button("Cancel", role: .cancel) {}
                        }

                        // Delete selected
                        Button {
                            for name in selectedFiles { ideVM.deleteLocalFile(name) }
                            selectedFiles = []; selectMode = false
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color(hex: "#161b22"))
            }

            if ideVM.fileSource == .local {
                // ── Local device files ──────────────────────────────
                List {
                    Section {
                        // Restore defaults
                        Button {
                            ideVM.examples.forEach { ex in
                                let fname = ex.name.lowercased()
                                    .replacingOccurrences(of: " ", with: "_") + ".ash"
                                UserDefaults.standard.set(ex.code, forKey: "ide_local_\(fname)")
                                if !ideVM.localFiles.contains(fname) { ideVM.localFiles.append(fname) }
                            }
                            UserDefaults.standard.set(ideVM.localFiles, forKey: "ide_local_file_list")
                            UserDefaults.standard.synchronize(); ideVM.loadLocalFiles()
                        } label: {
                            Label("Restore Default Projects", systemImage: "arrow.counterclockwise")
                                .foregroundColor(themeVM.dim)
                        }

                        // New file
                        Button {
                            ideVM.newFile()
                            withAnimation { ideVM.showDrawer = false }
                        } label: {
                            Label("New Local File", systemImage: "plus.square")
                                .foregroundColor(themeVM.accent)
                        }

                        // Select all / deselect all (only in select mode)
                        if selectMode {
                            Button {
                                if selectedFiles.count == ideVM.localFiles.count {
                                    selectedFiles = []
                                } else {
                                    selectedFiles = Set(ideVM.localFiles)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedFiles.count == ideVM.localFiles.count
                                        ? "checkmark.square.fill" : "square")
                                        .foregroundColor(themeVM.accent)
                                    Text(selectedFiles.count == ideVM.localFiles.count
                                        ? "Deselect All" : "Select All")
                                        .foregroundColor(themeVM.text)
                                }
                            }
                        }
                    }

                    Section {
                        ForEach(ideVM.localFiles, id: \.self) { name in
                            // Inline rename mode
                            if renamingFile == name {
                                HStack {
                                    Image(systemName: "pencil")
                                        .foregroundColor(themeVM.accent).font(.system(size: 12))
                                    TextField("Filename", text: $renameText)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(themeVM.accent)
                                        .autocorrectionDisabled().autocapitalization(.none)
                                        .onSubmit { commitRename(from: name) }
                                    Button("Save") { commitRename(from: name) }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(themeVM.accent)
                                    Button("✕") { renamingFile = nil }
                                        .font(.system(size: 11)).foregroundColor(.red)
                                }
                            } else {
                                // Normal row — tap to open, long-press to enter select mode
                                Button {
                                    if selectMode {
                                        if selectedFiles.contains(name) {
                                            selectedFiles.remove(name)
                                        } else {
                                            selectedFiles.insert(name)
                                        }
                                    } else {
                                        ideVM.openLocalFile(name)
                                        withAnimation { ideVM.showDrawer = false }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        // Multi-select checkbox
                                        if selectMode {
                                            Image(systemName: selectedFiles.contains(name)
                                                ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedFiles.contains(name)
                                                    ? themeVM.accent : themeVM.dim)
                                                .font(.system(size: 14))
                                        }
                                        Image(systemName: ideVM.currentFile == name
                                            ? "doc.text.fill" : "doc.text")
                                            .foregroundColor(ideVM.currentFile == name
                                                ? themeVM.accent : themeVM.dim)
                                        Text(name)
                                            .foregroundColor(ideVM.currentFile == name
                                                ? themeVM.accent : themeVM.text)
                                            .fontWeight(ideVM.currentFile == name ? .semibold : .regular)
                                            .font(.system(size: 13))
                                        Spacer()
                                        if ideVM.currentFile == name && !selectMode {
                                            Circle().fill(themeVM.accent).frame(width:5,height:5)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .onLongPressGesture {
                                    withAnimation { selectMode = true; selectedFiles.insert(name) }
                                }
                                // Swipe left → Delete
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        ideVM.deleteLocalFile(name)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                // Swipe right → Rename
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        let base = name.hasSuffix(".ash")
                                            ? String(name.dropLast(4)) : name
                                        renameText  = base
                                        renamingFile = name
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    .tint(themeVM.accent)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { ideVM.deleteLocalFile(ideVM.localFiles[i]) }
                        }
                    } header: {
                        Text("LOCAL DEVICE FILES")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(themeVM.dim).kerning(1)
                    }

                    // Save to device
                    Section {
                        Button {
                            ideVM.saveLocally()
                            ideVM.exportFileToDevice = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundColor(themeVM.accent)
                                Text("Save to Device")
                                    .foregroundColor(themeVM.accent)
                            }
                        }
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .onAppear { ideVM.loadLocalFiles() }
                .fileExporter(
                    isPresented: Binding(
                        get: { ideVM.exportFileToDevice },
                        set: { ideVM.exportFileToDevice = $0 }
                    ),
                    document: AshDocument(content: ideVM.sourceCode, filename: ideVM.currentFile),
                    contentType: .plainText,
                    defaultFilename: ideVM.currentFile
                ) { _ in ideVM.exportFileToDevice = false }
                // ZIP export for multi-select
                .fileExporter(
                    isPresented: $showZipExporter,
                    document: zipData.map { ZipDocument(data: $0) } ?? ZipDocument(data: Data()),
                    contentType: .zip,
                    defaultFilename: "ash_export.zip"
                ) { _ in showZipExporter = false; zipData = nil }

            } else if ideVM.fileSource == .examples {
                // ── Examples ─────────────────────────────────────────
                List {
                    ForEach(ideVM.examples, id: \.name) { ex in
                        Button {
                            ideVM.loadExample(name: ex.name, code: ex.code)
                            withAnimation { ideVM.showDrawer = false }
                        } label: {
                            Label(ex.name, systemImage: ex.icon).foregroundColor(themeVM.text)
                        }
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)

            } else {
                // ── Repository ───────────────────────────────────────
                IDEDrawerRepoFilesTab()
            }
        }
    }

    // Build ZIP from selected files
    private func buildZip() {
        var entries: [(name: String, data: Data)] = []
        for fname in selectedFiles {
            let content = UserDefaults.standard.string(forKey: "ide_local_\(fname)") ?? ""
            entries.append((name: fname, data: Data(content.utf8)))
        }
        zipData = buildRawZip(entries: entries)
    }

    private func buildRawZip(entries: [(name: String, data: Data)]) -> Data? {
        var zip = Data(); var cd = Data(); var offsets = [UInt32]()
        func u16(_ v: Int) -> Data { var n = UInt16(v); return Data(bytes: &n, count: 2) }
        func u32(_ v: Int) -> Data { var n = UInt32(v); return Data(bytes: &n, count: 4) }
        func crc32(_ d: Data) -> UInt32 {
            var c: UInt32 = 0xFFFFFFFF; var t = [UInt32](repeating:0,count:256)
            for i in 0..<256 { var v = UInt32(i); for _ in 0..<8 { v = (v&1) != 0 ? (v>>1)^0xEDB88320 : v>>1 }; t[i]=v }
            for b in d { c = (c>>8)^t[Int((c^UInt32(b))&0xFF)] }; return c^0xFFFFFFFF
        }
        for e in entries {
            let nb=Data(e.name.utf8); let cr=crc32(e.data); offsets.append(UInt32(zip.count))
            var lh=Data([0x50,0x4B,0x03,0x04]); lh+=u16(20);lh+=u16(0);lh+=u16(0);lh+=u16(0);lh+=u16(0)
            lh+=u32(Int(cr));lh+=u32(e.data.count);lh+=u32(e.data.count);lh+=u16(nb.count);lh+=u16(0);lh+=nb;lh+=e.data
            zip+=lh
            var ce=Data([0x50,0x4B,0x01,0x02]);ce+=u16(20);ce+=u16(20);ce+=u16(0);ce+=u16(0);ce+=u16(0);ce+=u16(0);ce+=u16(0)
            ce+=u32(Int(cr));ce+=u32(e.data.count);ce+=u32(e.data.count);ce+=u16(nb.count);ce+=u16(0);ce+=u16(0);ce+=u16(0);ce+=u16(0)
            ce+=u32(0);ce+=u32(Int(offsets.last!));ce+=nb; cd+=ce
        }
        let cdo=UInt32(zip.count); let cds=UInt32(cd.count); zip+=cd
        var eocd=Data([0x50,0x4B,0x05,0x06]);eocd+=u16(0);eocd+=u16(0);eocd+=u16(entries.count);eocd+=u16(entries.count)
        eocd+=u32(Int(cds));eocd+=u32(Int(cdo));eocd+=u16(0); zip+=eocd
        return zip
    }

    private func commitRename(from oldName: String) {
        var newName = renameText.trimmingCharacters(in: .whitespaces)
        if newName.isEmpty { renamingFile = nil; return }
        if !newName.hasSuffix(".ash") { newName += ".ash" }
        guard newName != oldName else { renamingFile = nil; return }
        // Copy content to new key, remove old
        if let content = UserDefaults.standard.string(forKey: "ide_local_\(oldName)") {
            UserDefaults.standard.set(content, forKey: "ide_local_\(newName)")
        }
        UserDefaults.standard.removeObject(forKey: "ide_local_\(oldName)")
        if let i = ideVM.localFiles.firstIndex(of: oldName) { ideVM.localFiles[i] = newName }
        UserDefaults.standard.set(ideVM.localFiles, forKey: "ide_local_file_list")
        UserDefaults.standard.synchronize()
        if ideVM.currentFile == oldName { ideVM.currentFile = newName }
        ideVM.loadLocalFiles()
        renamingFile = nil
    }
}

// FileDocument for ZIP export
import UniformTypeIdentifiers

struct ZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// Sub-view for repo files (extracted to keep IDEDrawerFilesTab manageable)
struct IDEDrawerRepoFilesTab: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    var body: some View {
        IDEDrawerReposTab2()
    }
}


struct IDELocalFilesSection: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    // Multi-select state
    @State private var selectMode   = false
    @State private var selected     = Set<String>()

    // Rename state
    @State private var renamingFile: String? = nil
    @State private var renameText   = ""

    // Export state
    @State private var showExportOptions = false
    @State private var exportAsZip      = false
    @State private var exportedZip: Data?  = nil
    @State private var showZipShare      = false
    @State private var showIndivExport   = false
    @State private var exportQueue: [String] = []
    @State private var exportIdx         = 0

    // Confirm delete
    @State private var showDeleteConfirm = false

    var body: some View {
        Section {
            // ── Toolbar row (normal / select mode) ──────────────
            if selectMode {
                // Select mode header
                HStack {
                    Button {
                        if selected.count == ideVM.localFiles.count {
                            selected.removeAll()
                        } else {
                            selected = Set(ideVM.localFiles)
                        }
                    } label: {
                        Image(systemName: selected.count == ideVM.localFiles.count
                            ? "checkmark.square.fill" : "square")
                            .foregroundColor(themeVM.accent)
                        Text(selected.count == ideVM.localFiles.count ? "Deselect All" : "Select All")
                            .font(.system(size: 11)).foregroundColor(themeVM.accent)
                    }
                    Spacer()
                    Button("Done") {
                        withAnimation { selectMode = false; selected.removeAll() }
                    }
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(themeVM.accent)
                }
                .padding(.vertical, 4)

                // Action buttons when files are selected
                if !selected.isEmpty {
                    HStack(spacing: 8) {
                        // Export ZIP
                        Button {
                            exportAsZip = true
                            buildAndShareZip()
                        } label: {
                            Label("ZIP", systemImage: "archivebox")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(themeVM.accent).cornerRadius(6)
                        }
                        // Export individual
                        Button {
                            exportQueue = Array(selected)
                            exportIdx = 0
                            ideVM.exportFileToDevice = true
                            ideVM.sourceCode = UserDefaults.standard.string(forKey: "ide_local_\(exportQueue[0])") ?? ""
                            ideVM.currentFile = exportQueue[0]
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(themeVM.accent)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(themeVM.accent.opacity(0.12)).cornerRadius(6)
                        }
                        Spacer()
                        // Delete selected
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.red.opacity(0.12)).cornerRadius(6)
                        }
                        .confirmationDialog(
                            "Delete \(selected.count) file(s)?",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) {
                                selected.forEach { ideVM.deleteLocalFile($0) }
                                selected.removeAll(); selectMode = false
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                }
            } else {
                // Normal mode: restore + new file buttons
                Button {
                    ideVM.examples.forEach { ex in
                        let fname = ex.name.lowercased().replacingOccurrences(of:" ",with:"_") + ".ash"
                        UserDefaults.standard.set(ex.code, forKey:"ide_local_\(fname)")
                        if !ideVM.localFiles.contains(fname) { ideVM.localFiles.append(fname) }
                    }
                    UserDefaults.standard.set(ideVM.localFiles, forKey:"ide_local_file_list")
                    UserDefaults.standard.synchronize(); ideVM.loadLocalFiles()
                } label: {
                    Label("Restore Default Projects", systemImage:"arrow.counterclockwise")
                        .foregroundColor(themeVM.dim)
                }

                Button {
                    ideVM.newFile()
                } label: {
                    Label("New Local File", systemImage:"plus.square").foregroundColor(themeVM.accent)
                }
            }

            // ── File rows ────────────────────────────────────────
            ForEach(ideVM.localFiles, id:\.self) { name in
                Group {
                    if renamingFile == name {
                        // Inline rename field
                        HStack {
                            Image(systemName:"pencil").foregroundColor(themeVM.accent)
                            TextField("Filename", text: $renameText)
                                .font(.system(size:12,design:.monospaced))
                                .foregroundColor(themeVM.text)
                                .onSubmit { commitRename(from: name) }
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                            Button("Save") { commitRename(from: name) }
                                .font(.system(size:11,weight:.semibold))
                                .foregroundColor(themeVM.accent)
                        }
                        .padding(.vertical, 2)
                    } else if selectMode {
                        // Checkbox row
                        Button {
                            if selected.contains(name) { selected.remove(name) }
                            else { selected.insert(name) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected.contains(name)
                                    ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selected.contains(name) ? themeVM.accent : themeVM.dim)
                                Image(systemName: ideVM.currentFile == name ? "doc.text.fill" : "doc.text")
                                    .foregroundColor(ideVM.currentFile == name ? themeVM.accent : themeVM.dim)
                                Text(name)
                                    .font(.system(size:12))
                                    .foregroundColor(ideVM.currentFile == name ? themeVM.accent : themeVM.text)
                                    .fontWeight(ideVM.currentFile == name ? .semibold : .regular)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Normal tap row with long-press
                        Button {
                            ideVM.openLocalFile(name)
                            withAnimation { ideVM.showDrawer = false }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: ideVM.currentFile == name ? "doc.text.fill" : "doc.text")
                                    .foregroundColor(ideVM.currentFile == name ? themeVM.accent : themeVM.dim)
                                Text(name)
                                    .foregroundColor(ideVM.currentFile == name ? themeVM.accent : themeVM.text)
                                    .fontWeight(ideVM.currentFile == name ? .semibold : .regular)
                                Spacer()
                                if ideVM.currentFile == name {
                                    Circle().fill(themeVM.accent).frame(width:5,height:5)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            withAnimation { selectMode = true; selected.insert(name) }
                        })
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role:.destructive) { ideVM.deleteLocalFile(name) }
                                label: { Label("Delete", systemImage:"trash") }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                renamingFile = name
                                renameText = String(name.dropLast(name.hasSuffix(".ash") ? 4 : 0))
                            } label: {
                                Label("Rename", systemImage:"pencil")
                            }
                            .tint(themeVM.accent)
                        }
                    }
                }
            }

            // ── Save button ──────────────────────────────────────
            if !selectMode {
                Button {
                    ideVM.saveLocally(); ideVM.exportFileToDevice = true
                } label: {
                    HStack(spacing:6) {
                        Image(systemName:"square.and.arrow.down").foregroundColor(themeVM.accent)
                        Text("Save to Device").foregroundColor(themeVM.accent)
                    }
                }
            }
        } header: {
            Text("LOCAL DEVICE FILES").font(.system(size:9,weight:.semibold,design:.monospaced))
                .foregroundColor(themeVM.dim).kerning(1)
        }
        // ZIP share sheet
        .sheet(isPresented: $showZipShare) {
            if let zipData = exportedZip {
                ShareSheet(items: [zipData as Any])
            }
        }
    }

    // Commit inline rename
    func commitRename(from oldName: String) {
        var newName = renameText.trimmingCharacters(in: .whitespaces)
        if !newName.hasSuffix(".ash") { newName += ".ash" }
        guard !newName.isEmpty, newName != oldName, !ideVM.localFiles.contains(newName) else {
            renamingFile = nil; return
        }
        let content = UserDefaults.standard.string(forKey:"ide_local_\(oldName)") ?? ""
        UserDefaults.standard.set(content, forKey:"ide_local_\(newName)")
        UserDefaults.standard.removeObject(forKey:"ide_local_\(oldName)")
        if let idx = ideVM.localFiles.firstIndex(of: oldName) {
            ideVM.localFiles[idx] = newName
        }
        UserDefaults.standard.set(ideVM.localFiles, forKey:"ide_local_file_list")
        UserDefaults.standard.synchronize()
        if ideVM.currentFile == oldName { ideVM.currentFile = newName }
        renamingFile = nil
        ideVM.loadLocalFiles()
    }

    // Build ZIP from selected files and share
    func buildAndShareZip() {
        var zip = Data()
        var centralDir = Data()
        var offsets = [UInt32]()

        func u16(_ v: Int) -> Data { var n = UInt16(v); return Data(bytes:&n,count:2) }
        func u32(_ v: Int) -> Data { var n = UInt32(v); return Data(bytes:&n,count:4) }

        for fname in selected {
            let content = UserDefaults.standard.string(forKey:"ide_local_\(fname)") ?? ""
            let fileData = Data(content.utf8)
            let nameBytes = Data(fname.utf8)
            let crc: UInt32 = {
                var c: UInt32 = 0xFFFFFFFF
                var t=[UInt32](repeating:0,count:256)
                for i in 0..<256{var v=UInt32(i);for _ in 0..<8{v=(v&1) != 0 ? (v>>1)^0xEDB88320 : v>>1};t[i]=v}
                for b in fileData{c=(c>>8)^t[Int((c^UInt32(b))&0xFF)]};return c^0xFFFFFFFF
            }()
            let offset = UInt32(zip.count); offsets.append(offset)
            var lh=Data(); lh += Data([0x50,0x4B,0x03,0x04])
            lh += u16(20);lh += u16(0);lh += u16(0);lh += u16(0);lh += u16(0)
            lh += u32(Int(crc));lh += u32(fileData.count);lh += u32(fileData.count)
            lh += u16(nameBytes.count);lh += u16(0);lh += nameBytes;lh += fileData
            zip += lh
            var cd=Data(); cd += Data([0x50,0x4B,0x01,0x02])
            cd += u16(20);cd += u16(20);cd += u16(0);cd += u16(0);cd += u16(0);cd += u16(0);cd += u16(0)
            cd += u32(Int(crc));cd += u32(fileData.count);cd += u32(fileData.count)
            cd += u16(nameBytes.count);cd += u16(0);cd += u16(0);cd += u16(0);cd += u16(0);cd += u32(0)
            cd += u32(Int(offset));cd += nameBytes
            centralDir += cd
        }
        let cdOffset=UInt32(zip.count),cdSize=UInt32(centralDir.count); zip += centralDir
        var eocd=Data(); eocd += Data([0x50,0x4B,0x05,0x06])
        eocd += u16(0);eocd += u16(0);eocd += u16(selected.count);eocd += u16(selected.count)
        eocd += u32(Int(cdSize));eocd += u32(Int(cdOffset));eocd += u16(0); zip += eocd
        exportedZip = zip
        showZipShare = true
    }
}

// UIActivityViewController wrapper for ZIP sharing
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}


struct IDEDrawerReposTab2: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("REPOSITORIES")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeVM.dim).kerning(1)
                    if !ideVM.syncedFiles.isEmpty {
                        Text("\(ideVM.syncedFiles.count) file(s) syncing")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(themeVM.accent)
                    }
                }
                Spacer()
                // Refresh/reconnect button
                Button { Task { await ideVM.loadRepos() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh").font(.system(size: 9))
                    }
                    .foregroundColor(themeVM.accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(themeVM.accent.opacity(0.1)).cornerRadius(5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if ideVM.isLoadingFiles {
                ProgressView().tint(themeVM.accent).padding()
            } else if ideVM.repos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundColor(themeVM.dim.opacity(0.4))
                    Text("No repositories loaded")
                        .font(.system(size: 12))
                        .foregroundColor(themeVM.dim)
                    Button("Load Repos") { Task { await ideVM.loadRepos() } }
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                List(ideVM.repos) { repo in
                    Button {
                        // selectRepo fixes nav: switches to repository file view
                        Task { await ideVM.selectRepo(repo) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(repo.name, systemImage: repo.isPrivate ? "lock.fill" : "folder")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeVM.text)
                            if let desc = repo.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 9))
                                    .foregroundColor(themeVM.dim)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct IDEDrawerSettingsTab: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        List {
            Section {
                // Theme picker
                Picker("Theme", selection: $themeVM.current) {
                    ForEach(IDEThemeViewModel.Theme.allCases, id: \.self) { t in
                        HStack {
                            Circle().fill(t.accent).frame(width: 8, height: 8)
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
                .tint(themeVM.accent)
            } header: {
                Text("APPEARANCE").font(.system(size: 9, design: .monospaced)).foregroundColor(themeVM.dim).kerning(1)
            }

            Section {
                LabeledContent("Compiler", value: "LEATR v2.0").foregroundColor(themeVM.text)
                LabeledContent("Switch Eq.", value: "(xa²√xa) ± 1").foregroundColor(themeVM.text)
                LabeledContent("LEATR", value: "25 Orders of Operation").foregroundColor(themeVM.text)
                LabeledContent("Tools 1-7", value: "Maze · Puzzle · Envelope · Hammer · Stick · Knife · Scissors").foregroundColor(themeVM.text)
                LabeledContent("Math 8-19", value: "Parentheses · Exponents · ×÷ · +- · Log · Trig · Temp · Vel · Pressure · Mass · Photosyn.").foregroundColor(themeVM.text)
                LabeledContent("Senses 20-25", value: "Touch · Taste · Vision · Smell · Hear · Proprioception").foregroundColor(themeVM.text)
                LabeledContent("BRPN", value: "Buoyancy Reflex Pendulum Node").foregroundColor(themeVM.text)
                LabeledContent("Shells", value: "Aerospace / Maritime / Geological").foregroundColor(themeVM.text)
                LabeledContent("Maze", value: "LEMAC + D3.e algorithm").foregroundColor(themeVM.text)
            } header: {
                Text("COMPILER").font(.system(size: 9, design: .monospaced)).foregroundColor(themeVM.dim).kerning(1)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct IDEDrawerProfileTab: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var editingUsername = false
    @State private var draftUsername   = ""

    var body: some View {
        List {
            // ── App Username (editable) ──────────────────────────
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Username")
                            .font(.system(size: 10)).foregroundColor(themeVM.dim)
                        if editingUsername {
                            TextField("Username", text: $draftUsername)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeVM.accent)
                                .onSubmit {
                                    let trimmed = draftUsername.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        authVM.appUsername = trimmed
                                        KeychainHelper.save(key: "ide_app_username", value: trimmed)
                                        authVM.username = trimmed
                                    }
                                    editingUsername = false
                                }
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                        } else {
                            Text(authVM.appUsername.isEmpty ? authVM.username : authVM.appUsername)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeVM.text)
                        }
                    }
                    Spacer()
                    Button {
                        if editingUsername {
                            let trimmed = draftUsername.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                authVM.appUsername = trimmed
                                KeychainHelper.save(key: "ide_app_username", value: trimmed)
                                authVM.username = trimmed
                            }
                            editingUsername = false
                        } else {
                            draftUsername   = authVM.appUsername.isEmpty ? authVM.username : authVM.appUsername
                            editingUsername = true
                        }
                    } label: {
                        Text(editingUsername ? "Save" : "Edit")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeVM.accent)
                    }
                }
            } header: {
                Text("ACCOUNT").font(.system(size: 9, design: .monospaced)).foregroundColor(themeVM.dim).kerning(1)
            }

            // ── Connected Accounts ───────────────────────────────
            // Tap the row → switch active account
            // Tap the red ✕ → disconnect that account only
            Section("CONNECTED ACCOUNTS") {
                ForEach(authVM.savedAccounts) { acc in
                    Button {
                        // Row tap = switch active account (never disconnects)
                        authVM.setActiveAccount(acc.provider)
                    } label: {
                        HStack(spacing: 10) {
                            // Active badge
                            ZStack {
                                Circle()
                                    .fill(acc.isActive ? themeVM.accent : Color.clear)
                                    .frame(width: 18, height: 18)
                                Image(systemName: acc.isActive ? "checkmark" : "circle")
                                    .font(.system(size: acc.isActive ? 9 : 12, weight: .bold))
                                    .foregroundColor(acc.isActive ? .black : themeVM.dim)
                            }

                            // Provider icon
                            Image(systemName: acc.provider == "github"
                                ? "chevron.left.forwardslash.chevron.right" : "apple.logo")
                                .font(.system(size: 13))
                                .foregroundColor(themeVM.accent)

                            // Account info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(acc.username)
                                    .font(.system(size: 13, weight: acc.isActive ? .semibold : .regular))
                                    .foregroundColor(acc.isActive ? themeVM.accent : themeVM.text)
                                Text(acc.isActive ? "Active session" : "Tap to switch")
                                    .font(.system(size: 9))
                                    .foregroundColor(acc.isActive ? themeVM.accent : themeVM.dim)
                            }

                            Spacer()

                            // Use account name toggle
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Use name")
                                    .font(.system(size: 8)).foregroundColor(themeVM.dim)
                                Toggle("", isOn: Binding(
                                    get: { authVM.useAccountName(provider: acc.provider) },
                                    set: { authVM.setUseAccountName($0, provider: acc.provider) }
                                ))
                                .labelsHidden()
                                .tint(themeVM.accent)
                                .scaleEffect(0.7)
                            }

                            // Red glowing disconnect button
                            Button {
                                authVM.disconnectAccount(acc.provider)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                    .shadow(color: .red.opacity(0.6), radius: 4, x: 0, y: 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("ADD ACCOUNT") {
                // Add GitHub if not connected
                if !authVM.githubConnected {
                    Button {
                        Task { await authVM.startGitHubDeviceFlow() }
                    } label: {
                        Label("Connect GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(themeVM.accent)
                    }
                }
                // Add Apple if not connected
                if authVM.appleUserId.isEmpty {
                    // Use UIViewRepresentable to avoid "not in hierarchy" crash from sidebar
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Connect Apple ID", systemImage: "apple.logo")
                            .font(.system(size: 11))
                            .foregroundColor(themeVM.accent)
                        AppleSignInButton(
                            onRequest: { req in authVM.prepareAppleRequest(req) },
                            onCompletion: { result in authVM.handleAppleCompletion(result) }
                        )
                        .frame(height: 44)
                        .cornerRadius(8)
                    }
                }
            }

            Section {
                Button(role: .destructive) { authVM.signOut() } label: {
                    Label("Sign Out All", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

struct IDEDrawerAboutTab: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://radicaldeepscale.com")!) {
                    Label("Radical Deepscale", systemImage: "globe")
                        .foregroundColor(themeVM.accent)
                }
                Link(destination: URL(string: "https://dartmeadow.com")!) {
                    Label("DART Meadow", systemImage: "globe")
                        .foregroundColor(themeVM.accent)
                }
                Link(destination: URL(string: "https://github.com/DART-Skyboard/AshtreeIDE-iOS")!) {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        .foregroundColor(themeVM.accent)
                }
                Link(destination: URL(string: "https://radicaldeepscale.com/ashtreeide.html")!) {
                    Label("Ash Tree IDE Web", systemImage: "safari")
                        .foregroundColor(themeVM.accent)
                }
                Link(destination: URL(string: "https://leatr.xyz")!) {
                    Label("LEATR", systemImage: "book")
                        .foregroundColor(themeVM.accent)
                }
            } header: {
                Text("LINKS").font(.system(size: 9, design: .monospaced)).foregroundColor(themeVM.dim).kerning(1)
            }

            Section {
                LabeledContent("App", value: "Ash Tree IDE").foregroundColor(themeVM.text)
                LabeledContent("Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.4.0")
                    .foregroundColor(themeVM.text)
                LabeledContent("Compiler", value: "LEATR v2").foregroundColor(themeVM.text)
                LabeledContent("Author", value: "Justin Craig Venable").foregroundColor(themeVM.text)
                LabeledContent("Company", value: "DART Meadow | Radical Deepscale LLC.").foregroundColor(themeVM.text)
            } header: {
                Text("ABOUT").font(.system(size: 9, design: .monospaced)).foregroundColor(themeVM.dim).kerning(1)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
