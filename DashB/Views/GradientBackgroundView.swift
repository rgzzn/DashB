//
//  GradientBackgroundView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct GradientBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateGradient = false
    @State private var animateGlow = false

    private var baseGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.08, blue: 0.16),
                Color(red: 0.07, green: 0.14, blue: 0.26),
                Color(red: 0.03, green: 0.05, blue: 0.12),
            ]
        }
        return [
            Color(red: 0.88, green: 0.93, blue: 0.98),
            Color(red: 0.8, green: 0.89, blue: 0.98),
            Color(red: 0.92, green: 0.95, blue: 0.99),
        ]
    }

    private var primaryGlowColor: Color {
        colorScheme == .dark ? Color.cyan.opacity(0.92) : Color.cyan
    }

    private var secondaryGlowColor: Color {
        colorScheme == .dark ? Color.indigo.opacity(0.8) : Color.blue
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: baseGradient,
                startPoint: animateGradient ? .topTrailing : UnitPoint(x: -0.2, y: -0.6),
                endPoint: animateGradient ? .bottomLeading : UnitPoint(x: 1.3, y: 0.6)
            )

            RadialGradient(
                colors: [
                    primaryGlowColor.opacity(
                        colorScheme == .dark
                            ? (animateGlow ? 0.22 : 0.15)
                            : (animateGlow ? 0.2 : 0.12)
                    ),
                    Color.clear,
                ],
                center: animateGlow ? UnitPoint(x: 0.22, y: 0.18) : UnitPoint(x: 0.76, y: 0.12),
                startRadius: 40,
                endRadius: 620
            )
            .blendMode(colorScheme == .dark ? .screen : .plusLighter)

            RadialGradient(
                colors: [
                    secondaryGlowColor.opacity(
                        colorScheme == .dark
                            ? (animateGlow ? 0.16 : 0.1)
                            : (animateGlow ? 0.08 : 0.04)
                    ),
                    Color.clear,
                ],
                center: animateGlow ? UnitPoint(x: 0.84, y: 0.78) : UnitPoint(x: 0.58, y: 0.92),
                startRadius: 30,
                endRadius: 520
            )
            .blendMode(colorScheme == .dark ? .screen : .plusLighter)

            if colorScheme == .dark {
                RadialGradient(
                    colors: [
                        Color.white.opacity(animateGlow ? 0.08 : 0.04),
                        Color.clear,
                    ],
                    center: animateGlow ? UnitPoint(x: 0.5, y: 0.04) : UnitPoint(x: 0.38, y: 0.18),
                    startRadius: 24,
                    endRadius: 460
                )
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Motion.ambient) {
                animateGradient.toggle()
            }
            withAnimation(Motion.ambient.delay(1.8)) {
                animateGlow.toggle()
            }
        }
    }
}
#Preview("GradientBackgroundView Preview") {
    GradientBackgroundView()
}
