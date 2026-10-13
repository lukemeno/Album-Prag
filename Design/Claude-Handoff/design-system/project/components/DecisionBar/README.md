# DecisionBar

Drei gleichwertige Entscheidungsknöpfe unter der Ideenkarte und das jederzeit erreichbare Rückgängig.

**SwiftUI:** Buttons in `InboxView` („Nein“, „Offen“, „Ja“, `Label("Rückgängig")`) · Status: **Vereinheitlichen**

- Drei Kacheln gleicher Breite, `radius-tile`, 64 pt hoch: Nein (Symbol `x` in `red`), Offen (`chev-d`/Pfeil nach oben), Ja (`action-fill`, Häkchen).
- Jede Wischgeste hat ihren Knopf. VoiceOver-Aktionen „Ja“, „Nein“, „Offen“ liegen zusätzlich auf der Karte.
- Während des Ziehens wächst die passende Kachel (1.04), die anderen treten auf 50 % zurück.
- Nach jeder Entscheidung erscheint der Undo-Toast (siehe Toast). „Rückgängig“ bleibt bis zur nächsten Entscheidung erreichbar.
- Weggewischte Ideen gehen nicht verloren: „Nein“ und „Offen“ stehen gefiltert in der Sammlung bzw. in der Liste „Entschieden“.
