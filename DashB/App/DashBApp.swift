//
//  DashBApp.swift
//  DashB
//
//  Creato da Luca Ragazzini il 20/01/26.
//

import SwiftData
import SwiftUI

@main
struct DashBApp: App {
    @StateObject private var weatherModel = WeatherModel()
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var rssModel = RSSModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if Config.hasRequiredOAuthConfig {
                    ContentView()
                        .environmentObject(weatherModel)
                        .environmentObject(calendarManager)
                        .environmentObject(rssModel)
                } else {
                    ConfigurationErrorView(missingKeys: Config.missingOAuthKeys)
                }
            }
        }
    }
}

private struct ConfigurationErrorView: View {
    let missingKeys: [String]

    var body: some View {
        ZStack {
            GradientBackgroundView().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Configurazione incompleta")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)

                Text(
                    "L'app non può avviare i servizi calendario perché mancano alcune chiavi OAuth in Info.plist."
                )
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Chiavi mancanti:")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(missingKeys, id: \.self) { key in
                        Text("• \(key)")
                            .font(.body.monospaced())
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("Aggiungi le chiavi mancanti e riavvia l'app.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(40)
            .frame(maxWidth: 1100)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .padding(30)
        }
    }
}
