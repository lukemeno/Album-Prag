# Tagesplan

Automatisch vorgeschlagene Tagespläne werden vor der Übernahme bestätigt. Danach zeigt die Tagesansicht die Stopps mit „Als Nächstes“.

**SwiftUI:** `DayPlanGenerator.swift`, `DayPlanPreview.swift`, `PlacesDrawer` („Tage planen“), `ReiseView` · Status: **neu abgeleitet**

- „Tage planen“ (Koralle) öffnet das Blatt „Vorschlag“: Tageschips So 4. bis Fr 9., nummerierte Stopps, freie Zeitfenster als „Frei“, Kartenausschnitt mit gezeichneter Route.
- Start am Hotel Urban Crème (`TripInfo.hotel`). Öffnungszeiten werden geprüft; ohne Daten erscheint keine Angabe.
- „Übernehmen“ speichert atomar. Danach folgt der Toast „Plan für Mo, 5. Okt übernommen“ mit „Rückgängig“.
- Tagesansicht: Fortschritt über besuchte Orte (`teal`), der nächste Stopp liegt auf `selection` mit Wegsymbol. „Ordnen“ für die Reihenfolge per Ziehen.
- Entfernungen nur bei freigegebenem Standort.
