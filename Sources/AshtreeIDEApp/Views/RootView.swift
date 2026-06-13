// ============================================================
//  RootView.swift — Entry, Splash, Auth gate
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

struct RootView: View {
    @EnvironmentObject var github: GitHubService
    @EnvironmentObject var ide: IDEState

    var body: some View {
        ZStack {
            if ide.showSplash {
                SplashView()
                    .transition(.opacity)
            } else if github.session == nil {
                AuthView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                MainIDEView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: ide.showSplash)
        .animation(.easeInOut(duration: 0.35), value: github.session == nil)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { ide.showSplash = false }
            }
        }
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var treePulse = false
    @State private var titleOpacity = 0.0
    @State private var subtitleOpacity = 0.0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Vector logo mark — Ash Tree frame in ash-frame dark green
                AshTreeLogoMark(size: 120)
                    .scaleEffect(treePulse ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: treePulse)
                    .onAppear { treePulse = true }

                Spacer().frame(height: 32)

                // Wordmark
                VStack(spacing: 6) {
                    Text("ASH TREE IDE")
                        .font(.custom("Georgia-Bold", size: 28))
                        .foregroundColor(Color("AshDark"))
                        .kerning(6)
                        .opacity(titleOpacity)
                    Text("LEATR · Lead Edge Ash Tree Reflex")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color("AshMid"))
                        .kerning(2)
                        .opacity(subtitleOpacity)
                    Text("© 2025 DART Meadow | Radical Deepscale LLC.")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(Color("AshMid").opacity(0.6))
                        .kerning(1)
                        .opacity(subtitleOpacity)
                }

                Spacer()

                // Boot line
                Text("Initializing compiler standard…")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color("AshMid").opacity(0.4))
                    .opacity(subtitleOpacity)
                    .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6).delay(0.3))  { titleOpacity = 1 }
            withAnimation(.easeIn(duration: 0.6).delay(0.65)) { subtitleOpacity = 1 }
        }
    }
}

// MARK: - Ash Tree Logo Mark (vector, pure SwiftUI)

struct AshTreeLogoMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let cx = w / 2, cy = h / 2

            // Draw the LEATR frame — the hardware syntax shell shape
            // Outer algebraic frame (red compiler posts)
            let frameRect = CGRect(x: w*0.12, y: h*0.05, width: w*0.76, height: h*0.90)
            var framePath = Path()
            framePath.addRoundedRect(in: frameRect, cornerSize: CGSize(width: 8, height: 8))
            ctx.stroke(framePath, with: .color(Color("FrameRed")), lineWidth: 3)

            // Inner cyan tag walls — peripheral form
            let innerRect = CGRect(x: w*0.20, y: h*0.14, width: w*0.60, height: h*0.72)
            var innerPath = Path()
            innerPath.addRoundedRect(in: innerRect, cornerSize: CGSize(width: 5, height: 5))
            ctx.stroke(innerPath, with: .color(Color("InnerCyan")), lineWidth: 1.5)

            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: cx, y: h*0.88))
            trunk.addCurve(
                to: CGPoint(x: cx, y: h*0.52),
                control1: CGPoint(x: cx - w*0.04, y: h*0.78),
                control2: CGPoint(x: cx + w*0.04, y: h*0.62)
            )
            ctx.stroke(trunk, with: .color(Color("AshDark")), style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Branches — recursive fan mirroring Arc Edge 1/8 circle arcs
            let branchData: [(startY: CGFloat, endX: CGFloat, endY: CGFloat, ctrl1: CGPoint, ctrl2: CGPoint)] = [
                // Level 2 branches
                (0.52, cx - w*0.28, h*0.32, CGPoint(x: cx - w*0.08, y: h*0.50), CGPoint(x: cx - w*0.20, y: h*0.40)),
                (0.52, cx + w*0.28, h*0.32, CGPoint(x: cx + w*0.08, y: h*0.50), CGPoint(x: cx + w*0.20, y: h*0.40)),
                (0.52, cx,          h*0.20, CGPoint(x: cx - w*0.02, y: h*0.44), CGPoint(x: cx + w*0.02, y: h*0.32)),
                // Level 3 sub-branches
                (0.32, cx - w*0.36, h*0.18, CGPoint(x: cx - w*0.28, y: h*0.28), CGPoint(x: cx - w*0.34, y: h*0.22)),
                (0.32, cx - w*0.18, h*0.14, CGPoint(x: cx - w*0.22, y: h*0.26), CGPoint(x: cx - w*0.18, y: h*0.18)),
                (0.32, cx + w*0.36, h*0.18, CGPoint(x: cx + w*0.28, y: h*0.28), CGPoint(x: cx + w*0.34, y: h*0.22)),
                (0.32, cx + w*0.18, h*0.14, CGPoint(x: cx + w*0.22, y: h*0.26), CGPoint(x: cx + w*0.18, y: h*0.18)),
                (0.20, cx - w*0.12, h*0.10, CGPoint(x: cx - w*0.04, y: h*0.16), CGPoint(x: cx - w*0.10, y: h*0.12)),
                (0.20, cx + w*0.12, h*0.10, CGPoint(x: cx + w*0.04, y: h*0.16), CGPoint(x: cx + w*0.10, y: h*0.12)),
            ]

            for (idx, b) in branchData.enumerated() {
                let thickness: CGFloat = idx < 3 ? 3.0 : 2.0
                var branch = Path()
                branch.move(to: CGPoint(x: cx, y: h * b.startY))
                branch.addCurve(to: CGPoint(x: b.endX, y: b.endY),
                                control1: b.ctrl1, control2: b.ctrl2)
                ctx.stroke(branch, with: .color(Color("AshDark")), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            }

            // Leaf dots at branch tips
            let leafPositions: [CGPoint] = [
                CGPoint(x: cx - w*0.36, y: h*0.18),
                CGPoint(x: cx - w*0.18, y: h*0.14),
                CGPoint(x: cx, y: h*0.20),
                CGPoint(x: cx + w*0.36, y: h*0.18),
                CGPoint(x: cx + w*0.18, y: h*0.14),
                CGPoint(x: cx - w*0.12, y: h*0.10),
                CGPoint(x: cx + w*0.12, y: h*0.10),
            ]
            for pt in leafPositions {
                var leaf = Path()
                leaf.addEllipse(in: CGRect(x: pt.x-4, y: pt.y-4, width: 8, height: 8))
                ctx.fill(leaf, with: .color(Color("AshDark")))
            }

            // Roots
            let rootData: [(startX: CGFloat, endX: CGFloat, endY: CGFloat)] = [
                (cx, cx - w*0.22, h*0.96),
                (cx, cx + w*0.22, h*0.96),
                (cx, cx - w*0.10, h*0.98),
                (cx, cx + w*0.10, h*0.98),
            ]
            for r in rootData {
                var root = Path()
                root.move(to: CGPoint(x: r.startX, y: h*0.88))
                root.addLine(to: CGPoint(x: r.endX, y: r.endY))
                ctx.stroke(root, with: .color(Color("AshDark").opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
    }
}
