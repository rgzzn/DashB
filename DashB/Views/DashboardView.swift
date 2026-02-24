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
    @EnvironmentObject private var rssModel: RSSModel
    @State private var showingSettings = false
    @State private var showContent = false

    // Impostazioni Utente
    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showGreeting") private var showGreeting = true

    @FocusState private var isSettingsFocused: Bool

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "Buongiorno"
        case 12..<18: return "Buon pomeriggio"
        case 18..<24: return "Buona sera"
        default: return "Buona notte"
        }
    }

    private var greetingText: String {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return greeting
        }
        return showGreeting ? "\(greeting), \(trimmedName)" : trimmedName
    }

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // MARK: - Intestazione
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(greetingText)
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(weatherModel.weatherAdvice)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    Spacer()

                    ClockView()
                }
                .padding(.top, 20)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)
                .animation(Motion.enter, value: showContent)
                .layoutPriority(1)

                // MARK: - Contenuto Principale (Griglia Bento)
                HStack(spacing: 30) {
                    // Colonna 1: Meteo
                    WeatherView()
                        .frame(minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: .infinity)

                    // Colonna 2: Calendario
                    CalendarView()
                        .frame(minWidth: 0, maxWidth: 400, minHeight: 0, maxHeight: .infinity)

                    // Colonna 3: Notizie / Hero
                    NewsTickerView()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)
                .animation(Motion.enter.delay(0.1), value: showContent)

                // MARK: - Pié di pagina (Azioni)
                HStack {
                    Spacer()

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10, weight: .light))
                            .padding(16)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(.card)  // Usa stile scheda per effetto focus nativo
                    .focused($isSettingsFocused)
                    .scaleEffect(isSettingsFocused ? 1.08 : 1)
                    .shadow(
                        color: .black.opacity(isSettingsFocused ? 0.35 : 0.15),
                        radius: isSettingsFocused ? 16 : 8
                    )
                }
                .padding(.bottom, 5)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 10)
                .animation(Motion.enter.delay(0.2), value: showContent)
                .layoutPriority(1)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
        .animation(Motion.focus, value: isSettingsFocused)
        .onAppear {
            showContent = true
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(weatherModel)
                .environmentObject(calendarManager)
                .environmentObject(rssModel)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(WeatherModel())
        .environmentObject(CalendarManager())
        .environmentObject(RSSModel())
}
