# Planung: Ortsvorschläge und Reiseerinnerungen

Stand 24.10.2026. Nutzerentscheidungen: Ortsvorschläge zuerst am Reiseziel, auf andere Städte erweiterbar; Kamera als eigener Punkt im bestehenden aufgefächerten Aktionsmenü; Fotos dürfen ohne Ortsauswahl aufgenommen und später optional mit einem Ort verknüpft werden. Noch lokale Issue-Entwürfe, keine App-Umsetzung. Plan Mode wurde vorgeschlagen, aktueller Modus ist Default.

## Bestehender Anschluss
`Album/PlaceEditor.swift` hat im Feld „Ort oder Adresse“ bereits MapKit `MKLocalSearch`, Reise-Kontext, Ergebniszeilen sowie Abbruch-/Generationenschutz. Das Namensfeld startet bisher keine Suche. Die Reiseshell hat ein gemeinsames Vierer-Aktionsmenü. „Erinnerungen“ öffnet `NativeMemoriesView`; dort muss Kamera und Mediathek heute erst einen existierenden Ort auswählen. `PlaceImageAsset` speichert Fotos bisher als Ortsbild in `Place`; es gibt noch kein separates Fotoobjekt der Reise.

## Issue-Entwurf 1: Passende Orte beim Eingeben des Namens vorschlagen
**Ziel:** Unter Ideen → Neue Idee schlägt die App beim Tippen von z.B. „Pasta Fresca“ konkrete Restaurants und Orte in der Zielstadt vor.

**Umfang:** Suche ab zwei Zeichen nach kurzer Tipp-Pause, höchstens fünf Treffer mit Name, Kategorie und Adresse/Stadt. Das Reiseziel ist der Suchkontext. Laden, kein Treffer und Fehler erhalten verständliche Zustände. Freie Texteingabe bleibt möglich; keine Live-GPS-Position.

**Akzeptanz:** Nur Treffer zur aktuellen Eingabe erscheinen; Antworten älterer Abfragen werden verworfen. Gleichnamige Orte sind unterscheidbar. Kein Treffer wird automatisch ausgewählt oder als echte Ortsidentität vorgetäuscht.

**Abhängigkeit:** Vorhandene PlaceEditor-/MapKit-Suche. Keine neue Providerintegration ohne belegten Grund.

**Prüfung:** „Pasta Fresca“ in Prag mit echten Treffern; kurze Eingabe, kein Treffer, offline, verspätete Antworten, Formularabbruch und VoiceOver.

## Issue-Entwurf 2: Treffer bewusst bestätigen und mit der Idee verbinden
**Ziel:** Der gewählte Vorschlag wird korrekt zur Ortsidentität der Idee; das Suchgebiet lässt sich bewusst erweitern.

**Umfang:** Auswahl übernimmt kanonischen Namen, Kategorie, Adresse und Koordinaten in den ungespeicherten Entwurf. Karten- und Bildsuche verwenden denselben Ort. „In anderer Stadt suchen“ erweitert den Kontext. Freie Ideen bleiben unterstützt; bestehende Orte werden nicht unbemerkt neu zugeordnet.

**Akzeptanz:** Trefferantippen speichert noch nichts. Änderungen am Titel nach Auswahl lösen die alte Bindung nachvollziehbar. Notiz, Link und übrige Entwurfsfelder bleiben erhalten. Dublettenprüfung verwendet die bestätigte Identität.

**Abhängigkeit:** Issue 1 und vorhandene Orts-/Bildmodelle.

**Prüfung:** Zwei gleichnamige Restaurants, Abbruch vor Speicherung, Kontextwechsel, Titeländerung nach Auswahl, Speichern/Neustart, Karten- und Bildidentität sowie Dublettenschutz.

## Issue-Entwurf 3: Fotos als Reiseerinnerungen unabhängig von Orten speichern
**Ziel:** Fotos können direkt aufgenommen oder aus der Mediathek gewählt werden, auch wenn noch kein passender Ort existiert oder bekannt ist.

**Umfang:** Eigenes Fotoobjekt in der Reise mit Bilddatei, Erstellungszeit und Autor. Die Fotoaufnahme und Mediatheksauswahl speichern es unmittelbar als Reiseerinnerung; Ortszuordnung ist optional und kann später erfolgen. Erinnerungen zeigt sowohl unabhängige Fotos als auch Ortsbilder. Ein unabhängiges Foto wird nicht als Ortsbild oder Besuchsbestätigung ausgegeben. Vorhandene lokale Dateispeicherung/-löschung, Sync- und Wiederherstellungsregeln wiederverwenden, soweit möglich. Noch offen: Sichtbarkeit/Sync für die ganze Reisegruppe oder nur auf diesem Gerät.

**Akzeptanz:** Foto ohne Orte aufnehmen/importieren und nach Neustart wiederfinden. Kein Ort wird vorausgewählt, erzeugt oder als besucht markiert. Späteres Verknüpfen erhält Bild und Autor und kann rückgängig gemacht werden. Ort zuordnen bleibt freiwillig. Löschen und fehlgeschlagener Upload hinterlassen keine verwaisten Bilddateien. Kamerazugriff wird erst beim tatsächlichen Aufnehmen benötigt.

**Abhängigkeiten:** Bestehender Erinnerungsbereich, `PlaceImageStorage`, Reise-Serialisierung und Sync. Vor Umsetzung die Gruppen-/Privatsichtbarkeit entscheiden.

**Prüfung:** Kamera und Mediathek ohne existierende Orte; ohne Zuordnung speichern; Neustart und Offline-Rückkehr; optional zuordnen/entfernen; löschen; Berechtigung verweigert; Sync zweier Teilnehmer, falls gemeinsame Sichtbarkeit gewählt wird.

## Issue-Entwurf 4: Kamera im gemeinsamen Aktionsmenü
**Ziel:** Die Kamera ist mit weniger Schritten aus jedem Reisetab erreichbar.

**Umfang:** Eigenständiger Punkt „Kamera“ mit Kamerasymbol im aufgefächerten Aktionsmenü, im Stil des Nutzer-Screenshots und der Einträge „Erinnerungen“, „Ausgaben“ und „Unterlagen“. Öffnet direkt die Aufnahme. „Erinnerungen“ bleibt separat. Aufnahme nutzt Issue 3 und erzwingt keine Ortsauswahl.

**Akzeptanz:** Aus Plan, Ideen, Karte und Gruppe erreichbar. Kamera öffnet sich direkt; Abbrechen kehrt in den Reisebereich zurück. Foto kann unmittelbar ohne Ort gespeichert werden. Fünf Menüaktionen sind auf kleinem Display unterscheidbar, bedienbar und mit VoiceOver benannt.

**Abhängigkeit:** Issue 3 und vorhandene Aktionsmenü-/Kameraroute.

**Prüfung:** Simulator aus allen vier Tabs, Layout und VoiceOver; Kamera abbrechen und unabhängiges Foto in Erinnerungen wiederfinden. Kamera-Hardware separat auf einem echten iPhone prüfen.

## Reihenfolge
Issue 1 → 2. Issue 3 → 4. Abschließend kombinierter Simulatorlauf. Die Entscheidung, ob Reiseerinnerungen für die Gruppe synchronisiert werden, muss vor Issue 3 fallen.

## Linear
Die Workspace-Suche enthält kein Album-Projekt; sichtbar ist nur das Codex-Team. Noch keine Issues in Linear angelegt. Issue-Entwürfe bleiben lokal, bis der Nutzer einen passenden Team-/Projektort angibt.
