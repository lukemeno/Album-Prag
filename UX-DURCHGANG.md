# UX-Durchgang

Gemeinsamer Durchgang durch den ganzen Ablauf, in der Reihenfolge, in der eine neue Nutzerin die App erlebt. Pro Schritt: was man tun können soll und über welchen *einen* Weg. Gebaut wird erst nach dem Durchgang.

Stand: 03.11.2026

## Schritt 1 – Übersicht und neue Reise

Befunde:
1. „… oder öffne eine Einladung“ verspricht etwas, für das es auf dem Bildschirm keinen Weg gibt.
2. Zwei Plus-Knöpfe für dieselbe Aktion; zwei Überschriften übereinander („Album“, „Deine Reisen“).
3. „Name der Reise“ und „Ziel“ sind zwei Felder für fast dasselbe; das Titelfoto hängt am Ziel.
4. Der Zeitraum steckt hinter einem Schalter, obwohl Reiseplan, „Heute“ und Erinnerungen davon leben.
5. Das Formular wirkt wie die iOS-Einstellungen; „Neue Reise“ steht doppelt.

Entscheidungen:
- **Ein Feld „Wohin geht's?“** statt Name und Ziel. Der Name übernimmt das Ziel; umbenennen später. (Befund 3)
- **„Einladung öffnen“** als zweiter, ruhiger Knopf in der Übersicht; erkennt einen kopierten Einladungslink. (Befund 1)
- **Oberes Plus** erst zeigen, wenn es schon eine Reise gibt. (Befund 2)
- **Zeitraum direkt abfragen**, mit „Weiß ich noch nicht“ als bewusster Wahl statt Schalter. (Befund 4)
- **Formular-Optik** im Design-Schritt an den Briefmarken-Stil angleichen, doppelte Überschrift weg. (Befund 5)

## Schritt 2 – In der Reise: Reise-Tab

Befunde (neue, leere Reise ohne Zeitraum):
1. Dieselben Ziele dreifach: Unterlagen, Ausgaben, Erinnerungen, Assistent stehen als Zeilen unten, im ✦-Fächer und im „…“-Menü am Titelfoto (7 Punkte).
2. Eine Idee anlegen geht vierfach: + oben rechts, roter Knopf „Idee einwerfen“, „Neue Idee“ im „…“-Menü, über Ideen-Tab.
3. Zwei leere Plan-Karten übereinander („Reiseplan – Noch kein Reisezeitraum“, „Dein Plan – Noch nichts geplant“); keine bietet „Zeitraum festlegen“ an.
4. Leeres graues Titelfoto mit Bild-Symbol, obwohl das Ziel bekannt ist; kein Hinweis, wie ein Foto hinkommt.
5. Kopf „‹ Album“: der Zurück-Weg zur Übersicht heißt wie die App, nicht wie das Ziel („Deine Reisen“).

Entscheidungen – jedes Element bekommt genau eine Aufgabe:
- **Reise-Tab** zeigt, was ansteht (Plan, Heute); die Zeilen darunter sind der einzige Weg zu Unterlagen, Ausgaben, Erinnerungen, Assistent. (Befund 1; Sammlung siehe Schritt 3)
- **✦-Fächer** nur für schnelles Festhalten unterwegs: Foto machen, Ausgabe erfassen, Reise fragen – Aktionen, keine Seiten. (Befund 1)
- **„…“ am Titelfoto** nur Einstellungen: Reise bearbeiten, Titelfoto, Teilen & Personen, Löschen/Verlassen. (Befund 1; schließt „Löschen in der geöffneten Reise“)
- **Idee anlegen** nur über den roten Knopf im Reise-Tab und das + im Ideen-Tab; das + oben im Reise-Tab entfällt. (Befund 2)
- **Leere Reise:** eine Karte „Wann fahrt ihr?“ mit Knopf zum Zeitraum statt zwei leerer Plan-Karten. (Befund 3)
- **Titelfoto** sucht sich automatisch eins zum Ziel und bietet „Foto wählen“ an. (Befund 4)
- **Zurück-Weg** heißt „Deine Reisen“. (Befund 5)

## Schritt 3 – Ideen-Tab

Befunde (drei Demo-Ideen):
1. Zwei Entscheidungs-Stapel: der Ideen-Tab selbst (Stapel, Nein/Offen/Ja) und „…“ → „Entscheiden“ als Blatt mit eigenem, anders aussehendem Stapel (Briefmarken-Karte, Wischen, Reiter Entdecken/Weggewischt/Sammlung), ohne Schließen-Knopf.
2. „Entdecken“ heißt zweimal etwas anderes: im Blatt der Stapel, im Tab ein Knopf für Ortsvorschläge.
3. Sammlung im Ideen-Tab dreifach: „…“-Menü, Knopf „Sammlung öffnen“, Reiter im Entscheiden-Blatt (dazu Zeile im Reise-Tab).
4. „Weggewischt“ (Nein-Ideen zurückholen) gibt es nur im Blatt, nicht im Tab.
5. „Bilder ergänzen“ ist ein Wartungswerkzeug, steht aber gleichrangig unter den Ideen.
6. Zwei Rückgängig-Wege: „Rückgängig“ im Blatt, im Tab nicht sichtbar.

Entscheidungen:
- **Ein einziger Stapel: der Ideen-Tab.** Das Entscheiden-Blatt entfällt. In den Tab wandern: Wischen als zweite Bedienung neben den Knöpfen, „Rückgängig“ direkt nach einer Entscheidung, aussortierte Ideen als Filter „Nein“ in der Liste. Ein Kartenstil, der des Tabs. (Befunde 1, 4, 6)
- **Sammlung als dritter Reiter: Stapel | Liste | Sammlung.** Alle anderen Eingänge entfallen, auch die Zeile im Reise-Tab (ändert Schritt 2). (Befund 3)
- **„Entdecken“ heißt „Orte vorschlagen“** und bleibt in der Liste. (Befund 2)
- **„Bilder ergänzen“** ins „…“-Menü des Ideen-Tabs. (Befund 5)

## Schritt 4 – Karte

Befunde (Prag-Reise, drei offene Ideen, noch keine Zustimmung):
1. Die Karte zeigt Norddeutschland statt Prag, obwohl das Ziel bekannt ist.
2. Offene Ideen erscheinen nicht; „Noch keine Orte – Hier erscheinen Orte, denen ihr zustimmt.“ Beim Entscheiden fehlt damit die Frage „Wo liegt das eigentlich?“.
3. Noch ein + oben rechts zum Anlegen einer Idee (widerspricht Schritt 2).

Entscheidungen:
- **Karte startet beim Ziel der Reise**; mit Orten zeigt sie den Bereich, der alle umfasst. (Befund 1)
- **Alle Ideen auf der Karte, zwei Stufen:** zugestimmte Orte kräftig, offene Ideen blass; Tipp auf eine offene Idee öffnet sie mit Ja/Nein/Offen. (Befund 2)
- **Das + oben entfällt.** (Befund 3)

## Schritt 5 – Einladen und Mitreisende

Befunde (Einladung selbst nicht erzeugt, weil das echte Serverdaten anlegt):
1. Das Blatt heißt „Zu zweit planen“ mit Stempel „Album für zwei“. PRODUCT.md sagt: für zwei, aber die Zweisamkeit „ausdrücklich nicht im Vordergrund“. Der Server kann bereits mehrere Mitglieder (Besitzer/Mitglied).
2. Zwei Eingänge: Knopf „Einladen“ im Reise-Tab und „Teilen & Personen“ im „…“-Menü.
3. Wie die eingeladene Person den Link öffnet und in der App ankommt, ist von hier aus nicht sichtbar (siehe Schritt 1, „Einladung öffnen“).

Grundsatzentscheidung (03.11.2026): **Album ist für eine Person bis zu kleinen Gruppen.** Allein muss alles voll funktionieren; Einladen ist eine Möglichkeit, kein Ziel. Das weicht von PRODUCT.md („nur für zwei“) ab – PRODUCT.md ist entsprechend anzupassen.

Entscheidungen:
- **Allein voll nutzbar:** bei einer Person heißt es „entscheiden“ statt „gemeinsam entscheiden“; nirgends ein Hinweis, dass etwas fehlt. Einladen ist ein Angebot. (Grundsatz)
- **Blatt „Gemeinsam planen“** statt „Zu zweit planen“; Stempel „Album für zwei“ entfällt. (Befund 1)
- **Ein Eingang für Personen:** die Avatar-Reihe im Reise-Tab mit „+ Einladen“ öffnet die Personen-Seite (einladen, sehen, wer dabei ist, als Besitzer entfernen). „Teilen & Personen“ fällt aus dem „…“-Menü (ändert Schritt 2). (Befund 2)
- **Mehrheitsregel:** eine Idee ist „Ja“, sobald mehr als die Hälfte Ja gesagt hat (allein: dein Ja; zu zweit: beide). Auf jeder Idee kleine Avatare, wer Ja/Nein/Offen gesagt hat. Wer noch nicht abgestimmt hat, sieht die Idee weiter im eigenen Stapel.

## Schritt 6 – Unterwegs

Befunde (Reise 4.–9. Oktober, heute der 5.):
1. „Heute · Montag, 5. Oktober · 1 Ort“ zeigt den Ort nicht, nur den Knopf „Tagesplan öffnen“. Was heute ansteht, ist einen Tipp entfernt.
2. Das Titelfoto nimmt auch unterwegs ein Drittel des Bildschirms ein; „Heute“ beginnt erst unter Einladen und Reiseplan.
3. Leere Tage heißen „Frei“ – liest sich wie „freier Tag“ statt „noch nichts geplant“.
4. Der Tagesstreifen zeigt pro Tag nur den ersten Ort (4. Okt. hat zwei), ohne Anzahl.
5. Unterlagen (Flug, Hotel) liegen unten in der Zeile, auch am An- und Abreisetag.

Entscheidungen – während der Reise ordnet sich der Reise-Tab um:
- **„Heute“ ganz oben** unter einem kleinen Kopf (Reisename, „Tag 2 von 6“); großes Titelfoto nur vor und nach der Reise. (Befund 2)
- **„Heute“ zeigt die Orte des Tages direkt**, in Reihenfolge, mit Adresse und „Route“; der nächste offene Ort hervorgehoben. „Tagesplan öffnen“ nur noch zum Umsortieren. (Befund 1)
- **Flug/Hotel am passenden Tag oben in „Heute“** (Bordkarte am Abflugtag, Hotel am Anreiseabend). (Befund 5)
- **Leere Tage „Noch offen“ mit +**, volle Tage erster Ort plus „+1“. (Befunde 3, 4)

## Schritt 7 – Nach der Reise

Befunde (Karte „Erinnerungen ansehen“ und Rückblick wurden am 03.11. zurückgeholt):
1. Zwei Dinge heißen „Erinnerungen“: die Zeile/der Fächer (Fotos per Kamera und Mediathek sammeln) und der Rückblick „Erinnerungen ansehen“ (besuchte Orte nach Tagen).
2. Der Rückblick zeigt nur Orte und deren Bilder, **nicht die Fotos, die man unterwegs mit der Kamera gemacht hat** (`TripMemoriesView` liest `tripMemories` nicht). Die eigenen Reisefotos fehlen also ausgerechnet im Album.
3. Ein Ort erscheint im Rückblick nur, wenn er als „besucht“ markiert wurde; wer das unterwegs vergisst, hat einen leeren Rückblick.
4. Bedienhilfe: Ortsname auf dem Foto zu wenig Kontrast, Schrift wächst nicht mit (siehe Bedienhilfe-Plan).

Entscheidungen – ein „Album“ statt zwei Erinnerungen:
- **„Album“** ist das Ergebnis der Reise: eine Ansicht nach Tagen, jeder Tag mit den besuchten Orten **und den eigenen Fotos dieses Tages** (Zuordnung über Aufnahmedatum, bei Nähe auch zum Ort). (Befunde 1, 2)
- **Während der Reise heißt der Weg „Fotos“** (Kamera, Mediathek); **nach der Reise wird daraus „Album ansehen“.** (Befund 1)
- **„Besucht“ markiert sich weitgehend selbst:** geplanter Ort + Foto in seiner Nähe am selben Tag = besucht; von Hand weiter möglich, keine Pflicht. (Befund 3)

## Bau-Reihenfolge (Vorschlag)

Kleine Pakete, jedes mit eigenem Plan, Ende-zu-Ende-Test und Freigabe. Reihenfolge nach Wirkung auf das Kernversprechen.

1. **Album nach der Reise** (Schritt 7) – eigene Fotos im Rückblick, „Fotos“/„Album“, besucht automatisch. Behebt das gebrochene Kernversprechen.
2. **Ein Ideen-Stapel** (Schritt 3) – Entscheiden-Blatt weg; Wischen, Rückgängig, Nein-Filter in den Tab; Sammlung als Reiter; „Orte vorschlagen“; „Bilder ergänzen“ ins Menü.
3. **Reise-Tab aufräumen** (Schritte 2, 5) – Zeilen/Fächer/„…“ mit je einer Aufgabe; + oben weg; „Wann fahrt ihr?“; „Deine Reisen“; Avatar-Reihe als Personen-Eingang.
4. **Unterwegs-Modus** (Schritt 6) – „Heute“ oben mit Orten, Route, Unterlage des Tages; kleiner Kopf; „Noch offen“.
5. **Neue Reise und Übersicht** (Schritt 1) – ein Feld „Wohin geht's?“, Zeitraum direkt, „Einladung öffnen“, oberes + nur mit Reisen.
6. **Karte** (Schritt 4) – Start beim Ziel, alle Ideen in zwei Stufen, + weg.
7. **Gruppen** (Schritt 5) – Mehrheitsregel, Stimmen-Avatare, „Gemeinsam planen“, mehrere Einladungen. Größtes Paket (Datenmodell, Sync).
8. **Bedienhilfe und Aufräumen** – mitwachsende Titel, Verlauf hinter Fototext, unsichtbare Tableiste, restliche UI-Tests, PRODUCT.md auf „eine Person bis kleine Gruppe“.
