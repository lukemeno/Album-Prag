<!-- Aktueller Checkpoint 03.10.: Nutzer verlangt visuelle Übereinstimmung der Expo-App mit Swift. Reiseübersicht auf Tagesstreifen/Tagesplan/Tickets umgestellt; 3-Tabs und schwebende Tab-Kapsel sowie Ideen/Sammlung-Segment ergänzt. TypeScript besteht. Expo-Go-Simulator passt nicht zu SDK57 (ExpoAsset fehlt); lokaler Client-Build scheitert aktuell wegen vollem Datenträger. Screen-für-Screen-Designparität und physischer Zwei-iPhone-Abschluss noch offen. -->
# Prag-Album: Übergabe für einen anderen Account

Stand: 03.10.2026. Nach Accountwechsel auf Nutzerwunsch fortgesetzt; laufende Updates in EXPO-MIGRATION-STATUS.md.

## Direkt weiterarbeiten

Projekt: `/Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album`
Expo: `expo/prague-album`
Chat: „Öffne aktuelles Prag-Albumprojekt“, ID `01a1023c-2d0a-78b1-a6aa-9c5714820d2b`.
Lokaler Chattext: `/Users/alexandergorny/Documents/Codex/2026-10-03/gr/Prag-Fortsetzung/CHATVERLAUF.md`.
Ein Accountwechsel überträgt den Chat nicht automatisch; diese Dateien erlauben die Fortsetzung in einem neuen lokalen Chat. Ein Cloud-Chat hat keinen Zugriff allein durch lokale Pfade.

Prompt zum Kopieren:
> Öffne das Projekt /Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album. Lies ACCOUNT-HANDOFF.md, AGENTS.md, EXPO-FUNCTION-PARITY.md und EXPO-MIGRATION-STATUS.md. Setze die Expo-Migration schrittweise fort. Alle bisherigen Funktionen sollen funktionsfähig werden; beide iPhones verwenden unterschiedliche Apple-Accounts, ohne bezahlte Apple-Developer-Mitgliedschaft. Erhalte die uncommitteten Änderungen. Lies den neuesten Checkpoint und die offene Akzeptanzliste; nichts als fertig behaupten, bevor die Geräteabnahme erfolgt ist.

## Nutzerauftrag und Präferenzen

- Alle recherchierten Prag-Ideen sollten direkt in der App erscheinen. Alle 78 Expo-Seed-IDs entsprechen jetzt dem nativen Seed. Der reale private Geräteexport enthält 80 Orte, 20 Sammlungsbeiträge, eine Unterlage.
- Expo-Migration tatsächlich umsetzen, keine reine Planung. Nutzer erwartet Assistent, TikTok/Bilderimporte, Routen und sämtliche bisherigen Funktionen.
- Beide Personen haben unterschiedliche Apple-Accounts; keine Apple-Developer-Gebühr.
- Root AGENTS: Sol plant/reviewt, Luna implementiert. Kleine Reparaturen gezielt vornehmen. Kein Poteto Mode.
- Nicht vorschnell „alles fertig“ melden. Alle offenen Akzeptanzkriterien stehen in EXPO-FUNCTION-PARITY.md. Swift-App bis zum abschließenden Gerätecheck erhalten.

## Bereits im aktiven Expo-Projekt

- Expo SDK57 (~57.0.26), ReactNative0.86.3, ExpoRouter, SQLite, Supabase, Karten.
- 78 Ideen, Suche/Filter, einfache Abstimmungen, hinzufügen; manuelle Tageszuordnung 4.–9. Oktober; Kartennadeln, ausgewählter Tageslinienzug, externe GoogleMaps-Fußroute.
- Anonyme Supabase-Sessions in SecureStore, Reise erstellen/beitreten, Einladung, manuelle/realtime Synchronisierung, JSON-Import/-Export.
- Sammlung: lokale Posts/Links, Kommentare, Herzen und Tombstones; Link-ID/Kanonisierung, begrenzte Vorschau, manuelles PlaceLink/Unlink und Versions-CAS für Supabase ergänzt. `check-collection.mjs` besteht. Live-Zwei-Identitäten-Abnahme und Geräte-UI sind offen. Automatische Caption-Ortsdetektion und native Share Extension (in Expo Go grundsätzlich nicht verfügbar) fehlen.
- Erinnerungen: eigener Bildschirm unter `/memories`, Chronik besuchter Orte mit Foto und Link zum Ortseditor; besucht/Chronik teilen den bestehenden Place-Sync. Geräte-/Realtime-Abnahme offen.
- Sync-UI wurde korrigiert: erfolgreicher Sync lädt PlaceStore neu und erhöht revision, Reiseunterlagen/Sammlung laden nach. syncNow liefert boolean und wartet auf eine bereits laufende Synchronisierung. Reise-Payload wird synchronisiert.
- Assistent nun integriert unter `/assistant`: Chat, lokale Historie/Vorlieben, Quellen, explizites Speichern/Deduplizieren/Wiederöffnen von Ortsvorschlägen; Tagesplan-Vorschlag mit Bestätigung, atomarer Anwendung, Kontextfingerprint und konfliktgeschütztem Undo; Abbruch/Retry/Timeout; optionale Websuche/Standort. UUID via expo-crypto.
- Neue Assistentdateien: src/domain/assistant.ts, src/storage/assistant-{service,context,actions}.ts, src/hooks/use-assistant.ts, src/app/assistant.tsx.
- Reise-Links auf tatsächliche Pressable-Karten umgestellt. Assistent-Composer repariert: Sendebutton in eigener Zeile neben Texteingabe statt Überlappung mit Webschalter; KeyboardAvoidingView; Vorlieben entfernen und Verlauf leeren UI ergänzt.
- Dependencies expo-crypto und expo-image-manipulator wurden SDK-konform installiert.

## Aktueller Prüfstand und Medien

- Assistent: echtes UI-Senden/Antwort/Neustart/Deduplizierung in ExpoGo57; authentifiziertes Backend HTTP200; lokale SQLite-Aktionen, Pläne, Importregression und Votes getestet.
- Medien-Slice im primären Expo-Projekt integriert: Idee bearbeiten/archivieren/wiederherstellen; Link-/TikTok-Metadaten, Foto-Picker/JPEG1600px/5MB, lokale Dateien, private Uploads/Partnercache, Kandidaten/Quellen/Galerie. DBv3 local_media; Upload vor Place-Publish. Alte paused-media-Kopie nicht darüberkopieren!
- Eigene Fotoidee im Simulator gespeichert; kompletter ExpoGo-Neustart erhält Titel und synthetisches Prüffoto. Direktlink-Speichern führt jetzt zu Ideen. Fotos auch in Ideenkarten sichtbar; native gebündelte Assets übernommen.
- Zwei synthetische anonyme Backend-Identitäten: create/join, getrennte Votes/Rücknahme, stale CAS-Abweisung. JPEG-A-Upload/B-SignedURL-Download byte-identisch und öffentlicher Zugriff verweigert. Prager-Burg-Bildsuche liefert fünf Quellen-Kandidaten. Das ersetzt keine physischen Zwei-iPhone-Prüfungen.
- TypeScript/Lint/SQLite-/Linkchecks erfolgreich; iOS-Export Medien-Slice erfolgreich /tmp/prague-expo-media-export-20261003. Nach weiteren Integrationen neu prüfen.
- Unterlagen und Reiseeditor vollständig integriert; PDF.js-/Lizenzfonts-Simulator-Probe, TypeScript/Lint/Regressionen/Expo Doctor/iOS-Export bestanden. Siehe neuesten Abschnitt in EXPO-MIGRATION-STATUS.md.

## Wichtige offene Punkte

1. Medien-UI auf Partnergerät und echte Linkimporte fertig prüfen; aktuelle Implementierung erhalten.
2. Timestamped Votes/open-Tombstones und CAS sind implementiert; physischen Zwei-Personen-/Offline-Nachweis abschließen. Unveränderter Swift-Mischbetrieb noch ungeprüft.
3. Live-Sammlung mit zwei Identitäten/Fremdzugriff, Kommentar-Tombstones und Änderung während Sync nachweisen; physische Geräteabnahme bleibt offen.
4. Automatische Tagesplanung ist integriert; verbleibend sind vollständige UI-Abnahme und erneuter Live-Öffnungszeitenabruf. Erinnerungen/Visited UI wurde ergänzt, noch keine Geräteabnahme.
5. Original-PDF/Reiseeditor integriert; noch physisch Import/Share/offline Neustart/Partner-Sync und echte Buchungs-PDFs abnehmen.
6. Tatsächliches Gerätealbum inklusive Fotobinaries/PDF migrieren, wiederholter Import darf neuere Änderungen nicht überschreiben; offline Neustart und Reconnect.
7. Beide physischen iPhones, separate Supabase-Identitäten, ExpoGo geöffnet, Create/Join/Synchronisierung/Fotos/PDF/Assistent/Route abschließend verifizieren.
8. ExpoGo bietet keine frei hinzufügbare eigene iOS-Share-Extension oder native Apple-LookAround-API. Sinnvolle Paste/Foto/Deeplink- und StreetView-Alternative implementieren und prüfen; keine identische Parität behaupten. Exakte Extension erfordert anderen nativen Buildpfad. ExpoGo ist keine eigenständig installierte eigene App; Metro-Verbindung erforderlich.

## Umgebung / Wiederaufnahme

- Aktuelles Arbeitsverzeichnis des Chats war /Users/alexandergorny/Documents/Codex/2026-10-03/gr; tatsächlichen Albumordner explizit verwenden.
- Umfangreiche bereits vorhandene uncommittete Swift-Änderungen erhalten, keine Resets/Checkout/clean. Anderer Albumchat ist möglicherweise parallel aktiv.
- Metro war localhost:8081 PID55866 (Zustand nach Accountwechsel neu prüfen); ExpoGo57 auf Simulator A297FE47-FA5E-468A-8D14-40DFD2AAC71D „iPhone 17 Pro“ und 32F5D213-FB39-4A48-9E88-5B01F3569D3B „Album Codex“ installiert.
- Öffnen: xcrun simctl openurl A297FE47-FA5E-468A-8D14-40DFD2AAC71D exp://127.0.0.1:8081/--/assistant.
- Xcode26 verwaltet Simulatoroberfläche über App com.apple.dt.Devices (DeviceHub), nicht klassisches Simulatorfenster. CUA neu initialisieren und tatsächlichen Screenshot lesen; Koordinaten nicht aus diesem Handoff raten.
- Verbundenes physisches iPhone: „iPhone von Luke (2)“, iPhone15Pro; zuletzt wieder verfügbar. ExpoGo-Installation/Gerätekonfiguration erneut prüfen.
- Supabase-Konfiguration nur ignorierte .env.local im Expo-Projekt, publicURL/publishableKey. Geheimnisse nie ausgeben, nie OpenAI-/serviceRole-Key in Client.
- Private Gerätebackup-Datei dauerhaft separat in dieser lokalen Sicherung `private/prague-album-iphone-backup.json` (falls vorhanden); nicht in Git/öffentliche Handoff-Dateien übernehmen.
- Node22.23.1 unterstützt node:sqlite/registerHooks/TypeScript-Stripping für scripts/check-assistant.mjs.
- `npm audit`:32 Advisories (20high12moderate), blindes --force würde SDK stark downgraden, daher nicht ausgeführt.
- Expo-AGENTS verlangt versionierte SDK57-Doku vor API-Nutzung. Gelesen: SQLite/Location/Clipboard/Sharing/ImagePicker/ImageManipulator/FileSystem/Crypto; FileSystem-Markdown lag unter /tmp/expo57-filesystem.md. APIs bei Fortsetzung gezielt nachlesen.

## Letzter Arbeitscheckpoint · 03.10.2026

- `npx tsc --noEmit`, `npx expo lint`, `check-documents`, `check-map`, `check-media`, `check-assistant`, `check-itinerary` und `npx expo-doctor` bestanden.
- Sammlung-Store und Screen sind jetzt verbunden: lokale Beiträge, kanonische Linkdedupe, bounded Link Preview, Kommentare, Herzen, Löschen via Tombstone, manuelles PlaceLink/Unlink, Versions-CAS im Trip-Sync. `check-collection.mjs` prüft den echten Store samt Offline-Persistenz und Tombstones.
- Erinnerungsansicht `/memories` ist von der Reiseübersicht aus erreichbar und listet besuchte Orte chronologisch nach Tag mit Ortsfoto.
- Designfeedback umgesetzt: Expo lädt nun die lizenzierten Fraunces-/Instrument-Serif-Fonts aus dem Swift-Projekt; Startkarten sind kompakter und die redundante Tab-Kopfleiste entfernt.
- Der Simulator-Test wurde zuletzt nicht erneut ausgeführt. Mac UI war gesperrt; beide physischen iPhones und reale Zwei-Geräte-Synchronisierung bleiben die maßgeblichen offenen Kriterien.

## Designparität-Checkpoint · 03.10.2026

- Verbindliche Vorlage ist die native Swift-App, beschrieben in `DESIGN.md` und implementiert u. a. in `Album/AlbumRoot.swift`, `Album/Stitch/ReiseView.swift` und `Album/InboxView.swift`.
- Expo-Reiseübersicht auf Reise-Header, 4.–9. Oktober-Tagesstreifen, Tagesplan, Unterlagen-Tickets und offenen-Ideen-Hinweis umgebaut. Assistent bleibt als globale schwebende Schaltfläche, Sammlung sitzt als Segment in Ideen; Tabnavigation ist auf Reise/Ideen/Karte reduziert.
- Neue Design-Änderungen liegen ausschließlich im Expo-Projekt. Bestehende Swift-Änderungen nicht zurücksetzen.
- TypeScript nach Layout und Navigation bestanden. Simulatoraufnahme zeigte nicht die App: die vorhandene Expo Go 367.5.1-Laufzeit kennt das SDK57-Modul `ExpoAsset` nicht. `expo-dev-client` und natives `ios/` wurden durch Prebuild erzeugt; iOS-Build stoppte mit `ENOSPC` (Datenträger voll). Nur die wiederherstellbaren Xcode-/CocoaPods-Caches und das fehlgeschlagene `PragAlbum`-DerivedData wurden bereinigt; verbleibende freie Kapazität reicht weiterhin nicht für einen vollständigen nativen Build.
- Nächste Schritte: erst lokalen Speicher freigeben, dann Simulator-Client installieren und Reisebildschirm mit Swift vergleichen; danach Ideen- und Kartenscreens angleichen, Fonts/Farbwerte/Abstände konsistent halten, abschließend Lint/Export/Regressionsprüfungen. Aktuelle App kann über Expo Go im Simulator derzeit nicht gestartet werden; native Projektverifikation steht aus.

## Empfohlene Startprüfungen

Im Expo-Ordner: npx tsc --noEmit; npx expo lint; node scripts/check-assistant.mjs. Zusätzlich node scripts/check-media.mjs. Danach laufende Itinerary-Review abschließen und integrieren. EXPO-FUNCTION-PARITY.md pflegen; keine bereits abgeschlossenen Arbeitsschritte neu beginnen.
