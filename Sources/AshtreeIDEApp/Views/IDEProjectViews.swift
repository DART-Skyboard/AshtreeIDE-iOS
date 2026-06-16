// IDEProjectViews.swift
// Project browser, file tree, new project sheet, repo push/sync
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Project List View (replaces IDEDrawerFilesTab Local section)

struct IDEProjectsPanel: View {
    @EnvironmentObject var themeVM:   IDEThemeViewModel
    @EnvironmentObject var ideVM:     IDEState
    @StateObject private var store = IDEProjectStore.shared
    @State private var showNewProject   = false
    @State private var showImportFile   = false
    @State private var renamingProject: String? = nil
    @State private var renameText = ""
    @State private var showDeleteConfirm: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────
            HStack {
                Text("PROJECTS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeVM.dim).kerning(1.5)
                Spacer()
                Button {
                    showNewProject = true
                } label: {
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 18))
                        .foregroundColor(themeVM.accent)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if store.projects.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 36)).foregroundColor(themeVM.dim.opacity(0.4))
                    Text("No projects yet")
                        .font(.system(size: 12)).foregroundColor(themeVM.dim)
                    Button("Create First Project") { showNewProject = true }
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeVM.accent)
                }
                .frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                // Project list
                List {
                    ForEach(store.projects) { proj in
                        ProjectListRow(
                            project: proj,
                            isActive: store.activeProjectId == proj.id,
                            onTap: { store.setActive(proj.id) },
                            onRename: {
                                renameText = proj.name
                                renamingProject = proj.id
                            },
                            onDelete: { showDeleteConfirm = proj.id }
                        )
                    }
                    .onDelete { offsets in
                        for i in offsets { store.deleteProject(store.projects[i].id) }
                    }
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showNewProject) {
            IDENewProjectSheet(isPresented: $showNewProject)
                .environmentObject(themeVM)
                .environmentObject(ideVM)
                .environmentObject(IDELanguageStore.shared)
        }
        .alert("Rename Project", isPresented: Binding(
            get: { renamingProject != nil },
            set: { if !$0 { renamingProject = nil } }
        )) {
            TextField("Project name", text: $renameText)
            Button("Rename") {
                if let id = renamingProject, !renameText.isEmpty {
                    store.renameProject(id, to: renameText)
                }
                renamingProject = nil
            }
            Button("Cancel", role: .cancel) { renamingProject = nil }
        }
        .confirmationDialog("Delete Project?", isPresented: Binding(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = showDeleteConfirm { store.deleteProject(id) }
                showDeleteConfirm = nil
            }
            Button("Cancel", role: .cancel) { showDeleteConfirm = nil }
        }
        .onAppear { store.load() }
    }
}

// MARK: - Project Row

struct ProjectListRow: View {
    let project: IDEProject
    let isActive: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Language color dot
                let env = IDELanguageEnv.find(id: project.primaryLanguage)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: env.color).opacity(isActive ? 0.2 : 0.08))
                        .frame(width: 32, height: 32)
                    Image(systemName: env.icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: env.color))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? themeVM.accent : themeVM.text)
                    HStack(spacing: 6) {
                        Text("\(project.files.count) items · \(env.name)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(themeVM.dim)
                        if project.syncEnabled, let repo = project.repoName {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8)).foregroundColor(themeVM.accent)
                            Text(repo).font(.system(size: 8, design: .monospaced))
                                .foregroundColor(themeVM.dim).lineLimit(1)
                        }
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeVM.accent).font(.system(size: 14))
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }.tint(themeVM.accent)
        }
    }
}

// MARK: - Project File Browser (shown below project list when one is active)

struct IDEProjectFileBrowser: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @StateObject private var store  = IDEProjectStore.shared
    @State private var showAddFile  = false
    @State private var showAddFolder = false
    @State private var showImport   = false
    @State private var showRepoSheet = false
    @State private var newFileName  = ""
    @State private var newFileLang  = "ash"
    @State private var newFolderName = ""
    @State private var targetFolder: String? = nil

    var project: IDEProject { store.activeProject ?? IDEProject(
        id:"", name:"", primaryLanguage:"ash", files:[], repoOwner:nil,
        repoName:nil, syncEnabled:false, createdAt:0, modifiedAt:0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Project header ───────────────────────────────
            HStack(spacing: 6) {
                let env = IDELanguageEnv.find(id: project.primaryLanguage)
                Image(systemName: env.icon)
                    .font(.system(size: 11)).foregroundColor(Color(hex: env.color))
                Text(project.name)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeVM.accent)
                Spacer()
                // Repo sync indicator
                if project.syncEnabled {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11)).foregroundColor(themeVM.accent)
                }
                // Repo button
                Button { showRepoSheet = true } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 11)).foregroundColor(themeVM.dim)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(hex: "#161b22"))

            // ── File tree ─────────────────────────────────────
            List {
                // Action buttons
                Section {
                    // Add file
                    Button { showAddFile = true } label: {
                        Label("New File", systemImage: "plus.square")
                            .foregroundColor(themeVM.accent)
                    }
                    // Add folder
                    Button { showAddFolder = true } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                            .foregroundColor(themeVM.accent)
                    }
                    // Import from device
                    Button { showImport = true } label: {
                        Label("Import File", systemImage: "arrow.down.doc")
                            .foregroundColor(themeVM.accent)
                    }
                }
                .fileImporter(isPresented: $showImport,
                              allowedContentTypes: [.item],
                              allowsMultipleSelection: false) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        _ = url.startAccessingSecurityScopedResource()
                        if let data = try? Data(contentsOf: url) {
                            store.importFile(in: project.id, name: url.lastPathComponent, data: data)
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // File tree
                Section("FILES") {
                    FileTreeNodes(
                        nodes: project.files,
                        projectId: project.id,
                        prefix: "",
                        depth: 0
                    )
                    .environmentObject(themeVM)
                    .environmentObject(ideVM)
                    .environmentObject(store)
                }

                // Save to device
                Section {
                    Button {
                        ideVM.exportFileToDevice = true
                    } label: {
                        Label("Save to Device", systemImage: "square.and.arrow.down")
                            .foregroundColor(themeVM.accent)
                    }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
        // Add File sheet
        .sheet(isPresented: $showAddFile) {
            AddFileSheet(projectId: project.id, isPresented: $showAddFile)
                .environmentObject(themeVM)
                .environmentObject(store)
        }
        // Add Folder alert
        .alert("New Folder", isPresented: $showAddFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                if !newFolderName.isEmpty {
                    store.addFolder(to: project.id, name: newFolderName)
                    newFolderName = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Repo sheet
        .sheet(isPresented: $showRepoSheet) {
            ProjectRepoSheet(projectId: project.id, isPresented: $showRepoSheet)
                .environmentObject(themeVM)
                .environmentObject(store)
        }
        .fileExporter(
            isPresented: Binding(get:{ideVM.exportFileToDevice},set:{ideVM.exportFileToDevice=$0}),
            document: AshDocument(content: ideVM.sourceCode, filename: ideVM.currentFile),
            contentType: .plainText, defaultFilename: ideVM.currentFile
        ) { _ in ideVM.exportFileToDevice = false }
    }
}

// MARK: - Recursive File Tree

struct FileTreeNodes: View {
    let nodes: [IDEFileNode]
    let projectId: String
    let prefix: String
    let depth: Int
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var store:   IDEProjectStore

    var body: some View {
        ForEach(nodes) { node in
            let path = prefix.isEmpty ? node.name : "\(prefix)/\(node.name)"
            if node.isFolder {
                FolderRow(node: node, path: path, projectId: projectId, depth: depth)
                    .environmentObject(themeVM)
                    .environmentObject(ideVM)
                    .environmentObject(store)
                // Show children if expanded
                if store.expandedFolders.contains(path), let children = node.children {
                    FileTreeNodes(nodes: children, projectId: projectId,
                                  prefix: path, depth: depth + 1)
                        .environmentObject(themeVM)
                        .environmentObject(ideVM)
                        .environmentObject(store)
                }
            } else {
                FileRow(node: node, path: path, projectId: projectId, depth: depth)
                    .environmentObject(themeVM)
                    .environmentObject(ideVM)
                    .environmentObject(store)
            }
        }
    }
}

struct FolderRow: View {
    let node: IDEFileNode; let path: String; let projectId: String; let depth: Int
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var store:   IDEProjectStore
    var isExpanded: Bool { store.expandedFolders.contains(path) }

    var body: some View {
        Button {
            withAnimation {
                if isExpanded { store.expandedFolders.remove(path) }
                else          { store.expandedFolders.insert(path) }
            }
        } label: {
            HStack(spacing: 6) {
                Rectangle().fill(.clear).frame(width: CGFloat(depth) * 12)
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#e5c07b"))
                Text(node.name)
                    .font(.system(size: 12)).foregroundColor(themeVM.text)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9)).foregroundColor(themeVM.dim)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.deleteFile(in: projectId, path: path) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct FileRow: View {
    let node: IDEFileNode; let path: String; let projectId: String; let depth: Int
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var store:   IDEProjectStore
    var isActive: Bool { store.activeFilePath == path && store.activeProjectId == projectId }
    var env: IDELanguageEnv { IDELanguageEnv.find(id: node.language) }

    var body: some View {
        Button {
            store.activeFilePath = path
            let content = store.readFile(in: projectId, path: path)
            ideVM.sourceCode  = content
            ideVM.currentFile = node.name
            ideVM.isDirty     = false
            withAnimation { ideVM.showDrawer = false }
        } label: {
            HStack(spacing: 6) {
                Rectangle().fill(.clear).frame(width: CGFloat(depth) * 12)
                Image(systemName: node.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? Color(hex: env.color) : themeVM.dim)
                Text(node.name)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? Color(hex: env.color) : themeVM.text)
                Spacer()
                if isActive { Circle().fill(Color(hex: env.color)).frame(width: 5, height: 5) }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.deleteFile(in: projectId, path: path) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add File Sheet

struct AddFileSheet: View {
    let projectId: String
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var store:   IDEProjectStore
    @State private var filename = ""
    @State private var selectedLang = "ash"

    var selectedEnv: IDELanguageEnv { IDELanguageEnv.find(id: selectedLang) }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0d1117").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text("NEW FILE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeVM.dim).kerning(2)

                    // Filename
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Filename")
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(themeVM.dim)
                        HStack {
                            TextField("filename", text: $filename)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(themeVM.accent)
                                .autocorrectionDisabled().autocapitalization(.none)
                            Text(selectedEnv.ext)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(themeVM.dim)
                        }
                        .padding(10).background(Color(hex: "#161b22")).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius:8)
                            .stroke(Color(hex:selectedEnv.color).opacity(0.3),lineWidth:0.5))
                    }

                    // Language picker
                    Text("Language")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(themeVM.dim)
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 8) {
                            ForEach(IDELanguageEnv.all, id: \.id) { env in
                                Button { selectedLang = env.id } label: {
                                    VStack(spacing:4) {
                                        Image(systemName: env.icon)
                                            .font(.system(size:16))
                                            .foregroundColor(Color(hex:env.color))
                                        Text(env.ext)
                                            .font(.system(size:8,weight:.bold,design:.monospaced))
                                            .foregroundColor(Color(hex:env.color))
                                    }
                                    .frame(height:48)
                                    .frame(maxWidth:.infinity)
                                    .background(selectedLang == env.id
                                        ? Color(hex:env.color).opacity(0.15) : Color(hex:"#161b22"))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius:8)
                                        .stroke(selectedLang == env.id
                                            ? Color(hex:env.color) : Color(hex:"#21262d"),
                                                lineWidth:0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 300)

                    Spacer()

                    Button {
                        let name = (filename.isEmpty ? "untitled" : filename)
                            + (filename.contains(".") ? "" : selectedEnv.ext)
                        store.addFile(to: projectId, name: name, language: selectedLang)
                        isPresented = false
                    } label: {
                        Text("Create File")
                            .font(.system(size:13,weight:.semibold))
                            .foregroundColor(.black).frame(maxWidth:.infinity)
                            .padding(.vertical,14)
                            .background(Color(hex:selectedEnv.color)).cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Cancel") { isPresented = false }.foregroundColor(themeVM.dim)
                }
            }
        }
    }
}

// MARK: - Repo Sheet

struct ProjectRepoSheet: View {
    let projectId: String
    @Binding var isPresented: Bool
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var store:   IDEProjectStore
    @State private var newRepoName    = ""
    @State private var isPrivate      = true
    @State private var isPushing      = false
    @State private var isSyncing      = false
    @State private var statusMessage  = ""
    @State private var showUnlink     = false

    var project: IDEProject? { store.projects.first { $0.id == projectId } }
    var owner: String { KeychainHelper.load(key: "ide_github_username") ?? "" }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0d1117").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let proj = project {
                            // Current link status
                            if let repo = proj.repoName, let repoOwner = proj.repoOwner {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("LINKED REPOSITORY")
                                        .font(.system(size:8,weight:.semibold,design:.monospaced))
                                        .foregroundColor(themeVM.dim).kerning(1.5)
                                    HStack {
                                        Image(systemName:"chevron.left.forwardslash.chevron.right")
                                            .foregroundColor(themeVM.accent)
                                        Text("\(repoOwner)/\(repo)")
                                            .font(.system(size:12,design:.monospaced))
                                            .foregroundColor(themeVM.text)
                                        Spacer()
                                        Toggle("Sync", isOn: Binding(
                                            get: { proj.syncEnabled },
                                            set: { on in
                                                if var p = store.projects.first(where:{$0.id==projectId}) {
                                                    p.syncEnabled = on
                                                    if let i = store.projects.firstIndex(where:{$0.id==projectId}) {
                                                        store.projects[i].syncEnabled = on
                                                        store.save()
                                                    }
                                                }
                                            }
                                        ))
                                        .tint(themeVM.accent).labelsHidden().scaleEffect(0.8)
                                    }
                                    .padding(12).background(Color(hex:"#161b22")).cornerRadius(8)

                                    // Sync from repo button
                                    Button {
                                        isSyncing = true; statusMessage = "Pulling from repo…"
                                        Task {
                                            do {
                                                try await store.syncProjectFromRepo(projectId: projectId)
                                                statusMessage = "✓ Synced from \(repo)"
                                            } catch {
                                                statusMessage = "⚠ \(error.localizedDescription)"
                                            }
                                            isSyncing = false
                                        }
                                    } label: {
                                        Label("Pull from Repository", systemImage:"arrow.down.circle")
                                            .font(.system(size:11,weight:.semibold,design:.monospaced))
                                            .foregroundColor(themeVM.accent)
                                            .frame(maxWidth:.infinity).padding(.vertical,10)
                                            .background(themeVM.accent.opacity(0.1)).cornerRadius(8)
                                    }
                                    .disabled(isSyncing)

                                    // Push all files button
                                    Button {
                                        isPushing = true; statusMessage = "Pushing all files…"
                                        Task {
                                            do {
                                                for path in proj.allFilePaths {
                                                    let content = store.readFile(in: projectId, path: path)
                                                    try await IDEGitHubClient.shared.writeFile(
                                                        owner: repoOwner, repo: repo, path: path,
                                                        content: content, message: "Push from Ash Tree IDE")
                                                }
                                                statusMessage = "✓ Pushed \(proj.allFilePaths.count) files"
                                            } catch { statusMessage = "⚠ \(error.localizedDescription)" }
                                            isPushing = false
                                        }
                                    } label: {
                                        Label("Push All Files", systemImage:"arrow.up.circle")
                                            .font(.system(size:11,weight:.semibold,design:.monospaced))
                                            .foregroundColor(Color(hex:"#39ff82"))
                                            .frame(maxWidth:.infinity).padding(.vertical,10)
                                            .background(Color(hex:"#39ff82").opacity(0.1)).cornerRadius(8)
                                    }
                                    .disabled(isPushing)

                                    // Unlink
                                    Button { showUnlink = true } label: {
                                        Label("Unlink Repository", systemImage:"xmark.circle")
                                            .font(.system(size:11,design:.monospaced))
                                            .foregroundColor(.red)
                                    }
                                    .confirmationDialog("Unlink \(repo)?",
                                                        isPresented: $showUnlink,
                                                        titleVisibility: .visible) {
                                        Button("Unlink", role: .destructive) {
                                            store.unlinkRepo(projectId: projectId)
                                        }
                                        Button("Cancel", role: .cancel) {}
                                    }
                                }

                            } else {
                                // Not linked — offer create or link existing
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("PUSH TO GITHUB")
                                        .font(.system(size:8,weight:.semibold,design:.monospaced))
                                        .foregroundColor(themeVM.dim).kerning(1.5)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("New repository name")
                                            .font(.system(size:10,design:.monospaced)).foregroundColor(themeVM.dim)
                                        TextField("\(proj.name.lowercased().replacingOccurrences(of:" ",with:"-"))",
                                                  text: $newRepoName)
                                            .font(.system(size:12,design:.monospaced))
                                            .foregroundColor(themeVM.accent)
                                            .autocorrectionDisabled().autocapitalization(.none)
                                            .padding(10).background(Color(hex:"#161b22")).cornerRadius(8)
                                    }

                                    Toggle("Private repository", isOn: $isPrivate)
                                        .tint(themeVM.accent)
                                        .font(.system(size:12,design:.monospaced))
                                        .foregroundColor(themeVM.text)

                                    Button {
                                        let rName = newRepoName.isEmpty
                                            ? proj.name.lowercased().replacingOccurrences(of:" ",with:"-")
                                            : newRepoName
                                        isPushing = true; statusMessage = "Creating repo and pushing…"
                                        Task {
                                            do {
                                                try await store.pushProjectToNewRepo(
                                                    projectId: projectId, repoName: rName,
                                                    owner: owner, isPrivate: isPrivate)
                                                statusMessage = "✓ Pushed to \(owner)/\(rName)"
                                            } catch { statusMessage = "⚠ \(error.localizedDescription)" }
                                            isPushing = false
                                        }
                                    } label: {
                                        HStack {
                                            if isPushing { ProgressView().scaleEffect(0.7).tint(.black) }
                                            Text(isPushing ? "Pushing…" : "Create Repo & Push")
                                                .font(.system(size:13,weight:.semibold))
                                        }
                                        .foregroundColor(.black).frame(maxWidth:.infinity)
                                        .padding(.vertical,14)
                                        .background(Color(hex:"#39ff82")).cornerRadius(12)
                                    }
                                    .disabled(isPushing || owner.isEmpty)

                                    if owner.isEmpty {
                                        Text("⚠ Connect GitHub in Profile to push to repos.")
                                            .font(.system(size:10,design:.monospaced))
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.system(size:10,design:.monospaced))
                                    .foregroundColor(statusMessage.contains("✓") ? .green : .orange)
                                    .padding(8).background(Color(hex:"#161b22")).cornerRadius(6)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Done") { isPresented = false }.foregroundColor(themeVM.accent)
                }
            }
        }
    }
}
