//
//  QRCodeView.swift
//  DashB
//
//  Created by Luca Ragazzini on 17/02/26.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct QRCodeView: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GradientBackgroundView().ignoresSafeArea()

            VStack(spacing: 30) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                if let qrImage = generateQRCode(from: url.absoluteString) {
                    Image(platformImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                } else {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }

                Text("Scansiona per aprire sul tuo dispositivo")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Button("Chiudi") {
                    dismiss()
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding()
        }
    }

    private func generateQRCode(from string: String) -> PlatformImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            // Scale up the image to avoid blur
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                #if canImport(UIKit)
                    return UIImage(cgImage: cgImage)
                #elseif canImport(AppKit)
                    return NSImage(
                        cgImage: cgImage,
                        size: NSSize(
                            width: scaledImage.extent.width, height: scaledImage.extent.height))
                #endif
            }
        }
        return nil
    }
}

#if canImport(UIKit)
    typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
            self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
            self.init(nsImage: platformImage)
        #endif
    }
}
