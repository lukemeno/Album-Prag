# AssistantMessage

Chatnachrichten des Reise-Assistenten mit Quellenzitaten.

**SwiftUI:** `AssistantView.swift`, `AssistantModels.swift` · Status: **Bestand; Stil angleichen**

- Eigene Nachricht: rechts, `action-fill` + `on-accent`, untere rechte Ecke 6 pt. Im Dunkelmodus auf `selection` mit `ink`.
- Antwort: links, `card` + `rule`, untere linke Ecke 6 pt, Text `body`/16.
- Zitate inline als `al-cite`-Kapsel mit Nummer. Darunter folgt der Block „Quellen“ mit Dokumentname bzw. Domain und dem **wörtlichen** Zitat in `ink-soft` kursiv.
- Fehlt eine Information, sagt die Antwort das ausdrücklich. Check-in-Zeiten oder Flugdaten werden nie erfunden.
- Laden: „Ich sehe kurz nach …“ in `ink-soft` kursiv, Abbrechen möglich. Fehler: Banner mit „Erneut versuchen“.
- Verlauf und Vorlieben sind privat und lokal („Verlauf bleibt offline verfügbar.“).
