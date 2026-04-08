//
//  NewsTickerView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI

struct QRCodeGenerator {
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    func generateQRCode(from string: String) -> CGImage? {
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            return context.createCGImage(scaledImage, from: scaledImage.extent)
        }
        return nil
    }
}

struct NewsTickerView: View {
    @EnvironmentObject private var model: RSSModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentIndex: Int = 0
    @State private var showContent = false
    @State private var currentQRCode: CGImage?
    @State private var qrCodeLink: String?
    @State private var strippedDescription = ""
    private let qrGenerator = QRCodeGenerator()
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }
    private var overlayBaseColor: Color { colorScheme == .dark ? .black : .white }

    private var safeNewsCount: Int {
        model.newsItems.count
    }

    private var currentItem: NewsItem? {
        guard safeNewsCount > 0 else { return nil }
        return model.newsItems[currentIndex % safeNewsCount]
    }

    var body: some View {
        ZStack {
            if let item = currentItem {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(
                                url: url,
                                transaction: Transaction(animation: Motion.calm)
                            ) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                        .transition(.opacity)
                                case .empty, .failure:
                                    fallbackBackground
                                @unknown default:
                                    fallbackBackground
                                }
                            }
                        } else {
                            fallbackBackground
                        }

                        LinearGradient(
                            gradient: Gradient(colors: [overlayBaseColor.opacity(0.88), .transparent]),
                            startPoint: .bottom, endPoint: .top
                        )

                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.12),
                                .clear,
                                Color.white.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(item.source.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .padding(.bottom, 4)
                                    .contentTransition(.opacity)

                                Text(item.title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.primaryText)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .contentTransition(.opacity)

                                Text(strippedDescription)
                                    .font(.body)
                                    .foregroundColor(theme.secondaryText)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                                    .contentTransition(.opacity)

                                HStack {
                                    Text(item.pubDate)
                                        .font(.caption)
                                        .foregroundColor(theme.tertiaryText)
                                    Spacer()
                                    HStack(spacing: 6) {
                                        let pageCount = min(model.newsItems.count, 5)
                                        ForEach(0..<pageCount, id: \.self) {
                                            index in
                                            Circle()
                                                .frame(width: 6, height: 6)
                                                .foregroundColor(
                                                    index
                                                        == (currentIndex % pageCount)
                                                        ? theme.primaryText : theme.tertiaryText)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }

                            Spacer()

                            if let qrCGImage = currentQRCode, qrCodeLink == item.link {
                                VStack(spacing: 6) {
                                    Image(decorative: qrCGImage, scale: 1.0)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 80, height: 80)
                                        .padding(6)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .shadow(radius: 5)
                                        .accessibilityLabel(
                                            L10n.string("news.accessibility.qrLabel", item.title)
                                        )
                                        .accessibilityHint(
                                            L10n.string("news.accessibility.qrHint")
                                        )

                                    Text("news.scan")
                                        .font(.caption2)
                                        .foregroundColor(theme.secondaryText)
                                }
                                .padding(.leading, 10)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            }
                        }
                        .padding(24)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 12)
                        .animation(Motion.enter.delay(0.08), value: showContent)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("news.loading")
                        .foregroundColor(theme.primaryText)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NewsTickerGlassPanel(cornerRadius: 30, tint: theme.glassTint))
        .onAppear {
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
            strippedDescription = stripHTML(from: currentItem?.description ?? "")
            updateQRCode(for: currentItem?.link)
        }
        .task(id: safeNewsCount) {
            guard safeNewsCount > 1 else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { return }

                await MainActor.run {
                    guard safeNewsCount > 1 else { return }
                    withAnimation(Motion.calm) {
                        currentIndex = (currentIndex + 1) % safeNewsCount
                    }
                }
            }
        }
        .onChange(of: safeNewsCount) { _, newCount in
            guard newCount > 0 else {
                currentIndex = 0
                currentQRCode = nil
                qrCodeLink = nil
                return
            }
            currentIndex %= newCount
            updateQRCode(for: currentItem?.link)
        }
        .onChange(of: currentItem?.link) { _, newLink in
            updateQRCode(for: newLink)
        }
        .onChange(of: currentItem?.id) { _, _ in
            strippedDescription = stripHTML(from: currentItem?.description ?? "")
        }
    }

    var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.12, blue: 0.24).opacity(0.82),
                Color(red: 0.06, green: 0.2, blue: 0.34).opacity(0.74),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(Color.black.opacity(0.25))
    }

    func stripHTML(from string: String) -> String {
        return string.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }

    private func updateQRCode(for link: String?) {
        guard let link else {
            qrCodeLink = nil
            currentQRCode = nil
            return
        }

        guard qrCodeLink != link else { return }
        qrCodeLink = link
        currentQRCode = qrGenerator.generateQRCode(from: link)
    }
}

private struct NewsTickerGlassPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let tint: Color
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
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primaryText.opacity(0.04),
                                .clear,
                                tint.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: theme.panelShadow, radius: 24, y: 12)
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}
#Preview("NewsTickerView Preview") {
    NewsTickerView()
        .environmentObject(RSSModel())
        .frame(width: 800, height: 400)
}
