# Unterlagen

PDFs importieren und privat speichern, Flüge, Hotel und Buchung automatisch extrahieren, Details prüfen und im PDF-Reader lesen.

**SwiftUI:** `TripDocumentsView.swift`, `TripDocumentParser.swift`, `ExtractedTripSheet` (TripDataViews.swift), `BoardingPass.swift` · Status: **neu abgeleitet**

- Erreichbar über „Unterlagen“ auf „Reise“ und aus Ticketkarten. Modales Blatt „Unterlagen“.
- Oben Reisedaten als TicketCards. Solange nichts ausgelesen ist, bleiben die Werte Gedankenstriche. Hotelname aus `TripInfo`.
- PDF-Liste mit DocumentCard-Zuständen: nicht ausgelesen (Aktion „Auslesen“), lädt hoch (Fortschritt), offline (wartet), Fehler (Banner).
- „Aus dem PDF gelesen“: Prüfblatt mit Häkchen pro Fund, „Kopieren“ für Buchungsnummern, Übernahme erst mit „Speichern“.
- Reader: PDFKit auf `paper-deep`, Seitenanzeige als dunkle Kapsel. Zitate des Assistenten sind markiert.
- Leerzustand: „Füg deine Buchungsbestätigung als PDF hinzu, dann steht alles hier.“
