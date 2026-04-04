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
    @AppStorage("weatherCity") private var weatherCity = L10n.string("onboarding.weather.cityPreset.milan")
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Temp State for Edit
    @State private var showingEditProfile = false
    @State private var tempUserName = ""

    @State private var showingEditWeather = false
    @State private var tempCity = ""
    @State private var showContent = false

    private let primaryText = Color(red: 0.14, green: 0.20, blue: 0.29)
    private let secondaryText = Color(red: 0.30, green: 0.38, blue: 0.48)

    private var connectedServicesCount: Int {
        [calendarManager.googleService.isConnected, calendarManager.outlookService.isConnected]
            .filter { $0 }
            .count
    }

    @ViewBuilder
    private var quickActions: some View {
        QuickActionButton(icon: "location.fill", title: L10n.string("settings.quickAction.changeCity")) {
            tempCity = weatherCity
            showingEditWeather = true
        }

        QuickActionButton(
            icon: "person.crop.circle.badge.plus", title: L10n.string("settings.quickAction.connectAccount")
        ) {
            // Default to Google for quick action, or show sheet
            authServiceItem = AuthServiceItem(
                service: calendarManager.googleService)
        }

        QuickActionButton(
            icon: "arrow.triangle.2.circlepath", title: L10n.string("settings.quickAction.refreshCalendars")
        ) {
            calendarManager.fetchEvents()
        }

        QuickActionButton(
            icon: "antenna.radiowaves.left.and.right", title: L10n.string("settings.quickAction.refreshRSS")
        ) {
            rssModel.fetchNews()
        }

        QuickActionButton(
            icon: "sparkles.rectangle.stack", title: L10n.string("settings.quickAction.reviewTour")
        ) {
            hasCompletedOnboarding = false
            dismiss()
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                GradientBackgroundView()
                    .overlay {
                        SettingsAmbientBackdrop()
                    }
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 30) {
                    settingsHeader

                    ScrollView {
                        VStack(spacing: 30) {
                            settingsOverview

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 20) {
                                    quickActions
                                }

                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 20
                                ) {
                                    quickActions
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 40
                            ) {
                                // 1. Profilo & Display
                                SettingsCard(
                                    icon: "person.fill",
                                    title: L10n.string("settings.card.profile.title"),
                                    color: .blue
                                ) {
                                    tempUserName = userName
                                    showingEditProfile = true
                                } content: {
                                    SettingsValueStack(
                                        primary: L10n.string("settings.profile.greeting", userName),
                                        secondary: showGreeting
                                            ? L10n.string("settings.profile.greetingEnabled")
                                            : L10n.string("settings.profile.greetingHidden")
                                    )
                                }

                                SettingsCard(
                                    icon: "cloud.sun.fill",
                                    title: L10n.string("settings.card.weather.title"),
                                    color: .orange
                                ) {
                                    tempCity = weatherCity
                                    showingEditWeather = true
                                } content: {
                                    SettingsValueStack(
                                        primary: weatherCity,
                                        secondary: L10n.string("settings.weather.currentCity")
                                    )
                                }

                                SettingsCard(
                                    icon: "calendar",
                                    title: L10n.string("settings.card.agenda.title"),
                                    color: .red
                                ) {
                                    navigationPath.append(SettingsDestination.agenda)
                                } content: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        SettingsStatusRow(
                                            title: L10n.string("settings.provider.google"),
                                            isActive: calendarManager.googleService.isConnected
                                        )
                                        SettingsStatusRow(
                                            title: L10n.string("settings.provider.outlook"),
                                            isActive: calendarManager.outlookService.isConnected
                                        )
                                    }
                                }

                                SettingsCard(
                                    icon: "newspaper.fill",
                                    title: L10n.string("settings.card.news.title"),
                                    color: .purple
                                ) {
                                    navigationPath.append(SettingsDestination.news)
                                } content: {
                                    SettingsValueStack(
                                        primary: L10n.string(
                                            "settings.news.sourcesCount",
                                            rssModel.feeds.count
                                        ),
                                        secondary: L10n.string("settings.news.activeSources")
                                    )
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 60)
                        }
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)
                .animation(Motion.enter, value: showContent)
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
            .onAppear {
                guard !showContent else { return }
                withAnimation(Motion.enter) {
                    showContent = true
                }
            }
        }
    }

    private var settingsHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string("settings.title"))
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)

                Text(L10n.string("settings.subtitle"))
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: 840, alignment: .leading)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark")
                    Text(L10n.string("common.close"))
                }
            }
            .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: false))
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
    }

    private var settingsOverview: some View {
        HStack(spacing: 20) {
            SettingsHeroPanel(
                eyebrow: L10n.string("settings.card.profile.title"),
                title: userName,
                detail: showGreeting
                    ? L10n.string("settings.hero.dynamicGreetingEnabled")
                    : L10n.string("settings.hero.minimalDashboard"),
                symbol: "person.crop.circle.fill",
                tint: .cyan
            )

            SettingsHeroPanel(
                eyebrow: L10n.string("settings.card.weather.title"),
                title: weatherCity,
                detail: weatherModel.conditionDescription,
                symbol: weatherModel.conditionIcon,
                tint: .orange
            )

            SettingsHeroPanel(
                eyebrow: L10n.string("settings.hero.services"),
                title: L10n.string("settings.hero.connectedServices", connectedServicesCount),
                detail: L10n.string("settings.hero.activeRssSources", rssModel.feeds.count),
                symbol: "dot.radiowaves.left.and.right",
                tint: .mint
            )
        }
        .padding(.horizontal, 40)
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

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.32, green: 0.39, blue: 0.5))
                    .padding(12)
                    .background(Color.white.opacity(isFocused ? 0.5 : 0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.22, blue: 0.31))

                Text("settings.quickAction.subtitle")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.43, green: 0.50, blue: 0.60))
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .padding(18)
            .modifier(
                SettingsGlassPanel(
                    cornerRadius: 22,
                    tint: isFocused
                        ? Color.cyan.opacity(0.08) : .clear,
                    isInteractive: true,
                    isFocused: isFocused
                )
            )
        }
        .dashBDisableSystemFocusEffect()
        #if os(tvOS)
            .buttonStyle(.plain)
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

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(color.opacity(isFocused ? 0.42 : 0.24))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))
                        Text("settings.card.openAndEdit")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.43, green: 0.50, blue: 0.60))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.43, green: 0.50, blue: 0.60))
                }

                Divider().background(Color(red: 0.80, green: 0.84, blue: 0.90))

                content()
                    .foregroundStyle(Color(red: 0.20, green: 0.28, blue: 0.38))

                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 210)
            .modifier(
                SettingsGlassPanel(
                    cornerRadius: 26,
                    tint: color.opacity(isFocused ? 0.12 : 0.06),
                    isInteractive: true,
                    isFocused: isFocused
                )
            )
        }
        .dashBDisableSystemFocusEffect()
        #if os(tvOS)
            .buttonStyle(.plain)
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
        ZStack {
            GradientBackgroundView().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                Text("settings.editProfile.title")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))

                TextField("settings.editProfile.namePlaceholder", text: $tempName)
                    .textFieldStyle(.plain)
                    .padding()
                    .modifier(SettingsGlassPanel(cornerRadius: 20))

                Toggle("settings.editProfile.showGreeting", isOn: $showGreeting)
                    #if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
                        .tint(.blue)
                    #else
                        .toggleStyle(SwitchToggleStyle())
                    #endif
                    .padding(.vertical, 8)

                Button("common.save") {
                    userName = tempName
                    isPresented = false
                }
                .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: true))
            }
            .padding(50)
            .frame(maxWidth: 760)
            .modifier(SettingsGlassPanel(cornerRadius: 30, tint: .white.opacity(0.04)))
            .padding(40)
        }
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
        ZStack {
            GradientBackgroundView().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 30) {
                Text("settings.editWeather.title")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))

                TextField("settings.editWeather.cityPlaceholder", text: $tempCity)
                    .textFieldStyle(.plain)
                    .padding()
                    .modifier(SettingsGlassPanel(cornerRadius: 20))

                Button("settings.editWeather.useCurrentLocation") {
                    weatherModel.useCurrentLocation()
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            tempCity = weatherModel.selectedCity
                        }
                    }
                }
                .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: false))

                Button("common.save") {
                    city = tempCity
                    weatherModel.updateCity(tempCity)
                    isPresented = false
                }
                .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: true))

                VStack(spacing: 5) {
                    HStack(spacing: 4) {
                        Text("")
                        Text("settings.editWeather.appleWeather")
                    }
                    .font(.caption)
                    .foregroundColor(Color(red: 0.43, green: 0.50, blue: 0.60))

                    Button("settings.editWeather.legalAttribution") {
                        showAttributionQR = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundColor(Color(red: 0.43, green: 0.50, blue: 0.60))
                    .underline()
                }
                .padding(.top, 12)
            }
            .padding(50)
            .frame(maxWidth: 760)
            .modifier(SettingsGlassPanel(cornerRadius: 30, tint: .white.opacity(0.04)))
            .padding(40)
        }
        .onAppear { tempCity = city }
        .sheet(isPresented: $showAttributionQR) {
            if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                QRCodeView(url: url, title: L10n.string("settings.editWeather.legalAttribution"))
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
        ZStack {
            GradientBackgroundView()
                .overlay {
                    SettingsAmbientBackdrop()
                }

            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.accounts.title")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))
                        Text("settings.accounts.subtitle")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.48))
                    }
                    Spacer()
                    Button("common.close") { dismiss() }
                        .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: false))
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)

                ScrollView {
                    VStack(spacing: 24) {
                        accountRow(
                            service: calendarManager.googleService,
                            icon: "g.circle.fill",
                            color: .red,
                            title: L10n.string("settings.accounts.googleCalendar"),
                            type: .google
                        )

                        accountRow(
                            service: calendarManager.outlookService,
                            icon: "m.circle.fill",
                            color: .blue,
                            title: L10n.string("settings.accounts.outlookCalendar"),
                            type: .outlook
                        )
                    }
                    .padding(40)
                }
            }
        }
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color.opacity(0.22))
                .frame(width: 92, height: 92)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))
                Text(
                    service.isConnected
                        ? L10n.string("settings.accounts.connected")
                        : L10n.string("settings.accounts.notConnected")
                )
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(service.isConnected ? .green : Color(red: 0.43, green: 0.50, blue: 0.60))
            }

            Spacer()

            HStack(spacing: 14) {
                if service.isConnected {
                    Button("settings.accounts.manage") {
                        showingCalendarSelection = type
                    }
                    .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: true))

                    Button("settings.accounts.signOut") {
                        service.logout()
                    }
                    .buttonStyle(PremiumButtonStyle(isDestructive: true))
                } else {
                    Button("settings.accounts.connect") {
                        authServiceItem = SettingsView.AuthServiceItem(service: service)
                    }
                    .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: true))
                }
            }
        }
        .padding(30)
        .modifier(SettingsGlassPanel(cornerRadius: 28, tint: color.opacity(0.08)))
    }
}

private struct SettingsAmbientBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.95, blue: 1.0),
                    Color(red: 0.86, green: 0.91, blue: 0.98),
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 740, height: 740)
                .blur(radius: 160)
                .offset(x: -480, y: -280)

            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 640, height: 640)
                .blur(radius: 140)
                .offset(x: 560, y: -250)
        }
        .ignoresSafeArea()
    }
}

private struct SettingsHeroPanel: View {
    let eyebrow: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.22))
                .frame(width: 74, height: 74)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color(red: 0.35, green: 0.42, blue: 0.52))
                }
                .modifier(
                    SettingsGlassPanel(
                        cornerRadius: 22,
                        tint: tint.opacity(0.08),
                        glassTint: tint,
                        isInteractive: false
                    )
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.43, green: 0.50, blue: 0.60))
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))
                Text(detail)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.30, green: 0.38, blue: 0.48))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .modifier(
            SettingsGlassPanel(
                cornerRadius: 28,
                tint: tint.opacity(0.08),
                glassTint: tint,
                isInteractive: false
            )
        )
    }
}

private struct SettingsValueStack: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primary)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.14, green: 0.20, blue: 0.29))
                .lineLimit(2)

            Text(secondary)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.43, green: 0.50, blue: 0.60))
                .lineLimit(2)
        }
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.20, green: 0.28, blue: 0.38))

            Spacer()

            Text(L10n.string(isActive ? "settings.status.active" : "settings.status.offline"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.43, green: 0.50, blue: 0.60))
        }
    }
}

private struct SettingsGlassPanel: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color = .clear
    var glassTint: Color = .white
    var isInteractive: Bool = false
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseFillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 1.8 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isFocused ? 0.28 : 0.18),
                                Color.white.opacity(0.06),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isFocused ? 0.08 : 0.05),
                                .clear,
                                glassTint.opacity(isFocused ? 0.06 : 0.03),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .settingsLiquidGlass(
                cornerRadius: cornerRadius,
                tint: glassTint,
                interactive: isInteractive
            )
            .scaleEffect(isFocused ? 1.012 : 1)
            .shadow(color: shadowColor, radius: isFocused ? 32 : 28, y: isFocused ? 14 : 12)
            .animation(Motion.focus, value: isFocused)
    }

    private var baseFillColor: Color {
        if isFocused {
            return Color.white.opacity(0.52)
        }
        return Color.white.opacity(0.24)
    }

    private var borderColor: Color {
        if isFocused {
            return Color(red: 0.62, green: 0.76, blue: 0.95)
        }
        return Color.white.opacity(0.55)
    }

    private var shadowColor: Color {
        if isFocused {
            return Color(red: 0.61, green: 0.73, blue: 0.90).opacity(0.26)
        }
        return Color(red: 0.61, green: 0.73, blue: 0.90).opacity(0.18)
    }
}

private struct SettingsAdaptiveGlassButtonStyle: PrimitiveButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        SettingsAdaptiveGlassButtonLabel(
            configuration: configuration,
            prominent: prominent
        )
    }
}

private struct SettingsAdaptiveGlassButtonLabel: View {
    let configuration: PrimitiveButtonStyleConfiguration
    let prominent: Bool

    var body: some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            if prominent {
                Button(role: nil, action: configuration.trigger) {
                    configuration.label
                }
                .buttonStyle(GlassProminentButtonStyle())
            } else {
                Button(role: nil, action: configuration.trigger) {
                    configuration.label
                }
                .buttonStyle(GlassButtonStyle())
            }
        } else {
            Button(role: nil, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(PremiumButtonStyle())
        }
    }
}

private extension View {
    @ViewBuilder
    func settingsLiquidGlass(cornerRadius: CGFloat, tint: Color = .white, interactive: Bool = false)
        -> some View
    {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(
                interactive
                    ? .regular.tint(tint.opacity(0.18)).interactive()
                    : .regular.tint(tint.opacity(0.1)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
        }
    }

    @ViewBuilder
    func dashBDisableSystemFocusEffect() -> some View {
        if #available(tvOS 17.0, iOS 17.0, macOS 14.0, visionOS 1.0, watchOS 10.0, *) {
            self
                .focusEffectDisabled()
                .hoverEffectDisabled(true)
        } else {
            self
        }
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
