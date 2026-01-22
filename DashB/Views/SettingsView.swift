//
//  SettingsView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var weatherModel: WeatherModel
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    // Navigation state
    enum SettingsCategory: String, CaseIterable, Identifiable {
        case profile = "Profilo"
        case weather = "Meteo"
        case accounts = "Account"

        var id: String { self.rawValue }
        var icon: String {
            switch self {
            case .profile: return "person.crop.circle"
            case .weather: return "cloud.sun.fill"
            case .accounts: return "key.fill"
            }
        }
    }

    @State private var selectedCategory: SettingsCategory = .profile
    @FocusState private var focusedArea: FocusedArea?

    enum FocusedArea: Hashable {
        case sidebar(SettingsCategory)
        case content
        case closeButton
    }

    // Auth state
    @State private var authServiceItem: AuthServiceItem?
    struct AuthServiceItem: Identifiable {
        let service: any CalendarService
        var id: String { service.serviceName }
    }

    // User Personalization
    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showGreeting") private var showGreeting = true
    @AppStorage("weatherCity") private var weatherCity = "Milano"

    @State private var tempUserName: String = ""
    @State private var tempCity: String = ""

    var body: some View {
        ZStack {
            // Background consistent with Dashboard
            GradientBackgroundView()
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // MARK: - Sidebar
                VStack(alignment: .leading, spacing: 15) {
                    Text("Impostazioni")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.bottom, 30)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(SettingsCategory.allCases) { category in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = category
                                }
                            } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: category.icon)
                                        .font(.title3)
                                    Text(category.rawValue)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PremiumButtonStyle())
                            .focused($focusedArea, equals: .sidebar(category))
                        }
                    }

                    Spacer()

                    Button {
                        applyAndDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Salva e Chiudi")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumButtonStyle())
                    .focused($focusedArea, equals: .closeButton)
                }
                .padding(50)
                .frame(width: 400)
                .background(Color.black.opacity(0.2))

                // MARK: - Main Content Area
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 35) {
                            headerView(for: selectedCategory)

                            VStack(alignment: .leading, spacing: 25) {
                                categoryContent(for: selectedCategory)
                            }
                        }
                        .padding(.vertical, 60)
                        .padding(.horizontal, 80)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
            }
        }
        .onAppear {
            tempCity = weatherCity
            tempUserName = userName
            focusedArea = .sidebar(.profile)
        }
        .sheet(item: $authServiceItem) { item in
            DeviceLoginView(service: item.service)
                .environmentObject(calendarManager)
        }
    }

    @ViewBuilder
    private func headerView(for category: SettingsCategory) -> some View {
        HStack(spacing: 15) {
            Image(systemName: category.icon)
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.8))
            Text(category.rawValue)
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    @State private var showingCalendarSelection: CalendarType?
    enum CalendarType: Identifiable {
        case google, outlook
        var id: Int { self.hashValue }
    }

    @ViewBuilder
    private func categoryContent(for category: SettingsCategory) -> some View {
        switch category {
        case .profile:
            VStack(alignment: .leading, spacing: 30) {
                Toggle(isOn: $showGreeting) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saluto Personalizzato")
                            .font(.title3)
                        Text("Mostra il tuo nome nella dashboard")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Il tuo nome")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))

                    TextField("Inserisci il tuo nome", text: $tempUserName)
                        .textFieldStyle(.plain)
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .font(.title3)
                }
            }

        case .weather:
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Città predefinita")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))

                    TextField("Es. Roma, Milano...", text: $tempCity)
                        .textFieldStyle(.plain)
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .font(.title3)
                }

                Button {
                    weatherModel.useCurrentLocation()
                    Task { @MainActor in
                        tempCity = weatherModel.selectedCity
                    }
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Usa Posizione Attuale")
                    }
                }
                .buttonStyle(PremiumButtonStyle())
            }

        case .accounts:
            VStack(alignment: .leading, spacing: 25) {
                accountCard(
                    title: "Google Calendar",
                    subtitle: "Sincronizza i tuoi eventi Google",
                    icon: "g.circle.fill",
                    iconColor: .red,
                    isConnected: calendarManager.googleService.isConnected,
                    logoutAction: { calendarManager.googleService.logout() },
                    manageAction: { showingCalendarSelection = .google },
                    loginAction: {
                        authServiceItem = AuthServiceItem(service: calendarManager.googleService)
                    }
                )

                accountCard(
                    title: "Outlook / Microsoft",
                    subtitle: "Sincronizza i tuoi eventi Microsoft",
                    icon: "m.circle.fill",
                    iconColor: .blue,
                    isConnected: calendarManager.outlookService.isConnected,
                    logoutAction: { calendarManager.outlookService.logout() },
                    manageAction: { showingCalendarSelection = .outlook },
                    loginAction: {
                        authServiceItem = AuthServiceItem(service: calendarManager.outlookService)
                    }
                )
            }
            .sheet(item: $showingCalendarSelection) { type in
                if type == .google {
                    CalendarSelectionView(
                        service: calendarManager.googleService,
                        selectedConfigs: Binding(
                            get: { calendarManager.selectedGoogleCalendars },
                            set: { calendarManager.selectedGoogleCalendars = $0 }
                        ))
                } else {
                    CalendarSelectionView(
                        service: calendarManager.outlookService,
                        selectedConfigs: Binding(
                            get: { calendarManager.selectedOutlookCalendars },
                            set: { calendarManager.selectedOutlookCalendars = $0 }
                        ))
                }
            }
        }
    }

    @ViewBuilder
    private func accountCard(
        title: String, subtitle: String, icon: String, iconColor: Color, isConnected: Bool,
        logoutAction: @escaping () -> Void, manageAction: @escaping () -> Void,
        loginAction: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(isConnected ? "Stato: Connesso" : subtitle)
                    .font(.body)
                    .foregroundColor(isConnected ? .green : .white.opacity(0.5))
            }

            Spacer()

            if isConnected {
                HStack(spacing: 25) {
                    Button(action: manageAction) {
                        Text("Gestisci")
                            .lineLimit(1)
                            .frame(minWidth: 200)
                    }
                    .buttonStyle(PremiumButtonStyle())

                    Button(role: .destructive, action: logoutAction) {
                        Text("Disconnetti")
                            .lineLimit(1)
                            .frame(minWidth: 240)
                    }
                    .buttonStyle(PremiumButtonStyle(isDestructive: true))
                }
            } else {
                Button(action: loginAction) {
                    Text("Connetti Account")
                        .lineLimit(1)
                        .frame(minWidth: 280)
                }
                .buttonStyle(PremiumButtonStyle())
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private func applyAndDismiss() {
        let trimmedCity = tempCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCity.isEmpty {
            weatherCity = trimmedCity
            weatherModel.updateCity(trimmedCity)
        }

        let trimmedName = tempUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            userName = trimmedName
        }

        dismiss()
    }
}

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
                Button("Riprova") { loadCalendars() }
                    .buttonStyle(PremiumButtonStyle())
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
                    errorMsg = "Errore: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WeatherModel())
        .environmentObject(CalendarManager())
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
