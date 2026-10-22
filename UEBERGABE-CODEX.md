# Übergabe · Stand 22.10.2026

Zuerst `PROJECT-MAP.md` und die jüngsten Einträge in `PROGRESS.md` lesen. Diese Datei ergänzt sie.

## Aufbau: ein Ordner, ein Branch

- **Ordner:** `/Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album`
- **Branch:** nur `main` (lokal). Keine weiteren Branches, keine Worktrees.
- `main` liegt 9 Commits vor `origin/main` (`55baad9`). **Nichts ist gepusht.** Push nur nach ausdrücklichem Go des Nutzers.
- Die Remote-Branches auf `origin` sind unverändert. Der Standard-Branch von `origin` ist `claude/busy-knuth-jci1vg`, nicht `main`. Das vor einem Push klären.

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
2. Push-Ziel klären und erst dann pushen. B1 ändert das Sync-Format: Die echte Prag-Reise nicht bearbeiten, bevor B1 auf dem Handy installiert ist (Stand dort: `a63fb6f`).
3. Bildauswahl: 14 Fälle der Testliste von Hand labeln (`supabase/tests/place_photo_golden/`), dann die Pipeline bauen. `place-photo` ist nicht deployt.
4. Assistenten-Limits Wellen 2–4 brauchen einen bezahlten Apple-Developer-Account.

## Regeln

Kein Push, kein Deploy, keine Live-Supabase-Änderung ohne ausdrückliches Go. Auth, Zahlung und Sicherheit nur nach Freigabe. Der Skill `impeccable` wird für Album nicht genutzt.

## Bestätigte Arbeitsbasis · 22.10.2026 (Nutzer)

Der Nutzer möchte am weiß/dunkelgrünen Album-Stand mit Haltemenü weiterarbeiten. Seine Bildreferenz zeigt Reisewahl und Reiseübersicht; die beigefügten Stichpunkte sind Ideen, kein pauschaler Umsetzungsauftrag. Arbeitsbasis bleibt die native SwiftUI-App auf lokalem `main`, mit dem vorhandenen Bogen-Menü (Halten, Ziehen, Loslassen) und dem Menü-Feinschliff vom 20.10. Die Aufnahmen unter `.qa-shots/native-20261019/` dokumentieren die Gestaltungsrichtung, sind aber kein neuer Simulatornachweis für den aktuellen HEAD. Expo-Kofferaufkleber-, Glas- und Rive-Entwürfe ersetzen diese Arbeitsbasis nicht. Technische Fortschritte wie B1 bleiben erhalten.
