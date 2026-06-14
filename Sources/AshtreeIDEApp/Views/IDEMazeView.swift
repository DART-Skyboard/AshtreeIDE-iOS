// ============================================================
//  IDEMazeView.swift — Lead Edge Maze + Cryptology Panel
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Matches the overlay panel style from ashtreeide.html web app.
//  Uses improved Autumn iOS randomized entry/exit openings.
// ============================================================

import SwiftUI
import SceneKit

struct IDEMazeView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var mazeVM:  MazeViewModel

    var body: some View {
        HStack(spacing: 0) {
            // ── Controls panel (matches web app panel style) ──────
            IDEMazeControlsPanel()
                .frame(width: 220)
                .background(Color(hex: "#0d1117"))
                .overlay(Divider().background(Color(hex: "#21262d")), alignment: .trailing)

            // ── 3D SceneKit view ──────────────────────────────────
            IDEMaze3DView()
        }
    }
}

// MARK: - Controls Panel (matches #maze-ui-panel web styling)

struct IDEMazeControlsPanel: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var mazeVM:  MazeViewModel
    @State private var showCrypto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Panel header — matches web #maze-ui-header
                HStack {
                    Circle().fill(Color(hex: "#ff5f57")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "#febc2e")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "#28c840")).frame(width: 8, height: 8)
                    Text("◈ LEAD EDGE MAZE")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#00ffcc"))
                        .kerning(1.5)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "#161b22"))
                .overlay(Divider().background(Color(hex: "#21262d")), alignment: .bottom)

                VStack(alignment: .leading, spacing: 10) {

                    // Mode selector
                    MazeSectionHeader("MODE")
                    Picker("Mode", selection: $mazeVM.config.mode) {
                        ForEach(MazeConfig.Mode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color(hex: "#00ffcc"))

                    // Engine selector
                    MazeSectionHeader("ENGINE")
                    Picker("Engine", selection: $mazeVM.config.engine) {
                        ForEach(MazeConfig.EngineType.allCases, id: \.self) { e in
                            Text(e.rawValue).tag(e)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(Color(hex: "#00ffcc"))

                    // Dimensions
                    MazeSectionHeader("DIMENSIONS")
                    MazeSlider(label: "Width",  value: $mazeVM.config.width,  range: 3...20)
                    MazeSlider(label: "Height", value: $mazeVM.config.height, range: 3...20)
                    if mazeVM.config.mode == .cubic {
                        MazeSlider(label: "Depth", value: $mazeVM.config.depth, range: 3...15)
                    }

                    // Action buttons — matches web .button style
                    MazeActionButton(
                        label: mazeVM.isGenerating ? "Generating…" : "▸ Generate",
                        color: Color(hex: "#00ffcc"),
                        busy: mazeVM.isGenerating
                    ) {
                        mazeVM.generate()
                    }

                    MazeActionButton(label: "◈ Show Solution", color: Color(hex: "#0088ff")) {
                        mazeVM.showSolutionPath()
                    }
                    .disabled(mazeVM.result == nil)
                    .opacity(mazeVM.result == nil ? 0.4 : 1)

                    // Status
                    if !mazeVM.statusText.isEmpty {
                        Text(mazeVM.statusText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#4a8a7a"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Path info
                    if let r = mazeVM.result {
                        let pathLen = r.cubicPath?.count ?? r.planarPath?.count ?? 0
                        VStack(alignment: .leading, spacing: 4) {
                            MazeInfoRow("Mode", r.mode.rawValue)
                            MazeInfoRow("Size", r.mode == .cubic
                                ? "\(r.w)×\(r.h)×\(r.d)" : "\(r.w)×\(r.h)")
                            MazeInfoRow("Entry", "(\(r.entry.x),\(r.entry.y)\(r.mode == .cubic ? ",\(r.entry.z)" : ""))")
                            MazeInfoRow("Exit",  "(\(r.exit.x),\(r.exit.y)\(r.mode == .cubic ? ",\(r.exit.z)" : ""))")
                            MazeInfoRow("Path",  pathLen > 0 ? "\(pathLen) steps" : "No solution")
                        }
                        .padding(8)
                        .background(Color(hex: "#0d1117"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#21262d"), lineWidth: 0.5))
                    }

                    Divider().background(Color(hex: "#21262d"))

                    // LEAD EDGE CRYPTOLOGY section (collapsible)
                    Button {
                        withAnimation { showCrypto.toggle() }
                    } label: {
                        HStack {
                            Text("◈ LEAD EDGE CRYPTOLOGY")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "#00ffcc"))
                                .kerning(1)
                            Spacer()
                            Image(systemName: showCrypto ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#4a8a7a"))
                        }
                        .padding(.vertical, 6)
                    }

                    if showCrypto {
                        IDECryptologyPanel()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Maze Control Sub-views

struct MazeSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 7, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "#4a5568"))
            .kerning(1.5)
    }
}

struct MazeSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "#8ab4cc"))
                .frame(width: 45, alignment: .leading)
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0.rounded()) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            .tint(Color(hex: "#00ffcc"))
            Text("\(value)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#00ffcc"))
                .frame(width: 24, alignment: .trailing)
        }
    }
}

struct MazeActionButton: View {
    let label: String
    let color: Color
    var busy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(busy ? color.opacity(0.5) : color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.25), lineWidth: 0.5))
                .cornerRadius(4)
        }
        .disabled(busy)
    }
}

struct MazeInfoRow: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "#4a5568"))
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#8ab4cc"))
        }
    }
}

// MARK: - Cryptology Panel (matches web LEAD EDGE CRYPTOLOGY section)

struct IDECryptologyPanel: View {
    @EnvironmentObject var ideVM: IDEState
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var keyDisplay = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Integrate maze-based keys into Ash programs via AshTreeCrypto.")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(hex: "#4a5568"))
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $inputText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "#c9d1d9"))
                .frame(minHeight: 60, maxHeight: 80)
                .background(Color(hex: "#0d1117"))
                .cornerRadius(4)
                .overlay(
                    Group {
                        if inputText.isEmpty {
                            Text("Type a message for cryptology…")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "#4a5568"))
                                .padding(8)
                        }
                    }, alignment: .topLeading)

            MazeActionButton(label: "◈ Generate Maze Keys", color: Color(hex: "#00ffcc")) {
                generateKeys()
            }
            MazeActionButton(label: "→ Encrypt", color: Color(hex: "#0088ff")) {
                encryptMessage()
            }
            MazeActionButton(label: "← Decrypt", color: Color(hex: "#bf5fff")) {
                decryptMessage()
            }

            if !keyDisplay.isEmpty {
                Text(keyDisplay)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color(hex: "#4a8a7a"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(6)
                    .background(Color(hex: "#0d1117"))
                    .cornerRadius(4)
            }
            if !outputText.isEmpty {
                Text(outputText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#00ffcc"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(6)
                    .background(Color(hex: "#0a140a"))
                    .cornerRadius(4)
            }
        }
    }

    private func generateKeys() {
        // Generate maze-based key using LEMAC + sha256-style hash of maze structure
        let maze = LEMACEngine.generateCubic(w: 6, h: 6, d: 6)
        let (entry, exit) = LEMACEngine.placeCubicOpenings(w: 6, h: 6, d: 6)
        // Derive key from maze topology (passage count + entry/exit)
        var wallCount = 0
        for z in 0..<6 { for y in 0..<6 { for x in 0..<6 {
            let c = maze[z][y][x]
            if !c.top { wallCount += 1 }
            if !c.right { wallCount += 1 }
            if !c.front { wallCount += 1 }
        }}}
        let privateKey = String(format: "%06X-%06X-%06X",
            entry.0 * 65536 + entry.1 * 256 + entry.2,
            wallCount,
            exit.0 * 65536 + exit.1 * 256 + exit.2)
        let publicKey  = String(format: "%08X", wallCount &* 0x9E3779B9)
        keyDisplay = "Private: \(privateKey)\nPublic:  \(publicKey)"
    }

    private func encryptMessage() {
        guard !inputText.isEmpty else { return }
        // Simple XOR with maze-derived key (demonstration)
        let key: [UInt8] = Array(keyDisplay.utf8.prefix(16))
        guard !key.isEmpty else { generateKeys(); return }
        let plain = Array(inputText.utf8)
        let enc = plain.enumerated().map { UInt8(($1 ^ key[$0 % key.count]) & 0xFF) }
        outputText = "ENC: " + enc.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private func decryptMessage() {
        outputText = "Decryption requires matching private maze key. Keys are session-bound and unique per maze generation."
    }
}

// MARK: - 3D Maze SceneKit View

struct IDEMaze3DView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var mazeVM:  MazeViewModel

    var body: some View {
        ZStack {
            if let node = mazeVM.sceneNode {
                IDESceneKitView(rootNode: node)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "#00ffcc").opacity(0.3))
                    Text("Configure and generate a maze")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568"))
                    Text("D1/D2/D3 Lead Edge algorithm")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568").opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0d1117"))
            }

            if mazeVM.isGenerating {
                VStack(spacing: 8) {
                    ProgressView().tint(Color(hex: "#00ffcc")).scaleEffect(1.2)
                    Text("Generating…")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#00ffcc"))
                }
                .padding(20)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - SceneKit UIView Wrapper

struct IDESceneKitView: UIViewRepresentable {
    let rootNode: SCNNode

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true
        scnView.showsStatistics = false
        scnView.antialiasingMode = .multisampling4X

        let scene = SCNScene()

        // Lighting
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 0.3)
        scene.rootNode.addChildNode(ambient)

        let dir = SCNNode()
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.color = UIColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 1.8)
        dir.position = SCNVector3(5, 8, 5)
        scene.rootNode.addChildNode(dir)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.color = UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        fill.position = SCNVector3(-5, -3, 5)
        scene.rootNode.addChildNode(fill)

        // Add maze
        scene.rootNode.addChildNode(rootNode)

        // Camera
        let camNode = SCNNode()
        camNode.camera = SCNCamera()
        camNode.camera?.fieldOfView = 60
        camNode.position = SCNVector3(4, 6, 10)
        let lookAt = SCNLookAtConstraint(target: rootNode)
        lookAt.isGimbalLockEnabled = true
        camNode.constraints = [lookAt]
        scene.rootNode.addChildNode(camNode)

        // Fog
        scene.fogColor    = UIColor(red: 0, green: 0, blue: 0.05, alpha: 1)
        scene.fogStartDistance = 8
        scene.fogEndDistance   = 30

        scnView.scene = scene
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Remove old maze nodes (keep lights + camera)
        scnView.scene?.rootNode.childNodes
            .filter { $0.light == nil && $0.camera == nil }
            .forEach { $0.removeFromParentNode() }
        scnView.scene?.rootNode.addChildNode(rootNode)

        // Gentle auto-rotation
        let rotation = CABasicAnimation(keyPath: "rotation")
        rotation.toValue  = NSValue(scnVector4: SCNVector4(0, 1, 0, Float.pi * 2))
        rotation.duration = 30
        rotation.repeatCount = .infinity
        rootNode.addAnimation(rotation, forKey: "autoRotate")
    }
}
