# VisitSlider

Schieber „Als besucht markieren“. Erst eine bewusste Wischbewegung markiert einen Ort als besucht.

**SwiftUI:** `VisitedTrack` (Album/Stitch/VisitedTrack.swift) · Status: **Bestand**

- Pille `size-button`, `card` + `rule`, Label in `red`. Der Griff ist ein 44-pt-Kreis mit `forward`-Symbol und `elevation-pinned`.
- Beim Ziehen füllt sich die Spur mit 12 % `red`. Ab 85 % rastet der Griff mit Haptik (`.impact`) ein, und die Pille wechselt auf `teal` („Besucht“).
- Gleichwertige Alternative: Tippen öffnet einen Bestätigungsdialog. VoiceOver bietet die Aktion „Als besucht markieren“ direkt an.
- Reduce Motion: Der Griff springt ohne Federung, der Zustand blendet über.
