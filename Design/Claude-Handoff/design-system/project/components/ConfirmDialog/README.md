# ConfirmDialog

Bestätigungsdialog für folgenreiche, geteilte oder schwer umkehrbare Aktionen.

**SwiftUI:** `.alert`/`.confirmationDialog` in `PlaceEditor`, `AssistantView`, `CollectionViews` · Status: **Bestand (System), Texte vereinheitlichen**

- Systemdialog mit Album-Flächen: `card`, `radius-card`. Titel `label`/17, Text `footnote`.
- Formel: Titel = Frage mit Objekt, Text = Folge für **beide** iPhones. Beispiel: „Ort löschen?“ / „Er verschwindet auch auf dem anderen iPhone.“
- Plan übernehmen: „Plan übernehmen?“ / „Der Plan wird gegen die aktuelle Reise geprüft und erst jetzt gespeichert.“
- Die destruktive Option steht rechts in `red`, „Abbrechen“ links.
