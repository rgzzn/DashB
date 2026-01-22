//
//  DeviceLoginView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

struct DeviceLoginView: View {
    let service: any CalendarService
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var manager: CalendarManager

    @State private var authInfo: DeviceAuthInfo?
    @State private var isLoading = true
    @State private var isPolling = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer?
    @State private var lastStatus: String = "Preparazione..."

    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                if let success = successMessage {
                    VStack(spacing: 30) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 150))
                            .foregroundColor(.green)

                        Text(success)
                            .font(.system(size: 60, weight: .bold))
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            dismiss()
                        }
                    }
                } else if let error = errorMessage {
                    ZStack {
                        Color.black.ignoresSafeArea()

                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 50) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 150))
                                    .foregroundColor(.yellow)

                                Text("Attenzione")
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(.white)

                                Text(error)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 100)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 60) {
                                    Button("Riprova") { startAuth() }
                                        .buttonStyle(PremiumButtonStyle())
                                        .controlSize(.large)
                                    Button("Annulla") { dismiss() }
                                        .buttonStyle(PremiumButtonStyle())
                                        .controlSize(.large)
                                }
                                .padding(.top, 50)
                            }
                            .padding(.vertical, 100)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .transition(.opacity)
                } else if isLoading {
                    VStack(spacing: 40) {
                        ProgressView().scaleEffect(3)
                        Text("Creazione codice di accesso...").font(.title2)
                    }
                } else if let info = authInfo {
                    HStack(spacing: 70) {
                        // QR
                        VStack(spacing: 25) {
                            if let qrImage = generateQRCode(from: info.verificationUri) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 400, height: 400)
                                    .padding(25)
                                    .background(.white)
                                    .cornerRadius(30)
                            }
                            Text("Scannerizza ora").font(.headline)
                        }

                        // Instructions
                        VStack(alignment: .leading, spacing: 35) {
                            Text("Connetti \(service.serviceName)")
                                .font(.system(size: 56, weight: .bold))
                                .minimumScaleFactor(0.5)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("DA TELEFONO").font(.caption).foregroundColor(.blue)
                                    .fontWeight(.black)
                                Text(info.verificationUri).font(.title3).lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("CODICE").font(.caption).foregroundColor(.blue).fontWeight(
                                    .black)
                                Text(info.userCode)
                                    .font(.system(size: 100, weight: .black, design: .monospaced))
                                    .minimumScaleFactor(0.4)
                                    .shadow(color: .blue.opacity(0.5), radius: 10)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 15) {
                                    if isPolling { ProgressView() }
                                    Text(lastStatus).font(.headline).foregroundColor(
                                        .white.opacity(0.8))
                                }
                                Text("Il codice scade tra: \(timeString(from: timeRemaining))")
                                    .font(.caption).foregroundColor(.white.opacity(0.4))
                            }
                            .padding().background(Color.white.opacity(0.05)).cornerRadius(20)
                        }
                        .frame(maxWidth: 700)
                    }
                }

                if successMessage == nil && errorMessage == nil {
                    Button("Chiudi") { dismiss() }.buttonStyle(PremiumButtonStyle()).padding(
                        .top, 20)
                }
            }
            .padding(70).background(.ultraThinMaterial).cornerRadius(60).padding(30)
        }
        .onAppear { startAuth() }
    }

    private func startAuth() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        lastStatus = "Avvio..."
        timer?.invalidate()
        Task {
            do {
                let info = try await service.startDeviceAuth()
                await MainActor.run {
                    self.authInfo = info
                    self.isLoading = false
                    self.timeRemaining = min(info.expiresIn, 600)
                    self.startCountdown()
                    self.startPolling()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Errore: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                errorMessage = "Tempo scaduto."
            }
        }
    }

    private func timeString(from seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func startPolling() {
        guard let info = authInfo else { return }
        isPolling = true
        Task {
            while isPolling && timeRemaining > 0 {
                do {
                    await MainActor.run { lastStatus = "Passaggio 3: In attesa di conferma..." }
                    let success = try await service.pollForToken(
                        deviceCode: info.deviceCode, interval: 0)
                    if success {
                        await MainActor.run {
                            self.isPolling = false
                            self.successMessage = "Perfetto! Collegato."
                            self.timer?.invalidate()
                            manager.fetchEvents()
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        self.isPolling = false
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
                // Use 5 seconds interval as recommended by Google to avoid slow_down blocks
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage {
            let scale = 400 / outputImage.extent.size.width
            let transformed = outputImage.transformed(
                by: CGAffineTransform(scaleX: scale, y: scale))
            if let cgimg = context.createCGImage(transformed, from: transformed.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
}
