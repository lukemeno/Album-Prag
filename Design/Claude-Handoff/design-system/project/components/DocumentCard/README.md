# DocumentCard

PDF-Zeile in den Unterlagen mit Upload-Fortschritt, Fehler- und Offline-Zustand.

**SwiftUI:** `TripDocumentsView.swift`, `TripDocumentParser.swift` · Status: **Bestand; Zustände ergänzen**

- `card` + `rule`, `radius-card`. Links das PDF-Symbol (44 × 54, `paper-deep`, Eselsohr), Name `label`, Meta `meta` (Datum, Seitenzahl).
- Hochladen: Fortschrittsbalken 4 pt in `ink` auf `paper-deep` mit Prozent. Offline: „Wird hochgeladen, sobald du online bist“ mit `wifi-off`.
- Fehler: Banner `err` mit „Erneut versuchen“. Das lokale PDF bleibt erhalten.
- Ausgelesen: Badge `ok` „Flüge und Hotel übernommen“. Die Aktion „Auslesen“ steht als Textaktion daneben.
- Privat: Speicherung im privaten Bucket. Hinweis mit `lock` im Leerzustand.
