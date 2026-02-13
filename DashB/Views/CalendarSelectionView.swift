//
//  CalendarSelectionView.swift
//  DashB
//
//  Created by Luca Ragazzini on 24/01/26.
//

import SwiftUI

struct CalendarSelectionView<Service: CalendarService>: View {
    let service: Service
    @Binding var selectedConfigs: [CalendarInfo]
    @Environment(\.dismiss) private var dismiss
    @State private var availableCalendars: [CalendarInfo] = []
    @State private var isLoading = true
    @State private var errorMsg: String?

    let basicColors = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#AF52DE",
        "#FF2D55", "#A2845E", "#8E8E93",
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Seleziona Calendari")
                    .font(.system(size: 38, weight: .bold))
                Spacer()
                Button("Fatto") { dismiss() }
                    .buttonStyle(PremiumButtonStyle())
            }
            .padding(50)
            .background(Color.black.opacity(0.3))

            if isLoading {
                Spacer()
                ProgressView("Caricamento calendari...")
                Spacer()
            } else if let error = errorMsg {
                Spacer()
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button("Riprova") { loadCalendars() }
                    .buttonStyle(PremiumButtonStyle())
                    .accessibilityLabel("Riprova caricamento calendari")
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(availableCalendars) { cal in
                            let isSelected = selectedConfigs.contains(where: { $0.id == cal.id })

                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cal.name)
                                            .font(.headline)
                                    }

                                    Spacer()

                                    Toggle(
                                        "",
                                        isOn: Binding(
                                            get: { isSelected },
                                            set: { active in
                                                if active {
                                                    if !isSelected {
                                                        var newCal = cal
                                                        newCal.colorHex = basicColors[0]
                                                        selectedConfigs.append(newCal)
                                                    }
                                                } else {
                                                    selectedConfigs.removeAll(where: {
                                                        $0.id == cal.id
                                                    })
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(.switch)
                                    .accessibilityLabel("Seleziona calendario \(cal.name)")
                                }

                                if isSelected {
                                    HStack(spacing: 20) {
                                        ForEach(basicColors, id: \.self) { hex in
                                            let isCurrent =
                                                selectedConfigs.first(where: { $0.id == cal.id })?
                                                .colorHex == hex

                                            Button {
                                                if let index = selectedConfigs.firstIndex(where: {
                                                    $0.id == cal.id
                                                }) {
                                                    selectedConfigs[index].colorHex = hex
                                                }
                                            } label: {
                                                Circle()
                                                    .fill(Color(hex: hex))
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(
                                                                Color.white,
                                                                lineWidth: isCurrent ? 4 : 0)
                                                    )
                                                    .shadow(radius: isCurrent ? 5 : 0)
                                            }
                                            .buttonStyle(ColorButtonStyle())
                                            .accessibilityLabel("Colore \(hex) per \(cal.name)")
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.leading, 10)
                                }
                            }
                            .padding(25)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(15)
                        }
                    }
                    .padding(50)
                }
            }
        }
        .background(GradientBackgroundView().ignoresSafeArea())
        .onAppear { loadCalendars() }
    }

    private func loadCalendars() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let fetched = try await service.fetchAvailableCalendars()
                await MainActor.run {
                    self.availableCalendars = fetched
                    // Auto-activate all calendars by default if they are not already selected
                    for cal in fetched {
                        if !selectedConfigs.contains(where: { $0.id == cal.id }) {
                            var newCal = cal
                            newCal.colorHex =
                                basicColors[
                                    availableCalendars.firstIndex(where: { $0.id == cal.id }) ?? 0
                                        % basicColors.count]
                            selectedConfigs.append(newCal)
                        }
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMsg = friendlyErrorMessage(from: error)
                    isLoading = false
                }
            }
        }
    }

    private func friendlyErrorMessage(from error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Connessione assente. Controlla la rete e riprova."
            case .timedOut:
                return "Il servizio calendari non risponde in tempo. Riprova tra poco."
            default:
                return "Impossibile caricare i calendari in questo momento."
            }
        }
        return "Impossibile caricare i calendari in questo momento."
    }
}

struct ColorButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.3 : 1.0)
            .shadow(color: .white.opacity(isFocused ? 0.6 : 0), radius: 10)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isFocused ? 4 : 0)
                    .padding(-6)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
    }
}
