//
//  OutlookCalendarService.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation
import SwiftUI

class OutlookCalendarService: NSObject, CalendarService {
    @Published var isConnected: Bool = false
    let serviceName = "Outlook / Microsoft 365"

    // MARK: - Configurazione
    private let clientID = "60f1d70e-d828-4638-b3d0-61588d393a4e"
    private let clientSecret = "Iw88Q~bTf4vSaS370Q6StvV1n~ClxvzGdHqCc-Sr"
    private let tenantID = "f53380d6-48f1-4cde-a11f-015ed6f5e159"
    private let scope = "Calendars.Read User.Read offline_access"

    private var deviceAuthEndpoint: String {
        "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/devicecode"
    }
    private var tokenEndpoint: String {
        "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/token"
    }

    // Chiavi Keychain
    private let keychainService = "DashB.Outlook"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"

    override init() {
        super.init()
        checkConnectionStatus()
    }

    private func checkConnectionStatus() {
        if KeychainHelper.shared.read(service: keychainService, account: accessTokenKey) != nil {
            DispatchQueue.main.async {
                self.isConnected = true
            }
        }
    }

    // MARK: - Autenticazione Flusso Dispositivo

    func startDeviceAuth() async throws -> DeviceAuthInfo {
        guard let url = URL(string: deviceAuthEndpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let charSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedClientID = clientID.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedSecret = clientSecret.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""

        // Reinserito il segreto e il Tenant ID specifico come richiesto da Azure per app aziendali
        let bodyString =
            "client_id=\(encodedClientID)&scope=\(encodedScope)&client_secret=\(encodedSecret)"
        let bodyData = bodyString.data(using: .utf8)
        request.httpBody = bodyData
        request.setValue("\(bodyData?.count ?? 0)", forHTTPHeaderField: "Content-Length")

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let userCode = json["user_code"] as? String,
                let deviceCode = json["device_code"] as? String,
                let verificationUri = json["verification_uri"] as? String
            {
                let expiresIn = json["expires_in"] as? Int ?? 1800
                let interval = json["interval"] as? Int ?? 5

                return DeviceAuthInfo(
                    userCode: userCode,
                    verificationUri: verificationUri,
                    deviceCode: deviceCode,
                    expiresIn: expiresIn,
                    interval: interval
                )
            } else if let errorDescription = json["error_description"] as? String {
                throw NSError(
                    domain: "OutlookCalendar", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errorDescription])
            }
        }

        throw URLError(.cannotParseResponse)
    }

    func pollForToken(deviceCode: String, interval: Int) async throws -> Bool {
        guard let url = URL(string: tokenEndpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let charSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedGrantType =
            "urn:ietf:params:oauth:grant-type:device_code".addingPercentEncoding(
                withAllowedCharacters: charSet) ?? ""
        let encodedClientID = clientID.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedDeviceCode =
            deviceCode.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedSecret = clientSecret.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""

        let bodyString =
            "grant_type=\(encodedGrantType)&client_id=\(encodedClientID)&device_code=\(encodedDeviceCode)&client_secret=\(encodedSecret)"
        let bodyData = bodyString.data(using: .utf8)
        request.httpBody = bodyData
        request.setValue("\(bodyData?.count ?? 0)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let accessToken = json["access_token"] as? String
                {

                    try KeychainHelper.shared.save(
                        accessToken, service: keychainService, account: accessTokenKey)
                    if let refreshToken = json["refresh_token"] as? String {
                        try KeychainHelper.shared.save(
                            refreshToken, service: keychainService, account: refreshTokenKey)
                    }

                    // Piccolo ritardo per sincronizzazione Keychain
                    try? await Task.sleep(nanoseconds: 200_000_000)

                    await MainActor.run {
                        self.isConnected = true
                    }
                    return true
                }
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let error = json["error"] as? String
            {
                if error == "authorization_pending" || error == "slow_down" { return false }
                let desc = json["error_description"] as? String ?? error
                throw NSError(
                    domain: "Outlook", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: desc])
            }
        }

        return false
    }

    func refreshToken() async throws -> Bool {
        guard
            let refresh = KeychainHelper.shared.read(
                service: keychainService, account: refreshTokenKey),
            let url = URL(string: tokenEndpoint)
        else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let charSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedClientID = clientID.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedRefresh = refresh.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedGrantType =
            "refresh_token".addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedSecret = clientSecret.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""

        let body =
            "client_id=\(encodedClientID)&refresh_token=\(encodedRefresh)&grant_type=\(encodedGrantType)&scope=\(encodedScope)&client_secret=\(encodedSecret)"
        let bodyData = body.data(using: .utf8)
        request.httpBody = bodyData
        request.setValue("\(bodyData?.count ?? 0)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access = json["access_token"] as? String
            {
                try KeychainHelper.shared.save(
                    access, service: keychainService, account: accessTokenKey)
                if let newRefresh = json["refresh_token"] as? String {
                    try KeychainHelper.shared.save(
                        newRefresh, service: keychainService, account: refreshTokenKey)
                }
                return true
            }
        }
        return false
    }

    func logout() {
        KeychainHelper.shared.delete(service: keychainService, account: accessTokenKey)
        KeychainHelper.shared.delete(service: keychainService, account: refreshTokenKey)
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }

    // MARK: - Recupero Eventi

    func fetchAvailableCalendars() async throws -> [CalendarInfo] {
        guard
            let accessToken = KeychainHelper.shared.read(
                service: keychainService, account: accessTokenKey)
        else {
            throw URLError(.userAuthenticationRequired)
        }

        guard let url = URL(string: "https://graph.microsoft.com/v1.0/me/calendars") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            if try await refreshToken() {
                return try await fetchAvailableCalendars()
            }
            throw URLError(.userAuthenticationRequired)
        }

        var calendars: [CalendarInfo] = []
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["value"] as? [[String: Any]]
        {
            for item in items {
                if let id = item["id"] as? String,
                    let name = item["name"] as? String
                {
                    calendars.append(CalendarInfo(id: id, name: name))
                }
            }
        }
        return calendars
    }

    func fetchEvents(for calendarIDs: [String]) async throws -> [DashboardEvent] {
        var allEvents: [DashboardEvent] = []

        for calendarID in calendarIDs {
            let events = try await fetchEventsForSingleCalendar(calendarID)
            allEvents.append(contentsOf: events)
        }

        return allEvents
    }

    private func fetchEventsForSingleCalendar(_ calendarID: String) async throws -> [DashboardEvent]
    {
        guard
            let accessToken = KeychainHelper.shared.read(
                service: keychainService, account: accessTokenKey)
        else {
            throw URLError(.userAuthenticationRequired)
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startOfDay)

        let endRange =
            calendar.date(byAdding: .day, value: 3, to: startOfDay)
            ?? startOfDay.addingTimeInterval(86400 * 3)
        let timeMax = formatter.string(from: endRange)

        let encodedID =
            calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"
        // Outlook usa ISO 8601 string per il filtro
        let urlString =
            "https://graph.microsoft.com/v1.0/me/calendars/\(encodedID)/events?$filter=start/dateTime ge '\(timeMin)' and start/dateTime le '\(timeMax)'&$orderby=start/dateTime&$top=100"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            if try await refreshToken() {
                return try await fetchEventsForSingleCalendar(calendarID)
            }
            throw URLError(.userAuthenticationRequired)
        }

        var events: [DashboardEvent] = []

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["value"] as? [[String: Any]]
        {
            for item in items {
                if let subject = item["subject"] as? String,
                    let startDict = item["start"] as? [String: Any],
                    let dateTime = startDict["dateTime"] as? String
                {
                    let locationDict = item["location"] as? [String: Any]
                    let locationName = locationDict?["displayName"] as? String
                    let isAllDay = item["isAllDay"] as? Bool ?? false

                    let isoFormatter = ISO8601DateFormatter()
                    if let date = isoFormatter.date(from: dateTime) ?? fallbackDate(from: dateTime)
                    {
                        var endDate: Date?
                        if let endDict = item["end"] as? [String: Any],
                            let endDateTime = endDict["dateTime"] as? String
                        {
                            endDate =
                                isoFormatter.date(from: endDateTime)
                                ?? fallbackDate(from: endDateTime)
                        }

                        let finalEndDate = endDate ?? date

                        events.append(
                            DashboardEvent(
                                title: subject, startDate: date, endDate: finalEndDate,
                                location: locationName,
                                color: .blue, calendarID: calendarID, isAllDay: isAllDay))
                    }
                }
            }
        }

        return events
    }

    private func fallbackDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        return formatter.date(from: string)
    }
}
