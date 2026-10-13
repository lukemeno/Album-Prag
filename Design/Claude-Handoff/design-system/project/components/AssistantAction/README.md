# AssistantAction

Bedienbare Antwortkarten: Ortsvorschlag, Planvorschlag und Bestätigung. Chattext allein verändert nie etwas.

**SwiftUI:** `AssistantActions.swift`, `DayPlanPreview` · Status: **Bestand; Karten angleichen**

- Ortskarte: Thumbnail `size-thumb`, Name `place-s`, Adresse in `meta`, Quelle als Badge. Aktionen: „Auf Karte zeigen“ (sekundär) und „Als Idee speichern“ (primär).
- Planvorschlag: Titel „Planvorschlag“ mit Tag, nummerierte Stopps (PlaceRow-Nummern), darunter „Plan prüfen und übernehmen“.
- Jede Änderung braucht zuerst eine Vorschau, dann die Bestätigung („Übernehmen“) und anschließend den Toast mit „Rückgängig“.
- Erledigt: Rahmen 1.5 pt `teal`, Label „Gespeicherte Orte erscheinen im Ideenstapel.“
- Konflikt (Plan zwischenzeitlich geändert): Banner `warn` „Der Plan wurde inzwischen geändert. Bitte erneut prüfen.“
