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
- Gemeinsam entscheiden pro Person: Vorschläge der anderen Person bleiben in den eigenen Ideen, bis man selbst abstimmt; beide dafür = Magnet-Klick. Stimmen werden beim Abgleich vereinigt.
- Tagesplan mit Reihenfolge, Dunkelmodus.
- Behoben: „new row violates row-level security policy“. Ursache: unsignierte Test-Builds (`CODE_SIGNING_ALLOWED=NO`) können die Sitzung nicht im Schlüsselbund speichern und schreiben ohne Token (HTTP 401). Außerdem prüft die App jetzt vor jedem Abgleich ihre Mitgliedschaft und tritt mit der gemerkten Einladung wieder bei; beide iPhones merken sich die Einladung. Live geprüft am 23.09. mit signiertem Simulator-Build.
- Offen: Test auf zwei echten iPhones.
