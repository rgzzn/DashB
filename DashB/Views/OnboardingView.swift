//
//  OnboardingView.swift
//  DashB
//
//  Created by Codex on 27/01/26.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var weatherModel: WeatherModel
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var rssModel: RSSModel

    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showGreeting") private var showGreeting = true
    @AppStorage("weatherCity") private var weatherCity = L10n.string("onboarding.weather.cityPreset.milan")
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentStep: OnboardingStep = .welcome
    @State private var draftName = ""
    @State private var draftCity = ""
    @State private var selectedFeeds: [FeedConfig] = []
    @State private var customFeedName = ""
    @State private var customFeedURL = ""
    @State private var validationError: String?
    @State private var authServiceItem: AuthServiceItem?
    @State private var calendarSelectionTarget: CalendarSelectionTarget?
    @State private var contentVisible = false
    @FocusState private var focusedElement: FocusElement?

    private let weatherCityPresetKeys = [
        "onboarding.weather.cityPreset.milan",
        "onboarding.weather.cityPreset.rome",
        "onboarding.weather.cityPreset.forli",
    ]

    private let feedSuggestions: [FeedConfig] = [
        FeedConfig(url: "https://www.ansa.it/emiliaromagna/notizie/emiliaromagna_rss.xml", source: "ANSA"),
        FeedConfig(url: "https://www.forlitoday.it/rss", source: "ForlìToday"),
        FeedConfig(url: "https://www.ilrestodelcarlino.it/forli/rss", source: "Il Resto del Carlino"),
        FeedConfig(url: "https://www.corriereromagna.it/forli/feed/", source: "Corriere Romagna"),
        FeedConfig(url: "https://www.comune.forli.fc.it/it/notizie/rss", source: "Comune di Forlì"),
        FeedConfig(url: "https://www.comune.forli.fc.it/it/eventi/rss", source: "Eventi Forlì"),
    ]

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .overlay {
                    onboardingBackdrop
                }
                .ignoresSafeArea()

            VStack(spacing: 30) {
                header
                stepContainer
                footer
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
        }
        .sheet(item: $authServiceItem) { item in
            DeviceLoginView(service: item.service)
                .environmentObject(calendarManager)
        }
        .sheet(item: $calendarSelectionTarget) { target in
            switch target {
            case .google:
                CalendarSelectionView(
                    service: calendarManager.googleService,
                    selectedConfigs: Binding(
                        get: { calendarManager.selectedGoogleCalendars },
                        set: { calendarManager.selectedGoogleCalendars = $0 }
                    )
                )
            case .outlook:
                CalendarSelectionView(
                    service: calendarManager.outlookService,
                    selectedConfigs: Binding(
                        get: { calendarManager.selectedOutlookCalendars },
                        set: { calendarManager.selectedOutlookCalendars = $0 }
                    )
                )
            }
        }
        .alert(
            "onboarding.alert.checkData",
            isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )
        ) {
            Button("common.ok", role: .cancel) {
                validationError = nil
            }
        } message: {
            Text(validationError ?? "")
        }
        .onAppear {
            draftName = userName
            draftCity = weatherCity
            selectedFeeds = rssModel.feeds
            withAnimation(Motion.enter) {
                contentVisible = true
            }
        }
        .animation(Motion.standard, value: currentStep)
    }

    private var onboardingBackdrop: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 720, height: 720)
                .blur(radius: 120)
                .offset(x: -420, y: -220)

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 560, height: 560)
                .blur(radius: 100)
                .offset(x: 520, y: -260)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 70)
                .offset(x: 420, y: 260)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("app.name")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .modifier(OnboardingGlassBadge())

                Spacer()

                Text(currentStep.caption)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }

            HStack(spacing: 12) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step == currentStep ? Color.white.opacity(0.92) : Color.white.opacity(0.18))
                        .frame(width: step == currentStep ? 74 : 28, height: 8)
                        .animation(Motion.focus, value: currentStep)
                }
            }
        }
    }

    private var stepContainer: some View {
        ZStack {
            stepContent(for: currentStep)
                .id(currentStep)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.985)), removal: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusSection()
    }

    @ViewBuilder
    private func stepContent(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            welcomeStep
        case .profile:
            profileStep
        case .weather:
            weatherStep
        case .calendars:
            calendarsStep
        case .news:
            newsStep
        case .finish:
            finishStep
        }
    }

    private var welcomeStep: some View {
        HStack(spacing: 36) {
            VStack(alignment: .leading, spacing: 24) {
                Text("onboarding.welcome.title")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(8)

                Text("onboarding.welcome.subtitle")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 760, alignment: .leading)

                featureStrip
            }

            Spacer()

            previewCluster
                .frame(width: 520)
        }
        .padding(44)
        .modifier(OnboardingCardStyle())
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 18)
    }

    private var profileStep: some View {
        onboardingFormLayout(
            title: L10n.string("onboarding.profile.title"),
            subtitle: L10n.string("onboarding.profile.subtitle")
        ) {
            VStack(alignment: .leading, spacing: 18) {
                OnboardingField(
                    title: L10n.string("onboarding.profile.field.name"),
                    text: $draftName,
                    prompt: L10n.string("onboarding.profile.field.name.placeholder")
                )

                Toggle("onboarding.profile.showContextGreeting", isOn: $showGreeting)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .toggleStyle(.switch)
                    .padding(22)
                    .modifier(OnboardingPanelStyle())

                Text(exampleGreeting)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(OnboardingPanelStyle())
            }
        }
    }

    private var weatherStep: some View {
        onboardingFormLayout(
            title: L10n.string("onboarding.weather.title"),
            subtitle: L10n.string("onboarding.weather.subtitle")
        ) {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingField(
                    title: L10n.string("onboarding.weather.field.city"),
                    text: $draftCity,
                    prompt: L10n.string("onboarding.weather.field.city.placeholder")
                )

                HStack(spacing: 16) {
                    ForEach(weatherCityPresetKeys, id: \.self) { cityKey in
                        let city = L10n.string(cityKey)
                        Button(city) {
                            draftCity = city
                        }
                        .focused($focusedElement, equals: .weatherPreset(cityKey))
                        .buttonStyle(OnboardingGlassButtonStyle(prominent: false))
                    }
                }
                .focusSection()
                .onMoveCommand { direction in
                    guard direction == .down else { return }
                    focusedElement = .continueButton
                }

                weatherPreviewPanel
            }
        }
    }

    private var calendarsStep: some View {
        onboardingFormLayout(
            title: L10n.string("onboarding.calendars.title"),
            subtitle: L10n.string("onboarding.calendars.subtitle")
        ) {
            HStack(spacing: 24) {
                calendarServiceCard(
                    title: L10n.string("onboarding.calendars.google"),
                    color: .red,
                    isConnected: calendarManager.googleService.isConnected,
                    connect: { authServiceItem = AuthServiceItem(service: calendarManager.googleService) },
                    manage: { calendarSelectionTarget = .google }
                )

                calendarServiceCard(
                    title: L10n.string("onboarding.calendars.outlook"),
                    color: .blue,
                    isConnected: calendarManager.outlookService.isConnected,
                    connect: { authServiceItem = AuthServiceItem(service: calendarManager.outlookService) },
                    manage: { calendarSelectionTarget = .outlook }
                )
            }
            .focusSection()

            HStack(spacing: 18) {
                statusPill(
                    title: L10n.string("onboarding.calendars.google"),
                    value: calendarManager.googleService.isConnected
                        ? L10n.string("onboarding.calendars.connected")
                        : L10n.string("onboarding.calendars.notConnected")
                )
                statusPill(
                    title: L10n.string("onboarding.calendars.outlook"),
                    value: calendarManager.outlookService.isConnected
                        ? L10n.string("onboarding.calendars.connected")
                        : L10n.string("onboarding.calendars.notConnected")
                )
                statusPill(
                    title: L10n.string("onboarding.calendars.activeCalendars"),
                    value: L10n.string("onboarding.calendars.activeCount", calendarCount)
                )
            }
        }
    }

    private var newsStep: some View {
        onboardingFormLayout(
            title: L10n.string("onboarding.news.title"),
            subtitle: L10n.string("onboarding.news.subtitle")
        ) {
            VStack(alignment: .leading, spacing: 22) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(feedSuggestions) { feed in
                        Button {
                            toggleFeed(feed)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(feed.source)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.96))

                                Text(feed.url)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(2)

                                Spacer()

                                Text(
                                    isFeedSelected(feed)
                                        ? L10n.string("onboarding.news.included")
                                        : L10n.string("common.add")
                                )
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isFeedSelected(feed) ? Color.cyan.opacity(0.22) : Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                        }
                        .buttonStyle(OnboardingFeedButtonStyle(selected: isFeedSelected(feed)))
                    }
                }
                .focusSection()

                HStack(spacing: 18) {
                    OnboardingField(
                        title: L10n.string("onboarding.news.field.sourceName"),
                        text: $customFeedName,
                        prompt: L10n.string("onboarding.news.field.sourceName.placeholder")
                    )
                    OnboardingField(
                        title: L10n.string("onboarding.news.field.rssURL"),
                        text: $customFeedURL,
                        prompt: L10n.string("onboarding.news.field.rssURL.placeholder")
                    )
                }
                .focusSection()

                HStack(spacing: 16) {
                    Button("onboarding.news.addCustomSource") {
                        addCustomFeed()
                    }
                    .buttonStyle(OnboardingGlassButtonStyle(prominent: true))

                    Text(L10n.string("onboarding.news.selectedSourcesCount", selectedFeeds.count))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
        }
    }

    private var finishStep: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 26) {
                Text("onboarding.finish.title")
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("onboarding.finish.subtitle")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: 760, alignment: .leading)

                summaryGrid
            }

            Spacer()

            VStack(spacing: 22) {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 160, weight: .light))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(40)
                    .modifier(OnboardingPanelStyle())

                Button("onboarding.finish.enterDashB") {
                    finishOnboarding()
                }
                .buttonStyle(OnboardingGlassButtonStyle(prominent: true))
            }
            .frame(width: 420)
        }
        .padding(44)
        .modifier(OnboardingCardStyle())
    }

    private var footer: some View {
        HStack {
            if currentStep != .welcome {
                Button("common.back") {
                    withAnimation(Motion.enter) {
                        currentStep = currentStep.previous ?? currentStep
                    }
                }
                .focused($focusedElement, equals: .backButton)
                .buttonStyle(
                    OnboardingGlassButtonStyle(
                        prominent: false,
                        externallyFocused: focusedElement == .backButton
                    )
                )
            }

            Spacer()

            if currentStep != .finish {
                Button(
                    L10n.string(currentStep == .welcome ? "onboarding.start" : "common.continue")
                ) {
                    advance()
                }
                .focused($focusedElement, equals: .continueButton)
                .buttonStyle(
                    OnboardingGlassButtonStyle(
                        prominent: true,
                        externallyFocused: focusedElement == .continueButton
                    )
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .focusSection()
    }

    private var featureStrip: some View {
        HStack(spacing: 14) {
            featureBadge(icon: "person.crop.circle", title: L10n.string("onboarding.feature.profile"))
            featureBadge(icon: "cloud.sun", title: L10n.string("onboarding.feature.weather"))
            featureBadge(icon: "calendar", title: L10n.string("onboarding.feature.agenda"))
            featureBadge(icon: "newspaper", title: L10n.string("onboarding.feature.news"))
        }
    }

    private var previewCluster: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                previewTile(
                    icon: "cloud.sun.fill",
                    title: L10n.string("onboarding.feature.weather"),
                    detail: L10n.string(
                        "onboarding.preview.readyForCity",
                        draftCity.isEmpty ? weatherCity : draftCity
                    )
                )
                previewTile(
                    icon: "calendar.badge.clock",
                    title: L10n.string("onboarding.feature.agenda"),
                    detail: L10n.string("onboarding.preview.activeCalendarsCount", calendarCount)
                )
            }

            previewTile(
                icon: "newspaper.fill",
                title: L10n.string("onboarding.feature.news"),
                detail: L10n.string(
                    "onboarding.preview.monitoredSourcesCount",
                    selectedFeeds.isEmpty ? rssModel.feeds.count : selectedFeeds.count
                )
            )
                .frame(maxWidth: .infinity)
        }
    }

    private var weatherPreviewPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("onboarding.weather.preview")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(draftCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? weatherCity : draftCity)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(weatherModel.weatherAdvice)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(2)
                }

                Spacer()

                Text(weatherModel.currentTemp)
                    .font(.system(size: 58, weight: .thin, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(26)
            .modifier(OnboardingPanelStyle())
        }
    }

    private var summaryGrid: some View {
        VStack(spacing: 16) {
            summaryRow(label: L10n.string("onboarding.summary.name"), value: resolvedName)
            summaryRow(label: L10n.string("onboarding.summary.weather"), value: resolvedCity)
            summaryRow(
                label: L10n.string("onboarding.summary.calendars"),
                value: L10n.string("onboarding.summary.selectedCalendarsCount", calendarCount)
            )
            summaryRow(
                label: L10n.string("onboarding.summary.rssFeeds"),
                value: L10n.string("onboarding.summary.sourcesCount", selectedFeeds.count)
            )
        }
    }

    private func onboardingFormLayout<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 34) {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: 620, alignment: .leading)

                Spacer()
            }
            .frame(width: 560, alignment: .leading)

            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(44)
        .modifier(OnboardingCardStyle())
    }

    private func featureBadge(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 20, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .modifier(OnboardingGlassBadge())
    }

    private func previewTile(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .padding(24)
        .modifier(OnboardingPanelStyle())
    }

    private func calendarServiceCard(
        title: String,
        color: Color,
        isConnected: Bool,
        connect: @escaping () -> Void,
        manage: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text(
                    isConnected
                        ? L10n.string("onboarding.calendars.connected")
                        : L10n.string("onboarding.calendars.toConnect")
                )
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isConnected ? Color.green : Color.white.opacity(0.62))
            }

            Text(
                isConnected
                    ? L10n.string("onboarding.calendars.connectedDetail")
                    : L10n.string("onboarding.calendars.connectDetail")
            )
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            HStack(spacing: 14) {
                Button(
                    L10n.string(
                        isConnected ? "onboarding.calendars.reconnect" : "settings.accounts.connect"
                    )
                ) {
                    connect()
                }
                .buttonStyle(OnboardingGlassButtonStyle(prominent: !isConnected))

                if isConnected {
                    Button("onboarding.calendars.chooseCalendars") {
                        manage()
                    }
                    .buttonStyle(OnboardingGlassButtonStyle(prominent: false))
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .leading)
        .modifier(OnboardingPanelStyle())
    }

    private func statusPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .modifier(OnboardingGlassBadge())
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .modifier(OnboardingPanelStyle())
    }

    private var exampleGreeting: String {
        let trimmed = resolvedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if showGreeting {
            return L10n.string("onboarding.profile.exampleGreeting", trimmed)
        }
        return trimmed
    }

    private var resolvedName: String {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.string("onboarding.defaultName") : trimmed
    }

    private var resolvedCity: String {
        let trimmed = draftCity.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? weatherCity : trimmed
    }

    private var calendarCount: Int {
        calendarManager.selectedGoogleCalendars.count + calendarManager.selectedOutlookCalendars.count
    }

    private func advance() {
        saveCurrentStepData()

        if currentStep == .finish {
            finishOnboarding()
            return
        }

        guard let next = currentStep.next else { return }
        withAnimation(Motion.enter) {
            currentStep = next
        }
    }

    private func saveCurrentStepData() {
        switch currentStep {
        case .profile:
            userName = resolvedName
        case .weather:
            weatherCity = resolvedCity
            weatherModel.updateCity(resolvedCity)
        case .news:
            rssModel.updateFeeds(selectedFeeds.isEmpty ? feedSuggestions : selectedFeeds)
        default:
            break
        }
    }

    private func finishOnboarding() {
        userName = resolvedName
        weatherCity = resolvedCity
        rssModel.updateFeeds(selectedFeeds.isEmpty ? feedSuggestions : selectedFeeds)
        weatherModel.updateCity(resolvedCity)
        hasCompletedOnboarding = true
    }

    private func toggleFeed(_ feed: FeedConfig) {
        if let index = selectedFeeds.firstIndex(of: feed) {
            selectedFeeds.remove(at: index)
        } else {
            selectedFeeds.append(feed)
        }
    }

    private func isFeedSelected(_ feed: FeedConfig) -> Bool {
        selectedFeeds.contains(feed)
    }

    private func addCustomFeed() {
        let normalizedName = customFeedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            validationError = L10n.string("onboarding.news.validation.enterSourceName")
            return
        }

        guard let validatedURL = FeedURLValidator.validatedHTTPSURL(from: customFeedURL) else {
            validationError = L10n.string("onboarding.news.validation.enterValidRSSURL")
            return
        }

        let feed = FeedConfig(url: validatedURL.absoluteString, source: normalizedName)
        guard !selectedFeeds.contains(feed) else {
            validationError = L10n.string("onboarding.news.validation.sourceAlreadyPresent")
            return
        }

        selectedFeeds.append(feed)
        customFeedName = ""
        customFeedURL = ""
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case profile
    case weather
    case calendars
    case news
    case finish

    var id: Int { rawValue }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }

    var caption: String {
        switch self {
        case .welcome: L10n.string("onboarding.step.welcome")
        case .profile: L10n.string("onboarding.step.profile")
        case .weather: L10n.string("onboarding.step.weather")
        case .calendars: L10n.string("onboarding.step.calendars")
        case .news: L10n.string("onboarding.step.news")
        case .finish: L10n.string("onboarding.step.finish")
        }
    }
}

private struct AuthServiceItem: Identifiable {
    let service: any CalendarService
    var id: String { service.serviceName }
}

private enum CalendarSelectionTarget: Identifiable {
    case google
    case outlook

    var id: Int { hashValue }
}

private enum FocusElement: Hashable {
    case backButton
    case continueButton
    case weatherPreset(String)
}

private struct OnboardingField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            TextField(prompt, text: $text)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
                .modifier(OnboardingPanelStyle())
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
        }
    }
}

private struct OnboardingCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                .clear,
                                Color.cyan.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .backgroundLiquidGlass(cornerRadius: 34, tint: .cyan)
            .shadow(color: .black.opacity(0.28), radius: 40, y: 14)
    }
}

private struct OnboardingPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                .clear,
                                Color.cyan.opacity(0.025),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .backgroundLiquidGlass(cornerRadius: 24, tint: .cyan)
    }
}

private struct OnboardingGlassBadge: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .backgroundLiquidGlassCapsule(tint: .white)
    }
}

private struct OnboardingGlassButtonStyle: PrimitiveButtonStyle {
    let prominent: Bool
    var externallyFocused: Bool? = nil
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        Button(role: nil, action: configuration.trigger) {
            configuration.label
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(minWidth: 160)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(backgroundFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(borderColor, lineWidth: effectiveFocused ? 2.4 : 1)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: sheenColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .backgroundLiquidGlass(
                    cornerRadius: 22,
                    tint: prominent ? .white : .cyan,
                    prominent: prominent
                )
                .overlay(alignment: .leading) {
                    if effectiveFocused {
                        Circle()
                            .fill(focusAccentColor)
                            .frame(width: 10, height: 10)
                            .padding(.leading, 14)
                            .transition(.opacity)
                    }
                }
                .shadow(color: buttonShadowColor, radius: effectiveFocused ? 22 : 10, y: effectiveFocused ? 10 : 4)
                .scaleEffect(effectiveFocused ? 1.045 : 1)
                .animation(Motion.focus, value: effectiveFocused)
        }
        .dashBDisableSystemFocusEffect()
        .buttonStyle(.plain)
    }

    private var effectiveFocused: Bool {
        externallyFocused ?? isFocused
    }

    private var foregroundColor: Color {
        if prominent {
            return effectiveFocused ? Color(red: 0.02, green: 0.08, blue: 0.16) : .black
        }
        return effectiveFocused ? Color.white.opacity(0.98) : .white
    }

    private var backgroundFillColor: Color {
        if prominent {
            return effectiveFocused
                ? Color(red: 0.82, green: 0.97, blue: 1.0).opacity(0.98)
                : Color.white.opacity(0.88)
        }
        return effectiveFocused
            ? Color(red: 0.05, green: 0.22, blue: 0.4).opacity(0.98)
            : Color(red: 0.12, green: 0.18, blue: 0.28).opacity(0.84)
    }

    private var borderColor: Color {
        if prominent {
            return effectiveFocused ? Color.cyan.opacity(1) : Color.white.opacity(0)
        }
        return effectiveFocused ? Color.cyan.opacity(0.95) : Color.cyan.opacity(0.22)
    }

    private var sheenColors: [Color] {
        let leading = Color.white.opacity(effectiveFocused ? (prominent ? 0.18 : 0.12) : (prominent ? 0.1 : 0.05))
        let trailing = prominent
            ? Color.cyan.opacity(effectiveFocused ? 0.08 : 0)
            : Color.cyan.opacity(effectiveFocused ? 0.12 : 0)
        return [leading, .clear, trailing]
    }

    private var buttonShadowColor: Color {
        if effectiveFocused {
            return prominent ? Color.cyan.opacity(0.42) : Color.cyan.opacity(0.34)
        }
        return .black.opacity(0.12)
    }

    private var focusAccentColor: Color {
        .cyan
    }
}

private struct OnboardingFeedButtonStyle: PrimitiveButtonStyle {
    let selected: Bool
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        Button(role: nil, action: configuration.trigger) {
            configuration.label
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(borderColor, lineWidth: isFocused ? 2.5 : 1.2)
                )
                .shadow(color: shadowColor, radius: isFocused ? 24 : 10, y: isFocused ? 12 : 4)
                .scaleEffect(isFocused ? 1.035 : 1)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isFocused ? 0.09 : 0.05),
                                    .clear,
                                    Color.cyan.opacity(isFocused ? (selected ? 0.1 : 0.06) : (selected ? 0.04 : 0.02)),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .backgroundLiquidGlass(cornerRadius: 24, tint: selected ? .cyan : .white)
        }
        .dashBDisableSystemFocusEffect()
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isFocused {
            return selected ? Color(red: 0.16, green: 0.24, blue: 0.36).opacity(0.96) : Color(red: 0.13, green: 0.18, blue: 0.28).opacity(0.94)
        }
        return selected ? Color(red: 0.11, green: 0.18, blue: 0.28).opacity(0.88) : Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        if isFocused {
            return selected ? Color.cyan.opacity(0.95) : Color.white.opacity(0.8)
        }
        return selected ? Color.cyan.opacity(0.55) : Color.white.opacity(0.12)
    }

    private var shadowColor: Color {
        selected ? Color.cyan.opacity(isFocused ? 0.32 : 0.12) : Color.white.opacity(isFocused ? 0.12 : 0.04)
    }
}

private extension View {
    @ViewBuilder
    func backgroundLiquidGlass(cornerRadius: CGFloat, tint: Color = .white, prominent: Bool = false)
        -> some View
    {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(
                prominent
                    ? .regular.tint(tint.opacity(0.14)).interactive()
                    : .regular.tint(tint.opacity(0.08)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self
        }
    }

    @ViewBuilder
    func backgroundLiquidGlassCapsule(tint: Color = .white) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.08)))
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

#Preview("OnboardingView") {
    OnboardingView()
        .environmentObject(WeatherModel())
        .environmentObject(CalendarManager())
        .environmentObject(RSSModel())
}
