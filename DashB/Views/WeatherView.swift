//
//  WeatherView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct WeatherView: View {
    @EnvironmentObject private var model: WeatherModel
    @State private var showContent = false
    @State private var animateIcon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Sopra: Condizioni Attuali
            HStack(alignment: .top) {
                Image(systemName: model.conditionIcon)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .symbolRenderingMode(.multicolor)
                    .scaleEffect(animateIcon ? 1.05 : 1.0)
                    .offset(y: animateIcon ? -2 : 2)
                    .shadow(color: .yellow.opacity(0.3), radius: 10)

                Spacer()

                VStack(alignment: .trailing, spacing: -5) {
                    Text(model.currentTemp)
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white)
                    Text(model.conditionDescription)  // Descrizione dinamica dal modello
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.bottom, 10)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 8)
            .animation(.easeOut(duration: 0.45).delay(0.05), value: showContent)

            // Centro: Prossime Ore
            VStack(alignment: .leading, spacing: 10) {
                Text("Prossime ore")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 20) {
                    ForEach(model.hourlyForecast) { forecast in
                        VStack(spacing: 8) {
                            Text(forecast.time)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Image(systemName: forecast.icon)
                                .font(.title3)
                                .symbolRenderingMode(.multicolor)
                            Text(forecast.temp)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(minWidth: 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 10)
            .animation(.easeOut(duration: 0.45).delay(0.12), value: showContent)
            .animation(.easeOut(duration: 0.35), value: model.hourlyForecast.count)

            Divider()
                .background(Color.white.opacity(0.2))

            // Sotto: Previsioni a 5 giorni
            VStack(alignment: .leading, spacing: 12) {
                Text("Previsioni a 5 giorni")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))

                VStack(spacing: 12) {
                    ForEach(model.dailyForecast) { day in
                        HStack {
                            Text(day.day)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 60, alignment: .leading)

                            Spacer()

                            Image(systemName: day.icon)
                                .symbolRenderingMode(.multicolor)

                            Spacer()

                            HStack(spacing: 8) {
                                Text(day.tempHigh)
                                    .fontWeight(.medium)
                                Text(day.tempLow)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .font(.callout)
                            .foregroundStyle(.white)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 12)
            .animation(.easeOut(duration: 0.45).delay(0.2), value: showContent)
            .animation(.easeOut(duration: 0.35), value: model.dailyForecast.count)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(.easeOut(duration: 0.5), value: showContent)
        .animation(
            .easeInOut(duration: 3).repeatForever(autoreverses: true),
            value: animateIcon
        )
        .onAppear {
            showContent = true
            animateIcon = true
        }
        .task {
            await model.refresh()
        }
    }
}

#Preview("WeatherView Preview") {
    WeatherView()
        .environmentObject(WeatherModel())
        .frame(width: 400, height: 600)
        .background(GradientBackgroundView().ignoresSafeArea())
}
