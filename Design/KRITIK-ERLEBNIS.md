# Kritik: Ist Album ein Erlebnis? (05.10.2026)

Grundlage: lokale Screen-Tour auf `cd3155e` (21 Tests, 0 Fehler, 37 Bilder: hell, dunkel, quer, große Schrift), Vorlage `Claude-Handoff/references/approved-native-design.png`, `PRODUCT.md`.

Maßstab des Nutzers: Jede Funktion hat einen Sinn. Jede Komponente passt zur nächsten. Jeder Screen ist auf Album zugeschnitten. Die Nutzung ist ein Erlebnis.

## Befund in einem Satz

Die einzelnen Teile sind ordentlich, aber Album erzählt seine eigene Geschichte nicht: Die Briefmarke klebt als Bild auf dem Titelfoto, statt das zu sein, was beim Entscheiden, Planen und Erleben tatsächlich passiert.

## 1. Sinn: Was keinen klaren Zweck hat

| # | Was | Wo | Warum es stört | Vorschlag |
|---|---|---|---|---|
| S1 | Zahl am Ideen-Tab „78“/„81“ | `AlbumRoot` `.badge(store.inbox.count)` | Zählt alle offenen Ideen, auch die Beispielorte. Eine Zahl, die nie kleiner wird, ist Lärm statt Hinweis. `newFromOthers` gibt es schon. | Nur zählen, was der andere neu eingeworfen hat. |
| S2 | KI-Kreis auf jedem Screen | `AlbumRoot` Overlay | Verdeckt Kacheln („Noch frei“), Zeilenaktionen (Fußweg), bei großer Schrift „Einladen“, steht im Ideen-Tab direkt neben „Offen“. Auf der Karte und bei den Ideen hat er keinen Bezug zum Inhalt. | Nur noch auf „Reise“ im Kopf neben „+“ bzw. als Zeile im Reiseplan („Plane morgen“). |
| S3 | Ausgegraute Aktionen „Teilen“, „Website“ | Ortsdetail | Ein Knopf, der nichts tut, sagt: hier fehlt etwas. | Nur zeigen, wenn möglich. Die Reihe wird dann kürzer, nicht leerer. |
| S4 | Statuszeile „Idee — Geplant — Besucht“ **und** Knopf „Als besucht markieren“ | Ortsdetail | Zweimal derselbe Zustand. | Die Statuszeile selbst wird der Weg: „Besucht“ antippen = abstempeln (mit Stempel-Moment, siehe E2). |
| S5 | „Album-Backup exportieren“ zwischen Flug und Hotel | Unterlagen | Technische Funktion zwischen Reiseunterlagen. | In „Teilen/Album“ verschieben. |
| S6 | „Flüge hinzufügen“ doppelt | Reise und Unterlagen | Gleiche Zeile an zwei Orten. | Auf Reise nur, solange keine Flüge da sind; dort direkt PDF-Auswahl. |
| S7 | Drei Zähler im Kartenblatt („6 Orte“, „Heute 3 Orte“, „3 Orte“) | Kartenblatt | Dreimal Zahlen für einen Blick. | Kopf: „Heute · 3 Orte“, Rest über die Tage. |

## 2. Zusammenhang: Wo Komponenten verschiedene Sprachen sprechen

| # | Was | Vorschlag |
|---|---|---|
| Z1 | Drei Schriften: schmale Display-Serif (Ortsnamen), fette Serif (Überschriften), SF (Rest). Ortsname „Altstädter Ring“ wirkt wie aus einer anderen App. | Eine Serif für alle Titel (wie Vorlage), SF für Text. Ortsnamen in derselben Serif wie „Reiseplan“. |
| Z2 | Kartenmarken: teils Fotomarken, teils braune Symbolkacheln, eine Marke unter der Statusleiste. | Alle Orte als Briefmarke; ohne Foto eine gezeichnete Kategorie-Marke im selben Zackenrand. Kamera so, dass keine Marke unter Statusleiste/Suche liegt. |
| Z3 | Idee ohne Foto: grüne Fläche mit Einkaufstaschen-Symbol. | Gleiche gezeichnete Kategorie-Marke wie Z2, auf Papier. Nie wieder „Platzhalter“-Gefühl. |
| Z4 | Entscheidungsleiste: „Nein“ und „Ja“ groß, „Offen“ als kleiner Text, „Rückgängig“ links, KI-Kreis rechts. | Drei gleichwertige Entscheidungen klar gestaffelt; Rückgängig erscheint nur nach einer Entscheidung, an der Stelle, wo die Karte hinging. |
| Z5 | Symbol oben links im Ideen-Tab (Ablage mit Pfeil) ist ohne Beschriftung kaum zu deuten. | Das Ablage-Symbol wird das sichtbare Ziel von „Nein“: Die Karte fliegt dort hinein, die Zahl springt. Dann ist klar, wo man sie zurückholt. |
| Z6 | Formulare (Neue Idee, Teilen) sind Standard-iOS-Listen. | Neue Idee als Postkarte: vorne Bild/Link, hinten Notiz; „Speichern“ = in den Briefschlitz werfen. |

## 3. Zuschnitt: Was noch nicht wie Album aussieht

| # | Was | Beleg | Vorschlag |
|---|---|---|---|
| A1 | Tab-Leiste liegt im Querformat **über dem Knopf „Route“** auf der Reise-Seite. | `11-reise-quer-tagesplan` | Querformat: Inhalt endet über der Tab-Leiste (wie das Kartenblatt, das im Querformat inzwischen korrekt endet, `24-karte-quer`). |
| A2 | Inhalt läuft hinter die Tab-Leiste, „Heute / Sonntag“ halb verdeckt im ersten Bild. | `01`, `04`, `32`, `33` | Unteren Abstand so, dass der erste Bildschirm an einer Kante endet, nicht mitten in einer Überschrift. |
| A3 | Assistent ist ein generischer Chat. | `29` | Später: Vorschläge als Karten im Album-Stil statt Chatblasen. |
| A4 | Teilen: „Album / Zu zwei planen“, zwei Überschriften, Formular. | `27`, `28` | Einladung als Briefumschlag, den man versiegelt und verschickt (siehe E3). |

## 4. Erlebnis: die Momente, die fehlen

Album hat eine Metapher, die schon alles enthält: **Ideen sind Post, entscheiden heißt abstempeln, erlebt heißt entwertet, die Erinnerung ist das gestempelte Album.** Heute passiert davon fast nichts beim Bedienen.

| # | Moment | Wann | Technik | Ohne Bewegung |
|---|---|---|---|---|
| E1 | **Abstempeln beim Ja.** Sind beide dafür, drückt ein Stempel „PRAHA“ auf die Karte, die Tinte zieht leicht ins Papier, die Karte gleitet zum Tag in den Reiseplan. | Ideen → Ja | Metal-Shader (Tinte, Körnung), Haptik schwer | Stempel blendet ein, Haptik bleibt |
| E2 | **Entwerten beim Besucht.** Wellenlinien-Poststempel über die Marke, Foto wird minimal wärmer. | Ortsdetail, Tagesplan | Metal-Shader, Haptik | Überblenden |
| E3 | **Siegel für die Einladung.** Umschlag schließt sich, rotes Wachssiegel wird aufgedrückt, dann „Senden“. | Teilen | Rive-Animation oder Metal, Haptik | Siegel erscheint |
| E4 | **Suche, die aus der Lupe wächst.** Treffer erscheinen versetzt, getippte Buchstaben fett. | Karte | SwiftUI matchedGeometry, Blur-Übergang | Sofortiges Erscheinen |

Bewusst **nicht**: Partikel, Konfetti, Daueranimationen, Parallaxe.

## Reihenfolge

1. **Ideen-Ablauf** (S1, S2 dort, Z3, Z4, Z5, E1). Der Nutzer stört sich daran am meisten, und hier entsteht der Kern-Moment.
2. **Reise-Seite** (A1, A2, S2, S6, Z1).
3. **Karte und Ortsdetail** (Z2, S3, S4, S7, E2, E4).
4. **Teilen und Unterlagen** (S5, A4, E3).

Jeder Schritt: Build, Unit- und UI-Tests, Vorher/Nachher-Screenshot neben der Vorlage, Bewegung reduzieren, große Schrift, dunkel.
