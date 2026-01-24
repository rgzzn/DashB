//
//  CalendarService.swift
//  DashB
//
//  Created by Luca Ragazzini on 20/01/26.
//

import Combine
import Foundation
import SwiftUI

struct DashboardEvent: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    var color: Color
    let calendarID: String
    let isAllDay: Bool
}

struct CalendarInfo: Identifiable, Codable {
    let id: String
    let name: String
    var colorHex: String?
}

struct DeviceAuthInfo {
    let userCode: String
    let verificationUri: String
    let deviceCode: String
    let expiresIn: Int
    let interval: Int

    var qrCodeUrl: URL? {
        URL(string: verificationUri)
    }
}

protocol CalendarService: ObservableObject, Identifiable {
    var id: String { get }
    var isConnected: Bool { get }
    var serviceName: String { get }

    func startDeviceAuth() async throws -> DeviceAuthInfo
    func pollForToken(deviceCode: String, interval: Int) async throws -> Bool
    func logout()
    func fetchAvailableCalendars() async throws -> [CalendarInfo]
    func fetchEvents(for calendarIDs: [String]) async throws -> [DashboardEvent]
}

extension CalendarService {
    var id: String { serviceName }
}
