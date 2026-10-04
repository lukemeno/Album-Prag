# Album – Design-Übergabe (Stand 04.10.2026)

## Was hier liegt

- `album-designsystem-v2.html`: Designsystem- und UI-Spezifikation der **nativen** iOS-App (SwiftUI/UIKit). Im Browser öffnen. Die Datei ist ca. 900 KB groß, weil Bilder als Base64 eingebettet sind. Zum Lesen besser diese README und den Swift-Code nehmen.
- Es wurde **kein App-Code** geändert.

## Quelle der Wahrheit

- Code-Stand: Branch `design/album-visual-refresh` @ `b6bef9c` (dieser Branch baut darauf auf).
- Verbindliche Referenz: `Design/Claude-Handoff/references/approved-native-design.png`.
- Tokens: `Album/Stitch/Stitch.swift` (Farben, Schriften, Abstände, Radien, Schatten, Motion).
- Produkt: `PRODUCT.md`, Regeln: `AGENTS.md`.
- Motion-Referenzen: `Design/Claude-Handoff/MOTION-PROMPTS.md`, `Design/Claude-Handoff/motion/`.

## Feste Grenzen

- Genau drei Tabs: Reise, Ideen, Karte.
- Der kleine dunkle KI-Kreis unten rechts ist freigegeben und bleibt.
- Die Karte bleibt Apple MapKit.
- Keine erfundenen Bewertungen, Profilbilder, Öffnungszeiten, Flugdaten oder Zeiten. Beispiele als solche kennzeichnen (z. B. Flug EW4241 ist nur ein Entwurf).
- Jede Geste braucht eine sichtbare Knopf-Alternative.
- Dynamic Type, VoiceOver und „Bewegung reduzieren“ berücksichtigen.
- Gefühl: cozy und sweet, schön und leicht zu bedienen.
- Look: Off-White-Papier, Navy-Tinte, Rot nur für Aktionen, Fraunces SemiBold für Titel, Instrument Serif für Ortsnamen, SF Pro für die Bedienung, Fotokarten, Fotopins mit weißem Rand, Ortsdetail mit Vollbildfoto.

## Gefundene Lücken, die das Design lösen soll

1. Kein sichtbarer Sync- oder Offline-Status.
2. Keine eigene Ansicht für abgelehnte Ideen („Dagegen“).
3. Kartenfilter „Besucht“ fehlt.
4. Kein einheitlicher Ortsstatus Idee → geplant → besucht.
5. Bildnachweis am Foto fehlt.
6. KI-Kreis verdeckt Inhalte.
7. `inkSoft` #737378 hat zu wenig Kontrast; Vorschlag #66676C.
8. Im Querformat überdeckt die Tab-Leiste das Ortsblatt.
9. Leere Tageskarten wirken kaputt.
10. Bei PDFs fehlen Upload-Zustände und der Hinweis auf die 25-MB-Grenze.
11. Koffer/Briefmarke nur als Material nutzen: Fotopin, Briefmarke, Poststempel.

## Gestaltungsideen aus der letzten Sitzung (nicht umgesetzt)

- Statuskette als Material: **Fotopin** = Idee, **Briefmarke** = geplant, **Poststempel** = besucht.
- KI-Kreis in die Zeile der schwebenden Tab-Leiste setzen (rechts daneben), damit er nie über Inhalten liegt. Im Dunkelmodus dunkel lassen (heute `Stitch.ink` → wird hell, weißes Symbol verschwindet).
- Kleine Sync-Pille im Kopf: „Abgeglichen“, „Gleicht ab …“, „Offline · n warten“, „Nicht abgeglichen“ + „Erneut versuchen“.
- Ideen oben mit Segmenten „Offen · Dafür · Dagegen“; Dagegen-Liste mit „Doch dafür“ und „Löschen“.
- Karte im Querformat: Ortsblatt als Seitenpanel links, Tab-Leiste mittig im freien Kartenbereich.
- Leerer Tag: gestrichelte Briefmarkenfläche „Noch frei“ + eine Aktion „Ideen für diesen Tag ansehen“.
- Bildnachweis als kleine Zeile unten rechts auf jedem Foto (z. B. Titelbild: „Foto: Thomas Fabian · CC BY-SA 2.0“).

## Offen

- Pixelgenaue Screens aller Ansichten (hoch/quer, hell/dunkel, Zustände leer/laden/offline/Fehler/Erfolg) wurden **noch nicht** gebaut.
- Nutzerwunsch zuletzt: Die **Bildanzeige in der App** soll zuverlässig funktionieren. Der genaue Fehler (welcher Screen, welcher Ort) ist noch nicht geklärt. Relevante Dateien: `Album/PlaceImageService.swift`, `Album/PlaceImageStorage.swift`, `Album/PlaceEditor.swift`, `supabase/functions/place-photo`; Verlauf in `PROGRESS.md` (Abschnitte vom 04.10.2026) und `QA/PHOTO-FALLBACK-FIX.md`. Laut `PROGRESS.md` sind die letzten Bild-Fixes noch nicht auf dem iPhone installiert.
- In einer Cloud-Umgebung gibt es kein Xcode: Swift-Änderungen dort nicht bauen oder testen, sondern lokal prüfen.
