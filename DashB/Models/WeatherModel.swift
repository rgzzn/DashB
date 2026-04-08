//
//  WeatherModel.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import CoreLocation
import MapKit
import Foundation
import SwiftUI
import WeatherKit

struct Forecast: Identifiable {
    let id = UUID()
    let time: String
    let icon: String  // Simbolo SF
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
            guard oldValue != useManualCity else { return }
            Task { await self.refresh() }
        }
    }

    private static let cityDefaultsKey = "WeatherModel.selectedCity"
    private static let useManualCityDefaultsKey = "WeatherModel.useManualCity"
    private var defaultCity: String { L10n.string("weather.defaultCity") }
    private var cachedManualCity: String?
    private var cachedManualLocation: CLLocation?
    private var cachedManualCityName: String?
    private var latestWeatherRequestID: UInt64 = 0

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "EE"
        return formatter
    }()

    @Published var currentTemp: String = "--°"
    @Published var conditionIcon: String = "cloud.fill"
    @Published var conditionDescription: String = "--"
    @Published var hourlyForecast: [Forecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var cityName: String = L10n.string("weather.city.loading")
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @Published var weatherAdvice: String = L10n.string("weather.advice.default")

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
            // Su tvOS non c'è posizione utente; predefinito a città manuale se non impostato dall'utente
            if UserDefaults.standard.object(forKey: Self.useManualCityDefaultsKey) == nil {
                self.useManualCity = true
            }
            if self.useManualCity && self.selectedCity.isEmpty {
                self.selectedCity = defaultCity
            }
        #endif
        requestLocationIfNeeded()
        // Determina la logica del nome città iniziale durante il primo aggiornamento
        startTimer()
        Task { await self.refresh() }
    }

    func startTimer() {
        timer?.invalidate()
        // Aggiorna ogni 15 minuti
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        // Caso 1: Città Manuale
        if useManualCity {
            let cityQuery = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines)
            #if os(tvOS)
                if !cityQuery.isEmpty {
                    if let cachedCity = cachedManualCity,
                        cachedCity.caseInsensitiveCompare(cityQuery) == .orderedSame,
                        let cachedLocation = cachedManualLocation
                    {
                        self.cityName = cachedManualCityName ?? cityQuery
                        await fetchWeather(for: cachedLocation)
                    } else if let (location, name) = await geocodeCityName(cityQuery) {
                        cachedManualCity = cityQuery
                        cachedManualLocation = location
                        cachedManualCityName = name
                        self.cityName = name
                        await fetchWeather(for: location)
                    } else {
                        // Ripiego su Open-Meteo se geocodifica Apple fallisce
                        if let (location, name) = await geocodeCityNameOpenMeteo(cityQuery) {
                            cachedManualCity = cityQuery
                            cachedManualLocation = location
                            cachedManualCityName = name
                            self.cityName = name
                            await fetchWeather(for: location)
                        } else {
                            // Fallimento TOTALE: mostra errore per la città cercata
                            self.cityName = cityQuery.capitalized
                            self.currentTemp = "--°"
                            self.conditionIcon = "exclamationmark.magnifyingglass"
                            self.conditionDescription = L10n.string("weather.city.notFound")
                            self.weatherAdvice = L10n.string("weather.city.checkName")
                            self.hourlyForecast = []
                            self.dailyForecast = []
                        }
                    }
                } else {
                    // Nessuna città digitata: usa predefinito
                    let fallback = CLLocation(latitude: 44.2225, longitude: 12.0408)
                    self.cityName = defaultCity
                    await fetchWeather(for: fallback)
                }
                return
            #else
                if !cityQuery.isEmpty {
                    // Prova a geocodificare per ottenere coordinate E bel nome
                    if let (location, name) = await geocodeCityName(cityQuery) {
                        self.cityName = name  // es. "Milano" dal geocoder
                        await fetchWeather(for: location)
                    } else if let (location, name) = await geocodeCityNameOpenMeteo(cityQuery) {
                        // Fallback Open-Meteo anche su iOS/macOS
                        self.cityName = name
                        await fetchWeather(for: location)
                    } else {
                        // Fallimento TOTALE
                        self.cityName = cityQuery.capitalized
                        self.currentTemp = "--°"
                        self.conditionIcon = "exclamationmark.magnifyingglass"
                        self.conditionDescription = L10n.string("weather.city.notFound")
                        self.weatherAdvice = L10n.string("weather.city.checkName")
                        self.hourlyForecast = []
                        self.dailyForecast = []
                    }
                }
                return
            #endif
        }

        // Caso 2: Auto / GPS
        #if os(tvOS)
            // tvOS non fornisce CoreLocation; ripiego su una città predefinita
            await fetchDefaultCityWeather()
            return
        #else

            // Controlla prima i permessi
            switch locationManager.authorizationStatus {
            case .denied, .restricted:
                self.cityName = L10n.string("weather.location.permissionDenied")
                await fetchDefaultCityWeather()
                return
            case .notDetermined:
                #if os(tvOS)
                    await fetchDefaultCityWeather()
                    return
                #else
                    // In attesa dell'utente...
                    self.cityName = L10n.string("weather.location.waitingPermission")
                    locationManager.requestWhenInUseAuthorization()
                    return
                #endif
            default:
                break
            }

            guard let location = await currentLocation() else {
                self.cityName = L10n.string("weather.location.notFound")
                await fetchDefaultCityWeather()
                return
            }

            // Geocodifica inversa per mostrare il nome della città per la posizione GPS
            if let name = await reverseGeocodeLocation(location) {
                self.cityName = name
            } else {
                self.cityName = L10n.string("weather.location.current")
            }

            await fetchWeather(for: location)
        #endif
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
        guard !trimmed.isEmpty else { return }

        let cityChanged = selectedCity.caseInsensitiveCompare(trimmed) != .orderedSame
        if cityChanged {
            selectedCity = trimmed
            cachedManualCity = nil
            cachedManualLocation = nil
            cachedManualCityName = nil
        }

        let wasManualCity = useManualCity
        useManualCity = true

        if wasManualCity && cityChanged {
            Task { await self.refresh() }
        }
    }

    func useCurrentLocation() {
        let wasManualCity = useManualCity
        useManualCity = false
        requestLocationIfNeeded()

        if !wasManualCity {
            Task { await self.refresh() }
        }

        Task {
            // Dopo il refresh GPS, riallinea selectedCity con la città effettiva.
            guard !self.useManualCity, let location = await currentLocation() else { return }
            if let cityName = await reverseGeocodeLocation(location) {
                self.selectedCity = cityName
            }
        }
    }

    private func currentLocation() async -> CLLocation? {
        if let loc = locationManager.location { return loc }
        return await withCheckedContinuation { continuation in
            let shouldRequest = locationRequestContinuations.isEmpty
            locationRequestContinuations.append(continuation)
            if shouldRequest {
                locationManager.requestLocation()
            }
        }
    }

    // Restituisce (Posizione, NomeFormattato)
    private func geocodeCityName(_ name: String) async -> (CLLocation, String)? {
        if #available(tvOS 26.0, *) {
            guard let request = MKGeocodingRequest(addressString: name) else { return nil }

            do {
                let mapItems = try await request.mapItems
                if let item = mapItems.first {
                    let resolvedName = item.addressRepresentations?.cityName ?? item.name ?? name
                    let location = item.location
                    return (location, resolvedName)
                }
                return nil
            } catch {
                return nil
            }
        } else {
            return await withCheckedContinuation { continuation in
                CLGeocoder().geocodeAddressString(name) { placemarks, _ in
                    if let placemark = placemarks?.first, let location = placemark.location {
                        let resolvedName = placemark.locality ?? placemark.name ?? name
                        continuation.resume(returning: (location, resolvedName))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func reverseGeocodeLocation(_ location: CLLocation) async -> String? {
        if #available(tvOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }

            do {
                let mapItems = try await request.mapItems
                return mapItems.first?.addressRepresentations?.cityName ?? mapItems.first?.name
            } catch {
                return nil
            }
        } else {
            return await withCheckedContinuation { continuation in
                CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                    continuation.resume(returning: placemarks?.first?.locality ?? placemarks?.first?.name)
                }
            }
        }
    }

    private func nextWeatherRequestID() -> UInt64 {
        latestWeatherRequestID &+= 1
        return latestWeatherRequestID
    }

    private func isLatestWeatherRequest(_ requestID: UInt64) -> Bool {
        requestID == latestWeatherRequestID
    }

    // MARK: - Meteo
    private func fetchWeather(for location: CLLocation) async {
        let requestID = nextWeatherRequestID()
        // Sanitizza posizione: crea un oggetto pulito con solo coordinate per evitare problemi di metadati geocoder
        let cleanLocation = CLLocation(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let previousCityName = self.cityName

        do {
            if #available(iOS 17.0, tvOS 17.0, macOS 14.0, watchOS 10.0, *) {
                let (current, hourly, daily) = try await weatherService.weather(
                    for: cleanLocation, including: .current, .hourly, .daily)

                // Condizioni attuali
                let tempC = current.temperature.converted(to: .celsius).value
                let currentTemp = String(format: "%.0f°", tempC)
                let conditionIcon = sfSymbol(for: current.symbolName)
                let conditionDescription = self.descriptionForCondition(current.condition)
                let weatherAdvice = self.adviceForCondition(current.condition)

                // Previsioni orarie (prossime 4 voci)
                var items: [Forecast] = []

                let hours = hourly.prefix(4)
                for (index, hour) in hours.enumerated() {
                    let label: String
                    if index == 0 {
                        label = L10n.string("weather.hour.now")
                    } else {
                        label = Self.hourFormatter.string(from: hour.date)
                    }
                    let icon = sfSymbol(for: hour.symbolName)
                    let t = hour.temperature.converted(to: .celsius).value
                    items.append(
                        Forecast(time: label, icon: icon, temp: String(format: "%.0f°", t)))
                }

                // Previsioni giornaliere (prossimi 5 giorni)
                var dailyItems: [DailyForecast] = []

                let days = daily.dropFirst().prefix(5)
                for day in days {
                    let label = Self.dayFormatter.string(from: day.date)
                    let icon = sfSymbol(for: day.symbolName)
                    let high = day.highTemperature.converted(to: .celsius).value
                    let low = day.lowTemperature.converted(to: .celsius).value
                    dailyItems.append(
                        DailyForecast(
                            day: label, icon: icon, tempHigh: String(format: "%.0f°", high),
                            tempLow: String(format: "%.0f°", low)))
                }

                guard isLatestWeatherRequest(requestID) else { return }
                self.currentTemp = currentTemp
                self.conditionIcon = conditionIcon
                self.conditionDescription = conditionDescription
                self.weatherAdvice = weatherAdvice
                self.hourlyForecast = items
                self.dailyForecast = dailyItems
            } else {
                let weather = try await weatherService.weather(for: cleanLocation)

                // Current conditions
                let tempC = weather.currentWeather.temperature.converted(to: .celsius).value
                let currentTemp = String(format: "%.0f°", tempC)
                let conditionIcon = sfSymbol(for: weather.currentWeather.symbolName)
                let conditionDescription = self.descriptionForCondition(
                    weather.currentWeather.condition)
                let weatherAdvice = self.adviceForCondition(weather.currentWeather.condition)

                // Hourly forecast (next 4 entries)
                var items: [Forecast] = []

                let hours = weather.hourlyForecast.prefix(4)
                for (index, hour) in hours.enumerated() {
                    let label: String
                    if index == 0 {
                        label = L10n.string("weather.hour.now")
                    } else {
                        label = Self.hourFormatter.string(from: hour.date)
                    }
                    let icon = sfSymbol(for: hour.symbolName)
                    let t = hour.temperature.converted(to: .celsius).value
                    items.append(
                        Forecast(time: label, icon: icon, temp: String(format: "%.0f°", t)))
                }

                // Daily forecast (next 5 days)
                var dailyItems: [DailyForecast] = []

                let days = weather.dailyForecast.dropFirst().prefix(5)
                for day in days {
                    let label = Self.dayFormatter.string(from: day.date)
                    let icon = sfSymbol(for: day.symbolName)
                    let high = day.highTemperature.converted(to: .celsius).value
                    let low = day.lowTemperature.converted(to: .celsius).value
                    dailyItems.append(
                        DailyForecast(
                            day: label, icon: icon, tempHigh: String(format: "%.0f°", high),
                            tempLow: String(format: "%.0f°", low)))
                }

                guard isLatestWeatherRequest(requestID) else { return }
                self.currentTemp = currentTemp
                self.conditionIcon = conditionIcon
                self.conditionDescription = conditionDescription
                self.weatherAdvice = weatherAdvice
                self.hourlyForecast = items
                self.dailyForecast = dailyItems
            }
        } catch {
            guard isLatestWeatherRequest(requestID) else { return }
            print("Weather fetch failed: \(error)")
            self.currentTemp = L10n.string("weather.error.short")
            self.conditionIcon = "exclamationmark.triangle.fill"
            self.conditionDescription = L10n.string("weather.error.title")
            self.weatherAdvice = L10n.string("weather.error.unavailable")

            self.cityName = userFacingWeatherErrorMessage(for: error)
            #if targetEnvironment(simulator)
                // Nel Simulatore, mostra sempre dati finti se WeatherKit fallisce
                self.applyMockWeather()
            #endif
            #if os(tvOS)
                // Su tvOS, ripiego su Open-Meteo se WeatherKit fallisce per mostrare comunque dati reali
                await fetchWeatherFromOpenMeteo(for: cleanLocation, requestID: requestID)
                guard isLatestWeatherRequest(requestID) else { return }
                if self.cityName == userFacingWeatherErrorMessage(for: error) {
                    // Mantieni etichetta città precedente se avevamo impostato un errore
                    self.cityName = previousCityName
                }
            #endif
        }
    }

    private func userFacingWeatherErrorMessage(for error: Error) -> String {
        if error is WeatherError {
            return L10n.string("weather.error.serviceUnavailable")
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return L10n.string("weather.error.network")
            default:
                return L10n.string("weather.error.connectionUnavailable")
            }
        }

        let technicalDescription = String(describing: error)
        if technicalDescription.localizedCaseInsensitiveContains("WeatherDaemon")
            || technicalDescription.localizedCaseInsensitiveContains("connection")
        {
            return L10n.string("weather.error.temporarilyUnavailable")
        }

        return L10n.string("weather.error.temporary")
    }

    private func sfSymbol(for symbolName: String) -> String {
        // WeatherKit restituisce già un nome compatibile con SF Symbol; ripiego su predefinito se vuoto
        return symbolName.isEmpty ? "cloud.fill" : symbolName
    }

    private func fetchDefaultCityWeather() async {
        #if os(tvOS)
            let location = CLLocation(latitude: 44.2225, longitude: 12.0408)
            self.cityName = defaultCity
            await fetchWeather(for: location)
        #else
            if let (location, name) = await geocodeCityName(defaultCity) {
                self.cityName = name
                await fetchWeather(for: location)
            } else {
                self.cityName = L10n.string("weather.error.defaultCityUnavailable")
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
            self.conditionDescription = L10n.string("weather.condition.sunny")
            self.weatherAdvice = L10n.string("weather.advice.sunny")
            let now = Date()
            let times = [
                now, now.addingTimeInterval(3600), now.addingTimeInterval(7200),
                now.addingTimeInterval(10800),
            ]
            var items: [Forecast] = []
            for (index, t) in times.enumerated() {
                let label =
                    index == 0 ? L10n.string("weather.hour.now") : Self.hourFormatter.string(from: t)
                let icon = index % 2 == 0 ? "cloud.sun.fill" : "cloud.fill"
                let temp = 20 + index
                items.append(Forecast(time: label, icon: icon, temp: String(format: "%d°", temp)))
            }
            self.hourlyForecast = items

            var dailyItems: [DailyForecast] = []
            let calendar = Calendar.current

            for i in 1...5 {
                guard let date = calendar.date(byAdding: .day, value: i, to: now) else { continue }
                let dayLabel = Self.dayFormatter.string(from: date)
                let icon = i % 2 == 0 ? "cloud.sun.fill" : "sun.max.fill"
                let high = 22 + i
                let low = 15 + i
                dailyItems.append(
                    DailyForecast(
                        day: dayLabel, icon: icon, tempHigh: "\(high)°", tempLow: "\(low)°"))
            }
            self.dailyForecast = dailyItems
            if self.cityName.isEmpty {
                self.cityName = L10n.string("weather.mock.sampleData")
            }
        }
    #endif

    // MARK: - Ripiego Open-Meteo (tvOS)
    private func sfSymbolFromWeatherCode(_ code: Int, isDay: Int = 1) -> String {
        switch code {
        case 0:
            return isDay == 1 ? "sun.max.fill" : "moon.stars.fill"  // Cielo sereno
        case 1, 2:
            return isDay == 1 ? "cloud.sun.fill" : "cloud.moon.fill"  // Prevalentemente sereno/parzialmente nuvoloso
        case 3:
            return "cloud.fill"  // Coperto
        case 45, 48:
            return "cloud.fog.fill"  // Nebbia
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"  // Pioviggine
        case 61, 63, 65, 66, 67:
            return "cloud.rain.fill"  // Pioggia
        case 71, 73, 75, 77:
            return "cloud.snow.fill"  // Neve
        case 80, 81, 82:
            return "cloud.heavyrain.fill"  // Rovesci di pioggia
        case 85, 86:
            return "cloud.snow.fill"  // Rovesci di neve
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"  // Temporale
        default:
            return "cloud.fill"
        }
    }

    private func descriptionFromWeatherCode(_ code: Int) -> String {
        switch code {
        case 0: return L10n.string("weather.condition.clear")
        case 1: return L10n.string("weather.condition.mostlyClear")
        case 2: return L10n.string("weather.condition.partlyCloudy")
        case 3: return L10n.string("weather.condition.overcast")
        case 45, 48: return L10n.string("weather.condition.fog")
        case 51, 53, 55: return L10n.string("weather.condition.drizzle")
        case 56, 57: return L10n.string("weather.condition.freezingDrizzle")
        case 61, 63, 65: return L10n.string("weather.condition.rain")
        case 66, 67: return L10n.string("weather.condition.freezingRain")
        case 71, 73, 75: return L10n.string("weather.condition.snow")
        case 77: return L10n.string("weather.condition.sleet")
        case 80, 81, 82: return L10n.string("weather.condition.showers")
        case 85, 86: return L10n.string("weather.condition.snowShowers")
        case 95: return L10n.string("weather.condition.thunderstorm")
        case 96, 99: return L10n.string("weather.condition.thunderstormHail")
        default: return L10n.string("weather.condition.unknown")
        }
    }

    // Helper to translate WeatherKit conditions to Italian
    private func descriptionForCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear: return L10n.string("weather.condition.clear")
        case .cloudy: return L10n.string("weather.condition.cloudy")
        case .mostlyClear: return L10n.string("weather.condition.mostlyClear")
        case .mostlyCloudy: return L10n.string("weather.condition.mostlyCloudy")
        case .partlyCloudy: return L10n.string("weather.condition.partlyCloudy")
        case .foggy: return L10n.string("weather.condition.fog")
        case .haze: return L10n.string("weather.condition.haze")
        case .breezy: return L10n.string("weather.condition.breezy")
        case .windy: return L10n.string("weather.condition.windy")
        case .drizzle: return L10n.string("weather.condition.drizzle")
        case .rain: return L10n.string("weather.condition.rain")
        case .heavyRain: return L10n.string("weather.condition.heavyRain")
        case .snow: return L10n.string("weather.condition.snow")
        case .heavySnow: return L10n.string("weather.condition.heavySnow")
        case .sleet: return L10n.string("weather.condition.sleet")
        case .freezingDrizzle: return L10n.string("weather.condition.freezingDrizzle")
        case .freezingRain: return L10n.string("weather.condition.freezingRain")
        case .flurries: return L10n.string("weather.condition.flurries")
        case .blowingSnow: return L10n.string("weather.condition.blowingSnow")
        case .hail: return L10n.string("weather.condition.hail")
        case .thunderstorms: return L10n.string("weather.condition.thunderstorms")
        case .isolatedThunderstorms: return L10n.string("weather.condition.isolatedThunderstorms")
        case .scatteredThunderstorms: return L10n.string("weather.condition.scatteredThunderstorms")
        case .strongStorms: return L10n.string("weather.condition.strongStorms")
        case .blowingDust: return L10n.string("weather.condition.blowingDust")
        case .blizzard: return L10n.string("weather.condition.blizzard")
        case .frigid: return L10n.string("weather.condition.frigid")
        case .hot: return L10n.string("weather.condition.hot")
        case .hurricane: return L10n.string("weather.condition.hurricane")
        case .smoky: return L10n.string("weather.condition.smoky")
        case .sunFlurries: return L10n.string("weather.condition.sunFlurries")
        case .sunShowers: return L10n.string("weather.condition.sunShowers")
        case .tropicalStorm: return L10n.string("weather.condition.tropicalStorm")
        case .wintryMix: return L10n.string("weather.condition.wintryMix")
        @unknown default: return L10n.string("weather.condition.unknown")
        }
    }

    private func adviceForCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .partlyCloudy:
            return L10n.string("weather.advice.sunny")
        case .cloudy, .mostlyCloudy:
            return L10n.string("weather.advice.cloudy")
        case .foggy, .haze:
            return L10n.string("weather.advice.lowVisibility")
        case .breezy, .windy:
            return L10n.string("weather.advice.windy")
        case .drizzle, .rain, .heavyRain:
            return L10n.string("weather.advice.rainy")
        case .snow, .heavySnow, .flurries, .blowingSnow, .sleet, .freezingDrizzle, .freezingRain:
            return L10n.string("weather.advice.snow")
        case .hail:
            return L10n.string("weather.advice.hail")
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return L10n.string("weather.advice.thunderstorms")
        case .blowingDust:
            return L10n.string("weather.advice.dust")
        case .blizzard:
            return L10n.string("weather.advice.blizzard")
        case .frigid:
            return L10n.string("weather.advice.frigid")
        case .hot:
            return L10n.string("weather.advice.hot")
        case .hurricane:
            return L10n.string("weather.advice.hurricane")
        case .smoky:
            return L10n.string("weather.advice.smoky")
        case .sunFlurries:
            return L10n.string("weather.advice.sunFlurries")
        case .sunShowers:
            return L10n.string("weather.advice.sunShowers")
        case .tropicalStorm:
            return L10n.string("weather.advice.tropicalStorm")
        case .wintryMix:
            return L10n.string("weather.advice.wintryMix")
        @unknown default:
            return L10n.string("weather.advice.default")
        }
    }

    private func adviceFromWeatherCode(_ code: Int) -> String {
        // Codici Open-Meteo (WMO)
        // 0-3: Sereno/Nuvoloso
        // 45,48: Nebbia
        // 51-67, 80-82: Pioggia/Pioviggine
        // 71-77, 85-86: Neve
        // 95-99: Temporali
        switch code {
        case 0, 1, 2:
            return L10n.string("weather.advice.sunny")
        case 3:
            return L10n.string("weather.advice.overcast")
        case 45, 48:
            return L10n.string("weather.advice.fog")
        case 51...67, 80...82:
            return L10n.string("weather.advice.rainy")
        case 71...77, 85...86:
            return L10n.string("weather.advice.snow")
        case 95...99:
            return L10n.string("weather.advice.thunderstormsShort")
        default:
            return L10n.string("weather.advice.default")
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
        let timezone: String?
    }

    private struct OpenMeteoGeocodingResponse: Decodable {
        let results: [OpenMeteoPlace]?
    }

    private struct OpenMeteoPlace: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?  // Regione/Stato
    }

    private func fetchWeatherFromOpenMeteo(for location: CLLocation, requestID: UInt64? = nil) async
    {
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
            if let requestID, !isLatestWeatherRequest(requestID) { return }

            let sourceTimeZone = decoded.timezone.flatMap(TimeZone.init(identifier:)) ?? .current
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            inputFormatter.locale = Locale(identifier: "en_US_POSIX")
            inputFormatter.timeZone = sourceTimeZone

            let outputHourFormatter = DateFormatter()
            outputHourFormatter.locale = .autoupdatingCurrent
            outputHourFormatter.dateFormat = "HH:mm"
            outputHourFormatter.timeZone = sourceTimeZone

            let dayInputFormatter = DateFormatter()
            dayInputFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayInputFormatter.dateFormat = "yyyy-MM-dd"
            dayInputFormatter.timeZone = sourceTimeZone

            let outputDayFormatter = DateFormatter()
            outputDayFormatter.locale = .autoupdatingCurrent
            outputDayFormatter.dateFormat = "EE"
            outputDayFormatter.timeZone = sourceTimeZone

            if let current = decoded.current_weather {
                self.currentTemp = String(format: "%.0f°", current.temperature)
                self.conditionIcon = self.sfSymbolFromWeatherCode(
                    current.weathercode, isDay: current.is_day)
                self.conditionDescription = self.descriptionFromWeatherCode(current.weathercode)
                self.weatherAdvice = self.adviceFromWeatherCode(current.weathercode)
            }

            if let hourly = decoded.hourly {
                // Open-Meteo restituisce l'ora nel formato "yyyy-MM-ddTHH:mm" (tipo ISO8601 ma semplice)
                let now = Date()
                var startIndex = 0
                for (idx, ts) in hourly.time.enumerated() {
                    // Prova a trovare il primo slot temporale che è >= adesso (o vicino)
                    if let d = inputFormatter.date(from: ts),
                        d >= now.addingTimeInterval(-1800)
                    {
                        // Consenti buffer di 30 min per non saltare l'ora corrente solo perché siamo a xx:01
                        startIndex = idx
                        break
                    }
                }

                let end = min(startIndex + 4, hourly.time.count)
                var items: [Forecast] = []

                for idx in startIndex..<end {
                    let rawTime = hourly.time[idx]
                    var label = "--:--"

                    if idx == startIndex {
                        label = L10n.string("weather.hour.now")
                    } else if let date = inputFormatter.date(from: rawTime) {
                        label = outputHourFormatter.string(from: date)
                    }

                    let temp = idx < hourly.temperature_2m.count ? hourly.temperature_2m[idx] : .nan
                    let tempString =
                        temp.isNaN ? "--°" : String(format: "%.0f°", temp)
                    let code = hourly.weathercode?[idx] ?? 0
                    let isDay = hourly.is_day?[idx] ?? 1
                    items.append(
                        Forecast(
                            time: label, icon: self.sfSymbolFromWeatherCode(code, isDay: isDay),
                            temp: tempString))
                }
                self.hourlyForecast = items
            }

            if let daily = decoded.daily {
                var dailyItems: [DailyForecast] = []

                let count = daily.time.count
                // Inizia dall'indice 1 (domani) per saltare oggi, prendi fino a 5 giorni
                let startIndex = 1
                let endIndex = min(startIndex + 5, count)

                for i in startIndex..<endIndex {
                    let label =
                        dayInputFormatter.date(from: daily.time[i]).map {
                            outputDayFormatter.string(from: $0)
                        } ?? daily.time[i]
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

    private func geocodeCityNameOpenMeteo(_ name: String) async -> (CLLocation, String)? {
        // Encodifica il nome città per l'URL
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }

        let preferredLanguageCode =
            Locale.preferredLanguages.first?
            .split(separator: "-")
            .first
            .map(String.init) ?? "it"

        let urlString =
            "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedName)&count=1&language=\(preferredLanguageCode)&format=json"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)

            if let result = decoded.results?.first {
                let location = CLLocation(latitude: result.latitude, longitude: result.longitude)
                // Costruisci un nome descrittivo, es: "Milano, Lombardia"
                let displayName = result.name
                /*
                if let admin = result.admin1, !admin.isEmpty {
                    displayName += ", \(admin)"
                }
                 */
                return (location, displayName)
            }
        } catch {
            print("Open-Meteo Geocoding failed: \(error)")
        }

        return nil
    }

    // MARK: - Continuazione posizione
    private var locationRequestContinuations: [CheckedContinuation<CLLocation?, Never>] = []

    deinit {
        timer?.invalidate()
    }
}

extension WeatherModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if self.useManualCity { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                await self.refresh()
            case .denied, .restricted:
                await self.fetchDefaultCityWeather()
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            if let loc = locations.last {
                let hadPendingContinuations = !self.locationRequestContinuations.isEmpty
                self.locationRequestContinuations.forEach { $0.resume(returning: loc) }
                self.locationRequestContinuations.removeAll()
                if self.useManualCity { return }
                if !hadPendingContinuations {
                    await self.fetchWeather(for: loc)
                }
            } else {
                self.locationRequestContinuations.forEach { $0.resume(returning: nil) }
                self.locationRequestContinuations.removeAll()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            #if DEBUG
                print("Location error: \(error)")
            #endif
            self.locationRequestContinuations.forEach { $0.resume(returning: nil) }
            self.locationRequestContinuations.removeAll()
        }
    }
}
