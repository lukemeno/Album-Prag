# Ideen · Entdecken

Ideenstapel zum gemeinsamen Entscheiden. Wischen oder Knöpfe: rechts = Ja, links = Nein, oben = Offen. Undo ist immer erreichbar.

**SwiftUI:** `InboxView.swift` (Picker „Entdecken“/„Sammlung“), `LetterSlot.swift` · Status: **neu abgeleitet**

- Großer Titel „Ideen“ in `display` (30 pt) mit „+“ als „Idee einwerfen“. Darunter der segmentierte Picker.
- Zähler „81 Ideen warten“ links, „Rückgängig“ rechts als Textaktion.
- Karte: IdeaCard mit zwei Stapelkanten. Darunter die DecisionBar mit drei gleichwertigen Kacheln.
- Beim Ziehen erscheint der Stempel, die passende Kachel wächst. Nach der Entscheidung kommt der Undo-Toast über der Tab-Leiste, und der Tab-Badge zählt herunter.
- **Weggewischt bleibt auffindbar:** Unter „Entschieden“ stehen Filter Ja / Nein / Offen, jede Idee lässt sich ändern. „Offen“ gilt nur für den aktuellen Durchgang.
- Leer: „Alles entschieden“ mit „Idee einwerfen“ als Primäraktion.
