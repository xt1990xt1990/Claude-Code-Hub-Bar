import SwiftUI

enum CCHTheme: String, CaseIterable, Identifiable, Hashable {
    case liquidGlass
    case endlessDark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liquidGlass:
            return "Liquid Glass"
        case .endlessDark:
            return "Endless Dark"
        }
    }

    var summary: String {
        switch self {
        case .liquidGlass:
            return "macOS 玻璃质感"
        case .endlessDark:
            return "深色外壳与细边框"
        }
    }

    var icon: String {
        switch self {
        case .liquidGlass:
            return "circle.hexagongrid.fill"
        case .endlessDark:
            return "moon.stars.fill"
        }
    }

    var palette: CCHThemePalette {
        switch self {
        case .liquidGlass:
            return .liquidGlass
        case .endlessDark:
            return .endlessDark
        }
    }
}

struct CCHThemePalette {
    let prefersGlassEffects: Bool
    let backgroundTop: Color
    let backgroundBottom: Color
    let backgroundOverlayTop: Color
    let backgroundOverlayBottom: Color
    let headerBackground: Color
    let footerBackground: Color
    let panel: Color
    let panelSoft: Color
    let row: Color
    let rowSelected: Color
    let control: Color
    let controlHover: Color
    let input: Color
    let border: Color
    let borderSubtle: Color
    let borderStrong: Color
    let hairline: Color
    let topHighlight: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accentBlue: Color
    let accentGreen: Color
    let accentOrange: Color
    let accentPurple: Color
    let accentRed: Color
    let accentMint: Color
    let userAccent: Color
    let settingsBackgroundBase: Color
    let settingsBackgroundOverlay: [Color]

    static let liquidGlass = CCHThemePalette(
        prefersGlassEffects: true,
        backgroundTop: Color(red: 0.135, green: 0.142, blue: 0.170),
        backgroundBottom: Color(red: 0.085, green: 0.090, blue: 0.115),
        backgroundOverlayTop: Color(red: 0.135, green: 0.142, blue: 0.170).opacity(0.16),
        backgroundOverlayBottom: Color(red: 0.085, green: 0.090, blue: 0.115).opacity(0.28),
        headerBackground: Color.white.opacity(0.045),
        footerBackground: Color.white.opacity(0.030),
        panel: Color.white.opacity(0.085),
        panelSoft: Color.white.opacity(0.055),
        row: Color.white.opacity(0.065),
        rowSelected: Color.accentColor.opacity(0.14),
        control: Color(nsColor: .controlBackgroundColor).opacity(0.52),
        controlHover: Color.white.opacity(0.16),
        input: Color(nsColor: .controlBackgroundColor).opacity(0.72),
        border: Color.white.opacity(0.070),
        borderSubtle: Color.white.opacity(0.080),
        borderStrong: Color.white.opacity(0.140),
        hairline: Color.white.opacity(0.080),
        topHighlight: Color.white.opacity(0.180),
        textPrimary: .primary,
        textSecondary: .secondary,
        textTertiary: .secondary.opacity(0.72),
        accentBlue: .blue,
        accentGreen: .green,
        accentOrange: .orange,
        accentPurple: .purple,
        accentRed: .red,
        accentMint: .mint,
        userAccent: Color.orange.opacity(0.95),
        settingsBackgroundBase: Color(nsColor: .windowBackgroundColor),
        settingsBackgroundOverlay: [
            Color.blue.opacity(0.13),
            Color.purple.opacity(0.09),
            Color.orange.opacity(0.08)
        ]
    )

    static let endlessDark = CCHThemePalette(
        prefersGlassEffects: false,
        backgroundTop: Color(red: 0.035, green: 0.035, blue: 0.036),
        backgroundBottom: Color(red: 0.006, green: 0.006, blue: 0.007),
        backgroundOverlayTop: Color.black.opacity(0.08),
        backgroundOverlayBottom: Color.black.opacity(0.42),
        headerBackground: Color(red: 0.026, green: 0.026, blue: 0.028).opacity(0.98),
        footerBackground: Color(red: 0.018, green: 0.018, blue: 0.020).opacity(0.98),
        panel: Color(red: 0.052, green: 0.052, blue: 0.056),
        panelSoft: Color(red: 0.070, green: 0.070, blue: 0.076).opacity(0.86),
        row: Color(red: 0.075, green: 0.075, blue: 0.082).opacity(0.88),
        rowSelected: Color(red: 0.070, green: 0.300, blue: 0.780).opacity(0.26),
        control: Color(red: 0.085, green: 0.085, blue: 0.092).opacity(0.90),
        controlHover: Color(red: 0.118, green: 0.118, blue: 0.128).opacity(0.95),
        input: Color(red: 0.070, green: 0.070, blue: 0.078).opacity(0.94),
        border: Color.white.opacity(0.100),
        borderSubtle: Color.white.opacity(0.055),
        borderStrong: Color.white.opacity(0.170),
        hairline: Color.white.opacity(0.085),
        topHighlight: Color.white.opacity(0.120),
        textPrimary: Color(red: 0.925, green: 0.925, blue: 0.930),
        textSecondary: Color(red: 0.690, green: 0.690, blue: 0.705),
        textTertiary: Color(red: 0.455, green: 0.455, blue: 0.475),
        accentBlue: Color(red: 0.140, green: 0.420, blue: 0.980),
        accentGreen: Color(red: 0.000, green: 0.690, blue: 0.470),
        accentOrange: Color(red: 0.980, green: 0.560, blue: 0.120),
        accentPurple: Color(red: 0.560, green: 0.300, blue: 0.960),
        accentRed: Color(red: 0.940, green: 0.220, blue: 0.220),
        accentMint: Color(red: 0.000, green: 0.760, blue: 0.700),
        userAccent: Color(red: 0.980, green: 0.560, blue: 0.120),
        settingsBackgroundBase: Color(red: 0.006, green: 0.006, blue: 0.007),
        settingsBackgroundOverlay: [
            Color.white.opacity(0.040),
            Color(red: 0.140, green: 0.420, blue: 0.980).opacity(0.055),
            Color(red: 0.980, green: 0.560, blue: 0.120).opacity(0.035)
        ]
    )
}

private struct CCHThemePaletteKey: EnvironmentKey {
    static let defaultValue = CCHTheme.liquidGlass.palette
}

extension EnvironmentValues {
    var cchTheme: CCHThemePalette {
        get { self[CCHThemePaletteKey.self] }
        set { self[CCHThemePaletteKey.self] = newValue }
    }
}

enum CCHThemeSurface {
    case panel
    case panelSoft
    case row
    case rowSelected
    case control
    case controlHover
    case input
}

private struct CCHThemeSurfaceModifier: ViewModifier {
    @Environment(\.cchTheme) private var theme
    let surface: CCHThemeSurface

    func body(content: Content) -> some View {
        content.background(color)
    }

    private var color: Color {
        switch surface {
        case .panel:
            return theme.panel
        case .panelSoft:
            return theme.panelSoft
        case .row:
            return theme.row
        case .rowSelected:
            return theme.rowSelected
        case .control:
            return theme.control
        case .controlHover:
            return theme.controlHover
        case .input:
            return theme.input
        }
    }
}

private struct CCHUserAccentModifier: ViewModifier {
    @Environment(\.cchTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundStyle(theme.userAccent)
    }
}

private struct CCHSecondaryTextModifier: ViewModifier {
    @Environment(\.cchTheme) private var theme

    func body(content: Content) -> some View {
        content.foregroundStyle(theme.textSecondary)
    }
}

extension View {
    func cchSurface(_ surface: CCHThemeSurface) -> some View {
        modifier(CCHThemeSurfaceModifier(surface: surface))
    }

    func cchUserAccent() -> some View {
        modifier(CCHUserAccentModifier())
    }

    func cchSecondaryText() -> some View {
        modifier(CCHSecondaryTextModifier())
    }
}
