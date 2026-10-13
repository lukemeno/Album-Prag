from gen_base import *

C = []  # (name, group, height, readme, body, stage_style)

def comp(name, group, height, readme, body, style=""):
    C.append((name, group, height, readme.strip() + "\n", body, style))

# ------------------------------------------------------------------ Fotos
comp("PhotoCard", "Fotos", 470, """
# PhotoCard

Fotofläche mit Verlauf, Titel und Bildnachweis. Sie ist die tragende Bildsprache der App: Titelfoto auf „Reise“, Ideenkarte, Ortsdetail und Tageskachel.

**SwiftUI:** `AlbumPhoto`, `PhotoCard` (Album/Design.swift) · Status: **Bestand, Maße an Referenz angleichen**

## Verwendung
- Titelfoto „Reise“: 362 × `size-hero` (300), `radius-card`, Titel in `hero-title`, Untertitel in `callout`, beides `on-accent` links unten (28 pt Innenabstand).
- Ortsdetail: randlos oben, das Blatt (`radius-floating`) überlappt das Foto um 28 pt.
- Verlauf exakt wie im Code: transparent bis 50 %, 6 % bei 74 %, 58 % bei 84 %, 84 % Schwarz am Boden. Kein farbiger Verlauf.

## Bildquellen in Reihenfolge
1. Linkvorschau (OG/Twitter, JSON-LD) – Kapsel „Bild der Quelle“
2. Wikimedia Commons – Kapsel „Foto: Urheber · Lizenz“
3. Tripadvisor (vorbereitet, standardmäßig aus)
4. Eigenes Foto / Upload – ohne Kapsel
5. Apple Look Around bzw. Kartensnapshot – Kapsel „Foto nicht verfügbar · Apple Karten · Straßenansicht“
6. Gestalteter Platzhalter: `paper-deep` mit Foto-Symbol in `ink-soft`

## Was der Consumer liefert
Bild-URL oder Asset, Titel, Untertitel, optional Credit/Lizenz. Für Fotos ohne gesicherten Ortsbezug immer die Bildwahl (ImageChoice) anbieten.

## Nicht
- Keine Bewertungen, Sterne oder erfundene Kennzahlen auf das Foto legen (die Referenz zeigt „4.8 (12K)“ – bewusst weggelassen).
- Credit nie weglassen, wenn die Lizenz ihn verlangt (CC BY-SA).
""", f'''
{cell("Titelfoto · Reise", photo("bridge", "grad", "width:362px;height:300px", f'<div class="corner r"><span class="al-iconbtn lg on-photo">{icon("more")}</span></div><div class="over"><div class="t-hero">Prag</div><div class="t-callout">4.–9. Oktober · Tag 1 von 6</div></div>'))}
{cell("Bildnachweis (Wikimedia)", photo("cover", "", "width:300px;height:200px", '<span class="al-credit">Foto: Thomas Fabian · CC BY-SA 2.0</span>'))}
<div class="al-cell" style="gap:20px">
{cell("Apple Look Around (Fallback)", '<div class="al-photo" style="width:220px;height:140px"><div class="al-lookaround"></div><span class="al-credit center">Foto nicht verfügbar<span style="font-weight:400">Apple Karten · Straßenansicht</span></span></div>')}
{cell("Platzhalter (kein Foto)", photo(None, "", "width:220px;height:110px"))}
</div>''')

comp("Stamp", "Fotos", 250, """
# Stamp

Briefmarken-Fassung für Fotos in „Erinnerungen“: gezähnter Rand in `card`, Passepartout in der Kategoriefarbe, darin das Bild.

**SwiftUI:** `StampFrame`, `StampShape`, `Postmark` (Stitch.swift) · Status: **Bestand, nur in Erinnerungen**

- Passepartout = `mat-*` der Kategorie (Essen `mat-rose`, Sehenswert `mat-sky`, Aussicht `mat-butter`, Unterkunft `mat-lilac`, Shopping `mat-mint`).
- Schatten `elevation-pinned`. Leichte Neigung (±3°) aus der Orts-ID (`stableTilt`), nie zufällig.
- Poststempel in `red`, Ring 2 pt, 76 pt, −12° gedreht, „PRAHA“ + Datum. Reine Zierde, `accessibilityHidden`.
- Die Briefmarken-Metapher bleibt auf Erinnerungen und Erststart beschränkt. Reise, Karte und Detail folgen der Referenz ohne Zähnung.
""", f'''
{cell("Marke · Aussicht", f'<div class="al-stamp" style="width:150px;transform:rotate(-2deg)"><div class="mat" style="background:var(--mat-butter)">{photo("letna","","height:120px")}</div></div>')}
{cell("Marke · Sehenswert", f'<div class="al-stamp" style="width:150px;transform:rotate(2.5deg)"><div class="mat" style="background:var(--mat-sky)">{photo("oldtown","","height:120px")}</div></div>')}
{cell("Poststempel", '<svg width="84" height="84" viewBox="0 0 84 84" style="transform:rotate(-12deg);color:var(--red)"><circle cx="42" cy="42" r="40" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="42" cy="42" r="34" fill="none" stroke="currentColor" stroke-opacity=".7"/><text x="42" y="38" text-anchor="middle" font-family="ui-monospace,monospace" font-weight="700" font-size="12.5" fill="currentColor" letter-spacing="1.5">PRAHA</text><rect x="21" y="43" width="42" height="1" fill="currentColor"/><text x="42" y="56" text-anchor="middle" font-family="ui-monospace,monospace" font-weight="600" font-size="10.5" fill="currentColor">4.–9.10.</text></svg>')}
''')

# ------------------------------------------------------------------ Aktionen
comp("Button", "Aktionen", 300, """
# Button

Pillenförmiger Knopf in drei Rollen: Primär (Navy-Fläche), Sekundär (helle Pille mit Kontur) und Textaktion.

**SwiftUI:** `StitchButton(primary:)`, `TextActionButton(tint:)` (Stitch.swift) · Status: **Bestand**

## Regeln
- Höhe `size-button` (52), Schrift `label`, Text **geometrisch zentriert**, Icon links mit 8 pt Abstand.
- Primär: `action-fill` + `on-accent`. Pro Ansicht genau eine Primäraktion, z. B. „Los geht’s“, „Übernehmen“ oder „Speichern“.
- Sekundär: `card` + 1 pt `rule` + `ink`. Das gilt für „Einladen“, „PDF hinzufügen“ und „Erneut versuchen“.
- Textaktion: `ink` (z. B. „Alle öffnen“). In Koralle (`red`) nur bei Orts- und Tagesbezug: „Tage planen“, „Route“, „5. Okt“.
- Destruktiv („Ort löschen“, „Beitrag löschen“) als Textaktion in `red` mit Bestätigungsdialog. Keine rote Fläche.
- Gedrückt: Skalierung 0.97 mit `--motion-press`. Bei Reduce Motion entfällt die Skalierung. Deaktiviert: `opacity-disabled`.
- Fokusring: 2 pt `system-blue` mit 3 pt Abstand in `paper`.
- Im Dunkelmodus erhält die Navy-Fläche eine `rule`-Kontur, weil `action-fill` dort kaum vom Grund abweicht.
""", f'''
{cell("Primär", '<button class="al-btn primary" style="width:220px">Los geht’s</button>')}
{cell("Primär · gedrückt", '<button class="al-btn primary is-pressed" style="width:220px">Übernehmen</button>')}
{cell("Primär · deaktiviert", '<button class="al-btn primary is-disabled" style="width:220px">Speichern</button>')}
{cell("Sekundär mit Icon", f'<button class="al-btn small">{icon("people-add")}Einladen</button>')}
{cell("Sekundär · Fokus", f'<button class="al-btn is-focus" style="width:200px">{icon("import")}PDF hinzufügen</button>')}
{cell("Textaktionen", f'<div style="display:flex;gap:18px;align-items:center"><span class="al-textbtn">{icon("calendar")}Alle öffnen</span><span class="al-textbtn coral">Tage planen</span><span class="al-textbtn coral">{icon("walk")}Route</span><span class="al-textbtn coral">{icon("calendar")}5. Okt</span></div>')}
{cell("Destruktiv", f'<span class="al-textbtn coral">{icon("trash")}Ort löschen</span>')}
''')

comp("IconButton", "Aktionen", 150, """
# IconButton

Runder Knopf nur mit Symbol (44 × 44 oder 50 × 50 auf Fotos) für Kopfzeilen, Zurück und Weitere Optionen.

**SwiftUI:** `HeaderIconButton` (Stitch.swift) · Status: **Bestand**

- Kopfzeile „Reise“: Teilnehmende (`people`) und Neue Idee (`plus`), je 44 pt, 12 pt Abstand, `card` + `rule`.
- Auf Fotos (Zurück, „…“): 50 pt, `card`-Fläche mit `elevation-pinned`, ohne Kontur.
- Jedes Symbol braucht ein `accessibilityLabel` („Teilnehmende verwalten“, „Neue Idee“, „Reiseoptionen“).
- Gedrückt: Skalierung 0.94.
""", f'''
{cell("Kopfzeile", f'<div style="display:flex;gap:12px"><span class="al-iconbtn">{icon("people")}</span><span class="al-iconbtn">{icon("plus")}</span></div>')}
{cell("Auf Foto", f'<div style="display:flex;gap:12px;padding:12px;border-radius:16px;background:#7a8aa0"><span class="al-iconbtn lg on-photo">{icon("chev-l")}</span><span class="al-iconbtn lg on-photo">{icon("more")}</span></div>')}
{cell("Gedrückt", f'<span class="al-iconbtn is-pressed">{icon("x")}</span>')}
{cell("Navy (Senden)", f'<span class="al-iconbtn dark">{icon("send")}</span>')}
''')

comp("ActionTile", "Aktionen", 210, """
# ActionTile

Quadratische Aktionskachel mit Symbol über Label, im Ortsdetail in einer Reihe.

**SwiftUI:** Kacheln in `TripMapView` (Ortsdetail: „Route“, „Plan ändern“, „Teilen“, „Website“) · Status: **Vereinheitlichen**

- Höhe ≥ 72, `radius-tile`, `card` + `rule`, Symbol 24 pt in `ink`, Label `body`/15 pt.
- Die kontextuelle Hauptaktion („Plan ändern“ bzw. „Zum Plan“) liegt auf `selection` (Hellblau), genau wie „Add to plan“ in der Referenz.
- 2 bis 4 Kacheln, gleich breit, 12 pt Abstand. Bei großer Dynamic Type umbrechen sie in zwei Zeilen und schneiden nichts ab.
- „Website“ erscheint nur, wenn eine Quelle existiert. Fehlt sie, rücken die übrigen Kacheln zusammen.
""", f'''
{cell("Ortsdetail · 2 Kacheln (Referenz)", f'<div class="al-tiles" style="--n:2;width:362px"><div class="al-tile">{icon("nav")}Route</div><div class="al-tile primary">{icon("plus")}Plan ändern</div></div>')}
{cell("4 Kacheln (Quelle vorhanden)", f'<div class="al-tiles" style="--n:4;width:362px"><div class="al-tile">{icon("nav")}Route</div><div class="al-tile primary">{icon("plus")}Zum Plan</div><div class="al-tile">{icon("share")}Teilen</div><div class="al-tile">{icon("compass")}Website</div></div>')}
''')

comp("VisitSlider", "Aktionen", 220, """
# VisitSlider

Schieber „Als besucht markieren“. Erst eine bewusste Wischbewegung markiert einen Ort als besucht.

**SwiftUI:** `VisitedTrack` (Album/Stitch/VisitedTrack.swift) · Status: **Bestand**

- Pille `size-button`, `card` + `rule`, Label in `red`. Der Griff ist ein 44-pt-Kreis mit `forward`-Symbol und `elevation-pinned`.
- Beim Ziehen füllt sich die Spur mit 12 % `red`. Ab 85 % rastet der Griff mit Haptik (`.impact`) ein, und die Pille wechselt auf `teal` („Besucht“).
- Gleichwertige Alternative: Tippen öffnet einen Bestätigungsdialog. VoiceOver bietet die Aktion „Als besucht markieren“ direkt an.
- Reduce Motion: Der Griff springt ohne Federung, der Zustand blendet über.
""", f'''
{cell("Ruhe", f'<div class="al-visit" style="width:362px"><span class="knob">{icon("forward")}</span>Als besucht markieren</div>')}
{cell("Ziehen", f'<div class="al-visit mid" style="width:362px"><i class="fill"></i><span class="knob">{icon("forward")}</span>Als besucht markieren</div>')}
{cell("Besucht", f'<div class="al-visit done" style="width:362px"><span class="knob">{icon("check")}</span>Besucht · Mo, 5. Oktober</div>')}
''', "flex-direction:column")

# ------------------------------------------------------------------ Eingaben
comp("TextField", "Eingaben", 400, """
# TextField

Ein- und mehrzeilige Eingabe auf `card` mit Schreibmaschinen-Schiene. Ein kleiner Korallen-Schlitten folgt dem Text.

**SwiftUI:** `StitchTextField` (AlbumRoot.swift), Felder im `PlaceEditor` · Status: **Bestand; Editorfelder angleichen**

- Fläche `card`, `radius-card`, 1 pt `rule`, Text `body`, Platzhalter `ink-soft`, Label darüber in `footnote`/semibold `ink-soft`.
- Fokus: Die Schiene färbt sich in `ink` 35 %, der Schlitten (14 × 5, `red`) folgt mit 40–90 ms Verzögerung. Reduce Motion: kein Schlitten.
- Fehler: 1.5 pt `red`-Kontur und eine Zeile mit `warn`-Symbol, z. B. „Der Link muss mit https:// beginnen.“
- Felder im Editor: „Name der Idee“, „Link von TikTok oder Instagram“, „Warum möchtet ihr dorthin?“, „Ort oder Adresse in Prag“.
""", f'''
<div class="al-cell" style="width:340px;gap:16px">
<div class="al-field"><span class="lbl">Dein Name</span><div class="al-input rail is-focus">Luke<i class="carriage" style="left:58px"></i></div></div>
<div class="al-field"><span class="lbl">Link</span><div class="al-input">{icon("link")}<span class="ph">Link von TikTok oder Instagram</span></div></div>
<div class="al-field"><span class="lbl">Link</span><div class="al-input is-error">http://prague.eu/…</div><span class="err">{icon("warn")}Der Link muss mit https:// beginnen.</span></div>
</div>
<div class="al-cell" style="width:300px;gap:16px">
<div class="al-field"><span class="lbl">Beschreibung</span><div class="al-input area"><span class="ph">Warum möchtet ihr dorthin?</span></div></div>
<div class="al-field"><span class="lbl">Ort</span><div class="al-input">{icon("pin")}Haštalská 795/1, 110 00 Praha 1</div><span class="hint">Koordinaten aus Apple Karten übernommen</span></div>
</div>''')

comp("SearchField", "Eingaben", 170, """
# SearchField

Schwebende Suchpille über der Karte mit Filterknopf. Darunter: die Ortssuche im Editor.

**SwiftUI:** Suchfeld in `TripMapView` („Prag durchsuchen“), Ortssuche in `PlaceEditor` · Status: **Bestand (Referenz)**

- Karte: 52 pt hoch, volle Breite minus `page`, `radius-pill`, `card` + `elevation-floating`. Lupe links in `ink`, Filter (`sliders`) rechts mit eigenem Label „Karte filtern“.
- In Sheets flach mit `rule`-Kontur statt Schatten.
- Platzhalter immer konkret: „Prag durchsuchen“, „Ort suchen“, „In der Sammlung suchen“.
""", f'''
{cell("Karte (schwebend)", f'<div class="al-search" style="width:362px">{icon("search")}<span class="grow">Prag durchsuchen</span>{icon("sliders")}</div>')}
{cell("Im Sheet (flach)", f'<div class="al-search flat" style="width:330px">{icon("search")}<span class="grow" style="color:var(--ink)">Café Sav</span>{icon("x")}</div>')}
''')

comp("SegmentedControl", "Eingaben", 160, """
# SegmentedControl

Nativer segmentierter Picker und Schalter für zwei bis drei gleichrangige Ansichten.

**SwiftUI:** `Picker("Ideenbereich")` in `InboxView` („Entdecken“ · „Sammlung“), Toggle „Web-Recherche“ im Assistenten · Status: **Bestand**

- Grund `paper-deep`, aktives Segment `card` mit leichtem Schatten, Text `label`/14 pt in `ink`.
- Er ersetzt keine Tabs. Er schaltet nur innerhalb von „Ideen“ zwischen Entdecken und Sammlung.
- Schalter „an“ in `teal`, immer mit sichtbarem Label daneben.
""", f'''
{cell("Ideen", '<div class="al-seg" style="width:300px"><span class="on">Entdecken</span><span>Sammlung</span></div>')}
{cell("Schalter", f'<div style="display:flex;align-items:center;gap:12px;width:280px" class="t-body"><span style="flex:1">{icon("globe")} Web-Recherche</span><i class="al-toggle on"></i></div>')}
''')

# ------------------------------------------------------------------ Navigation
comp("TabBar", "Navigation", 190, """
# TabBar

Schwebende Tab-Leiste mit genau drei Tabs: Reise, Ideen und Karte. Weitere Haupt-Tabs gibt es nicht.

**SwiftUI:** `TabView` in `AlbumRoot` (Symbole `suitcase`, `tray`, `map`) · Status: **Vereinheitlichen auf Referenz**

- 274 × `size-tabbar` (62), `radius-pill`, `card` + `elevation-floating`, 26 pt über dem unteren Rand und horizontal zentriert.
- Aktiver Tab: Pille `tab-selected` hinter Symbol und Label. Alle Symbole gefüllt, 26 pt, in `ink`. Label im Stil `tab`.
- Badge am Ideen-Tab: Anzahl offener Ideen (`store.inbox.count`) in `badge`, z. B. 81.
- Beim Scrollen wird die Leiste kompakter (48 pt, nur Symbole). Reduce Motion: kein Größenwechsel.
- „Idee einwerfen“ ist keine Tab-Position, sondern das „+“ in der Kopfzeile bzw. Toolbar.
""", f'''
{cell("Reise aktiv", tabbar("reise", static=True))}
{cell("Karte aktiv", tabbar("karte", badge="", static=True))}
{cell("Kompakt beim Scrollen", tabbar("ideen", static=True, compact=True))}
''')

comp("AssistantButton", "Navigation", 170, """
# AssistantButton

Der kleine schwebende KI-Kreis unten rechts. Er ist das einzige ausdrücklich freigegebene Element des bisherigen Zwischenstands und wird **unverändert** übernommen.

**SwiftUI:** Overlay in `AlbumRoot` (48 × 48, `Stitch.ink`, `sparkles` 20 pt medium, `elevation-floating`) · Status: **Freigegeben, nicht verändern**

- Position: `page` (20) vom rechten Rand, 76 pt über dem unteren Safe-Area-Rand, also über der Tab-Leiste.
- Auf der Karte sitzt er an der Oberkante des Ortsblatts (half/collapsed) und verdeckt keine Kartenaktion.
- Ausgeblendet, solange ein Editor, die Unterlagen, Teilen, der Erststart oder das Assistent-Sheet offen sind.
- VoiceOver: „Reise-Assistent“. Kontextuelle Einstiege bei Ort und Tagesplan öffnen denselben Chat mit Vorbelegung.
""", f'''
{cell("Ruhe", fab(static=True))}
{cell("Über der Tab-Leiste", f'<div style="position:relative;width:360px;height:120px;border-radius:22px;background:var(--paper-deep)">{tabbar("reise", static=False).replace("bottom: 26px","")}{fab("bottom:78px;right:16px")}</div>')}
''')

comp("Sheet", "Navigation", 520, """
# Sheet

Blätter und das verschiebbare Ortsblatt. Ein Blatt hat oben `radius-floating`, einen Greifer und einen ruhigen Kopf.

**SwiftUI:** `PlacesDrawer` (Zustände hidden · collapsed · half · full), System-Sheets in `AlbumRoot` · Status: **Bestand; Kopf vereinheitlichen**

## Ortsblatt (Karte)
- **hidden:** nur die Karte, unten eine kleine Pille „Liste“ zum Wiederöffnen.
- **collapsed:** Greifer, Titel in `sheet-title` („2 Orte“), Untertitel `meta` („Heute 1 Ort“).
- **half:** zusätzlich Filterchips und die ersten Zeilen (Referenz).
- **full:** volle Liste, Kopf bleibt stehen. Im Querformat links als schwebendes Panel (360 pt).
- Greifer 40 × 5 in `ink-soft` 45 %. Federung `--motion-panel`, bei Reduce Motion Überblendung.
- Kopfaktionen rechts: „Tage planen“ (Koralle), „Ordnen“, Schließen (`x`).

## Modale Blätter
Navigationsleiste mit „Abbrechen“ links, Titel mittig (17 pt semibold) und der Primäraktion rechts („Speichern“, „Übernehmen“, „Fertig“). Wichtige Bestätigungen erscheinen zusätzlich als Primärpille am Ende des Inhalts.
""", f'''
{cell("collapsed", f'<div style="position:relative;width:250px;height:190px;border-radius:20px;overflow:hidden">{mapbg()}<div class="al-sheet" style="height:92px"><i class="grab"></i><div class="in" style="padding-top:10px"><div class="t-section">2 Orte</div><div class="t-meta" style="font-size:13px">Heute 1 Ort</div></div></div></div>')}
{cell("half", f'<div style="position:relative;width:250px;height:190px;border-radius:20px;overflow:hidden">{mapbg()}<div class="al-sheet" style="height:135px"><i class="grab"></i><div class="in" style="padding:10px 14px 0"><div class="t-section">2 Orte</div><div class="al-chips" style="margin-top:8px"><span class="al-chip sm on">Alle</span><span class="al-chip sm">{icon("fork")}Essen</span><span class="al-chip sm">{icon("columns")}Sehenswert</span></div></div></div></div>')}
{cell("full", f'<div style="position:relative;width:250px;height:190px;border-radius:20px;overflow:hidden">{mapbg()}<div class="al-sheet" style="height:178px"><i class="grab"></i><div class="in" style="padding:10px 14px 0;display:flex;flex-direction:column;gap:6px"><div class="t-section">2 Orte</div><div class="al-skel" style="height:28px"></div><div class="al-skel" style="height:28px"></div><div class="al-skel" style="height:28px"></div></div></div></div>')}
{cell("hidden", f'<div style="position:relative;width:250px;height:190px;border-radius:20px;overflow:hidden">{mapbg()}<span class="al-btn small" style="position:absolute;left:50%;bottom:12px;transform:translateX(-50%);box-shadow:var(--elevation-floating)">{icon("list")}Liste</span></div>')}
{cell("Modales Blatt · Kopf", f'<div class="al-card" style="width:380px;padding:0;background:var(--paper)"><i class="grab" style="display:block;width:40px;height:5px;border-radius:3px;background:color-mix(in srgb,var(--ink-soft) 45%,transparent);margin:8px auto 0"></i><div class="al-navbar"><span class="al-textbtn">Abbrechen</span><span class="ttl">Idee einwerfen</span><span class="al-textbtn" style="color:var(--ink)">Speichern</span></div></div>')}
''')

# ------------------------------------------------------------------ Inhalte
comp("SectionTitle", "Inhalte", 150, """
# SectionTitle

Abschnittsüberschrift in Fraunces links, optional eine Aktion oder Zahl rechts.

**SwiftUI:** `SectionTitle` (Stitch.swift) · Status: **Bestand**

- Titel im Stil `section` (20/26) in `ink` mit `isHeader`-Trait. Rechts eine `TextActionButton` mit Symbol, an der Grundlinie ausgerichtet.
- Beispiele: „Reiseplan“ + „Alle öffnen“, „Heute“ + Wochentag darunter in `meta`, „Fotos“ + „Alle“, „Unterlagen“ + Pfeil.
- Maximal ein Abschnittstitel pro Karte. Der Abstand zum Inhalt beträgt `space-m`.
""", f'''
{cell("Mit Aktion", f'<div class="al-section" style="width:330px"><h3>Reiseplan</h3><span class="al-textbtn">{icon("calendar")}Alle öffnen</span></div>')}
{cell("Mit Untertitel", '<div style="width:300px"><div class="al-section"><h3>Heute</h3></div><div class="t-meta">Sonntag, 4. Oktober</div></div>')}
{cell("Mit Zahl", '<div class="al-section" style="width:300px"><h3>Fotos</h3><span class="t-meta">3</span></div>')}
''')

comp("ParticipantRow", "Inhalte", 210, """
# ParticipantRow

Teilnehmerzeile unter dem Titelfoto: Initialen-Avatare links, „Einladen“ rechts.

**SwiftUI:** Zeile in `ReiseView` (`Label("Einladen")`, Teilnehmende verwalten) · Status: **Bestand (Referenz)**

- Avatare 38 pt, Initialen (`LU`) in 14 pt bold, Grund `selection`, zweite Person `mat-butter`, 3 pt `paper`-Ring, −8 pt Überlappung.
- **Keine Profilfotos.** Die Referenz zeigt Porträts, die App kennt aber nur Namen. Initialen sind korrekt.
- Offene Einladung: gestrichelter Kreis „?“. Sobald die zweite Person beigetreten ist, verschwindet der Knopf „Einladen“ und weicht dem Sync-Status.
- Zwei Teilnehmende sind das Maximum. Die Partnerschaft ist sichtbar, aber nie das Hauptmotiv.
""", f'''
{cell("Allein · Referenz", f'<div class="al-people" style="width:362px"><div class="al-avatars"><span class="al-avatar">LU</span></div><span class="al-btn small">{icon("people-add")}Einladen</span></div>')}
{cell("Einladung offen", f'<div class="al-people" style="width:362px"><div class="al-avatars"><span class="al-avatar">LU</span><span class="al-avatar pending">?</span></div><span class="t-foot soft">Einladung gesendet</span></div>')}
{cell("Zu zweit · abgeglichen", f'<div class="al-people" style="width:362px"><div class="al-avatars"><span class="al-avatar">LU</span><span class="al-avatar b">MI</span></div><span class="al-badge ok">{icon("check")}Abgeglichen</span></div>')}
''')

comp("DayTile", "Inhalte", 230, """
# DayTile

Tageskachel im Reiseplan mit Datum (Versalien), Bildfläche und Titel. Sechs Kacheln, horizontal scrollend.

**SwiftUI:** `itineraryDay(_:)` in `ReiseView` · Status: **Bestand; Maße an Referenz**

- 104 × ~170 pt, `radius-tile`, `card` + `rule`, Innenabstand 8. Datum `eyebrow` („4. OKT“), Bild 92 pt hoch mit `radius-thumb`.
- Ohne Plan: `paper-deep` mit Kalendersymbol, Titel „Noch offen“. Mit Plan: Foto des ersten Orts, Titel = Ortsname oder Zusammenfassung.
- Heute: Rand 2 pt `selection`, Fläche zu 45 % `selection`, Datum in `ink`.
- Daten nur aus dem Repo: 4.–9. Oktober 2026 (So bis Fr), „Tag 1 von 6“.
""", f'''
<div class="al-days">
<div class="al-day today"><span class="d">4. OKT</span><span class="ph">{icon("calendar")}</span><span class="n">Noch offen</span></div>
<div class="al-day"><span class="d">5. OKT</span><span class="ph"><img src="{IMG["oldtown"]}" alt=""></span><span class="n">Altstädter Ring</span></div>
<div class="al-day"><span class="d">6. OKT</span><span class="ph"><img src="{IMG["letna"]}" alt=""></span><span class="n">Letná Park</span></div>
<div class="al-day"><span class="d">7. OKT</span><span class="ph">{icon("calendar")}</span><span class="n">Noch offen</span></div>
</div>''')

comp("PlaceRow", "Inhalte", 470, """
# PlaceRow

Ortszeile im Kartenblatt und in Listen: Thumbnail, Ortsname in Instrument Serif und Metadaten.

**SwiftUI:** Zeilen in `PlacesDrawer` · Status: **Bestand (Referenz)**

- Thumbnail `size-row-thumb` (64) mit `radius-thumb`, Abstand 14. Name `place-m` in `ink`, Meta `meta`: „Kategorie · Tageszeit“ oder „Noch ohne Tag“.
- Ausgewählt (Pin ↔ Liste synchron): ganze Zeile auf `selection`, `radius-card`, darunter die Schnellaktionen „Route“ und „5. Okt“ in `red`.
- Besucht: Name in `ink-soft`, Häkchen-Badge in `teal`. Kein Durchstreichen.
- Im Tagesplan: Nummer (26-pt-Kreis, `action-fill`) statt Thumbnail-Badge, erledigt in `teal`.
- **Keine Sterne oder Bewertungen.** Die Referenz zeigt „4.8 (12K)“, Album hat diese Daten nicht.
""", f'''
<div class="al-cell" style="width:380px;gap:4px">
<div class="al-rowwrap sel"><div class="al-row">{photo("oldtown")}<div class="tx"><span class="t-place-m">Altstädter Ring</span><span class="t-meta">Sehenswert · vormittags</span></div><span class="chev">{icon("chev-r")}</span></div><div class="acts" style="padding-left:90px"><span class="al-textbtn coral">{icon("walk")}Route</span><span class="al-textbtn coral">{icon("calendar")}5. Okt</span></div></div>
<div class="al-row">{photo("letna")}<div class="tx"><span class="t-place-m">Letná Park</span><span class="t-meta">Aussicht · Noch ohne Tag</span></div><span class="chev">{icon("chev-r")}</span></div>
<div class="al-row visited">{photo("cafe")}<div class="tx"><span class="t-place-m">Café Savoy</span><span class="t-meta"><span class="al-badge ok" style="height:20px">{icon("check")}Besucht</span> · Essen &amp; Trinken</span></div><span class="chev">{icon("chev-r")}</span></div>
<div class="al-row"><span class="al-num">2</span><div class="tx"><span class="t-place-m">Speculum Alchemiae</span><span class="t-meta">Sehenswert · Haštalská 795/1</span></div><span class="chev">{icon("chev-r")}</span></div>
</div>''')

comp("Chip", "Inhalte", 150, """
# Chip

Filter- und Kategoriechips als Pillen, horizontal scrollend.

**SwiftUI:** Filterchips in `PlacesDrawer` / `TripMapView` („Alle“, „Essen“, „Sehenswert“, „Aussicht“) · Status: **Bestand (Referenz)**

- Höhe `size-touch` (44), `radius-pill`, `card` + `rule`, Label 16 pt semibold, Symbol links.
- Gewählt: `action-fill` + `on-accent`, ohne Kontur. Es ist immer genau ein Filter aktiv; „Alle“ ist Standard.
- Kleine Chips (32 pt) für Vorschläge im Assistenten und für Ortsverknüpfungen in der Sammlung.
- Der letzte Chip darf angeschnitten sein, um Scrollbarkeit zu zeigen (Referenz). Es gibt keinen Pfeil.
""", f'''
<div class="al-chips" style="width:560px"><span class="al-chip on">Alle</span><span class="al-chip">{icon("fork")}Essen</span><span class="al-chip">{icon("columns")}Sehenswert</span><span class="al-chip">{icon("binoculars")}Aussicht</span></div>
{cell("Vorschläge (klein)", '<div class="al-suggest"><span class="al-chip sm">Was passt jetzt?</span><span class="al-chip sm">Plan für morgen</span><span class="al-chip sm">Wann ist Check-in?</span></div>')}
''', "flex-direction:column")

comp("Badge", "Inhalte", 170, """
# Badge

Kleine Kapseln für Kategorie, Quelle, Zustand und Zahlen.

**SwiftUI:** verstreut (Kategorie-Label, „Besucht“, Sync, Inbox-Badge) · Status: **Neu als einheitlicher Baustein**

- 24 pt hoch, `radius-pill`, Schrift `caption`. Kategorie auf `mat-*`, Text immer `ink`.
- Quelle: `card` + `rule` mit Plattformname („TikTok“, „Instagram“, „prague.eu“). Plattformlogos werden nicht nachgezeichnet.
- Zustände: `ok` (teal, „Besucht“, „Abgeglichen“), `warn` (red, „Nicht abgeglichen“, „Ortszuordnung prüfen“), neutral (`paper-deep`, „Noch offen“).
- Jeder Zustand trägt Wort **und** Symbol. Farbe allein reicht nie.
- Zählbadge (`badge`, weiß) nur am Ideen-Tab.
""", f'''
{cell("Kategorien", ''.join(f'<span class="al-badge {CAT[c][1]}" style="margin-right:6px">{icon(CAT[c][0])}{CAT[c][2]}</span>' for c in ["Essen & Trinken","Sehenswert","Aussicht","Unterkunft","Shopping"]))}
{cell("Quelle", f'<span class="al-badge line" style="margin-right:6px">{icon("link")}TikTok</span><span class="al-badge line" style="margin-right:6px">{icon("link")}Instagram</span><span class="al-badge line">{icon("globe")}prague.eu</span>')}
{cell("Zustand", f'<span class="al-badge ok" style="margin-right:6px">{icon("check")}Besucht</span><span class="al-badge warn" style="margin-right:6px">{icon("warn")}Ortszuordnung prüfen</span><span class="al-badge" style="margin-right:6px">{icon("clock")}Noch offen</span><span class="al-badge sel">{icon("sync")}Ausstehend</span>')}
{cell("Zahl", '<span style="position:relative;display:inline-block;width:40px;height:30px"><i class="al-count" style="left:0;top:0">81</i></span>')}
''')

comp("IdeaCard", "Inhalte", 640, """
# IdeaCard

Ideenkarte im Entdecken-Stapel: großes Foto, Ortsname, Quelle, Kategorie und Beschreibung.

**SwiftUI:** Karte in `InboxView` · Status: **Vereinheitlichen auf Referenzsprache**

- Volle Breite minus `page`, `radius-card`, `card` + `elevation-floating`. Foto 300 pt hoch, darunter 16/18 pt Innenabstand.
- Zeile 1: Quelle als Badge (`line`) und Kategorie (`mat-*`). Zeile 2: Name `place-l`. Zeile 3: Beschreibung `body`, höchstens 3 Zeilen, dann „Mehr anzeigen“.
- Autor der Idee als kleine Zeile in `meta` („Von LU eingeworfen“). Die Partnerschaft bleibt Beiwerk.
- Gesten: rechts = **Ja**, links = **Nein**, oben = **Offen** (nur für diesen Durchgang, ohne Stimme). Beim Ziehen erscheint der Stempel „Ja“ (`teal`), „Nein“ (`red`) oder „Offen“ (`ink`).
- Rücklauf ohne Entscheidung mit `--motion-return`. Reduce Motion: Karte blendet aus statt zu fliegen.
- Dahinter liegen zwei Karten als Stapelkanten (versetzt um 10/20 pt), sonst nichts.
""", f'''
{cell("Ruhe", f'<div class="al-stack" style="width:362px"><div class="behind b2"></div><div class="behind"></div><article class="al-idea">{photo("oldtown")}<div class="body"><div class="src"><span class="al-badge line">{icon("globe")}prague.eu</span><span class="al-badge sky">{icon("columns")}Sehenswert</span></div><div class="t-place-l">Speculum Alchemiae</div><div class="t-body">Alchemie-Museum in der Prager Altstadt.</div><div class="t-meta" style="font-size:13px">Haštalská 795/1 · Von LU eingeworfen</div></div></article></div>')}
{cell("Nach rechts gezogen · Ja", f'<article class="al-idea" style="width:300px;transform:rotate(4deg) translateX(14px)"><span class="stampw yes">Ja</span>{photo("letna","","height:220px")}<div class="body"><div class="src"><span class="al-badge butter">{icon("binoculars")}Aussicht</span></div><div class="t-place-l">Letná Park</div><div class="t-body">Park mit Blick über die Moldau.</div></div></article>')}
''')

comp("DecisionBar", "Inhalte", 260, """
# DecisionBar

Drei gleichwertige Entscheidungsknöpfe unter der Ideenkarte und das jederzeit erreichbare Rückgängig.

**SwiftUI:** Buttons in `InboxView` („Nein“, „Offen“, „Ja“, `Label("Rückgängig")`) · Status: **Vereinheitlichen**

- Drei Kacheln gleicher Breite, `radius-tile`, 64 pt hoch: Nein (Symbol `x` in `red`), Offen (`chev-d`/Pfeil nach oben), Ja (`action-fill`, Häkchen).
- Jede Wischgeste hat ihren Knopf. VoiceOver-Aktionen „Ja“, „Nein“, „Offen“ liegen zusätzlich auf der Karte.
- Während des Ziehens wächst die passende Kachel (1.04), die anderen treten auf 50 % zurück.
- Nach jeder Entscheidung erscheint der Undo-Toast (siehe Toast). „Rückgängig“ bleibt bis zur nächsten Entscheidung erreichbar.
- Weggewischte Ideen gehen nicht verloren: „Nein“ und „Offen“ stehen gefiltert in der Sammlung bzw. in der Liste „Entschieden“.
""", f'''
{cell("Ruhe", f'<div class="al-decide" style="width:362px"><button class="al-btn no">{icon("x")}Nein</button><button class="al-btn">{icon("send")}Offen</button><button class="al-btn yes">{icon("check")}Ja</button></div>')}
{cell("Ziehen nach rechts", f'<div class="al-decide" style="width:362px"><button class="al-btn no recede">{icon("x")}Nein</button><button class="al-btn recede">{icon("send")}Offen</button><button class="al-btn yes grown">{icon("check")}Ja</button></div>')}
''', "flex-direction:column")

comp("CollectionPost", "Inhalte", 520, """
# CollectionPost

Beitrag in der geteilten Sammlung: Link oder Text, Linkvorschau, verknüpfte Orte, Herzen, Kommentare und Sync-Zustand.

**SwiftUI:** `CollectionViews.swift`, Daten `CollectionEntry` · Status: **Bestand; auf Kartensprache bringen**

- Kopf: Avatar (28 pt Initialen), Name, relative Zeit und Sync-Badge, falls nicht abgeglichen.
- Linkvorschau auf `paper` mit `rule`: Thumbnail 72 pt, Titel (z. B. „TikTok · @creator“), Caption in `meta`, höchstens 2 Zeilen. Solange `metadataState` = `pending`, erscheinen Skeleton und „Vorschau wird geladen …“.
- Instagram wird nie ausgelesen: Es erscheint nur „Instagram-Link“ mit Host und dem Hinweis „Vorschau nicht verfügbar“. TikTok nur über oEmbed.
- Orte: kleine Chips mit Pin. „Ort hinzufügen“ öffnet die Vorschläge („Orte aus dem Beitrag“); der Nutzer bestätigt, nichts geschieht automatisch.
- Fuß: Herz (gefüllt in `red`, wenn eigenes), Kommentaranzahl, „Quelle öffnen“.
""", f'''
<article class="al-post" style="width:362px"><div class="head"><span class="al-avatar sm">LU</span><div style="flex:1"><div class="t-label">Luke</div><div class="t-foot soft">vor 2 Std.</div></div><span class="al-badge ok">{icon("check")}Abgeglichen</span></div>
<div class="prev">{photo("bridge")}<div style="min-width:0"><div class="t-label">TikTok · @creator</div><div class="t-foot soft">Beschreibung aus oEmbed, auf zwei Zeilen gekürzt …</div><span class="al-badge line" style="margin-top:6px">{icon("link")}tiktok.com</span></div></div>
<div class="places"><span class="al-chip sm">{icon("pin")}Karlsbrücke</span><span class="al-chip sm">{icon("plus")}Ort hinzufügen</span></div>
<div class="foot"><span class="liked">{icon("heart-fill")} 2</span><span>{icon("bubble")} 1</span><span style="margin-left:auto">{icon("ext")} Quelle öffnen</span></div></article>
<article class="al-post" style="width:330px"><div class="head"><span class="al-avatar sm b">MI</span><div style="flex:1"><div class="t-label">Mia</div><div class="t-foot soft">gerade eben</div></div><span class="al-badge sel">{icon("sync")}Ausstehend</span></div>
<div class="prev"><div class="al-photo" style="width:72px;height:72px;border-radius:10px"><div class="empty">{icon("link")}</div></div><div style="min-width:0;flex:1"><div class="t-label">Instagram-Link</div><div class="t-foot soft">Vorschau nicht verfügbar · instagram.com</div></div></div>
<div class="txt t-body">Das sieht so schön aus, lass uns da abends hin!</div>
<div class="foot"><span>{icon("heart")} 0</span><span>{icon("bubble")} 0</span><span style="margin-left:auto">{icon("pin")} Kein Ort erkannt</span></div></article>
''')

comp("ListRow", "Inhalte", 300, """
# ListRow

Gruppierte Listenzeile für Einstellungen, Reisedaten und Unterlagen.

**SwiftUI:** Formularzeilen in `AlbumSettings`, `TripDocumentsView` · Status: **Vereinheitlichen**

- Gruppe auf `card`, `radius-card`, 1 pt `rule`. Zeilen ≥ 52 pt, getrennt durch eine `rule`-Linie.
- Symbol links in `ink` (19 pt), Titel `body`/16, Wert rechts in `ink-soft`, Chevron bei Navigation.
- Keine Systemgrau-Formulare: Albums Flächen ersetzen den `insetGrouped`-Look.
""", f'''
<div class="al-list" style="width:362px">
<div class="al-li">{icon("person")}<span class="grow">Dein Name</span><span class="val">Luke</span>{icon("chev-r")}</div>
<div class="al-li">{icon("people-add")}<span class="grow">Einladung senden</span>{icon("chev-r")}</div>
<div class="al-li">{icon("sync")}<span class="grow">Jetzt abgleichen</span><span class="val">vor 3 Min.</span></div>
<div class="al-li">{icon("import")}<span class="grow">Album-Backup exportieren</span>{icon("chev-r")}</div>
</div>''')

# ------------------------------------------------------------------ Karte
comp("MapPin", "Karte", 330, """
# MapPin

Fotopins, Cluster, Kategorie-Fallback, Standortpunkt und Route auf der MapKit-Karte.

**SwiftUI:** Annotationen in `TripMapView`, `MapPinClustering.swift` · Status: **Bestand (Referenz)**

- Fotopin `size-pin` (56): Foto mit 3 pt `card`-Rahmen, `radius-thumb`, `elevation-pinned`, darunter ein 7-pt-Punkt als Fuß.
- Ausgewählt: 64 pt, Rahmen 3 pt `system-blue`, Fuß in `system-blue`. Die zugehörige Listenzeile wird gleichzeitig `selection`.
- Ohne Foto: Fläche in `mat-*` der Kategorie mit Symbol. Besucht: kleines `teal`-Häkchen oben rechts.
- Cluster: zwei versetzte Fotos plus Zahl in `action-fill`. Tippen zoomt hinein, die Liste filtert auf diese Orte („3 Orte“).
- Bei aktivem Filter treten nicht passende Pins auf 45 % zurück.
- Pins landen beim Erscheinen mit einem leichten Federn (nicht bei Reduce Motion). Routen zeichnen sich als gepunktete Linie in `red`.
""", f'''
<div style="position:relative;width:620px;height:280px;border-radius:22px;overflow:hidden">{mapbg()}
{pin(80,140,"letna")}{pin(200,150,"oldtown",sel=True)}{pin(320,140,cat="Essen & Trinken")}{pin(430,140,"cafe",visited=True)}{cluster(540,140,"bridge","oldtown",3)}{pin(260,250,"bridge",dim=True)}
<i class="al-me" style="left:120px;top:220px"></i>
<svg style="position:absolute;inset:0" width="620" height="280"><path class="m-route" d="M120 220 C 150 200, 170 180, 200 160"/></svg>
</div>''')

# ------------------------------------------------------------------ Assistent
comp("AssistantMessage", "Assistent", 470, """
# AssistantMessage

Chatnachrichten des Reise-Assistenten mit Quellenzitaten.

**SwiftUI:** `AssistantView.swift`, `AssistantModels.swift` · Status: **Bestand; Stil angleichen**

- Eigene Nachricht: rechts, `action-fill` + `on-accent`, untere rechte Ecke 6 pt. Im Dunkelmodus auf `selection` mit `ink`.
- Antwort: links, `card` + `rule`, untere linke Ecke 6 pt, Text `body`/16.
- Zitate inline als `al-cite`-Kapsel mit Nummer. Darunter folgt der Block „Quellen“ mit Dokumentname bzw. Domain und dem **wörtlichen** Zitat in `ink-soft` kursiv.
- Fehlt eine Information, sagt die Antwort das ausdrücklich. Check-in-Zeiten oder Flugdaten werden nie erfunden.
- Laden: „Ich sehe kurz nach …“ in `ink-soft` kursiv, Abbrechen möglich. Fehler: Banner mit „Erneut versuchen“.
- Verlauf und Vorlieben sind privat und lokal („Verlauf bleibt offline verfügbar.“).
""", f'''
<div class="al-chat" style="width:380px">
<div class="al-msg me">Was passt heute Abend in der Altstadt?</div>
<div class="al-msg bot">Aus euren Ideen passt die Geister- und Legenden-Tour gut. Treffpunkt ist Kožná 500/6 <span class="al-cite">1</span>. Für danach habe ich Café Savoy recherchiert <span class="al-cite">2</span>.
<div class="al-sources"><div class="t-eyebrow" style="font-size:11px">Quellen</div>
<div class="al-source"><span class="n">1</span><span>Gespeicherte Idee · spectrumtours.cz <span class="q">„Treffpunkt Kožná 500/6“</span></span></div>
<div class="al-source"><span class="n">2</span><span>Web · prague.eu</span></div></div></div>
<div class="al-msg bot typing">Ich sehe kurz nach …</div>
</div>
<div class="al-chat" style="width:320px">
<div class="al-msg me">Wann können wir im Hotel einchecken?</div>
<div class="al-msg bot">In euren Unterlagen finde ich keine Check-in-Zeit für Hotel Urban Crème. Füg die Buchungsbestätigung als PDF hinzu, dann sehe ich dort nach.</div>
<div class="al-banner err">{icon("wifi-off")}<span class="grow">Keine Verbindung. Deine Frage bleibt hier.</span><span class="al-textbtn" style="min-height:auto">Erneut versuchen</span></div>
</div>''')

comp("AssistantAction", "Assistent", 520, """
# AssistantAction

Bedienbare Antwortkarten: Ortsvorschlag, Planvorschlag und Bestätigung. Chattext allein verändert nie etwas.

**SwiftUI:** `AssistantActions.swift`, `DayPlanPreview` · Status: **Bestand; Karten angleichen**

- Ortskarte: Thumbnail `size-thumb`, Name `place-s`, Adresse in `meta`, Quelle als Badge. Aktionen: „Auf Karte zeigen“ (sekundär) und „Als Idee speichern“ (primär).
- Planvorschlag: Titel „Planvorschlag“ mit Tag, nummerierte Stopps (PlaceRow-Nummern), darunter „Plan prüfen und übernehmen“.
- Jede Änderung braucht zuerst eine Vorschau, dann die Bestätigung („Übernehmen“) und anschließend den Toast mit „Rückgängig“.
- Erledigt: Rahmen 1.5 pt `teal`, Label „Gespeicherte Orte erscheinen im Ideenstapel.“
- Konflikt (Plan zwischenzeitlich geändert): Banner `warn` „Der Plan wurde inzwischen geändert. Bitte erneut prüfen.“
""", f'''
<div class="al-cell" style="width:340px;gap:14px">
<div class="al-action"><div class="hd">{photo("cafe")}<div style="flex:1;min-width:0"><div class="t-place-s">Café Savoy</div><div class="t-meta" style="font-size:13px">Essen &amp; Trinken · Adresse aus Apple Karten</div><span class="al-badge line" style="margin-top:4px">{icon("globe")}prague.eu</span></div></div><div class="ft"><button class="al-btn small">{icon("map")}Auf Karte</button><button class="al-btn small primary">{icon("plus")}Als Idee speichern</button></div></div>
<div class="al-action done"><div class="hd">{photo("oldtown")}<div style="flex:1"><div class="t-place-s">Speculum Alchemiae</div><div class="t-foot teal">{icon("check")} Gespeichert · erscheint im Ideenstapel</div></div></div></div>
</div>
<div class="al-action" style="width:340px;padding:14px"><div class="t-eyebrow">Planvorschlag · Mo, 5. Okt</div>
<div style="display:flex;flex-direction:column;gap:2px;margin:10px 0 12px">
<div class="al-row" style="padding:6px 0"><span class="al-num">1</span><div class="tx"><span class="t-place-s">Altstädter Ring</span><span class="t-meta" style="font-size:13px">vormittags</span></div></div>
<div class="al-row" style="padding:6px 0"><span class="al-num">2</span><div class="tx"><span class="t-place-s">Speculum Alchemiae</span><span class="t-meta" style="font-size:13px">Öffnungszeiten werden geprüft …</span></div></div>
<div class="al-row" style="padding:6px 0"><span class="al-num">3</span><div class="tx"><span class="t-place-s">Old Czech Chimney Cake</span><span class="t-meta" style="font-size:13px">Karlova 145/25</span></div></div>
</div><button class="al-btn primary block">Plan prüfen und übernehmen</button></div>
''')

comp("Composer", "Assistent", 170, """
# Composer

Eingabezeile des Assistenten mit Diktieren über die iOS-Tastatur und einem Navy-Sendeknopf, darüber Vorschlagschips.

**SwiftUI:** Eingabe in `AssistantView` · Status: **Bestand**

- Pille auf `card` + `rule`, Platzhalter „Womit soll ich helfen?“, Sendeknopf 36 pt `action-fill`. Ist das Feld leer, ist der Knopf deaktiviert (`opacity-disabled`).
- Vorschläge als kleine Chips: „Was passt jetzt?“ und weitere aus dem Reisekontext.
- Standort nur auf ausdrücklichen Aufruf, mit iOS-Berechtigung.
""", f'''
<div class="al-cell" style="width:380px;gap:12px"><div class="al-suggest"><span class="al-chip sm">Was passt jetzt?</span><span class="al-chip sm">Regen-Alternative</span><span class="al-chip sm">Frage zu Unterlagen</span></div>
<div class="al-composer"><span class="grow">Womit soll ich helfen?</span>{icon("mic")}<span class="send">{icon("send")}</span></div></div>''')

# ------------------------------------------------------------------ Unterlagen
comp("TicketCard", "Unterlagen", 380, """
# TicketCard

Flug- und Hotelkarte mit Abrisskante, aus dem PDF gelesen.

**SwiftUI:** `TicketShape`, `BoardingPass.swift`, `TicketRow` in `ReiseView` · Status: **Bestand**

- `card`, `radius-thumb`, zwei Kerben (9 pt) an der Abrisskante, gepunktete Trennlinie in `rule`. Rechts der Abschnitt (96 pt) für Buchungscode bzw. Sitz.
- Flughafen-Codes in Fraunces 28, Werte in `ticket` (Mono), Labels in Versalien `ink-soft`.
- **Nur echte Daten.** Bis ein PDF ausgelesen ist, zeigt die Karte Gedankenstriche und „Aus dem PDF lesen“. Der Figma-Entwurf „EW4241 CGN → PRG“ ist nicht bestätigt und erscheint nicht.
- Hotel: Name aus `TripInfo.hotel` („Hotel Urban Crème“), Check-in/-out nur, wenn ausgelesen, sonst „Unterkunft“. Passepartout `mat-lilac`.
- Tippen öffnet die Reiseunterlagen, langes Drücken bietet „Kopieren“ für Buchungsnummern.
""", f'''
<div class="al-cell" style="width:380px;gap:14px">
{cell("Flug · noch nicht ausgelesen", f'<div class="al-ticket empty"><div class="main"><div class="t-eyebrow">Hinflug · So, 4. Okt</div><div class="route"><span class="code">—</span><span class="rt">{icon("plane")}</span><span class="code">PRG</span></div><div class="kv"><div><span>Flug</span><b>—</b></div><div><span>Ab</span><b>—</b></div><div><span>An</span><b>—</b></div></div></div><div class="stub"><span class="t-eyebrow" style="font-size:11px">Buchung</span><span class="al-textbtn" style="min-height:auto;font-size:13px">Aus dem PDF lesen</span></div></div>')}
{cell("Hotel", f'<div class="al-ticket"><div class="main" style="flex-direction:row;align-items:center;gap:12px"><span style="width:44px;height:44px;border-radius:12px;background:var(--mat-lilac);display:grid;place-items:center;font-size:22px">{icon("bed")}</span><div><div class="t-place-s">Hotel Urban Crème</div><div class="t-meta" style="font-size:13px">Unterkunft</div></div></div><div class="stub"><span class="t-eyebrow" style="font-size:11px">Buchung</span><b class="t-mono soft">—</b></div></div>')}
</div>''')

comp("DocumentCard", "Unterlagen", 380, """
# DocumentCard

PDF-Zeile in den Unterlagen mit Upload-Fortschritt, Fehler- und Offline-Zustand.

**SwiftUI:** `TripDocumentsView.swift`, `TripDocumentParser.swift` · Status: **Bestand; Zustände ergänzen**

- `card` + `rule`, `radius-card`. Links das PDF-Symbol (44 × 54, `paper-deep`, Eselsohr), Name `label`, Meta `meta` (Datum, Seitenzahl).
- Hochladen: Fortschrittsbalken 4 pt in `ink` auf `paper-deep` mit Prozent. Offline: „Wird hochgeladen, sobald du online bist“ mit `wifi-off`.
- Fehler: Banner `err` mit „Erneut versuchen“. Das lokale PDF bleibt erhalten.
- Ausgelesen: Badge `ok` „Flüge und Hotel übernommen“. Die Aktion „Auslesen“ steht als Textaktion daneben.
- Privat: Speicherung im privaten Bucket. Hinweis mit `lock` im Leerzustand.
""", f'''
<div class="al-cell" style="width:362px;gap:12px">
<div class="al-doc"><span class="ic">PDF</span><div class="grow"><span class="t-label">Prag Urlaub.pdf</span><span class="al-badge ok">{icon("check")}Flüge und Hotel übernommen</span></div>{icon("chev-r")}</div>
<div class="al-doc"><span class="ic">PDF</span><div class="grow"><span class="t-label">Buchungsbestätigung.pdf</span><div class="al-progress"><i style="width:64%"></i></div><span class="t-foot soft">Wird hochgeladen · 64 %</span></div></div>
<div class="al-doc"><span class="ic">PDF</span><div class="grow"><span class="t-label">Buchungsbestätigung.pdf</span><span class="t-foot soft">{icon("wifi-off")} Wird hochgeladen, sobald du online bist</span></div></div>
<div class="al-banner err">{icon("warn")}<span class="grow">Hochladen fehlgeschlagen. Das PDF bleibt auf diesem iPhone.</span><span class="al-textbtn" style="min-height:auto">Erneut</span></div>
</div>''')

# ------------------------------------------------------------------ Feedback
comp("Toast", "Feedback", 260, """
# Toast

Kurzmeldungen am unteren Rand mit Undo und der Clipboard-Hinweis oben.

**SwiftUI:** Undo-Leiste in `InboxView`, `ClipboardNote` (AlbumRoot.swift) · Status: **Bestand; Undo-Toast vereinheitlichen**

- Undo-Toast: Navy-Pille (`action-fill`), Text `body`/15 links, „Rückgängig“ rechts als helle Innenpille. Sitzt 12 pt über der Tab-Leiste und bleibt bis zur nächsten Aktion bzw. 6 s.
- Gilt für Ideen-Entscheidungen, übernommene Pläne, „Als besucht markieren“ und gelöschte Kommentare.
- Clipboard-Hinweis: Karte oben unter der Toolbar, Icon-Mulde `paper-deep` mit `link` in `red`, „Link kopiert“ / „Als Idee einwerfen?“ und nativer „Einfügen“-Knopf (`red-fill`). Wegwischen nach oben, verschwindet nach 6 s.
- Der Inhalt der Zwischenablage wird erst beim Tippen auf „Einfügen“ gelesen.
""", f'''
<div class="al-cell" style="width:362px;gap:16px">
<div class="al-toast">{icon("check")}<span class="grow">„Letná Park“: Ja</span><span class="act">{icon("undo")}Rückgängig</span></div>
<div class="al-toast">{icon("calendar")}<span class="grow">Plan für Mo, 5. Okt übernommen</span><span class="act">Rückgängig</span></div>
<div class="al-note"><span class="well">{icon("link")}</span><div class="grow"><div class="t-label">Link kopiert</div><div class="t-foot soft">Als Idee einwerfen?</div></div><span class="al-btn small coral" style="min-height:36px;padding:6px 14px">Einfügen</span></div>
</div>''')

comp("SyncIsland", "Feedback", 200, """
# SyncIsland

Kleine schwebende Abgleich-Insel für den Sync-Zustand zwischen beiden iPhones.

**SwiftUI:** `SyncIsland.swift`, Abgleich in `ReiseView` / `AlbumStore` · Status: **Bestand**

- Pille 40 pt, `card` + `elevation-floating`, Punkt + Text `label`/14.
- Zustände: **Abgleich** (Spinner), **Abgeglichen** (`teal`), **Ausstehend** (`ink-soft`, „2 Änderungen warten“), **Fehler** (`red`, „Nicht abgeglichen · Erneut“), **Neu von Mia** (kurz, wenn die andere Person etwas geändert hat).
- Offline zuerst: Lokale Eingaben gehen nie verloren. Bei Konflikten gewinnt der neuere Zeitstempel, ohne Rückfrage.
- Erscheint beim Herunterziehen oder nach Änderungen, sonst bleibt sie verborgen.
""", '''
<span class="al-island busy"><i class="dot"></i>Abgleich …</span>
<span class="al-island ok"><i class="dot"></i>Abgeglichen</span>
<span class="al-island"><i class="dot"></i>2 Änderungen warten</span>
<span class="al-island err"><i class="dot"></i>Nicht abgeglichen · Erneut</span>
<span class="al-island ok"><i class="dot"></i>3 neue Ideen von Mia</span>
''')

comp("StateView", "Feedback", 420, """
# StateView

Leer-, Lade-, Offline- und Fehlerzustände in einer gemeinsamen Form.

**SwiftUI:** verstreute Leerzustände („Noch nichts gesammelt“, „Noch keine Flüge“, „Noch keine besuchten Orte“) · Status: **Neu als einheitlicher Baustein**

- Leer: Mulde 72 pt (`paper-deep`) mit Symbol, Titel `section`, ein Satz in `meta`, höchstens eine Aktion (sekundär oder primär).
- Laden: Skeletons in `paper-deep` mit der Form des Inhalts (Zeile, Karte). Kein Spinner auf ganzen Seiten.
- Offline: Banner `paper-deep` mit `wifi-off`. Inhalte bleiben sichtbar. Karte, Ortssuche und TikTok brauchen Netz und sagen das.
- Fehler: Banner `err` mit konkreter Ursache und „Erneut versuchen“. Nie „Etwas ist schiefgelaufen“ ohne Ausweg.
- Texte nennen, was bleibt („Links und Nachrichten bleiben hier, auch wenn du gerade offline bist.“).
""", f'''
<div class="al-card" style="width:300px"><div class="al-empty"><span class="well">{icon("inbox-full")}</span><h4 class="t-section">Noch nichts gesammelt</h4><p class="t-meta" style="margin:0">Links und Nachrichten bleiben hier, auch wenn du gerade offline bist.</p><span class="al-btn small">{icon("plus")}Sammeln</span></div></div>
<div class="al-cell" style="width:330px;gap:12px">
<div class="al-card" style="display:flex;gap:12px;align-items:center"><div class="al-skel" style="width:64px;height:64px;border-radius:12px"></div><div style="flex:1;display:flex;flex-direction:column;gap:8px"><div class="al-skel" style="height:16px;width:70%"></div><div class="al-skel" style="height:12px;width:45%"></div></div></div>
<div class="al-banner">{icon("wifi-off")}<span class="grow">Offline. Karte und Ortssuche brauchen Internet.</span></div>
<div class="al-banner err">{icon("warn")}<span class="grow">Ortssuche nicht erreichbar.</span><span class="al-textbtn" style="min-height:auto">Erneut versuchen</span></div>
<div class="al-banner ok">{icon("check")}<span class="grow">Alles abgeglichen.</span></div>
</div>''')

comp("ConfirmDialog", "Feedback", 300, """
# ConfirmDialog

Bestätigungsdialog für folgenreiche, geteilte oder schwer umkehrbare Aktionen.

**SwiftUI:** `.alert`/`.confirmationDialog` in `PlaceEditor`, `AssistantView`, `CollectionViews` · Status: **Bestand (System), Texte vereinheitlichen**

- Systemdialog mit Album-Flächen: `card`, `radius-card`. Titel `label`/17, Text `footnote`.
- Formel: Titel = Frage mit Objekt, Text = Folge für **beide** iPhones. Beispiel: „Ort löschen?“ / „Er verschwindet auch auf dem anderen iPhone.“
- Plan übernehmen: „Plan übernehmen?“ / „Der Plan wird gegen die aktuelle Reise geprüft und erst jetzt gespeichert.“
- Die destruktive Option steht rechts in `red`, „Abbrechen“ links.
""", f'''
<div style="position:relative;width:340px;height:240px;border-radius:22px;overflow:hidden;background:var(--paper-deep)"><div class="al-alert" style="position:absolute"><div class="b"><span class="t-label" style="font-size:17px">Ort löschen?</span><span class="t-foot">Er verschwindet auch auf dem anderen iPhone.</span></div><div class="a"><span>Abbrechen</span><span class="coral">Löschen</span></div></div></div>
<div style="position:relative;width:340px;height:240px;border-radius:22px;overflow:hidden;background:var(--paper-deep)"><div class="al-alert" style="position:absolute"><div class="b"><span class="t-label" style="font-size:17px">Plan übernehmen?</span><span class="t-foot">Der Plan wird gegen die aktuelle Reise geprüft und erst jetzt gespeichert.</span></div><div class="a"><span>Abbrechen</span><span>Übernehmen</span></div></div></div>
''')

comp("ImageChoice", "Fotos", 470, """
# ImageChoice

Bildwahl für einen Ort: Kandidaten in fester Quellenreihenfolge, unsichere Fotos zur manuellen Bestätigung, Credits sichtbar.

**SwiftUI:** „Bild wählen“ in `PlaceEditor`, `PlaceImageService.swift` · Status: **Bestand; Layout angleichen**

- Raster mit zwei Spalten, `radius-tile`, Foto 116 pt, darunter Quelle (`label`/13) und Credit (`caption` in `ink-soft`).
- Reihenfolge: Linkvorschau, Wikimedia (sicher), Wikimedia (unsicher, mit Badge „Ortszuordnung bitte prüfen“), eigenes Foto („Eigenes Foto wählen“), Apple-Karten-Vorschau.
- Hinweis über unsicheren Kandidaten: „Prüfe, ob das Foto wirklich Altstädter Ring zeigt.“
- Gewählt: Rahmen 3 pt `ink` + Häkchen. Eine manuelle Wahl und eigene Fotos haben Vorrang vor jeder Automatik.
- „Bild entfernen“ als destruktive Textaktion am Ende.
""", f'''
<div style="width:380px;display:flex;flex-direction:column;gap:12px">
<div class="al-banner">{icon("info")}<span class="grow">Prüfe, ob das Foto wirklich Altstädter Ring zeigt.</span></div>
<div class="al-pick">
<div class="al-cand on"><span class="tick">{icon("check")}</span>{photo("oldtown")}<div class="meta"><span class="t-label" style="font-size:13px">Linkvorschau</span><span class="t-caption soft">Bild der Quelle · prague.eu</span></div></div>
<div class="al-cand">{photo("bridge")}<div class="meta"><span class="t-label" style="font-size:13px">Wikimedia</span><span class="al-badge warn" style="height:20px;font-size:11px">{icon("warn")}Bitte prüfen</span></div></div>
<div class="al-cand"><div class="al-photo" style="height:116px;border-radius:0"><div class="empty">{icon("camera")}</div></div><div class="meta"><span class="t-label" style="font-size:13px">Eigenes Foto wählen</span><span class="t-caption soft">ohne EXIF · max. 2048 px</span></div></div>
<div class="al-cand"><div class="al-photo" style="height:116px;border-radius:0"><div class="al-lookaround"></div></div><div class="meta"><span class="t-label" style="font-size:13px">Apple-Karten-Vorschau</span><span class="t-caption soft">Apple Karten · Straßenansicht</span></div></div>
</div></div>''')
