//
//  WeatherModel.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import CoreLocation
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
            Task { await self.refresh() }
        }
    }

    private static let cityDefaultsKey = "WeatherModel.selectedCity"
    private static let useManualCityDefaultsKey = "WeatherModel.useManualCity"
    private let geocoder = CLGeocoder()
    private let defaultCity = "Forlì"
    private var cachedManualCity: String?
    private var cachedManualLocation: CLLocation?
    private var cachedManualCityName: String?

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let openMeteoInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let openMeteoDayInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @Published var currentTemp: String = "--°"
    @Published var conditionIcon: String = "cloud.fill"
    @Published var conditionDescription: String = "--"
    @Published var hourlyForecast: [Forecast] = []
    @Published var dailyForecast: [DailyForecast] = []
    @Published var cityName: String = "Caricamento..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @Published var weatherAdvice: String = "Bentornato nella tua dashboard."

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
                            self.conditionDescription = "Città non trovata"
                            self.weatherAdvice = "Controlla il nome della città."
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
            #endif
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
                    self.conditionDescription = "Città non trovata"
                    self.weatherAdvice = "Controlla il nome della città."
                    self.hourlyForecast = []
                    self.dailyForecast = []
                }
            }
            return
        }

        // Caso 2: Auto / GPS
        #if os(tvOS)
            // tvOS non fornisce CoreLocation; ripiego su una città predefinita
            await fetchDefaultCityWeather()
            return
        #endif

        // Controlla prima i permessi
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
                // In attesa dell'utente...
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

        // Geocodifica inversa per mostrare il nome della città per la posizione GPS
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
            cachedManualCity = nil
            cachedManualLocation = nil
            cachedManualCityName = nil
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
            let shouldRequest = locationRequestContinuations.isEmpty
            locationRequestContinuations.append(continuation)
            if shouldRequest {
                locationManager.requestLocation()
            }
        }
    }

    // Restituisce (Posizione, NomeFormattato)
    private func geocodeCityName(_ name: String) async -> (CLLocation, String)? {
        await withCheckedContinuation { continuation in
            geocoder.geocodeAddressString(name) { placemarks, error in
                if let placemark = placemarks?.first, let location = placemark.location {
                    // Usa località (Città) o nome, ripiego su input utente
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

    // MARK: - Meteo
    private func fetchWeather(for location: CLLocation) async {
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
                self.currentTemp = String(format: "%.0f°", tempC)
                self.conditionIcon = sfSymbol(for: current.symbolName)
                self.conditionDescription = self.descriptionForCondition(current.condition)
                self.weatherAdvice = self.adviceForCondition(current.condition)

                // Previsioni orarie (prossime 4 voci)
                var items: [Forecast] = []

                let hours = hourly.prefix(4)
                for (index, hour) in hours.enumerated() {
                    let label: String
                    if index == 0 {
                        label = "Ora"
                    } else {
                        label = Self.hourFormatter.string(from: hour.date)
                    }
                    let icon = sfSymbol(for: hour.symbolName)
                    let t = hour.temperature.converted(to: .celsius).value
                    items.append(
                        Forecast(time: label, icon: icon, temp: String(format: "%.0f°", t)))
                }
                self.hourlyForecast = items

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
                self.dailyForecast = dailyItems
            } else {
                let weather = try await weatherService.weather(for: cleanLocation)

                // Current conditions
                let tempC = weather.currentWeather.temperature.converted(to: .celsius).value
                self.currentTemp = String(format: "%.0f°", tempC)
                self.conditionIcon = sfSymbol(for: weather.currentWeather.symbolName)
                self.conditionDescription = self.descriptionForCondition(
                    weather.currentWeather.condition)
                self.weatherAdvice = self.adviceForCondition(weather.currentWeather.condition)

                // Hourly forecast (next 4 entries)
                var items: [Forecast] = []

                let hours = weather.hourlyForecast.prefix(4)
                for (index, hour) in hours.enumerated() {
                    let label: String
                    if index == 0 {
                        label = "Ora"
                    } else {
                        label = Self.hourFormatter.string(from: hour.date)
                    }
                    let icon = sfSymbol(for: hour.symbolName)
                    let t = hour.temperature.converted(to: .celsius).value
                    items.append(
                        Forecast(time: label, icon: icon, temp: String(format: "%.0f°", t)))
                }
                self.hourlyForecast = items

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
                self.dailyForecast = dailyItems
            }
        } catch {
            print("Weather fetch failed: \(error)")
            self.currentTemp = "Err"
            self.conditionIcon = "exclamationmark.triangle.fill"
            self.conditionDescription = "Errore"
            self.weatherAdvice = "Impossibile recuperare il meteo."

            self.cityName = userFacingWeatherErrorMessage(for: error)
            #if targetEnvironment(simulator)
                // Nel Simulatore, mostra sempre dati finti se WeatherKit fallisce
                self.applyMockWeather()
            #endif
            #if os(tvOS)
                // Su tvOS, ripiego su Open-Meteo se WeatherKit fallisce per mostrare comunque dati reali
                await fetchWeatherFromOpenMeteo(for: cleanLocation)
                if self.cityName.hasPrefix("Err")
                    || self.cityName.localizedCaseInsensitiveContains("Capab")
                {
                    // Mantieni etichetta città precedente se avevamo impostato un errore
                    self.cityName = previousCityName
                }
            #endif
        }
    }

    private func userFacingWeatherErrorMessage(for error: Error) -> String {
        if error is WeatherError {
            return "Servizio meteo non disponibile"
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return "Errore di rete"
            default:
                return "Connessione non disponibile"
            }
        }

        let technicalDescription = String(describing: error)
        if technicalDescription.localizedCaseInsensitiveContains("WeatherDaemon")
            || technicalDescription.localizedCaseInsensitiveContains("connection")
        {
            return "Servizio meteo momentaneamente non raggiungibile"
        }

        return "Errore meteo temporaneo"
    }

    private func sfSymbol(for symbolName: String) -> String {
        // WeatherKit restituisce già un nome compatibile con SF Symbol; ripiego su predefinito se vuoto
        return symbolName.isEmpty ? "cloud.fill" : symbolName
    }

    private func fetchDefaultCityWeather() async {
        #if os(tvOS)
            let location = CLLocation(latitude: 44.2225, longitude: 12.0408)
            self.cityName = "Forlì"
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
            self.weatherAdvice = "Goditi questa bella giornata di sole!"
            let now = Date()
            let times = [
                now, now.addingTimeInterval(3600), now.addingTimeInterval(7200),
                now.addingTimeInterval(10800),
            ]
            var items: [Forecast] = []
            for (index, t) in times.enumerated() {
                let label = index == 0 ? "Ora" : Self.hourFormatter.string(from: t)
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
            if self.cityName.isEmpty || self.cityName.hasPrefix("Err") {
                self.cityName = "Dati di esempio"
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
        case .blizzard: return "Bufera di neve"
        case .frigid: return "Gelo intenso"
        case .hot: return "Caldo intenso"
        case .hurricane: return "Uragano"
        case .smoky: return "Fumosità"
        case .sunFlurries: return "Raffiche di neve con sole"
        case .sunShowers: return "Piovaschi con sole"
        case .tropicalStorm: return "Tempesta tropicale"
        case .wintryMix: return "Misto invernale"
        @unknown default: return "Sconosciuto"
        }
    }

    private func adviceForCondition(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear, .partlyCloudy:
            return "Una bella giornata! Goditi il sole."
        case .cloudy, .mostlyCloudy:
            return "Il cielo è un po' grigio oggi."
        case .foggy, .haze:
            return "Attenzione alla visibilità ridotta."
        case .breezy, .windy:
            return "Oggi tira vento, copriti bene!"
        case .drizzle, .rain, .heavyRain:
            return "Oggi piove, non dimenticare l'ombrello!"
        case .snow, .heavySnow, .flurries, .blowingSnow, .sleet, .freezingDrizzle, .freezingRain:
            return "Fa freddo e nevica, copriti bene!"
        case .hail:
            return "Attenzione alla grandine!"
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return "Ci sono temporali, meglio stare al coperto."
        case .blowingDust:
            return "Attenzione alla polvere nell'aria."
        case .blizzard:
            return "Bufera di neve: evita spostamenti se possibile."
        case .frigid:
            return "Freddo intenso: copriti molto bene."
        case .hot:
            return "Caldo intenso: resta idratato e evita le ore più calde."
        case .hurricane:
            return "Uragano in corso: segui le indicazioni delle autorità."
        case .smoky:
            return "Aria fumosa: limita le attività all'aperto."
        case .sunFlurries:
            return "Raffiche di neve con schiarite: attenzione alla strada."
        case .sunShowers:
            return "Piovaschi con schiarite: porta con te un ombrello."
        case .tropicalStorm:
            return "Tempesta tropicale: resta al coperto e informato."
        case .wintryMix:
            return "Misto invernale: possibile ghiaccio, guida con cautela."
        @unknown default:
            return "Bentornato nella tua dashboard."
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
            return "Una bella giornata! Goditi il sole."
        case 3:
            return "Il cielo è coperto oggi."
        case 45, 48:
            return "Attenzione alla nebbia."
        case 51...67, 80...82:
            return "Giornata di pioggia, ricorda l'ombrello!"
        case 71...77, 85...86:
            return "Nevica! Copriti bene se esci."
        case 95...99:
            return "Temporali in corso, attenzione."
        default:
            return "Bentornato nella tua dashboard."
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
                self.weatherAdvice = self.adviceFromWeatherCode(current.weathercode)
            }

            if let hourly = decoded.hourly {
                // Open-Meteo restituisce l'ora nel formato "yyyy-MM-ddTHH:mm" (tipo ISO8601 ma semplice)
                let now = Date()
                var startIndex = 0
                for (idx, ts) in hourly.time.enumerated() {
                    // Prova a trovare il primo slot temporale che è >= adesso (o vicino)
                    if let d = Self.openMeteoInputFormatter.date(from: ts),
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
                        label = "Ora"
                    } else if let date = Self.openMeteoInputFormatter.date(from: rawTime) {
                        label = Self.hourFormatter.string(from: date)
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
                        Self.openMeteoDayInputFormatter.date(from: daily.time[i]).map {
                            Self.dayFormatter.string(from: $0)
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

        let urlString =
            "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedName)&count=1&language=it&format=json"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)

            if let result = decoded.results?.first {
                let location = CLLocation(latitude: result.latitude, longitude: result.longitude)
                // Costruisci un nome descrittivo, es: "Milano, Lombardia"
                var displayName = result.name
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
                manager.requestLocation()
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
                self.locationRequestContinuations.forEach { $0.resume(returning: loc) }
                self.locationRequestContinuations.removeAll()
                await self.fetchWeather(for: loc)
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
