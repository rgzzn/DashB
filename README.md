# DashB ✨

**DashB** è una dashboard moderna in stile *bento* pensata per trasformare la tua AppleTV in un centro di controllo elegante: meteo, calendario e notizie in un’unica vista pulita e immersiva.  
Progettata con SwiftUI, ha un look premium, animazioni morbide e un focus sulla leggibilità da lontano.

---

## 🌟 Highlights

- **Meteo intelligente** con WeatherKit e aggiornamento automatico.
- **Agenda giornaliera** con eventi da Google Calendar e Microsoft Outlook.
- **Ticker notizie** da feed RSS locali, con immagini e QR code per leggere l’articolo completo.
- **Impostazioni rapide** per personalizzare nome, città e account.
- **Design TV‑friendly** con componenti grandi, contrasto elevato e layout bento.

---

## 🧩 Funzionalità principali

- **Dashboard centrale** con saluto personalizzato e orologio.
- **Meteo**: condizioni attuali, previsioni orarie e a 5 giorni.
- **Agenda**: eventi di giornata, all‑day e con orario.
- **Notizie**: rotazione automatica, immagini e QR code per aprire al volo le notizie.
- **Account**: accesso rapido a Google/Outlook con selezione calendari.

---

## 🛠️ Stack tecnologico

- **SwiftUI** per l’interfaccia
- **WeatherKit** per il meteo
- **OAuth Device Flow** per l’accesso a Google e Microsoft
- **Keychain** per la gestione sicura dei token
- **RSS** per le notizie

---

## ✅ Requisiti

- **Xcode 15+**
- **Swift 5.9+**
- Account **Apple Developer** abilitato a **WeatherKit**
- Connessione internet attiva

---

## 🚀 Avvio rapido

1. Apri il progetto in Xcode:
   ```bash
   open DashB.xcodeproj
   ```
2. Seleziona il target (iOS, macOS o tvOS compatibile).
3. Avvia l’app con **Run ▶︎**.

---

## ⚙️ Configurazione servizi

### WeatherKit
L’app utilizza WeatherKit. Assicurati che l’entitlement sia attivo e che il profilo di provisioning includa **com.apple.developer.weatherkit**.

### Google Calendar / Outlook
Le integrazioni usano il **Device Flow** OAuth.  
Per produzione è consigliato sostituire le credenziali presenti nei servizi con le proprie:

- `DashB/Services/GoogleCalendarService.swift`
- `DashB/Services/OutlookCalendarService.swift`

---

## 📰 Fonti notizie (RSS)
Le fonti sono configurate nel modello RSS e possono essere personalizzate:

- `DashB/Models/RSSModel.swift`

---

## 🗺️ Roadmap (idee)

- Widget configurabili (musica, traffico, To‑Do)
- Modalità *focus* per fullscreen content
- Tema chiaro/scuro automatico

---

## 📸 Anteprima

> *Aggiungi qui screenshot e/o GIF della dashboard.*

---

## 👤 Autore

Creato da **Luca Ragazzini**.

---

Se vuoi migliorare DashB o contribuire, sei il benvenuto! 💙

## 🔐 Privacy
Per dettagli su dati trattati, finalità e retention locale: `PRIVACY.md`.
