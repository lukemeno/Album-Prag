# Übergabe: Album – Prag Design System

Stand 4.10.2026, erstellt in einer Claude-Code-Cloud-Session. Dieser Ordner enthält alles, damit ein lokaler Chat ohne Vorwissen weiterarbeiten kann.

## Was das ist

- Veröffentlichtes Artefakt (privat, Typ „Design System“): https://claude.ai/artifact/QCJiHXe72Q7MizDFAZtf4a
- `project/` ist der Inhalt dieses Artefakts. Er ist 1:1 der Stand der letzten Veröffentlichung:
  - `tokens.json`: Farben Hell/Dunkel, Typo, Spacing, Radius, Size, Shadow, Opacity. Werte exakt aus `Album/Stitch/Stitch.swift`; neu aus den Referenzscreens: `radius-tile`, `tab-selected`, `size-pin`, `size-row-thumb`.
  - `README.md`: Brand-Book mit Regeln, Ton, Farbe, Typo, Fotos, Motion, Icons, Zugänglichkeit und der Zuordnung Komponente → Swift-Datei.
  - `Bestandsaufnahme.md`: was umgesetzt ist, was uneinheitlich ist, welche Screens abgedeckt sind.
  - `components/<Name>/README.md` + `preview.html`: 30 Bausteine und 14 Screen-Tafeln (`Screen*`). `components/bundle.css` ist die gemeinsame statische CSS-Nachbildung.
  - `design-system.json`: Index des Artefakts, inklusive Blob-IDs der fünf hochgeladenen Fotos.
- `tools/`: Generator. Previews und READMEs der Komponenten werden **nicht von Hand** editiert, sondern in `gen_components.py` bzw. `gen_screens.py` geändert und mit `run.py` neu erzeugt.

## Workflow

```sh
cd Design/Claude-Handoff/design-system/tools
python3 run.py                    # schreibt ../project/components/*
python3 build_tokens_css.py       # nur für lokale Screenshots
mkdir -p shots && node shot.js ScreenReise,ScreenKarte light   # Playwright nötig; PNGs in tools/shots/
```

Zurück ins Artefakt: Claude Code mit dem Artifact-Tool, `url` = Link oben, nur geänderte `project/…`-Dateien senden. Der Index `design-system.json` geht nur mit, wenn sich Titel oder Assets ändern; seine übrigen Schlüssel bleiben erhalten.

## Verbindliche Leitplanken (aus AGENTS.md / Nutzerfeedback)

- Nur native SwiftUI/UIKit-App, Expo ist beendet. Genau drei Tabs: Reise, Ideen, Karte.
- Vorlage: `references/approved-native-design.png` + `current-app/2026-10-04-reference-{reise,map,detail}.png`. Keine freie Neuinterpretation.
- Freigegeben ist nur der KI-Kreis (48 pt, Navy, `sparkles`), alles andere folgt den Referenzen.
- „Referenzgetreu“ erst nach direktem Simulator-Screenshotvergleich. Die Web-Previews hier sind die Vorlage, nicht der Nachweis.
- Nichts erfinden: keine Sterne/Bewertungen, Profilfotos, Öffnungszeiten, Flugdaten, Distanzen.
- Entscheidungen heißen „Ja / Nein / Offen“ (Code, PRODUCT.md).

## Offene Befunde

1. Kontrast (gemessen): `ink-soft` #737378 auf `paper` 4.48:1, auf `selection` 4.16:1. Vorschlag für den Code: `#6b6b70` (5.0:1).
2. `action-fill` (Navy) im Dunkelmodus 1.01:1 zum Hintergrund. Navy-Flächen brauchen dort eine `rule`-Kontur.
3. Bildnachweise fehlen im Repo für `imgPhotoCharlesBridge`, `imgPhotoOldTown`, `imgPhotoLetna`, `imgThumbCafe`. Nur `imgPragueCover` ist dokumentiert (CC BY-SA 2.0).
4. Icons in den Previews sind nachgezeichnete SVGs; in der App gelten die SF-Symbol-Namen aus dem README.

## Vorgeschlagener nächster Schritt (laut AGENTS.md: Sol plant, Luna setzt um)

Umsetzungspaket für `Album/Stitch/Stitch.swift` und die Kern-Screens:
1. Tokens ergänzen (`radius-tile`, Tab-Leisten-Pille, Pin-Größen) und Kontrast fixen.
2. Schwebende Tab-Leiste nach Referenz (TabBar-README).
3. Fotopins, Auswahl und Cluster (MapPin-README).
4. Kacheln (DayTile, ActionTile) und Ortszeile (PlaceRow).
5. Danach Simulator-Screenshots von Reise, Karte und Ortsdetail neben die Referenzen legen und Abweichungen beheben.

Swift-Dateien wurden in der Cloud-Session nicht geändert.
