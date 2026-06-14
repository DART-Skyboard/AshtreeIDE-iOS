// ArcEdgeGLDriver.swift — Arc Edge Vector GL Driver for Ash Tree IDE
// Full port of arc-edge-vector.html to Swift/SceneKit
// © 2025 DART Meadow | Radical Deepscale LLC.
import Foundation
import SceneKit
import SwiftUI
import simd

// MARK: - Arc Edge Math

public struct ArcEdgeMath {
    public static let DOC: Double = 3.0
    public static let ARC_S: Double = 2.3
    public static let STEPS: Int = 72

    public static func circumference(_ d: Double) -> Double { pow(sqrt(d * DOC), 2) }
    public static func area(_ d: Double) -> Double { pow(circumference(d), 2) }
    public static func volume(_ d: Double) -> Double { pow(area(d), 3) }
    public static func sphereSA(_ d: Double) -> Double { volume(d) * 0.25 }
    public static func branchArc(_ d: Double) -> Double { circumference(d) * 0.125 }
    public static func arcDeviation(t: Double, phase: Double, influence: Double) -> Double {
        sin(DOC * t + phase) * influence * 0.48
    }
}

// MARK: - State

public struct ArcAxisState {
    public var handles: [[Double]] = [[0,0],[0,0],[0,0]]
    public var smooth: Bool = true
    public var influence: Double = 0
    public var phase: Double = 0
    public var physTargets: [Bool] = [true,true,true]
    public var visible: Bool = true
    public init() {}
}

public struct ArcPhysicsEnv {
    public var wind: Double = 0; public var temperature: Double = 72
    public var gravity: Double = 9.81; public var humidity: Double = 50
    public var pressure: Double = 14.7
    public init() {}
}

public struct ArcGridConfig {
    public var enabled: Bool = false
    public var xzEnabled: Bool = true; public var xzCountX: Int = 5; public var xzCountZ: Int = 5
    public var xyEnabled: Bool = true; public var xyCountX: Int = 5; public var xyCountY: Int = 5
    public var zyEnabled: Bool = true; public var zyCountZ: Int = 5; public var zyCountY: Int = 5
    public init() {}
}

// MARK: - ViewModel

@MainActor
public final class ArcEdgeVM: ObservableObject {
    @Published public var axisX = ArcAxisState()
    @Published public var axisY = ArcAxisState()
    @Published public var axisZ = ArcAxisState()
    @Published public var physics = ArcPhysicsEnv()
    @Published public var grid = ArcGridConfig()
    @Published public var meridianJoin: Bool = true
    @Published public var tangentEnabled: Bool = true

    public let scene = SCNScene()
    private var simTime: Double = 0
    private var displayLink: CADisplayLink?
    private var sigmaM: SIMD3<Double> = .zero

    private let splineXNode = SCNNode(); private let splineYNode = SCNNode()
    private let splineZNode = SCNNode(); private let axisNode    = SCNNode()
    private let gridNode    = SCNNode(); private let handleNode  = SCNNode()
    private let sigmaNode   = SCNNode()

    public init() {
        scene.background.contents = UIColor(red:0.024,green:0.039,blue:0.063,alpha:1)
        scene.fogColor = UIColor(red:0.024,green:0.039,blue:0.063,alpha:1)
        scene.fogStartDistance = 15; scene.fogEndDistance = 50
        let al = SCNLight(); al.type = .ambient; al.color = UIColor(white:0.3,alpha:1)
        let an = SCNNode(); an.light = al; scene.rootNode.addChildNode(an)
        let dl = SCNLight(); dl.type = .directional; dl.color = UIColor(red:0,green:0.9,blue:1,alpha:1)
        let dn = SCNNode(); dn.light = dl; dn.position = SCNVector3(5,8,5); scene.rootNode.addChildNode(dn)
        for n in [splineXNode,splineYNode,splineZNode,axisNode,gridNode,handleNode,sigmaNode] {
            scene.rootNode.addChildNode(n)
        }
        buildAxisLines(); rebuild()
    }

    public func startAnimation() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to:.main, forMode:.common)
    }
    public func stopAnimation() { displayLink?.invalidate(); displayLink = nil }

    @objc private func tick() { simTime += 1.0/60.0; rebuild() }

    func axisState(_ ax: String) -> ArcAxisState {
        switch ax { case "X": return axisX; case "Y": return axisY; default: return axisZ }
    }

    func physOffset(axis: String, hIdx: Int) -> [Double] {
        let sp = axisState(axis); if !sp.physTargets[hIdx] { return [0,0] }
        let t=Double(hIdx)*0.5, gn=physics.gravity/9.81, wn=physics.wind/100
        let tn=(physics.temperature-72)/48, hn=physics.humidity/100, pn=(physics.pressure-14.7)/15.3
        let gravBell=4*t*(1-t), gravSag=(gn-1)*0.55*gravBell
        let wA=sin(simTime*ArcEdgeMath.DOC*0.26+sp.phase+Double(hIdx))*wn*0.45
        let wB=cos(simTime*ArcEdgeMath.DOC*0.20+sp.phase+Double(hIdx)*1.5)*wn*0.28
        let hA=sin(simTime*ArcEdgeMath.DOC*0.64+Double(hIdx)*2.0)*hn*0.13, pA=pn*0.08
        var da=0.0, db=0.0
        if axis=="X" { da = -gravSag+wA+tn*0.18+hA+pA; db=wB }
        else if axis=="Y" { da=wA+tn*0.14+hA+pA; db=wB }
        else { da=wA+pA; db = -gravSag+wB+tn*0.18+hA }
        return [da*sp.influence, db*sp.influence]
    }

    func effHandle(axis: String, idx: Int) -> [Double] {
        let sp=axisState(axis); let po=tangentEnabled ? physOffset(axis:axis,hIdx:idx) : [0.0,0.0]
        return [sp.handles[idx][0]+po[0], sp.handles[idx][1]+po[1]]
    }

    func naturalMidpoint(axis: String) -> SIMD3<Double> {
        let sp=axisState(axis)
        let eHW=effHandle(axis:axis,idx:0), eHE=effHandle(axis:axis,idx:2)
        let po=tangentEnabled ? physOffset(axis:axis,hIdx:1) : [0.0,0.0]
        let eHM=[sp.handles[1][0]+po[0], sp.handles[1][1]+po[1]]
        let bA=0.25*eHW[0]+0.5*eHM[0]+0.25*eHE[0], bB=0.25*eHW[1]+0.5*eHM[1]+0.25*eHE[1]
        let arc=tangentEnabled ? ArcEdgeMath.arcDeviation(t:0.5,phase:sp.phase,influence:sp.influence) : 0
        if axis=="X" { return SIMD3(0, bA+arc, bB) }
        else if axis=="Y" { return SIMD3(bA+arc, 0, bB) }
        return SIMD3(bA+arc, bB, 0)
    }

    func computeSigmaM() {
        var sx=0.0,sy=0.0,sz=0.0,nx=0,ny=0,nz=0
        for ax in ["X","Y","Z"] {
            guard axisState(ax).visible else { continue }
            let mp=naturalMidpoint(axis:ax)
            if ax=="X" { sy+=mp.y;ny+=1;sz+=mp.z;nz+=1 }
            else if ax=="Y" { sx+=mp.x;nx+=1;sz+=mp.z;nz+=1 }
            else { sx+=mp.x;nx+=1;sy+=mp.y;ny+=1 }
        }
        sigmaM=SIMD3(nx>0 ? sx/Double(nx):0, ny>0 ? sy/Double(ny):0, nz>0 ? sz/Double(nz):0)
    }

    func sigmaMHandle(axis: String, eHW: [Double], eHE: [Double]) -> [Double] {
        let sp=axisState(axis)
        let arc=tangentEnabled ? ArcEdgeMath.arcDeviation(t:0.5,phase:sp.phase,influence:sp.influence) : 0
        let ta: Double, tb: Double
        if axis=="X" { ta=sigmaM.y; tb=sigmaM.z }
        else if axis=="Y" { ta=sigmaM.x; tb=sigmaM.z }
        else { ta=sigmaM.x; tb=sigmaM.y }
        return [2*(ta-arc)-0.5*(eHW[0]+eHE[0]), 2*tb-0.5*(eHW[1]+eHE[1])]
    }

    func genSpline(axis: String) -> [SIMD3<Double>] {
        let sp=axisState(axis)
        let eHW=effHandle(axis:axis,idx:0), eHE=effHandle(axis:axis,idx:2)
        let eHM: [Double] = (tangentEnabled && meridianJoin && sp.visible) ?
            sigmaMHandle(axis:axis,eHW:eHW,eHE:eHE) : effHandle(axis:axis,idx:1)
        let eH=[eHW,eHM,eHE]
        var pts: [SIMD3<Double>] = []
        for i in 0...ArcEdgeMath.STEPS {
            let t=Double(i)/Double(ArcEdgeMath.STEPS), s=(t*2-1)*ArcEdgeMath.ARC_S
            var x=0.0,y=0.0,z=0.0
            if axis=="X"{x=s}else if axis=="Y"{y=s}else{z=s}
            if tangentEnabled {
                let wW=(1-t)*(1-t),wM=2*t*(1-t),wE=t*t
                let bA=eH[0][0]*wW+eH[1][0]*wM+eH[2][0]*wE
                let bB=eH[0][1]*wW+eH[1][1]*wM+eH[2][1]*wE
                let arc=ArcEdgeMath.arcDeviation(t:t,phase:sp.phase,influence:sp.influence)
                if axis=="X"{y+=bA+arc;z+=bB}else if axis=="Y"{x+=bA+arc;z+=bB}else{x+=bA+arc;y+=bB}
            }
            pts.append(SIMD3(x,y,z))
        }
        return pts
    }

    func rebuild() {
        if tangentEnabled && meridianJoin { computeSigmaM() }
        for n in [splineXNode,splineYNode,splineZNode,handleNode,sigmaNode] {
            n.childNodes.forEach { $0.removeFromParentNode() }
        }
        let cols: [String:UIColor] = [
            "X":UIColor(red:1,green:0.239,blue:0.353,alpha:1),
            "Y":UIColor(red:0.224,green:1,blue:0.51,alpha:1),
            "Z":UIColor(red:0,green:0.898,blue:1,alpha:1)
        ]
        for ax in ["X","Y","Z"] {
            guard axisState(ax).visible else { continue }
            let pts=genSpline(axis:ax)
            let sn=ax=="X" ? splineXNode : ax=="Y" ? splineYNode : splineZNode
            addSpline(node:sn, pts:pts, color:cols[ax]!)
            // Handle spheres
            let eHW=effHandle(axis:ax,idx:0), eHE=effHandle(axis:ax,idx:2)
            let eHM=(tangentEnabled && meridianJoin) ? sigmaMHandle(axis:ax,eHW:eHW,eHE:eHE) : effHandle(axis:ax,idx:1)
            for (i,eff) in [eHW,eHM,eHE].enumerated() {
                let t=Double(i)*0.5, s=(t*2-1)*ArcEdgeMath.ARC_S
                var x=0.0,y=0.0,z=0.0
                if ax=="X"{x=s}else if ax=="Y"{y=s}else{z=s}
                if ax=="X"{y+=eff[0];z+=eff[1]}else if ax=="Y"{x+=eff[0];z+=eff[1]}else{x+=eff[0];y+=eff[1]}
                let sp=SCNSphere(radius:i==1 ? 0.055 : 0.04); sp.segmentCount=8
                let c:UIColor=i==1 ? .white : UIColor(red:1,green:0.87,blue:0.32,alpha:1)
                sp.firstMaterial?.diffuse.contents=c; sp.firstMaterial?.emission.contents=c
                sp.firstMaterial?.lightingModel = .constant
                let n=SCNNode(geometry:sp); n.position=SCNVector3(x,y,z)
                handleNode.addChildNode(n)
            }
        }
        // Sigma point
        if tangentEnabled && meridianJoin {
            let sg=SCNSphere(radius:0.05); sg.segmentCount=8
            sg.firstMaterial?.diffuse.contents=UIColor.white
            sg.firstMaterial?.emission.contents=UIColor.white
            sg.firstMaterial?.lightingModel = .constant
            let n=SCNNode(geometry:sg); n.position=SCNVector3(sigmaM.x,sigmaM.y,sigmaM.z)
            sigmaNode.addChildNode(n)
        }
        // Grid
        gridNode.childNodes.forEach { $0.removeFromParentNode() }
        if grid.enabled { buildGridPlanes() }
    }

    func addSpline(node: SCNNode, pts: [SIMD3<Double>], color: UIColor) {
        guard pts.count>1 else { return }
        let verts=pts.map{SCNVector3($0.x,$0.y,$0.z)}
        var idx=[Int32](); for i in 0..<verts.count-1{idx.append(Int32(i));idx.append(Int32(i+1))}
        let src=SCNGeometrySource(vertices:verts)
        let el=SCNGeometryElement(indices:idx,primitiveType:.line)
        let geo=SCNGeometry(sources:[src],elements:[el])
        let mat=SCNMaterial(); mat.diffuse.contents=color; mat.emission.contents=color; mat.lightingModel = .constant
        geo.firstMaterial=mat; node.addChildNode(SCNNode(geometry:geo))
        // Glow
        let gmat=SCNMaterial(); gmat.diffuse.contents=color.withAlphaComponent(0.35)
        gmat.emission.contents=color.withAlphaComponent(0.35); gmat.lightingModel = .constant
        let ggeo=SCNGeometry(sources:[src],elements:[el]); ggeo.firstMaterial=gmat
        node.addChildNode(SCNNode(geometry:ggeo))
    }

    func buildAxisLines() {
        axisNode.childNodes.forEach { $0.removeFromParentNode() }
        let s=ArcEdgeMath.ARC_S*1.22
        let axCols=["X":UIColor(red:1,green:0.24,blue:0.35,alpha:0.5),"Y":UIColor(red:0.22,green:1,blue:0.51,alpha:0.5),"Z":UIColor(red:0,green:0.90,blue:1,alpha:0.5)]
        addLine(SCNVector3(-s,0,0),SCNVector3(s,0,0),axCols["X"]!,axisNode)
        addLine(SCNVector3(0,-s,0),SCNVector3(0,s,0),axCols["Y"]!,axisNode)
        addLine(SCNVector3(0,0,-s),SCNVector3(0,0,s),axCols["Z"]!,axisNode)
        // Ground grid
        let gH=ArcEdgeMath.ARC_S*1.1, step=ArcEdgeMath.ARC_S*2.2/12
        let gc=UIColor(red:0.07,green:0.12,blue:0.18,alpha:0.9)
        for i in 0...12 {
            let p = -gH+Double(i)*step
            addLine(SCNVector3(p,0,-gH),SCNVector3(p,0,gH),gc,axisNode)
            addLine(SCNVector3(-gH,0,p),SCNVector3(gH,0,p),gc,axisNode)
        }
        let orig=SCNSphere(radius:0.03); orig.firstMaterial?.diffuse.contents=UIColor.white; orig.firstMaterial?.lightingModel = .constant
        axisNode.addChildNode(SCNNode(geometry:orig))
    }

    func addLine(_ a: SCNVector3, _ b: SCNVector3, _ color: UIColor, _ parent: SCNNode) {
        let mat=SCNMaterial(); mat.diffuse.contents=color; mat.emission.contents=color; mat.lightingModel = .constant
        let geo=SCNGeometry(sources:[SCNGeometrySource(vertices:[a,b])],
            elements:[SCNGeometryElement(indices:[Int32(0),Int32(1)],primitiveType:.line)])
        geo.firstMaterial=mat; parent.addChildNode(SCNNode(geometry:geo))
    }

    func buildGridPlanes() {
        let s=ArcEdgeMath.ARC_S
        if grid.xzEnabled { addGridLines(n1:grid.xzCountX,n2:grid.xzCountZ,ax1:.x,ax2:.z,color:UIColor(red:0.22,green:1,blue:0.51,alpha:0.4),s:s) }
        if grid.xyEnabled { addGridLines(n1:grid.xyCountX,n2:grid.xyCountY,ax1:.x,ax2:.y,color:UIColor(red:1,green:0.24,blue:0.35,alpha:0.4),s:s) }
        if grid.zyEnabled { addGridLines(n1:grid.zyCountZ,n2:grid.zyCountY,ax1:.z,ax2:.y,color:UIColor(red:0,green:0.90,blue:1,alpha:0.4),s:s) }
    }

    enum A3 { case x,y,z }
    func addGridLines(n1:Int,n2:Int,ax1:A3,ax2:A3,color:UIColor,s:Double) {
        func pt(_ a:Double,_ b:Double)->SCNVector3{
            var x=0.0,y=0.0,z=0.0
            switch ax1{case .x:x=a;case .y:y=a;case .z:z=a}
            switch ax2{case .x:x=b;case .y:y=b;case .z:z=b}
            return SCNVector3(x,y,z)
        }
        for i in 0...n1 { let a = -s+Double(i)*(s*2/Double(max(n1,1))); addLine(pt(a,-s),pt(a,s),color,gridNode) }
        for j in 0...n2 { let b = -s+Double(j)*(s*2/Double(max(n2,1))); addLine(pt(-s,b),pt(s,b),color,gridNode) }
    }
}

// MARK: - SwiftUI View

public struct ArcEdgeSceneView: View {
    @StateObject private var vm = ArcEdgeVM()
    @State private var showPanel = true

    public init() {}

    public var body: some View {
        ZStack(alignment: .topLeading) {
            ArcEdgeSCNView(vm: vm)

            if showPanel {
                ArcEdgePanel(vm: vm, show: $showPanel)
                    .frame(width:215)
                    .background(Color(hex:"#0d1117").opacity(0.92))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius:12).stroke(Color(hex:"#21262d"),lineWidth:0.5))
                    .padding(10)
                    .shadow(color:.black.opacity(0.5),radius:10)
                    .transition(.move(edge:.leading))
            }

            // Collapse tab
            VStack {
                Button { withAnimation { showPanel.toggle() } } label: {
                    Image(systemName: showPanel ? "sidebar.left" : "sidebar.right")
                        .font(.system(size:11,weight:.semibold))
                        .foregroundColor(Color(hex:"#00e5ff"))
                        .padding(7)
                        .background(Color(hex:"#0d1117").opacity(0.85))
                        .cornerRadius(6)
                }
                .padding(.top, 10)
                .padding(.leading, showPanel ? 229 : 10)
                Spacer()
            }
        }
        .onAppear  { vm.startAnimation() }
        .onDisappear { vm.stopAnimation() }
    }
}

struct ArcEdgeSCNView: UIViewRepresentable {
    @ObservedObject var vm: ArcEdgeVM
    func makeCoordinator() -> Coord { Coord(vm:vm) }
    func makeUIView(context: Context) -> SCNView {
        let v=SCNView()
        v.backgroundColor=UIColor(red:0.024,green:0.039,blue:0.063,alpha:1)
        v.allowsCameraControl=false; v.antialiasingMode = .multisampling4X
        v.rendersContinuously=true; v.preferredFramesPerSecond=60; v.scene=vm.scene
        let cam=SCNCamera(); cam.fieldOfView=60; cam.zFar=500_000; cam.zNear=0.001
        cam.bloomIntensity=0.8; cam.bloomThreshold=0.65; cam.bloomBlurRadius=5
        let cn=SCNNode(); cn.camera=cam; vm.scene.rootNode.addChildNode(cn); v.pointOfView=cn
        let c=context.coordinator; c.scnView=v; c.camNode=cn; c.resetView()
        let orb=UIPanGestureRecognizer(target:c,action:#selector(Coord.orbit(_:)))
        orb.minimumNumberOfTouches=1;orb.maximumNumberOfTouches=1
        let pan=UIPanGestureRecognizer(target:c,action:#selector(Coord.pan(_:)))
        pan.minimumNumberOfTouches=2;pan.maximumNumberOfTouches=2
        let pinch=UIPinchGestureRecognizer(target:c,action:#selector(Coord.dolly(_:)))
        let dbl=UITapGestureRecognizer(target:c,action:#selector(Coord.resetView)); dbl.numberOfTapsRequired=2
        for g:[UIGestureRecognizer] in [[orb],[pan],[pinch],[dbl]] { g[0].delegate=c; v.addGestureRecognizer(g[0]) }
        return v
    }
    func updateUIView(_ v: SCNView, context: Context) {}

    class Coord: NSObject, UIGestureRecognizerDelegate {
        let vm:ArcEdgeVM; weak var scnView:SCNView?; var camNode:SCNNode?
        static let defQ=simd_normalize(simd_quatf(angle:0.52,axis:SIMD3<Float>(0,1,0))*simd_quatf(angle:-0.38,axis:SIMD3<Float>(1,0,0)))
        var q=Coord.defQ; var r:Float=8; var piv=SIMD3<Float>.zero
        var r0:Float=0; var lt=CGPoint.zero; var lp=CGPoint.zero
        init(vm:ArcEdgeVM){self.vm=vm}
        @objc func orbit(_ g:UIPanGestureRecognizer){ guard let v=scnView else{return}
            if g.state == .began{lt = .zero}
            if g.state == .changed{let cur=g.translation(in:v);let dx=Float(cur.x-lt.x);let dy=Float(cur.y-lt.y);lt=cur
                let rgt=q.act(SIMD3<Float>(1,0,0))
                q=simd_normalize(simd_quatf(angle:-dx*0.006,axis:SIMD3<Float>(0,1,0))*simd_quatf(angle:-dy*0.006,axis:rgt)*q);commit()}}
        @objc func pan(_ g:UIPanGestureRecognizer){ guard let v=scnView else{return}
            if g.state == .began{lp = .zero}
            if g.state == .changed{let cur=g.translation(in:v);let dx=Float(cur.x-lp.x);let dy=Float(cur.y-lp.y);lp=cur
                let spd=r*0.0028;let rgt=q.act(SIMD3<Float>(1,0,0));let up=q.act(SIMD3<Float>(0,1,0))
                piv -= (rgt*dx-up*dy)*spd;commit()}}
        @objc func dolly(_ g:UIPinchGestureRecognizer){if g.state == .began{r0=r};if g.state == .changed{r=max(0.5,min(200,r0/Float(g.scale)));commit()}}
        @objc func resetView(){q=Coord.defQ;r=8;piv = .zero;SCNTransaction.begin();SCNTransaction.animationDuration=0.45;commit();SCNTransaction.commit()}
        func commit(){ guard let c=camNode else{return};let d=q.act(SIMD3<Float>(0,0,1));let p=piv+d*r;c.simdPosition=p;c.simdLook(at:piv,up:SIMD3<Float>(0,1,0),localFront:SIMD3<Float>(0,0,-1))}
        public func gestureRecognizer(_ g:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith o:UIGestureRecognizer)->Bool{true}
    }
}

// MARK: - Controls Panel

struct ArcEdgePanel: View {
    @ObservedObject var vm: ArcEdgeVM
    @Binding var show: Bool
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:0) {
                HStack(spacing:5) {
                    Circle().fill(Color(hex:"#ff5f57")).frame(width:8,height:8)
                    Circle().fill(Color(hex:"#febc2e")).frame(width:8,height:8)
                    Circle().fill(Color(hex:"#28c840")).frame(width:8,height:8)
                    Text("◈ ARC EDGE VECTOR").font(.system(size:8,weight:.semibold,design:.monospaced)).foregroundColor(Color(hex:"#00e5ff")).kerning(1.5)
                    Spacer()
                    Button(action:{withAnimation{show=false}}){Image(systemName:"chevron.left").font(.system(size:10)).foregroundColor(Color(hex:"#4a5568"))}
                }.padding(10).background(Color(hex:"#161b22")).overlay(Divider().background(Color(hex:"#21262d")),alignment:.bottom)
                VStack(alignment:.leading,spacing:8) {
                    ArcToggle("Tangent System",val:$vm.tangentEnabled)
                    ArcToggle("Join Meridians Σ",val:$vm.meridianJoin)
                    Divider().background(Color(hex:"#21262d"))
                    ArcAxisCtrl(label:"X AXIS",color:Color(hex:"#ff3d5a"),inf:$vm.axisX.influence,phase:$vm.axisX.phase,vis:$vm.axisX.visible)
                    ArcAxisCtrl(label:"Y AXIS",color:Color(hex:"#39ff82"),inf:$vm.axisY.influence,phase:$vm.axisY.phase,vis:$vm.axisY.visible)
                    ArcAxisCtrl(label:"Z AXIS",color:Color(hex:"#00e5ff"),inf:$vm.axisZ.influence,phase:$vm.axisZ.phase,vis:$vm.axisZ.visible)
                    Divider().background(Color(hex:"#21262d"))
                    Text("ENVIRONMENT").font(.system(size:7,weight:.semibold,design:.monospaced)).foregroundColor(Color(hex:"#4a5568")).kerning(1.5)
                    ArcSl("Gravity",val:$vm.physics.gravity,range:0...20,unit:"m/s²")
                    ArcSl("Wind",val:$vm.physics.wind,range:0...200,unit:"mph")
                    ArcSl("Temp",val:$vm.physics.temperature,range:0...120,unit:"°F")
                    ArcSl("Humidity",val:$vm.physics.humidity,range:0...100,unit:"%")
                    ArcSl("Pressure",val:$vm.physics.pressure,range:0...30,unit:"PSI")
                    Divider().background(Color(hex:"#21262d"))
                    ArcToggle("Grid Planes",val:$vm.grid.enabled)
                    if vm.grid.enabled {
                        ArcSl("XZ count X",val:.init(get:{Double(vm.grid.xzCountX)},set:{vm.grid.xzCountX=Int($0.rounded())}),range:1...20,unit:"")
                        ArcSl("XZ count Z",val:.init(get:{Double(vm.grid.xzCountZ)},set:{vm.grid.xzCountZ=Int($0.rounded())}),range:1...20,unit:"")
                    }
                    Divider().background(Color(hex:"#21262d"))
                    Text("ARC EDGE MATH (doc=3.0)").font(.system(size:7,weight:.semibold,design:.monospaced)).foregroundColor(Color(hex:"#4a5568")).kerning(1.5)
                    Text("Circ=sqrt(d·3)²  Area=Circ²\nVol=Area³  SA=Vol·0.25\nBranch=Circ/8").font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#4a5568")).fixedSize(horizontal:false,vertical:true)
                }.padding(10)
            }
        }
    }
}
struct ArcToggle: View {
    let label:String; @Binding var val:Bool
    var body: some View { HStack{Text(label).font(.system(size:9,design:.monospaced)).foregroundColor(Color(hex:"#c9d1d9"));Spacer();Toggle("",isOn:$val).labelsHidden().tint(Color(hex:"#00e5ff")).scaleEffect(0.7)}}
}
struct ArcAxisCtrl: View {
    let label: String; let color: Color
    @Binding var inf: Double; @Binding var phase: Double; @Binding var vis: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(color).frame(width:7,height:7)
                Text(label).font(.system(size:8,weight:.semibold,design:.monospaced)).foregroundColor(color)
                Spacer()
                let btnLabel = vis ? "ON" : "OFF"
                let btnColor = vis ? color : Color(hex:"#4a5568")
                Button(btnLabel) { vis.toggle() }
                    .font(.system(size:7,weight:.bold,design:.monospaced))
                    .foregroundColor(btnColor)
                    .padding(.horizontal,5).padding(.vertical,2)
                    .background(vis ? color.opacity(0.15) : Color.clear)
                    .cornerRadius(3)
            }
            ArcSl("Influence", val: $inf, range: 0...1, unit: "")
            ArcSl("Phase",     val: $phase, range: 0...6.28, unit: "rad")
        }
    }
}
struct ArcSl: View {
    let label: String; @Binding var val: Double; let range: ClosedRange<Double>; let unit: String
    var body: some View {
        HStack {
            Text(label).font(.system(size:9,design:.monospaced)).foregroundColor(Color(hex:"#8ab4cc"))
                .frame(width:58,alignment:.leading)
            Slider(value: $val, in: range).tint(Color(hex:"#00e5ff"))
            let display = String(format: "%.2f", val) + (unit.isEmpty ? "" : " " + unit)
            Text(display).font(.system(size:8,design:.monospaced)).foregroundColor(Color(hex:"#00e5ff"))
                .frame(width:52,alignment:.trailing)
        }
    }
}
