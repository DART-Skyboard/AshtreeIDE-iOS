// ============================================================
//  MainIDEView.swift — Primary IDE layout
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

struct MainIDEView: View {
    @EnvironmentObject var github: GitHubService
    @EnvironmentObject var ide: IDEState
    @State private var showUserMenu = false

    var body: some View {
        NavigationView {
            // Sidebar (iPad) — invisible on iPhone, content is in sheets/tabs
            FilesBrowserView()
                .navigationBarHidden(true)

            // Main content
            VStack(spacing: 0) {
                IDEToolbar(showUserMenu: $showUserMenu)
                IDETabBar()
                IDEContentArea()
                IDEStatusBar()
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $ide.showFileBrowser) { FilesBrowserView() }
        .sheet(isPresented: $ide.showSettings)    { SettingsView() }
        .confirmationDialog("Account", isPresented: $showUserMenu) {
            Button("Sign Out", role: .destructive) { github.signOut() }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Toolbar

struct IDEToolbar: View {
    @EnvironmentObject var github: GitHubService
    @EnvironmentObject var ide: IDEState
    @Binding var showUserMenu: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Logo wordmark
            HStack(spacing: 8) {
                AshTreeLogoMark(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ASH TREE IDE")
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .foregroundColor(Color("AshDark"))
                        .kerning(2)
                    Text("LEATR v2")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color("AshMid"))
                        .kerning(1)
                }
            }
            .padding(.leading, 16)

            Spacer()

            // Toolbar actions
            HStack(spacing: 4) {
                ToolbarButton(icon: "folder", label: "Files")  { ide.showFileBrowser = true }
                ToolbarButton(icon: "gearshape", label: "Settings") { ide.showSettings = true }

                // User avatar / login
                Button { showUserMenu = true } label: {
                    if let url = github.session?.avatarUrl, let u = URL(string: url) {
                        AsyncImage(url: u) { img in img.resizable() } placeholder: { Color("AshLight") }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color("AshLight"))
                            .frame(width: 28, height: 28)
                            .overlay(Image(systemName: "person.fill").foregroundColor(Color("AshMid")).font(.system(size: 12)))
                    }
                }
                .padding(.trailing, 12)
            }
        }
        .frame(height: 52)
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color("AshMid"))
                .frame(width: 36, height: 36)
        }
    }
}

// MARK: - Tab Bar

struct IDETabBar: View {
    @EnvironmentObject var ide: IDEState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { ide.selectedTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: 13, weight: ide.selectedTab == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: ide.selectedTab == tab ? .semibold : .regular))
                            .kerning(0.5)
                    }
                    .foregroundColor(ide.selectedTab == tab ? Color("AshDark") : Color("AshMid").opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        Rectangle()
                            .fill(ide.selectedTab == tab ? Color("AshDark") : .clear)
                            .frame(height: 2),
                        alignment: .bottom
                    )
                }
            }
        }
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    func tabIcon(_ tab: AppTab) -> String {
        switch tab {
        case .editor:   return "chevron.left.forwardslash.chevron.right"
        case .terminal: return "terminal"
        case .files:    return "folder"
        case .docs:     return "book"
        }
    }
}

// MARK: - Content Area

struct IDEContentArea: View {
    @EnvironmentObject var ide: IDEState

    var body: some View {
        Group {
            switch ide.selectedTab {
            case .editor:   EditorView()
            case .terminal: TerminalView()
            case .files:    FilesBrowserView()
            case .docs:     DocsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Status Bar

struct IDEStatusBar: View {
    @EnvironmentObject var ide: IDEState

    var shell: String { ide.brpnResult?.shell ?? "—" }
    var buoyancy: String {
        guard let b = ide.brpnResult?.buoyancy else { return "—" }
        return String(format: "%.4f", b)
    }

    var body: some View {
        HStack(spacing: 16) {
            Label(ide.currentFile, systemImage: "doc.text")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(Color("AshMid"))

            Spacer()

            if ide.isCompiling {
                ProgressView().scaleEffect(0.5)
                Text("Compiling…")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color("AshMid"))
            } else {
                Text("SHELL: \(shell)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color("AshMid"))
                Text("BUOY: \(buoyancy)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color("AshMid"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color("AshLight"))
        .overlay(Divider(), alignment: .top)
    }
}
