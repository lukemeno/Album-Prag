# Reise

Startseite „Reise“: Albumkopf, Titelfoto mit Ziel und Zeitraum, Teilnehmerzeile, Reiseplan mit Tageskacheln, Heute, Unterlagen und wartende Ideen.

**Referenz:** `approved-native-design.png` (links) + `2026-10-04-reference-reise.png` · **SwiftUI:** `ReiseView.swift`, `TripDataViews.swift`

## Abgleich mit der Referenz (402 pt Breite)
| Element | Referenz | System |
|---|---|---|
| Titel „Album“ | Fraunces ~34 pt, links, 20 pt Rand | `display` |
| Kopf-Knöpfe | 2 × 44-pt-Kreise, weiß mit Kontur | IconButton |
| Titelfoto | 362 × 300, Radius ~22, Verlauf unten | PhotoCard `size-hero`, `radius-card` |
| „Prag“ / Zeitraum | Serif ~48 / 16 pt, weiß | `hero-title` / `callout` |
| Teilnehmer | Initialen-Kreis + Pille „Einladen“ | ParticipantRow |
| Reiseplan | weiße Karte mit Kontur, 94-pt-Kacheln | `al-card` + DayTile |
| Tab-Leiste | schwebend, 3 Tabs, aktive Pille | TabBar |
| KI-Kreis | 48 pt Navy unten rechts | AssistantButton (freigegeben) |

## Bewusste Abweichungen von `approved-native-design.png`
Keine Profilfotos, kein Glockensymbol, keine Briefmarke im Titelfoto, keine „Explore/Activity/Profile“-Tabs: Album hat genau drei Tabs. Englische Texte sind durch die echten deutschen Labels ersetzt.

Beim Scrollen wird die Tab-Leiste kompakt. „Heute“ zeigt den Tagesplan oder „Noch nichts geplant“ mit „Tage planen“.
