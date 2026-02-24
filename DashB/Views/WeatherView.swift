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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sopra: Condizioni Attuali
            HStack(alignment: .top) {
                Image(systemName: model.conditionIcon)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .symbolRenderingMode(.multicolor)
                    .contentTransition(.symbolEffect(.replace))
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
            .animation(Motion.enter.delay(0.05), value: showContent)

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
            .animation(Motion.enter.delay(0.12), value: showContent)
            .animation(Motion.standard, value: model.hourlyForecast.count)

            Divider()
                .background(Color.white.opacity(0.2))

            // Sotto: Previsioni a 5 giorni
            VStack(alignment: .leading, spacing: 8) {
                Text("Previsioni a 5 giorni")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))

                VStack(spacing: 8) {
                    ForEach(model.dailyForecast) { day in
                        HStack {
                            Text(day.day)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.8))
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
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 45, alignment: .trailing)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .font(.callout)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 12)
            .animation(Motion.enter.delay(0.2), value: showContent)
            .animation(Motion.standard, value: model.dailyForecast.count)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(Motion.enter, value: showContent)
        .onAppear {
            showContent = true
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
