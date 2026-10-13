# Share Extension

Links und Bilder aus TikTok, Instagram, Safari oder Fotos an Album übergeben. Die Queue ist verlustfrei, vervollständigt wird später in Album.

**SwiftUI:** `ShareExtension/ShareViewController.swift`, `Shared/ShareInbox.swift`, `drainShareQueue()` · Status: **neu abgeleitet**

- Kompaktes Blatt über der Quell-App: Vorschau ohne Netzwerkaufruf (nur Host und Typ), optionaler Kommentar, Ziel „Prag 2026 · Sammlung“, „Sammeln“.
- Beim nächsten Öffnen von Album wird die Queue übernommen: Banner „2 geteilte Beiträge übernommen“. Beiträge für eine andere Reise bleiben erhalten und erscheinen als Hinweis.
- IDs sind deterministisch, eine Wiederholung erzeugt keine Dubletten.
