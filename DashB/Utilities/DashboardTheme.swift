import SwiftUI

struct DashboardTheme {
    let scheme: ColorScheme

    var primaryText: Color { scheme == .dark ? .white : .primary }
    var secondaryText: Color { scheme == .dark ? .white.opacity(0.72) : .secondary }
    var tertiaryText: Color { scheme == .dark ? .white.opacity(0.56) : .secondary.opacity(0.78) }

    var panelFill: Color { scheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    var panelStroke: Color { scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.14) }
    var panelShadow: Color { scheme == .dark ? .black.opacity(0.24) : .black.opacity(0.1) }
    var glassTint: Color { scheme == .dark ? .white : .black }
}
