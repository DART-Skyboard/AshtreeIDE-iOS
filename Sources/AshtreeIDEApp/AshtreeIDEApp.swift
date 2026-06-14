// ============================================================
//  AshtreeIDEApp.swift — App Entry Point
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

@main
struct AshtreeIDEApp: App {
    @StateObject private var authVM  = IDEAuthViewModel()
    @StateObject private var themeVM = IDEThemeViewModel()
    @StateObject private var ideVM   = IDEState()
    @StateObject private var mazeVM  = MazeViewModel()

    var body: some Scene {
        WindowGroup {
            IDERootView()
                .environmentObject(authVM)
                .environmentObject(themeVM)
                .environmentObject(ideVM)
                .environmentObject(mazeVM)
                .preferredColorScheme(themeVM.colorScheme())
        }
    }
}

// MARK: - Root View

struct IDERootView: View {
    @EnvironmentObject var authVM:  IDEAuthViewModel
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            themeVM.bg.ignoresSafeArea()

            if showSplash {
                IDESplashView(onDone: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                })
                .transition(.opacity)
                .zIndex(10)
            } else if !authVM.isSignedIn {
                IDEWelcomeView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                IDEMainView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authVM.isSignedIn)
        .animation(.easeInOut(duration: 0.45), value: showSplash)
        .onAppear {
            authVM.restoreSession()
        }
    }
}

// MARK: - Splash Screen

struct IDESplashView: View {
    let onDone: () -> Void
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var tagOpacity: Double = 0
    @State private var pulseAnim = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0d1b3e"), Color(hex: "#0a140a")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo orb — matches ArcLake pattern
                ZStack {
                    // Pulse rings
                    Circle()
                        .stroke(themeVM.accent.opacity(0.08), lineWidth: 1)
                        .frame(width: pulseAnim ? 230 : 190, height: pulseAnim ? 230 : 190)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                                   value: pulseAnim)
                    Circle()
                        .stroke(themeVM.accent.opacity(0.15), lineWidth: 1)
                        .frame(width: 160, height: 160)
                    Circle()
                        .fill(Color(hex: "#0d1b3e").opacity(0.6))
                        .frame(width: 148, height: 148)

                    // Logo image
                    if let logo = UIImage(named: "AppLogo") {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                    } else {
                        // Fallback SVG-style canvas
                        IDELogoMark(size: 140, accent: themeVM.accent)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                    pulseAnim = true
                }

                Spacer().frame(height: 32)

                // Wordmark
                VStack(spacing: 6) {
                    Text("ASH TREE IDE")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .kerning(6)
                        .opacity(titleOpacity)

                    Text("LEATR · Lead Edge Ash Tree Reflex")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(themeVM.accent.opacity(0.7))
                        .kerning(2)
                        .opacity(tagOpacity)

                    Text("© 2025 DART Meadow | Radical Deepscale LLC.")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .kerning(1)
                        .opacity(tagOpacity)
                }

                Spacer()

                // Boot line
                Text("Initializing compiler standard…")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeVM.accent.opacity(0.3))
                    .opacity(tagOpacity)
                    .padding(.bottom, 52)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5).delay(0.4))  { titleOpacity = 1 }
            withAnimation(.easeIn(duration: 0.5).delay(0.7))  { tagOpacity = 1 }
            // Auto-dismiss after 2.2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onDone() }
        }
    }
}

// MARK: - Fallback Logo Mark (canvas-drawn when image asset missing)

struct IDELogoMark: View {
    let size: CGFloat
    let accent: Color

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height, cx = w/2

            // Curly braces (left = purple, right = cyan — from the logo)
            ctx.withCGContext { cg in
                cg.setStrokeColor(UIColor(red:0.6,green:0.2,blue:1.0,alpha:1).cgColor)
                cg.setLineWidth(3)
                let lp = CGMutablePath()
                lp.move(to: CGPoint(x: w*0.25, y: h*0.15))
                lp.addCurve(to: CGPoint(x: w*0.15, y: h*0.35),
                            control1: CGPoint(x: w*0.18, y: h*0.15),
                            control2: CGPoint(x: w*0.15, y: h*0.25))
                lp.addCurve(to: CGPoint(x: w*0.25, y: h*0.5),
                            control1: CGPoint(x: w*0.15, y: h*0.45),
                            control2: CGPoint(x: w*0.25, y: h*0.5))
                lp.addCurve(to: CGPoint(x: w*0.15, y: h*0.65),
                            control1: CGPoint(x: w*0.25, y: h*0.5),
                            control2: CGPoint(x: w*0.15, y: h*0.55))
                lp.addCurve(to: CGPoint(x: w*0.25, y: h*0.85),
                            control1: CGPoint(x: w*0.15, y: h*0.75),
                            control2: CGPoint(x: w*0.18, y: h*0.85))
                cg.addPath(lp)
                cg.strokePath()

                // Right brace (cyan)
                cg.setStrokeColor(UIColor(red:0.0,green:0.9,blue:1.0,alpha:1).cgColor)
                let rp = CGMutablePath()
                rp.move(to: CGPoint(x: w*0.75, y: h*0.15))
                rp.addCurve(to: CGPoint(x: w*0.85, y: h*0.35),
                            control1: CGPoint(x: w*0.82, y: h*0.15),
                            control2: CGPoint(x: w*0.85, y: h*0.25))
                rp.addCurve(to: CGPoint(x: w*0.75, y: h*0.5),
                            control1: CGPoint(x: w*0.85, y: h*0.45),
                            control2: CGPoint(x: w*0.75, y: h*0.5))
                rp.addCurve(to: CGPoint(x: w*0.85, y: h*0.65),
                            control1: CGPoint(x: w*0.75, y: h*0.5),
                            control2: CGPoint(x: w*0.85, y: h*0.55))
                rp.addCurve(to: CGPoint(x: w*0.75, y: h*0.85),
                            control1: CGPoint(x: w*0.85, y: h*0.75),
                            control2: CGPoint(x: w*0.82, y: h*0.85))
                cg.addPath(rp)
                cg.strokePath()
            }

            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: cx, y: h*0.85))
            trunk.addCurve(to: CGPoint(x: cx, y: h*0.52),
                           control1: CGPoint(x: cx-w*0.04, y: h*0.75),
                           control2: CGPoint(x: cx+w*0.04, y: h*0.62))
            ctx.stroke(trunk, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            // Branches
            let branches: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [
                (0.52, 0.32, -0.22, 0.05),
                (0.52, 0.32, 0.22, 0.05),
                (0.52, 0.24, 0.0, -0.04),
            ]
            for (sy, ey, dx, _) in branches {
                var b = Path()
                b.move(to: CGPoint(x: cx, y: h*sy))
                b.addCurve(to: CGPoint(x: cx+w*dx, y: h*ey),
                           control1: CGPoint(x: cx+w*dx*0.3, y: h*(sy-0.08)),
                           control2: CGPoint(x: cx+w*dx*0.8, y: h*(ey+0.05)))
                ctx.stroke(b, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

            // Maze roots
            ctx.withCGContext { cg in
                cg.setStrokeColor(UIColor(red:0.0,green:0.7,blue:1.0,alpha:0.7).cgColor)
                cg.setLineWidth(1.5)
                let steps: [(CGFloat,CGFloat)] = [
                    (-0.1,0.05),(0.05,-0.05),(0.08,0.05),(0.05,-0.05),(0.1,0.05)
                ]
                var mx = cx, my = h*0.85
                cg.move(to: CGPoint(x: mx, y: my))
                for (dx, dy) in steps { mx += w*dx; my += h*dy; cg.addLine(to: CGPoint(x: mx, y: my)) }
                cg.strokePath()
            }
        }
        .frame(width: size, height: size)
    }
}
