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
    @Environment(\.colorScheme) private var colorScheme
    private let onClose: (() -> Void)?

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

    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }
    private var headerPrimaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.99) : theme.primaryText
    }
    private var headerSecondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.86) : theme.secondaryText
    }

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

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
            Task { @MainActor in
                rssModel.fetchNews()
            }
        }

        QuickActionButton(
            icon: "sparkles.rectangle.stack", title: L10n.string("settings.quickAction.reviewTour")
        ) {
            hasCompletedOnboarding = false
            closeView()
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

    private var settingsHeader: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string("settings.title"))
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(headerPrimaryText)

                Text(L10n.string("settings.subtitle"))
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(headerSecondaryText)
                    .frame(maxWidth: 840, alignment: .leading)
            }

            Spacer()

            Button {
                closeView()
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

    private func closeView() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

enum SettingsDestination: Hashable {
    case agenda
    case news
}

private struct SettingsButtonPalette {
    let primary: Color
    let secondary: Color
    let divider: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            primary = Color.white.opacity(0.98)
            secondary = Color.white.opacity(0.86)
            divider = Color.white.opacity(0.2)
        } else {
            primary = Color(red: 0.08, green: 0.09, blue: 0.12)
            secondary = Color(red: 0.42, green: 0.45, blue: 0.5)
            divider = Color.black.opacity(0.08)
        }
    }
}

// MARK: - Subviews & Components

// MARK: - Subviews & Components

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }
    private var palette: SettingsButtonPalette { SettingsButtonPalette(colorScheme: colorScheme) }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.primary)
                .padding(12)
                .background(theme.subtleFill.opacity(isFocused ? 1.4 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primary)

            Text("settings.quickAction.subtitle")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(18)
        .scaleEffect(isFocused ? 1.02 : 1)
        .zIndex(isFocused ? 20 : 0)
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

    var body: some View {
        #if os(tvOS)
            content
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .focusable(interactions: .activate)
                .focused($isFocused)
                .onTapGesture(perform: action)
                .accessibilityAddTraits(.isButton)
        #else
            Button(action: action) {
                content
            }
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

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }
    private var palette: SettingsButtonPalette { SettingsButtonPalette(colorScheme: colorScheme) }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.primary)
                    .padding(12)
                    .background(color.opacity(isFocused ? 0.42 : 0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primary)
                    Text("settings.card.openAndEdit")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.secondary)
            }

            Divider().background(palette.divider)

            content()
                .foregroundStyle(palette.secondary)

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 210)
        .scaleEffect(isFocused ? 1.02 : 1)
        .zIndex(isFocused ? 20 : 0)
        .modifier(
            SettingsGlassPanel(
                cornerRadius: 26,
                tint: color.opacity(isFocused ? 0.12 : 0.06),
                isInteractive: true,
                isFocused: isFocused
            )
        )
    }

    var body: some View {
        #if os(tvOS)
            contentView
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .focusable(interactions: .activate)
                .focused($isFocused)
                .onTapGesture(perform: action)
                .accessibilityAddTraits(.isButton)
        #else
            Button(action: action) {
                contentView
            }
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
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    var body: some View {
        ZStack {
            GradientBackgroundView().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                Text("settings.editProfile.title")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)

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
            .modifier(SettingsGlassPanel(cornerRadius: 30, tint: theme.elevatedTint))
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
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    var body: some View {
        ZStack {
            GradientBackgroundView().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 30) {
                Text("settings.editWeather.title")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)

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
                    .foregroundColor(theme.secondaryText)

                    Button("settings.editWeather.legalAttribution") {
                        showAttributionQR = true
                    }
                    .font(.caption2)
                    .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: false))
                }
                .padding(.top, 12)
            }
            .padding(50)
            .frame(maxWidth: 760)
            .modifier(SettingsGlassPanel(cornerRadius: 30, tint: theme.elevatedTint))
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
    @Environment(\.colorScheme) private var colorScheme

    // Auth State for this view
    @State private var authServiceItem: SettingsView.AuthServiceItem?
    @State private var showingCalendarSelection: CalendarType?

    enum CalendarType: Identifiable {
        case google, outlook
        var id: Int { self.hashValue }
    }

    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

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
                            .foregroundStyle(theme.primaryText)
                        Text("settings.accounts.subtitle")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.secondaryText)
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
                        .foregroundStyle(theme.primaryText)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text(
                    service.isConnected
                        ? L10n.string("settings.accounts.connected")
                        : L10n.string("settings.accounts.notConnected")
                )
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(service.isConnected ? .green : theme.tertiaryText)
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
                    .buttonStyle(SettingsAdaptiveGlassButtonStyle(prominent: false, isDestructive: true))
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
    @Environment(\.colorScheme) private var colorScheme

    private var backdropGradient: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.09, blue: 0.16),
                Color(red: 0.07, green: 0.12, blue: 0.21),
                Color(red: 0.04, green: 0.07, blue: 0.15),
            ]
        }
        return [
            Color(red: 0.91, green: 0.95, blue: 1.0),
            Color(red: 0.86, green: 0.91, blue: 0.98),
            Color(red: 0.95, green: 0.97, blue: 1.0),
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backdropGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.16 : 0.1))
                .frame(width: 680, height: 680)
                .blur(radius: 120)
                .offset(x: -440, y: -250)

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(width: 560, height: 560)
                .blur(radius: 100)
                .offset(x: 540, y: -220)

            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color.indigo.opacity(0.24)
                        : Color.white.opacity(0.7)
                )
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
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }
    private var eyebrowColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.76) : theme.tertiaryText
    }
    private var detailColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.86) : theme.secondaryText
    }

    var body: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.22))
                .frame(width: 74, height: 74)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
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
                    .foregroundStyle(eyebrowColor)
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text(detail)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(detailColor)
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
    @Environment(\.colorScheme) private var colorScheme
    private var palette: SettingsButtonPalette { SettingsButtonPalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(primary)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primary)
                .lineLimit(2)

            Text(secondary)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(palette.secondary)
                .lineLimit(2)
        }
    }
}

private struct SettingsStatusRow: View {
    let title: String
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var palette: SettingsButtonPalette { SettingsButtonPalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primary)

            Spacer()

            Text(L10n.string(isActive ? "settings.status.active" : "settings.status.offline"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondary)
        }
    }
}

private struct SettingsGlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    var tint: Color = .clear
    var glassTint: Color = .white
    var isInteractive: Bool = false
    var isFocused: Bool = false

    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }
    private var usesButtonChrome: Bool { isInteractive }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(panelBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(baseFillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        borderColor,
                        lineWidth: usesButtonChrome && isFocused ? 2.2 : (isFocused ? 1.6 : 1)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(usesButtonChrome ? tint.opacity(isFocused ? 0.35 : 0.2) : tint)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                topHighlightStart,
                                topHighlightMid,
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
                                topGlowLeading,
                                .clear,
                                topGlowTrailing,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                if usesButtonChrome && isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.95 : 0.72),
                                    liquidGlassTint.opacity(colorScheme == .dark ? 0.9 : 0.58),
                                    Color.white.opacity(colorScheme == .dark ? 0.56 : 0.32),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.4
                        )
                }
            }
            .overlay {
                if usesButtonChrome && isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(liquidGlassTint.opacity(colorScheme == .dark ? 0.52 : 0.28), lineWidth: 5.5)
                        .blur(radius: 8)
                        .padding(-3)
                }
            }
            .overlay(alignment: .topLeading) {
                if usesButtonChrome && isFocused {
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.26 : 0.18))
                        .frame(width: cornerRadius * 1.2, height: cornerRadius * 1.2)
                        .blur(radius: 12)
                        .offset(x: 18, y: 14)
                }
            }
            .settingsLiquidGlass(
                cornerRadius: cornerRadius,
                tint: liquidGlassTint,
                interactive: usesButtonChrome
            )
            .brightness(colorScheme == .dark && usesButtonChrome && isFocused ? 0.03 : 0)
            .saturation(colorScheme == .dark && usesButtonChrome && isFocused ? 1.06 : 1)
            .scaleEffect(isFocused ? (usesButtonChrome ? 1.06 : 1.01) : 1)
            .offset(y: usesButtonChrome && isFocused ? -2 : 0)
            .zIndex(usesButtonChrome && isFocused ? 15 : 0)
            .shadow(
                color: shadowColor,
                radius: isFocused ? (usesButtonChrome ? 38 : 28) : (usesButtonChrome ? 24 : 16),
                y: isFocused ? (usesButtonChrome ? 14 : 9) : (usesButtonChrome ? 10 : 5)
            )
            .animation(Motion.focus, value: isFocused)
    }

    private var baseFillColor: Color {
        if colorScheme == .dark {
            if usesButtonChrome {
                return isFocused
                    ? Color(red: 0.17, green: 0.28, blue: 0.45).opacity(0.7)
                    : Color(red: 0.11, green: 0.20, blue: 0.34).opacity(0.52)
            }
            return isFocused
                ? Color(red: 0.14, green: 0.25, blue: 0.41).opacity(0.62)
                : Color(red: 0.1, green: 0.18, blue: 0.31).opacity(0.48)
        }

        if usesButtonChrome {
            return isFocused
                ? theme.focusFill.opacity(colorScheme == .dark ? 0.96 : 0.78)
                : theme.panelFill.opacity(colorScheme == .dark ? 1.1 : 0.92)
        }
        return isFocused ? theme.focusFill : theme.panelFill
    }

    private var borderColor: Color {
        if colorScheme == .dark {
            if usesButtonChrome {
                return isFocused
                    ? Color(red: 0.6, green: 0.84, blue: 1.0).opacity(0.9)
                    : Color(red: 0.39, green: 0.67, blue: 0.96).opacity(0.46)
            }
            return isFocused
                ? Color(red: 0.52, green: 0.77, blue: 1.0).opacity(0.74)
                : Color(red: 0.34, green: 0.61, blue: 0.92).opacity(0.38)
        }

        if usesButtonChrome {
            return isFocused
                ? theme.focusStroke.opacity(colorScheme == .dark ? 0.82 : 0.7)
                : theme.panelStroke.opacity(colorScheme == .dark ? 1.2 : 1.05)
        }
        return isFocused ? theme.focusStroke : theme.panelStroke
    }

    private var shadowColor: Color {
        if colorScheme == .dark {
            if usesButtonChrome {
                return isFocused
                    ? Color(red: 0.06, green: 0.35, blue: 0.78).opacity(0.4)
                    : Color.black.opacity(0.3)
            }
            return isFocused
                ? Color(red: 0.05, green: 0.27, blue: 0.63).opacity(0.24)
                : Color.black.opacity(0.26)
        }

        if usesButtonChrome {
            return isFocused ? theme.focusShadow.opacity(0.9) : theme.panelShadow.opacity(1.2)
        }
        return isFocused ? theme.focusShadow : theme.panelShadow
    }

    private var panelBackground: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(.ultraThinMaterial)
        }
        return AnyShapeStyle(theme.panelMaterial)
    }

    private var liquidGlassTint: Color {
        if colorScheme == .dark {
            return usesButtonChrome
                ? Color(red: 0.36, green: 0.64, blue: 0.98)
                : Color(red: 0.31, green: 0.59, blue: 0.94)
        }
        return glassTint
    }

    private var topHighlightStart: Color {
        if colorScheme == .dark {
            return Color.white.opacity(usesButtonChrome ? (isFocused ? 0.28 : 0.18) : (isFocused ? 0.24 : 0.16))
        }
        return theme.primaryText.opacity(
            usesButtonChrome ? (isFocused ? 0.14 : 0.1) : (isFocused ? 0.22 : 0.14)
        )
    }

    private var topHighlightMid: Color {
        if colorScheme == .dark {
            return Color.white.opacity(usesButtonChrome ? 0.08 : 0.1)
        }
        return theme.primaryText.opacity(usesButtonChrome ? 0.03 : 0.04)
    }

    private var topGlowLeading: Color {
        if colorScheme == .dark {
            return Color.white.opacity(usesButtonChrome ? (isFocused ? 0.11 : 0.07) : (isFocused ? 0.1 : 0.06))
        }
        return theme.primaryText.opacity(
            usesButtonChrome ? (isFocused ? 0.04 : 0.025) : (isFocused ? 0.06 : 0.04)
        )
    }

    private var topGlowTrailing: Color {
        if colorScheme == .dark {
            return liquidGlassTint.opacity(usesButtonChrome ? (isFocused ? 0.14 : 0.08) : (isFocused ? 0.13 : 0.08))
        }
        return glassTint.opacity(
            usesButtonChrome ? (isFocused ? 0.045 : 0.02) : (isFocused ? 0.06 : 0.03)
        )
    }
}

private struct SettingsAdaptiveGlassButtonStyle: PrimitiveButtonStyle {
    let prominent: Bool
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Button(role: isDestructive ? .destructive : nil, action: configuration.trigger) {
            configuration.label
        }
        .buttonStyle(SettingsFallbackGlassButtonStyle(prominent: prominent, isDestructive: isDestructive))
    }
}

private struct SettingsFallbackGlassButtonStyle: ButtonStyle {
    let prominent: Bool
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        SettingsFallbackGlassButton(configuration: configuration, prominent: prominent, isDestructive: isDestructive)
    }
}

private struct SettingsFallbackGlassButton: View {
    let configuration: ButtonStyle.Configuration
    let prominent: Bool
    let isDestructive: Bool

    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorScheme) private var colorScheme

    private var palette: SettingsButtonPalette { SettingsButtonPalette(colorScheme: colorScheme) }

    var body: some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.vertical, prominent ? 16 : 14)
            .padding(.horizontal, prominent ? 30 : 26)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused ? 2.2 : 1)
            )
            .overlay(alignment: .top) {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isFocused ? 0.72 : 0.55),
                                Color.white.opacity(0.16),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(isFocused ? 0.24 : 0.18), radius: isFocused ? 28 : 22, y: isFocused ? 10 : 8)
            .scaleEffect(isFocused ? 1.02 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.focus, value: isFocused)
            .animation(Motion.quick, value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        if isDestructive {
            return colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.72)
        }
        if prominent {
            return colorScheme == .dark ? Color.white.opacity(0.22) : Color.white.opacity(0.78)
        }
        return colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.62)
    }

    private var foregroundColor: Color {
        if isDestructive {
            return Color.red.opacity(0.9)
        }
        return palette.primary
    }

    private var borderColor: Color {
        if isFocused {
            return colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.18)
        }
        return colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.08)
    }
}

private extension View {
    @ViewBuilder
    func settingsLiquidGlass(
        cornerRadius: CGFloat,
        tint: Color = .white,
        interactive: Bool = false
    ) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(
                interactive
                    ? .regular.tint(tint.opacity(0.24)).interactive()
                    : .regular.tint(tint.opacity(0.12)),
                in: .rect(cornerRadius: cornerRadius)
            )
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
