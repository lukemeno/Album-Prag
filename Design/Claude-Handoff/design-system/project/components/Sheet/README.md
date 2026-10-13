# Sheet

Blätter und das verschiebbare Ortsblatt. Ein Blatt hat oben `radius-floating`, einen Greifer und einen ruhigen Kopf.

**SwiftUI:** `PlacesDrawer` (Zustände hidden · collapsed · half · full), System-Sheets in `AlbumRoot` · Status: **Bestand; Kopf vereinheitlichen**

## Ortsblatt (Karte)
- **hidden:** nur die Karte, unten eine kleine Pille „Liste“ zum Wiederöffnen.
- **collapsed:** Greifer, Titel in `sheet-title` („2 Orte“), Untertitel `meta` („Heute 1 Ort“).
- **half:** zusätzlich Filterchips und die ersten Zeilen (Referenz).
- **full:** volle Liste, Kopf bleibt stehen. Im Querformat links als schwebendes Panel (360 pt).
- Greifer 40 × 5 in `ink-soft` 45 %. Federung `--motion-panel`, bei Reduce Motion Überblendung.
- Kopfaktionen rechts: „Tage planen“ (Koralle), „Ordnen“, Schließen (`x`).

## Modale Blätter
Navigationsleiste mit „Abbrechen“ links, Titel mittig (17 pt semibold) und der Primäraktion rechts („Speichern“, „Übernehmen“, „Fertig“). Wichtige Bestätigungen erscheinen zusätzlich als Primärpille am Ende des Inhalts.
