//
//  CalendarManager.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation
import SwiftUI

class CalendarManager: ObservableObject {
    @Published var upcomingEvents: [DashboardEvent] = []
    @Published var isRefreshing: Bool = false

    // Persistenza
    @AppStorage("selectedGoogleCalendars") private var selectedGoogleCalendarsData: Data = Data()
    @AppStorage("selectedOutlookCalendars") private var selectedOutlookCalendarsData: Data = Data()

    var selectedGoogleCalendars: [CalendarInfo] {
        get {
            (try? JSONDecoder().decode([CalendarInfo].self, from: selectedGoogleCalendarsData))
                ?? []
        }
        set { selectedGoogleCalendarsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var selectedOutlookCalendars: [CalendarInfo] {
        get {
            (try? JSONDecoder().decode([CalendarInfo].self, from: selectedOutlookCalendarsData))
                ?? []
        }
        set { selectedOutlookCalendarsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    // Servizi
    let googleService = GoogleCalendarService()
    let outlookService = OutlookCalendarService()

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init() {
        // Reindirizzamento delle modifiche all'UI
        googleService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        outlookService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        googleService.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] connected in
                if connected {
                    print("DEBUG: Google connesso. Fetching...")
                    self?.fetchEvents()
                }
            }
            .store(in: &cancellables)

        fetchEvents()

        // Aggiorna periodicamente ogni 5 min
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func fetchEvents() {
        Task {
            await MainActor.run { self.isRefreshing = true }

            var allEvents: [DashboardEvent] = []

            // Recupera Google
            if googleService.isConnected {
                // Auto-selezione se vuoto
                if selectedGoogleCalendars.isEmpty {
                    do {
                        let available = try await googleService.fetchAvailableCalendars()
                        await MainActor.run {
                            self.selectedGoogleCalendars = available
                        }
                    } catch {
                        print("DEBUG: Auto-select Google calendars failed: \(error)")
                    }
                }

                let ids = selectedGoogleCalendars.map { $0.id }
                if !ids.isEmpty {
                    do {
                        let events = try await googleService.fetchEvents(for: ids)
                        // Applica colori personalizzati
                        let enriched = events.map { event -> DashboardEvent in
                            var e = event
                            if let config = selectedGoogleCalendars.first(where: {
                                $0.id == event.calendarID
                            }),
                                let hex = config.colorHex
                            {
                                e.color = Color(hex: hex)
                            }
                            return e
                        }
                        allEvents.append(contentsOf: enriched)
                    } catch {
                        print("DEBUG: Google Fetch error: \(error.localizedDescription)")
                    }
                }
            }

            // Recupera Outlook
            if outlookService.isConnected {
                // Auto-selezione se vuoto
                if selectedOutlookCalendars.isEmpty {
                    do {
                        let available = try await outlookService.fetchAvailableCalendars()
                        await MainActor.run {
                            self.selectedOutlookCalendars = available
                        }
                    } catch {
                        print("DEBUG: Auto-select Outlook calendars failed: \(error)")
                    }
                }

                let ids = selectedOutlookCalendars.map { $0.id }
                if !ids.isEmpty {
                    do {
                        let events = try await outlookService.fetchEvents(for: ids)
                        // Applica colori personalizzati
                        let enriched = events.map { event -> DashboardEvent in
                            var e = event
                            if let config = selectedOutlookCalendars.first(where: {
                                $0.id == event.calendarID
                            }),
                                let hex = config.colorHex
                            {
                                e.color = Color(hex: hex)
                            }
                            return e
                        }
                        allEvents.append(contentsOf: enriched)
                    } catch {
                        print("DEBUG: Outlook Fetch error: \(error.localizedDescription)")
                    }
                }
            }

            // Mock di simulazione: aggiungi 3 eventi se non ci sono account connessi o nessun evento recuperato
            if (!googleService.isConnected && !outlookService.isConnected) || allEvents.isEmpty {
                let cal = Calendar.current
                let now = Date()
                let startToday = cal.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
                let endToday = cal.date(byAdding: .minute, value: 60, to: startToday) ?? startToday.addingTimeInterval(3600)

                let tomorrowDate = cal.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
                let startTomorrow = cal.date(bySettingHour: 15, minute: 30, second: 0, of: tomorrowDate) ?? tomorrowDate
                let endTomorrow = cal.date(byAdding: .minute, value: 90, to: startTomorrow) ?? startTomorrow.addingTimeInterval(5400)

                // Evento tutto il giorno per oggi
                let allDayStart = cal.startOfDay(for: now)
                let allDayEnd = cal.date(byAdding: .day, value: 1, to: allDayStart) ?? allDayStart

                let mockToday = DashboardEvent(
                    title: "Riunione di allineamento",
                    startDate: startToday,
                    endDate: endToday,
                    location: "Sala A / Teams",
                    color: .red,
                    calendarID: "mock",
                    isAllDay: false
                )

                let mockTomorrow = DashboardEvent(
                    title: "Revisione progetto",
                    startDate: startTomorrow,
                    endDate: endTomorrow,
                    location: "Sala Riunioni",
                    color: .blue,
                    calendarID: "mock",
                    isAllDay: false
                )

                let mockAllDay = DashboardEvent(
                    title: "Focus Day",
                    startDate: allDayStart,
                    endDate: allDayEnd,
                    location: nil,
                    color: .green,
                    calendarID: "mock",
                    isAllDay: true
                )

                allEvents.append(contentsOf: [mockAllDay, mockToday, mockTomorrow])
            }

            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow =
                calendar.date(byAdding: .day, value: 7, to: today)
                ?? today.addingTimeInterval(86400 * 7)

            let filtered = allEvents.filter { event in
                event.endDate >= today && event.startDate < tomorrow
            }

            let sorted = filtered.sorted { $0.startDate < $1.startDate }

            await MainActor.run {
                self.upcomingEvents = sorted
                self.isRefreshing = false
            }
        }
    }
}

// Helper per inizializzare Colore da Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CalendarManagerPreviewView: View {
    @StateObject private var manager = CalendarManager()

    var body: some View {
        NavigationStack {
            List {
                if manager.isRefreshing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Aggiornamento eventi…")
                        }
                    }
                }
                Section("Prossimi eventi") {
                    if manager.upcomingEvents.isEmpty {
                        Text("Nessun evento in arrivo")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(manager.upcomingEvents.indices, id: \.self) { idx in
                            let event = manager.upcomingEvents[idx]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(event.color)
                                        .frame(width: 8, height: 8)
                                    Text("\(event.startDate.formatted(date: .abbreviated, time: .shortened)) → \(event.endDate.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let location = event.location {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Anteprima Calendario")
        }
    }
}

#Preview("CalendarManager Preview") {
    CalendarManagerPreviewView()
}

