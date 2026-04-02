//
//  GradientBackgroundView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct GradientBackgroundView: View {
    @State private var animateGradient = false
    @State private var animateGlow = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.06, blue: 0.16),
                    Color(red: 0.03, green: 0.12, blue: 0.28),
                    Color(red: 0.0, green: 0.02, blue: 0.08),
                ],
                startPoint: animateGradient ? .topTrailing : UnitPoint(x: -0.2, y: -0.6),
                endPoint: animateGradient ? .bottomLeading : UnitPoint(x: 1.3, y: 0.6)
            )

            RadialGradient(
                colors: [
                    Color.cyan.opacity(animateGlow ? 0.2 : 0.12),
                    Color.clear,
                ],
                center: animateGlow ? UnitPoint(x: 0.22, y: 0.18) : UnitPoint(x: 0.76, y: 0.12),
                startRadius: 40,
                endRadius: 620
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    Color.white.opacity(animateGlow ? 0.08 : 0.04),
                    Color.clear,
                ],
                center: animateGlow ? UnitPoint(x: 0.84, y: 0.78) : UnitPoint(x: 0.58, y: 0.92),
                startRadius: 30,
                endRadius: 520
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
        .onAppear {
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
