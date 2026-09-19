//
//  IDEInterfaceView.swift — Always-present Interface tab
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
//
//  Direct port of the web app's Interface-tab restructure: a real,
//  always-present tab (not embedded inside Output) that shows the
//  running program's graphical surface when the script has real
//  graphical intent (generalized via AshRuntime.hasGraphicalIntent —
//  ANY script that imports GLDrivers or calls gl.*, not a hardcoded
//  example list), or a generic "Program Controls" panel — live
//  input fields driven by the script's own real declared variables
//  — for any script with interactive state but no graphics. A
//  script whose only interactive variable is literally named "expr"
//  (the Ash calculator convention) gets a real tappable keypad wired
//  to the same Research() evaluator the terminal uses.
//

import SwiftUI

struct IDEInterfaceView: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @EnvironmentObject var mazeVM:  MazeViewModel

    private var hasGraphics: Bool {
        AshRuntime.hasGraphicalIntent(ideVM.sourceCode)
    }

    private var runtime: AshRuntime? { ideVM.compiler.runtime }

    var body: some View {
        Group {
            if hasGraphics {
                IDEGLOutputPanel()
                    .id(ideVM.compiler.compilerLines.count)
            } else if let rt = runtime, rt.hasInteractiveState() {
                IDEProgramControlsPanel(runtime: rt)
                    .id(ideVM.compiler.compilerLines.count)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 32)).foregroundColor(Color(hex: "#00e5ff").opacity(0.3))
                    Text("This script has no graphical output")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568"))
                    Text("import (GLDrivers) or gl.* calls render here automatically after Build & Run")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(hex: "#4a5568").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#0d1117"))
            }
        }
    }
}

// MARK: - Program Controls — generic live-variable panel

struct IDEProgramControlsPanel: View {
    @EnvironmentObject var themeVM: IDEThemeViewModel
    @EnvironmentObject var ideVM:   IDEState
    @ObservedObject var runtimeBox: AshRuntimeBox

    init(runtime: AshRuntime) {
        self.runtimeBox = AshRuntimeBox(runtime: runtime)
    }

    private var interactiveVars: [String] {
        runtimeBox.runtime.listVars().filter { $0 != "s" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("◈ PROGRAM CONTROLS")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00e5ff")).kerning(2)

                if interactiveVars.count == 1 && interactiveVars[0] == "expr" {
                    IDECalculatorKeypad(runtimeBox: runtimeBox)
                } else {
                    IDEGenericControls(runtimeBox: runtimeBox, vars: interactiveVars)
                }

                if !runtimeBox.output.isEmpty {
                    Text(runtimeBox.output)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#0a0f14"))
                        .cornerRadius(10)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0d1117"))
    }
}

/// AshRuntime is a plain class, not an ObservableObject — this thin
/// wrapper lets the Program Controls views observe changes (a new
/// var value, a new run() output) without changing AshRuntime's own
/// shape, which stays a faithful 1:1 port of the JS runtime.
final class AshRuntimeBox: ObservableObject {
    @Published var runtime: AshRuntime
    @Published var output: String = ""
    init(runtime: AshRuntime) { self.runtime = runtime }

    func setVar(_ name: String, _ value: String) {
        runtime.setVar(name, value)
        objectWillChange.send()
    }
    func run() {
        output = runtime.run().joined(separator: "\n")
    }
}

// MARK: - Real calculator keypad — same evaluator the terminal uses

struct IDECalculatorKeypad: View {
    @ObservedObject var runtimeBox: AshRuntimeBox
    @State private var exprText = ""

    private let rows: [[String]] = [
        ["AC", "(", ")", "/"],
        ["7", "8", "9", "*"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["sqrt(", "0", ".", "="]
    ]

    var body: some View {
        VStack(spacing: 10) {
            Text(exprText.isEmpty ? "0" : exprText)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "#e8f4f2"))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(14)
                .background(Color(hex: "#0a0f14"))
                .cornerRadius(8)

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 7) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            Text(displayLabel(key))
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(color(for: key).fg)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(color(for: key).bg)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#141a22"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#00e5ff").opacity(0.2)))
    }

    private func displayLabel(_ key: String) -> String {
        switch key {
        case "*": return "×"
        case "/": return "÷"
        case "-": return "−"
        case "sqrt(": return "√"
        default: return key
        }
    }

    private func color(for key: String) -> (bg: Color, fg: Color) {
        switch key {
        case "AC": return (Color(hex: "#3a1a1a"), Color(hex: "#ff8a8a"))
        case "=": return (Color(hex: "#00e5ff"), Color(hex: "#00141a"))
        case "+", "-", "*", "/", "(", ")": return (Color(hex: "#0d3e46"), Color(hex: "#4dd8e8"))
        case "sqrt(": return (Color(hex: "#221a33"), Color(hex: "#b98cf0"))
        default: return (Color(hex: "#1f2932"), Color(hex: "#e8f4f2"))
        }
    }

    private func tap(_ key: String) {
        if key == "AC" {
            exprText = ""
        } else if key == "=" {
            runtimeBox.setVar("expr", exprText.isEmpty ? "0" : exprText)
            runtimeBox.run()
        } else {
            exprText += key
        }
    }
}

// MARK: - Generic labeled-fields controls for any other variable-driven script

struct IDEGenericControls: View {
    @ObservedObject var runtimeBox: AshRuntimeBox
    let vars: [String]
    @State private var fieldValues: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(vars, id: \.self) { name in
                VStack(alignment: .leading, spacing: 5) {
                    Text(name)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#8a97a3"))
                    TextField("", text: Binding(
                        get: { fieldValues[name] ?? runtimeBox.runtime.vars[name]?.asString ?? "" },
                        set: { fieldValues[name] = $0 }
                    ))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(hex: "#e8f4f2"))
                    .padding(10)
                    .background(Color(hex: "#0a0f14"))
                    .cornerRadius(6)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                }
            }
            Button {
                for name in vars {
                    if let v = fieldValues[name] { runtimeBox.setVar(name, v) }
                }
                runtimeBox.run()
            } label: {
                Text("▸ RUN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#00141a"))
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color(hex: "#00e5ff"))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(hex: "#141a22"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#00e5ff").opacity(0.2)))
    }
}
