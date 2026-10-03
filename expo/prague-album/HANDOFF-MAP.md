# Übergabe: Expo Karten-/Tagesrouten-Slice

Arbeitskopie: `/tmp/prague-expo-map-20261003`

## Dateien

- `src/domain/map-route.ts`
  - Endliche Koordinaten und Hotel-Fallback Altstadt.
  - Filter Alle/Bestätigt/Besucht/Reisetag, Entfernungssortierung und Haversine.
  - Google-Maps-Fußrouten beginnen/enden am Hotel. Bei vielen Stopps werden überlappende Abschnitte mit höchstens fünf Punkten und höchstens drei Waypoints erzeugt.
- `src/storage/map-actions.ts`
  - Vollständiger Snapshot aus Album-/Trip-Scope und allen aktiven bestätigten Orten, einschließlich Orten ohne Koordinaten.
  - Atomare Tageszuweisung, Entfernung, Reassign, Besuchsstatus und Koordinatenspeicherung mit Scope-/Identitätsprüfung, lückenlosen Reihenfolgen, monotonen Zeitstempeln und Abstimmungserhalt.
- `src/app/(tabs)/karte.tsx`
  - Kartenfilter, Marker-Details mit Editor-Link, Tagesliste inklusive fehlender Koordinaten, Auf/Ab, Entfernen, Tageswechsel und Besuchsstatus.
  - Expliziter Standortbutton mit Berechtigungs-/Timeout-Handling, gespeicherte Pins bleiben offline sichtbar.
  - Geocode-Treffer werden zuerst angezeigt und erst nach Auswahl gespeichert; keine automatische Ersttreffer-Speicherung.
  - Routenabschnitte werden über eigene Etappenbuttons einzeln in Google Maps geöffnet; ausgelassene Orte ohne Koordinaten werden ausdrücklich genannt.
  - Die Kartenliste bleibt in einem vertikal scrollbaren Panel bedienbar; Filter vergleichen Tageswerte semantisch.
  - UI-Snapshots werden vor jeder Tagesänderung gegen frische SQLite-Zeilen verglichen. Geocode-Suchergebnisse tragen Ortidentität, Snapshot und Generation und verfallen bei Änderungen.
  - Jede Etappe wird separat geöffnet; ohne gültige Stopps entsteht keine Hotel-zu-Hotel-Route. Bei GPS werden nahe Orte als auswählbare Liste mit Entfernung gezeigt.
  - Link zur Tagesplanung `/itinerary`.
- `src/storage/place-editor.ts`, `src/app/place/[id].tsx`
  - Öffnungszeiten-Feld, Speicherung für INSERT/UPDATE und unterstützte Parserprüfung.
  - Unveränderte bestehende unbekannte Texte bleiben erhalten und werden als unbekannt angezeigt; neue ungültige Werte werden abgelehnt.
- `src/storage/place-store.tsx`
  - `assignDay` validiert Reisetage, normalisiert nur betroffene bestätigte Tage und schreibt nur echte Änderungen mit monotonen Zeitstempeln.
  - `setCoordinates` validiert Koordinaten, liest die aktuelle Zeile transaktional, behandelt No-op-Koordinaten und entfernt bei Ortswechsel automatisch erzeugte Medien/Galerie/Öffnungszeiten.
- `scripts/check-map.mjs`
  - Reproduzierbare Algorithmus- und echte SQLite-Prüfung.

## Prüfungen

- `node scripts/check-map.mjs` erfolgreich: Koordinatenwächter, vollständige Routenabschnitte, Google-Maps-Limit, Nearby-Sortierung, atomare Reihenfolge/Entfernen/Reassign, Stimmen, No-op, Stale-, Scope- und Rollback-Fälle.
- `node scripts/check-media.mjs` erfolgreich.
- `npx tsc --noEmit` erfolgreich.
- `npx expo lint` erfolgreich ohne Warnungen.

## Grenzen

- Geocoding nutzt Expo Location nur nach ausdrücklicher Nutzeraktion; Treffer müssen ausgewählt werden.
- Google Maps wird als externe URL geöffnet; es gibt keine eigene Routing- oder Netzwerkdatenbank.
- Der Parent muss Route-/Layout-Änderungen integrieren, sofern sie außerhalb dieser Besitzdateien liegen.
