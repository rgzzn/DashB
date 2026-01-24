//
//  WeatherView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct WeatherView: View {
    @EnvironmentObject private var model: WeatherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Sopra: Condizioni Attuali
            HStack(alignment: .top) {
                Image(systemName: model.conditionIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .symbolRenderingMode(.multicolor)
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
                    }
                }
            }

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
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .task {
            await model.refresh()
        }
    }
}
