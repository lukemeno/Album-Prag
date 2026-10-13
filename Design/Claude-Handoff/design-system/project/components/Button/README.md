# Button

Pillenförmiger Knopf in drei Rollen: Primär (Navy-Fläche), Sekundär (helle Pille mit Kontur) und Textaktion.

**SwiftUI:** `StitchButton(primary:)`, `TextActionButton(tint:)` (Stitch.swift) · Status: **Bestand**

## Regeln
- Höhe `size-button` (52), Schrift `label`, Text **geometrisch zentriert**, Icon links mit 8 pt Abstand.
- Primär: `action-fill` + `on-accent`. Pro Ansicht genau eine Primäraktion, z. B. „Los geht’s“, „Übernehmen“ oder „Speichern“.
- Sekundär: `card` + 1 pt `rule` + `ink`. Das gilt für „Einladen“, „PDF hinzufügen“ und „Erneut versuchen“.
- Textaktion: `ink` (z. B. „Alle öffnen“). In Koralle (`red`) nur bei Orts- und Tagesbezug: „Tage planen“, „Route“, „5. Okt“.
- Destruktiv („Ort löschen“, „Beitrag löschen“) als Textaktion in `red` mit Bestätigungsdialog. Keine rote Fläche.
- Gedrückt: Skalierung 0.97 mit `--motion-press`. Bei Reduce Motion entfällt die Skalierung. Deaktiviert: `opacity-disabled`.
- Fokusring: 2 pt `system-blue` mit 3 pt Abstand in `paper`.
- Im Dunkelmodus erhält die Navy-Fläche eine `rule`-Kontur, weil `action-fill` dort kaum vom Grund abweicht.
