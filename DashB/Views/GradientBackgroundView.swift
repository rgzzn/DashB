//
//  GradientBackgroundView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct GradientBackgroundView: View {
    @State private var startPoint = UnitPoint(x: 0, y: -2)
    @State private var endPoint = UnitPoint(x: 4, y: 0)
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),  // Blu scuro profondo/viola
                Color(red: 0.1, green: 0.05, blue: 0.2),  // Viola scuro
                Color(red: 0.0, green: 0.0, blue: 0.1),  // Quasi nero
            ]), startPoint: animateGradient ? UnitPoint(x: 1, y: 0) : UnitPoint(x: 0, y: -2),
            endPoint: animateGradient ? UnitPoint(x: 0, y: 1) : UnitPoint(x: 4, y: 0)
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}
#Preview("GradientBackgroundView Preview") {
    GradientBackgroundView()
}
