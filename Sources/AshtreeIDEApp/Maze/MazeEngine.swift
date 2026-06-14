// ============================================================
//  MazeEngine.swift — Lead Edge Maze + Cryptology Engine
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Port of LEMAC_ENGINE from ashtreeide.html web app.
//  Improved randomized entry/exit from Autumn-iOS MazeEngine.swift.
//  D1/D2/D3 Lead Edge algebra: D3.e = path-solved axis iteration
// ============================================================

import Foundation
import SceneKit
import SwiftUI

// MARK: - Maze Cell

public struct MazeCell {
    // Planar (2D)
    public var N = true, E = true, S = true, W = true
    // Cubic (3D)
    public var top = true, bottom = true, left = true, right = true, front = true, back = true
    public var visited = false
    public var isPath  = false
}

// MARK: - Maze Config

public struct MazeConfig {
    public var width: Int    = 10
    public var height: Int   = 10
    public var depth: Int    = 10
    public var mode: Mode    = .cubic
    public var engine: EngineType = .reflective

    public enum Mode: String, CaseIterable {
        case planar = "Planar (2D)"
        case cubic  = "Cubic (3D)"
    }
    public enum EngineType: String, CaseIterable {
        case reflective = "Reflective"
        case dither     = "Dither"
    }
}

// MARK: - Maze Result

public struct MazeResult {
    public var planarGrid: [[MazeCell]]?
    public var cubicGrid:  [[[MazeCell]]]?
    public var entry: (x: Int, y: Int, z: Int)
    public var exit:  (x: Int, y: Int, z: Int)
    public var planarPath: [(x: Int, y: Int)]?
    public var cubicPath:  [(x: Int, y: Int, z: Int)]?
    public var mode: MazeConfig.Mode
    public var w: Int; public var h: Int; public var d: Int
}

// MARK: - LEMAC Engine (Lead Edge Maze Algorithm Core)

public final class LEMACEngine {

    // MARK: Planar generation — LEMAC algebraic byproduct (D3.e iteration)
    public static func generatePlanar(w: Int, h: Int) -> [[MazeCell]] {
        var g = Array(repeating: Array(repeating: MazeCell(), count: w), count: h)
        var stack: [(Int, Int)] = [(Int.random(in: 0..<w), Int.random(in: 0..<h))]
        g[stack[0].1][stack[0].0].visited = true
        var visitCount = 1
        let total = w * h

        let dirs: [(dx: Int, dy: Int, wall: WritableKeyPath<MazeCell, Bool>, opp: WritableKeyPath<MazeCell, Bool>)] = [
            (0, -1, \.N, \.S), (1, 0, \.E, \.W), (0, 1, \.S, \.N), (-1, 0, \.W, \.E)
        ]

        while visitCount < total, let (cx, cy) = stack.last {
            let neighbors = dirs.shuffled().compactMap { dir -> (Int, Int, WritableKeyPath<MazeCell, Bool>, WritableKeyPath<MazeCell, Bool>)? in
                let nx = cx + dir.dx, ny = cy + dir.dy
                guard nx >= 0 && nx < w && ny >= 0 && ny < h && !g[ny][nx].visited else { return nil }
                return (nx, ny, dir.wall, dir.opp)
            }
            if let (nx, ny, wall, opp) = neighbors.first {
                g[cy][cx][keyPath: wall] = false
                g[ny][nx][keyPath: opp]  = false
                g[ny][nx].visited = true
                stack.append((nx, ny))
                visitCount += 1
            } else {
                stack.removeLast()
            }
        }
        return g
    }

    // MARK: Randomized entry/exit for planar — from Autumn iOS improvement
    // Randomly on any perimeter edge, NOT just corners
    public static func placePlanarOpenings(w: Int, h: Int) -> (entry: (Int, Int), exit: (Int, Int)) {
        // Collect all perimeter cells
        var perimeter: [(Int, Int)] = []
        for x in 0..<w {
            perimeter.append((x, 0))       // top
            perimeter.append((x, h - 1))   // bottom
        }
        for y in 1..<(h-1) {
            perimeter.append((0, y))        // left
            perimeter.append((w - 1, y))   // right
        }
        let shuffled = perimeter.shuffled()
        let entry = shuffled[0]
        // Exit: must be far enough away (Manhattan distance > max(w,h)/2)
        let minDist = max(w, h) / 2
        let farCells = shuffled.filter { abs($0.0 - entry.0) + abs($0.1 - entry.1) >= minDist }
        let exit = farCells.randomElement() ?? shuffled.last!
        return (entry, exit)
    }

    // MARK: Cubic generation — D3 volumetric (matches web app generateCubic)
    public static func generateCubic(w: Int, h: Int, d: Int) -> [[[MazeCell]]] {
        var g = Array(repeating: Array(repeating: Array(repeating: MazeCell(), count: w), count: h), count: d)
        var stack: [(Int, Int, Int)] = [(0, 0, 0)]
        g[0][0][0].visited = true
        var visitCount = 1
        let total = w * h * d

        typealias Dir = (dx: Int, dy: Int, dz: Int,
                         wall: WritableKeyPath<MazeCell, Bool>,
                         opp:  WritableKeyPath<MazeCell, Bool>)
        let dirs: [Dir] = [
            (0,-1,0, \.top,    \.bottom),
            (0, 1,0, \.bottom, \.top),
            (-1,0,0, \.left,   \.right),
            (1, 0,0, \.right,  \.left),
            (0, 0,1, \.front,  \.back),
            (0, 0,-1,\.back,   \.front)
        ]

        while visitCount < total, let (cx, cy, cz) = stack.last {
            let neighbors = dirs.shuffled().compactMap { dir -> (Int,Int,Int, WritableKeyPath<MazeCell,Bool>, WritableKeyPath<MazeCell,Bool>)? in
                let nx = cx+dir.dx, ny = cy+dir.dy, nz = cz+dir.dz
                guard nx >= 0 && nx < w && ny >= 0 && ny < h && nz >= 0 && nz < d && !g[nz][ny][nx].visited else { return nil }
                return (nx, ny, nz, dir.wall, dir.opp)
            }
            if let (nx, ny, nz, wall, opp) = neighbors.first {
                g[cz][cy][cx][keyPath: wall] = false
                g[nz][ny][nx][keyPath: opp]  = false
                g[nz][ny][nx].visited = true
                stack.append((nx, ny, nz))
                visitCount += 1
            } else {
                stack.removeLast()
            }
        }
        return g
    }

    // MARK: Randomized entry/exit for cubic — Autumn iOS pattern
    // Random cells on any outer face, far apart
    public static func placeCubicOpenings(w: Int, h: Int, d: Int) -> (entry: (Int,Int,Int), exit: (Int,Int,Int)) {
        var faces: [(Int, Int, Int)] = []
        let lx = w-1, ly = h-1, lz = d-1
        for y in 0..<h { for z in 0..<d {
            faces.append((0, y, z)); faces.append((lx, y, z))
        }}
        for x in 0..<w { for z in 0..<d {
            faces.append((x, 0, z)); faces.append((x, ly, z))
        }}
        for x in 0..<w { for y in 0..<h {
            faces.append((x, y, 0)); faces.append((x, y, lz))
        }}
        let shuffled = faces.shuffled()
        let entry = shuffled[0]
        let minDist = max(w, max(h, d))
        let far = shuffled.filter { abs($0.0 - entry.0) + abs($0.1 - entry.1) + abs($0.2 - entry.2) >= minDist }
        let exit = far.randomElement() ?? shuffled.last!
        return (entry, exit)
    }

    // MARK: BFS solvers

    public static func solvePlanar(_ g: [[MazeCell]], start: (Int,Int), end: (Int,Int), w: Int, h: Int) -> [(Int,Int)]? {
        var visited = Set<String>()
        var queue: [(path: [(Int,Int)], pos: (Int,Int))] = [([start], start)]
        visited.insert("\(start.0),\(start.1)")
        let dirs = [(0,-1,\MazeCell.N),(1,0,\MazeCell.E),(0,1,\MazeCell.S),(-1,0,\MazeCell.W)] as [(Int,Int,KeyPath<MazeCell,Bool>)]
        while !queue.isEmpty {
            let (path, (cx, cy)) = queue.removeFirst()
            if cx == end.0 && cy == end.1 { return path }
            for (dx, dy, wall) in dirs {
                guard !g[cy][cx][keyPath: wall] else { continue }
                let nx = cx+dx, ny = cy+dy
                guard nx>=0&&nx<w&&ny>=0&&ny<h else { continue }
                let k = "\(nx),\(ny)"
                guard !visited.contains(k) else { continue }
                visited.insert(k)
                queue.append((path + [(nx, ny)], (nx, ny)))
            }
        }
        return nil
    }

    public static func solveCubic(_ g: [[[MazeCell]]], start: (Int,Int,Int), end: (Int,Int,Int), w: Int, h: Int, d: Int) -> [(Int,Int,Int)]? {
        var visited = Set<String>()
        var queue: [(path: [(Int,Int,Int)], pos: (Int,Int,Int))] = [([start], start)]
        visited.insert("\(start.0),\(start.1),\(start.2)")
        typealias Dir = (Int,Int,Int,KeyPath<MazeCell,Bool>)
        let dirs: [Dir] = [(0,-1,0,\.top),(0,1,0,\.bottom),(-1,0,0,\.left),(1,0,0,\.right),(0,0,1,\.front),(0,0,-1,\.back)]
        while !queue.isEmpty {
            let (path, (cx,cy,cz)) = queue.removeFirst()
            if cx==end.0 && cy==end.1 && cz==end.2 { return path }
            for (dx,dy,dz,wall) in dirs {
                guard !g[cz][cy][cx][keyPath: wall] else { continue }
                let nx=cx+dx, ny=cy+dy, nz=cz+dz
                guard nx>=0&&nx<w&&ny>=0&&ny<h&&nz>=0&&nz<d else { continue }
                let k = "\(nx),\(ny),\(nz)"
                guard !visited.contains(k) else { continue }
                visited.insert(k)
                queue.append((path + [(nx,ny,nz)], (nx,ny,nz)))
            }
        }
        return nil
    }
}

// MARK: - Maze ViewModel

@MainActor
public final class MazeViewModel: ObservableObject {

    @Published public var config = MazeConfig()
    @Published public var result: MazeResult?
    @Published public var isGenerating = false
    @Published public var showSolution = false
    @Published public var statusText = "Configure and generate a maze"
    @Published public var sceneNode: SCNNode?

    public func generate() {
        isGenerating = true
        statusText = "Generating…"
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let cfg = await self.config
            var res: MazeResult

            if cfg.mode == .planar {
                let g = LEMACEngine.generatePlanar(w: cfg.width, h: cfg.height)
                let (entry, exit) = LEMACEngine.placePlanarOpenings(w: cfg.width, h: cfg.height)
                let path = LEMACEngine.solvePlanar(g, start: entry, end: exit, w: cfg.width, h: cfg.height)
                res = MazeResult(planarGrid: g, cubicGrid: nil,
                                 entry: (entry.0, entry.1, 0), exit: (exit.0, exit.1, 0),
                                 planarPath: path, cubicPath: nil,
                                 mode: .planar, w: cfg.width, h: cfg.height, d: 1)
            } else {
                let g = LEMACEngine.generateCubic(w: cfg.width, h: cfg.height, d: cfg.depth)
                let (entry, exit) = LEMACEngine.placeCubicOpenings(w: cfg.width, h: cfg.height, d: cfg.depth)
                let path = LEMACEngine.solveCubic(g, start: entry, end: exit,
                                                   w: cfg.width, h: cfg.height, d: cfg.depth)
                res = MazeResult(planarGrid: nil, cubicGrid: g,
                                 entry: entry, exit: exit,
                                 planarPath: nil, cubicPath: path,
                                 mode: .cubic, w: cfg.width, h: cfg.height, d: cfg.depth)
            }

            let node = await self.buildScene(result: res)
            await MainActor.run { [weak self] in
                self?.result = res
                self?.sceneNode = node
                self?.isGenerating = false
                self?.statusText = "Generated \(cfg.mode == .planar ? "\(cfg.width)×\(cfg.height)" : "\(cfg.width)×\(cfg.height)×\(cfg.depth)") maze · \(res.cubicPath?.count ?? res.planarPath?.count ?? 0) path steps"
            }
        }
    }

    public func showSolutionPath() {
        guard let r = result else { return }
        showSolution = true
        let pathNode = buildPathNode(result: r)
        sceneNode?.addChildNode(pathNode)
    }

    // MARK: - SceneKit Scene Builder

    private func buildScene(result r: MazeResult) -> SCNNode {
        let root = SCNNode()
        let s: Float = 0.5   // cell size
        let t: Float = 0.025 // wall thickness

        let wallMat = SCNMaterial()
        wallMat.diffuse.contents  = UIColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 0.45)
        wallMat.emission.contents = UIColor(red: 0.0, green: 0.4, blue: 0.3, alpha: 0.15)
        wallMat.lightingModel = .physicallyBased
        wallMat.metalness.contents = 0.9
        wallMat.roughness.contents = 0.1
        wallMat.isDoubleSided = true

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
            let ox = Float(w) * s * 0.5
            let oz = Float(h) * s * 0.5

            for y in 0..<h { for x in 0..<w {
                let cell = g[y][x]
                let cx = Float(x) * s - ox + s * 0.5
                let cz = Float(y) * s - oz + s * 0.5

                // E wall
                if cell.E && x < w-1 {
                    let geo = SCNBox(width: CGFloat(t), height: CGFloat(s), length: CGFloat(s), chamferRadius: 0)
                    let n = SCNNode(geometry: geo)
                    n.geometry?.firstMaterial = wallMat
                    n.position = SCNVector3(cx + s*0.5, 0, cz)
                    root.addChildNode(n)
                }
                // S wall
                if cell.S && y < h-1 {
                    let geo = SCNBox(width: CGFloat(s), height: CGFloat(s), length: CGFloat(t), chamferRadius: 0)
                    let n = SCNNode(geometry: geo)
                    n.geometry?.firstMaterial = wallMat
                    n.position = SCNVector3(cx, 0, cz + s*0.5)
                    root.addChildNode(n)
                }
            }}

            // Perimeter (skipping entry/exit openings)
            let (ex, ey) = (r.entry.x, r.entry.y)
            let (xx, xy) = (r.exit.x, r.exit.y)

            for x in 0..<w {
                if !(ex == x && ey == 0) && !(xx == x && xy == 0) {
                    let geo = SCNBox(width: CGFloat(s), height: CGFloat(s), length: CGFloat(t), chamferRadius: 0)
                    let n = SCNNode(geometry: geo); n.geometry?.firstMaterial = wallMat
                    n.position = SCNVector3(Float(x)*s - ox + s*0.5, 0, -oz)
                    root.addChildNode(n)
                }
                if !(ex == x && ey == h-1) && !(xx == x && xy == h-1) {
                    let geo = SCNBox(width: CGFloat(s), height: CGFloat(s), length: CGFloat(t), chamferRadius: 0)
                    let n = SCNNode(geometry: geo); n.geometry?.firstMaterial = wallMat
                    n.position = SCNVector3(Float(x)*s - ox + s*0.5, 0, Float(h)*s - oz)
                    root.addChildNode(n)
                }
            }
            for y in 0..<h {
                if !(ex == 0 && ey == y) && !(xx == 0 && xy == y) {
                    let geo = SCNBox(width: CGFloat(t), height: CGFloat(s), length: CGFloat(s), chamferRadius: 0)
                    let n = SCNNode(geometry: geo); n.geometry?.firstMaterial = wallMat
                    n.position = SCNVector3(-ox, 0, Float(y)*s - oz + s*0.5)
                    root.addChildNode(n)
                }
                if !(ex == w-1 && ey == y) && !(xx == w-1 && xy == y) {
                    let geo = SCNBox(width: CGFloat(t), height: CGFloat(s), length: CGFloat(s), chamferRadius: 0)
                    let n = SCNNode(geometry: geo); n.geometry?.firstMaterial = wallMat
                    n.position = SCNVector3(Float(w)*s - ox, 0, Float(y)*s - oz + s*0.5)
                    root.addChildNode(n)
                }
            }

        } else if r.mode == .cubic, let g = r.cubicGrid {
            let w = r.w, h = r.h, d = r.d
            let ox = Float(w)*s*0.5, oy = Float(h)*s*0.5, oz = Float(d)*s*0.5

            for z in 0..<d { for y in 0..<h { for x in 0..<w {
                let cell = g[z][y][x]
                let cx = Float(x)*s - ox + s*0.5
                let cy = Float(y)*s - oy + s*0.5
                let cz = Float(z)*s - oz + s*0.5
                let tube = SCNCylinder(radius: CGFloat(t), height: CGFloat(s*0.48))
                tube.radialSegmentCount = 6
                let mat = SCNMaterial()
                mat.diffuse.contents  = UIColor(red:0,green:0.9,blue:1,alpha:0.5)
                mat.emission.contents = UIColor(red:0,green:0.4,blue:0.5,alpha:0.3)
                mat.lightingModel = .constant

                func addTube(dx: Float, dy: Float, dz: Float, angle: SCNVector3) {
                    let n = SCNNode(geometry: tube)
                    n.geometry?.firstMaterial = mat
                    n.position = SCNVector3(cx+dx*s*0.25, cy+dy*s*0.25, cz+dz*s*0.25)
                    n.eulerAngles = angle
                    root.addChildNode(n)
                }
                if !cell.right  { addTube(dx:1,dy:0,dz:0, angle:SCNVector3(0,0,Float.pi/2)) }
                if !cell.top    { addTube(dx:0,dy:1,dz:0, angle:SCNVector3(0,0,0)) }
                if !cell.front  { addTube(dx:0,dy:0,dz:1, angle:SCNVector3(Float.pi/2,0,0)) }

                // Cell sphere
                let sphere = SCNSphere(radius: CGFloat(t*1.5))
                sphere.segmentCount = 6
                sphere.firstMaterial = mat
                let sn = SCNNode(geometry: sphere)
                sn.position = SCNVector3(cx, cy, cz)
                root.addChildNode(sn)
            }}}
        }

        // Entry marker
        let entrySphere = SCNSphere(radius: 0.06)
        entrySphere.firstMaterial = entryMat
        let entryNode = SCNNode(geometry: entrySphere)
        entryNode.position = SCNVector3(
            Float(r.entry.x)*s - Float(r.w)*s*0.5 + s*0.5,
            Float(r.entry.y)*s - Float(r.h)*s*0.5 + s*0.5,
            Float(r.entry.z)*s - Float(r.d)*s*0.5 + s*0.5)
        root.addChildNode(entryNode)

        // Exit marker
        let exitSphere = SCNSphere(radius: 0.06)
        exitSphere.firstMaterial = exitMat
        let exitNode = SCNNode(geometry: exitSphere)
        exitNode.position = SCNVector3(
            Float(r.exit.x)*s - Float(r.w)*s*0.5 + s*0.5,
            Float(r.exit.y)*s - Float(r.h)*s*0.5 + s*0.5,
            Float(r.exit.z)*s - Float(r.d)*s*0.5 + s*0.5)
        root.addChildNode(exitNode)

        return root
    }

    private func buildPathNode(result r: MazeResult) -> SCNNode {
        let root = SCNNode()
        let s: Float = 0.5
        let pathMat = SCNMaterial()
        pathMat.diffuse.contents  = UIColor(red: 0.8, green: 0.0, blue: 1.0, alpha: 0.9)
        pathMat.emission.contents = UIColor(red: 0.4, green: 0.0, blue: 0.5, alpha: 0.5)
        pathMat.lightingModel = .constant

        if let path = r.planarPath {
            for (x, y) in path {
                let plane = SCNPlane(width: CGFloat(s*0.8), height: CGFloat(s*0.8))
                plane.firstMaterial = pathMat
                let n = SCNNode(geometry: plane)
                n.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
                n.position = SCNVector3(Float(x)*s - Float(r.w)*s*0.5 + s*0.5,
                                        0.05,
                                        Float(y)*s - Float(r.h)*s*0.5 + s*0.5)
                root.addChildNode(n)
            }
        } else if let path = r.cubicPath {
            for (x, y, z) in path {
                let box = SCNBox(width: CGFloat(s*0.4), height: CGFloat(s*0.4), length: CGFloat(s*0.4), chamferRadius: 0)
                box.firstMaterial = pathMat
                let n = SCNNode(geometry: box)
                n.position = SCNVector3(Float(x)*s - Float(r.w)*s*0.5 + s*0.5,
                                        Float(y)*s - Float(r.h)*s*0.5 + s*0.5,
                                        Float(z)*s - Float(r.d)*s*0.5 + s*0.5)
                root.addChildNode(n)
            }
        }
        return root
    }
}
