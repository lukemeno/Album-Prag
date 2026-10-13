# Stamp

Briefmarken-Fassung für Fotos in „Erinnerungen“: gezähnter Rand in `card`, Passepartout in der Kategoriefarbe, darin das Bild.

**SwiftUI:** `StampFrame`, `StampShape`, `Postmark` (Stitch.swift) · Status: **Bestand, nur in Erinnerungen**

- Passepartout = `mat-*` der Kategorie (Essen `mat-rose`, Sehenswert `mat-sky`, Aussicht `mat-butter`, Unterkunft `mat-lilac`, Shopping `mat-mint`).
- Schatten `elevation-pinned`. Leichte Neigung (±3°) aus der Orts-ID (`stableTilt`), nie zufällig.
- Poststempel in `red`, Ring 2 pt, 76 pt, −12° gedreht, „PRAHA“ + Datum. Reine Zierde, `accessibilityHidden`.
- Die Briefmarken-Metapher bleibt auf Erinnerungen und Erststart beschränkt. Reise, Karte und Detail folgen der Referenz ohne Zähnung.
