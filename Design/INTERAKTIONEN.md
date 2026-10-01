# Interaktionen – Entscheidung vom 23.09.2026

Maßstab laut PRODUCT.md: schön und leicht vor allem anderen. Eine Interaktion kommt nur rein, wenn sie die Bedienung erleichtert oder einen echten Moment schafft. Jede Interaktion gilt in beiden möglichen Welten (Kreuzstich oder Scrapbook); nur das Material ändert sich.

Regeln für alle Interaktionen (abgeleitet aus der Referenz „Ticket abreißen“, 22.09.2026):
1. Die Geste bedeutet die Handlung.
2. Der Finger steuert die Animation direkt: unterbrechbar, halbe Geste = halber Zustand, Loslassen federt zurück.
3. Das Material antwortet mit Welle, Schatten und Haptik.
4. Jede Geste hat eine gleichwertige Schaltfläche. Bei „Bewegung reduzieren“ wird überblendet statt bewegt.

## V1 – bis zur Abreise am 4.10.

| # | Interaktion | Wo | Aufgabe | Technik |
|---|---|---|---|---|
| 2 | Zettel aus der Zwischenablage | App-Start | Kopierter Link wird ohne Tippen zur Idee: Zettel hochziehen = gespeichert, nach 5 s verschwindet er | `UIPasteboard.detectPatterns` (kein Einfüge-Dialog, bevor der Nutzer zieht), SwiftUI-Geste |
| 1 | Briefkasten-Schlitz | Link hinzufügen | Abschicken fühlt sich abgeschickt an: Karte nach oben schnippen, Klappe schlägt zu | Rive (Klappe), `.impact(.rigid)` |
| 5 | Magnet-Klick | Ideen | Leise Bestätigung, wenn beide dafür sind; bewusst klein | Zwei Hälften schnappen zusammen, zweifache Haptik |
| 7 | Stecknadel | Karte | Neuer Ort landet sichtbar auf der Karte | Pin fällt, Delle/Schatten per Shader, `.impact(.light)` |
| 8 | Roter Faden | Karte | Tagesplanung nebenbei: Orte eines Tages als Faden verbunden, Pin verschieben spannt den Faden neu | Spring-Physik für den Faden; nutzt vorhandenes `Place.day` |
| 11 | Abreißkalender | Reise | Vorfreude-Ritual bis Prag: ein Blatt pro Tag abreißen | Abrisskante als Shader, Blatt fällt mit Physik |
| 9 | Tram-Klingel | Aktualisieren | Abgleich wird hör- und fühlbar | Pull-to-refresh als Klingelschnur, Rive-Glocke, heller Haptik-Impuls |

Bleibt: Wischen zum Entscheiden (schon gebaut und getestet in `InboxView.swift`), weil es der schnellste Weg ist.

## V2 – nach der Abreise

| # | Interaktion | Warum später |
|---|---|---|
| 10 | Ticket griffbereit | Braucht Ortsbezug und Uhrzeiten der Buchungen; Risiko falscher Auslösung vor einem echten Test in Prag |
| 12 | Polaroid entwickeln mit Schütteln | Gehört zum Erinnern nach der Reise |
| 4 | Karteikasten | Lohnt sich erst ab etwa 20 offenen Ideen |
| 13 | Sticker abziehen | Braucht erst Markierungen im Datenmodell |

## Verworfen

| # | Interaktion | Grund |
|---|---|---|
| 3 | Stempel mit Druck | Langsamer als Wischen; widerspricht „leicht“. Die Stempel-Optik kann als Rückmeldung auf „Dafür“ weiterleben. |
| 6 | Stadtplan auffalten | Karte ist ein Tab; eine Falt-Transition zwischen Tabs widerspricht der iOS-Navigation. |

## Stand 23.09.2026 – Welt „Kreuzstich“ gebaut (Branch `design/kreuzstich`)

| # | Interaktion | Status | Wo im Code |
|---|---|---|---|
| 2 | Zettel aus der Zwischenablage | gebaut, im Simulator geprüft | `AlbumRoot.swift` (`ClipboardNote`, `PasteButton` ohne Einfüge-Dialog) |
| 1 | Briefkasten-Schlitz | gebaut, geprüft; reine SwiftUI statt Rive. Seit 30.09. per Finger: Karte nach oben in den Schlitz ziehen (Schwelle mit Haptik, sonst Feder zurück) oder „Nach oben einwerfen“ tippen; Naht schließt sich, ein Zettel „Liegt bei Ideen“ wird nachgedruckt | `Stitch/LetterSlot.swift` |
| – | Kreuz stickt sich bei „Dafür“ | gebaut, geprüft (ersetzt vorerst den Magnet-Klick) | `InboxView.swift` |
| 5 | Magnet-Klick | gebaut: Stimmen pro Person (`approvals`), zwei Herzhälften schnappen zusammen; keine Migration nötig, Orte liegen als JSON in `places.payload` | `InboxView.swift` (`MagnetHearts`), `AlbumStore.decided` |
| 7 | Stecknadel | gebaut, geprüft | `TripMapView.swift` (`StitchPin`) |
| 8 | Roter Faden | gebaut: Vorstich pro Tag in geplanter Reihenfolge; Tag per Menü, Reihenfolge im „Tagesplan“ per Ziehen | `TripMapView.swift` (`DayMenu`, `DayPlanner`) |
| 11 | Abreißkalender | gebaut, geprüft | `Stitch/ReiseExtras.swift` (`TearCalendar`) |
| 9 | Tram-Klingel | gebaut, geprüft (Haptik, kein Ton) | `Stitch/ReiseExtras.swift` (`TramBell`) |
| – | „Heute“ für unterwegs | gebaut, geprüft mit `ALBUM_TODAY=2026-10-05` | `Stitch/ReiseExtras.swift` (`TodayPlan`) |

Debug-Hilfen (nur in Debug-Builds): `ALBUM_START_TAB=Reise|Ideen|Karte`, `ALBUM_TODAY=yyyy-MM-dd`, `ALBUM_TEST_STORE=<ordner>`.

Dunkelmodus: indigogefärbtes Leinen, hellere Garne (`Stitch.dynamic`). Name pro Gerät (`album.myName`), einmal beim ersten Start abgefragt.

## Stand 30.09.2026 – Ideen-Stapel (`InboxView.swift`)

| Baustein | Verhalten |
|---|---|
| Auffächern | Beim Erscheinen und wenn eine neue Karte oben liegt, fächern die zwei hinteren Polaroids kurz weiter auf und legen sich per Feder (response 0,4, damping 0,72, rund 4 % Überschwingen) auf -4°/5° |
| Anheben | Beim Ziehen wächst die oberste Karte auf 1,05, der Schatten wird tiefer; dazu neigt sie sich um die Y-Achse mit der geglätteten Ziehgeschwindigkeit (höchstens ±12°), richtet sich bei Ruhe nach 300 ms und beim Loslassen per Feder auf |
| Foto groß | Tippen auf das Foto wächst es im Vollbild aus dem Polaroid; nach unten ziehen schrumpft es proportional zurück (über 110 pt oder schneller Wurf schließt, sonst Feder), Schließen-Knopf oben rechts, Bildnachweis unten |
| Schild „Dafür?“ / „Später?“ | Laufstiche in Garnfarbe (Rot / Kobalt) füllen das Schild mit dem Weg; an der Schwelle rastet das Label ein (ohne „?“, Puls 1,06, Selection-Haptik), „Dafür“ wird zur Knopffläche, „Später“ bekommt eine dickere Kante |
| Bewegung reduzieren | Kein Auffächern, Anheben, Neigen; Foto wird überblendet statt bewegt und lässt sich nur über den Knopf schließen |

Wischen bleibt „entscheiden“; „Später“ und „Dafür“ bleiben als Knöpfe.


## Stand 30.09.2026 – Eingabefeld mit Nadel (`AlbumRoot.swift`)

`StitchTextField`: Unter dem Text wächst ein Vorstich (gestrichelt, `Stitch.red`, 1,5 pt), eine kleine Nadel steckt am Ende und folgt jedem Anschlag per Feder mit 40–90 ms Verzögerung (aus der Textlänge, kein Zufall). Der Text erscheint sofort. `NamePrompt`: Beim ersten Buchstaben ploppt die Hand einmal auf (Feder, höchstens 1,07). Bewegung reduzieren: keine Nadel, Linie ohne Animation, kein Plopp.

## Stand 01.10.2026 – Einladung einlösen (`Stitch/InvitationMoment.swift`)

| Baustein | Verhalten |
|---|---|
| Fahrkarte | Gestickte Karte „Prag · 4.–9. Oktober“ (Absender, wenn bekannt) mit Heftstich; wird wie die Briefkasten-Karte nach oben in den Schlitz gezogen |
| Schwelle | Ab 40 % Weg oder vorhergesagtem Ende beginnt der echte Beitritt; halbe Geste = halber Zustand, zu früh losgelassen federt zurück |
| Knopf | „Einladung einlösen“ → „Album wird geöffnet …“ → „Album ansehen“; Tippen löst ohne Ziehen aus, VoiceOver-Aktion „Einlösen“ |
| Ergebnis | Aus demselben Schlitz druckt ein Zettel nach unten („13 Orte · 5 Tage“) |
| Fehler | Klappe öffnet, Karte federt heraus, Text ruhig über dem Knopf, erneut versuchbar |
| Bewegung reduzieren | Karte bleibt stehen, Knopf löst aus, Überblenden statt Bewegen |

Die Schlitz-Mechanik liegt als `SlotScene` in `Stitch/LetterSlot.swift` und wird auch vom Briefkasten benutzt.

## Stand 01.10.2026 – Abgleich-Insel (`Stitch/SyncIsland.swift`)

| Baustein | Verhalten |
|---|---|
| Pulsieren | Kleine Kapsel links in der Leiste der Reise-Seite, ab 0,5 s Abgleich, Garn-Kreuz und „Abgleich“ atmen |
| Aufwachsen | Bringt der Abgleich Neues der anderen Person, wächst die Hülle mit durchgehendem Kapselradius (Feder), nach 0,15 s blendet der Text ein |
| Zuklappen | Nach 5 s oder per Tipp: erst Text weg, dann schrumpft die Hülle; jederzeit unterbrechbar, auch von einer neuen Meldung |
| Tipp | Gleichwertig zur Geste gibt es keine: die Insel hat keine Geste, nur Tipp zum Schließen und eine VoiceOver-Ansage |
| Bewegung reduzieren | Kein Pulsieren, Hülle springt, Text blendet |

## Stand 01.10.2026 – Foto-Stapel (`Stitch/PhotoStack.swift`)

| Baustein | Verhalten |
|---|---|
| Stapel | Mehrere Fotos eines Ortes liegen mit ±2,5° Neigung und wenigen Punkten Versatz hintereinander; ein einzelnes Foto bleibt wie bisher |
| Wischen | Waagrecht, die Karte folgt dem Finger und neigt sich, die hinteren rücken anteilig nach; Schwelle 80 pt oder vorhergesagtes Ende, sonst Feder zurück; die Karte gleitet hinten wieder ein (zyklisch) |
| Tippen | Öffnet das Foto groß (`PhotoViewer`) mit Bildnachweis; Schließen wie bei den Ideen |
| Zähler | „1 / 3“ blättert ohne Geste, VoiceOver „Nächstes Foto“ |
| Bewegung reduzieren | Nur die vorderste Karte, Überblenden statt Fliegen |

## Stand 01.10.2026 – Bordkarte (`Stitch/BoardingPass.swift`) und Besucht-Spur (`Stitch/VisitedTrack.swift`)

| Baustein | Verhalten |
|---|---|
| Bordkarte | Tippen auf das angeheftete Flug-Ticket: Hülle wächst mit weichem Überschwingen, nach 150 ms blendet der Inhalt ein (Zeiten, Route, Flugnummer, Datum); Schließen kehrt um, unterbrechbar; „Reiseunterlagen“ bleibt als Knopf in der Karte |
| Besucht-Spur | Daumen nach rechts, Garn füllt die Spur, ab 85 % rastet „Loslassen“ ein (Selection-Haptik), Loslassen setzt „Besucht ✓“ (gesperrt); zu früh federt zurück |
| Gleichwertig | Tippen füllt die Spur von selbst; VoiceOver aktiviert sie; Bordkarte öffnet und schließt per Tipp |
| Stempel | Gestickter Stempel landet mit Feder auf dem Foto |
| Bewegung reduzieren | Bordkarte und Spur springen bzw. blenden über, Stempel blendet ein |
