//
//  WeatherModel.swift
//  DashB
//
//  Created by User on 20/01/26.
//

import Combine
import CoreLocation
import Foundation
import SwiftUI
import WeatherKit

struct Forecast: Identifiable {
    let id = UUID()
    let time: String
    let icon: String  // SF Symbol
    let temp: String
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let day: String
    let icon: String
    let tempHigh: String
    let tempLow: String
}

@MainActor
class WeatherModel: NSObject, ObservableObject {
    @Published var selectedCity: String {
        didSet {
            UserDefaults.standard.set(selectedCity, forKey: Self.cityDefaultsKey)
        }
    }
    @Published var useManualCity: Bool {
        didSet {
            UserDefaults.standard.set(useManualCity, forKey: Self.useManualCityDefaultsKey)
            Task { await self.refresh() }
        }
    }

    private static let cityDefaultsKey = "WeatherModel.selectedCity"
    private static let useManualCityDefaultsKey = "WeatherModel.useManualCity"
    private let geocoder = CLGeocoder()
    private let defaultCity = "Milano"

    @Published var currentTemp: String = "--°"
    @Published var conditionIcon: String = "cloud.fill"
    @Published var conditionDescription: String = "--"
    @Published var hourlyForecast: [Forecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var cityName: String = "Caricamento..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var timer: Timer?
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()

    override init() {
        self.selectedCity = UserDefaults.standard.string(forKey: Self.cityDefaultsKey) ?? ""
        self.useManualCity =
            UserDefaults.standard.object(forKey: Self.useManualCityDefaultsKey) as? Bool ?? false
        super.init()
        locationManager.delegate = self
        #if os(tvOS)
            // On tvOS there is no user location; default to manual city if not set by the user
            if UserDefaults.standard.object(forKey: Self.useManualCityDefaultsKey) == nil {
                self.useManualCity = true
            }
            if self.useManualCity && self.selectedCity.isEmpty {
                self.selectedCity = defaultCity
            }
        #endif
        requestLocationIfNeeded()
        // Determine initial city name logic during first refresh
        startTimer()
        Task { await self.refresh() }
    }

    func startTimer() {
        // Update every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        // Case 1: Manual City
        if useManualCity {
            let cityQuery = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
            #if os(tvOS)
                if !cityQuery.isEmpty {
                    if let (location, name) = await geocodeCityName(cityQuery) {
                        self.cityName = name
                        await fetchWeather(for: location)
                    } else {
                        // Fallback to default coordinates on tvOS if geocoding fails
                        let fallback = CLLocation(latitude: 45.4642, longitude: 9.1900)
                        self.cityName = defaultCity
                        await fetchWeather(for: fallback)
                    }
                } else {
                    // No city typed: use default
                    let fallback = CLLocation(latitude: 45.4642, longitude: 9.1900)
                    self.cityName = defaultCity
                    await fetchWeather(for: fallback)
                }
                return
            #endif
            if !cityQuery.isEmpty {
                // Try to geocode to get coordinates AND pretty name
                if let (location, name) = await geocodeCityName(cityQuery) {
                    self.cityName = name  // e.g. "Milano" from geocoder
                    await fetchWeather(for: location)
                }
            }
            return
        }

        // Case 2: Auto / GPS
        #if os(tvOS)
            // tvOS does not provide CoreLocation; fallback to a default city
            await fetchDefaultCityWeather()
            return
        #endif

        // Check permissions first
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            self.cityName = "Permessi Geoloc. Negati"
            await fetchDefaultCityWeather()
            return
        case .notDetermined:
            #if os(tvOS)
                await fetchDefaultCityWeather()
                return
            #else
                // Waiting for user...
                self.cityName = "In attesa di permessi..."
                locationManager.requestWhenInUseAuthorization()
                return
            #endif
        default:
            break
        }

        guard let location = await currentLocation() else {
            self.cityName = "Posizione non trovata"
            await fetchDefaultCityWeather()
            return
        }

        // Reverse geocode to show city name for GPS location
        if let name = await reverseGeocodeLocation(location) {
            self.cityName = name
        } else {
            self.cityName = "Posizione Attuale"
        }

        await fetchWeather(for: location)
    }

    func requestLocationIfNeeded() {
        #if !os(tvOS)
            if useManualCity { return }

            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            } else if locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways
            {
                locationManager.requestLocation()
            }
        #endif
    }

    func updateCity(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            self.selectedCity = trimmed
            self.useManualCity = true
            Task { await self.refresh() }
        }
    }

    func useCurrentLocation() {
        self.useManualCity = false
        requestLocationIfNeeded()
        Task {
            await self.refresh()
            // Dopo il refresh, se abbiamo una posizione GPS, aggiorniamo selectedCity con il nome della città
            if !self.useManualCity, let location = await currentLocation() {
                if let cityName = await reverseGeocodeLocation(location) {
                    self.selectedCity = cityName
                }
            }
        }
    }

    private func currentLocation() async -> CLLocation? {
        if let loc = locationManager.location { return loc }
        return await withCheckedContinuation { continuation in
            locationRequestContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // Returns (Location, FormattedName)
    private func geocodeCityName(_ name: String) async -> (CLLocation, String)? {
        await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(name) { placemarks, error in
                if let placemark = placemarks?.first, let location = placemark.location {
                    // Use locality (City) or name, fallback to user input
                    let resolvedName = placemark.locality ?? placemark.name ?? name
                    continuation.resume(returning: (location, resolvedName))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.locality)
            }
        }
    }

    // MARK: - Weather
    private func fetchWeather(for location: CLLocation) async {
        // Sanitize location: create a clean object with just coords to avoid any geocoder metadata issues
        let cleanLocation = CLLocation(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let previousCityName = self.cityName

        do {
            if #available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, *) {
                let (current, hourly, daily) = try await weatherService.weather(
                    for: cleanLocation, including: .current, .hourly, .daily)

                // Current conditions
                let tempC = current.temperature.converted(to: .celsius).value
                self.currentTemp = String(format: "%.0f°", tempC)
                self.conditionIcon = sfSymbol(for: current.symbolName)
                self.conditionDescription = self.descriptionForCondition(current.condition)

                // Hourly forecast (next 4 entries)
                var items: [Forecast] = []
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "it_IT")
                dateFormatter.dateFormat = "HH:mm"

                let hours = hourly.prefix(4)
                for (index, hour) in hours.enumerated() {
                    let label: String
                    if index == 0 {
                        label = "Ora"
                    } else {
                        label = dateFormatter.string(from: hour.date)
                    }
                    let icon = sfSymbol(for: hour.symbolName)
                    let t = hour.temperature.converted(to: .celsius).value
                    items.append(
                        Forecast(time: label, icon: icon, temp: String(format: "%.0f°", t)))
                }
                self.hourlyForecast = items

                // Daily forecast (next 5 days)
                var dailyItems: [DailyForecast] = []
                let dayFormatter = DateFormatter()
                dayFormatter.locale = Locale(identifier: "it_IT")
                dayFormatter.dateFormat = "EEE"  // Wed, Thu, etc.

                let days = daily.dropFirst().prefix(5)
                for day in days {
                    let label = dayFormatter.string(from: day.date)
                    let icon = sfSymbol(for: day.symbolName)
                    let high = day.highTemperature.converted(to: .celsius).value
                    let low = day.lowTemperature.converted(to: .celsius).value
                    dailyItems.append(
                        DailyForecast(
                            day: label, icon: icon, tempHigh: String(format: "%.0f°", high),
                            tempLow: String(format: "%.0f°", low)))
                }
                self.dailyForecast = dailyItems
            } else {
                let weather = try await weatherService.weather(for: cleanLocation)

                // Current conditions
                let tempC = weather.currentWeather.temperature.converted(to: .celsius).value
                self.currentTemp = String(format: "%.0f°", tempC)
                self.conditionIcon = sfSymbol(for: weather.currentWeather.symbolName)
                self.conditionDescription = self.descriptionForCondition(
                    weather.currentWeather.condition)

                // Hourly forecast (next 4 entries)
                var items: [Forecast] = []
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "it_IT")
                dateFormatter.dateFormat = "HH:mm"

                let hours = weather.hourlyForecast.prefix(4)
                for (index, hour) in hours.enumerated() {
                    let label: String
                    if index == 0 {
                        label = "Ora"
                    } else {
                        label = dateFormatter.string(from: hour.date)
                    }
                    let icon = sfSymbol(for: hour.symbolName)
                    let t = hour.temperature.converted(to: .celsius).value
                    items.append(
                        Forecast(time: label, icon: icon, temp: String(format: "%.0f°", t)))
                }
                self.hourlyForecast = items

                // Daily forecast (next 5 days)
                var dailyItems: [DailyForecast] = []
                let dayFormatter = DateFormatter()
                dayFormatter.locale = Locale(identifier: "it_IT")
                dayFormatter.dateFormat = "EEE"

                let days = weather.dailyForecast.dropFirst().prefix(5)
                for day in days {
                    let label = dayFormatter.string(from: day.date)
                    let icon = sfSymbol(for: day.symbolName)
                    let high = day.highTemperature.converted(to: .celsius).value
                    let low = day.lowTemperature.converted(to: .celsius).value
                    dailyItems.append(
                        DailyForecast(
                            day: label, icon: icon, tempHigh: String(format: "%.0f°", high),
                            tempLow: String(format: "%.0f°", low)))
                }
                self.dailyForecast = dailyItems
            }
        } catch {
            print("Weather fetch failed: \(error)")
            self.currentTemp = "Err"
            self.conditionIcon = "exclamationmark.triangle.fill"
            self.conditionDescription = "Errore"

            let errString = error.localizedDescription

            // Check for common error signatures
            if let weatherError = error as? WeatherError {
                // WeatherError does not expose missingPermissions/unauthorized cases. Show a generic message with the error.
                self.cityName = "Err WeatherKit: \(weatherError)"
            } else if errString.localizedCaseInsensitiveContains("WeatherDaemon")
                || errString.localizedCaseInsensitiveContains("connection")
            {
                self.cityName = "Riavvia Sim / Aggiungi Capab."
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    self.cityName = "Errore di rete"
                default:
                    self.cityName = "Err Rete: \(urlError.localizedDescription)"
                }
            } else {
                // Fallback
                self.cityName = errString
            }
            #if targetEnvironment(simulator)
                // In Simulator, always show mock data if WeatherKit fails
                self.applyMockWeather()
            #endif
            #if os(tvOS)
                // On tvOS, fallback to Open-Meteo if WeatherKit fails so we still show real data
                await fetchWeatherFromOpenMeteo(for: cleanLocation)
                if self.cityName.hasPrefix("Err")
                    || self.cityName.localizedCaseInsensitiveContains("Capab")
                {
                    // Keep previous city label if we had set an error
                    self.cityName = previousCityName
                }
            #endif
        }
    }

    private func sfSymbol(for symbolName: String) -> String {
        // WeatherKit already returns an SF Symbol compatible name; fall back to a default if empty
        return symbolName.isEmpty ? "cloud.fill" : symbolName
    }

    private func fetchDefaultCityWeather() async {
        #if os(tvOS)
            let location = CLLocation(latitude: 45.4642, longitude: 9.1900)
            self.cityName = "Milano"
            await fetchWeather(for: location)
        #else
            if let (location, name) = await geocodeCityName(defaultCity) {
                self.cityName = name
                await fetchWeather(for: location)
            } else {
                self.cityName = "Città di default non disponibile"
                #if targetEnvironment(simulator)
                    self.applyMockWeather()
                #endif
            }
        #endif
    }

    #if DEBUG || targetEnvironment(simulator)
        private func applyMockWeather() {
            // Provide mock data for development when WeatherKit isn't available (e.g., missing capability on Simulator)
            self.currentTemp = "21°"
            self.conditionIcon = "cloud.sun.fill"
            self.conditionDescription = "Soleggiato"
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "it_IT")
            dateFormatter.dateFormat = "HH:mm"
            let now = Date()
            let times = [
                now, now.addingTimeInterval(3600), now.addingTimeInterval(7200),
                now.addingTimeInterval(10800),
            ]
            var items: [Forecast] = []
            for (index, t) in times.enumerated() {
                let label = index == 0 ? "Ora" : dateFormatter.string(from: t)
                let icon = index % 2 == 0 ? "cloud.sun.fill" : "cloud.fill"
                let temp = 20 + index
                items.append(Forecast(time: label, icon: icon, temp: String(format: "%d°", temp)))
            }
            self.hourlyForecast = items

            var dailyItems: [DailyForecast] = []
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "it_IT")
            dayFormatter.dateFormat = "EEE"
            let calendar = Calendar.current

            for i in 1...5 {
                guard let date = calendar.date(byAdding: .day, value: i, to: now) else { continue }
                let dayLabel = dayFormatter.string(from: date)
                let icon = i % 2 == 0 ? "cloud.sun.fill" : "sun.max.fill"
                let high = 22 + i
                let low = 15 + i
                dailyItems.append(
                    DailyForecast(
                        day: dayLabel, icon: icon, tempHigh: "\(high)°", tempLow: "\(low)°"))
            }
            self.dailyForecast = dailyItems
            if self.cityName.isEmpty || self.cityName.hasPrefix("Err") {
                self.cityName = "Dati di esempio"
            }
        }
    #endif

    // MARK: - Open-Meteo fallback (tvOS)
    private func sfSymbolFromWeatherCode(_ code: Int, isDay: Int = 1) -> String {
        switch code {
        case 0:
            return isDay == 1 ? "sun.max.fill" : "moon.stars.fill"  // Clear sky
        case 1, 2:
            return isDay == 1 ? "cloud.sun.fill" : "cloud.moon.fill"  // Mainly clear/partly cloudy
        case 3:
            return "cloud.fill"  // Overcast
        case 45, 48:
            return "cloud.fog.fill"  // Fog
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"  // Drizzle
        case 61, 63, 65, 66, 67:
            return "cloud.rain.fill"  // Rain
        case 71, 73, 75, 77:
            return "cloud.snow.fill"  // Snow
        case 80, 81, 82:
            return "cloud.heavyrain.fill"  // Rain showers
        case 85, 86:
            return "cloud.snow.fill"  // Snow showers
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"  // Thunderstorm
        default:
            return "cloud.fill"
        }
    }

    private func descriptionFromWeatherCode(_ code: Int) -> String {
        switch code {
        case 0: return "Ciel Sereno"
        case 1: return "Poco Nuvoloso"
        case 2: return "Parz. Nuvoloso"
        case 3: return "Coperto"
        case 45, 48: return "Nebbia"
        case 51, 53, 55: return "Pioviggine"
        case 56, 57: return "Pioviggine Gel."
        case 61, 63, 65: return "Pioggia"
        case 66, 67: return "Pioggia Gelata"
        case 71, 73, 75: return "Neve"
        case 77: return "Nevischio"
        case 80, 81, 82: return "Rovesci"
        case 85, 86: return "Rovesci Nevosi"
        case 95: return "Temporale"
        case 96, 99: return "Temp. con Grandine"
        default: return "Sconosciuto"
        }
    }

    // Helper to translate WeatherKit conditions to Italian
    private func descriptionForCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return "Ciel Sereno"
        case .cloudy: return "Nuvoloso"
        case .mostlyClear: return "Preval. Sereno"
        case .mostlyCloudy: return "Preval. Nuvoloso"
        case .partlyCloudy: return "Parz. Nuvoloso"
        case .foggy: return "Nebbia"
        case .haze: return "Foschia"
        case .breezy: return "Ventoso"
        case .windy: return "Molto Ventoso"
        case .drizzle: return "Pioviggine"
        case .rain: return "Pioggia"
        case .heavyRain: return "Forte Pioggia"
        case .snow: return "Neve"
        case .heavySnow: return "Forte Neve"
        case .sleet: return "Nevischio"
        case .freezingDrizzle: return "Pioviggine Gel."
        case .freezingRain: return "Pioggia Gelata"
        case .flurries: return "Rovesci di Neve"
        case .blowingSnow: return "Neve Vento"
        case .hail: return "Grandine"
        case .thunderstorms: return "Temporali"
        case .isolatedThunderstorms: return "Temporali Isol."
        case .scatteredThunderstorms: return "Temporali Sparsi"
        case .strongStorms: return "Tempeste Forti"
        case .blowingDust: return "Polvere"
        @unknown default: return "Sconosciuto"
        }
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature: Double
            let weathercode: Int
            let is_day: Int
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let weathercode: [Int]?
            let is_day: [Int]?
        }
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let weathercode: [Int]?
        }
        let current_weather: Current?
        let hourly: Hourly?
        let daily: Daily?
    }

    private func fetchWeatherFromOpenMeteo(for location: CLLocation) async {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current_weather", value: "true"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weathercode,is_day"),
            URLQueryItem(name: "daily", value: "weathercode,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = comps.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            if let current = decoded.current_weather {
                self.currentTemp = String(format: "%.0f°", current.temperature)
                self.conditionIcon = self.sfSymbolFromWeatherCode(
                    current.weathercode, isDay: current.is_day)
                self.conditionDescription = self.descriptionFromWeatherCode(current.weathercode)
            }

            if let hourly = decoded.hourly {
                // Open-Meteo returns time in "yyyy-MM-ddTHH:mm" format (ISO8601-like but simple)
                let isoFormatter = DateFormatter()
                isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                isoFormatter.locale = Locale(identifier: "en_US_POSIX")

                let now = Date()
                var startIndex = 0
                for (idx, ts) in hourly.time.enumerated() {
                    // Try to find the first time slot that is >= now (or close to it)
                    if let d = isoFormatter.date(from: ts), d >= now.addingTimeInterval(-1800) {
                        // Allow 30 mins buffer so we don't skip current hour just because we are at xx:01
                        startIndex = idx
                        break
                    }
                }

                let end = min(startIndex + 4, hourly.time.count)
                var items: [Forecast] = []

                let outputFormatter = DateFormatter()
                outputFormatter.locale = Locale(identifier: "it_IT")
                outputFormatter.dateFormat = "HH:mm"

                for idx in startIndex..<end {
                    let rawTime = hourly.time[idx]
                    var label = "--:--"

                    if idx == startIndex {
                        label = "Ora"
                    } else if let date = isoFormatter.date(from: rawTime) {
                        label = outputFormatter.string(from: date)
                    }

                    let temp = idx < hourly.temperature_2m.count ? hourly.temperature_2m[idx] : .nan
                    let code = hourly.weathercode?[idx] ?? 0
                    let isDay = hourly.is_day?[idx] ?? 1
                    items.append(
                        Forecast(
                            time: label, icon: self.sfSymbolFromWeatherCode(code, isDay: isDay),
                            temp: String(format: "%.0f°", temp)))
                }
                self.hourlyForecast = items
            }

            if let daily = decoded.daily {
                var dailyItems: [DailyForecast] = []
                let df = DateFormatter()
                df.locale = Locale(identifier: "it_IT")
                df.dateFormat = "yyyy-MM-dd"
                let outDf = DateFormatter()
                outDf.locale = Locale(identifier: "it_IT")
                outDf.dateFormat = "EEE"

                let count = daily.time.count
                // Start from index 1 (tomorrow) to skip today, take up to 5 days
                let startIndex = 1
                let endIndex = min(startIndex + 5, count)

                for i in startIndex..<endIndex {
                    let label =
                        df.date(from: daily.time[i]).map { outDf.string(from: $0) } ?? daily.time[i]
                    let code = daily.weathercode?[i] ?? 0
                    let high = daily.temperature_2m_max[i]
                    let low = daily.temperature_2m_min[i]
                    dailyItems.append(
                        DailyForecast(
                            day: label, icon: self.sfSymbolFromWeatherCode(code),
                            tempHigh: String(format: "%.0f°", high),
                            tempLow: String(format: "%.0f°", low)))
                }
                self.dailyForecast = dailyItems
            }
        } catch {
            #if DEBUG
                print("Open-Meteo fallback failed: \(error)")
            #endif
        }
    }

    // MARK: - Location continuation
    private var locationRequestContinuation: CheckedContinuation<CLLocation?, Never>?

    deinit {
        timer?.invalidate()
    }
}

extension WeatherModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if useManualCity { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
            Task { await refresh() }
        case .denied, .restricted:
            Task { await fetchDefaultCityWeather() }
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            locationRequestContinuation?.resume(returning: loc)
            locationRequestContinuation = nil
            Task { await fetchWeather(for: loc) }
        } else {
            locationRequestContinuation?.resume(returning: nil)
            locationRequestContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
            print("Location error: \(error)")
        #endif
        locationRequestContinuation?.resume(returning: nil)
        locationRequestContinuation = nil
    }
}
