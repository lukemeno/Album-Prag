# TicketCard

Flug- und Hotelkarte mit Abrisskante, aus dem PDF gelesen.

**SwiftUI:** `TicketShape`, `BoardingPass.swift`, `TicketRow` in `ReiseView` · Status: **Bestand**

- `card`, `radius-thumb`, zwei Kerben (9 pt) an der Abrisskante, gepunktete Trennlinie in `rule`. Rechts der Abschnitt (96 pt) für Buchungscode bzw. Sitz.
- Flughafen-Codes in Fraunces 28, Werte in `ticket` (Mono), Labels in Versalien `ink-soft`.
- **Nur echte Daten.** Bis ein PDF ausgelesen ist, zeigt die Karte Gedankenstriche und „Aus dem PDF lesen“. Der Figma-Entwurf „EW4241 CGN → PRG“ ist nicht bestätigt und erscheint nicht.
- Hotel: Name aus `TripInfo.hotel` („Hotel Urban Crème“), Check-in/-out nur, wenn ausgelesen, sonst „Unterkunft“. Passepartout `mat-lilac`.
- Tippen öffnet die Reiseunterlagen, langes Drücken bietet „Kopieren“ für Buchungsnummern.
