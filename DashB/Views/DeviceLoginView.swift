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
    @State private var lastStatus: String = L10n.string("deviceLogin.status.preparing")
    @State private var showContent = false

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
                            .accessibilityHidden(true)

                        Text(success)
                            .font(.system(size: 60, weight: .bold))
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            dismiss()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if let error = errorMessage {
                    ZStack {
                        Color.black.ignoresSafeArea()

                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 50) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 150))
                                    .foregroundColor(.yellow)
                                    .accessibilityHidden(true)

                                Text("deviceLogin.warning")
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(.white)

                                Text(error)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 100)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 60) {
                                    Button("common.retry") { startAuth() }
                                        .buttonStyle(PremiumButtonStyle())
                                        #if !os(tvOS)
                                            .controlSize(.large)
                                        #endif
                                        .accessibilityLabel("deviceLogin.accessibility.retryAuth")
                                    Button("common.cancel") { dismiss() }
                                        .buttonStyle(PremiumButtonStyle())
                                        #if !os(tvOS)
                                            .controlSize(.large)
                                        #endif
                                        .accessibilityLabel("deviceLogin.accessibility.closeLogin")
                                }
                                .padding(.top, 50)
                            }
                            .padding(.vertical, 100)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if isLoading {
                    VStack(spacing: 40) {
                        ProgressView().scaleEffect(3)
                        Text("deviceLogin.loading").font(.title2)
                    }
                    .transition(.opacity)
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
                                    .accessibilityLabel(
                                        L10n.string(
                                            "deviceLogin.accessibility.qrLabel",
                                            service.serviceName
                                        )
                                    )
                                    .accessibilityHint(
                                        L10n.string("deviceLogin.accessibility.qrHint")
                                    )
                            }
                            Text("deviceLogin.scanNow").font(.headline)
                        }

                        // Istruzioni
                        VStack(alignment: .leading, spacing: 35) {
                            Text(L10n.string("deviceLogin.connectService", service.serviceName))
                                .font(.system(size: 56, weight: .bold))
                                .minimumScaleFactor(0.5)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("deviceLogin.fromPhone").font(.caption).foregroundColor(.blue)
                                    .fontWeight(.black)
                                Text(info.verificationUri).font(.title3).lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("deviceLogin.code").font(.caption).foregroundColor(.blue).fontWeight(
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
                                Text(
                                    L10n.string(
                                        "deviceLogin.codeExpiresIn",
                                        timeString(from: timeRemaining)
                                    )
                                )
                                    .font(.caption).foregroundColor(.white.opacity(0.4))
                            }
                            .padding().background(Color.white.opacity(0.05)).cornerRadius(20)
                            .accessibilityElement(children: .combine)
                        }
                        .frame(maxWidth: 700)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }

                if successMessage == nil && errorMessage == nil {
                    Button("common.close") { dismiss() }.buttonStyle(PremiumButtonStyle()).padding(
                        .top, 20)
                }
            }
            .padding(70).background(.ultraThinMaterial).cornerRadius(60).padding(30)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 16)
            .animation(Motion.enter, value: showContent)
        }
        .onAppear {
            startAuth()
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
    }

    private func startAuth() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        lastStatus = L10n.string("deviceLogin.status.starting")
        timer?.invalidate()

        let missingKeys = Config.missingOAuthKeys(for: service.serviceName)
        guard missingKeys.isEmpty else {
            errorMessage = L10n.string(
                "deviceLogin.error.missingOAuth",
                missingKeys.joined(separator: ", ")
            )
            isLoading = false
            return
        }

        Task {
            do {
                let info = try await withTimeout(seconds: 20) {
                    try await service.startDeviceAuth()
                }
                await MainActor.run {
                    self.authInfo = info
                    self.isLoading = false
                    self.timeRemaining = min(info.expiresIn, 600)
                    self.startCountdown()
                    self.startPolling()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = friendlyErrorMessage(from: error)
                    self.isLoading = false
                }
            }
        }
    }


    private func withTimeout<T>(seconds: UInt64, operation: @escaping () async throws -> T)
        async throws -> T
    {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }

            let firstCompleted = try await group.next()
            group.cancelAll()

            guard let result = firstCompleted else {
                throw URLError(.unknown)
            }
            return result
        }
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                errorMessage = L10n.string("deviceLogin.error.codeExpired")
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
                    await MainActor.run {
                        lastStatus = L10n.string("deviceLogin.status.waitingConfirmation")
                    }
                    let success = try await service.pollForToken(
                        deviceCode: info.deviceCode, interval: 0)
                    if success {
                        await MainActor.run {
                            self.isPolling = false
                            self.successMessage = L10n.string("deviceLogin.success.connected")
                            self.timer?.invalidate()
                            manager.fetchEvents()
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        self.isPolling = false
                        self.errorMessage = friendlyErrorMessage(from: error)
                    }
                    return
                }
                // Usa intervallo di 5 secondi come raccomandato da Google per evitare blocchi slow_down
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

    private func friendlyErrorMessage(from error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return L10n.string("deviceLogin.error.noInternet")
            case .timedOut:
                return L10n.string("deviceLogin.error.timeout")
            default:
                return L10n.string("deviceLogin.error.startFailed")
            }
        }

        return L10n.string("deviceLogin.error.generic")
    }
}
#Preview("DeviceLoginView Preview") {
    DeviceLoginView(service: MockCalendarService())
        .environmentObject(CalendarManager())
}
