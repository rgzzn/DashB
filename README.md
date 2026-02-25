# DashB

DashB trasforma Apple TV in una dashboard TV-first con meteo, calendario e notizie in una singola UI SwiftUI ad alta leggibilità.

## Download
- App Store: https://apps.apple.com/us/app/dashb/id6759085627
- TestFlight: https://testflight.apple.com/join/hBXZH1qd

## Stato attuale del progetto
- Piattaforma target corrente: `tvOS` (`TARGETED_DEVICE_FAMILY = 3`)
- Versione app: `1.0.1` (`CURRENT_PROJECT_VERSION = 2`)
- Deployment target: `tvOS 18.5`

## Funzionalità principali
- Dashboard bento con saluto personalizzato, orologio live e animazioni focus ottimizzate per telecomando.
- Meteo con WeatherKit: condizioni correnti, 4 slot orari e previsioni a 5 giorni.
- Modalità meteo manuale o posizione attuale (su tvOS viene usata città manuale di default).
- Fallback meteo/geocoding via Open-Meteo quando WeatherKit o geocoding Apple falliscono.
- Agenda aggregata Google Calendar + Outlook/Microsoft 365.
- Vista agenda multi-giorno (finestra prossimi 7 giorni) con eventi timed/all-day e location.
- Selezione calendari per account con colore personalizzabile per ogni calendario.
- Notizie RSS con rotazione automatica ogni 10 secondi, immagini e QR code articolo.
- Gestione fonti RSS da UI (aggiunta/rimozione/ripristino default) con validazione URL HTTPS.

## Aggiornamenti automatici
- Meteo: refresh ogni 15 minuti.
- RSS: refresh ogni 15 minuti.
- Calendario: refresh ogni 5 minuti.

## Accesso account calendario
- Autenticazione OAuth Device Flow (Google e Microsoft) con QR code.
- Polling di conferma con gestione timeout/errori user-friendly.
- Token salvati in Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).

## Configurazione richiesta
L’app ora blocca l’avvio dei servizi calendario se mancano chiavi OAuth valide in `Info.plist` e mostra una schermata di configurazione con i campi mancanti.

Chiavi richieste:
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `OUTLOOK_CLIENT_ID`
- `OUTLOOK_TENANT_ID`

Note:
- Placeholder non risolti (es. `$(GOOGLE_CLIENT_ID)`) sono considerati mancanti.
- WeatherKit richiede entitlement `com.apple.developer.weatherkit`.

## Avvio rapido
```bash
open DashB.xcodeproj
```
1. Apri il progetto in Xcode.
2. Imposta i valori OAuth nelle Build Settings/Info.plist del target.
3. Esegui su Apple TV o simulatore tvOS compatibile.

## Struttura utile
- `DashB/Core/Config.swift`: validazione chiavi OAuth.
- `DashB/Services/CalendarManager.swift`: aggregazione eventi e refresh.
- `DashB/Services/GoogleCalendarService.swift`: OAuth Device Flow Google + API Calendar.
- `DashB/Services/OutlookCalendarService.swift`: OAuth Device Flow Microsoft + Graph API.
- `DashB/Models/WeatherModel.swift`: WeatherKit + fallback Open-Meteo.
- `DashB/Models/RSSModel.swift`: fetch/parsing RSS + enrichment immagini.
- `DashB/Views/SettingsView.swift`: gestione profilo, meteo, account, RSS.

## Autore
Creato da Luca Ragazzini.
