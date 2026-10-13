# Hinzufügen und Bearbeiten

Orts- und Ideen-Editor: Link, automatische Metadaten, Name, Kategorie, Beschreibung, Ort sowie die Bildwahl.

**SwiftUI:** `PlaceEditor.swift`, `PlaceImageService.swift`, `LINK-ENRICHMENT-PLAN.md` · Status: **neu abgeleitet**

- Modales Blatt mit „Abbrechen“ / „Idee einwerfen“ / „Speichern“. Oben das gewählte Bild mit Credit-Kapsel und „Bild wählen“.
- Link zuerst: Nach dem Einfügen ergänzt die App Titel, Bild und Beschreibung und bestätigt das in `teal`. Fehler stehen inline am Feld.
- Kategorie als Chips (Essen, Sehenswert, Aussicht, Shopping, Unterkunft). Ohne Wahl gilt „Idee“.
- Ortssuche: Apple-Karten-Treffer mit Adresse, ähnliche Namen als „bitte prüfen“, Kartenvorschau mit gewähltem Pin. Koordinaten werden erst beim Speichern übernommen.
- Bild wählen: Quellenreihenfolge, unsichere Fotos manuell bestätigen, Credits sichtbar, „Bild entfernen“.
- Instagram wird nicht gescrapt. Aus Social-Captions wird nie automatisch ein Ort gesetzt.
