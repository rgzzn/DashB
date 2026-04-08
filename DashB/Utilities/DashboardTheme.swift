import SwiftUI

struct DashboardTheme {
    let scheme: ColorScheme

    var primaryText: Color { scheme == .dark ? Color.white.opacity(0.98) : .black.opacity(0.88) }
    var secondaryText: Color { scheme == .dark ? Color.white.opacity(0.84) : .black.opacity(0.62) }
    var tertiaryText: Color { scheme == .dark ? Color.white.opacity(0.68) : .black.opacity(0.46) }

    var panelMaterial: Material { scheme == .dark ? .ultraThinMaterial : .ultraThinMaterial }
    var panelFill: Color {
        scheme == .dark
            ? Color(red: 0.09, green: 0.17, blue: 0.3).opacity(0.48)
            : Color.white.opacity(0.34)
    }
    var panelStroke: Color {
        scheme == .dark
            ? Color(red: 0.38, green: 0.65, blue: 0.95).opacity(0.34)
            : Color.black.opacity(0.1)
    }
    var panelShadow: Color { scheme == .dark ? .black.opacity(0.3) : .black.opacity(0.1) }
    var glassTint: Color {
        scheme == .dark
            ? Color(red: 0.32, green: 0.61, blue: 0.95)
            : .black
    }
    var subtleFill: Color { scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.05) }
    var elevatedTint: Color {
        scheme == .dark
            ? Color(red: 0.28, green: 0.55, blue: 0.88).opacity(0.16)
            : Color.white.opacity(0.18)
    }
    var focusFill: Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.26, blue: 0.42).opacity(0.8)
            : Color.white.opacity(0.82)
    }
    var focusStroke: Color { scheme == .dark ? Color(red: 0.56, green: 0.82, blue: 1.0).opacity(0.78) : Color.blue.opacity(0.4) }
    var focusShadow: Color { scheme == .dark ? Color(red: 0.09, green: 0.41, blue: 0.86).opacity(0.24) : Color.blue.opacity(0.12) }
}
