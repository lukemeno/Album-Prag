# Album – Stand
- Neues natives SwiftUI/Xcode-Projekt; Workspace enthielt keinen Code.
- Figma 6:7, 6:62, 23:6 gelesen. Fotos, Logo, Typografie und Farbtokens werden übernommen.
- Ziel: Home, Inbox-Swipe, MapKit/Ortsuche, PDF, lokale Speicherung und gemeinsame Supabase-Reise.
- Prag 4.–9.10.2026, Hotel Urban Crème. Figma-Flugdaten nur Entwurf.
- Umgesetzt: SwiftUI-App mit Home, Inbox-Wischen, Karte/MapKit, Place-Details, PDF-Import/PDFKit, lokaler Persistenz und Supabase-Synchronisierung über privaten Einladungslink.
- Backend: anonyme Auth-Sitzungen, RLS für vier Tabellen, private PDF-Ablage, Edge Functions für gehashte Einladungen und Realtime-Abgleich.
- Entfernt: CloudKit, App Groups und Share Extension. Dadurch ist die Signierung mit einem kostenlosen Personal Team möglich.
- Assets: originale Figma-Fotos, Zwei-Türme-Logo, Icons, Fraunces, Instrument Serif und IBM Plex Sans/Mono.
- Prüfung: Build für iPhone-Simulator erfolgreich; 11 Unit-Tests, 1 UI-Test und 2 Deno-Tests erfolgreich. Beide Edge Functions bestehen `deno check`.
- Offen: Supabase-Projekt anlegen, Migration und Edge Functions deployen, URL und Publishable Key eintragen und den Zwei-Geräte-Abgleich mit echten Konten prüfen.

## 23.09.2026 – Redesign „Kreuzstich“ (Branch `design/kreuzstich`)
- Neue Welt: Leinen, Garn, Kreuzstiche (alles von SwiftUI gezeichnet, keine Bilddateien). Produktgrundlage in `PRODUCT.md`, Interaktionen in `Design/INTERAKTIONEN.md`.
- Tabs heißen jetzt Reise, Ideen, Karte (native iOS-Tab-Leiste). „Frankieren/Zurücklegen“ heißt jetzt „Dafür/Später“.
- App-Sprache ist Deutsch (`CFBundleDevelopmentRegion: de`), damit auch System-Knöpfe deutsch sind.
- Offen: Magnet-Klick (Supabase-Migration nötig), Pins zum Umsortieren ziehen, Dunkelmodus (App ist weiterhin nur hell), Test auf zwei echten iPhones.
