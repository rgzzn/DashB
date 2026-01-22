//
//  CalendarView.swift
//  DashB
//
//  Created by User on 20/01/26.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var manager: CalendarManager

    private var allDayEvents: [DashboardEvent] {
        manager.upcomingEvents.filter { $0.isAllDay }
    }

    private var timedEvents: [DashboardEvent] {
        manager.upcomingEvents.filter { !$0.isAllDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.red)
                Text("Agenda")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 5)

            if manager.upcomingEvents.isEmpty {
                VStack(spacing: 15) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    Text("Nessun evento\nin programma")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Sezione Eventi Tutto il Giorno
                        if !allDayEvents.isEmpty {
                            ForEach(allDayEvents.prefix(3)) { event in
                                allDayEventRow(event)
                            }
                        }

                        // Sezione Eventi con Orario
                        ForEach(timedEvents.prefix(5)) { event in
                            timedEventRow(event)
                        }
                    }
                }
            }
        }
        .padding(25)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
    }

    // MARK: - Evento Tutto il Giorno (stile più compatto e morbido)
    @ViewBuilder
    private func allDayEventRow(_ event: DashboardEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.color.opacity(0.8))
                .frame(width: 10, height: 10)

            Text(event.title)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Text("Tutto il giorno")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(event.color.opacity(0.15))
        .cornerRadius(14)
    }

    // MARK: - Evento con Orario (stile migliorato)
    @ViewBuilder
    private func timedEventRow(_ event: DashboardEvent) -> some View {
        HStack(alignment: .center, spacing: 15) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.color)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))

                        Text(location)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Text(
                    event.startDate.formatted(
                        date: .omitted, time: .shortened)
                )
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
    }
}
