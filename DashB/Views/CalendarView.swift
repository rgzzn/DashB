//
//  CalendarView.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var manager: CalendarManager
    @State private var showContent = false

    private var groupedEvents: [(Date, [DashboardEvent])] {
        let grouped = Dictionary(grouping: manager.upcomingEvents) { event in
            Calendar.current.startOfDay(for: event.startDate)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    private func dateHeader(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi"
        } else if calendar.isDateInTomorrow(date) {
            return "Domani"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE d MMMM"
            formatter.locale = Locale(identifier: "it_IT")
            return formatter.string(from: date).capitalized
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Restore Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.red)
                Text("Agenda")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 5)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedEvents, id: \.0) { date, events in
                        VStack(alignment: .leading, spacing: 8) {
                            // Header Data
                            Text(dateHeader(for: date).uppercased())
                                .font(.callout.weight(.semibold))
                                .foregroundColor(isDateToday(date) ? .red : .gray)
                                .padding(.leading, 2)
                                .padding(.bottom, 2)

                            // Eventi
                            ForEach(events) { event in
                                if event.isAllDay {
                                    allDayEventRow(event)
                                } else {
                                    timedEventRow(event)
                                }
                            }
                        }
                        .padding(.bottom, 10)
                    }

                    if groupedEvents.isEmpty {
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
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // Align top
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 10)
        .animation(.easeOut(duration: 0.5), value: showContent)
        .onAppear {
            showContent = true
        }
    }

    private func isDateToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - Evento Tutto il Giorno (Pill Style)
    @ViewBuilder
    private func allDayEventRow(_ event: DashboardEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 15))
                .foregroundColor(event.color)  // Icon color matches event
                .padding(6)
                .background(Circle().fill(Color.white.opacity(0.2)))

            Text(event.title)
                .font(.system(size: 25, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(event.color)  // Text color matches event

            Spacer()

            Text("tutto il giorno")
                .font(.system(size: 21))
                .foregroundColor(event.color.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(event.color.opacity(0.2))  // Tinted background
        .cornerRadius(8)  // Smaller radius for items
    }

    // MARK: - Evento con Orario (Vertical Bar Style)
    @ViewBuilder
    private func timedEventRow(_ event: DashboardEvent) -> some View {
        HStack(spacing: 0) {
            // Vertical Color Bar
            Rectangle()
                .fill(event.color)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(event.color)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)  // Allow wrapping

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                    Text(
                        "\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))"
                    )
                    .font(.system(size: 21))
                }
                .foregroundColor(event.color.opacity(0.8))

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                        Text(location)
                            .font(.system(size: 21))
                            .fixedSize(horizontal: false, vertical: true)  // Allow location wrapping
                    }
                    .foregroundColor(event.color.opacity(0.8))
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 10)
            .padding(.trailing, 12)

            Spacer()
        }
        .background(event.color.opacity(0.15))  // Sfondo colorato trasparente
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(event.color.opacity(0.3), lineWidth: 1)  // Optional border for better definition
        )
    }
}
