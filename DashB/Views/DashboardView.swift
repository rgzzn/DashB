//
//  DashboardView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct DashboardView: View {
    private let dashboardCardHeight: CGFloat = 707
    private let dashboardCardRowHeight: CGFloat = 736

    @EnvironmentObject private var weatherModel: WeatherModel
    @EnvironmentObject private var calendarManager: CalendarManager
    @EnvironmentObject private var rssModel: RSSModel
    @State private var showingSettings = false
    @State private var showContent = false

    // Impostazioni Utente
    @AppStorage("userName") private var userName = "Luca"
    @AppStorage("showGreeting") private var showGreeting = true

    @FocusState private var isSettingsFocused: Bool

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return L10n.string("dashboard.greeting.morning")
        case 12..<18: return L10n.string("dashboard.greeting.afternoon")
        case 18..<24: return L10n.string("dashboard.greeting.evening")
        default: return L10n.string("dashboard.greeting.night")
        }
    }

    private var greetingText: String {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return greeting
        }
        return showGreeting ? "\(greeting), \(trimmedName)" : trimmedName
    }

    private var connectedServicesCount: Int {
        [calendarManager.googleService.isConnected, calendarManager.outlookService.isConnected]
            .filter { $0 }
            .count
    }

    var body: some View {
        ZStack {
            GradientBackgroundView()
                .overlay {
                    DashboardAmbientBackdrop()
                }
                .ignoresSafeArea()

            VStack(spacing: 20) {
                dashboardHeader
                dashboardGrid
                dashboardFooter
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
        .fullScreenCover(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(weatherModel)
                .environmentObject(calendarManager)
                .environmentObject(rssModel)
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(greetingText)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.opacity)
                    .animation(Motion.calm, value: greetingText)

                Text(weatherModel.weatherAdvice)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
                    .animation(Motion.calm, value: weatherModel.weatherAdvice)
            }

            Spacer()

            ClockView()
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .modifier(
                    DashboardGlassPanel(
                        cornerRadius: 28,
                        tint: .white.opacity(0.03),
                        glassTint: .white
                    )
                )
        }
        .padding(.top, 20)
        .offset(y: -10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 12)
        .animation(Motion.enter, value: showContent)
        .layoutPriority(1)
    }

    private var dashboardGrid: some View {
        HStack(alignment: .top, spacing: 30) {
            WeatherView()
                .frame(width: 400, height: dashboardCardHeight, alignment: .top)

            CalendarView()
                .frame(width: 400, height: dashboardCardHeight, alignment: .top)

            NewsTickerView()
                .frame(maxWidth: .infinity, minHeight: dashboardCardHeight, maxHeight: dashboardCardHeight, alignment: .top)
        }
        .frame(height: dashboardCardRowHeight, alignment: .top)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 16)
        .scaleEffect(showContent ? 1 : 0.985, anchor: .top)
        .animation(Motion.enter.delay(0.1), value: showContent)
    }

    private var dashboardFooter: some View {
        HStack {
            Spacer()

            Button {
                showingSettings = true
            } label: {
                Label("dashboard.settings", systemImage: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .focused($isSettingsFocused)
            .buttonStyle(DashboardAdaptiveGlassButtonStyle(prominent: false))
            .scaleEffect(isSettingsFocused ? 1.02 : 1)
            .animation(Motion.focus, value: isSettingsFocused)
        }
        .padding(.bottom, 5)
        .offset(y: 10)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .scaleEffect(showContent ? 1 : 0.985, anchor: .bottomTrailing)
        .animation(Motion.enter.delay(0.2), value: showContent)
        .layoutPriority(1)
    }
}

private struct DashboardAmbientBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 720, height: 720)
                .blur(radius: 140)
                .offset(x: -430, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 620, height: 620)
                .blur(radius: 120)
                .offset(x: 520, y: -240)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 520, height: 520)
                .blur(radius: 90)
                .offset(x: 460, y: 280)
        }
        .ignoresSafeArea()
    }
}

private struct DashboardGlassPanel: ViewModifier {
    let cornerRadius: CGFloat
    var tint: Color = .clear
    var glassTint: Color = .white

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.06),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                .clear,
                                glassTint.opacity(0.03),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .dashboardLiquidGlass(cornerRadius: cornerRadius, tint: glassTint)
            .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
    }
}

private struct DashboardAdaptiveGlassButtonStyle: PrimitiveButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            if prominent {
                Button(role: nil, action: configuration.trigger) {
                    configuration.label
                }
                .buttonStyle(GlassProminentButtonStyle())
            } else {
                Button(role: nil, action: configuration.trigger) {
                    configuration.label
                }
                .buttonStyle(GlassButtonStyle())
            }
        } else {
            Button(role: nil, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(PremiumButtonStyle())
        }
    }
}

private extension View {
    @ViewBuilder
    func dashboardLiquidGlass(cornerRadius: CGFloat, tint: Color = .white) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.1)), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(WeatherModel())
        .environmentObject(CalendarManager())
        .environmentObject(RSSModel())
}
