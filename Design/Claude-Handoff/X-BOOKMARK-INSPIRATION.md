# X-Bookmark-Inspiration — Album

Geprüft: die 20 neuesten Einträge aus den X-Bookmarks des Nutzers. Die Auswahl wurde nach tatsächlichen Produkt-, UI- und Motion-Beispielen gefiltert. Die Referenzen dienen als Inspiration; Album übernimmt weder fremde Produktlogik noch einen fremden visuellen Stil.

## Für Album besonders relevant

### Swipe-Entscheidung mit ehrlichem Undo

[withAnimation — „delightful yet concise feedback“](https://x.com/withAnimationUI/status/2105584911046557713)

Der Clip zeigt zwei klare Optionen. Nach Auswahl wird die getroffene Option zu einer breiteren, farbigen Bestätigung („Rejected“); daneben erscheint ein gleich gut erreichbarer Undo-Pfeil. Das Feedback bleibt im selben Bereich und unterbricht den Flow nicht.

**Übertragung auf Album:** „Dafür“, „Dagegen“ und „Offen“ bleiben als verständliche, beschriftete Zustände erkennbar. Bei Tap oder Swipe folgt eine direkte visuelle Bestätigung mit dezenter, semantisch passender Haptik. Die Auswahl darf sich visuell durchsetzen, während die anderen Optionen zurücktreten; ein sofort erreichbares Rückgängigmachen bleibt sichtbar. Keine undokumentierte automatische Entscheidung beim bloßen Wegwischen.

### Ortskarten, die sich wie eine Sammlung anfühlen

[Dottaa — „An app for sharing/keeping random things“](https://x.com/HelloDottaa/status/2106271864053977096)

Die Screens zeigen eine persönliche, gemeinsam nutzbare Sammlung: visuelle Beiträge, kurze Beschriftungen, Kategorien und eine ruhige Feed-Ansicht. Die handschriftlichen Namen, angehefteten Fotos und gezackten Ränder erzeugen viel Eigencharakter, wirken für Album aber als Vollstil zu verspielt.

**Übertragung auf Album:** Beiträge von Mitreisenden und gespeicherte Orte sollen schnell als persönliche Sammlung lesbar sein. Dafür eignen sich klare Foto-Karten, sparsame Absender-/Kategorie-Metadaten und eine subtile Editorial-Note. Album bleibt heller, ruhiger und fotozentriert; keine handschriftliche Schrift oder Briefmarkenkante auf jeder Karte.

[Nao — „Motion details“](https://x.com/andaui/status/2104901575596560607)

Im Video erscheinen hochwertige Fotokarten horizontal als zusammenhängendes Karussell: kleiner Kontextkopf, große Motive, knappe Preis-/Beschreibungstexte und ein sofort erkennbarer Favorit. Der horizontale Aufbau unterstützt Entdecken, ohne den Inhalt zu überladen.

**Übertragung auf Album:** Für Ortsvorschläge oder passende Orte neben einem ausgewählten Pin können horizontale Fotokarten mit klarer Auswahl-/Favorit-Aktion funktionieren. Auf der Karte muss die Auswahl in der Liste synchron bleiben; der Karten-Feed darf die vollständige Karte nicht verdrängen.

### Ruhiger, klarer Einstieg

[Doji-Onboarding von Spotted in Prod](https://x.com/spottedinprod/status/2106054951051129332)

Der Clip hält die Produktaufnahme auf einem ruhigen, hellen Screen: ein zentrales Motiv, viel Weißraum, eine kurze Erklärung und eine eindeutig platzierte „Next“-Aktion. Die Bewegung liegt in der Präsentation und hält Text und CTA lesbar.

**Übertragung auf Album:** Für Reise-Start, leere Sammlungen oder einen neuen Tag kann ein starkes, echtes Reisefoto mit genau einer sinnvollen Hauptaktion besser funktionieren als mehrere gleich gewichtete Karten. Das ist ein Hierarchie-Muster, kein zusätzlicher Onboarding-Zwang.

### Motion beschreiben und systematisch wiederverwenden

[Alex Kehr — Taste Design Breakdowns](https://x.com/alexkehr/status/2106063484824010858)

Das Video zeigt zu einer Produktansicht konkrete Motion-Ereignisse mit Zeitpunkten und kurzen Beschreibungen, etwa wann Tabs wechseln oder eine Liste neu erscheint. Es ist primär ein Werkzeug-/Web-UI und keine Stilvorlage für Album.

**Übertragung auf Album:** Animationen bekommen im Expo-Designsystem explizite Rollen und überprüfbare Spezifikationen: Auslöser, Bewegungsziel, Dauerbereich, Kurve, Haptik, Abbruch/Undo und Reduced-Motion-Fallback. So lässt sich „fühlt sich flüssig an“ anhand konkreter Abläufe überprüfen.

## Sekundäre Referenzen

- [Planner for iPhone Duo](https://x.com/kombaiselects/status/2105704299645001839): Das Video zeigt ein Journal neben einer Sticker-Auswahl; ein Kaffee-Sticker wird in die Seite gezogen. Für Album ist die direkte, greifbare Drag-Geste interessant, der Scrapbook-Stil passt jedoch nicht als durchgängige Gestaltung.
- [SwatchThis-Profil](https://x.com/azhassan_/status/2105677869099983154): persönliche Fotoauswahl und sichtbare Profilstatistik. Der dunkle, handschriftliche Look ist für Album kein Zielbild; interessant bleibt ein individueller, aber strukturierter Sammlungs-/Profilbereich.
- [ADHD-App-Onboarding](https://x.com/yarSaverin/status/2105751184774447516): klare Progress-Anzeige, eine zentrale Illustration und eine einzelne „Next“-Aktion. Die dunkle 3D-Spielwelt ist thematisch fremd; die ruhige Führung durch einen Schritt ist übertragbar.
- [Orbit Image Carousel](https://x.com/raul_dronca/status/2105931809607344418): als Karussell-Interaktion relevant, der Inhalt ist für Album nicht belegt genug, um daraus ein konkretes Muster abzuleiten.

## Bewusst nicht als Album-Vorlage übernommen

Portfolio-/WebGL-Showcases, KI-SaaS-Dashboards, allgemeine KI-/Produktwerbung, React-Komponenten-Ressourcen und stark gamifizierte Interfaces bilden keine passende Produkt- oder Stilreferenz. Sie wurden beim Filtern erkannt, aber nicht in Album-Ziele umgewandelt. Beim „Stamps“-Clip konnte das Medium auf X nicht laden; daraus wurde keine visuelle Schlussfolgerung gezogen.

## Daraus abgeleitete Leitplanken

1. Der Stil bleibt hell, ruhig und fotozentriert wie in den ausgewählten Album-Screenshots; die X-Fundstücke ergänzen vor allem konkrete Interaktionsmuster.
2. Entscheiden fühlt sich unmittelbar und korrigierbar an: „Dafür“, „Dagegen“ oder „Offen“, mit kurzer Bestätigung und einem sichtbaren Rückweg.
3. Fotos tragen die Ortsauswahl. Karten, Karte und Liste teilen sich einen synchronen Auswahlzustand.
4. Haptik folgt bedeutsamen Aktionen, nicht jedem Scroll- oder Tap-Kontakt.
5. Für Expo Go wird Motion nativ wirkend, mit Reanimated auf dem UI-Thread umgesetzt; Haptics bleiben sparsam und Reduced Motion erhält einen ruhigen Fallback.
6. Scrapbook, Sticker und handschriftliche Akzente dürfen punktuell als Album-Charakter auftauchen, aber nie Lesbarkeit, konsistente Komponenten oder die zentrale Typografie ersetzen.
