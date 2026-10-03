# Album: Nachtlauf mit Luna

Plan von Sol, 03.10.2026. Dieser Plan startet keinen Lauf und keine Automation.

## Ziel und Umgebung

Eine neue lokale Codex-Session mit Luna fuehrt die offenen Abnahmen aus und liefert
einen verifizierbaren Morgenbericht. Vorgesehener Hoechstrahmen: sechs Stunden ab
Start, einschliesslich Aufraeumen und Bericht. Fertige Pakete nicht weiter pollen
oder ohne Anlass wiederholen. Unzugreifbare Einzelpruefungen blockieren nicht den Rest.

Projekt:
`/Users/alexandergorny/.codex/.chatgpt-projects/g-p-6aabf1a8b2b48191be855674e1d66a30/Album`

Bestehender QA-Simulator:
`A297FE47-FA5E-468A-8D14-40DFD2AAC71D` (iPhone 17 Pro, iOS 26.5).
Die ebenfalls gestarteten Simulatoren Album Ansicht und Album Codex gehoeren
nicht diesem Lauf. Nicht bedienen, zuruecksetzen oder herunterfahren.

Xcode-Scheme `Album QA`, Testplan `Album-QA-Full`.
Bestehende DerivedData:
`/Users/alexandergorny/Library/Developer/Xcode/DerivedData/Album-cjjfafycoualizgshgnastorleed`

Eine gewoehnliche Cloud-Session kann diesen lokalen Xcode-/Simulatorlauf nicht
ersetzen. Das Repository hat derzeit keinen Git-Remote; der Arbeitsstand enthaelt
viele uncommittete Aenderungen. Ein frischer Cloud-Checkout waere deshalb auch kein
Nachweis fuer diesen Stand. Cloud nur als optionale getrennte Quellpruefung.

## Bereits bestaetigt: nicht wieder von vorne beginnen

- Gesamte aktuelle Unit-Suite: 124 bestanden; vier explizite Skips
  (drei Live-Opt-ins und echtes Buchungs-PDF).
- Native Share-Extension: Abbrechen erzeugt keinen Post, Speichern genau einen,
  Neustart keinen zweiten. Zusammen mit Collection-/Store-Regressionen 27 bestanden.
- Echtzeit: echter initialer Abgleich und Place, CollectionPost, Kommentar/Herz,
  Trip mit zwei getrennten Teilnehmern; Stop entfernt Kanal und weitere Callbacks.
- Echte Storage-Roundtrips fuer JPEG/PDF einschliesslich Reload und Cache-Reparatur.
- Maximale OS-Schrift: Ideenkarte ohne Textueberlappung, Ja/Nein erreichbar,
  Scrollen legt die Karte nicht als Offen weg; vier Rand-Taps oeffnen den Editor.
- Normale Ideenbedienung nach Layoutfix: Ja/Undo/Neustart und gegenlaeufige
  unterschwellige Gesten bestanden.

Beweise stehen in den letzten Eintraegen von `QA-FULL-STATUS.md`. Das Dokument ist
chronologisch: alte Fehler-/Aktivmeldungen nicht als aktuellen Zustand behandeln.
Aktuelle Quellen und Laufrevisionen sind massgeblich.

## Ablauf: ein Ausfuehrer fuer Simulator und Live-Backend

Luna ist der Controller und besitzt exklusiv Builds, Simulator, Computerbedienung,
Live-Clients und Cleanup. Maximal zwei zusaetzliche Luna-Agenten duerfen parallel
klar getrennte Quellen oder vorhandene Medien lesen. Keine zweite Simulator-
Steuerung, kein zweiter Build, kein paralleler Live-Test. Kein redundantes Panel.
Der Lauf in diesem bisherigen Chat darf nicht gleichzeitig weiter testen.

### 1. Start und Zugangscheck — etwa 15 Minuten

1. `AGENTS.md`, diesen Plan und die letzten Status-Eintraege lesen. Den vorhandenen
   dirty Arbeitsstand erhalten; Startzeit, Git-Stand und lokale Aenderungen notieren.
2. Pruefen, ob noch fremde Build-/Testprozesse laufen. Bei Konflikt betroffenen
   Zugriff auslassen, keine fremden Prozesse beenden.
3. Einmal Computerzugriff pruefen. Bei Sperre/AX-Fehler native Bedienung als
   blockiert markieren; automatisierte Simulator-Tests trotzdem durchfuehren.
   Keine Endlosschleife und kein Umgehen der Sperre.
4. Simulator-/Systemeinstellungen und vorhandenen AppGroup-Kontext/Queue sichern.
   Ausschliesslich isolierte `slot-night-<UUID>` Stores und synthetische Daten nutzen.
5. Ergebnisse unter `qa-night/<run-id>/` im Projekt speichern: Manifest, Logs,
   xcresults, Medien und Fortschritt. Keine Zugangsdaten in Ausgaben speichern.

### 2. Offene Pakete — priorisiert, insgesamt etwa 3 bis 4 Stunden

| Paket | Pruefung | Nachweis / Erfolgskriterium |
| --- | --- | --- |
| N1 Karte und Bewegung | Pin -> gleiche Listenzeile; alle Drawer-Hoehen; X vs Herunterziehen; langsames Ziehen, Umkehr, Scrollen und Rotation waehrend Bedienung; Foto-/Detail-Uebergaenge | Erwarteter Endzustand, kein Springen/Haengen/versehentlicher Aktion. Native bewegte Aufnahme soweit zugreifbar. XCTest-Endpunkte allein nicht als Fluessigkeitsnachweis ausgeben. |
| N2 Verbindungsunterbrechung | Zwei isolierte Teilnehmer; Testclient-Verbindung gezielt unterbrechen; Partner aendert Ort/Post/Kommentar/Herz; Verbindung wiederherstellen und App-Rueckkehr pruefen | Daten konvergieren, keine Duplikate oder verlorenen lokalen Aenderungen, kein mehrfacher Kanal/Callback. Reine Mock-Tests und absichtliches SDK-Disconnect sauber von echtem unerwartetem Netzausfall unterscheiden. Niemals das WLAN des Macs oder anderer Geraete abschalten. |
| N3 Dokument-Realtime | Bestehendes Swift-Live-Gate um Dokument hinzufuegen/aendern/entfernen erweitern; zwei echte QA-Clients | Partner sieht die richtige Dokument-ID und Metadaten ueber produktiven Callback. Reload und bestehender PDF-Download konsistent. Speicherung und Event-Empfang getrennt belegen. |
| N4 Darstellung/Bedienbarkeit | Verbleibende Reise-/Editor-/Ideen-/Karten-Audits; normal und maximale Schrift, passende Orientierungen, wichtige Aktionen und Scroll-/Tastaturzustaende | Screenshot plus AX-Befund. Sichtbare Fehler von Audit-only-Meldungen trennen; keine pauschalen Suppressions. Deaktiviertes Speichern oder native visuelle Button-Groesse nicht ohne Pruefung als Produktfehler werten. |
| N5 Echte Systemeinstellungen und Import | Reduce Motion im QA-Simulator ueber tatsaechliche iOS-Einstellung pruefen, danach zurueckstellen; echtes Buchungs-PDF falls bereitgestellt | Lauf darf `ALBUM_QA_REDUCE_MOTION=1` nicht als OS-Nachweis verwenden. PDF: Import, Extraktion, Abbruch/Anwenden und Neustart. Ohne echte Datei bleibt genau dieses Gate offen; synthetische PDFs separat pruefen. |

Fuer N1 jeden Bewegungstyp einmal langsam, einmal schnell und einmal mit Abbruch
pruefen. Keine ungezaehlten Zufallsklicks. Fuer N2/N3 jeweils drei frische,
vollstaendig bereinigte Durchlaeufe; bei reproduzierbarem Fehler sofort zum Fund
wechseln, nicht weitere Testnutzer erzeugen.

## Fehlerbehandlung und Fixgrenzen

- Pro Fund: Prioritaet, genaue Schritte, erwartet/ist, Build/Store, Nachweis und
  betroffene Dateien. Vermutung getrennt von reproduziertem Fehler dokumentieren.
- Hoechstens ein unveraenderter Wiederholungsversuch zur Flake-Pruefung. Weitere
  Laeufe nur nach konkreter Diagnose, Code-/Fixture-Aenderung oder gezieltem Experiment.
- XCTest-Zusammenfassung zeigt eventuell nur den ersten Fehler: vollstaendige
  Activities auswerten. Testselektoren anhand der tatsaechlichen Hierarchie korrigieren.
- Ein defekter Testselektor oder eine klar abgegrenzte Fixture darf repariert werden.
  Keine Assertion abschwaechen, Timeouts einfach aufblasen oder Skips als Pass ausgeben.
- Neue Produktfehler erhalten einen minimalen Fixvorschlag mit Regression fuer Sol.
  Keine unbeaufsichtigte Architektur-, Auth-, Schema-, Designsystem- oder
  Gesten-Neuentwicklung. Keine neuen Features. Nach bereits konkret vorgegebenem
  Fixplan darf Luna den kleinen Fix ausfuehren; sonst morgens Sol-Review.
- Nach einem Produktfix passende Regressionen und betroffene Bedienablaeufe erneut
  pruefen. Genau einmal finale Suite am letzten Stand; nicht jede kleine Probe mit
  einem erneuten kompletten Durchlauf kombinieren.

## Laufzuverlaessigkeit und Datensicherheit

- Nach Build App und UI-Runner ausdruecklich frisch installieren. Aktuelle
  Testrevision und erwartete Methodenzahl kontrollieren; alte Bundles waren eine
  reale Fehlerquelle. Neue Dateien auch in Xcode-Compile-Sources registrieren.
- Ad-hoc-Simulator-Signierung mit vorhandenen Entitlements erhalten. Kein
  Apple-Konto veraendern, keine AppGroup-Entitlements entfernen, keine Geraetesignierung
  umgehen. Keine Commits, Pushes oder Deployments.
- Vor jedem Live-Request Pflicht-Receipt mit restriktiven Dateirechten anlegen.
  Beide Stores erhalten `NoBackgroundSyncService`: `syncService=nil` isoliert nicht.
  Exakt zwei urspruengliche Session-/Membership-IDs verlangen.
- Projekt `akzrlkbylglwrlbaacjo` nur im bereits autorisierten, synthetischen QA-Umfang.
  Ausgangswerte neu lesen; zuvor waren es 1 Trip, 3 Mitglieder, 0 Collection-Eintraege,
  0 markierte QA-Nutzer. Keine persoenlichen Inhalte fuer Fixtures nutzen.
- Nach jedem Live-Lauf ausschliesslich Receipt-verifizierte QA-Objekte bereinigen:
  Storage zuerst ueber Storage-API, dann verifizierte QA-Reise/Auth-IDs mit
  Membership-/Metadaten-Guards. Niemals globale Loeschungen oder direkte Storage-SQL.
  Bei unklarer Ownership abbrechen und Restobjekte mit Receipt dokumentieren.
- AppGroup-Originalzustand erhalten/wiederherstellen, nur nachgewiesene eigene
  Queue-/Context-Aenderungen entfernen. Auch Unit-Tests koennen dort schreiben.
- OS-Schrift, Erscheinungsbild und Reduce Motion am Ende auf den gesicherten
  Ausgangswert zurueckstellen. Keine Simulator-Erases oder Loeschung der Haupt-Appdaten.

## Abschluss — letzte 30 bis 60 Minuten reservieren

Vor Ende des Sechs-Stunden-Rahmens keine neuen Pakete beginnen. Eigenen laufenden
Test geordnet beenden bzw. auswerten, eigene QA-Daten und Einstellungen aufraeumen.
Nicht auf einen unerreichbaren Computer oder eine nicht vorhandene PDF-Datei warten.

`QA-NIGHT-REPORT.md` erstellen mit:

1. kurzer Entscheidung: was ist verifiziert, welche konkreten Bugs bleiben;
2. Tabelle N1 bis N5: bestanden / fehlgeschlagen / blockiert / nicht ausgefuehrt,
   samt direktem xcresult-/Mediennachweis und Grund;
3. neue Fehler mit Prioritaet und minimalem Fixplan fuer Sol;
4. Aenderungen an Test-/Produktdateien und Ergebnisse der Nachtests;
5. Cleanup, wiederhergestellte Einstellungen und etwaige eigene Restobjekte;
6. menschlicher iPhone-Check: Haptik fuehlen und Bewegungsqualitaet beurteilen.

Der Bericht ist das Ergebnis des Nachtlaufs. Eine gefuehlte Haptik-Abnahme oder
'alles fertig' darf er nicht vortaeuschen. `QA-FULL-STATUS.md` mit knapper,
aktueller Zusammenfassung ergaenzen und anschliessend stoppen.

## Vorbereitung durch den Nutzer

- Neue **lokale** Session am bestehenden Album-Projekt; Modell **Luna**.
- Mac am Strom und fuer die Laufdauer wach. Bildschirmsperren nicht umgehen:
  falls native Bedienung dadurch ausfaellt, verbleiben automatisierte Tests und Bericht.
- Den bisherigen Chat nicht gleichzeitig am Simulator weiterarbeiten lassen.
- Optional eine echte Beispiel-Buchungs-PDF mit lokalem Pfad bereitstellen.
- Dieser Plan ist vorbereitet; der Nachtlauf ist noch nicht gestartet.
