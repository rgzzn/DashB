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
    @StateObject private var model = RSSModel()
    @State private var currentIndex: Int = 0
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let qrGenerator = QRCodeGenerator()

    var body: some View {
        ZStack {
            if !model.newsItems.isEmpty {
                let item = model.newsItems[currentIndex % model.newsItems.count]

                // Sfondo
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        // Immagine di sfondo o gradiente
                        if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                case .empty, .failure:
                                    fallbackBackground
                                @unknown default:
                                    fallbackBackground
                                }
                            }
                        } else {
                            fallbackBackground
                        }

                        // Sovrapposizione gradiente per leggibilità testo
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.9), .transparent]),
                            startPoint: .bottom, endPoint: .top)

                        // Contenuto
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

                                Text(item.title)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(stripHTML(from: item.description))
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(3)

                                HStack {
                                    Text(item.pubDate)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    Spacer()
                                    // Punti di paginazione
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

                            // Codice QR
                            if let qrCGImage = qrGenerator.generateQRCode(from: item.link) {
                                Image(decorative: qrCGImage, scale: 1.0)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 80, height: 80)
                                    .padding(6)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(radius: 5)
                                    .padding(.leading, 10)
                            }
                        }
                        .padding(24)
                    }
                }
                .transition(.opacity.animation(.easeInOut))
                .id(item.id)  // Forza ridisegno/transizione al cambio
            } else {
                // Caricamento / Stato Vuoto
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("Caricamento notizie...")
                        .foregroundColor(.white)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .cornerRadius(30)
        .clipped()
        .onReceive(timer) { _ in
            withAnimation {
                if !model.newsItems.isEmpty {
                    currentIndex = (currentIndex + 1) % model.newsItems.count
                }
            }
        }
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

extension Color {
    static let transparent = Color.black.opacity(0)
}
