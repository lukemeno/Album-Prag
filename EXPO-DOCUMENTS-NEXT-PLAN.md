# Nächster Luna-Slice: Reise und Unterlagen

Status: vorbereiteter Plan; noch nicht implementiert. Nach Integration/Review des laufenden Tagesplan-Slices verwenden. Bestehende Funktionen und SQLite-Daten erhalten.

## Ziel

In Expo Go auf iPhones PDF-Originale importieren, offline lesen/teilen und zwischen zwei Reise-Mitgliedern privat synchronisieren. Buchungstext lokal auslesen; erkannte Flüge/Hotel ausschließlich nach überprüfbarer Bestätigung übernehmen. Reiseinformationen manuell bearbeiten.

## Quellen und vorhandene Verträge

- Native: Album/TripDocumentsView.swift, Album/TripDocumentParser.swift, Album/Models.swift (TripInfo, FlightLeg, HotelDetails, TravelDocument).
- Expo: album_settings Schlüssel trip enthält native TripInfo mit Swift-Referenzdatum updatedAt; trip_documents enthält native Dokument-Metadaten. Importierte Dokumente können nur Text und noch kein Original enthalten: ehrlich als fehlendes Original zeigen.
- Backend: supabase/migrations/202609210001_shared_album.sql; documents(trip_id,id,name,filename,extracted_text,storage_path,updated_at), privater trip-files Bucket, PDF ≤25.000.000 Bytes, Pfad beginnt mit tripID. Auth/Membership wie vorhandener trip-sync. Keine neue externe Dokumentenverarbeitung oder API-Schlüssel.
- SDK57 WebView ausdrücklich in Expo Go vorhanden: https://docs.expo.dev/versions/v57.0.0/sdk/webview/ ; SDK-passend über npx expo install.
- Lokales PDF.js: https://mozilla.github.io/pdf.js/getting_started/ und https://mozilla.github.io/pdf.js/examples/ . Keine CDN-Skripte im privaten Dokument-Viewer.

## Erst eine kleine technische Probe

1. SDK57-WebView installieren; ein synthetisches PDF mit zwei Seiten lokal speichern.
2. WKWebView auf lokalem PDF prüfen: Original sichtbar, Seitenwechsel/Zoom, App-Neustart ohne Netz. JavaScript für direkten Original-Viewer abschalten; Zugriff nur auf Dokumentordner.
3. Lokale Textauslese mit gebündeltem PDF.js in WebView prüfen. Display- und Worker-Version identisch, nötige Assets ebenfalls lokal. Kein Versuch, PDF.js direkt in Hermes auszuführen. Bytes/JS-Bridge begrenzen, getTextContent pro Seite mit Zeilenumbrüchen, Ergebnis begrenzt an RN zurückgeben. Netzwerk im Extraktions-Viewer unterbinden. Falls Fake-Worker benötigt wird, lokalen Worker-Bundle im selben JS-Kontext laden; zuerst mit synthetischem Text bestätigen. Passwörter, gescannte/leere PDFs und beschädigte Dateien ergeben sichtbare Meldung statt erfundener Daten.
4. Erst nach funktionierender Probe den kompletten Import integrieren. Wenn das Original nicht zuverlässig darstellbar ist, die konkrete Einschränkung melden und einen funktionierenden lokalen Viewer aufbauen; Teilen alleine ist kein vollständiger Ersatz.

## Dateien / Besitz

Neue domain/trip.ts, domain/trip-document-parser.ts, storage/trip-info.ts, storage/travel-documents.ts, components/document-reader.tsx, app/documents/index.tsx, app/documents/[id].tsx, app/trip-editor.tsx. Benötigte Asset-/Buildskripte klar dokumentieren. Zentrale database.ts/trip-sync.tsx/rootlayout und Reise/Assistant-Links erst nach Parent-Review integrieren; Änderungen als gezielte Patches liefern.

## Persistenz und Sync

- SQLite-Migration eigene lokale Dokumentdatei-Mapping-Tabelle, Dokument-ID stabil; keine privaten Dateien im Repository.
- Picker kopiert in Cache, vor Commit PDF-Signatur/Größe prüfen, dauerhafte UUID-basierte Datei in Paths.document; Namen nicht als Dateipfade verwenden.
- PDF zuerst privat hochladen, anschließend Metadaten veröffentlichen. Fehlendes Original aus Legacy-JSON nicht als leere Datei hochladen. Wiederholungen idempotent; Partnerdownload signiert, begrenzt, lokal cachen; ohne Netz bereits vorhandenes Original öffnen.
- Downloadpfad/Trip-Zugehörigkeit prüfen. Während Netzoperation lokal geänderte Daten nicht durch älteren Snapshot überschreiben. Monotone Zeitstempel; Backend-Updates mit erwarteter Version wie places. Metadaten-/Original-Fehler separat sichtbar halten.
- Realtime documents abonnieren. Reise-Sync muss nur frischere TripInfo übernehmen; aktuelle lokale Änderungen während Await schützen.
- PDF teilen mit expo-sharing. Export/Import darf Originale nicht als übertragen behaupten, wenn nur JSON verfügbar ist. Nach Möglichkeit Original aus vorhandener privater Backend-Datei wiederherstellen; ansonsten user-facing Dateiauswahl zum Ergänzen derselben Dokument-ID.

## Lokale Extraktion und Reiseeditor

- Native Parserregeln gezielt portieren: PDF-Leerzeichen/Ligaturen reparieren, Flugnummer/Datum/Abflug/Ankunft/Route, Buchungscode, Hoteladresse/Check-in/out/Inklusivleistungen/Reisende/Check-in-Hinweis.
- Keine Geburtsdaten/Ausweisnummern übernehmen. Keine heuristischen Treffer still anwenden. Vorschau mit editierbaren Werten und Bestätigung; Vorlage/Trip-Snapshot schützen.
- Manuell Hotel/Adresse, Flüge Hin/Rück, Nummer/Airline/Datum/Zeiten/Route/Flugbuchung, Reisebuchung/Reisende/Notizen bearbeiten; IDs aus direction+number kompatibel. Vorhandene unbekannte Felder erhalten. Hoteleingabe synchronisiert passende Unterkunft nur ausdrücklich, keine automatische falsche Geokodierung.
- Erfolgreicher Save persistiert offline, aktualisiert Reise-/Assistent-/Tagesplan-Kontext und startet regulären Sync.
- Assistent-Dokumentquellen öffnen Dokumentroute; bei vorhandenem Text Ausschnitt zeigen, bei fehlendem Original weiterhin Text verfügbar.

## Nachweise

TypeScript/Lint/iOS-Export; synthetische Parser- und SQLite-Regressionen; ExpoGo echtes Picker/Original/Text/Teilen/Neustart; privater Upload+zweite Identität+Bytevergleich+kein öffentlicher Zugriff; Offline-Reopen und Wiederholung ohne Duplikate. Abschluss auf beiden physischen iPhones bleibt erforderlich.
