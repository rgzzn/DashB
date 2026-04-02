//
//  NewsTickerView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
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
    @State private var currentIndex: Int = 0
    @State private var showContent = false
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let qrGenerator = QRCodeGenerator()

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
                                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
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
                            gradient: Gradient(colors: [.black.opacity(0.92), .transparent]),
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
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .contentTransition(.opacity)

                                Text(stripHTML(from: item.description))
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                                    .contentTransition(.opacity)

                                HStack {
                                    Text(item.pubDate)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
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
                                                        ? .white : .white.opacity(0.3))
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }

                            Spacer()

                            if let qrCGImage = qrGenerator.generateQRCode(from: item.link) {
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
                                        .foregroundColor(.white.opacity(0.8))
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
                .id(item.id)
            } else {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("news.loading")
                        .foregroundColor(.white)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(NewsTickerGlassPanel(cornerRadius: 30, tint: .white))
        .onAppear {
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
        .onReceive(timer) { _ in
            withAnimation(Motion.calm) {
                if safeNewsCount > 0 {
                    currentIndex = (currentIndex + 1) % safeNewsCount
                }
            }
        }
        .onChange(of: safeNewsCount) { _, newCount in
            guard newCount > 0 else {
                currentIndex = 0
                return
            }
            currentIndex %= newCount
        }
        .animation(Motion.calm, value: currentIndex)
    }

    var fallbackBackground: some View {
        LinearGradient(
            colors: [.purple.opacity(0.3), .blue.opacity(0.3)], startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(Color.black.opacity(0.2))
    }

    func stripHTML(from string: String) -> String {
        return string.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
    }
}

private struct NewsTickerGlassPanel: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                .clear,
                                tint.opacity(0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .newsTickerLiquidGlass(cornerRadius: cornerRadius, tint: tint)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 24, y: 12)
    }
}

private extension View {
    @ViewBuilder
    func newsTickerLiquidGlass(cornerRadius: CGFloat, tint: Color) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.1)), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
        }
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
