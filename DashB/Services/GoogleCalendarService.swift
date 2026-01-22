//
//  GoogleCalendarService.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation
import SwiftUI

class GoogleCalendarService: NSObject, CalendarService {
    @Published var isConnected: Bool = false
    let serviceName = "Google Calendar"

    // MARK: - Configuration
    private let clientID =
        "312785097359-987aqfia9t8m2ct6vurt36el99o0hl48.apps.googleusercontent.com"
    private let clientSecret = "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"
    private let scope = "https://www.googleapis.com/auth/calendar.readonly"

    private let deviceAuthEndpoint = "https://oauth2.googleapis.com/device/code"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"

    // Keychain Keys
    private let keychainService = "DashB.Google"
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

    // MARK: - Auth Flow

    func startDeviceAuth() async throws -> DeviceAuthInfo {
        guard let url = URL(string: deviceAuthEndpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Unreserved characters for x-www-form-urlencoded
        var charSet = CharacterSet.alphanumerics
        charSet.insert(charactersIn: "-._~")

        let encodedClientID = clientID.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedClientSecret =
            clientSecret.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""

        let bodyString =
            "client_id=\(encodedClientID)&client_secret=\(encodedClientSecret)&scope=\(encodedScope)"
        let bodyData = bodyString.data(using: .utf8)
        request.httpBody = bodyData
        request.setValue("\(bodyData?.count ?? 0)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpRes = response as? HTTPURLResponse {
            print("DEBUG: Google Auth Response Status: \(httpRes.statusCode)")
            if let string = String(data: data, encoding: .utf8) {
                print("DEBUG: Google Auth Response Body: \(string)")
            }
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let userCode = json["user_code"] as? String,
                let deviceCode = json["device_code"] as? String,
                let verUri = json["verification_url"] as? String
            {

                let finalUri = json["verification_url_complete"] as? String ?? verUri
                return DeviceAuthInfo(
                    userCode: userCode,
                    verificationUri: finalUri,
                    deviceCode: deviceCode,
                    expiresIn: json["expires_in"] as? Int ?? 1800,
                    interval: json["interval"] as? Int ?? 5
                )
            } else if let error = json["error"] as? String {
                let desc = json["error_description"] as? String ?? error
                throw NSError(
                    domain: "Google", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Errore Google: \(desc)"])
            }
        }
        throw URLError(.cannotParseResponse)
    }

    func pollForToken(deviceCode: String, interval: Int) async throws -> Bool {
        guard let url = URL(string: tokenEndpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var charSet = CharacterSet.alphanumerics
        charSet.insert(charactersIn: "-._~")

        let encodedClientID = clientID.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedClientSecret =
            clientSecret.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedDeviceCode =
            deviceCode.addingPercentEncoding(withAllowedCharacters: charSet) ?? ""
        let encodedGrantType =
            "urn:ietf:params:oauth:grant-type:device_code".addingPercentEncoding(
                withAllowedCharacters: charSet) ?? ""

        let bodyString =
            "client_id=\(encodedClientID)&client_secret=\(encodedClientSecret)&device_code=\(encodedDeviceCode)&grant_type=\(encodedGrantType)"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("\(request.httpBody?.count ?? 0)", forHTTPHeaderField: "Content-Length")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        if httpResponse?.statusCode == 200 {
            if let accessToken = json["access_token"] as? String {
                try KeychainHelper.shared.save(
                    accessToken, service: keychainService, account: accessTokenKey)
                if let refreshToken = json["refresh_token"] as? String {
                    try KeychainHelper.shared.save(
                        refreshToken, service: keychainService, account: refreshTokenKey)
                }

                // Allow Keychain to sync
                try? await Task.sleep(nanoseconds: 200_000_000)

                await MainActor.run { self.isConnected = true }
                return true
            }
        } else if let error = json["error"] as? String {
            if error == "authorization_pending" || error == "slow_down" { return false }
            let desc = json["error_description"] as? String ?? error
            throw NSError(
                domain: "Google", code: httpResponse?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: desc])
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

        let encodedClientID =
            clientID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let encodedClientSecret =
            clientSecret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let encodedRefreshToken =
            refresh.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""

        let body =
            "client_id=\(encodedClientID)&client_secret=\(encodedClientSecret)&refresh_token=\(encodedRefreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access = json["access_token"] as? String
            {
                try KeychainHelper.shared.save(
                    access, service: keychainService, account: accessTokenKey)
                return true
            }
        }
        return false
    }

    func logout() {
        KeychainHelper.shared.delete(service: keychainService, account: accessTokenKey)
        KeychainHelper.shared.delete(service: keychainService, account: refreshTokenKey)
        DispatchQueue.main.async { self.isConnected = false }
    }

    // MARK: - Fetching

    func fetchAvailableCalendars() async throws -> [CalendarInfo] {
        guard
            let accessToken = KeychainHelper.shared.read(
                service: keychainService, account: accessTokenKey)
        else {
            throw URLError(.userAuthenticationRequired)
        }

        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")
        else {
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
            let items = json["items"] as? [[String: Any]]
        {
            for item in items {
                if let id = item["id"] as? String,
                    let summary = item["summary"] as? String
                {
                    calendars.append(CalendarInfo(id: id, name: summary))
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

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startOfDay)

        let encodedCalendarID =
            calendarID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "primary"
        let urlString =
            "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendarID)/events?orderBy=startTime&singleEvents=true&timeMin=\(timeMin)&maxResults=15"

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
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = json["items"] as? [[String: Any]]
        {
            for item in items {
                if let summary = item["summary"] as? String,
                    let startDict = item["start"] as? [String: Any]
                {
                    var date: Date?
                    var isAllDay = false
                    if let dt = startDict["dateTime"] as? String {
                        date = formatter.date(from: dt)
                        isAllDay = false
                    } else if let d = startDict["date"] as? String {
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        date = df.date(from: d)
                        isAllDay = true
                    }
                    let location = item["location"] as? String
                    if let d = date {
                        events.append(
                            DashboardEvent(
                                title: summary, startDate: d, location: location, color: .red,
                                calendarID: calendarID, isAllDay: isAllDay))
                    }
                }
            }
        }
        return events
    }
}
