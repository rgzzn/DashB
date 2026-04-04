//
//  WeatherView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct WeatherView: View {
    @EnvironmentObject private var model: WeatherModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showContent = false

    private let panelShape = RoundedRectangle(cornerRadius: 30, style: .continuous)
    private var theme: DashboardTheme { DashboardTheme(scheme: colorScheme) }

    var body: some View {
        ZStack {
            panelShape
                .fill(.ultraThinMaterial)
                .overlay(
                    panelShape
                        .fill(theme.panelFill)
                )
                .overlay(
                    panelShape
                        .stroke(theme.panelStroke, lineWidth: 1)
                )
                .overlay {
                    panelShape
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primaryText.opacity(0.05),
                                    .clear,
                                    theme.primaryText.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .weatherLiquidGlass(cornerRadius: 30, tint: theme.glassTint)

            weatherContent
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)
                .animation(Motion.enter, value: showContent)
        }
        .clipShape(panelShape)
        .shadow(color: theme.panelShadow, radius: 24, y: 12)
        .onAppear {
            guard !showContent else { return }
            withAnimation(Motion.enter) {
                showContent = true
            }
        }
    }

    private var weatherContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentConditions
            hourlySection
            Divider()
                .background(theme.panelStroke)
            dailySection
        }
    }

    private var currentConditions: some View {
        HStack(alignment: .top) {
            Image(systemName: model.conditionIcon)
                .font(.system(size: 72, weight: .regular))
                .frame(width: 84, height: 84)
                .symbolRenderingMode(.multicolor)
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: .yellow.opacity(0.3), radius: 10)

            Spacer()

            VStack(alignment: .trailing, spacing: -5) {
                Text(model.currentTemp)
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(theme.primaryText)
                    .contentTransition(.numericText())
                    .animation(Motion.calm, value: model.currentTemp)

                Text(model.conditionDescription)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryText)
                    .contentTransition(.opacity)
                    .animation(Motion.calm, value: model.conditionDescription)
            }
        }
        .padding(.bottom, 10)
    }

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("weather.section.hourly")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.secondaryText)

            HStack(spacing: 20) {
                ForEach(model.hourlyForecast) { forecast in
                    VStack(spacing: 8) {
                        Text(forecast.time)
                            .font(.caption2)
                            .foregroundColor(theme.tertiaryText)

                        Image(systemName: forecast.icon)
                            .font(.title3)
                            .symbolRenderingMode(.multicolor)

                        Text(forecast.temp)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(theme.primaryText)
                    }
                    .frame(minWidth: 40)
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("weather.section.daily")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.secondaryText)

            VStack(spacing: 8) {
                ForEach(model.dailyForecast) { day in
                    HStack {
                        Text(day.day)
                            .font(.callout)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: day.icon)
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                            .frame(width: 35)

                        HStack(spacing: 6) {
                            Text(day.tempHigh)
                                .fontWeight(.medium)
                                .frame(width: 45, alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(day.tempLow)
                                .foregroundStyle(theme.tertiaryText)
                                .frame(width: 45, alignment: .trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.callout)
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private extension View {
    @ViewBuilder
    func weatherLiquidGlass(cornerRadius: CGFloat, tint: Color) -> some View {
        if #available(tvOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 26.0, *) {
            self.glassEffect(.regular.tint(tint.opacity(0.1)), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
        }
    }
}

#Preview("WeatherView Preview") {
    WeatherView()
        .environmentObject(WeatherModel())
        .frame(width: 400, height: 600)
        .background(GradientBackgroundView().ignoresSafeArea())
}
