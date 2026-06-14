// ============================================================
//  ThemeSystem.swift — IDE Theme Engine
//  Ash Tree IDE · © 2025 DART Meadow | Radical Deepscale LLC.
// ============================================================

import SwiftUI

@MainActor
public final class IDEThemeViewModel: ObservableObject {

    public enum Theme: String, CaseIterable {
        case dark       = "Dark"
        case stealth    = "Stealth"
        case ashTree    = "Ash Tree"
        case neon       = "Neon"
        case arctic     = "Arctic"
        case solar      = "Solar"
        case molten     = "Molten"
        case quantum    = "Quantum"
        case light      = "Light"

        public var bg: Color {
            switch self {
            case .dark:     return Color(hex: "#0d1117")
            case .stealth:  return Color(hex: "#060a10")
            case .ashTree:  return Color(hex: "#0a140a")
            case .neon:     return Color(hex: "#080010")
            case .arctic:   return Color(hex: "#001428")
            case .solar:    return Color(hex: "#140a00")
            case .molten:   return Color(hex: "#140500")
            case .quantum:  return Color(hex: "#050014")
            case .light:    return Color(hex: "#f5f5f5")
            }
        }

        public var surface: Color {
            switch self {
            case .light: return Color(hex: "#ffffff")
            default:     return bg.opacity(0.7)
            }
        }

        public var accent: Color {
            switch self {
            case .dark:     return Color(hex: "#00e5ff")
            case .stealth:  return Color(hex: "#00e5ff")
            case .ashTree:  return Color(hex: "#44ff88")
            case .neon:     return Color(hex: "#ff00ff")
            case .arctic:   return Color(hex: "#88ddff")
            case .solar:    return Color(hex: "#ffaa00")
            case .molten:   return Color(hex: "#ff4400")
            case .quantum:  return Color(hex: "#8800ff")
            case .light:    return Color(hex: "#0066cc")
            }
        }

        public var text: Color {
            switch self {
            case .light: return Color(hex: "#111111")
            default:     return Color(hex: "#c9d1d9")
            }
        }

        public var dim: Color {
            switch self {
            case .light: return Color(hex: "#666666")
            default:     return Color(hex: "#4a5568")
            }
        }

        public var border: Color {
            switch self {
            case .light: return Color(hex: "#e0e0e0")
            default:     return Color(hex: "#21262d")
            }
        }

        // Editor syntax colors
        public var syntaxKeyword:    Color { Color(hex: "#00e5ff") }
        public var syntaxDeclaration: Color { Color(hex: "#9cdcfe") }
        public var syntaxTool:       Color { Color(hex: "#bf5fff") }
        public var syntaxString:     Color { Color(hex: "#ce9178") }
        public var syntaxComment:    Color { Color(hex: "#4a8a7a") }
        public var syntaxOuterTag:   Color { Color(hex: "#ffd700") }
        public var syntaxInnerTag:   Color { Color(hex: "#bf5fff") }
        public var syntaxPolyTag:    Color { Color(hex: "#ff9500") }
        public var syntaxNetTag:     Color { Color(hex: "#39ff14") }
        public var syntaxNodeStart:  Color { Color(hex: "#00ffcc") }
        public var syntaxNumber:     Color { Color(hex: "#b5cea8") }

        // Terminal colors
        public var termBg:      Color { Color(hex: "#0d1117") }
        public var termAccent:  Color { accent }
        public var termText:    Color { Color(hex: "#e6edf3") }
        public var termDim:     Color { Color(hex: "#4a5568") }
        public var termSystem:  Color { Color(hex: "#4a8a7a") }
        public var termError:   Color { Color(hex: "#ff4466") }
    }

    @Published public var current: Theme = Theme(
        rawValue: UserDefaults.standard.string(forKey: "ide_theme") ?? "dark"
    ) ?? .dark {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "ide_theme") }
    }

    public var bg: Color      { current.bg }
    public var surface: Color { current.surface }
    public var accent: Color  { current.accent }
    public var text: Color    { current.text }
    public var dim: Color     { current.dim }
    public var border: Color  { current.border }
    public var isDark: Bool   { current != .light }

    public func colorScheme() -> ColorScheme { isDark ? .dark : .light }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 3:  (r,g,b,a) = ((int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17,255)
        case 6:  (r,g,b,a) = (int>>16, int>>8&0xFF, int&0xFF, 255)
        case 8:  (r,g,b,a) = (int>>24, int>>16&0xFF, int>>8&0xFF, int&0xFF)
        default: (r,g,b,a) = (0,0,0,255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}
