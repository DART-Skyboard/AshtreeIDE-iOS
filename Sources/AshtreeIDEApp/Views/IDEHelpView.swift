// IDEHelpView.swift — Ash Tree IDE App Guide
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI

struct IDEHelpView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var expandedSection: String? = nil

    var body: some View {
        ZStack {
            // Faint logo splash background
            VStack {
                IDELogoMark(size: 200, accent: themeVM.accent).opacity(0.04)
                Text("ASH TREE IDE").font(.system(size:24,weight:.bold,design:.rounded))
                    .foregroundColor(themeVM.accent.opacity(0.03)).kerning(6)
            }
            .frame(maxWidth:.infinity,maxHeight:.infinity)

            ScrollView {
                VStack(alignment:.leading,spacing:16) {

                    // Header
                    VStack(alignment:.leading,spacing:4) {
                        Text("◈ APP GUIDE")
                            .font(.system(size:9,weight:.semibold,design:.monospaced))
                            .foregroundColor(themeVM.dim).kerning(2)
                        Text("Ash Tree IDE")
                            .font(.system(size:22,weight:.bold,design:.rounded))
                            .foregroundColor(themeVM.text)
                        Text("LEATR v2 · Lead Edge Ash Tree Reflex")
                            .font(.system(size:10,design:.monospaced))
                            .foregroundColor(themeVM.dim)
                    }
                    .padding(.bottom,4)

                    // Sections
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

// MARK: - Help Section Card

struct HelpSectionCard: View {
    let section: IDEHelpSection
    let isExpanded: Bool
    let onTap: () -> Void
    @EnvironmentObject var themeVM: IDEThemeViewModel

    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            // Header row — always visible
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

            // Expanded content
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

// MARK: - Help Content Model

struct IDEHelpItem {
    let gesture: String?
    let headline: String
    let detail: String
    init(_ headline: String, detail: String, gesture: String? = nil) {
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
                detail: "Editor · Output · Terminal · Files · Maze · Docs · Help — tap any tab in the top bar to switch panels."),
            IDEHelpItem("Side Drawer", gesture: "Tap ☰ avatar",
                detail: "Tap your avatar (top-left) to open the side drawer. Contains Projects, Repos, Settings, Profile, and About tabs."),
            IDEHelpItem("Close Drawer", gesture: "Tap ✕ or swipe",
                detail: "Tap the ✕ button at the top of the drawer, or tap the editor area to dismiss it."),
            IDEHelpItem("Maze Panel", gesture: "Tap ❮ / ❯",
                detail: "The maze controls panel can be collapsed or expanded using the arrow button on its edge. The panel widens automatically when Lead Edge Cryptology is expanded."),
        ]),

        IDEHelpSection(title: "Editor & Running Scripts", icon: "chevron.left.forwardslash.chevron.right", items: [
            IDEHelpItem("Write Code", gesture: "Tap editor",
                detail: "Tap the Editor tab to write Ash Edge Language scripts. Syntax is highlighted in real-time using the LEATR v2 color scheme."),
            IDEHelpItem("Run / Build", gesture: "Tap ▶ RUN",
                detail: "Tap the cyan RUN button (top-right) to compile and run the current script. Output appears in the Output tab."),
            IDEHelpItem("Build & Run", gesture: "BUILD & RUN button",
                detail: "In the Editor toolbar, BUILD & RUN compiles, NET COMPILE runs the network layer, AUTO LOAD ASH loads from examples, and CLEAR wipes the editor."),
            IDEHelpItem("GL Output", gesture: "▸ Render 3D",
                detail: "Scripts with import (GLDrivers) or Arc Edge nodes auto-render in the GL OUTPUT panel below the compiler output. Tap ▸ Render 3D to manually re-trigger. Tap ↺ Reset to clear and re-render."),
            IDEHelpItem("Auto-save", detail:
                "Your script is saved to device storage automatically whenever you tap Save to Device. Files also persist across app restarts."),
        ]),

        IDEHelpSection(title: "Terminal", icon: "terminal", items: [
            IDEHelpItem("Open Terminal", gesture: "Tap Terminal tab",
                detail: "The LEATR App Runtime terminal shows compile output, node execution results, and accepts live commands."),
            IDEHelpItem("Run a Command", gesture: "Type + Return or ⏎",
                detail: "Type any Ash terminal command (e.g. run NodeName) and hit Return or the ⏎ button to execute. The terminal stays focused so you can chain multiple commands."),
            IDEHelpItem("Dismiss Keyboard", gesture: "Tap Done",
                detail: "The Done button appears inline next to the input field when the keyboard is active. Tap it to dismiss without losing your typed command."),
            IDEHelpItem("Clear Output", gesture: "Tap clear",
                detail: "Tap the 'clear' button (top-right of terminal header) to wipe all terminal output and start fresh."),
        ]),

        IDEHelpSection(title: "Projects & Files", icon: "folder.badge.plus", items: [
            IDEHelpItem("Switch Source", gesture: "Tap Examples / Repository / Local",
                detail: "The segmented control at the top of the Projects drawer switches between built-in examples, your GitHub repository files, and locally saved device files."),
            IDEHelpItem("Open a File", gesture: "Tap file row",
                detail: "Tap any file in the list to load it into the editor. The active file is highlighted in cyan with a filled icon and dot indicator."),
            IDEHelpItem("New File", gesture: "Tap New Local File",
                detail: "Creates a new untitled.ash file with a unique auto-incremented name and immediately saves it to device storage."),
            IDEHelpItem("Delete File", gesture: "Swipe left → Delete",
                detail: "Swipe any local file row to the left to reveal the red Delete button. Tap it to permanently remove the file from device storage."),
            IDEHelpItem("Rename File", gesture: "Swipe right → Rename",
                detail: "Swipe any local file row to the right to reveal the cyan Rename button. Tap it to enter inline rename mode — type the new name and tap Save or hit Return. .ash is auto-appended."),
            IDEHelpItem("Multi-Select", gesture: "Long-press a file",
                detail: "Press and hold any file row to enter multi-select mode. Checkboxes appear on every row. Tap files to check/uncheck them. A Select All checkbox appears at the top."),
            IDEHelpItem("Export Selected", gesture: "Multi-select → ↑ Export",
                detail: "In multi-select mode, tap the export icon to choose: Export as ZIP (saves all selected files as a single zip), Export Individually (file picker), or Delete Selected."),
            IDEHelpItem("Save to Device", gesture: "Tap Save to Device",
                detail: "Opens the iOS file picker so you can choose exactly where to save the current file — iCloud Drive, Files app, or any connected location."),
            IDEHelpItem("Restore Defaults", gesture: "Tap Restore Default Projects",
                detail: "Restores all built-in example scripts (hello_world, arc_edge_vector, neural_scene, etc.) to local device storage without overwriting custom files."),
        ]),

        IDEHelpSection(title: "Repository Browser", icon: "chevron.left.forwardslash.chevron.right", items: [
            IDEHelpItem("Load Repos", gesture: "Tap Repository tab → Repos drawer",
                detail: "Your connected GitHub repositories appear in the Repos drawer tab. Tap Refresh to reconnect if the list doesn't load."),
            IDEHelpItem("Browse Files", gesture: "Tap repo → tap folder/file",
                detail: "Tap a repository to browse its file tree. Tap a folder to expand it, tap a .ash file to load it into the editor."),
            IDEHelpItem("Sync to Repo", gesture: "Toggle ⇄ on a file row",
                detail: "Each .ash file in the repo browser has a sync toggle on the right. Turn it ON to auto-push every save back to that file in your GitHub repo. Turn it OFF to work locally only. The header shows how many files are currently syncing."),
            IDEHelpItem("Refresh", gesture: "Tap Refresh button",
                detail: "If the repository list loses connection, tap the Refresh button in the Repos drawer header to reconnect without restarting the app."),
        ]),

        IDEHelpSection(title: "Accounts & Profile", icon: "person.circle", items: [
            IDEHelpItem("Sign In", detail:
                "From the welcome screen: tap Sign in with Apple (Face ID), Sign in with GitHub (opens browser for device auth), or Continue as Guest. GitHub auto re-authorizes if you've previously connected."),
            IDEHelpItem("Switch Account", gesture: "Tap account row in Profile",
                detail: "In the Profile drawer tab, tap any account row to switch it to the active session. The cyan checkmark shows which account is currently active. Switching never disconnects the other account."),
            IDEHelpItem("Disconnect Account", gesture: "Tap red ✕ on account row",
                detail: "Tap the glowing red ✕ circle on any account row to disconnect only that account. Other connected accounts remain active. If no accounts remain, you're returned to the sign-in screen."),
            IDEHelpItem("Add Another Account", gesture: "ADD ACCOUNT section",
                detail: "In the Profile tab, the ADD ACCOUNT section shows Connect GitHub or Connect Apple ID if that provider isn't connected yet. You can be signed into both simultaneously."),
            IDEHelpItem("Edit Username", gesture: "Tap Edit in Profile",
                detail: "In the Profile tab Account section, tap Edit next to App Username to type a custom display name. Tap Save to store it. This appears next to your avatar in the drawer header."),
            IDEHelpItem("Use Account Name", gesture: "Toggle 'Use name' per account",
                detail: "Each connected account row has a small 'Use name' toggle. Turn it ON to display that account's username (e.g. @dartsolarpunk from GitHub, or email prefix from Apple) as the app username instead of your custom name."),
            IDEHelpItem("Sign Out All", gesture: "Sign Out All button",
                detail: "Scrolling to the bottom of the Profile tab shows Sign Out All — this clears all connected accounts and returns to the welcome screen."),
        ]),

        IDEHelpSection(title: "Maze & Cryptology", icon: "puzzlepiece.extension", items: [
            IDEHelpItem("Generate Maze", gesture: "Set size → Tap Generate",
                detail: "Choose Planar (2D) or Cubic (3D) mode, select the Reflective or Dither engine, set Width/Height/Depth with sliders (3–50), then tap ▶ Generate. The maze renders in the right panel."),
            IDEHelpItem("Show Solution", gesture: "Tap Show Solution",
                detail: "After generating, tap Show Solution to highlight the shortest path from entry (green dot) to exit (red dot) in magenta."),
            IDEHelpItem("Orbit / Pan / Zoom", gesture: "1-finger / 2-finger / pinch",
                detail: "1-finger drag: orbit the 3D maze. 2-finger drag: pan the camera. Pinch: zoom in and out. Double-tap: reset the camera to the default view."),
            IDEHelpItem("Reset View", gesture: "Tap Reset View",
                detail: "Returns the 3D camera to the default isometric angle and zoom level."),
            IDEHelpItem("Dismiss Keyboard", gesture: "Tap ⌨↓ in header",
                detail: "The keyboard dismiss button appears in the maze panel header (between the traffic lights and the ❮ button). Tap it anytime the keyboard is covering the controls."),
            IDEHelpItem("Lead Edge Cryptology", gesture: "Tap ◈ LEAD EDGE CRYPTOLOGY",
                detail: "Expands the full cryptology section below the maze controls. The panel automatically widens to fit. Collapse it to return to normal width."),
            IDEHelpItem("Encrypt Files", gesture: "Select Files → Generate Keys → Encrypt → ZIP",
                detail: "Type an optional message, attach files (any type), configure maze key layers and interchange dimensions, tap Generate Keys, then Encrypt → ZIP. Share the encrypted ZIP via the download button."),
            IDEHelpItem("Decrypt", gesture: "▼ DECRYPT FROM ZIP section",
                detail: "Expand the decrypt section, load an encrypted ZIP, paste the private key, tap Decrypt. Download the decrypted ZIP with your original content restored."),
        ]),

        IDEHelpSection(title: "Settings & Appearance", icon: "gearshape", items: [
            IDEHelpItem("Change Theme", gesture: "Settings → Theme picker",
                detail: "9 themes available: Stealth (dark default), Aurora, Ember, Forest, Glacier, Midnight, Neon, Obsidian, Solar. Changes take effect instantly across the whole app."),
            IDEHelpItem("Compiler Info", gesture: "Settings → COMPILER section",
                detail: "Shows LEATR version, switch equation, all 25 Orders of Operation (Tools 1-7, Math/Physics 8-19, Senses 20-25), BRPN shells, and maze engine info."),
            IDEHelpItem("App Version", gesture: "About → Version",
                detail: "The About tab in the drawer shows the current app version, compiler, author, and company info, plus links to Radical Deepscale, DART Meadow, GitHub source, and LEATR docs."),
        ]),

        IDEHelpSection(title: "Arc Edge Vector GL", icon: "waveform.path", items: [
            IDEHelpItem("What it is", detail:
                "Arc Edge Vector is a 3D spline system using arc-edge math (doc=3.0 replaces π). Three axes (X/Y/Z) produce quadratic Bézier curves meeting at a shared Sigma Meridian point."),
            IDEHelpItem("Run Arc Edge Script", gesture: "Load arc_edge_vector.ash → RUN",
                detail: "Open the arc_edge_vector.ash example from Projects, hit RUN — the GL Output panel auto-detects the ArcEdge nodes and launches the interactive 3D viewer."),
            IDEHelpItem("Controls Panel", gesture: "Tap < to show/hide",
                detail: "The left panel has axis on/off toggles, influence and phase sliders per axis, physics environment (gravity, wind, temp, humidity, pressure), and grid plane toggles."),
            IDEHelpItem("Orbit / Pan / Zoom", gesture: "1-finger / 2-finger / pinch",
                detail: "Same controls as the maze: 1-finger orbit, 2-finger pan, pinch zoom, double-tap resets to default angle."),
            IDEHelpItem("Arc Edge Math", detail:
                "Circumference = sqrt(d×3)². Area = Circ². Volume = Area³. Sphere SA = Vol×0.25. Branch arc = Circ/8. All formulas use doc=3.0 (Justin Craig Venable)."),
        ]),
    ]
}
