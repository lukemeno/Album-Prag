# Album: verbindliche Projektzuordnung

Stand: 20.10.2026. Nach Abgleich beider Repositories ist die bestehende, funktionsfähige SwiftUI-App die Entwicklungsbasis. Das separate W0-Gerüst bleibt erhalten und wird nicht parallel zur Hauptapp ausgebaut.

## Hauptprojekt: hier weiterarbeiten

- Ordner: `/Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album`
- Xcode-Projekt: [Album.xcodeproj](Album.xcodeproj), Schema **Album**.
- App-Einstieg: `Album/AlbumApp.swift` → `AlbumExperienceRoot`.
- Enthält Home, Tagesplan, Ideen, MapKit, Gruppe, Unterlagen, Reisekosten, Erinnerungen, Assistent und Bogen-Menü sowie die bestehende lokale Speicherung und Supabase-Anbindung.
- Aktive Gestaltungsrichtung des Ports: Weiß/Grün, Inter/Lora, entsprechend dem geprüften HTML-Prototyp. Ältere Briefmarken-/Kreuzstich-Abschnitte sind Historie, keine neue Gestaltungsanweisung.
- Prüfstand: [NATIVE-PORT.md](NATIVE-PORT.md), [QA-BACKEND-CLIENTS.md](QA-BACKEND-CLIENTS.md), letzte Checkpoints in [PROGRESS.md](PROGRESS.md). Vor dieser Zuordnung letzter Commit: `c026212`.
- Die dokumentierten Simulator- und Live-Sync-Ergebnisse gelten für diese App. Echte Kamera, fühlbare Haptik, VoiceOver auf dem Gerät und der gemeinsame Ablauf auf zwei physischen iPhones bleiben separat abzunehmen. iOS 18 ist damit nicht als Laufzeit geprüft behauptet.

## Referenzprojekt: Gestaltung und W0-Experiment

- Ordner: `/Users/alexandergorny/.t3/scratch/2026-10-17-baue-in-https-www-figma-6e7fdb27`
- `album-app.html` bleibt die Referenz für Gestaltung und Interaktionen; dessen Web-Backlog ist kein Nachweis fehlender nativer Funktionen.
- Separates Xcode-Projekt: `/Users/alexandergorny/.t3/scratch/2026-10-17-baue-in-https-www-figma-6e7fdb27/ios/Album/Album.xcodeproj`.
- W0-Stand `aa40422`: eigenständiges SwiftUI-Gerüst mit Platzhaltern, Toasts, Theme und Navigationshülle. Keine Fortsetzung der geprüften Hauptapp, keine zusätzliche Produktions-App.
- Die W0-Liste „noch nicht gebaut“ gilt nur für dieses Gerüst. Dessen Rand-Wisch-/Toast-/HUD-Befunde dürfen nicht ohne Reproduktion der Hauptapp zugeordnet werden.

## Regeln für die nächste Arbeit

1. Vor einer iOS-Änderung Arbeitsordner und Xcode-Projekt prüfen; standardmäßig das Hauptprojekt verwenden.
2. Neue Funktionen und Fehlerkorrekturen einmal in der Hauptapp umsetzen. W0 nicht automatisch weiterbauen.
3. Nützliche W0-Details nur nach gezieltem Vergleich übernehmen; vorhandene Datenmodelle, Backend-Anbindung und gespeicherte Alben erhalten. Keine pauschale Zusammenführung der beiden Codebasen.
4. Prüfungen immer mit Repository, Commit, Gerät/Simulator und tatsächlichem Ergebnis dokumentieren. Historische Aussagen nicht als aktuelle Vollabnahme lesen.
5. Vorhandene uncommittete Nutzerarbeit in Store, Inbox, Expo und Designordnern erhalten. Diese Zuordnung ändert nur Dokumentation und weder App-Daten noch Quellcode.
