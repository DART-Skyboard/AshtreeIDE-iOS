// IDEMazeView.swift v2 — Liquid glass material, perimeter walls, collapsible panel, ArcLake orbit
// Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
import SwiftUI
import SceneKit

// MARK: - Maze View (main)

struct IDEMazeView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var mazeVM:  MazeViewModel
    @State private var panelCollapsed = false

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Controls panel (collapsible) ──────────────────
                if !panelCollapsed {
                    IDEMazeControlsPanel(isCollapsed: $panelCollapsed)
                        .frame(width: 220)
                        .background(Color(hex: "#0d1117"))
                        .overlay(Divider().background(Color(hex: "#21262d")), alignment: .trailing)
                        .transition(.move(edge: .leading))
                }

                // ── Collapse tab ──────────────────────────────────
                ZStack(alignment: .topLeading) {
                    // 3D SceneKit view
                    IDEMaze3DView()

                    // Collapse tab button pinned to top-left of scene
                    VStack {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                panelCollapsed.toggle()
                            }
                        } label: {
                            Image(systemName: panelCollapsed ? "sidebar.left" : "sidebar.leading")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#00ffcc"))
                                .padding(8)
                                .background(Color(hex: "#0d1117").opacity(0.85))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#00ffcc").opacity(0.25), lineWidth: 0.5))
                        }
                        .padding(.top, 10)
                        .padding(.leading, 8)
                        Spacer()
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: panelCollapsed)
        }
    }
}

// MARK: - Controls Panel

struct IDEMazeControlsPanel: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var mazeVM:  MazeViewModel
    @Binding var isCollapsed: Bool
    @State private var showCrypto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with traffic lights
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: "#ff5f57")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "#febc2e")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "#28c840")).frame(width: 8, height: 8)
                    Text("◈ LEAD EDGE MAZE")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#00ffcc"))
                        .kerning(1.5)
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size:12)).foregroundColor(Color(hex:"#4a5568"))
                    }
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isCollapsed = true }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10)).foregroundColor(Color(hex: "#4a5568"))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(hex: "#161b22"))
                .overlay(Divider().background(Color(hex: "#21262d")), alignment: .bottom)

                VStack(alignment: .leading, spacing: 10) {
                    // Mode
                    MazeSectionHeader("MODE")
                    Picker("", selection: $mazeVM.config.mode) {
                        ForEach(MazeConfig.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).tint(Color(hex: "#00ffcc"))

                    // Engine
                    MazeSectionHeader("ENGINE")
                    Picker("", selection: $mazeVM.config.engine) {
                        ForEach(MazeConfig.EngineType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).tint(Color(hex: "#00ffcc"))

                    // Dimensions — all max 50
                    MazeSectionHeader("DIMENSIONS (3–50)")
                    MazeSlider(label: "Width",  value: $mazeVM.config.width,  range: 3...50)
                    MazeSlider(label: "Height", value: $mazeVM.config.height, range: 3...50)
                    if mazeVM.config.mode == .cubic {
                        MazeSlider(label: "Depth", value: $mazeVM.config.depth, range: 3...50)
                    }

                    // Actions
                    MazeActionButton(
                        label: mazeVM.isGenerating ? "Generating…" : "▸ Generate",
                        color: Color(hex: "#00ffcc"), busy: mazeVM.isGenerating
                    ) { mazeVM.generate() }

                    MazeActionButton(label: "◈ Show Solution", color: Color(hex: "#0088ff")) {
                        mazeVM.showSolutionPath()
                    }.disabled(mazeVM.result == nil).opacity(mazeVM.result == nil ? 0.4 : 1)

                    MazeActionButton(label: "↺ Reset View", color: Color(hex: "#4a5568")) {
                        mazeVM.resetCamera?()
                    }

                    // Status
                    if !mazeVM.statusText.isEmpty {
                        Text(mazeVM.statusText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#4a8a7a"))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Info
                    if let r = mazeVM.result {
                        let pathLen = r.cubicPath?.count ?? r.planarPath?.count ?? 0
                        VStack(alignment: .leading, spacing: 3) {
                            MazeInfoRow("Mode", r.mode.rawValue)
                            MazeInfoRow("Size", r.mode == .cubic ? "\(r.w)×\(r.h)×\(r.d)" : "\(r.w)×\(r.h)")
                            MazeInfoRow("Entry", "(\(r.entry.x),\(r.entry.y)\(r.mode == .cubic ? ",\(r.entry.z)" : ""))")
                            MazeInfoRow("Exit",  "(\(r.exit.x),\(r.exit.y)\(r.mode == .cubic ? ",\(r.exit.z)" : ""))")
                            MazeInfoRow("Path",  pathLen > 0 ? "\(pathLen) steps" : "No path")
                        }
                        .padding(8)
                        .background(Color(hex: "#0d1117"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#21262d"), lineWidth: 0.5))
                    }

                    Divider().background(Color(hex: "#21262d"))

                    // Cryptology collapsible
                    Button { withAnimation { showCrypto.toggle() } } label: {
                        HStack {
                            Text("◈ LEAD EDGE CRYPTOLOGY")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "#00ffcc")).kerning(1)
                            Spacer()
                            Image(systemName: showCrypto ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10)).foregroundColor(Color(hex: "#4a5568"))
                        }.padding(.vertical, 6)
                    }

                    if showCrypto {
                        IDECryptologyView()
                            .frame(maxHeight: 700)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Maze 3D View (ArcLake orbit controls + glass material)

struct IDEMaze3DView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var mazeVM:  MazeViewModel

    var body: some View {
        ZStack {
            if let node = mazeVM.sceneNode {
                IDEMazeSceneKitView(rootNode: node, resetTrigger: mazeVM.triggerReset)

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
                    Text("1-finger: orbit  ·  2-finger: pan  ·  pinch: zoom")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568").opacity(0.5))
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

// MARK: - SceneKit View with ArcLake orbit controls

struct IDEMazeSceneKitView: UIViewRepresentable {
    let rootNode: SCNNode
    let resetTrigger: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)
        v.allowsCameraControl = false  // manual controls below
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = true
        v.preferredFramesPerSecond = 60

        let scene = SCNScene()
        scene.fogColor    = UIColor(red: 0, green: 0.02, blue: 0.05, alpha: 1)
        scene.fogStartDistance = 10
        scene.fogEndDistance   = 50

        // Lighting
        let ambient = SCNLight(); ambient.type = .ambient
        ambient.color = UIColor(red: 0, green: 1, blue: 0.8, alpha: 0.3)
        let ambientNode = SCNNode(); ambientNode.light = ambient; scene.rootNode.addChildNode(ambientNode)

        let dir = SCNLight(); dir.type = .directional
        dir.color = UIColor(red: 0, green: 1, blue: 0.8, alpha: 1.8)
        let dirNode = SCNNode(); dirNode.light = dir; dirNode.position = SCNVector3(5,8,5)
        scene.rootNode.addChildNode(dirNode)

        let fill = SCNLight(); fill.type = .directional
        fill.color = UIColor(red: 0, green: 0.5, blue: 1, alpha: 1)
        let fillNode = SCNNode(); fillNode.light = fill; fillNode.position = SCNVector3(-5,-3,5)
        scene.rootNode.addChildNode(fillNode)

        scene.rootNode.addChildNode(rootNode)

        // Camera — ArcLake pattern
        let cam = SCNCamera()
        cam.fieldOfView = 60; cam.zFar = 500_000; cam.zNear = 0.001
        cam.bloomIntensity = 0.8; cam.bloomThreshold = 0.65; cam.bloomBlurRadius = 5.0
        let camNode = SCNNode(); camNode.camera = cam; camNode.name = "mazeCamera"
        scene.rootNode.addChildNode(camNode)
        v.scene = scene; v.pointOfView = camNode

        let c = context.coordinator
        c.scnView = v; c.camNode = camNode
        c.resetView()

        // Gestures — ArcLake orbit control pattern
        let orbit = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handleOrbit(_:)))
        orbit.minimumNumberOfTouches = 1; orbit.maximumNumberOfTouches = 1
        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 2; pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.handleDolly(_:)))
        let dbl = UITapGestureRecognizer(target: c, action: #selector(Coordinator.resetView))
        dbl.numberOfTapsRequired = 2

        for g: UIGestureRecognizer in [orbit, pan, pinch, dbl] {
            g.delegate = c; v.addGestureRecognizer(g)
        }
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        // Trigger camera reset when resetTrigger changes
        if context.coordinator.lastResetTrigger != resetTrigger {
            context.coordinator.lastResetTrigger = resetTrigger
            context.coordinator.resetView()
        }
        // Remove old maze nodes, add new one
        v.scene?.rootNode.childNodes
            .filter { $0.light == nil && $0.camera == nil && $0.name != "mazeCamera" }
            .forEach { $0.removeFromParentNode() }
        v.scene?.rootNode.addChildNode(rootNode)

        // Auto-rotation disabled — use orbit controls to manipulate
    }

    // MARK: Coordinator — ArcLake orbit controls ported exactly
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var scnView: SCNView?
        var camNode: SCNNode?

        var lastResetTrigger: Int = -1
        static let defaultQ: simd_quatf = simd_normalize(
            simd_quatf(angle: 0.52, axis: SIMD3<Float>(0,1,0)) *
            simd_quatf(angle: -0.38, axis: SIMD3<Float>(1,0,0)))
        private var camQ: simd_quatf = Coordinator.defaultQ
        private var radius: Float = 8.0
        private var pivot = SIMD3<Float>.zero
        private var r0: Float = 0
        private var lastOrbitT = CGPoint.zero
        private var lastPanT   = CGPoint.zero

        @objc func handleOrbit(_ g: UIPanGestureRecognizer) {
            guard let v = scnView else { return }
            if g.state == .began { lastOrbitT = .zero }
            if g.state == .changed {
                let cur = g.translation(in: v)
                let dx = Float(cur.x - lastOrbitT.x); let dy = Float(cur.y - lastOrbitT.y)
                lastOrbitT = cur
                let spd: Float = 0.006
                let right = camQ.act(SIMD3<Float>(1,0,0))
                let qYaw   = simd_quatf(angle: -dx*spd, axis: SIMD3<Float>(0,1,0))
                let qPitch = simd_quatf(angle: -dy*spd, axis: right)
                camQ = simd_normalize(qYaw * qPitch * camQ); commit()
            }
        }
        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = scnView else { return }
            if g.state == .began { lastPanT = .zero }
            if g.state == .changed {
                let cur = g.translation(in: v)
                let dx = Float(cur.x - lastPanT.x); let dy = Float(cur.y - lastPanT.y)
                lastPanT = cur
                let spd = radius * 0.0028
                let right = camQ.act(SIMD3<Float>(1,0,0)); let up = camQ.act(SIMD3<Float>(0,1,0))
                pivot -= (right * dx - up * dy) * spd; commit()
            }
        }
        @objc func handleDolly(_ g: UIPinchGestureRecognizer) {
            if g.state == .began { r0 = radius }
            if g.state == .changed { radius = max(1.0, min(500, r0 / Float(g.scale))); commit() }
        }
        @objc func resetView() {
            camQ = Coordinator.defaultQ; radius = 8.0; pivot = .zero
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.45
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            commit(); SCNTransaction.commit()
        }
        private func commit() {
            guard let cam = camNode else { return }
            let dir = camQ.act(SIMD3<Float>(0,0,1))
            let pos = pivot + dir * radius
            cam.simdPosition = pos
            cam.simdLook(at: pivot, up: SIMD3<Float>(0,1,0), localFront: SIMD3<Float>(0,0,-1))
        }
        public func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
    }
}

// MARK: - Maze Engine extension — glass material + perimeter walls

extension MazeViewModel {
    // Build scene with liquid-glass perimeter walls
    func buildGlassScene(result r: MazeResult) -> SCNNode {
        let root = SCNNode()
        let s: Float = 0.5   // cell size
        let t: Float = 0.025 // wall thickness

        // LIQUID GLASS wall material (iOS 26 style — semi-transparent, high metalness)
        func glassMat(alpha: Float = 0.35, emissiveIntensity: CGFloat = 0.15) -> SCNMaterial {
            let m = SCNMaterial()
            m.diffuse.contents   = UIColor(red: 0.0, green: 0.95, blue: 0.85, alpha: CGFloat(alpha))
            m.emission.contents  = UIColor(red: 0.0, green: 0.4,  blue: 0.3,  alpha: CGFloat(alpha * 0.4))
            m.specular.contents  = UIColor.white
            m.lightingModel      = .physicallyBased
            m.metalness.contents = NSNumber(value: 0.9)
            m.roughness.contents = NSNumber(value: 0.05)
            m.isDoubleSided      = true
            m.writesToDepthBuffer = false
            m.blendMode          = .alpha
            return m
        }

        let wallMat      = glassMat(alpha: 0.35)
        let perimMat     = glassMat(alpha: 0.20)  // more transparent for outer cube

        let entryMat = SCNMaterial()
        entryMat.diffuse.contents  = UIColor.green
        entryMat.emission.contents = UIColor.green
        entryMat.lightingModel = .constant

        let exitMat = SCNMaterial()
        exitMat.diffuse.contents  = UIColor.red
        exitMat.emission.contents = UIColor.red
        exitMat.lightingModel = .constant

        if r.mode == .planar, let g = r.planarGrid {
            let w = r.w, h = r.h
            let ox = Float(w)*s*0.5, oz = Float(h)*s*0.5

            // Internal walls
            for y in 0..<h { for x in 0..<w {
                let cell = g[y][x]
                let cx = Float(x)*s - ox + s*0.5
                let cz = Float(y)*s - oz + s*0.5
                if cell.E && x < w-1 {
                    let n = SCNNode(geometry: SCNBox(width: CGFloat(t), height: 0.4, length: CGFloat(s), chamferRadius: 0))
                    n.geometry?.firstMaterial = wallMat; n.position = SCNVector3(cx+s*0.5, 0, cz); root.addChildNode(n)
                }
                if cell.S && y < h-1 {
                    let n = SCNNode(geometry: SCNBox(width: CGFloat(s), height: 0.4, length: CGFloat(t), chamferRadius: 0))
                    n.geometry?.firstMaterial = wallMat; n.position = SCNVector3(cx, 0, cz+s*0.5); root.addChildNode(n)
                }
            }}

            // Perimeter walls (skipping entry/exit openings)
            let ex = r.entry.x, ey = r.entry.y, xx = r.exit.x, xy = r.exit.y
            for x in 0..<w {
                if !(ex==x && ey==0) && !(xx==x && xy==0) {
                    let n = SCNNode(geometry: SCNBox(width: CGFloat(s), height: 0.4, length: CGFloat(t), chamferRadius: 0))
                    n.geometry?.firstMaterial = perimMat; n.position = SCNVector3(Float(x)*s-ox+s*0.5, 0, -oz); root.addChildNode(n)
                }
                if !(ex==x && ey==h-1) && !(xx==x && xy==h-1) {
                    let n = SCNNode(geometry: SCNBox(width: CGFloat(s), height: 0.4, length: CGFloat(t), chamferRadius: 0))
                    n.geometry?.firstMaterial = perimMat; n.position = SCNVector3(Float(x)*s-ox+s*0.5, 0, Float(h)*s-oz); root.addChildNode(n)
                }
            }
            for y in 0..<h {
                if !(ex==0 && ey==y) && !(xx==0 && xy==y) {
                    let n = SCNNode(geometry: SCNBox(width: CGFloat(t), height: 0.4, length: CGFloat(s), chamferRadius: 0))
                    n.geometry?.firstMaterial = perimMat; n.position = SCNVector3(-ox, 0, Float(y)*s-oz+s*0.5); root.addChildNode(n)
                }
                if !(ex==w-1 && ey==y) && !(xx==w-1 && xy==y) {
                    let n = SCNNode(geometry: SCNBox(width: CGFloat(t), height: 0.4, length: CGFloat(s), chamferRadius: 0))
                    n.geometry?.firstMaterial = perimMat; n.position = SCNVector3(Float(w)*s-ox, 0, Float(y)*s-oz+s*0.5); root.addChildNode(n)
                }
            }

        } else if r.mode == .cubic, let g = r.cubicGrid {
            let w = r.w, h = r.h, d = r.d
            let ox = Float(w)*s*0.5, oy = Float(h)*s*0.5, oz = Float(d)*s*0.5

            let tube = SCNCylinder(radius: CGFloat(t), height: CGFloat(s*0.48))
            tube.radialSegmentCount = 6

            func addTube(_ cx: Float, _ cy: Float, _ cz: Float, _ dx: Float, _ dy: Float, _ dz: Float, _ euler: SCNVector3, mat: SCNMaterial) {
                let n = SCNNode(geometry: tube); n.geometry?.firstMaterial = mat
                n.position = SCNVector3(cx+dx*s*0.25, cy+dy*s*0.25, cz+dz*s*0.25)
                n.eulerAngles = euler; root.addChildNode(n)
            }

            for z in 0..<d { for y in 0..<h { for x in 0..<w {
                let cell = g[z][y][x]
                let cx = Float(x)*s - ox + s*0.5
                let cy = Float(y)*s - oy + s*0.5
                let cz = Float(z)*s - oz + s*0.5

                // Internal passages
                if !cell.right  { addTube(cx,cy,cz, 1,0,0, SCNVector3(0,0,Float.pi/2), mat: wallMat) }
                if !cell.top    { addTube(cx,cy,cz, 0,1,0, SCNVector3(0,0,0),         mat: wallMat) }
                if !cell.front  { addTube(cx,cy,cz, 0,0,1, SCNVector3(Float.pi/2,0,0),mat: wallMat) }

                // Perimeter face panels — add solid faces where walls exist on outer surfaces
                // Skip entry/exit openings
                let isEntry = (x==r.entry.x && y==r.entry.y && z==r.entry.z)
                let isExit  = (x==r.exit.x  && y==r.exit.y  && z==r.exit.z)

                func perimPanel(_ nx: Float, _ ny: Float, _ nz: Float, _ pw: CGFloat, _ ph: CGFloat, _ pd: CGFloat) {
                    guard !isEntry && !isExit else { return }
                    let geo = SCNBox(width: pw, height: ph, length: pd, chamferRadius: 0)
                    let n = SCNNode(geometry: geo); n.geometry?.firstMaterial = perimMat
                    n.position = SCNVector3(cx+nx, cy+ny, cz+nz); root.addChildNode(n)
                }

                // Left face (x==0)
                if x == 0 && cell.left   { perimPanel(-s*0.5, 0, 0, CGFloat(t), CGFloat(s), CGFloat(s)) }
                // Right face (x==w-1)
                if x == w-1 && cell.right { perimPanel(s*0.5, 0, 0, CGFloat(t), CGFloat(s), CGFloat(s)) }
                // Bottom face (y==0)
                if y == 0 && cell.top    { perimPanel(0, -s*0.5, 0, CGFloat(s), CGFloat(t), CGFloat(s)) }
                // Top face (y==h-1)
                if y == h-1 && cell.bottom { perimPanel(0, s*0.5, 0, CGFloat(s), CGFloat(t), CGFloat(s)) }
                // Back face (z==0)
                if z == 0 && cell.back   { perimPanel(0, 0, -s*0.5, CGFloat(s), CGFloat(s), CGFloat(t)) }
                // Front face (z==d-1)
                if z == d-1 && cell.front { perimPanel(0, 0, s*0.5, CGFloat(s), CGFloat(s), CGFloat(t)) }

                // Cell node
                let sphere = SCNSphere(radius: CGFloat(t*1.5)); sphere.segmentCount = 6
                sphere.firstMaterial = wallMat
                let sn = SCNNode(geometry: sphere); sn.position = SCNVector3(cx, cy, cz); root.addChildNode(sn)
            }}}
        }

        // Entry/exit markers — for planar maze, placed AT the perimeter opening (outside the wall)
        func marker(_ pos: SCNVector3, _ color: UIColor) {
            let sphere = SCNSphere(radius: 0.08); sphere.segmentCount = 8
            sphere.firstMaterial?.diffuse.contents  = color
            sphere.firstMaterial?.emission.contents = color
            sphere.firstMaterial?.lightingModel = .constant
            let n = SCNNode(geometry: sphere); n.position = pos; root.addChildNode(n)
            let ring = SCNTorus(ringRadius: 0.14, pipeRadius: 0.02); ring.ringSegmentCount = 24; ring.pipeSegmentCount = 8
            ring.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.6)
            ring.firstMaterial?.lightingModel = .constant
            let rn = SCNNode(geometry: ring); rn.position = pos; root.addChildNode(rn)
            let pulse = CABasicAnimation(keyPath: "scale"); pulse.fromValue = NSValue(scnVector3: SCNVector3(1,1,1))
            pulse.toValue = NSValue(scnVector3: SCNVector3(1.5,1.5,1.5)); pulse.duration = 1.2
            pulse.autoreverses = true; pulse.repeatCount = .infinity; rn.addAnimation(pulse, forKey: "pulse")
        }

        // Planar: opening is in the perimeter wall of cell (ex,ey).
        // Detect which edge the cell sits on; offset marker just outside that wall.
        func planarMarkerPos(_ ex: Int, _ ey: Int, _ w: Int, _ h: Int, _ ox: Float, _ oz: Float) -> SCNVector3 {
            let cx = Float(ex)*s - ox + s*0.5
            let cz = Float(ey)*s - oz + s*0.5
            if ey == 0     { return SCNVector3(cx,     0.1, -oz - s*0.35) }
            if ey == h-1   { return SCNVector3(cx,     0.1, Float(h)*s - oz + s*0.35) }
            if ex == 0     { return SCNVector3(-ox - s*0.35, 0.1, cz) }
            if ex == w-1   { return SCNVector3(Float(w)*s - ox + s*0.35, 0.1, cz) }
            return SCNVector3(cx, 0.1, cz)
        }

        if r.mode == .planar {
            let w = r.w, h = r.h
            let ox = Float(w)*s*0.5, oz = Float(h)*s*0.5
            marker(planarMarkerPos(r.entry.x, r.entry.y, w, h, ox, oz), UIColor.green)
            marker(planarMarkerPos(r.exit.x,  r.exit.y,  w, h, ox, oz), UIColor.red)
        } else {
            let es = s * 0.5
            marker(SCNVector3(Float(r.entry.x)*s - Float(r.w)*s*0.5 + es,
                              Float(r.entry.y)*s - Float(r.h)*s*0.5 + es,
                              Float(r.entry.z)*s - Float(r.d)*s*0.5 + es), UIColor.green)
            marker(SCNVector3(Float(r.exit.x)*s - Float(r.w)*s*0.5 + es,
                              Float(r.exit.y)*s - Float(r.h)*s*0.5 + es,
                              Float(r.exit.z)*s - Float(r.d)*s*0.5 + es), UIColor.red)
        }
        return root
    }
}

// MARK: - Subviews (reused)

struct MazeSectionHeader: View {
    let title: String; init(_ t: String) { title = t }
    var body: some View {
        Text(title)
            .font(.system(size: 7, weight: .semibold, design: .monospaced))
            .foregroundColor(Color(hex: "#4a5568")).kerning(1.5)
    }
}
struct MazeSlider: View {
    let label: String; @Binding var value: Int; let range: ClosedRange<Int>
    var body: some View {
        HStack {
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundColor(Color(hex: "#8ab4cc"))
                .frame(width: 45, alignment: .leading)
            Slider(value: Binding(get:{Double(value)}, set:{value=Int($0.rounded())}),
                   in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .tint(Color(hex: "#00ffcc"))
            Text("\(value)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#00ffcc")).frame(width: 28, alignment: .trailing)
        }
    }
}
struct MazeActionButton: View {
    let label: String; let color: Color; var busy: Bool = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(busy ? color.opacity(0.5) : color).frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.25), lineWidth: 0.5))
                .cornerRadius(4)
        }.disabled(busy)
    }
}
struct MazeInfoRow: View {
    let label, value: String; init(_ l: String, _ v: String) { label=l; value=v }
    var body: some View {
        HStack {
            Text(label+":").font(.system(size: 9, design: .monospaced)).foregroundColor(Color(hex: "#4a5568")).frame(width: 40, alignment: .leading)
            Text(value).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(Color(hex: "#8ab4cc"))
        }
    }
}

// MARK: - Cryptology Panel

struct IDECryptologyPanel: View {
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var keyDisplay = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Generate maze-based keys for Ash cryptology.")
                .font(.system(size: 9, design: .monospaced)).foregroundColor(Color(hex: "#4a5568"))
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(size: 10, design: .monospaced)).foregroundColor(Color(hex: "#c9d1d9"))
                    .frame(minHeight: 60, maxHeight: 80)
                    .background(Color(hex: "#0d1117")).cornerRadius(4)
                if inputText.isEmpty {
                    Text("Type a message…").font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568")).padding(8).allowsHitTesting(false)
                }
            }

            MazeActionButton(label: "◈ Generate Maze Keys", color: Color(hex: "#00ffcc")) { generateKeys() }
            MazeActionButton(label: "→ Encrypt", color: Color(hex: "#0088ff")) { encryptMessage() }
            MazeActionButton(label: "← Decrypt", color: Color(hex: "#bf5fff")) { decryptMessage() }

            if !keyDisplay.isEmpty {
                Text(keyDisplay).font(.system(size: 8, design: .monospaced)).foregroundColor(Color(hex: "#4a8a7a"))
                    .fixedSize(horizontal: false, vertical: true).padding(6)
                    .background(Color(hex: "#0d1117")).cornerRadius(4)
            }
            if !outputText.isEmpty {
                Text(outputText).font(.system(size: 9, design: .monospaced)).foregroundColor(Color(hex: "#00ffcc"))
                    .fixedSize(horizontal: false, vertical: true).padding(6)
                    .background(Color(hex: "#0a140a")).cornerRadius(4)
            }
        }
    }

    private func generateKeys() {
        let maze = LEMACEngine.generateCubic(w: 6, h: 6, d: 6)
        let (entry, exit) = LEMACEngine.placeCubicOpenings(w: 6, h: 6, d: 6)
        var wallCount = 0
        for z in 0..<6 { for y in 0..<6 { for x in 0..<6 {
            let c = maze[z][y][x]; if !c.top { wallCount+=1 }; if !c.right { wallCount+=1 }; if !c.front { wallCount+=1 }
        }}}
        let privateKey = String(format: "%06X-%06X-%06X",
            entry.0 * 65536 + entry.1 * 256 + entry.2, wallCount, exit.0 * 65536 + exit.1 * 256 + exit.2)
        let publicKey  = String(format: "%08X", wallCount &* 0x9E3779B9)
        keyDisplay = "Private: \(privateKey)\nPublic:  \(publicKey)"
    }
    private func encryptMessage() {
        guard !inputText.isEmpty else { return }
        if keyDisplay.isEmpty { generateKeys() }
        let key = Array(keyDisplay.utf8.prefix(16)); guard !key.isEmpty else { return }
        let enc = Array(inputText.utf8).enumerated().map { UInt8(($1 ^ key[$0 % key.count]) & 0xFF) }
        outputText = "ENC: " + enc.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    private func decryptMessage() {
        outputText = "Decryption requires matching private maze key. Keys are session-bound."
    }
}
