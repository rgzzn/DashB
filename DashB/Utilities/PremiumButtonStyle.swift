//
//  PremiumButtonStyle.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct PremiumButtonStyle: ButtonStyle {
    var backgroundColor: Color = .white.opacity(0.12)
    var foregroundColor: Color = .white
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PremiumButtonContainer(
            configuration: configuration,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            isDestructive: isDestructive
        )
    }
}

private struct PremiumButtonContainer: View {
    let configuration: ButtonStyle.Configuration
    let backgroundColor: Color
    let foregroundColor: Color
    let isDestructive: Bool

    @Environment(\.isFocused) var isFocused

    var body: some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(isDestructive ? .red : (isFocused ? .black : foregroundColor))
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            isFocused
                                ? Color.white
                                : (isDestructive ? Color.red.opacity(0.15) : backgroundColor))

                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.2))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isFocused
                            ? Color.white
                            : (isDestructive ? Color.red.opacity(0.3) : Color.white.opacity(0.1)),
                        lineWidth: isFocused ? 3 : 1)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.5 : 0.3), radius: isFocused ? 15 : 10, x: 0,
                y: isFocused ? 8 : 5
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PremiumButtonStyle {
    static var premium: PremiumButtonStyle {
        PremiumButtonStyle()
    }

    static func premium(backgroundColor: Color = .white.opacity(0.12), isDestructive: Bool = false)
        -> PremiumButtonStyle
    {
        PremiumButtonStyle(backgroundColor: backgroundColor, isDestructive: isDestructive)
    }
}
