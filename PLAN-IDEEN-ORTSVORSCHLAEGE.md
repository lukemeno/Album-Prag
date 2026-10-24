# Ortsvorschläge beim Eingeben einer Idee

Stand24.10.2026, Planung. Nutzerentscheidung: zuerst Reiseziel, Suche auf andere Städte erweiterbar. Keine Umsetzung oder Linear-Erstellung behaupten; bestätigtes Linear-Zielprojekt fehlt noch. Aktiver Modus ist Default; Plan Mode wurde vorgeschlagen, nicht aktiviert.

## Ziel und Ablauf
Unter Ideen → Neue Idee tippt man z.B. „Pasta Fresca“ ins Namensfeld. Eine Liste zeigt passende konkrete Orte am Reiseziel mit Name, Adresse/Stadt und Kategorie. Ein Tipp übernimmt den gewählten Ort samt Koordinaten in den Entwurf; erst Speichern legt die Idee an. Keine automatische Auswahl bei Mehrdeutigkeit. Ohne Treffer oder offline bleibt freie Eingabe möglich. „In anderer Stadt suchen“ erweitert den Kontext bewusst. Keine aktuelle GPS-Position nötig.

## Vorhandener Anschluss
PlaceEditor.swift besitzt im getrennten Feld „Ort oder Adresse“ bereits MKLocalSearch mit tripRegionContext, Ergebniszeilen und Abbruch-/Generationenschutz. Das Namensfeld startet bisher keine Suche. Darauf aufbauen, keine zweite unabhängige Ortsidentität. Vorhandene Bildauswahl nach bestätigtem Ort verwenden; Texte/Notizen nicht überschreiben. Neues oder geändertes Suchwort darf alte Antworten nicht wieder einblenden.

## Issue-Entwürfe
1. Namensvorschläge und Suchzustand: nach kurzer Tipp-Pause ab sinnvoller Mindestlänge suchen, alte Anfragen abbrechen, 3–5 verständliche Treffer, Laden/leer/offline, nur aktive Eingabe darf Vorschläge ändern. Prüfung: verzögerte vertauschte Antworten, Abbruch/Schließen, leere und kurze Eingabe.
2. Bestätigter Ort und Suchkontext: Reiseziel bevorzugen, Auswahl übernimmt verifizierte Koordinaten/Adresse/Identität; Erweiterung auf andere Stadt, freie Idee bleibt möglich. Bestehende Idee nicht unbemerkt neu zuordnen; bearbeitete Notizen/Links erhalten. Prüfung: mehrere gleichnamige Restaurants, fehlender Reisekontext, Ortswechsel, Dubletten, manuelle Änderungen.
3. Simulator-Abnahme: echte Suche „Pasta Fresca“ in Prag, Treffer bewusst auswählen, speichern, richtige Karte/Bildsuche, Neustart; offline und erweiterten Kontext prüfen. Testmodus muss echte MapKit-Abfragen gezielt erlauben, normale deterministische UI-Tests behalten ihre Isolation. Bestehende PlaceEditor-Suche überspringt derzeit MapKit in jedem ALBUM_TEST_STORE; deshalb explizites lokales QA-Opt-in nötig.

Abhängigkeiten:1→2→3. Anbieterentscheidung nach Prüfung der vorhandenen MapKit-Suche; keine kostenpflichtigen neuen APIs ungeprüft einführen. Restaurantvorschläge sind konkrete Ortsdaten, keine generative Erfindung.
