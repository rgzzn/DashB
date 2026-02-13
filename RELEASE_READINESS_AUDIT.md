# DashB — Audit pre-rilascio v1 (App Store)

Data audit: 2026-02-13  
Scope: analisi statica codice + configurazioni progetto (stabilità, sicurezza, UX/UI, performance, compliance store).

## Executive summary

**Stato complessivo:** ⚠️ **Non pronto al rilascio immediato** senza hardening mirato.

Punti forti:
- Architettura SwiftUI pulita con separazione per domini (weather/calendar/rss).
- Uso di Keychain per token OAuth.
- Fallback meteo su tvOS quando WeatherKit fallisce.

Blocchi principali pre-store:
1. **Crash hard** in assenza di variabili OAuth (`fatalError` in `Config`).
2. **Leak informativo nei log** durante auth Google (stampa body completo risposta).
3. **Input RSS utente non validato/sanitizzato** (URL arbitrari, rischio traffico inatteso/instabilità).
4. **Mancanza test automatici e impossibilità di build CI verificata in questo ambiente**.

---

## Metodologia

Verifiche eseguite:
- Revisione file core app, servizi OAuth, modelli dati, viste principali.
- Ricerca pattern a rischio (`fatalError`, `print`, endpoint, fallback, timer).
- Verifica impostazioni plist/entitlements/progetto.

Limiti audit:
- In questo ambiente non è disponibile `xcodebuild`, quindi non è stato possibile validare build/test runtime.

---

## 1) Stabilità & affidabilità

### 1.1 Rischi critici

- **Crash a startup per config mancante**: `Config` usa `fatalError` per ogni chiave OAuth. In produzione un errore di configurazione/provisioning chiude l’app.  
  **Priorità:** P0.

### 1.2 Rischi alti

- **Timer non conservato** in `CalendarManager`: viene creato con `Timer.scheduledTimer` ma non mantenuto/invalido in `deinit`; rischio di lifecycle non controllato in evoluzioni future.  
  **Priorità:** P1.

- **Retry auth ricorsivo** in servizi calendario (refresh + recall): funziona ma senza limite esplicito di tentativi; in edge case può produrre cicli ripetuti.  
  **Priorità:** P1.

### 1.3 Rischi medi

- Diverse chiamate rete usano parsing JSON permissivo (`try?`) con fallback silenziosi: riduce crash ma maschera errori API e complica diagnostica.
- Stato errore in meteo con stringhe utente direttamente da `localizedDescription`: UX disomogenea.

### Raccomandazioni stabilità

- Sostituire `fatalError` con config-safe bootstrap + schermata di errore guidata.
- Introdurre policy retry centralizzata (max tentativi + backoff).
- Aggiungere metriche/error reporting (es. OSLog + telemetria non sensibile).

---

## 2) Sicurezza & privacy

### 2.1 Rischi critici/alti

- **Logging sensibile in auth Google**: stampa status e body completi della risposta device auth. Anche se spesso contiene codici temporanei, non va in log release.  
  **Priorità:** P0.

- **Client secret lato client** (Google/Outlook in app): è comune in alcune integrazioni device flow, ma da considerare comunque esposizione recuperabile via reverse engineering.  
  **Priorità:** P1 (mitigare con app registration/scopes minimi, rotazione, monitoraggio abuso).

- **RSS custom non validato**: l’utente può inserire URL arbitrari, inclusi host non attesi; manca allowlist/scheme hardening (`https` obbligatorio).  
  **Priorità:** P1.

### 2.2 Rischi medi

- Keychain usa `kSecAttrAccessibleAfterFirstUnlock`: ok per background, ma più permissivo di opzioni più restrittive. Verificare requisito reale.
- Mancano policy esplicite su retention/cancellazione dati locali (AppStorage feed/città/calendari selezionati).

### Raccomandazioni sicurezza

- Rimuovere log debug sensibili in release (`#if DEBUG` + redaction).
- Validare URL feed (`https`, host valido, dimensione risposta, timeout stretti).
- Documentare privacy (dati trattati, finalità, retention) e verificare etichette App Privacy in App Store Connect.

---

## 3) UI/UX (tvOS-first)

### Punti positivi

- Layout dashboard leggibile da distanza (tipografia ampia, card chiare).
- Animazioni coerenti e gerarchia visiva buona.
- Device Login con QR + codice molto chiaro per contesto TV.

### Problemi principali

- **Accessibilità non completa**: mancano evidenze di etichette/accessibility modifiers su elementi critici (icone, card, QR context).
- **Gestione errore non unificata**: testi molto tecnici in alcuni stati (“Err ...”, messaggi raw di rete).
- **Input RSS su tvOS**: text field disabilitano focus (`focusable(false)`), possibile frizione forte nell’inserimento da telecomando.

### Raccomandazioni UX

- Standardizzare stati errore (friendly copy + retry + fallback).
- Aggiungere audit accessibilità (VoiceOver labels, contrasto, Dynamic Type dove applicabile).
- Riesaminare UX inserimento feed su tvOS (flow da companion app/QR invece di text input diretto).

---

## 4) Performance & ottimizzazione

### Osservazioni

- Refresh periodici presenti (meteo 15m, calendario 5m, rss 15m): buono per dashboard.
- `RSSModel` arricchisce immagini aprendo pagine articolo (top 12): costo rete/CPU accettabile ma non controllato da cache esplicita.
- Molte animazioni concorrenti in dashboard/news ticker: in generale ok su Apple TV recente, ma da validare su device meno performanti.

### Ottimizzazioni consigliate

- Introdurre cache immagini (NSCache / URLCache configurata) e limite concorrenza fetch OG image.
- Ridurre creazione ripetuta formatter dove possibile nei path caldi UI.
- Profilare con Instruments (Time Profiler + Network + Memory) su sessione reale 2-4 ore.

---

## 5) Compliance App Store (prima submission)

Checklist essenziale prima del submit:
- [ ] Privacy Policy pubblica e linkata.
- [ ] App Privacy labels complete (dati account calendario, diagnostica, identificatori se presenti).
- [ ] Revisione testo marketing/screenshot store.
- [ ] Verifica uso brand/termini Google/Microsoft in metadata.
- [ ] Test login/logout e revoca consenso account.
- [ ] Test offline/poor network (cold start senza internet).

Nota: non risultano permessi location in `Info.plist`; coerente con scelta manuale tvOS, ma va verificata strategia multi-piattaforma indicata nel README.

---

## 6) Piano operativo consigliato (go-live)

### Fase 0 — Bloccanti (1-2 giorni)
1. Rimuovere/stoppare log sensibili OAuth in release.
2. Eliminare `fatalError` di configurazione e mostrare errore recoverable.
3. Validare feed RSS custom (`https` only + handling errori input).

### Fase 1 — Hardening (2-4 giorni)
4. Retry/backoff standard per rete + limite tentativi refresh token.
5. Uniformare error handling UI (copy + stati).
6. Logging strutturato (`OSLog`) con redaction.

### Fase 2 — Quality gate (2-3 giorni)
7. Smoke test manuale su device reale (72h soak test dashboard).
8. Aggiungere test unit minimi (parser RSS, mapping eventi, sanitizzazione URL).
9. Sessione Instruments e ottimizzazioni finali.

---

## 7) Valutazione finale

**Decisione:** ⚠️ **NO-GO temporaneo** finché i punti P0/P1 non sono chiusi.  
Con i fix indicati, il progetto può diventare **GO** rapidamente (stima 5-9 giorni lavorativi per una v1 più sicura/stabile).

