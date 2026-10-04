# Album redesign status

## Aktive Richtung seit 04.10.2026

Album wird als native SwiftUI-/UIKit-App weiterentwickelt. Die Swift-App bleibt die visuelle und funktionale Grundlage; die generierten Designentwürfe dienen als Zielreferenz. Die Expo-Änderungen unten sind ein beendetes Experiment und kein aktuelles Implementierungsziel. Der isolierte Branch `design/album-visual-refresh` bleibt bestehen.

## Aktueller Stundenlauf · 04.10.2026, 10:50 MESZ

- Referenz weiter umgesetzt: echter Karlsbrücken-Sonnenuntergang als Reise-Cover (imgPragueCover), responsive Ortsdetail-Aktionen, kleiner KI-Kreis. Quelle/Lizenz dokumentiert.
- Funktionskorrekturen: kurze Swipes, konsistente Kartensuche/Routen, ausdrückliches Speichern von KI-Ortsvorschlägen und persistente Plan-Snapshots. Gefülltes Detail-Lesezeichen öffnet Planbearbeitung.
- 144 Unit-Tests + 14 unterschiedliche UI-Abläufe bestanden, vier Spezialtests ausgelassen. Finaler Karten-Nachtest ebenfalls bestanden. Neues signiertes Album inklusive Share-Extension auf iPhone 15 Pro installiert; physischer Start durch Gerätesperre blockiert.
- Visuelle Screenshots: QA/one-hour-screenshots/home-current.png, map-search-current.png, detail-current.png und automatisierte Drawer-/Rotationsansichten. Vollständiger Accessibility-Audit und physische Haptik weiter offen; historische Befunde unten sind keine neue Abnahme.
- Voller Bericht: QA/ONE-HOUR-READINESS.md. Die unten erwähnte Tageslicht-Abweichung des früheren Reise-Covers ist durch das neue Cover behoben; Profilinitialen/echte Daten und drei Tabs bleiben bewusste Abweichungen.

## Bisheriger Verlauf

### Verbindliche Referenz statt erster Interpretation

Nutzer lehnt den ersten nativen Hero-/Tagesstreifen-Pass ab. Verbindliche visuelle Referenz ist das erneut angehängte generierte Drei-Screen-Bild (Album-Reise, Karte, Karlsbrücken-Detail). Der erste Screenshot `2026-10-04-native-reise.png` ist verworfen.

- Reiseübersicht nach Referenz aufgebaut: eigener kompakter Album-Kopf ohne Toolbar-Leerraum, 300-pt-Foto mit Titel/Zeitraum im Bild, echte Teilnehmerinitialen, Einladen-Pill, weiße Reiseplan-Karte mit gleichbreiten horizontalen Tageskarten. Keine erfundenen Teilnehmer/Bewertungen; ungeplante Tage bleiben neutral.
- KI-Einstieg: 48-pt-Navy-Kreis mit Sparkles, kein sichtbarer Assistententext; fest unten rechts über der Tabbar, auch bei geöffneter Kartenliste. VoiceOver-Label erhalten.
- Karte: weiße abgerundete Foto-Pins, hellblaue Zeilenauswahl, abgerundete normale Fotothumbnails statt Briefmarkenrahmen. Neue schwebende Suche filtert Pins und Tages-/Ortsliste gemeinsam nach Name/Adresse.
- Ortsdetails: großes Foto, weiße Fläche mit abgerundeten oberen Ecken, Serifentitel, kompakte Aktionskacheln und existente Fotos/Quellen. Bearbeiten, Route und besuchte Orte bleiben bedienbar.
- Prüfung: Build erfolgreich, Large-Type-Test bestanden. Der vorbereitete Cluster-Audit wurde mangels Fixture übersprungen, nicht als bestanden gewertet. Pin-Auswahl und Scrollen zur passenden hellblauen Zeile sowie Öffnen des Details im Device Hub manuell mit isolierter Zwei-Orte-Fixture geprüft. Allgemeiner Karten-Audit scheitert weiterhin mit sechs Befunden: MapKit-Rechtshinweis-Kontrast, „Noch frei“-Kontrast, drei Dynamic-Type-Befunde an Tages-/Ortslabels und Suchfeld-Clipping. Änderungen an Suchfeldhöhe und vertikaler Textgröße haben diese Audit-Befunde nicht behoben. Kein bestandenes Audit behaupten; Details `/tmp/album-native-map-audit-v3.log`. Ein Zwischenversuch konnte wegen erneut vollem Laufwerk nicht installieren; alte temporäre Paketkopien entfernt.
- Screenshots im `Claude-Handoff/current-app`: `2026-10-04-reference-reise.png`, `2026-10-04-reference-map.png`, `2026-10-04-reference-detail.png`. Alle aus dem echten Simulator, lokale Beispieldaten separat von Nutzerdaten.
- Offene visuelle Abweichungen: vorhandenes Karlsbrückenfoto zeigt Tageslicht statt Referenz-Sonnenuntergang; Initialen statt echter Profilfotos; vorhandene drei native Tabs statt erfundener fünf Referenztabs; Fotos werden nur für wirklich vorhandene Daten gezeigt. Noch kein pixelidentischer Gesamtstand.

### Native Umsetzung 04.10.2026

- `Album/Stitch/ReiseView.swift`: fotografischer Prag-Hero mit vorhandenem Karlsbrückenfoto, kompaktere Titelhierarchie und Tagesauswahl. Bei Accessibility-Schriftgrößen steht der Titel unter dem Foto.
- `Album/Stitch/Stitch.swift`: gemeinsame Radien für Vorschaubilder, Karten und große Flächen vereinheitlicht (12/22/28 pt).
- iOS-Simulator-Build erfolgreich; Reiseübersicht im Device Hub visuell geprüft. Screenshot: `current-app/2026-10-04-native-reise.png` im Claude-Handoff.
- Erste Buildversuche scheiterten an vollem Laufwerk. Alte temporäre Album-Buildprodukte und Paketkopien entfernt, vorhandenen Xcode-Paketcache wiederverwendet. Keine Projektquellen entfernt.
- Claude Desktop: korrigierten nativen Designauftrag in der vorhandenen Session „App design planning“ gesendet; Auftrag läuft. Cloud-Session erstellt einen ergänzenden Designprototyp, ohne Zugriff auf lokale Swift-Quellen. Desktop-Konto verfügbar; die frühere Browser-Quotameldung unten beschreibt einen alten Versuch.
- Prüfung großer Schrift: `testAccessibilityLargeTypeTravelAndIdeasLayoutSnapshots` bestanden (1 Test, 0 Fehler); prüft Reisezeitraum, Titel und erreichbare Aktionen bei großer Schrift. `git diff --check` für diesen Designschritt ebenfalls bestanden.
- Nächster Schritt: Ideen, Ortsdetails und Karte auf dieselbe visuelle Sprache abstimmen und Claudes Vorschlag beurteilen.

- Working branch: `design/album-visual-refresh` (isolated worktree).
- Direction: preserve the Swift app's blue-gray paper palette, Fraunces / Instrument Serif typography, small stamp-color accents, compact native-feeling controls, and photo-led editorial cards; refine spacing, hierarchy, button centering, and navigation across the whole app.
- Local changes: Expo design tokens and SF Symbol tab icons updated; Swift typography files are reused by the Expo app; overview, ideas, map, and collection surfaces share the refreshed palette and component geometry; app orientation is no longer locked to portrait.
- Review prototype: `Design/rive/idea-decision/app-design-preview.html` is a responsive five-screen demo (trip, plan, ideas, map/list, collection) with working navigation, decision/undo, day selection, map/list selection, sheet, and assistant panel.
- Claude: the app-wide brief was sent to the private duplicate artifact. Claude rejected the response because its weekly usage limit is reached (reset shown as 4 Oct 2026, 13:00 MESZ). Continue in that artifact after reset; requested direction clarified as “the Swift app, only more beautiful and modern, like the generated images.”
- Checks: `npx tsc --noEmit`, `npx expo lint`, and `npx expo export --platform ios` pass. `npx expo export --platform web` is blocked by the installed `expo-sqlite` package referencing a missing `wa-sqlite.wasm`; the iOS app bundle exports successfully.
