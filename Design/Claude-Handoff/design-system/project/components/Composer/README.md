# Composer

Eingabezeile des Assistenten mit Diktieren über die iOS-Tastatur und einem Navy-Sendeknopf, darüber Vorschlagschips.

**SwiftUI:** Eingabe in `AssistantView` · Status: **Bestand**

- Pille auf `card` + `rule`, Platzhalter „Womit soll ich helfen?“, Sendeknopf 36 pt `action-fill`. Ist das Feld leer, ist der Knopf deaktiviert (`opacity-disabled`).
- Vorschläge als kleine Chips: „Was passt jetzt?“ und weitere aus dem Reisekontext.
- Standort nur auf ausdrücklichen Aufruf, mit iOS-Berechtigung.
