//
//  SettingsView.swift
//  DashB
//
//  Created by Luca Ragazzini on 24/01/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var weatherModel: WeatherModel
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var rssModel: RSSModel
    @Environment(\.dismiss) private var dismiss

    // Navigation State
    @State private var navigationPath = NavigationPath()

    // Auth State
    @State private var authServiceItem: AuthServiceItem?
    struct AuthServiceItem: Identifiable {
        let service: any CalendarService
        var id: String { service.serviceName }
    }

    // User Preferences
    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showGreeting") private var showGreeting = true
    @AppStorage("weatherCity") private var weatherCity = "Milano"

    // Temp State for Edit
    @State private var showingEditProfile = false
    @State private var tempUserName = ""

    @State private var showingEditWeather = false
    @State private var tempCity = ""

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                GradientBackgroundView().ignoresSafeArea()

                VStack(alignment: .leading, spacing: 30) {
                    // Header
                    HStack {
                        Text("Impostazioni")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 40)

                    ScrollView {
                        VStack(spacing: 30) {
                            // Quick Actions Row
                            HStack(spacing: 20) {
                                QuickActionButton(icon: "location.fill", title: "Cambia Città") {
                                    tempCity = weatherCity
                                    showingEditWeather = true
                                }

                                QuickActionButton(
                                    icon: "person.crop.circle.badge.plus", title: "Collega Account"
                                ) {
                                    // Default to Google for quick action, or show sheet
                                    authServiceItem = AuthServiceItem(
                                        service: calendarManager.googleService)
                                }

                                QuickActionButton(
                                    icon: "arrow.triangle.2.circlepath", title: "Aggiorna Calendari"
                                ) {
                                    calendarManager.fetchEvents()
                                }

                                QuickActionButton(
                                    icon: "antenna.radiowaves.left.and.right", title: "Aggiorna RSS"
                                ) {
                                    rssModel.fetchNews()
                                }
                            }
                            .padding(.horizontal, 40)

                            // Bento Grid
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 40
                            ) {
                                // 1. Profilo & Display
                                SettingsCard(
                                    icon: "person.fill",
                                    title: "Profilo",
                                    color: .blue
                                ) {
                                    tempUserName = userName
                                    showingEditProfile = true
                                } content: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Ciao, \(userName)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        Text(showGreeting ? "Saluto attivo" : "Saluto nascosto")
                                            .font(.caption)
                                            .opacity(0.7)
                                    }
                                }

                                // 2. Meteo
                                SettingsCard(
                                    icon: "cloud.sun.fill",
                                    title: "Meteo",
                                    color: .orange
                                ) {
                                    tempCity = weatherCity
                                    showingEditWeather = true
                                } content: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(weatherCity)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                        Text("Città attuale")
                                            .font(.caption)
                                            .opacity(0.7)
                                    }
                                }

                                // 3. Agenda (Accounts)
                                SettingsCard(
                                    icon: "calendar",
                                    title: "Agenda",
                                    color: .red
                                ) {
                                    navigationPath.append(SettingsDestination.agenda)
                                } content: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Circle().fill(
                                                calendarManager.googleService.isConnected
                                                    ? Color.green : Color.red
                                            ).frame(width: 8, height: 8)
                                            Text("Google")
                                        }
                                        HStack {
                                            Circle().fill(
                                                calendarManager.outlookService.isConnected
                                                    ? Color.green : Color.red
                                            ).frame(width: 8, height: 8)
                                            Text("Outlook")
                                        }
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                }

                                // 4. Notizie
                                SettingsCard(
                                    icon: "newspaper.fill",
                                    title: "Notizie",
                                    color: .purple
                                ) {
                                    navigationPath.append(SettingsDestination.news)
                                } content: {
                                    Text("\(rssModel.feeds.count) fonti")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 60)
                        }
                    }
                }
            }
            .navigationDestination(for: SettingsDestination.self) { dest in
                switch dest {
                case .agenda:
                    AccountsSettingsView()
                        .environmentObject(calendarManager)
                        .environmentObject(rssModel)  // Pass through environment if needed
                case .news:
                    NewsSettingsView()
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet(
                    userName: $userName, showGreeting: $showGreeting,
                    isPresented: $showingEditProfile)
            }
            .sheet(isPresented: $showingEditWeather) {
                EditWeatherSheet(city: $weatherCity, isPresented: $showingEditWeather)
                    .environmentObject(weatherModel)
            }
            .sheet(item: $authServiceItem) { item in
                DeviceLoginView(service: item.service)
                    .environmentObject(calendarManager)
            }
        }
    }
}

enum SettingsDestination: Hashable {
    case agenda
    case news
}

// MARK: - Subviews & Components

// MARK: - Subviews & Components

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        #if os(tvOS)
            .buttonStyle(.card)
        #else
            .buttonStyle(.plain)
        #endif
    }
}

struct SettingsCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    let content: () -> Content

    init(
        icon: String, title: String, color: Color, action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
        self.content = content
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                        .padding(6)
                        .background(color.opacity(0.2))
                        .clipShape(Circle())

                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))
                }

                Divider().background(Color.white.opacity(0.1))

                content()
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 180)
            .background(Color.white.opacity(0.05))
            .cornerRadius(15)
        }
        #if os(tvOS)
            .buttonStyle(.card)
        #else
            .buttonStyle(.plain)
        #endif
    }
}

// MARK: - Edit Sheets

struct EditProfileSheet: View {
    @Binding var userName: String
    @Binding var showGreeting: Bool
    @Binding var isPresented: Bool
    @State private var tempName: String = ""

    var body: some View {
        VStack(spacing: 30) {
            Text("Modifica Profilo")
                .font(.title)
                .fontWeight(.bold)

            TextField("Il tuo nome", text: $tempName)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

            Toggle("Mostra Saluto", isOn: $showGreeting)
                #if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
                    .tint(.blue)
                #else
                    .toggleStyle(SwitchToggleStyle())
                #endif

            Button("Salva") {
                userName = tempName
                isPresented = false
            }
            .buttonStyle(PremiumButtonStyle())
        }
        .padding(50)
        .onAppear { tempName = userName }
    }
}

struct EditWeatherSheet: View {
    @Binding var city: String
    @Binding var isPresented: Bool
    @EnvironmentObject var weatherModel: WeatherModel
    @State private var showAttributionQR = false
    @State private var tempCity: String = ""

    var body: some View {
        VStack(spacing: 30) {
            Text("Imposta Meteo")
                .font(.title)
                .fontWeight(.bold)

            TextField("Città (es. Roma)", text: $tempCity)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

            Button("Usa Posizione Attuale") {
                weatherModel.useCurrentLocation()
                Task {
                    // Small delay to allow location update
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        tempCity = weatherModel.selectedCity
                    }
                }
            }

            Button("Salva") {
                city = tempCity
                weatherModel.updateCity(tempCity)
                isPresented = false
            }
            .buttonStyle(PremiumButtonStyle())

            VStack(spacing: 5) {
                // Trademark
                HStack(spacing: 4) {
                    Text("")
                    Text("Weather")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

                // Legal Link
                Button("Legal Attribution") {
                    showAttributionQR = true
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
                .underline()
            }
            .padding(.top, 20)
        }
        .padding(50)
        .onAppear { tempCity = city }
        .sheet(isPresented: $showAttributionQR) {
            if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                QRCodeView(url: url, title: "Legal Attribution")
            }
        }
    }
}

// MARK: - Agenda / Accounts View (Extracted)

struct AccountsSettingsView: View {
    @EnvironmentObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    // Auth State for this view
    @State private var authServiceItem: SettingsView.AuthServiceItem?
    @State private var showingCalendarSelection: CalendarType?

    enum CalendarType: Identifiable {
        case google, outlook
        var id: Int { self.hashValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Account & Calendari")
                    .font(.system(size: 38, weight: .bold))
                Spacer()
                Button("Chiudi") { dismiss() }
                    .buttonStyle(PremiumButtonStyle())
            }
            .padding(40)
            .background(Color.black.opacity(0.3))

            ScrollView {
                VStack(spacing: 30) {
                    accountRow(
                        service: calendarManager.googleService,
                        icon: "g.circle.fill",
                        color: .red,
                        title: "Google Calendar",
                        type: .google
                    )

                    accountRow(
                        service: calendarManager.outlookService,
                        icon: "m.circle.fill",
                        color: .blue,
                        title: "Outlook Calendar",
                        type: .outlook
                    )
                }
                .padding(40)
            }
        }
        .background(GradientBackgroundView().ignoresSafeArea())
        .sheet(item: $authServiceItem) { item in
            DeviceLoginView(service: item.service)
                .environmentObject(calendarManager)
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

    @ViewBuilder
    private func accountRow(
        service: any CalendarService, icon: String, color: Color, title: String, type: CalendarType
    ) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(color)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(service.isConnected ? "Connesso" : "Non connesso")
                    .foregroundColor(service.isConnected ? .green : .gray)
            }

            Spacer()

            if service.isConnected {
                Button("Gestisci") {
                    showingCalendarSelection = type
                }
                .buttonStyle(PremiumButtonStyle())

                Button("Esci") {
                    service.logout()
                }
                .buttonStyle(PremiumButtonStyle(isDestructive: true))
            } else {
                Button("Connetti") {
                    authServiceItem = SettingsView.AuthServiceItem(service: service)
                }
                .buttonStyle(PremiumButtonStyle())
            }
        }
        .padding(30)
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
}

#Preview("SettingsView") {
    // Provide lightweight instances for preview to avoid missing environment objects
    let weather = WeatherModel()
    let calendar = CalendarManager()
    let rss = RSSModel()

    return SettingsView()
        .environmentObject(weather)
        .environmentObject(calendar)
        .environmentObject(rss)
}
