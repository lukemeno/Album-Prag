# Beta-Checkliste für Album · Entwurf 29.10.2026

Quelle: die fünf Beta-Tests von ceciliakimdesign. Wunsch des Nutzers (29.10.): Album wird genau so geprüft. Jeder Test wird als E2E-UI-Test in `AlbumUITests/BetaChecklistUITests.swift` umgesetzt, mit isoliertem Test-Store und Screenshot als Beleg. Zuerst werden die Tests geschrieben, dann die Fehler behoben, bis sie grün sind.

Stand laut Code-Review vom 28.10.: Alle fünf schlagen heute ganz oder teilweise fehl.

| Nr. | Test | Ablauf in Album | Bestanden, wenn | Stand 28.10. |
|---|---|---|---|---|
| 1 | Einfügen statt Tippen | In Ausgaben „1.250,50 “, „12,50 €“, „€ 12,50“ und „12.50“ einfügen. In Neue Idee „www.prague.eu“ und „Schau mal: https://prague.eu/x“ als Link einfügen. | Alle Beträge werden erkannt. Der Link wird zu einer gültigen https-Adresse. „Speichern“ ist aktiv, oder es steht ein verständlicher Hinweis daneben. | Teilweise: Leerzeichen geht, „€“ und „12.50“ nicht, Link ohne https wird still abgelehnt |
| 2 | Versehentlich löschen | Idee über „…“ → Löschen. Erinnerungsfoto über das Kontextmenü löschen. | Rückfrage mit Namen oder „Rückgängig“ für einige Sekunden. Nach „Behalten“ bzw. „Rückgängig“ ist alles wie vorher, auch nach Sync. | Fehlt (sofort gelöscht) |
| 3 | Formular aus Versehen schließen | In Neue Idee, Neue Ausgabe und Neue Reise etwas eintragen, dann nach unten wischen und „Abbrechen“ tippen. | „Änderungen verwerfen?“ mit „Weiter bearbeiten“. Ein leeres Formular schließt ohne Rückfrage. | Fehlt |
| 4 | Öffnen, dann zurück | In Ideen nach unten scrollen, eine Idee bearbeiten und schließen. Zu Karte wechseln und zurück. | Die Liste steht an derselben Stelle, Filter und Kartenausschnitt bleiben erhalten. | Teilweise: Sheet geht, Tab-Wechsel setzt zurück |
| 5 | Finden, was man gerade hinzugefügt hat | Bei 30 Ideen eine neue Idee speichern. | Die Liste zeigt die neue Idee sichtbar mit „Neu“-Marke, dazu kurz „Idee hinzugefügt“. | Fehlt (landet unten) |

Die vier weiteren Tests aus der Bildunterschrift des Posts liegen nicht vor. Die Liste wird ergänzt, sobald du sie schickst.

## Einordnung in den Plan

Vorschlag zur Reihenfolge: P0 (Debug-Seeding) → **Beta-Checkliste** (Tests rot schreiben, dann beheben) → P1 Begleittext → P2 Video → P3. P3 aus `PLAN-VIDEO-ORTE.md` geht dabei in Test 5 auf. Ab dann muss jedes neue Paket alle fünf Tests grün halten, bevor es als fertig gilt.
