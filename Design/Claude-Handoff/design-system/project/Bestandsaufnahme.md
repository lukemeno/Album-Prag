# Bestandsaufnahme

Stand 4. Oktober 2026, Branch `design/album-visual-refresh`. Gelesen wurden AGENTS.md, PRODUCT.md, README.md, PROGRESS.md (Abschnitte 02.–04.10.), DESIGN-REDESIGN-PLAN.md, CHATBOT-PLAN.md, SAMMLUNG-PLAN.md, AlbumRoot.swift, Stitch.swift, Design.swift, Models.swift sowie die Labels aller Views. Expo ist ausgeklammert.

## Bereits umgesetzt (native App)

| Bereich | Stand im Code |
|---|---|
| Navigation | `TabView` mit Reise, Ideen und Karte, Badge mit Ideenzahl, Sheets für Editor, Teilen, Unterlagen, Name, PDF-Funde, Assistent |
| Reise | Titelfoto „Prag“ (imgPragueCover, CC BY-SA), Teilnehmerzeile mit „Einladen“, Reiseplan mit Tageskacheln, Heute, Unterlagen-Tickets, „N Ideen warten“, Abgleich-Insel, Erinnerungen |
| Ideen | Wischstapel Ja/Nein/Offen mit Buttons und Undo, Picker Entdecken/Sammlung, Quelle und Karte öffnen |
| Sammlung | Link- und Textbeiträge, Kommentare, Herzen, mehrere Orte, Linkvorschau (TikTok oEmbed, OG), Ortsvorschläge aus Text, CAS-Sync, Share-Queue |
| Karte | MapKit, Fotopins, Cluster, Suche, Filter, Drawer hidden/collapsed/half/full, Pin↔Liste synchron, Querformat links, Detail mit Route/Plan ändern/Teilen/Website, Besucht-Schieber |
| Editor | Link, Metadaten, Kategorie, Ortssuche, Bildwahl mit Quellenreihenfolge und Credits, eigenes Foto, Look-Around-Fallback |
| Unterlagen | PDF-Import, Auslesen von Flügen/Hotel/Buchung, Prüfblatt, Backup-Export |
| Assistent | KI-Kreis, privater Verlauf, Quellen, Web-Recherche, Orts- und Planvorschläge mit Bestätigung und Undo, Vorlieben |
| Systemweit | Offline zuerst, Supabase-Sync, Reduce Motion, Hoch-/Querformat, Accessibility-IDs |

## Uneinheitlich oder fehlend

| Befund | Wirkung | Im System gelöst durch |
|---|---|---|
| Stitch.swift trägt noch die „Briefmarke“-Welt (Zähnung, Poststempel, Perforation) in Kernscreens | weicht von der Referenz ab | Briefmarke nur in Erinnerungen, Erststart und Einladung (Stamp). Kernscreens ohne Zähnung |
| Kein Token für Kachelradius (Referenz ~16 pt) | Tages- und Aktionskacheln improvisiert | `radius-tile` (neu) |
| Tab-Leiste ist Standard-`TabView`, Referenz schwebt mit aktiver Pille | Kernscreens nicht referenzgetreu | TabBar, `tab-selected`, `size-tabbar` |
| Fotopins, Auswahl in Systemblau, Cluster ohne Tokens | Karte uneinheitlich | MapPin, `size-pin`, `system-blue` |
| Koralle für Primäraktionen (Code-Kommentar), Referenz nutzt Navy und Hellblau | zwei konkurrierende Akzente | Rollen getrennt: Navy = Primär, Hellblau = Auswahl/Hauptkachel, Koralle = Orts- und Tagesaktion |
| `action-fill` im Dunkelmodus unsichtbar (1.01:1 zu `paper`) | Primärknopf und KI-Kreis verschwinden fast | Kontur `rule` im Dunkelmodus (Regel in Button, AssistantButton) |
| `ink-soft` auf `paper` 4.48:1, auf `selection` 4.16:1 | Metadaten knapp unter AA | Regel: dort 15 pt semibold oder `ink`; Vorschlag `#6b6b70` für den Code |
| Leer-, Lade-, Fehler- und Offline-Zustände je Screen frei formuliert | wirkt zusammengestückelt | StateView, Banner, Skeleton |
| Formulare (Teilen, Reisedaten) im System-`insetGrouped`-Look | „Legacy“-Optik | ListRow auf Album-Flächen |
| Badges/Zustandsmarken verstreut | Farbe teils ohne Wort | Badge mit Wort und Symbol |
| Ideenkarte, Sammlung, Assistent-Karten nutzen eigene Kartenstile | keine gemeinsame Kartensprache | IdeaCard, CollectionPost, AssistantAction auf `radius-card`/`card`/`rule` |
| Undo-Leiste nur in Ideen | Bestätigung und Undo uneinheitlich | Toast für alle umkehrbaren Aktionen |
| Mockup-Inhalte (Sterne, „12K“, Profilfotos, km) | würden erfundene Daten zeigen | ausdrücklich weggelassen, Initialen statt Fotos |

## Abgedeckte Screens

- **Kern (referenzgetreu nachgebaut):** Reise, Reise weiter unten · Karte half, full und Querformat · Ortsdetail, Detail mit Quelle/Adresse/Credits, Detail besucht
- **Unterstützend (abgeleitet):** Ideen (Entdecken, Ziehen + Undo, alles entschieden + Wiederfinden) · Sammlung (Liste, Beitrag + Ortsvorschläge, Sammeln) · Editor (Link erkannt, Ortssuche, Bildwahl) · Unterlagen (Liste, PDF-Funde, Reader) · Assistent (Chat, Planvorschlag + Bestätigung + Konflikt, Vorlieben) · Tagesplan (Vorschlag, Tag unterwegs) · Teilen (Einstellungen, Einladung empfangen, Sync-Fehler) · Erststart und Erinnerungen · Share Extension (Teilen-Blatt, Queue übernommen)
- **Randzustände:** Offline, leere Karte, Laden mit Bildfehler. Dazu kommen die Zustände in den Komponenten: Sync ausstehend/Fehler/erfolgreich, fehlende Bildquelle, manueller Bildentscheid, Bestätigung/Undo, Upload-Fortschritt.

## Prüfhinweis

Die Kernscreens sind als Web-Nachbau proportional an den Referenzen ausgerichtet (402 pt Breite). Laut AGENTS.md gilt das native Design erst nach direktem Screenshotvergleich im Simulator als referenzgetreu. Dieses System ist die Vorlage für diesen Vergleich, nicht der Nachweis.
