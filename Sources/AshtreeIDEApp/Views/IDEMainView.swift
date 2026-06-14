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
            case .repos:    IDEDrawerReposTab()
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

    var body: some View {
        VStack(spacing: 0) {
            // Source picker
            Picker("Source", selection: $ideVM.fileSource) {
                ForEach(IDEState.FileSource.allCases, id: \.self) { s in
                    Label(s.rawValue, systemImage: s.icon).tag(s)
                }
            }.pickerStyle(.segmented).padding(10)
            .background(themeVM.surface)

            List {
                switch ideVM.fileSource {
                case .examples:
                    Section {
                        Button {
                            ideVM.newFile()
                            withAnimation { ideVM.showDrawer = false }
                        } label: {
                            Label("New Project", systemImage: "folder.badge.plus").foregroundColor(themeVM.accent)
                        }
                        ForEach(ideVM.examples, id: \.name) { ex in
                            Button {
                                ideVM.loadExample(ex.code, name: ex.name.lowercased().replacingOccurrences(of: " ", with: "_"))
                                withAnimation { ideVM.showDrawer = false }
                            } label: {
                                Label(ex.name, systemImage: ex.icon).foregroundColor(themeVM.text)
                            }
                        }
                    } header: {
                        Text("EXAMPLE PROJECTS").font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(themeVM.dim).kerning(1)
                    }

                case .repository:
                    // Show repo files
                    if ideVM.isLoadingFiles {
                        HStack { Spacer(); ProgressView().tint(themeVM.accent); Spacer() }.padding()
                    } else if let repo = ideVM.currentRepo {
                        Section {
                            if !ideVM.currentPath.isEmpty {
                                Button {
                                    let parent = String(ideVM.currentPath.split(separator: "/").dropLast().joined(separator: "/"))
                                    Task { await ideVM.loadFiles(repo: repo, path: parent) }
                                } label: {
                                    Label(".. (up)", systemImage: "arrow.up.doc").foregroundColor(themeVM.dim)
                                }
                            }
                            ForEach(ideVM.repoFiles, id: \.path) { file in
                                Button {
                                    if file.type == "dir" {
                                        Task { await ideVM.loadFiles(repo: repo, path: file.path) }
                                    } else {
                                        Task { await ideVM.openFile(file); withAnimation { ideVM.showDrawer = false } }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: file.type == "dir" ? "folder.fill" : (file.name.hasSuffix(".ash") ? "chevron.left.forwardslash.chevron.right" : "doc"))
                                            .foregroundColor(file.type == "dir" ? themeVM.accent : (file.name.hasSuffix(".ash") ? Color(hex: "#00ffcc") : themeVM.dim))
                                        Text(file.name).font(.system(size: 12, design: file.name.hasSuffix(".ash") ? .monospaced : .default))
                                            .foregroundColor(themeVM.text)
                                    }
                                }
                            }
                        } header: {
                            Text("\(repo.name)\(ideVM.currentPath.isEmpty ? "" : "/\(ideVM.currentPath)")")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(themeVM.dim).kerning(1)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName:"folder.badge.questionmark")
                                .font(.system(size:32)).foregroundColor(themeVM.dim.opacity(0.3))
                            Text("Open a repository from the Repos tab")
                                .font(.system(size:11)).foregroundColor(themeVM.dim)
                                .multilineTextAlignment(.center)
                            Button("Go to Repos") {
                                ideVM.drawerTab = .repos
                                Task { await ideVM.loadRepos() }
                            }
                            .font(.system(size:10,weight:.semibold,design:.monospaced))
                            .foregroundColor(themeVM.accent)
                        }
                        .frame(maxWidth:.infinity)
                        .padding(.top,30)
                    }

                case .local:
                    Section {
                        Button {
                            ideVM.newFile()
                            withAnimation { ideVM.showDrawer = false }
                        } label: {
                            Label("New Local File", systemImage: "plus.square").foregroundColor(themeVM.accent)
                        }
                        ForEach(ideVM.localFiles, id: \.self) { name in
                            Button {
                                ideVM.openLocalFile(name)
                                withAnimation { ideVM.showDrawer = false }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: ideVM.currentFile == name
                                        ? "doc.text.fill" : "doc.text")
                                        .foregroundColor(ideVM.currentFile == name
                                            ? themeVM.accent : themeVM.dim)
                                    Text(name)
                                        .foregroundColor(ideVM.currentFile == name
                                            ? themeVM.accent : themeVM.text)
                                        .fontWeight(ideVM.currentFile == name ? .semibold : .regular)
                                    Spacer()
                                    if ideVM.currentFile == name {
                                        Circle().fill(themeVM.accent).frame(width:5,height:5)
                                    }
                                }
                            }
                        }
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
                    } header: {
                        Text("LOCAL DEVICE FILES").font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(themeVM.dim).kerning(1)
                    }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden)
        }
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
    }
}

struct IDEDrawerReposTab: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("REPOSITORIES")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeVM.dim).kerning(1)
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

    var body: some View {
        List {
            Section {
                LabeledContent("Username", value: authVM.username).foregroundColor(themeVM.text)
                if authVM.githubConnected {
                    LabeledContent("GitHub", value: "@\(authVM.githubUsername)").foregroundColor(themeVM.text)
                }
                if !authVM.appleUserId.isEmpty {
                    LabeledContent("Apple ID", value: "Signed in").foregroundColor(themeVM.text)
                }
            } header: {
                Text("ACCOUNT").font(.system(size: 9, design: .monospaced)).foregroundColor(themeVM.dim).kerning(1)
            }

            Section("CONNECTED ACCOUNTS") {
                ForEach(authVM.savedAccounts) { acc in
                    HStack {
                        // Active indicator
                        Image(systemName: acc.isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundColor(acc.isActive ? themeVM.accent : themeVM.dim)
                        Image(systemName: acc.provider == "github" ? "chevron.left.forwardslash.chevron.right" : "apple.logo")
                            .font(.system(size: 11)).foregroundColor(themeVM.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(acc.username).font(.system(size: 12, weight: .medium)).foregroundColor(themeVM.text)
                            Text(acc.isActive ? "Active session" : acc.provider.capitalized)
                                .font(.system(size: 9))
                                .foregroundColor(acc.isActive ? themeVM.accent : themeVM.dim)
                        }
                        Spacer()
                        if !acc.isActive {
                            // Switch active session to this account
                            Button("Use") {
                                authVM.setActiveAccount(acc.provider)
                            }
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(themeVM.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(themeVM.accent.opacity(0.12)).cornerRadius(4)
                        }
                        // Disconnect — only on explicit ✕ tap
                        Button {
                            authVM.disconnectAccount(acc.provider)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
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
                LabeledContent("Version", value: "1.0.0").foregroundColor(themeVM.text)
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
