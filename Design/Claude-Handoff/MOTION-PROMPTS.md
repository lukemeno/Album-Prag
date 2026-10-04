# Motion-Prompts aus den Screenrecordings

Die folgenden Prompts beschreiben Qualitäten und Abläufe, die in den sechs vom Nutzer geteilten Clips zu sehen sind. Sie sind einzeln verwendbar oder können zusammen in Claude eingefügt werden. Die Clips stammen teilweise aus anderen Apps und Produktkategorien: übertrage deshalb die Bewegungsqualität auf passende Album-Interaktionen, nicht deren fremde Produktlogik oder Gestaltung.

## 1. Entscheidung mit klarer Rückmeldung und Undo

**Referenz:** `motion/album-motion-17.29.43.png`

> Gestalte die Entscheidung bei einer Idee als klaren, unmittelbaren Zustandswechsel. Beim Auswählen einer positiven oder negativen Option reagiere das betätigte Element direkt: kurzer haptischer Kontakt, ein präziser Farb-/Symbolwechsel und eine kompakte Bestätigung, die den neuen Zustand eindeutig benennt. Die Auswahl soll abgeschlossen wirken, ohne den Nutzer aus dem Flow zu werfen. Biete eine gut erreichbare Undo-Möglichkeit an, die für einen kurzen Moment sichtbar bleibt und die letzte Entscheidung zuverlässig rückgängig macht. Übertrage dieses Prinzip auf Album mit den vorhandenen Zuständen „Dafür“, „Dagegen“ und „Offen“; lasse keine Option wie ein stummes Überspringen wirken. Vermeide dauerhaft grelle Flächen, übertriebene Rückfederung und Haptik bei jeder kleinsten Berührung.

## 2. Detailblatt, Favorit, erfolgreiche Aktion und aktualisierte Anzahl

**Referenz:** `motion/album-motion-17.29.05.png`

> Nutze die Qualität dieses Ablaufs als Inspiration für Album: Ein Detail öffnet sich als räumlich nachvollziehbare Erweiterung des Elements, aus dem es stammt; ein Favorit reagiert fein und taktil; eine bestätigte Hauptaktion verändert ihren Button in einen eindeutigen Erfolgszustand; zugehörige Zähler aktualisieren sich unmittelbar und ruhig. Lass die Aktion nicht abrupt verschwinden: kurze morphende Übergänge und eine konsistente Erfolgsfarbe vermitteln, was passiert ist. Übertrage das auf passende Album-Vorgänge wie Ort merken, Idee zur Sammlung hinzufügen oder einen Ort in einen Tagesplan übernehmen. Nutze passende Undo- oder Rückgängigwege, wo eine Aktion korrigierbar sein sollte. Halte Inhalte, VoiceOver-Ansagen und tatsächlichen Datenzustand synchron; Animation darf keinen falschen Erfolg vortäuschen.

## 3. Reiseillustration als zusammenhängendes Panorama

**Referenz:** `motion/album-motion-17.28.37.png`

> Entwickle für Album eine warme, eigenständige Reisebewegung, bei der eine horizontale Panorama- oder Collage-Illustration mehrere Orte als zusammenhängende Reise zeigt. Die Bewegung soll wie ein sanftes Entdecken wirken: Elemente kommen mit dezenter Tiefe und leicht versetzten Ebenen ins Bild, der Blick kann entlang der Route wandern, und der Übergang landet ruhig auf dem nächsten Motiv. Lass Text und Bedienelemente stabil und lesbar bleiben. Setze diese Inszenierung nur dort ein, wo eine Reise, Route oder ein Ortswechsel inhaltlich davon profitiert; sie soll nicht als dauernder Hintergrund und nicht als dekorativer Effekt auf jedem Screen laufen. Entwickle Bildsprache und Timing eigenständig für Album.

## 4. Weicher Übergang zwischen Reiseorten / Panorama-Schwenk

**Referenz:** `motion/album-motion-17.26.23.png`

> Nutze einen horizontalen Panoramawechsel als Referenz für Übergänge zwischen Reiseabschnitten: Die Illustration oder Bildfläche darf sich etwas weiterbewegen als der Inhalt, während sich der nächste Ort natürlich in den Fokus schiebt. Erzeuge einen klaren räumlichen Zusammenhang, ohne die Bedienoberfläche mitzuziehen oder Orientierung zu verlieren. Der Wechsel sollte auf eine Geste reagieren, die Geschwindigkeit des Fingers respektieren und beim Loslassen kontrolliert zum nächsten sinnvollen Halt animieren. Ein Wechsel zurück muss sich genauso selbstverständlich anfühlen. Baue keine endlose Bewegungsschleife ein; achte auf Reduce Motion und statische Fallbacks.

## 5. Langer Reiseplan: natürliches vertikales Scrollen

**Referenz:** `motion/album-motion-17.25.05.png`

> Poliere das vertikale Durchblättern eines längeren Reiseplans. Die Liste soll direkt unter dem Finger folgen, mit natürlicher Trägheit auslaufen und ohne ruckelige Sprünge oder ungewollte Konkurrenz zwischen Scroll- und Sheet-Geste stoppen. Ein sinnvoller Reise-/Tageskopf darf während des Scrollens stabil und lesbar bleiben, aber Inhalte dürfen nicht verdeckt werden. Halte Datum, Ort und Tagesabschnitte beim Vorbeiziehen gut unterscheidbar. Verwende leichte Übergänge für Abschnittswechsel, keine Animation pro Listenzeile und keine künstliche Verzögerung. Prüfe kurze und lange Listen sowie Hoch- und Querformat.

## 6. Weiterblättern und ruhiges Einrasten in einer Liste

**Referenz:** `motion/album-motion-17.24.51.png`

> Nimm aus diesem Clip das ruhige, kontrollierte Navigieren durch wiederholte Reiseeinträge mit: Scrollen soll fein dosierbar bleiben, bei kleinen Fingerbewegungen nicht überreagieren und nach einer längeren Bewegung sauber in einem stabilen Zustand landen. Bewahre die Orientierung über mehrere Einträge hinweg; falls sich ein Hero-Bild oder Tageskopf mit dem Inhalt bewegt, soll dessen Verhalten konsistent und vorhersehbar sein. Verbinde keine gleichzeitig scrollenden Flächen mit mehrdeutigen Gesten. Für Album ist Lesbarkeit und Kontrolle wichtiger als ein auffälliger Parallax-Effekt. Verifiziere auch den Übergang zwischen Kartenblatt und darunterliegendem Inhalt, falls beide dieselbe vertikale Geste beanspruchen.

## Gemeinsamer Auftrag für das Motion-System

> Leite aus diesen Beispielen ein kleines, kohärentes Bewegungssystem für Album ab. Gib jeder Bewegung einen Zweck: Orientierung, Ursache/Wirkung, räumlicher Zusammenhang oder Bestätigung. Definiere wenige wiederverwendbare Rollen für Dauer, Kurven, Federverhalten und Haptik, statt pro Screen beliebige Werte zu verteilen. Interaktive Elemente sollen unter dem Finger direkt reagieren; Zustandsänderungen sollen klar sein und zuverlässig rückgängig gemacht werden können, wo sinnvoll. Haptik sparsam und semantisch passend einsetzen. Berücksichtige Reduce Motion, VoiceOver, Dynamic Type, Tastatur, iOS-Safe-Areas und alle unterstützten Interface-Orientierungen. Vermeide dekorative Daueranimationen, unnötige Bounces, ruckartige Sheet-Gesten und Animationen, die Funktionalität oder Inhalt verdecken. Entscheide selbst, welche dieser Inspirationsmuster tatsächlich zur Album-App passen.
