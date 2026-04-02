//
//  ContentView.swift
//  DashB
//
//  Creato da Luca Ragazzini il 20/01/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                DashboardView()
                    .transition(.opacity.combined(with: .scale(scale: 1.01)))
            } else {
                OnboardingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
            }
        }
        .animation(Motion.calm, value: hasCompletedOnboarding)
    }
}

#Preview("ContentView Preview") {
    ContentView()
        .environmentObject(WeatherModel())
        .environmentObject(CalendarManager())
        .environmentObject(RSSModel())
}
