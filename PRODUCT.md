# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Zwei Menschen, ein Paar, beide mit iPhone. Sie planen gemeinsam Reisen, die erste ist Prag vom 4. bis 9. Oktober 2026 (Hotel Urban Crème). Beide sammeln unabhängig voneinander Ideen aus TikTok, Instagram und dem Netz und wollen daraus eine gemeinsame Reise machen.

Drei Nutzungssituationen, alle gleich wichtig:
- **Vorher planen:** zu Hause, mit Ruhe. Ideen einwerfen, über die Ideen des anderen abstimmen, Orte auf der Karte sehen, Reisedaten und PDF-Unterlagen ablegen.
- **Unterwegs in Prag:** auf der Straße, oft einhändig, mit wechselndem Netz. Wo ist der Ort, was steht heute an, wie komme ich an Ticket oder Buchung.
- **Danach erinnern:** nach der Reise. Was haben wir wirklich gemacht, eigene Fotos, etwas zum Durchblättern.

## Product Purpose

Eine private Reise-App nur für zwei. Sie macht aus verstreuten Links und Screenshots einen gemeinsamen Plan und am Ende eine Erinnerung. Erfolg: Beide werfen ihre Funde gern hinein, entscheiden gemeinsam, was sie machen, finden unterwegs alles sofort und haben danach ein Album, das sie sich gern anschauen.

## Positioning

Keine Planungs-Software und kein Reiseportal, sondern ein schöner, einfacher Ort für eine gemeinsame Reise: Links sammeln, gemeinsam entscheiden, was ihr davon macht, und alles Wichtige wiederfinden. Laut Nutzer zählen **schön aussehen** und **leichte Bedienung** am meisten. Dass zwei Menschen beteiligt sind, darf in der App spürbar sein, steht aber ausdrücklich **nicht im Vordergrund**.

## Operating Context

- Ideen kommen als Links (TikTok, Instagram, Webseiten) oder als Orte aus der Kartensuche.
- Abstimmen per Wischen: rechts = dafür („frankieren“), links = zurücklegen, mit Rückgängig.
- Reisedaten (Anreise, Flug, Hotel) und PDF-Unterlagen, bisher eine Datei „Prag Urlaub.pdf“ in iCloud.
- Synchronisierung zwischen zwei Geräten über einen privaten Einladungslink.

## Capabilities and Constraints

- Native SwiftUI-App, iOS, mit MapKit (Apple-Karten) und PDFKit. Projekt wird per XcodeGen (`project.yml`) erzeugt.
- Backend Supabase (Projekt `akzrlkbylglwrlbaacjo`): anonyme Anmeldung, Postgres mit RLS, Realtime, privater Storage, Edge Functions `create-trip`, `join-trip`, `place-photo`.
- Offline zuerst: Daten liegen lokal und werden später abgeglichen. Bei Konflikten gewinnt der neuere Stand.
- Ortsbilder: Linkvorschau → Wikimedia → optional Tripadvisor (aus) → eigenes Foto → gestalteter Platzhalter.
- Instagram wird nicht ausgelesen; TikTok nur per oEmbed.
- Installation über ein kostenloses Apple Personal Team; keine iCloud-, App-Group- oder Share-Extension-Entitlements.
- Datenmodell ist heute auf **eine** Reise ausgelegt (`TripInfo`). Entschieden: jetzt für Prag gestalten, aber so, dass später weitere Reisen Platz haben.
- Tools für die Gestaltung: Figma (Datei `BvFJ4PzwQXAxhPlrEw73rB`), Rive CLI 1.0.1.

## Brand Commitments

- Nichts ist gesetzt: Name „Album“, Zwei-Türme-Logo und die Briefmarken-Metapher dürfen ersetzt werden. Die Briefmarken-Idee gefällt, ist aber nicht bindend.
- Verbindliches Gefühl laut Nutzer: **cozy und sweet**.

## Evidence on Hand

- Echte Fotos aus Prag (Karlsbrücke, Altstadt, Letná, Café) in `Album/Assets.xcassets` und `~/Travel Buddy/references/photos/`.
- Screenshots des jetzigen Stands: `Album/Figma Screens/01–08`.
- Design-Referenzen der Nutzer (X-Posts, Inspora, Sticker, Briefmarken): `~/Travel Buddy/references/`.
- Keine echten Flugdaten bestätigt; die Figma-Flugdaten (EW4241 CGN → PRG) sind nur ein Entwurf.

## Product Principles

1. **Schön und leicht vor allem anderen.** Jede Gestaltungsidee muss die Bedienung einfacher oder angenehmer machen, nie schwerer.
2. **Gemeinsam entscheiden, ohne Aufhebens.** Man sieht, was beide wollen, aber die Zweisamkeit ist Beiwerk, nicht Thema.
3. **Eine Reise ist ein Objekt, keine Liste.** Planen, Erleben und Erinnern sind dieselbe Sache in drei Zuständen.
4. **Unterwegs schlägt schön.** Was man in Prag auf der Straße braucht, ist mit einer Hand und schlechtem Netz sofort erreichbar.
5. **Einwerfen muss mühelos sein.** Ein Link genügt; die App ergänzt Ort, Bild und Kategorie.
6. **Offline ist der Normalfall.** Nichts geht verloren, wenn das Netz fehlt.

## Accessibility & Inclusion

- Die App unterstützt bereits „Bewegung reduzieren“. Jede neue Animation braucht eine ruhige Alternative.
- Jede Wischgeste hat eine gleichwertige Schaltfläche.
