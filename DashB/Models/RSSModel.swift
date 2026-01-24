//
//  RSSModel.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation

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

@MainActor
class RSSModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []

    private var timer: Timer?
    private let feeds: [FeedConfig] = [
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
        // Update feed every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchNews()
            }
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

            // Sort by rawDate (most recent first)
            let sortedItems = allItems.sorted { (item1, item2) -> Bool in
                let date1 = item1.rawDate ?? .distantPast
                let date2 = item2.rawDate ?? .distantPast
                return date1 > date2
            }

            self.newsItems = Array(sortedItems.prefix(50))  // Keep top 50 items
            self.enrichNewsItemsWithImages()
        }
    }

    private func fetchSingleFeed(_ config: FeedConfig) async -> [NewsItem] {
        guard let url = URL(string: config.url) else { return [] }

        let request = URLRequest(
            url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let parser = RSSParser(source: config.source)
            return parser.parse(data: data)
        } catch {
            print("Error fetching RSS feed \(config.source): \(error.localizedDescription)")
            return []
        }
    }

    private func enrichNewsItemsWithImages() {
        // Only enrich the first 12 items to save resources
        let itemsToFetch = newsItems.prefix(12)

        for item in itemsToFetch {
            guard item.imageUrl == nil, let url = URL(string: item.link) else { continue }

            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let html = String(data: data, encoding: .utf8),
                        let ogImage = self.extractOGImage(from: html)
                    {
                        if let index = self.newsItems.firstIndex(where: { $0.id == item.id }) {
                            self.newsItems[index].imageUrl = ogImage
                        }
                    }
                } catch {
                    // Ignore image fetch errors
                }
            }
        }
    }

    private func extractOGImage(from html: String) -> String? {
        let pattern = "<meta property=\"og:image\" content=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = html as NSString
            let results = regex.matches(
                in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            if let result = results.first {
                return nsString.substring(with: result.range(at: 1))
            }
        }
        return nil
    }

    deinit {
        timer?.invalidate()
    }
}

// Separate non-isolated parser to satisfy Swift 6 concurrency rules
class RSSParser: NSObject, XMLParserDelegate {
    private var tempItems: [NewsItem] = []
    private var currentElement = ""
    private var currentTitle: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    private var currentLink: String = ""
    private let source: String

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
        let pattern = "src=\"(http[^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsString = html as NSString
            let results = regex.matches(
                in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            if let result = results.first {
                return nsString.substring(with: result.range(at: 1))
            }
        }
        return nil
    }
}
