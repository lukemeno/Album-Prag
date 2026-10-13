# Reise-Assistent

Privater Chat mit gemeinsamem Reisekontext: Fragen zu Reise und Dokumenten mit Quellen, Web-Recherche, Orts- und Planvorschläge. Aktionen werden immer bestätigt.

**SwiftUI:** `AssistantView.swift`, `AssistantSession.swift`, `AssistantActions.swift`, `AssistantService.swift`, `CHATBOT-PLAN.md` · Status: **neu abgeleitet**

- Geöffnet über den KI-Kreis. Blatt mit „Schließen“, Titel und Einstellungen (Vorlieben). Oben der Hinweis auf Privatsphäre und Offline-Verlauf.
- Antworten kurz, Zitate als nummerierte Kapseln mit Quellenblock. Neue Orte als Ortskarten mit „Auf Karte“ und „Als Idee speichern“.
- Planvorschlag mit „Plan prüfen und übernehmen“, dann Bestätigungsdialog und Revalidierung. Konflikte erscheinen als Banner und überschreiben nichts.
- Vorlieben: sichtbar merken, bearbeiten, löschen. Web-Recherche und Standort sind getrennt schaltbar.
- Zustände: Laden („Ich sehe kurz nach …“, abbrechbar), Offline (Frage bleibt), Fehler („Erneut versuchen“), Quote erreicht (Banner, kein Absturz).
