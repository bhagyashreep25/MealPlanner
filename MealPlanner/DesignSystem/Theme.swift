import SwiftUI

// MARK: - Color Palette

enum MPColors {
    // Primary — warm red-terracotta
    static let primary = Color(hex: "C25F34")
    static let primaryLight = Color(hex: "D4845F")
    static let primarySoft = Color(hex: "F5E3DA")
    static let primaryMuted = Color(hex: "C9A08D")

    // Warm accent — terracotta
    static let accent = Color(hex: "C4724E")
    static let accentSoft = Color(hex: "F5E6DE")

    // On-primary — cream text/icons on primary backgrounds
    static let onPrimary = Color(hex: "FEFCF8")

    // Neutrals — warm parchment tones
    static let background = Color(hex: "F5F0E8")
    static let surface = Color(hex: "FEFCF8")
    static let surfaceSecondary = Color(hex: "EDE8DF")
    static let textPrimary = Color(hex: "2C2218")
    static let textSecondary = Color(hex: "8B7E74")
    static let textTertiary = Color(hex: "B5AA9E")
    static let textWarm = Color(hex: "A39074") // golden warm secondary
    static let divider = Color(hex: "DDD5C8")
    static let shadow = Color(hex: "2C2218").opacity(0.08)

    // Semantic
    static let error = Color(hex: "A63D2F")
    static let warning = Color(hex: "C47F2A")

    // Dark mode variants — warm darks
    static let backgroundDark = Color(hex: "1A1612")
    static let surfaceDark = Color(hex: "262019")
    static let surfaceSecondaryDark = Color(hex: "332C24")
}

// MARK: - Typography
//
// Display/headings: Gloock (single weight, used for prominent text)
// Body/UI: Schibsted Grotesk (variable weight)
// Text fields: Schibsted Grotesk

enum MPTypography {
    // Gloock — display serif for headings and prominent text
    static func gloock(_ size: CGFloat = 24) -> Font {
        .custom("Gloock-Regular", size: size)
    }

    // Schibsted Grotesk — clean sans-serif for UI text
    private static let grotesk = "Schibsted Grotesk"

    static func display(_ size: CGFloat = 55) -> Font {
        .custom("SchibstedGrotesk-Bold", size: size)
    }

    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .custom(grotesk, size: 30).weight(weight)
    }

    static func title(_ weight: Font.Weight = .semibold) -> Font {
        .custom(grotesk, size: 24).weight(weight)
    }

    static func title2(_ weight: Font.Weight = .semibold) -> Font {
        .custom(grotesk, size: 20).weight(weight)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .custom(grotesk, size: 17).weight(weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .custom(grotesk, size: 15).weight(weight)
    }

    static func callout(_ weight: Font.Weight = .regular) -> Font {
        .custom(grotesk, size: 14).weight(weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .custom(grotesk, size: 12).weight(weight)
    }

    static func small(_ weight: Font.Weight = .regular) -> Font {
        .custom(grotesk, size: 11).weight(weight)
    }

    static func cardo(_ size: CGFloat = 15) -> Font {
        .custom(grotesk, size: size)
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
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
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
        scheme == .dark ? Color(hex: "F0E8DB") : MPColors.textPrimary
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "B5AA9E") : MPColors.textSecondary
    }
}
