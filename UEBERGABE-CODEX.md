# Übergabe · Stand 23.10.2026

Zuerst `PROJECT-MAP.md` und die jüngsten Einträge in `PROGRESS.md` lesen. Diese Datei ergänzt sie.

## Aufbau: ein Ordner, ein Branch

- **Ordner:** `/Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album`
- **Branch:** nur `main` (lokal). Keine weiteren Branches, keine Worktrees.
- Die Bereinigung wurde mit `16599f3` auf GitHub veröffentlicht. Weitere lokale Änderungen werden auf `main` umgesetzt und bis zum nächsten ausdrücklichen Push-Go lokal geprüft.
- Auf GitHub gibt es ebenfalls nur `main`; `main` ist der Standard-Branch. Die früheren Branches bleiben im lokalen Sicherungs-Bundle erhalten.

## Was auf `main` ist

- **Optik wie am 19.10.:** weiß, dunkelgrüner Akzent (22/75/60), ✦ in der Kopfzeile, Haltemenü im Pinterest-Stil. Referenz: `.qa-shots/native-20261019/uebersicht.jpg`. Der Bogen-Menü-Feinschliff vom 20.10. (hellerer Schleier, KI-Badge, volle Labels, Haptik) bleibt.
- **Zurückgenommen** (Terrakotta und Politur): `5cbdd10`, `a63fb6f`, `4554789`, `6e35c61`, `ba315fe`, `f6da5de`. Die fünf Politur-Commits der Design-Linie (Unterlagen, Erinnerungen, Assistent-Chips, Ideen-Plan-Button, Gruppe-Untertitel) sind nicht übernommen.
- **B1 (flexible Reisen)** zusammengeführt, Merge-Commit `8552271`. `store.tripName` liest `Trip.title` (Rückfall „Prag“).
- **Bildauswahl:** Plan, Testliste (100 Fälle) und Messlauf, ohne App-Änderung.
- **Funktion von vorher bleibt:** Web-Recherche fest an, Assistenten-Limits Welle 1, Supabase-Angleichung, Ideen wiederherstellen.

## Geprüft

- Unit-Tests: 183 Tests, 0 Fehler, 4 übersprungene Live-Tests.
- UI-Tests: `NativePrototypeUITests` 6/6 und `AssistantUITests` 2/2.
- Nicht geprüft: Gerät (Haptik, Kamera, Sync zwischen zwei iPhones), echte Prag-Reise im v2-Format.

## Sicherung

`~/Album-Sicherung-20261022/` enthält alles, was beim Aufräumen aus dem Repo verschwand:
- `alle-branches.bundle`: alle 41 Referenzen vom Zeitpunkt vor dem Aufräumen. Wiederherstellen: `git fetch ~/Album-Sicherung-20261022/alle-branches.bundle 'refs/heads/*:refs/heads/alt/*'`.
- `refs-vorher.txt`, `worktrees-vorher.txt`: Liste der Branches und Worktrees vorher.
- `patches/`: uncommittete Änderungen je Worktree.
- `worktrees/`: vier Ordner mit ungesicherter Arbeit, unverändert verschoben: `Album-cloud-design`, `album-native-shell-20261019`, `map-ux-sol-20261002` (Codex), `prag-album-release-signing` (Codex).

## Uncommittet im Hauptordner (nicht anfassen)

`PROGRESS.md`, `expo/prague-album/src/app/_layout.tsx` und ungetrackte Ordner (`Design/…`, `qa-night/` mit 1 GB, `Users/` mit einer versehentlich verschachtelten Pfadkopie, `.impeccable/`, `.vision/`, `PLAN-APPSTORE.md`). Sie gehören dem Nutzer oder Cursor.

## Nächste Schritte

1. Optik im Simulator gegen `uebersicht.jpg` prüfen (Home, Plan, Ideen, Gruppe).
2. Push-Ziel ist `main`, Push weiterhin nur nach ausdrücklichem Go. B1 ändert das Sync-Format: Die echte Prag-Reise nicht bearbeiten, bevor B1 auf dem Handy installiert ist (Stand dort: `a63fb6f`).
3. Bildauswahl: 14 Fälle der Testliste von Hand labeln (`supabase/tests/place_photo_golden/`), dann die Pipeline bauen. `place-photo` ist nicht deployt.
4. Assistenten-Limits Wellen 2–4 brauchen einen bezahlten Apple-Developer-Account.

## Regeln

Kein Push, kein Deploy, keine Live-Supabase-Änderung ohne ausdrückliches Go. Auth, Zahlung und Sicherheit nur nach Freigabe. Der Skill `impeccable` wird für Album nicht genutzt.

## Bestätigte Arbeitsbasis · 22.10.2026 (Nutzer)

Der Nutzer möchte am weiß/dunkelgrünen Album-Stand mit Haltemenü weiterarbeiten. Seine Bildreferenz zeigt Reisewahl und Reiseübersicht; die beigefügten Stichpunkte sind Ideen, kein pauschaler Umsetzungsauftrag. Arbeitsbasis bleibt die native SwiftUI-App auf lokalem `main`, mit dem vorhandenen Bogen-Menü (Halten, Ziehen, Loslassen) und dem Menü-Feinschliff vom 20.10. Die Aufnahmen unter `.qa-shots/native-20261019/` dokumentieren die Gestaltungsrichtung, sind aber kein neuer Simulatornachweis für den aktuellen HEAD. Expo-Kofferaufkleber-, Glas- und Rive-Entwürfe ersetzen diese Arbeitsbasis nicht. Technische Fortschritte wie B1 bleiben erhalten.

## Verbesserungsrunde 1 · 22.10.2026

Sol plante und prüfte, zwei Luna-Agenten setzten um: Ausgaben bearbeiten/löschen mit rückwärtskompatiblen Löschmarkierungen, dynamische Daten auf der Startkarte, Zustimmung unabhängig von Tagesplanung. Zugestimmte ungeplante Ideen bleiben an ihrer Listenposition; Tageswahl ist explizit. Planstempel und Zusammenführen noch nicht hochgeladener Orte schützen Planung/Stimmen beim Abgleich. Kein Backend-Deployment.

Xcode-Build-/Paketcache unter `~/Library/Developer/Xcode/DerivedData/` verwenden. Der frühere Cache unter Documents/Codex enthält ausgelagerte (`dataless`) Paketdateien und blockierte die Paketauflösung; er ist keine zuverlässige Build-Grundlage. Testresultate ebenfalls außerhalb ausgelagerter Dokumentordner ablegen.

Final geprüft: 196 Unit-Tests (4 übersprungen, 0 Fehler) und 10 UI-Tests bestanden; einschließlich Korrektur/Löschen von Ausgaben mit Neustart und Zustimmung/ausdrücklicher Tageswahl mit Neustart. Lokaler main-Commit, noch kein Push dieser Verbesserungsrunde.


## Globale Ortsbilder · 23.10.2026 (lokal, Veröffentlichung ausstehend)

- Umsetzung auf `main`: Ortsauflösung vor Bildsuche, globale Suchregion aus Reise/Unterkünften/bestätigten Orten, Zielname ohne Koordinaten als Suchkontext. Kein fester Prag-Rückfall in diesen Such- und Kartenpfaden.
- Ideenliste: „Bilder ergänzen“, Ortsauswahl bei mehreren Treffern, Bearbeiten allgemeiner Ideen wie „Ramen“, Retry bei Fehlern. Nutzerbilder bleiben erhalten; veraltete automatische Wikimedia-Bilder werden mit Fotoauswahlversion 4 neu geprüft.
- Wikimedia: Englisch + validierte Gerätesprache + erkannte Region-Sprache (max. 3); kanonische Namen vor bloßen Alias-Treffern. Mehrere kanonische gleichnamige Nachbarorte bleiben ohne eindeutigen Adressbeleg ungeklärt. Quelle/Urheber/Lizenz werden mitgeführt. Kein neuer bezahlter Anbieter aktiviert.
- Nach erfolgreicher aktueller leerer Bildantwort werden alte automatische v3-Fotos entfernt; bei Netzfehlern bleiben sie für Retry erhalten. Manuelle Auswahl bleibt geschützt. Abbruch und veraltete Antworten ändern keine neueren Nutzereingaben.
- **Noch nicht veröffentlicht:** kein Push, kein Supabase-Deploy. Zuerst Backend mit Fotoauswahlversion 4 veröffentlichen, dann neuen Client verteilen; sonst akzeptiert der v4-Client alte v3-Serverantworten nicht automatisch. `place-photo` UND Verbraucher der geänderten gemeinsamen Module (`place-enrichment`, `place-enrichment-worker`) vor Deployment auf Live-Drift prüfen. Den Hinweis zu Live-Snapshots vom 21.10. beachten.
- Tests und Root-Simulatorabnahme stehen im neuesten `PROGRESS.md`-Checkpoint. Nachweis im Codex-Chat unter `outputs/globale-ortsbilder/`; Simulator-Testdaten sind isoliert, keine echte Reise synchronisiert.
