// IDEHelpView.swift — Ash Tree IDE App Guide
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI

struct IDEHelpView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var expandedSection: String? = nil

    var body: some View {
        ZStack {
            VStack {
                IDELogoMark(size: 200, accent: themeVM.accent).opacity(0.04)
                Text("ASH TREE IDE")
                    .font(.system(size:24,weight:.bold,design:.rounded))
                    .foregroundColor(themeVM.accent.opacity(0.03)).kerning(6)
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity)

            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    VStack(alignment:.leading,spacing:4) {
                        Text("◈ APP GUIDE")
                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(2)
                        Text("Ash Tree IDE")
                            .font(.system(size:22,weight:.bold,design:.rounded))
                            .foregroundColor(themeVM.text)
                        Text("LEATR v2 · Lead Edge Ash Tree Reflex · v1.5.0")
                            .font(.system(size:10,design:.monospaced))
                            .foregroundColor(themeVM.dim)
                    }
                    .padding(.bottom,4)

                    ForEach(IDEHelpSection.all, id:\.title) { section in
                        HelpSectionCard(section: section,
                                        isExpanded: expandedSection == section.title) {
                            withAnimation(.spring(response:0.35,dampingFraction:0.85)) {
                                expandedSection = (expandedSection == section.title) ? nil : section.title
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(themeVM.bg)
    }
}

struct HelpSectionCard: View {
    let section: IDEHelpSection
    let isExpanded: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            Button(action: onTap) {
                HStack(spacing:10) {
                    Image(systemName: section.icon)
                        .font(.system(size:14))
                        .foregroundColor(themeVM.accent)
                        .frame(width:22)
                    Text(section.title)
                        .font(.system(size:11,weight:.semibold,design:.monospaced))
                        .foregroundColor(themeVM.text)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size:10))
                        .foregroundColor(themeVM.dim)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment:.leading,spacing:10) {
                    ForEach(section.items, id:\.headline) { item in
                        HelpItem(item: item)
                    }
                }
                .padding(.horizontal,12).padding(.bottom,12)
                .transition(.opacity.combined(with:.move(edge:.top)))
            }
        }
        .background(Color(hex:"#0d1117"))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius:10)
            .stroke(isExpanded ? themeVM.accent.opacity(0.3) : Color(hex:"#21262d"), lineWidth:0.5))
    }
}

struct HelpItem: View {
    let item: IDEHelpItem
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        VStack(alignment:.leading,spacing:3) {
            HStack(spacing:6) {
                if let gesture = item.gesture {
                    Text(gesture)
                        .font(.system(size:9,weight:.bold,design:.monospaced))
                        .foregroundColor(Color(hex:"#e5c07b"))
                        .padding(.horizontal,5).padding(.vertical,2)
                        .background(Color(hex:"#e5c07b").opacity(0.12))
                        .cornerRadius(4)
                }
                Text(item.headline)
                    .font(.system(size:10,weight:.semibold,design:.monospaced))
                    .foregroundColor(themeVM.accent)
            }
            Text(item.detail)
                .font(.system(size:10,design:.monospaced))
                .foregroundColor(Color(hex:"#8ab4cc"))
                .fixedSize(horizontal:false,vertical:true)
                .lineSpacing(2)
        }
        .padding(.top,4)
    }
}

struct IDEHelpItem {
    let gesture: String?
    let headline: String
    let detail: String
    init(_ headline: String, gesture: String? = nil, detail: String) {
        self.gesture = gesture; self.headline = headline; self.detail = detail
    }
}

struct IDEHelpSection {
    let title: String
    let icon: String
    let items: [IDEHelpItem]

    static let all: [IDEHelpSection] = [

        IDEHelpSection(title: "Navigation", icon: "map", items: [
            IDEHelpItem("Main Tabs", gesture: "Tap",
                detail: "Editor · Output · Terminal · Files · Maze · Docs · Help — tap any tab to switch panels."),
            IDEHelpItem("Side Drawer", gesture: "Tap avatar",
                detail: "Tap your avatar (top-left) to open the side drawer. Contains Projects, Repos, Settings, Profile, and About tabs."),
            IDEHelpItem("Close Drawer", gesture: "Tap ✕ or swipe",
                detail: "Tap the ✕ button or tap anywhere in the editor area to dismiss the drawer."),
            IDEHelpItem("Maze Panel", gesture: "Tap ❮ / ❯",
                detail: "Tap the arrow on the maze panel edge to collapse or expand it. The panel auto-widens when Lead Edge Cryptology is expanded."),
        ]),

        IDEHelpSection(title: "Projects & Files", icon: "folder.badge.plus", items: [
            IDEHelpItem("What is a Project", detail:
                "A project is a named container of files and folders for a specific language. Each project persists locally and can optionally sync to a GitHub repo."),
            IDEHelpItem("Create Project", gesture: "Local → + button",
                detail: "In the Projects drawer, tap the + button to open the New Project sheet. Choose a language (Ash, HTML, Python, C++, etc.), optionally name it, and tap Create. The project is set up with the correct template files for that language."),
            IDEHelpItem("Switch Projects", gesture: "Tap project row",
                detail: "Tap any project in the list to make it active. Its file tree loads below."),
            IDEHelpItem("Rename Project", gesture: "Swipe right on project row",
                detail: "Swipe a project row to the right to reveal the Rename button."),
            IDEHelpItem("Delete Project", gesture: "Swipe left on project row",
                detail: "Swipe a project row left to reveal the Delete button. This permanently removes the project and all its files."),
            IDEHelpItem("Open a File", gesture: "Tap file row",
                detail: "Tap any file in the project file tree to load it into the editor. The active file is highlighted in the project's language color."),
            IDEHelpItem("New File in Project", gesture: "Tap New File",
                detail: "Opens a language picker grid. Select the file type, type a filename (extension auto-appended), tap Create File. Starter code is inserted automatically."),
            IDEHelpItem("New Folder", gesture: "Tap New Folder",
                detail: "Creates a folder inside the active project for organizing files. Tap a folder row to expand/collapse it."),
            IDEHelpItem("Import File", gesture: "Tap Import File",
                detail: "Opens the iOS file picker. Select any file from your device — it's imported into the active project. Extension is auto-detected to set the language."),
            IDEHelpItem("Save to Device", gesture: "Tap Save to Device",
                detail: "Opens the iOS file picker so you can choose where to save the current file — iCloud Drive, Files app, AirDrop, etc."),
            IDEHelpItem("Restore Default Examples", gesture: "Local → Restore Default Projects",
                detail: "Restores all built-in example scripts to local storage without overwriting custom files."),
            IDEHelpItem("Repo Files tab", gesture: "Tap Repo Files",
                detail: "Browse files directly from your connected GitHub repositories. Tap a repo to see its file tree. Tap a file to load it in the editor. Tap images/videos to preview them inline."),
        ]),

        IDEHelpSection(title: "Language Environments", icon: "chevron.left.forwardslash.chevron.right", items: [
            IDEHelpItem("Supported Languages", detail:
                "Ash Edge Language (native) · HTML5 · CSS3 · JavaScript · TypeScript · Three.js · React/JSX · Vue.js · PHP · Python 3 · Python ML · SQL · Bash · Ruby · R · Swift · C++ · C · C# · Go · Rust · Kotlin · Java · Dart"),
            IDEHelpItem("Auto Language Detection", detail:
                "Opening any file automatically detects the language from its extension (.html → HTML, .py → Python, .cpp → C++, etc.) and updates the active environment. BUILD & RUN always double-checks the file extension before routing."),
            IDEHelpItem("Change Language", gesture: "New Project → pick language",
                detail: "Create a project with any language. The language color and icon update throughout the UI. The RUN button color matches the active language."),
            IDEHelpItem("Ash Edge Language", detail:
                "The native language — compiled by the LEATR v2 engine built into the app. 25 Orders of Operation, BRPN shells, Arc Edge GL output. No network needed."),
        ]),

        IDEHelpSection(title: "Building & Running Code", icon: "play.fill", items: [
            IDEHelpItem("BUILD & RUN", gesture: "Tap BUILD & RUN",
                detail: "Compiles and runs the current file using the correct engine for its language. Ash → LEATR compiler. HTML/JS/Python/Three.js/React/Vue → WKWebView. C++/Java/Go/Rust/Swift/C#/Kotlin/Ruby/Bash/R → Judge0 CE remote compiler (free, no account needed)."),
            IDEHelpItem("NET COMPILE", gesture: "Tap NET COMPILE",
                detail: "Same as BUILD & RUN but forces a network compilation pass. Use this for HTML files that reference external URLs, or for system languages (C++, Java, etc.) that need the remote compiler."),
            IDEHelpItem("HTML Output", detail:
                "HTML files render as a full live web page in the output panel. CSS and JS files referenced from within the project are automatically inlined — so a project with index.html + style.css + script.js renders the complete page with all styles and scripts applied."),
            IDEHelpItem("JavaScript / TypeScript", detail:
                "Runs in WKWebView. console.log() output is captured and displayed in a terminal-style output panel. Errors show with line numbers."),
            IDEHelpItem("Python", detail:
                "Runs via Pyodide (Python 3 compiled to WebAssembly). Loads from CDN on first run (~8MB). print() output displayed live. Standard library available. Install packages with micropip for ML projects."),
            IDEHelpItem("Three.js / React / Vue", detail:
                "CDN is injected automatically. Your Three.js scene, React component, or Vue component renders directly in the output panel — no build step needed."),
            IDEHelpItem("SQL", detail:
                "Runs via SQL.js (SQLite in WebAssembly). Query results displayed as a formatted table with row counts."),
            IDEHelpItem("C++ / Java / Go / Rust / Swift / C# / Kotlin / Ruby / Bash / R", detail:
                "Compiled and executed remotely via Judge0 CE (https://ce.judge0.com). Free public instance, no API key required. stdout appears in cyan, stderr in red, compile errors labeled separately. Execution time and memory shown in the header."),
            IDEHelpItem("Mobile / Desktop View Toggle", gesture: "📱 / 🖥 buttons in output header",
                detail: "When a web output is displayed, two buttons appear in the output header. 📱 Mobile injects width=device-width viewport (responsive). 🖥 Desktop injects width=1280px viewport to render the full desktop layout. Toggle between them to preview both."),
            IDEHelpItem("RUN button", gesture: "Tap ▶ RUN (top-right)",
                detail: "The global RUN button in the navigation bar does the same as BUILD & RUN — it auto-detects the file extension and routes to the correct execution engine."),
        ]),

        IDEHelpSection(title: "Editor", icon: "pencil", items: [
            IDEHelpItem("Write Code", gesture: "Tap editor area",
                detail: "Full syntax-highlighted editor. LEATR v2 color scheme: outer tags cyan, inner tags magenta, poly/net brackets green, keywords purple. Non-Ash syntax (HTML, Python, etc.) also highlighted by extension."),
            IDEHelpItem("AUTO LOAD ASH", gesture: "Tap AUTO LOAD ASH",
                detail: "Loads the arc_edge_vector.ash example into the editor — the full Arc Edge Vector GL script."),
            IDEHelpItem("CLEAR", gesture: "Tap CLEAR",
                detail: "Wipes the current editor content. Cannot be undone — save first if needed."),
        ]),

        IDEHelpSection(title: "Repository Browser", icon: "chevron.left.forwardslash.chevron.right", items: [
            IDEHelpItem("Browse Repos", gesture: "Drawer → Repos tab",
                detail: "Lists all your connected GitHub repositories. Tap a repo to browse its file tree."),
            IDEHelpItem("Repo Files Tab", gesture: "Projects → Repo Files",
                detail: "Alternative file browser embedded in the Projects panel. Tap a repo → navigate folders → tap files to open them in the editor."),
            IDEHelpItem("Back Navigation", gesture: "Tap ← Repos",
                detail: "In the Repo Files browser, tap the back button to return to the repo list from a file tree."),
            IDEHelpItem("File Preview", gesture: "Tap image/video/PDF",
                detail: "Tapping a PNG, JPG, GIF, WebP, SVG, PDF, MP4, or MOV in the repo browser opens an inline preview sheet. SVG and PDF render in WKWebView. Videos play with native controls."),
            IDEHelpItem("Sync Toggle", gesture: "Toggle ⇄ on a .ash file row",
                detail: "Turn on to auto-push every save of that file back to its GitHub path. The header shows how many files are syncing."),
            IDEHelpItem("Push Project to Repo", gesture: "Project file browser → </> button → Push",
                detail: "Open the repo sheet from the project file browser header. Create a new GitHub repo and push all project files, or link to an existing repo and push/pull."),
        ]),

        IDEHelpSection(title: "Terminal", icon: "terminal", items: [
            IDEHelpItem("Run a Command", gesture: "Type + Return or ⏎ button",
                detail: "Type any Ash terminal command (e.g. run NodeName) and hit Return or the ⏎ button. The terminal stays focused for chained commands."),
            IDEHelpItem("Dismiss Keyboard", gesture: "Tap Done",
                detail: "The Done button appears inline next to the input field when the keyboard is active."),
            IDEHelpItem("Clear Output", gesture: "Tap clear",
                detail: "Clears all terminal output and restores the startup banner."),
        ]),

        IDEHelpSection(title: "Accounts & Profile", icon: "person.circle", items: [
            IDEHelpItem("Sign In", detail:
                "From the welcome screen: Sign in with Apple (Face ID), Sign in with GitHub (browser device flow), or Continue as Guest."),
            IDEHelpItem("Switch Account", gesture: "Tap account row in Profile",
                detail: "Tap any account row in Profile → Connected Accounts to switch the active session. Never disconnects the other account."),
            IDEHelpItem("Disconnect Account", gesture: "Tap red ✕ on account row",
                detail: "Tap the glowing red ✕ to disconnect only that account. Other accounts stay connected."),
            IDEHelpItem("Edit App Username", gesture: "Profile → Account → Edit",
                detail: "Type a custom display name and tap Save. Stored to keychain, persists across sessions."),
            IDEHelpItem("Use Account Name Toggle", gesture: "Toggle 'Use name' per account",
                detail: "Each connected account row has a 'Use name' toggle. ON → uses that provider's username (GitHub @handle or Apple email prefix) as your display name."),
        ]),

        IDEHelpSection(title: "Maze & Cryptology", icon: "puzzlepiece.extension", items: [
            IDEHelpItem("Generate Maze", gesture: "Set size → Tap Generate",
                detail: "Choose Planar 2D or Cubic 3D, Reflective or Dither engine, set Width/Height/Depth (3–50), tap ▶ Generate."),
            IDEHelpItem("Orbit / Pan / Zoom", gesture: "1-finger / 2-finger / pinch",
                detail: "1-finger: orbit. 2-finger: pan. Pinch: zoom. Double-tap: reset view."),
            IDEHelpItem("Show Solution", gesture: "Tap Show Solution",
                detail: "Highlights the shortest path from entry (green) to exit (red) in magenta."),
            IDEHelpItem("Keyboard Dismiss", gesture: "Tap ⌨↓ in maze header",
                detail: "Dismisses the keyboard from the maze panel header without losing focus."),
            IDEHelpItem("Lead Edge Cryptology", gesture: "Tap ◈ LEAD EDGE CRYPTOLOGY",
                detail: "Expands full cryptology tools. Panel auto-widens. Type a message or attach files, configure maze layers and interchange dimensions, Generate Keys, then Encrypt → ZIP to download. Decrypt from ZIP with the private key."),
        ]),

        IDEHelpSection(title: "Arc Edge Vector GL", icon: "waveform.path", items: [
            IDEHelpItem("Run Arc Edge Script", gesture: "Load arc_edge_vector.ash → RUN",
                detail: "The GL output panel auto-detects ArcEdge nodes and launches the interactive 3D viewer."),
            IDEHelpItem("Controls Panel", gesture: "Tap < to show/hide",
                detail: "Axis on/off toggles, influence and phase sliders, physics environment (gravity, wind, temp, humidity, pressure), grid plane toggles."),
            IDEHelpItem("Orbit / Pan / Zoom", detail:
                "Same as maze: 1-finger orbit, 2-finger pan, pinch zoom, double-tap resets."),
            IDEHelpItem("Arc Edge Math", detail:
                "doc=3.0 replaces π. Circumference = sqrt(d×3)². Area = Circ². Volume = Area³. Sphere SA = Vol×0.25. Branch arc = Circ/8."),
        ]),

        IDEHelpSection(title: "Settings & About", icon: "gearshape", items: [
            IDEHelpItem("Change Theme", gesture: "Settings → Theme",
                detail: "9 themes: Stealth (default), Aurora, Ember, Forest, Glacier, Midnight, Neon, Obsidian, Solar."),
            IDEHelpItem("LEATR Compiler Info", gesture: "Settings → COMPILER section",
                detail: "Shows LEATR version, switch equation, all 25 Orders of Operation (Tools 1-7, Math/Physics 8-19, Senses 20-25), BRPN shells."),
            IDEHelpItem("App Version", gesture: "Drawer → About",
                detail: "Shows the current version, compiler, author (Justin Craig Venable), company (DART Meadow | Radical Deepscale LLC.), plus links to the website, GitHub source, and LEATR docs."),
        ]),
    ]
}
