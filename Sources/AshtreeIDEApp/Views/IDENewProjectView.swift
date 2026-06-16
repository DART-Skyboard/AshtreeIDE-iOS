// IDENewProjectView.swift
// New Project language picker sheet
// © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI

struct IDENewProjectSheet: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var langStore: IDELanguageStore
    @Binding var isPresented: Bool

    @State private var selectedEnv: IDELanguageEnv = IDELanguageEnv.find(id: "ash")
    @State private var projectName = ""
    @State private var showDropdown = false
    @FocusState private var nameFocused: Bool

    // Quick-access featured languages (big buttons at top)
    private let featured = ["ash","python","html","javascript","threejs","react"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0d1117").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── Header ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 4) {
                            Text("◈ NEW PROJECT")
                                .font(.system(size:9,weight:.semibold,design:.monospaced))
                                .foregroundColor(Color(hex:"#4a5568")).kerning(2)
                            Text("Choose a language environment")
                                .font(.system(size:14,weight:.semibold))
                                .foregroundColor(Color(hex:"#c9d1d9"))
                            Text("All environments use Ash Edge Language syntax with native library wrappers.")
                                .font(.system(size:10,design:.monospaced))
                                .foregroundColor(Color(hex:"#4a5568"))
                                .fixedSize(horizontal:false,vertical:true)
                        }

                        // ── Featured language buttons ────────────────
                        Text("FEATURED")
                            .font(.system(size:8,weight:.semibold,design:.monospaced))
                            .foregroundColor(Color(hex:"#4a5568")).kerning(1.5)

                        LazyVGrid(columns: [
                            GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(IDELanguageEnv.all.filter { featured.contains($0.id) }, id:\.id) { env in
                                LanguageEnvButton(env: env, isSelected: selectedEnv.id == env.id) {
                                    selectedEnv = env
                                    showDropdown = false
                                }
                            }
                        }

                        // ── More languages dropdown ──────────────────
                        Text("ALL ENVIRONMENTS")
                            .font(.system(size:8,weight:.semibold,design:.monospaced))
                            .foregroundColor(Color(hex:"#4a5568")).kerning(1.5)

                        ForEach(IDELanguageEnv.Category.allCases, id:\.rawValue) { cat in
                            let envs = IDELanguageEnv.all.filter { $0.category == cat && !featured.contains($0.id) }
                            if !envs.isEmpty {
                                VStack(alignment:.leading,spacing:6) {
                                    Text(cat.rawValue.uppercased())
                                        .font(.system(size:7,weight:.semibold,design:.monospaced))
                                        .foregroundColor(Color(hex:"#4a5568")).kerning(1)
                                    ForEach(envs, id:\.id) { env in
                                        Button {
                                            selectedEnv = env
                                        } label: {
                                            HStack(spacing:10) {
                                                Image(systemName: env.icon)
                                                    .font(.system(size:13))
                                                    .foregroundColor(Color(hex:env.color))
                                                    .frame(width:20)
                                                Text(env.name)
                                                    .font(.system(size:12))
                                                    .foregroundColor(Color(hex:"#c9d1d9"))
                                                Text(env.ext)
                                                    .font(.system(size:9,design:.monospaced))
                                                    .foregroundColor(Color(hex:"#4a5568"))
                                                Spacer()
                                                if selectedEnv.id == env.id {
                                                    Image(systemName:"checkmark.circle.fill")
                                                        .foregroundColor(Color(hex:env.color))
                                                }
                                            }
                                            .padding(.horizontal,12).padding(.vertical,8)
                                            .background(selectedEnv.id == env.id
                                                ? Color(hex:env.color).opacity(0.08)
                                                : Color(hex:"#161b22"))
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius:8)
                                                .stroke(selectedEnv.id == env.id
                                                    ? Color(hex:env.color).opacity(0.4)
                                                    : Color(hex:"#21262d"), lineWidth:0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // ── Project name ─────────────────────────────
                        VStack(alignment:.leading,spacing:6) {
                            Text("PROJECT NAME (optional)")
                                .font(.system(size:8,weight:.semibold,design:.monospaced))
                                .foregroundColor(Color(hex:"#4a5568")).kerning(1.5)
                            HStack {
                                Image(systemName: selectedEnv.icon)
                                    .foregroundColor(Color(hex:selectedEnv.color))
                                TextField(
                                    "my_project (auto-named if blank)",
                                    text: $projectName
                                )
                                .font(.system(size:12,design:.monospaced))
                                .foregroundColor(Color(hex:"#c9d1d9"))
                                .focused($nameFocused)
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                                Text(selectedEnv.ext)
                                    .font(.system(size:10,design:.monospaced))
                                    .foregroundColor(Color(hex:"#4a5568"))
                            }
                            .padding(10)
                            .background(Color(hex:"#161b22"))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius:8)
                                .stroke(Color(hex:selectedEnv.color).opacity(0.3),lineWidth:0.5))
                        }

                        // ── Create button ─────────────────────────────
                        Button {
                            createProject()
                        } label: {
                            HStack(spacing:10) {
                                Image(systemName:"plus.square.fill")
                                    .font(.system(size:16))
                                Text("Create \(selectedEnv.name) Project")
                                    .font(.system(size:13,weight:.semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth:.infinity)
                            .padding(.vertical,14)
                            .background(Color(hex:selectedEnv.color))
                            .cornerRadius(12)
                        }
                        .shadow(color:Color(hex:selectedEnv.color).opacity(0.4),radius:10,x:0,y:4)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(Color(hex:"#4a5568"))
                }
            }
        }
    }

    private func createProject() {
        // Build filename
        let base: String
        if !projectName.trimmingCharacters(in:.whitespaces).isEmpty {
            base = projectName.trimmingCharacters(in:.whitespaces)
                .replacingOccurrences(of:" ", with:"_")
                .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        } else {
            base = selectedEnv.id == "ash" ? "untitled" : selectedEnv.id + "_project"
        }

        // Ensure unique filename
        var fname = base + selectedEnv.ext
        var n = 1
        let ud = UserDefaults.standard
        while ideVM.localFiles.contains(fname) || ud.string(forKey:"ide_local_\(fname)") != nil {
            fname = "\(base)_\(n)\(selectedEnv.ext)"; n += 1
        }

        // Set the active language environment in the store
        langStore.setEnv(selectedEnv)

        // Load template into editor
        ideVM.sourceCode  = selectedEnv.templateCode
        ideVM.currentFile = fname
        ideVM.isDirty     = false

        // Persist immediately
        ud.set(selectedEnv.templateCode, forKey:"ide_local_\(fname)")
        if !ideVM.localFiles.contains(fname) { ideVM.localFiles.append(fname) }
        ud.set(ideVM.localFiles, forKey:"ide_local_file_list")
        ud.synchronize()
        ideVM.loadLocalFiles()

        isPresented = false
    }
}

// MARK: - Language Button Component

struct LanguageEnvButton: View {
    let env: IDELanguageEnv
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing:6) {
                ZStack {
                    RoundedRectangle(cornerRadius:10)
                        .fill(isSelected
                            ? Color(hex:env.color).opacity(0.18)
                            : Color(hex:"#161b22"))
                        .frame(height:56)
                        .overlay(
                            RoundedRectangle(cornerRadius:10)
                                .stroke(isSelected
                                    ? Color(hex:env.color)
                                    : Color(hex:"#21262d"),
                                    lineWidth: isSelected ? 1.5 : 0.5)
                        )
                        .shadow(color: isSelected
                            ? Color(hex:env.color).opacity(0.35) : .clear,
                            radius:8,x:0,y:0)
                    VStack(spacing:3) {
                        Image(systemName:env.icon)
                            .font(.system(size:18))
                            .foregroundColor(Color(hex:env.color))
                        Text(env.ext)
                            .font(.system(size:8,weight:.bold,design:.monospaced))
                            .foregroundColor(Color(hex:env.color).opacity(0.7))
                    }
                }
                Text(env.name)
                    .font(.system(size:8,weight: isSelected ? .semibold : .regular,design:.monospaced))
                    .foregroundColor(isSelected ? Color(hex:env.color) : Color(hex:"#8ab4cc"))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Environment Status Bar Item

struct IDELangEnvBadge: View {
    @EnvironmentObject var langStore: IDELanguageStore

    var body: some View {
        HStack(spacing:4) {
            Image(systemName: langStore.activeEnv.icon)
                .font(.system(size:9))
            Text(langStore.activeEnv.id.uppercased())
                .font(.system(size:8,weight:.semibold,design:.monospaced))
        }
        .foregroundColor(Color(hex:langStore.activeEnv.color))
        .padding(.horizontal,7).padding(.vertical,3)
        .background(Color(hex:langStore.activeEnv.color).opacity(0.1))
        .cornerRadius(5)
        .overlay(RoundedRectangle(cornerRadius:5)
            .stroke(Color(hex:langStore.activeEnv.color).opacity(0.3),lineWidth:0.5))
    }
}
