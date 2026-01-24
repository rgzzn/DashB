//
//  DashBApp.swift
//  DashB
//
//  Creato da Luca Ragazzini il 20/01/26.
//

import SwiftData
import SwiftUI

@main
struct DashBApp: App {
    @StateObject private var weatherModel = WeatherModel()
    @StateObject private var calendarManager = CalendarManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weatherModel)
                .environmentObject(calendarManager)
        }
    }
}
