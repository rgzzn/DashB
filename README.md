# DashB ✨

**DashB** è una dashboard moderna in stile *bento* pensata per trasformare uno schermo (iPad, Mac o Apple TV) in un centro di controllo elegante: meteo, calendario e notizie in un’unica vista pulita e immersiva.  
Progettata con SwiftUI, ha un look premium, animazioni morbide e un focus sulla leggibilità da lontano.

---

## 🌟 Highlights

- **Meteo intelligente** con WeatherKit, GPS o città manuale, e aggiornamento automatico.
- **Agenda giornaliera** da Google Calendar e Microsoft Outlook con colori personalizzati.
- **Ticker notizie** da feed RSS locali, immagini e QR code per leggere l’articolo completo.
- **Impostazioni rapide** per profilo, meteo, account e fonti RSS.
- **Design TV‑friendly** con componenti grandi, contrasto elevato e layout bento.

---

## 🧩 Funzionalità principali

- **Dashboard centrale** con saluto personalizzato, suggerimenti meteo e orologio.
- **Meteo**: condizioni attuali, previsioni orarie e a 5 giorni, GPS o città manuale.
- **Agenda**: eventi di giornata, all‑day e con orario, raggruppati per data.
- **Calendari**: login Device Flow con QR/code, multi‑account Google/Outlook.
- **Selezione calendari** con colore per evento e auto‑attivazione iniziale.
- **Notizie**: rotazione automatica, immagini (Open Graph) e QR code per leggere al volo.
- **Gestione RSS**: aggiungi/rimuovi fonti e ripristino default.
- **Azioni rapide**: aggiorna calendari e RSS con un tap.

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
 - Permessi di **localizzazione** (solo se usi il meteo GPS)

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

Note:
- Su **tvOS** non è disponibile la posizione utente: di default si usa una città manuale e, se WeatherKit fallisce, viene usato **Open‑Meteo** come fallback.
- In **Simulator** (DEBUG), se WeatherKit non risponde, vengono mostrati **dati meteo mock**.

### Google Calendar / Outlook
Le integrazioni usano il **Device Flow** OAuth.  
Per produzione è consigliato sostituire le credenziali presenti nei servizi con le proprie:

- `DashB/Services/GoogleCalendarService.swift`
- `DashB/Services/OutlookCalendarService.swift`

---

## 📰 Fonti notizie (RSS)
Le fonti sono configurate nel modello RSS e possono essere personalizzate:

- `DashB/Models/RSSModel.swift`

Puoi anche gestirle dalla UI (aggiunta, rimozione e reset default).

---

## ⏱️ Aggiornamenti automatici

- **Meteo**: refresh ogni 15 minuti
- **Notizie RSS**: refresh ogni 15 minuti
- **Calendari**: refresh ogni 5 minuti

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
