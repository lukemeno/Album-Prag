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
| 1 | Briefkasten-Schlitz | gebaut, im Simulator geprüft; reine SwiftUI statt Rive | `Stitch/LetterSlot.swift` |
| – | Kreuz stickt sich bei „Dafür“ | gebaut, geprüft (ersetzt vorerst den Magnet-Klick) | `InboxView.swift` |
| 5 | Magnet-Klick | gebaut: Stimmen pro Person (`approvals`), zwei Herzhälften schnappen zusammen; keine Migration nötig, Orte liegen als JSON in `places.payload` | `InboxView.swift` (`MagnetHearts`), `AlbumStore.decided` |
| 7 | Stecknadel | gebaut, geprüft | `TripMapView.swift` (`StitchPin`) |
| 8 | Roter Faden | gebaut: Vorstich pro Tag in geplanter Reihenfolge; Tag per Menü, Reihenfolge im „Tagesplan“ per Ziehen | `TripMapView.swift` (`DayMenu`, `DayPlanner`) |
| 11 | Abreißkalender | gebaut, geprüft | `Stitch/ReiseExtras.swift` (`TearCalendar`) |
| 9 | Tram-Klingel | gebaut, geprüft (Haptik, kein Ton) | `Stitch/ReiseExtras.swift` (`TramBell`) |
| – | „Heute“ für unterwegs | gebaut, geprüft mit `ALBUM_TODAY=2026-10-05` | `Stitch/ReiseExtras.swift` (`TodayPlan`) |

Debug-Hilfen (nur in Debug-Builds): `ALBUM_START_TAB=Reise|Ideen|Karte`, `ALBUM_TODAY=yyyy-MM-dd`, `ALBUM_TEST_STORE=<ordner>`.

Dunkelmodus: indigogefärbtes Leinen, hellere Garne (`Stitch.dynamic`). Name pro Gerät (`album.myName`), einmal beim ersten Start abgefragt.
