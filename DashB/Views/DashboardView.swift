//
//  DashboardView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var weatherModel: WeatherModel
    @EnvironmentObject private var calendarManager: CalendarManager
    @State private var showingSettings = false

    // User Settings
    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showUserName") private var showUserName = true

    @FocusState private var isSettingsFocused: Bool

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // MARK: - Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(showUserName ? "Buona sera, \(userName)" : "Buona sera")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white)
                        Text("Bentornato nella tua dashboard.")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    ClockView()
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)

                // MARK: - Main Content (Bento Grid)
                HStack(spacing: 30) {
                    // Column 1: Weather
                    WeatherView()
                        .frame(maxWidth: 400)  // Fixed width for nice proportion

                    // Column 2: Calendar
                    CalendarView()
                        .frame(maxWidth: 400)

                    // Column 3: News / Hero
                    NewsTickerView()
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 60)

                // MARK: - Footer (Actions)
                HStack {
                    Spacer()

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 44, weight: .light))
                            .padding(20)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(.card)  // Use card style for native focus effect
                    .focused($isSettingsFocused)
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 60)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSettingsFocused)
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(weatherModel)
                .environmentObject(calendarManager)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(WeatherModel())
}
