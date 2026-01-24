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

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),  // Blu scuro profondo/viola
                Color(red: 0.1, green: 0.05, blue: 0.2),  // Viola scuro
                Color(red: 0.0, green: 0.0, blue: 0.1),  // Quasi nero
            ]), startPoint: startPoint, endPoint: endPoint
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                startPoint = UnitPoint(x: 1, y: 0)
                endPoint = UnitPoint(x: 0, y: 1)
            }
        }
    }
}
