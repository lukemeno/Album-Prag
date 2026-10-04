# Wo die Inspiration in Album hingehört

Dieser Plan ordnet die gefilterten X-Referenzen den vorhandenen Expo-Go-Screens und echten Album-Aktionen zu. Er ist eine Gestaltungs- und Interaktionsplanung, keine Implementierungsvorgabe im Pixelmaßstab. Die Screens bleiben Album-eigen: hell, ruhig, fotozentriert und mit klaren, moderaten Textgrößen.

## Priorität 1 — Karte und Ortsauswahl

**Vorhandener Ort:** Tab „Karte“ (`src/app/(tabs)/karte.tsx`). Es gibt bereits eine Karte, Pins, Tageschips, eine Routenlinie für geplante Orte und darunter ein festes Informationspanel. Pin-Auswahl und passende, durchsuchbare Ortsliste sind aktuell noch nicht verbunden.

**Inspiration:** Nao-Fotokarten und Dottaa-Sammlung. Übernehmen: kompakte horizontale Fotokarten mit knappem Ortsnamen/Kategorie und einem klaren Auswahlzustand.

**Album-Flow:** Die Karte bleibt als primäre Fläche immer lesbar. Ein ziehbares unteres Blatt wechselt zwischen Kartenübersicht, Ortsliste und ausgewähltem Ort. Pin antippen markiert denselben Ort in der Liste und öffnet dessen Vorschau; Listeneintrag antippen hebt den Pin hervor und zentriert die Karte passend. Der ausgewählte Ort kann mit einer eindeutigen Aktion in den Tagesplan übernommen werden. Ein erneuter Tap auf den aktiven Tab/Griff schließt das Blatt vollständig; ein Griff holt es zurück.

**Motion:** Blatt folgt dem Finger ohne Nachlaufen; beim Loslassen rastet es in wenigen verständlichen Positionen ein. Pin- und Listenauswahl überblenden/skalieren kurz und ruhig, die Routenlinie erscheint erst nach Auswahl eines Tagesplans. Leichte Haptik nur beim Einrasten und beim Wechsel des ausgewählten Ortes. Keine dekorative Daueranimation.

**Nicht übernehmen:** Fotokarten oder Blatt so groß machen, dass sie die Karte verdecken; Herz-Aktion, solange es in Album keinen echten Favoritenstatus gibt.

## Priorität 2 — Ideen entscheiden und den Plan ändern

**Vorhandener Ort:** Tab „Ideen“ (`src/app/(tabs)/ideen.tsx`) und Zuordnung zu einem Reisetag. Der aktuelle Stand zeigt „Dafür“ und „Später“, während „Offen“ ein Filter ist. Bereits geplante Einträge zeigen Tageschips.

**Inspiration:** withAnimation — Entscheidung bestätigt sich in derselben Karte und Undo bleibt direkt sichtbar.

**Album-Flow:** Drei gleich verständliche Zustände: „Dafür“, „Dagegen“ und „Offen“. Eine Entscheidung bekommt unmittelbar eine visuelle Bestätigung und bleibt ohne Navigation rückgängig zu machen. „Offen“ bedeutet ausdrücklich, dass noch keine Stimme abgegeben wurde. Ein Swipe darf den Zustand unterstützen, aber die beschrifteten Buttons bleiben immer verfügbar; Scrollen darf nie versehentlich abstimmen. Geplante Ideen bieten eine ebenso sichtbare Möglichkeit, den Tag zu ändern oder die Zuordnung zu entfernen.

**Motion/Haptik:** Karte reagiert beim Ziehen dezent auf Richtung und Widerstand. Erst nach klarer Schwelle wird der Zustand übernommen; Abbruch federt zur Ausgangslage zurück. Nach Entscheidung wird der gewählte Zustand kurz hervorgehoben, benachbarte Optionen treten zurück und „Rückgängig“ erscheint dort, wo die Aktion stattfand. Leichte Auswahlhaptik beim Commit, keine Haptik während normalem Listen-Scrollen. Bei Reduce Motion: unmittelbarer Zustandswechsel ohne räumliches Gleiten.

**Designhinweis:** Keine Rot/Grün-Ampel als alleinige Bedeutung und keine fremden Labels wie „Rejected“. Semantik kommt über ausgeschriebenen Text und ergänzende Icons/Farben.

## Priorität 3 — Sammlung mit Beiträgen der Mitreisenden

**Vorhandener Ort:** Tab „Sammlung“ (`src/app/(tabs)/sammlung.tsx`) mit Beiträgen/Links, Reaktionen und Kommentaren. Aktuell ist es im Kern eine Text- und Linkliste.

**Inspiration:** Dottaa-Feed: persönliche Beiträge, Kategorien und Absender machen eine Sammlung sozial und schnell scannbar.

**Album-Flow:** Beitrag wird als ruhige, fotozentrierte Karte dargestellt. Absender und kurzer Kontext stehen oberhalb, Ort/Link und Beitrag darunter. Wenn ein Vorschaubild wirklich verfügbar ist, bekommt es eine großzügige Bildfläche; ohne Bild bleibt die Karte sauber typografisch. Kategorie- oder Ortschips helfen beim Wiederfinden. Reaktion und Kommentar bleiben an den Beitrag gebunden und zeigen den eigenen Zustand.

**Motion:** Neue Karte kommt dezent an der Einfügeposition ins Bild; Reaktion bestätigt sich lokal und kurz. Kommentare öffnen sich inline oder als leichtes Blatt, damit der Feed-Kontext erhalten bleibt. Kein öffentliches Social-Netzwerk-Feeling und keine erfundenen Profilzahlen.

**Abhängigkeit:** Visuelle Linkvorschau hängt von den verfügbaren Metadaten/Bildern ab. Fehlende Vorschau darf kein kaputtes oder leeres Bild erzeugen.

## Priorität 4 — Reise-Startseite als klarer Einstieg in den Tagesplan

**Vorhandener Ort:** Tab „Reise“ (`src/app/(tabs)/index.tsx`) mit Reiseübersicht, Ideen-Teaser, gemeinsamer Reise, Sync und Album-Übertragung. Die eigentliche Tagesplanung lebt derzeit hauptsächlich in Ideen und Karte.

**Inspiration:** Doji-Einstieg: ein ruhiges Hauptmotiv, kurze Orientierung und eine primäre Aktion. Zusätzlich die bereits ausgewerteten Screenrecordings/Claude-Prototyp-Muster für Tageschips und sticky Tageskopf.

**Album-Flow:** Oben ein starkes Prag-Foto mit Reisedaten und einer klaren Aktion. Darunter kompakter Plan für den ausgewählten Tag mit Orten in Reihenfolge und einer verständlichen Aktion zum Ändern. Tagesauswahl bleibt beim Scrollen greifbar, ohne die Seite dauerhaft mit einer großen Navigation zu blockieren. Sync/Einladung und Import sind sekundäre Reiseverwaltung und werden visuell von der Tagesplanung getrennt.

**Motion:** Tageswechsel überträgt die Auswahl sichtbar in den Plan, ohne den gesamten Screen neu aufbauen zu lassen. Der Sticky-Tageskopf komprimiert leicht beim Scrollen. Leere Tagesplanung bietet eine einzelne nächste Aktion, etwa „Ideen für diesen Tag ansehen“.

**Nicht übernehmen:** Zusätzlicher Onboarding-Zwang, erfundene Buchungs-/Reisedaten, Fantasiezähler oder mehrere gleichgewichtige primäre Aktionen.

## Querschnitt — Ein konsistentes Motion- und Komponenten-System

**Inspiration:** Taste Design Breakdowns und die übrigen Screenrecordings, die zeitlich klare, physische Übergänge zeigen.

Vor Umsetzung sollten für jede Motion-Rolle dieselben Angaben feststehen: Auslöser, Ausgangs-/Endzustand, Dauerbereich, Kurve, Unterbrechbarkeit, Haptik, Undo, Reduced-Motion-Fallback und Testschritt. Rollen statt Einmalwerte verwenden, etwa `selection`, `sheetSnap`, `cardCommit`, `routeReveal` und `tabChange`. Die existierenden Expo-Bausteine (Reanimated, Expo Haptics und react-native-maps) sind der Rahmen; native SwiftUI-Muster nur als Interaktionsreferenz übersetzen, nicht als technische Vorgabe.

Das gemeinsame System definiert außerdem Farbrollen, Typografieskala, Spacing, Radien, Bildverhältnisse, Karten, Chips, Buttons, Bottom Sheets und Zustandsfeedback. Scrollen bleibt ruhig; Haptik signalisiert Auswahl, Commit oder Einrasten und wird durch Systemoptionen für reduzierte Bewegung respektiert.

## Empfohlene Reihenfolge für die spätere Umsetzung

1. System und Komponentenrollen für Fotos, Typografie, Chips, Buttons und Karten festlegen.
2. Karte/Liste/Ortsdetail als einen synchronen Ablauf gestalten; alle Orientierungen prüfen.
3. Ideenstatus samt Dagegen/Offen, Swipe-Schwelle, Undo und Tag ändern konsistent machen.
4. Sammlung für echte Beiträge, Reaktionen und optionale Vorschauen gestalten.
5. Reise-Startseite mit Tagesplan verbinden und Motion/Haptik screenübergreifend abstimmen.
6. Screen-Tour mit VoiceOver, großen Texten, Reduce Motion, Hoch-/Querformat und langsamen Gesten prüfen.

## Referenzindex

Die konkreten Quellen und ursprüngliche Beobachtungen stehen in [`X-BOOKMARK-INSPIRATION.md`](X-BOOKMARK-INSPIRATION.md); die sechs Video-Motion-Prompts liegen in [`MOTION-PROMPTS.md`](MOTION-PROMPTS.md). Die Referenzen sind Musterbibliothek, keine Aufforderung, fremde Oberflächen zu kopieren.
