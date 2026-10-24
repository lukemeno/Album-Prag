# Planung: Ortsvorschläge und schneller Kamerazugriff

Stand 24.10.2026. Nutzerentscheidungen: Ortsvorschläge zuerst am Reiseziel suchen, Suche bewusst auf andere Städte erweiterbar; Kamera als eigener Punkt im vorhandenen Aktionsmenü. Das ist ein lokaler Issue-Entwurf, keine Umsetzung. Plan Mode wurde vorgeschlagen, der aktuelle Modus ist Default.

## Bestehender Anschluss
`Album/PlaceEditor.swift` hat bereits ein separates Feld „Ort oder Adresse“ mit MapKit `MKLocalSearch`, Trip-Kontext, Ergebniszeilen sowie Abbruch-/Generationenschutz. Das Namensfeld startet bisher keine Suche. Die Reiseshell hat ein gemeinsames Vierer-Aktionsmenü; „Erinnerungen“ öffnet eine Ansicht mit separater Kamerafunktion.

## Issue-Entwurf 1: Passende Orte beim Eingeben des Namens vorschlagen
**Ziel:** Unter Ideen → Neue Idee schlägt die App beim Tippen von z.B. „Pasta Fresca“ konkrete Restaurants und Orte in der Zielstadt vor.

**Umfang:** Suche ab zwei eingegebenen Zeichen, kurze Tipp-Pause vor der Abfrage, bis zu fünf Treffer mit Name, Kategorie und Adresse/Stadt. Zielstadt der Reise ist der Suchkontext. Laden, kein Treffer und Fehler erhalten verständliche Zustände. Texteingabe bleibt auch ohne Netz oder Treffer speicherbar. Keine Live-GPS-Position.

**Akzeptanz:**
- Nur Ergebnisse für den aktuellen Text erscheinen; geänderte Eingabe und geschlossenes Formular verwerfen ältere Antworten.
- Mehrere gleichnamige Orte bleiben getrennt auswählbar.
- Kein Treffer wird automatisch ausgewählt und kein Resultat wird als existierender Ort vorgetäuscht.

**Abhängigkeiten:** Baut auf vorhandener PlaceEditor-/MapKit-Suche auf; keine zweite Providerintegration ohne Grund. Unabhängig von Kamera.

**Prüfung:** „Pasta Fresca“ im Testziel Prag zeigt reale passende Treffer; kurze Texte und kein Treffer; langsame Antworten in vertauschter Reihenfolge; Abbruch/Schließen; offline; VoiceOver-Beschriftungen.

## Issue-Entwurf 2: Treffer bestätigen, Ort übernehmen und Suchgebiet erweitern
**Ziel:** Ein ausgewählter Treffer wird eindeutig mit der Idee verbunden und kann bei Bedarf außerhalb der Zielstadt gesucht werden.

**Umfang:** Auswahl übernimmt kanonischen Namen, Kategorie, Adresse und Koordinaten in den noch ungespeicherten Entwurf. Bildsuche und Kartenposition nutzen denselben bestätigten Ort. „In anderer Stadt suchen“ erweitert den Suchkontext, bis der Nutzer ihn zurücksetzt. Freie Ideen ohne Treffer bleiben unterstützt. Bearbeiten einer bestehenden Idee ordnet den Ort nicht stillschweigend neu zu.

**Akzeptanz:**
- Vorschauantippen erzeugt noch keine gespeicherte Idee; Speichern bleibt der klare Bestätigungsschritt.
- Änderungen am Namen nach Auswahl lösen die alte Ortsbindung und Bildzuordnung nachvollziehbar.
- Notiz, Link und andere Entwurfsfelder bleiben bei der Trefferauswahl erhalten.
- Dubletten-/QID-Prüfung greift bei erneuter Auswahl und Speicherung.

**Abhängigkeiten:** Issue 1; vorhandene Orts- und Bildmodelle.

**Prüfung:** Treffer auswählen und abbrechen, falschen von zwei gleichnamigen Treffern wählen, Titel nach Auswahl ändern, Ort über Suchbereich erweitern, speichern/neu öffnen, Bild-/Kartenidentität sowie Dublettenschutz prüfen.

## Issue-Entwurf 3: Kamera direkt im gemeinsamen Aktionsmenü öffnen
**Ziel:** Die Kamera mit einem Tipp weniger aus jedem Reisetab erreichen.

**Umfang:** Das vorhandene Aktionsmenü bekommt einen klar beschrifteten Punkt „Kamera“, der den vorhandenen Aufnahmeablauf in Erinnerungen öffnet. „Erinnerungen“ bleibt ein eigener Menüpunkt. Keine neue zweite Aufnahmelogik.

**Akzeptanz:**
- Kameraaktion ist aus Plan, Ideen, Karte und Gruppe erreichbar.
- Auswahl öffnet den vorhandenen Aufnahmebildschirm; Zurück/Abbrechen kehrt in den vorherigen Reisezusammenhang zurück.
- Die erste nötige Systemabfrage für Kamerazugriff und bestehende Foto-Speicherung funktionieren unverändert.
- Fünf Menüaktionen bleiben auf kleinen Displays unterscheidbar, bedienbar und mit VoiceOver benannt.

**Abhängigkeiten:** Bestehende Fan-Menü- und Erinnerungs-/Kamerarouten; unabhängig von den Ortsvorschlägen.

**Prüfung:** Manueller Simulatorlauf aus jedem Reisetab, Menülayout auf iPhone-Größe, VoiceOver-Namen, Kamera-Abbrechen und Foto in Erinnerungen wiederfinden. Echte Kamera-Hardware separat prüfen, da Simulatorhardware keine vollständige Geräteabnahme ersetzt.

## Umsetzungsreihenfolge
Issue 1 → Issue 2. Issue 3 kann unabhängig parallel umgesetzt werden. Abschließender kombinierter App-/Simulatordurchgang.

## Linear
Es gibt kein Linear-Projekt „Album“ in der verbundenen Workspace-Suche. Der einzige sichtbare Team-Bereich heißt „Codex“; ich habe dort keine Produkt-Issues angelegt. Diese drei vollständigen Entwürfe bleiben lokal, bis ein passendes Team/Projekt benannt wird.
