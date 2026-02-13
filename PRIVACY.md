# Privacy & Data Retention (DashB)

## Dati trattati in locale
- Preferenze utente (`AppStorage`): nome visualizzato, città meteo, toggle UI, calendari selezionati, feed RSS configurati.
- Credenziali OAuth (`Keychain`): access token e refresh token Google/Outlook.
- Cache runtime: articoli RSS/eventi calendario in memoria durante l'esecuzione.

## Finalità
- Mostrare dashboard meteo/news/calendario.
- Consentire accesso account Google/Outlook e lettura eventi in sola lettura.
- Personalizzare esperienza utente (fonti RSS e preferenze).

## Retention
- `AppStorage`: persistente fino a reset manuale dell'app o reinstallazione.
- `Keychain`: persistente fino a logout esplicito dal provider o rimozione app (comportamento OS).
- Dati in memoria (RSS/eventi): temporanei, ricostruiti ai refresh.

## Cancellazione
- Logout Google/Outlook elimina token dal Keychain locale.
- Ripristino feed default sovrascrive i feed custom.
- Reinstallazione app rimuove preferenze locali; i token Keychain possono richiedere logout esplicito in base al comportamento del sistema.

## Note sicurezza
- URL RSS custom accettati solo in `https` con host valido (blocco host locali).
- Logging di autenticazione sensibile limitato a build `DEBUG` con redazione dei dettagli.
