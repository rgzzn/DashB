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
    @StateObject private var rssModel = RSSModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weatherModel)
                .environmentObject(calendarManager)
                .environmentObject(rssModel)
        }
    }
}
