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

    // Impostazioni Utente
    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showUserName") private var showUserName = true

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

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // MARK: - Intestazione
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(showUserName ? "\(greeting), \(userName)" : greeting)
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.white)
                        Text(weatherModel.weatherAdvice)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    ClockView()
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)

                // MARK: - Contenuto Principale (Griglia Bento)
                HStack(spacing: 30) {
                    // Colonna 1: Meteo
                    WeatherView()
                        .frame(maxWidth: 400)  // Larghezza fissa per belle proporzioni

                    // Colonna 2: Calendario
                    CalendarView()
                        .frame(maxWidth: 400)

                    // Colonna 3: Notizie / Hero
                    NewsTickerView()
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 60)

                // MARK: - Pié di pagina (Azioni)
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
                    .buttonStyle(.card)  // Usa stile scheda per effetto focus nativo
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
