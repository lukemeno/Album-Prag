# StateView

Leer-, Lade-, Offline- und Fehlerzustände in einer gemeinsamen Form.

**SwiftUI:** verstreute Leerzustände („Noch nichts gesammelt“, „Noch keine Flüge“, „Noch keine besuchten Orte“) · Status: **Neu als einheitlicher Baustein**

- Leer: Mulde 72 pt (`paper-deep`) mit Symbol, Titel `section`, ein Satz in `meta`, höchstens eine Aktion (sekundär oder primär).
- Laden: Skeletons in `paper-deep` mit der Form des Inhalts (Zeile, Karte). Kein Spinner auf ganzen Seiten.
- Offline: Banner `paper-deep` mit `wifi-off`. Inhalte bleiben sichtbar. Karte, Ortssuche und TikTok brauchen Netz und sagen das.
- Fehler: Banner `err` mit konkreter Ursache und „Erneut versuchen“. Nie „Etwas ist schiefgelaufen“ ohne Ausweg.
- Texte nennen, was bleibt („Links und Nachrichten bleiben hier, auch wenn du gerade offline bist.“).
