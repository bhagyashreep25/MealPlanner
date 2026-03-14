import SwiftUI

// MARK: - Color Palette

enum MPColors {
    // Primary greens
    static let primary = Color(hex: "2E7D32")
    static let primaryLight = Color(hex: "4CAF50")
    static let primarySoft = Color(hex: "E8F5E9")
    static let primaryMuted = Color(hex: "A5D6A7")

    // Neutrals
    static let background = Color(hex: "FAFAFA")
    static let surface = Color.white
    static let surfaceSecondary = Color(hex: "F5F5F5")
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "6B6B6B")
    static let textTertiary = Color(hex: "9E9E9E")
    static let divider = Color(hex: "E0E0E0")
    static let shadow = Color.black.opacity(0.06)

    // Semantic
    static let error = Color(hex: "D32F2F")
    static let warning = Color(hex: "F57C00")

    // Dark mode variants
    static let backgroundDark = Color(hex: "121212")
    static let surfaceDark = Color(hex: "1E1E1E")
    static let surfaceSecondaryDark = Color(hex: "2C2C2C")
}

// MARK: - Typography

enum MPTypography {
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 32, weight: weight, design: .rounded)
    }

    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 24, weight: weight, design: .rounded)
    }

    static func title2(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 20, weight: weight, design: .rounded)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 17, weight: weight, design: .rounded)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 15, weight: weight, design: .rounded)
    }

    static func callout(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 14, weight: weight, design: .rounded)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 12, weight: weight, design: .rounded)
    }

    static func small(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 11, weight: weight, design: .rounded)
    }
}

// MARK: - Spacing

enum MPSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Radius

enum MPRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 100
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Colors (light/dark)

struct MPAdaptiveColors {
    @Environment(\.colorScheme) static var colorScheme

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? MPColors.backgroundDark : MPColors.background
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? MPColors.surfaceDark : MPColors.surface
    }

    static func surfaceSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? MPColors.surfaceSecondaryDark : MPColors.surfaceSecondary
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : MPColors.textPrimary
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "B0B0B0") : MPColors.textSecondary
    }
}
