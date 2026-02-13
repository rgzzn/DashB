//
//  RSSModel.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation

actor OGImageService {
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

    func ogImageURL(for articleLink: String) async -> String? {
        if let cached = cache.object(forKey: articleLink as NSString) {
            return cached as String
        }

        guard let articleURL = URL(string: articleLink) else { return nil }

        do {
            let (data, response) = try await session.data(from: articleURL)
            guard let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let html = String(data: data, encoding: .utf8),
                let ogImage = extractOGImage(from: html)
            else {
                return nil
            }
            cache.setObject(ogImage as NSString, forKey: articleLink as NSString)
            return ogImage
        } catch {
            return nil
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

struct NewsItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let pubDate: String
    let rawDate: Date?
    let link: String
    let source: String
    var imageUrl: String? = nil
}

struct FeedConfig {
    let url: String
    let source: String
}

enum FeedURLValidator {
    static func validatedHTTPSURL(from rawURL: String) -> URL? {
        guard let components = URLComponents(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
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
    @Published var newsItems: [NewsItem] = []

    private var timer: Timer?
    private let ogImageService = OGImageService()
    @Published var feeds: [FeedConfig] = [
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
        fetchNews()
        startTimer()
    }

    func startTimer() {
        // Aggiorna il feed ogni 15 minuti
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchNews()
            }
        }
    }

    func updateFeeds(_ newFeeds: [FeedConfig]) {
        self.feeds = newFeeds
        self.newsItems = []  // Clear old items
        Task { @MainActor in
            self.fetchNews()
        }
    }

    func fetchNews() {
        Task {
            var allItems: [NewsItem] = []

            await withTaskGroup(of: [NewsItem].self) { group in
                for feed in feeds {
                    group.addTask {
                        return await self.fetchSingleFeed(feed)
                    }
                }

                for await items in group {
                    allItems.append(contentsOf: items)
                }
            }

            // Ordina per rawDate (più recenti prima)
            let sortedItems = allItems.sorted { (item1, item2) -> Bool in
                let date1 = item1.rawDate ?? .distantPast
                let date2 = item2.rawDate ?? .distantPast
                return date1 > date2
            }

            self.newsItems = Array(sortedItems.prefix(50))  // Mantieni i primi 50 elementi
            await self.enrichNewsItemsWithImages()
        }
    }

    private func fetchSingleFeed(_ config: FeedConfig) async -> [NewsItem] {
        guard let url = FeedURLValidator.validatedHTTPSURL(from: config.url) else { return [] }

        let request = URLRequest(
            url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return []
            }

            let maxFeedSize = 2 * 1024 * 1024
            guard data.count <= maxFeedSize else { return [] }

            let parser = RSSParser(source: config.source)
            return parser.parse(data: data)
        } catch {
            print("Error fetching RSS feed \(config.source): \(error.localizedDescription)")
            return []
        }
    }

    private func enrichNewsItemsWithImages() async {
        // Arricchisci solo i primi 12 elementi per risparmiare risorse
        let itemsToFetch = Array(newsItems.prefix(12))
        let batchSize = 3

        guard !itemsToFetch.isEmpty else { return }

        for start in stride(from: 0, to: itemsToFetch.count, by: batchSize) {
            let end = min(start + batchSize, itemsToFetch.count)
            let batch = itemsToFetch[start..<end]

            await withTaskGroup(of: (UUID, String?).self) { group in
                for item in batch {
                    guard item.imageUrl == nil else { continue }
                    let itemID = item.id
                    let link = item.link
                    group.addTask {
                        let imageURL = await self.ogImageService.ogImageURL(for: link)
                        return (itemID, imageURL)
                    }
                }

                for await (itemID, ogImage) in group {
                    guard let ogImage,
                        let index = self.newsItems.firstIndex(where: { $0.id == itemID })
                    else { continue }
                    self.newsItems[index].imageUrl = ogImage
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
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
        formatter.locale = Locale(identifier: "it_IT")
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
