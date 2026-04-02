# DashB

DashB turns Apple TV into a TV-first dashboard with weather, calendar, and news in a single high-readability SwiftUI interface.

## Download
- App Store: https://apps.apple.com/us/app/dashb/id6759085627
- TestFlight: https://testflight.apple.com/join/hBXZH1qd

## Current Project Status
- Current target platform: `tvOS` (`TARGETED_DEVICE_FAMILY = 3`)
- App version: `2.0` (`CURRENT_PROJECT_VERSION = 1`)
- Deployment target: `tvOS 18.5`

## Key Features
- Bento-style dashboard with personalized greeting, live clock, and remote-optimized focus animations.
- Weather with WeatherKit: current conditions, 4 hourly slots, and a 5-day forecast.
- Manual weather mode or current location (on tvOS, manual city is used by default).
- Weather/geocoding fallback via Open-Meteo when WeatherKit or Apple geocoding fails.
- Aggregated agenda from Google Calendar + Outlook/Microsoft 365.
- Multi-day agenda view (next 7 days window) with timed/all-day events and location.
- Per-account calendar selection with customizable color for each calendar.
- RSS news with automatic rotation every 10 seconds, images, and article QR code.
- RSS sources managed from the UI (add/remove/restore defaults) with HTTPS URL validation.

## What's New
- Italian and English localization across core screens, with dedicated strings for both languages.
- Restyled News Settings screen with improved tvOS focus behavior and smoother remote interactions.
- UI fluidity improvements with cancellation of redundant refresh tasks for weather, calendar, and news.
- More robust weather handling with request tracking and more reliable update management.
- New OAuth secret handling via `DashB/Config/Secrets.xcconfig` (local file ignored by Git).
- Updated icons and App Store/Top Shelf assets aligned with product branding.

## Automatic Updates
- Weather: refresh every 15 minutes.
- RSS: refresh every 15 minutes.
- Calendar: refresh every 5 minutes.

## Calendar Account Access
- OAuth Device Flow authentication (Google and Microsoft) with QR code.
- Confirmation polling with user-friendly timeout/error handling.
- Tokens stored in Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).

## Required Configuration
The app now blocks calendar service startup when valid OAuth keys are missing in `Info.plist`, and shows a configuration screen with missing fields.

Required keys:
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `OUTLOOK_CLIENT_ID`
- `OUTLOOK_TENANT_ID`

Notes:
- Unresolved placeholders (for example `$(GOOGLE_CLIENT_ID)`) are treated as missing.
- WeatherKit requires the `com.apple.developer.weatherkit` entitlement.

## Quick Start
```bash
open DashB.xcodeproj
```
1. Open the project in Xcode.
2. Create the local secrets file:
```bash
cp DashB/Config/Secrets.example.xcconfig DashB/Config/Secrets.xcconfig
```
3. Add real OAuth values in `DashB/Config/Secrets.xcconfig`.
4. Run on Apple TV or a compatible tvOS simulator.

`DashB/Config/Secrets.xcconfig` is ignored by Git and is not pushed to GitHub.

## Useful Structure
- `DashB/Core/Config.swift`: OAuth key validation.
- `DashB/Services/CalendarManager.swift`: event aggregation and refresh.
- `DashB/Services/GoogleCalendarService.swift`: Google OAuth Device Flow + Calendar API.
- `DashB/Services/OutlookCalendarService.swift`: Microsoft OAuth Device Flow + Graph API.
- `DashB/Models/WeatherModel.swift`: WeatherKit + Open-Meteo fallback.
- `DashB/Models/RSSModel.swift`: RSS fetch/parsing + image enrichment.
- `DashB/Views/SettingsView.swift`: profile, weather, account, and RSS management.

## Author
Created by Luca Ragazzini.
