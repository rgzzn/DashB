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

    @State private var newFeedUrl: String = ""
    @State private var newFeedSource: String = ""
    @State private var isAddingFeed = false

    // Default feeds backup for reset
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Gestione Notizie")
                    .font(.system(size: 38, weight: .bold))
                Spacer()
                Button("Chiudi") { dismiss() }
                    .buttonStyle(PremiumButtonStyle())
            }
            .padding(40)
            .background(Color.black.opacity(0.3))

            // Content
            HStack(spacing: 40) {
                // List of Feeds
                VStack(alignment: .leading, spacing: 20) {
                    Text("Fonti RSS Attive")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))

                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(rssModel.feeds, id: \.url) { feed in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(feed.source)
                                            .font(.headline)
                                        Text(feed.url)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Button {
                                        removeFeed(feed)
                                    } label: {
                                        Image(systemName: "trash")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(TrashButtonStyle())
                                    .padding(.leading, 15)
                                }
                                .padding(.vertical, 15)
                                .padding(.horizontal, 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }
                        .padding(40)
                    }
                }
                .frame(maxWidth: .infinity)

                // Add New Feed Panel
                VStack(alignment: .leading, spacing: 30) {
                    Text("Aggiungi Fonte")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 10)
                        .fixedSize(horizontal: false, vertical: true)  // Prevent vertical clipping

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nome Fonte")
                            .font(.headline)
                        TextField("Es. BBC News", text: $newFeedSource)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            #if os(tvOS)
                                .focusEffect(.none)
                            #endif
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("URL RSS")
                            .font(.headline)
                        TextField("https://...", text: $newFeedUrl)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            #if os(tvOS)
                                .focusEffect(.none)
                            #endif
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }

                    Button {
                        addNewFeed()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Aggiungi")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PremiumButtonStyle())
                    .disabled(newFeedUrl.isEmpty || newFeedSource.isEmpty)
                    .opacity((newFeedUrl.isEmpty || newFeedSource.isEmpty) ? 0.5 : 1)

                    Spacer()

                    Button {
                        resetDefaults()
                    } label: {
                        Text("Ripristina Default")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 20)
                }
                .frame(width: 750)  // Increased width to 750
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.03))
                )
            }
            .padding(40)
        }
        .background(GradientBackgroundView().ignoresSafeArea())
    }

    private func removeFeed(_ feed: FeedConfig) {
        var currentFeeds = rssModel.feeds
        currentFeeds.removeAll { $0.url == feed.url }
        rssModel.updateFeeds(currentFeeds)
    }

    private func addNewFeed() {
        guard !newFeedUrl.isEmpty, !newFeedSource.isEmpty else { return }
        let newFeed = FeedConfig(url: newFeedUrl, source: newFeedSource)
        var currentFeeds = rssModel.feeds
        currentFeeds.append(newFeed)
        rssModel.updateFeeds(currentFeeds)

        // Reset fields
        newFeedUrl = ""
        newFeedSource = ""
    }

    private func resetDefaults() {
        rssModel.updateFeeds(defaultFeeds)
    }
}

struct TrashButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isFocused ? .white : .red)
            .padding(14)
            .background(
                Circle()
                    .fill(isFocused ? Color.red : Color.red.opacity(0.1))
            )
            .scaleEffect(isFocused ? 1.1 : 1.0)  // Reduced scale to prevent clipping
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
            .padding(8)  // Increased reserve space for scale
    }
}
