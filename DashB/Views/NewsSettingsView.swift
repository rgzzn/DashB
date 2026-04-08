//
//  NewsSettingsView.swift
//  DashB
//
//  Created by Luca Ragazzini on 24/01/26.
//

import SwiftUI

struct NewsSettingsView: View {
    @EnvironmentObject var rssModel: RSSModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var newFeedUrl: String = ""
    @State private var newFeedSource: String = ""
    @State private var validationError: String?
    @State private var showContent = false
    @FocusState private var focusedElement: NewsSettingsFocusElement?
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    private let defaultFeeds: [FeedConfig] = [
        FeedConfig(
            url: "https://www.ansa.it/emiliaromagna/notizie/emiliaromagna_rss.xml", source: "ANSA"),
        FeedConfig(url: "https://www.forlitoday.it/rss", source: "ForlìToday"),
        FeedConfig(
            url: "https://www.ilrestodelcarlino.it/forli/rss", source: "Il Resto del Carlino"),
        FeedConfig(url: "https://www.corriereromagna.it/forli/feed/", source: "Corriere Romagna"),
        FeedConfig(url: "https://www.comune.forli.fc.it/it/notizie/rss", source: "Comune di Forlì"),
        FeedConfig(url: "https://www.comune.forli.fc.it/it/eventi/rss", source: "Eventi Forlì"),
    ]

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .overlay {
                    SubmenuAmbientBackdrop()
                }
                .ignoresSafeArea()

            VStack(spacing: 24) {
                header

                HStack(alignment: .top, spacing: 32) {
                    activeFeedsPanel
                    addFeedPanel
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .focusSection()
                .onMoveCommand { direction in
                    guard direction == .up else { return }
                    focusedElement = .closeButton
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 14)
            .animation(Motion.enter, value: showContent)
        }
        .alert(
            "newsSettings.alert.invalidURL.title",
            isPresented: Binding(
                get: { validationError != nil }, set: { if !$0 { validationError = nil } })
        ) {
            Button("common.ok", role: .cancel) { validationError = nil }
        } message: {
            Text(validationError ?? "")
        }
        .onAppear {
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("newsSettings.title")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)

                Text("newsSettings.subtitle")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer()

            Button("common.close") { dismiss() }
                .focused($focusedElement, equals: .closeButton)
                .buttonStyle(SubmenuAdaptiveGlassButtonStyle(prominent: false))
        }
        .padding(.horizontal, 40)
        .padding(.top, 40)
        .focusSection()
    }

    private var activeFeedsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("newsSettings.activeFeeds")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)

            ScrollView {
                VStack(spacing: 18) {
                    ForEach(rssModel.feeds, id: \.url) { feed in
                        HStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(feed.source)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.primaryText)

                                Text(feed.url)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button {
                                removeFeed(feed)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .buttonStyle(TrashButtonStyle())
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
                        .modifier(SubmenuGlassPanel(cornerRadius: 22, tint: .cyan.opacity(0.03)))
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .modifier(SubmenuGlassPanel(cornerRadius: 28, tint: .cyan.opacity(0.04)))
    }

    private var addFeedPanel: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("newsSettings.addSource")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)

            feedField(
                title: L10n.string("newsSettings.field.sourceName"),
                text: $newFeedSource,
                prompt: L10n.string("newsSettings.field.sourceName.placeholder")
            )

            feedField(
                title: L10n.string("newsSettings.field.rssURL"),
                text: $newFeedUrl,
                prompt: L10n.string("newsSettings.field.rssURL.placeholder"),
                lowercase: true
            )

            #if os(tvOS)
                Text(
                    "newsSettings.hint.remotePaste"
                )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            #endif

            Button {
                addNewFeed()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("common.add")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SubmenuAdaptiveGlassButtonStyle(prominent: true))
            .disabled(newFeedUrl.isEmpty || newFeedSource.isEmpty)
            .opacity((newFeedUrl.isEmpty || newFeedSource.isEmpty) ? 0.5 : 1)

            Spacer()

            Button {
                resetDefaults()
            } label: {
                Text("newsSettings.resetDefault")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SubmenuAdaptiveGlassButtonStyle(prominent: false))
        }
        .frame(width: 760)
        .padding(32)
        .modifier(SubmenuGlassPanel(cornerRadius: 30, tint: .purple.opacity(0.04)))
    }

    private func feedField(
        title: String,
        text: Binding<String>,
        prompt: String,
        lowercase: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(theme.secondaryText)

            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding()
                .modifier(SubmenuGlassPanel(cornerRadius: 18))
                .textInputAutocapitalization(lowercase ? .never : .words)
                .disableAutocorrection(true)
        }
    }

    private func removeFeed(_ feed: FeedConfig) {
        var currentFeeds = rssModel.feeds
        currentFeeds.removeAll { $0.url == feed.url }
        rssModel.updateFeeds(currentFeeds)
    }

    private func addNewFeed() {
        guard !newFeedUrl.isEmpty, !newFeedSource.isEmpty else { return }

        guard let validatedURL = FeedURLValidator.validatedHTTPSURL(from: newFeedUrl) else {
            validationError =
                L10n.string("newsSettings.validation.invalidURL")
            return
        }

        let normalizedSource = newFeedSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSource.isEmpty else {
            validationError = L10n.string("newsSettings.validation.emptySourceName")
            return
        }

        let newFeed = FeedConfig(url: validatedURL.absoluteString, source: normalizedSource)
        var currentFeeds = rssModel.feeds

        if currentFeeds.contains(where: { $0.url == newFeed.url }) {
            validationError = L10n.string("newsSettings.validation.duplicateSource")
            return
        }

        currentFeeds.append(newFeed)
        rssModel.updateFeeds(currentFeeds)
        newFeedUrl = ""
        newFeedSource = ""
    }

    private func resetDefaults() {
        rssModel.updateFeeds(defaultFeeds)
    }
}

private enum NewsSettingsFocusElement: Hashable {
    case closeButton
}

struct TrashButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isFocused ? .white : .red)
            .padding(14)
            .background(
                Circle()
                    .fill(isFocused ? Color.red.opacity(0.9) : Color.red.opacity(0.15))
            )
            .shadow(color: Color.red.opacity(isFocused ? 0.28 : 0.1), radius: isFocused ? 14 : 6)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(Motion.focus, value: isFocused)
            .padding(8)
            .dashBDisableSystemFocusEffect()
    }
}

private struct SubmenuAmbientBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.15 : 0.12))
                .frame(width: 620, height: 620)
                .blur(radius: 120)
                .offset(x: -420, y: -220)

            Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.16 : 0.1))
                .frame(width: 520, height: 520)
                .blur(radius: 100)
                .offset(x: 420, y: -180)

            Circle()
                .fill(
                    colorScheme == .dark
                        ? Color.blue.opacity(0.18)
                        : Color.white.opacity(0.1)
                )
                .frame(width: 540, height: 540)
                .blur(radius: 110)
                .offset(x: 430, y: 200)
        }
        .ignoresSafeArea()
    }
}

private struct SubmenuGlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    var tint: Color = .clear
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.panelMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.panelFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.primaryText.opacity(0.08), .clear, tint.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .dashBLiquidGlass(
                cornerRadius: cornerRadius,
                tint: theme.glassTint,
                staticTintOpacity: colorScheme == .dark ? 0.12 : 0.08
            )
            .shadow(color: theme.panelShadow, radius: 26, y: 12)
    }
}

private struct SubmenuAdaptiveGlassButtonStyle: PrimitiveButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        Button(role: nil, action: configuration.trigger) {
            configuration.label
        }
        .dashBDisableSystemFocusEffect()
        .modifier(SubmenuButtonChrome(prominent: prominent))
        .buttonStyle(.plain)
    }
}

private struct SubmenuButtonChrome: ViewModifier {
    let prominent: Bool
    @Environment(\.isFocused) private var isFocused
    @Environment(\.colorScheme) private var colorScheme
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(prominent ? Color.black.opacity(0.88) : theme.primaryText)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        prominent
                            ? Color.white.opacity(0.9)
                            : theme.panelFill.opacity(colorScheme == .dark ? 1.25 : 0.96)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        prominent ? Color.clear : theme.focusStroke.opacity(isFocused ? 0.8 : 0.4),
                        lineWidth: isFocused ? 1.6 : 1
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(isFocused ? 0.08 : 0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .dashBLiquidGlass(
                cornerRadius: 20,
                tint: prominent ? .white : theme.glassTint,
                interactive: true,
                interactiveTintOpacity: colorScheme == .dark ? 0.24 : 0.16
            )
            .scaleEffect(isFocused ? 1.05 : 1)
            .shadow(color: theme.focusShadow.opacity(isFocused ? 1 : 0.5), radius: isFocused ? 24 : 16, y: isFocused ? 10 : 6)
            .animation(Motion.focus, value: isFocused)
    }
}

private extension View {
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

#Preview {
    NewsSettingsView()
        .environmentObject(RSSModel())
        .background(GradientBackgroundView().ignoresSafeArea())
}
