# Vollstaendige App-Abnahme — Sol 6.1

Ziel: jede erreichbare Funktion und jede Bewegung/Haptik pruefen, reproduzierbare Bugs durch Luna beheben und nachpruefen. Dieser Plan verkleinert das Nutzerziel nicht. Ein gruener Build allein ist keine Abnahme.

## Ablauf und Rollen

Sol 6.1 (Parent) erstellt Test- und anschliessend Fixplan, beurteilt Beweise und integriert. Luna fuehrt getrennte Test-/Fixpakete aus. Maximal drei Luna-Auftraege gleichzeitig; mehrere Wellen. Native Computer-Steuerung hat genau einen Besitzer. Nur ein Build/Test-Prozess pro Konfiguration/DerivedData. Produktionsdaten und bestehende fremde Aenderungen bleiben erhalten.

1. Aktuellen Stand inventarisieren, Testdaten isolieren, Debug/Release und vorhandene gesamte XCTest-Suite pruefen.
2. Luna-Welle 1: (A) vollstaendiges Motion-/Haptik-/Accessibility-Inventar, (B) funktionale Daten-/Sync-/Import-Pruefung, (C) echte Bedienung Karte/Drawer/Detail via Computer.
3. Luna-Welle 2: (D) Ideen/Swipe/Editor/Sammlung/Share, (E) Reise/Tickets/Tagesplanung/Dokumente/Erinnerungen/Einladung, (F) Rotation/Dynamic Type/Reduce Motion/Fehler-/Offline-Zustaende. CUA-Pakete laufen nacheinander, Quellpruefungen parallel.
4. Sol bewertet jeden Fund und erstellt einen Fixplan mit Ursache, Eigentumsgrenzen und Regression. Luna behebt voneinander unabhaengige Pakete; keine gleichzeitigen Aenderungen derselben Dateien.
5. Betroffene Tests plus echter Ablauf erneut; anschliessend kompletter Durchlauf am finalen Stand. Neue Funde wiederholen den Zyklus.

## Pruefmatrix

Jede Zeile benoetigt Normalfall, Abbruch, Wiederholung, schnelle Eingabe/Unterbrechung, Scroll/Tastatur, Rotation, grossen Text und Wiederstart soweit zutreffend.

| Bereich | Konkrete Abnahme |
| --- | --- |
| Einstieg/Navigation | Namenseingabe, alle Tabs, Toolbar, Clipboard-Hinweis, verschachtelte Sheets, Schliessen/Zurueck |
| Reise | Tagwechsel, Pull-to-refresh, Ticket auf/zu, Flug/Hotel, naechster Halt, erledigt/Undo, Dokumente, Erinnerungen |
| Ideen | dafuer/dagegen/offen, langsamer/kurzer/schneller Swipe, Umkehr/Abbruch, Buttons, Undo, leere Liste, Fotoansicht |
| Editor | Text/Link/Ort/Kategorie, Google-Redirect, TikTok/Instagram, Kandidaten bestaetigen, veraltete Requests, manueller Ort, Bildwahl/Fallback, Speichern/Abbrechen/Fehler |
| Karte | Pin waehlen -> richtiger Listeneintrag, Cluster, Filter, Ortung, Routing, vollstaendige Karte, alle Drawer-Hoehen, Scroll/Drag-Konkurrenz, X und Drag gleicher Endzustand, Umkehr und Rotation mitten im Ziehen |
| Detail/Fotos | bearbeiten, Besuch/Undo, Originalquelle, Gallery, Viewer oeffnen/schliessen, Lade-/Fallbackzustand |
| Tagesplanung | Vorschlag/Abbruch/Anwenden, manuelles Ordnen/Tagwechsel, leere Tage, konsistente Reise/Karte |
| Sammlung | Text/Link, Originalquelle, fehlende Vorschau, Kommentare, Herzen an/aus, mehrere Orte, entfernen/loeschen, Duplicate-Link, Neustart, Offline |
| Teilen-Menue | URL/Text/Notiz, Abbruch, fehlender Kontext, gemeinsame Ablage, genau einmal importieren, falsche Reise, kaputte Queue, Wiederholung |
| Dokumente | PDF-Import/Lesen/Extraktion/Anwenden/Abbruch, Original persistiert, ungueltige Datei |
| Zusammenarbeit | Einladung Erfolg/Fehler/Wiederholung, Mitglieder, zwei Clients, Offline-Retry, CAS, fremder Zugriff, Realtime |
| Allgemein | Hell/Dunkel, alle unterstuetzten Orientierungen, Dynamic Type bis Accessibility, VoiceOver-Reihenfolge/Labels/44pt-Ziele, Reduce Motion/Transparency/Contrast, Bildschirm-/Hintergrundwechsel |

## Motion- und Haptik-Beweis

Luna A liefert jeden konkreten Trigger und jede Transition aus aktuellen Quellen. Pro Eintrag: Aktion, erwartet/ist, kontinuierliches Tracking, Umkehr/Unterbrechung, Endzustand, Reduce Motion und Beweis. Ruhige Endpunkt-Screenshots beweisen keine fluessige Animation. Gefrorene DeviceHub-Videos gelten nicht als Motion-Beweis. Aktuelle native Bedienung und verifizierbare bewegte Aufnahmen sind erforderlich; gemessene FPS nur mit geeigneter Messung.

Haptik: Trigger/Mehrfachausloesung und Timing technisch pruefen; taktiles Gefuehl benoetigt echtes iPhone. Simulator-Ausgabe oder Quellcode allein beweist keine fuehlbare Qualitaet. Geraetesignierung/Apple-Konto und physische Abnahme sind explizite Gates, keine stillen Ausnahmen.

## Fundformat / Fertig-Gates

Jeder Fund: ID, Prioritaet, Build/Store/Geraet, Schritte, erwartet/ist, Beweis, Ursache (oder Hypothese), Fixeigentum, Nachtest. Status offen/bestaetigt/behoben/nachgeprueft/blockiert. Quellverdacht getrennt von reproduziertem Fehler.

Fertig erst bei vollstaendigem Inventar und Abdeckung, allen behobenen/nachgeprueften relevanten Bugs, finalen funktionalen/visuellen/Motion-/Haptik-Beweisen und erfolgreichem Geraete-/Share-/Mehrteilnehmer-Test. Fehlender Zugriff oder nicht beobachtbare Haptik bleiben offen. Fortschritt: QA-FULL-STATUS.md; keine pauschale Behauptung 'alle Tests bestanden' fuer ungetestete Bereiche.
