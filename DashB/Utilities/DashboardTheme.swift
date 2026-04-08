import SwiftUI

struct DashboardTheme {
    let scheme: ColorScheme

    var primaryText: Color { scheme == .dark ? .white : .black.opacity(0.88) }
    var secondaryText: Color { scheme == .dark ? .white.opacity(0.72) : .black.opacity(0.62) }
    var tertiaryText: Color { scheme == .dark ? .white.opacity(0.56) : .black.opacity(0.46) }

    var panelMaterial: Material { scheme == .dark ? .thickMaterial : .ultraThinMaterial }
    var panelFill: Color { scheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.34) }
    var panelStroke: Color { scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.1) }
    var panelShadow: Color { scheme == .dark ? .black.opacity(0.24) : .black.opacity(0.1) }
    var glassTint: Color { scheme == .dark ? .white : .black }
    var subtleFill: Color { scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05) }
    var elevatedTint: Color { scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.18) }
    var focusFill: Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.17, blue: 0.26).opacity(0.88)
            : Color.white.opacity(0.82)
    }
    var focusStroke: Color { scheme == .dark ? Color.cyan.opacity(0.55) : Color.blue.opacity(0.4) }
    var focusShadow: Color { scheme == .dark ? Color.cyan.opacity(0.12) : Color.blue.opacity(0.12) }
}
