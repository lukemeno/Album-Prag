# Übergabe: Expo Itinerary-Slice

Arbeitskopie: `/tmp/prague-expo-itinerary-20261003`

## Dateien

- `src/domain/opening-hours.ts`
  - Prüft den unterstützten OSM-Teilbereich ohne Netzwerk.
  - Unterstützt Wochentage, Zeitbereiche, `off`/`closed`, `24/7` und Bereiche über Mitternacht.
  - Unbekannte oder nicht parsebare Regeln bleiben `unknown` (`null`).
- `src/domain/itinerary.ts`
  - Plant 4.–9. Oktober 2026.
  - Rechnet Anreisetag `Ankunft + 90 Minuten`, Abreisetag `Abflug - 165 Minuten`.
  - Filtert bestätigte, aktive, lokalisierte Orte ohne Unterkunft.
  - Behält bestehende Tage optional, priorisiert wenige Öffnungstage, begrenzt Mahlzeiten auf zwei und Tageslast auf 85 %.
  - Haversine, nearest-neighbor, 2-opt, Mahlzeitenabstand und sichtbare Warnungen/Restliste.
  - Orte ohne Koordinaten werden mit Grund `missing_coordinates` in der Restliste behalten.
- `src/storage/itinerary-actions.ts`
  - Erstellt lokale Vorschauen mit Snapshot aus Reise-/Album-Settings und relevanten Place-Feldern.
  - Wendet Vorschauen atomar mit Scope-/Snapshot-Prüfung an.
  - Ändert nur `day`, `day_order`, `updated_at`; Abstimmungen bleiben unverändert.
  - Undo prüft Scope und unveränderte Post-Apply-Fingerprints und stellt nur geänderte Zuweisungen wieder her.
- `src/storage/opening-hours-service.ts`
  - Lädt fehlende Öffnungszeiten nur auf explizite Aktion über Overpass (80 m, Titel-Token-Jaccard mindestens 0,5, maximal drei parallele Anfragen, 20-Sekunden-Abbruch).
  - Aktualisiert nur noch immer leere, identische lokale Datensätze innerhalb einer Transaktion; Reisewechsel, Identitätsänderungen und Abbruch werden erkannt. Trefferlos bleibt `''`, Netzfehler bleibt `null`.
- `src/app/itinerary.tsx`
  - Deutsche Vorschau mit Tagen, Zeitfenstern, Slots, Öffnungszeitenwarnungen und Restliste.
  - Explizite Buttons für Vorschau, Übernahme und Rücknahme.
  - Gemeinsame Reise wird vor Apply/Undo synchronisiert; veraltete Antworten werden angezeigt.
  - Öffnungszeiten-Button, Status für geladen/unbekannt/Fehler, synchroner Busy-Schutz und Abbruch bei Unmount.

- `scripts/check-itinerary.mjs`
  - Reproduzierbare Node/SQLite-Prüfung mit echter `migrateDatabase`- und `itinerary-actions`-Ausführung.
  - Prüft Overnight-Regeln, unbekannte Öffnungszeiten, geklemmte Flugfenster, Restliste, ungültige/duplizierte Tage, atomaren Rollback, Abstimmungserhalt, No-op-Zeitstempel, stale edits, neue bestätigte IDs, Scope-Wechsel und Undo-Konflikte.

Route und Einstieg bleiben beim Parent gemäß Ownership.

## Prüfungen

- `npx tsc --noEmit` erfolgreich.
- `npx expo lint` erfolgreich, ohne Warnungen.
- `node scripts/check-itinerary.mjs` erfolgreich: Overnight/unknown, geklemmte Fenster, algorithmische Restliste sowie atomare SQLite-Regressionsfälle.
- `npx tsc --noEmit` erfolgreich.
- `npx expo lint` erfolgreich, ohne Warnungen.

## Grenzen

- Es gibt keine automatische OSM-/Overpass-Abfrage. Der Button lädt nur fehlende Werte; vorhandene `opening_hours`-Werte werden nie überschrieben und unbekannte Werte bleiben sichtbar.
- Flugzeiten werden aus dem gespeicherten `trip.flights`-Array gelesen; bei fehlenden/ungültigen Zeiten gelten die nativen Fallbacks.
- Der Parent muss die Route registrieren und einen Einstieg aus der Reise-/Kartenoberfläche ergänzen.
