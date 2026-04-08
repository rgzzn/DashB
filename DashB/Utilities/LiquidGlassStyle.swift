import SwiftUI

extension View {
    @ViewBuilder
    func dashBLiquidGlass(
        cornerRadius: CGFloat,
        tint: Color = .white,
        interactive: Bool = false,
        interactiveTintOpacity: Double = 0.18,
        staticTintOpacity: Double = 0.1
    ) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(
                interactive
                    ? .regular.tint(tint.opacity(interactiveTintOpacity)).interactive()
                    : .regular.tint(tint.opacity(staticTintOpacity)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
        }
    }
}
