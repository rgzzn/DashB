//
//  RSSModel.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation
import os

actor OGImageService {
    enum Source: Sendable {
        case memoryCache
        case network
        case none
    }

    struct Result: Sendable {
        let url: String?
        let source: Source
    }

    private let session: URLSession
    private let ogImageRegex = try? NSRegularExpression(
        pattern: "<meta property=\"og:image\" content=\"([^\"]+)\"", options: .caseInsensitive)
    private let cache = NSCache<NSString, NSString>()

    init() {
        let cache = URLCache(memoryCapacity: 30 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024)
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: configuration)
        self.cache.countLimit = 120
    }

    func ogImageURL(for articleLink: String) async -> Result {
        if let cached = cache.object(forKey: articleLink as NSString) {
            return Result(url: cached as String, source: .memoryCache)
        }

        guard let articleURL = URL(string: articleLink) else { return Result(url: nil, source: .none) }

        do {
            let (data, response) = try await session.data(from: articleURL)
            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let html = String(data: data, encoding: .utf8),
                let ogImage = extractOGImage(from: html)
            else {
                return Result(url: nil, source: .none)
            }
            cache.setObject(ogImage as NSString, forKey: articleLink as NSString)
            return Result(url: ogImage, source: .network)
        } catch {
            return Result(url: nil, source: .none)
        }
    }

    private func extractOGImage(from html: String) -> String? {
        guard let ogImageRegex else { return nil }
        let nsString = html as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = ogImageRegex.firstMatch(in: html, options: [], range: range) else {
            return nil
        }
        return nsString.substring(with: result.range(at: 1))
    }
}

struct NewsItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let pubDate: String
    let rawDate: Date?
    let link: String
    let source: String
    var imageUrl: String? = nil

    init(
        title: String,
        description: String,
        pubDate: String,
        rawDate: Date?,
        link: String,
        source: String,
        imageUrl: String? = nil
    ) {
        self.id = NewsItem.stableID(title: title, link: link, source: source)
        self.title = title
        self.description = description
        self.pubDate = pubDate
        self.rawDate = rawDate
        self.link = link
        self.source = source
        self.imageUrl = imageUrl
    }

    private static func stableID(title: String, link: String, source: String) -> String {
        let trimmedLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLink.isEmpty { return trimmedLink }
        return "\(source)::\(title.trimmingCharacters(in: .whitespacesAndNewlines))"
    }
}

struct FeedConfig: Codable, Equatable, Identifiable, Sendable {
    var id: String { url }
    let url: String
    let source: String
}

enum FeedURLValidator {
    static func validatedHTTPSURL(from rawURL: String) -> URL? {
        guard
            let components = URLComponents(
                string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
            components.scheme?.lowercased() == "https",
            let host = components.host,
            !host.isEmpty
        else {
            return nil
        }

        let blockedHosts = ["localhost", "127.0.0.1", "0.0.0.0", "::1"]
        if blockedHosts.contains(host.lowercased()) { return nil }

        return components.url
    }
}

@MainActor
class RSSModel: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DashB", category: "RSS")
    private static let refreshInterval: TimeInterval = 15 * 60
    private static let refreshOffset: TimeInterval = 120

    @Published var newsItems: [NewsItem] = []
    @Published var feeds: [FeedConfig] {
        didSet {
            persistFeeds()
        }
    }

    private var timer: Timer?
    private var initialRefreshTask: Task<Void, Never>?
    private var fetchTask: Task<Void, Never>?
    private var isRefreshing = false
    private let ogImageService = OGImageService()
    private let feedsDefaultsKey = "RSSModel.savedFeeds"
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

    init() {
        if
            let data = UserDefaults.standard.data(forKey: feedsDefaultsKey),
            let decoded = try? JSONDecoder().decode([FeedConfig].self, from: data),
            !decoded.isEmpty
        {
            self.feeds = decoded
        } else {
            self.feeds = defaultFeeds
        }
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        initialRefreshTask?.cancel()

        // Offset di circa 120 secondi rispetto al refresh immediato dei calendari.
        initialRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.refreshOffset * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.fetchNews()
            self?.timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fetchNews()
                }
            }
        }
    }

    func updateFeeds(_ newFeeds: [FeedConfig]) {
        guard feeds != newFeeds else { return }
        feeds = newFeeds
        newsItems = []  // Clear old items
        fetchNews()
    }

    func fetchNews() {
        guard !isRefreshing else {
            Self.logger.debug("RSS refresh skipped because a refresh is already running")
            return
        }
        isRefreshing = true
        fetchTask?.cancel()
        let feedsSnapshot = feeds
        let startedAt = Date()

        fetchTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.isRefreshing = false
                }
            }
            var allItems: [NewsItem] = []

            await withTaskGroup(of: [NewsItem].self) { group in
                for feed in feedsSnapshot {
                    group.addTask {
                        if Task.isCancelled { return [] }
                        return await self.fetchSingleFeed(feed)
                    }
                }

                for await items in group {
                    if Task.isCancelled { return }
                    allItems.append(contentsOf: items)
                }
            }
            if Task.isCancelled { return }

            // Ordina per rawDate (più recenti prima)
            let sortedItems = allItems.sorted { (item1, item2) -> Bool in
                let date1 = item1.rawDate ?? .distantPast
                let date2 = item2.rawDate ?? .distantPast
                return date1 > date2
            }

            let nextItems = Array(sortedItems.prefix(50))
            if self.newsItems != nextItems {
                self.newsItems = nextItems  // Mantieni i primi 50 elementi
            }
            let imageStats = await self.enrichNewsItemsWithImages()
            let duration = Date().timeIntervalSince(startedAt)
            Self.logger.info("RSS refresh completed in \(duration, format: .fixed(precision: 2))s, articles: \(nextItems.count), og images network: \(imageStats.network), cache: \(imageStats.cache)")
        }
    }

    nonisolated private func fetchSingleFeed(_ config: FeedConfig) async -> [NewsItem] {
        guard let url = FeedURLValidator.validatedHTTPSURL(from: config.url) else { return [] }

        let request = URLRequest(
            url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                return []
            }

            let maxFeedSize = 2 * 1024 * 1024
            guard data.count <= maxFeedSize else { return [] }

            let parser = RSSParser(source: config.source)
            return parser.parse(data: data)
        } catch {
            Self.logger.error("RSS feed \(config.source, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func enrichNewsItemsWithImages() async -> (network: Int, cache: Int) {
        // Arricchisci solo i primi 12 elementi per risparmiare risorse
        let itemsToFetch = Array(newsItems.prefix(12))
        let batchSize = 3

        guard !itemsToFetch.isEmpty else { return (0, 0) }
        var networkHits = 0
        var cacheHits = 0

        for start in stride(from: 0, to: itemsToFetch.count, by: batchSize) {
            if Task.isCancelled { return (networkHits, cacheHits) }
            let end = min(start + batchSize, itemsToFetch.count)
            let batch = itemsToFetch[start..<end]
            var updates: [String: String] = [:]

            await withTaskGroup(of: (String, OGImageService.Result).self) { group in
                for item in batch {
                    guard item.imageUrl == nil else { continue }
                    let itemID = item.id
                    let link = item.link
                    group.addTask {
                        let result = await self.ogImageService.ogImageURL(for: link)
                        return (itemID, result)
                    }
                }

                for await (itemID, result) in group {
                    switch result.source {
                    case .memoryCache: cacheHits += 1
                    case .network: networkHits += 1
                    case .none: break
                    }
                    guard let ogImage = result.url else { continue }
                    updates[itemID] = ogImage
                }
            }

            guard !updates.isEmpty else { continue }
            var mergedItems = newsItems
            var didMutate = false
            for index in mergedItems.indices {
                let id = mergedItems[index].id
                guard let imageURL = updates[id], mergedItems[index].imageUrl == nil else { continue }
                mergedItems[index].imageUrl = imageURL
                didMutate = true
            }

            if didMutate {
                newsItems = mergedItems
            }
        }

        return (networkHits, cacheHits)
    }

    deinit {
        timer?.invalidate()
        initialRefreshTask?.cancel()
        fetchTask?.cancel()
    }

    func resetToDefaultFeeds() {
        updateFeeds(defaultFeeds)
    }

    private func persistFeeds() {
        guard let data = try? JSONEncoder().encode(feeds) else { return }
        UserDefaults.standard.set(data, forKey: feedsDefaultsKey)
    }
}

// Parser non isolato separato per soddisfare le regole di concorrenza di Swift 6
class RSSParser: NSObject, XMLParserDelegate {
    private var tempItems: [NewsItem] = []
    private var currentElement = ""
    private var currentTitle: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    private var currentLink: String = ""
    private let source: String
    private static let imageRegex = try? NSRegularExpression(
        pattern: "src=\"(http[^\"]+)\"", options: .caseInsensitive)

    private lazy var rssDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private lazy var displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM, HH:mm"
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    init(source: String) {
        self.source = source
        super.init()
    }

    func parse(data: Data) -> [NewsItem] {
        tempItems = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return tempItems
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        if currentElement == "item" {
            currentTitle = ""
            currentDescription = ""
            currentPubDate = ""
            currentLink = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        case "link": currentLink += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")

            let description = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")

            let rawDateString = currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            var formattedDate = rawDateString
            let rawDate = rssDateFormatter.date(from: rawDateString)

            if let date = rawDate {
                formattedDate = displayDateFormatter.string(from: date).capitalized
            }

            let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let imageUrl = extractImage(from: description)

            let item = NewsItem(
                title: title,
                description: description,
                pubDate: formattedDate,
                rawDate: rawDate,
                link: link,
                source: source,
                imageUrl: imageUrl
            )
            tempItems.append(item)
        }
    }

    private func extractImage(from html: String) -> String? {
        guard let regex = Self.imageRegex else { return nil }
        let nsString = html as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let result = regex.firstMatch(in: html, options: [], range: range) else {
            return nil
        }
        return nsString.substring(with: result.range(at: 1))
    }
}
