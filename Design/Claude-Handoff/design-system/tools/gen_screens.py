from gen_base import *

S = []  # (name, group, height, readme, body)

def screen(name, group, readme, phones, height=960):
    S.append((name, group, height, readme.strip() + "\n", phones))

def top(h=60):
    return f'<div style="height:{h}px"></div>'

def header_album():
    return (f'<div class="al-page" style="display:flex;align-items:center;justify-content:space-between;height:66px">'
            f'<span class="t-display">Album</span><span style="display:flex;gap:12px"><span class="al-iconbtn">{icon("people")}</span>'
            f'<span class="al-iconbtn">{icon("plus")}</span></span></div>')

def navtitle(title, left="", right="", large=False):
    if large:
        return (f'<div class="al-page" style="display:flex;align-items:center;justify-content:space-between;height:56px">'
                f'<span class="t-display" style="font-size:30px">{title}</span><span style="display:flex;gap:12px">{right}</span></div>')
    return f'<div class="al-navbar"><span>{left or "&nbsp;"}</span><span class="ttl">{title}</span><span>{right or "&nbsp;"}</span></div>'

def sheet_open(top_px, inner, card=False, grab=True):
    g = '<i class="grab"></i>' if grab else ""
    return f'<div class="al-sheet{" card" if card else ""}" style="top:{top_px}px">{g}{inner}</div>'

def day_tiles():
    return f'''<div class="al-days" style="margin-right:-16px">
<div class="al-day today" style="width:94px"><span class="d">4. OKT</span><span class="ph" style="height:96px">{icon("calendar")}</span><span class="n">Noch offen</span></div>
<div class="al-day" style="width:94px"><span class="d">5. OKT</span><span class="ph" style="height:96px">{icon("calendar")}</span><span class="n">Noch offen</span></div>
<div class="al-day" style="width:94px"><span class="d">6. OKT</span><span class="ph" style="height:96px">{icon("calendar")}</span><span class="n">Noch offen</span></div>
<div class="al-day" style="width:94px"><span class="d">7. OKT</span><span class="ph" style="height:96px">{icon("calendar")}</span><span class="n">Noch offen</span></div></div>'''

# =============================================================== Kern: Reise
reise_main = f'''{top(54)}{header_album()}
<div class="al-page" style="margin-top:6px">{photo("bridge","grad","height:300px",f'<div class="corner r"><span class="al-iconbtn lg on-photo">{icon("more")}</span></div><div class="over"><div class="t-hero">Prag</div><div class="t-callout">4.–9. Oktober · Tag 1 von 6</div></div>', "Karlsbrücke mit Kleinseitner Brückenturm")}</div>
<div class="al-page al-people" style="margin-top:18px"><div class="al-avatars"><span class="al-avatar">LU</span></div><span class="al-btn small">{icon("people-add")}Einladen</span></div>
<div class="al-page" style="margin-top:18px"><div class="al-card" style="padding:18px 16px 16px;overflow:hidden">
<div class="al-section" style="margin-bottom:16px"><h3>Reiseplan</h3><span class="al-textbtn">{icon("calendar")}Alle öffnen</span></div>{day_tiles()}</div></div>
<div class="al-page" style="margin-top:22px"><div class="al-section"><h3 style="font-size:24px">Heute</h3></div><div class="t-meta">Sonntag, 4. Oktober</div></div>
{fab()}{tabbar("reise")}'''

reise_scrolled = f'''{top(54)}
<div class="al-page" style="padding-top:8px"><div class="al-section"><h3 style="font-size:24px">Heute</h3><span class="al-textbtn coral">Tage planen</span></div><div class="t-meta">Sonntag, 4. Oktober</div>
<div class="al-card" style="margin-top:12px;display:flex;flex-direction:column;gap:6px;align-items:flex-start"><span class="t-label" style="font-size:17px">Noch nichts geplant</span><span class="t-meta">Wähle Orte auf der Karte oder lass Tage vorschlagen.</span></div></div>
<div class="al-page" style="margin-top:22px"><div class="al-section"><h3>Morgen · Mo, 5. Okt</h3></div>
<div class="al-card" style="margin-top:12px;padding:6px 8px">
<div class="al-row"><span class="al-num">1</span>{photo("oldtown","","width:56px;height:56px;border-radius:12px")}<div class="tx"><span class="t-place-s">Altstädter Ring</span><span class="t-meta" style="font-size:13px">Sehenswert · vormittags</span></div><span class="coral">{icon("walk")}</span></div>
<hr class="al-hr" style="margin-left:52px">
<div class="al-row"><span class="al-num">2</span>{photo("letna","","width:56px;height:56px;border-radius:12px")}<div class="tx"><span class="t-place-s">Letná Park</span><span class="t-meta" style="font-size:13px">Aussicht · nachmittags</span></div><span class="coral">{icon("walk")}</span></div></div></div>
<div class="al-page" style="margin-top:22px"><div class="al-section"><h3>Unterlagen</h3><span class="al-textbtn">{icon("chev-r")}</span></div>
<div style="margin-top:12px" class="al-ticket"><div class="main" style="flex-direction:row;align-items:center;gap:12px"><span style="width:44px;height:44px;border-radius:12px;background:var(--mat-lilac);display:grid;place-items:center;font-size:22px">{icon("bed")}</span><div><div class="t-place-s">Hotel Urban Crème</div><div class="t-meta" style="font-size:13px">Unterkunft</div></div></div><div class="stub"><span class="t-eyebrow" style="font-size:11px">Buchung</span><b class="t-mono soft">—</b></div></div></div>
<div class="al-page" style="margin-top:14px"><div class="al-card" style="display:flex;align-items:center;gap:12px"><span style="width:48px;height:48px;border-radius:12px;background:var(--paper-deep);display:grid;place-items:center;font-size:22px">{icon("inbox-full")}</span><div style="flex:1"><div class="t-label" style="font-size:17px">81 Ideen warten</div><div class="t-meta">Ja, Nein oder Offen</div></div><span class="soft">{icon("chev-r")}</span></div></div>
{fab()}{tabbar("reise", compact=True)}'''

screen("ScreenReise", "Screens · Kern", """
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
""", phone(reise_main, label="Reise · Referenz") + phone(reise_scrolled, label="Reise · weiter unten"), 960)

# =============================================================== Kern: Karte
karte_half = f'''{mapbg()}
<div style="position:absolute;left:20px;right:20px;top:62px;z-index:8"><div class="al-search">{icon("search")}<span class="grow">Prag durchsuchen</span>{icon("sliders")}</div></div>
{pin(165,262,"letna")}{pin(250,390,"oldtown",sel=True)}{pin(120,330,cat="Sehenswert")}
<i class="al-me" style="left:250px;top:405px"></i>
<span class="al-maplegal" style="top:408px">Karten · Rechtl. Informationen</span>
{sheet_open(428, f"""<div class="in" style="padding-top:14px"><div style="display:flex;align-items:flex-start;justify-content:space-between"><div><div class="t-sheet">2 Orte</div><div class="t-meta">Heute 1 Ort</div></div><div style="display:flex;gap:14px;align-items:center;padding-top:4px"><span class="al-textbtn coral" style="font-size:16px">Tage planen</span><span class="al-textbtn" style="font-size:16px">Ordnen</span><span class="soft" style="font-size:20px">{icon("x")}</span></div></div>
<div class="al-chips" style="margin:16px -20px 0 0"><span class="al-chip on">Alle</span><span class="al-chip">{icon("fork")}Essen</span><span class="al-chip">{icon("columns")}Sehenswert</span><span class="al-chip">{icon("binoculars")}Aussicht</span></div>
<div class="al-rowwrap sel" style="margin-top:16px"><div class="al-row">{photo("oldtown")}<div class="tx"><span class="t-place-m">Altstädter Ring</span><span class="t-meta">Sehenswert · vormittags</span></div><span class="chev">{icon("chev-r")}</span></div><div class="acts" style="padding-left:90px"><span class="al-textbtn coral">{icon("walk")}Route</span><span class="al-textbtn coral">{icon("calendar")}5. Okt</span></div></div></div>""")}
{fab("bottom:auto;top:404px")}{tabbar("karte", badge="")}'''

karte_full = f'''{mapbg()}
{sheet_open(70, f"""<div class="in" style="padding-top:12px"><div style="display:flex;align-items:flex-start;justify-content:space-between"><div><div class="t-sheet">Orte in Prag</div><div class="t-meta">14 Orte · 2 heute</div></div><span class="soft" style="font-size:20px;padding-top:6px">{icon("x")}</span></div>
<div class="al-search flat" style="margin-top:14px;height:44px">{icon("search")}<span class="grow">Prag durchsuchen</span></div>
<div class="al-chips" style="margin:12px -20px 0 0"><span class="al-chip">Alle</span><span class="al-chip on">{icon("columns")}Sehenswert</span><span class="al-chip">{icon("fork")}Essen</span><span class="al-chip">{icon("binoculars")}Aussicht</span></div>
<div style="display:flex;flex-direction:column;gap:2px;margin:12px -8px 0">
<div class="al-row sel">{photo("oldtown")}<div class="tx"><span class="t-place-m">Altstädter Ring</span><span class="t-meta">Sehenswert · vormittags</span></div><span class="chev">{icon("chev-r")}</span></div>
<div class="al-row">{photo(None)}<div class="tx"><span class="t-place-m">Speculum Alchemiae</span><span class="t-meta">Sehenswert · Noch ohne Tag</span></div><span class="chev">{icon("chev-r")}</span></div>
<div class="al-row">{photo("bridge")}<div class="tx"><span class="t-place-m">Karlsbrücke</span><span class="t-meta">Sehenswert · Noch ohne Tag</span></div><span class="chev">{icon("chev-r")}</span></div>
<div class="al-row">{photo(None)}<div class="tx"><span class="t-place-m">St Nicholas Church · Old Town</span><span class="t-meta">Sehenswert · Noch ohne Tag</span></div><span class="chev">{icon("chev-r")}</span></div>
<div class="al-row visited">{photo(None)}<div class="tx"><span class="t-place-m">Church of Our Lady Victorious</span><span class="t-meta">Sehenswert · Karmelitská 9</span></div><span class="chev">{icon("chev-r")}</span></div>
</div></div>""")}
{tabbar("karte", badge="")}'''

karte_land = f'''{mapbg()}
{pin(560,170,"letna")}{pin(650,260,"oldtown",sel=True)}{cluster(760,230,"bridge","cafe",3)}
<div style="position:absolute;right:20px;top:20px;width:300px;z-index:8"><div class="al-search">{icon("search")}<span class="grow">Prag durchsuchen</span>{icon("sliders")}</div></div>
<div class="al-sheet side" style="top:12px"><i class="grab" style="display:none"></i><div class="in" style="padding:18px 16px 0"><div class="t-sheet" style="font-size:26px">2 Orte</div><div class="t-meta">Heute 1 Ort</div>
<div class="al-chips" style="margin:12px -16px 0 0"><span class="al-chip sm on">Alle</span><span class="al-chip sm">{icon("fork")}Essen</span><span class="al-chip sm">{icon("columns")}Sehenswert</span></div>
<div class="al-row sel" style="margin:12px -6px 0">{photo("oldtown")}<div class="tx"><span class="t-place-m">Altstädter Ring</span><span class="t-meta">Sehenswert · vormittags</span></div></div>
<div class="al-row" style="margin:0 -6px">{photo("letna")}<div class="tx"><span class="t-place-m">Letná Park</span><span class="t-meta">Aussicht</span></div></div></div></div>
{fab("bottom:20px;right:20px")}<div style="position:absolute;left:372px;right:0;bottom:-10px;height:90px">{tabbar("karte", badge="", compact=True)}</div>'''

screen("ScreenKarte", "Screens · Kern", """
# Karte

MapKit-Karte mit Fotopins und Clustern, schwebender Suche, Filterchips und verschiebbarem Ortsblatt. Pin und Liste sind synchron.

**Referenz:** `approved-native-design.png` (Mitte) + `2026-10-04-reference-map.png` · **SwiftUI:** `TripMapView.swift`, `PlacesDrawer.swift`, `MapPinClustering.swift`

- Suche schwebt 62 pt unter dem oberen Rand (unter der Statusleiste), volle Breite minus 2 × `page`.
- Ortsblatt **half** beginnt bei ~49 % der Höhe (Referenz 428 pt). Der KI-Kreis sitzt rechts auf dessen Oberkante.
- Kopf: „2 Orte“ (`sheet-title`), „Heute 1 Ort“, rechts „Tage planen“ (Koralle), „Ordnen“, Schließen.
- Auswahl: Pin 64 pt mit `system-blue` und gleichzeitig die Listenzeile auf `selection` mit „Route“ und Tag.
- **full:** Suche wandert ins Blatt, Liste scrollt, der letzte Eintrag bleibt über der Tab-Leiste frei.
- **Querformat:** Das Blatt wird zum schwebenden Panel links (360 pt), die Suche rückt nach rechts. Beide Drehrichtungen werden unterstützt.
- Keine Bewertungen und keine „km“-Distanzen, solange kein Standort freigegeben ist.
""", phone(karte_half, label="Karte · half · Referenz") + phone(karte_full, label="Karte · full · Filter Sehenswert") + phone(karte_land, land=True, label="Karte · Querformat"), 960)

# =============================================================== Kern: Ortsdetail
detail_main = f'''<div style="position:absolute;inset:0 0 auto 0;height:80px;overflow:hidden">{mapbg()}</div>
<div style="position:absolute;left:0;right:0;top:62px;height:380px;border-radius:28px 28px 0 0;overflow:hidden">{photo("oldtown","r0","position:absolute;inset:0")}
<span class="al-iconbtn lg on-photo" style="position:absolute;left:20px;top:22px">{icon("chev-l")}</span><span class="al-iconbtn lg on-photo" style="position:absolute;right:20px;top:22px">{icon("more")}</span></div>
{sheet_open(398, f"""<div class="in" style="padding-top:26px"><div class="t-place-xl">Altstädter Ring</div>
<div class="t-meta" style="display:flex;gap:8px;align-items:center;margin-top:18px;font-size:16px">{icon("pin-ell")}Sehenswert</div>
<p class="t-body" style="margin:18px 0 4px">Route durch die Altstadt planen.</p><div class="t-meta" style="font-size:16px">Montag, 5. Oktober</div>
<div class="al-tiles" style="--n:2;margin-top:20px"><div class="al-tile">{icon("nav")}Route</div><div class="al-tile primary">{icon("plus")}Plan ändern</div></div>
<div class="al-visit" style="margin-top:20px"><span class="knob">{icon("forward")}</span>Als besucht markieren</div></div>""", card=True)}'''

detail_more = f'''{top(54)}
<div class="al-page" style="padding-top:10px;display:flex;justify-content:space-between"><span class="al-iconbtn">{icon("chev-l")}</span><span style="display:flex;gap:12px"><span class="al-iconbtn">{icon("share")}</span><span class="al-iconbtn">{icon("more")}</span></span></div>
<div class="al-page" style="margin-top:12px"><div class="t-place-l">Speculum Alchemiae</div><div class="t-meta" style="margin-top:4px">Sehenswert · Noch ohne Tag</div></div>
<div class="al-page" style="margin-top:16px"><div class="al-tiles" style="--n:4"><div class="al-tile">{icon("nav")}Route</div><div class="al-tile primary">{icon("plus")}Zum Plan</div><div class="al-tile">{icon("share")}Teilen</div><div class="al-tile">{icon("compass")}Website</div></div></div>
<div class="al-page" style="margin-top:22px"><div class="al-section"><h3>Fotos</h3><span class="al-textbtn">Bild wählen</span></div>
<div style="display:grid;grid-template-columns:1.3fr 1fr;gap:8px;margin-top:12px">{photo("oldtown","tile","height:150px",'<span class="al-credit" style="font-size:11px;padding:4px 10px">Bild der Quelle</span>')}<div class="al-photo tile" style="height:150px"><div class="al-lookaround"></div></div></div></div>
<div class="al-page" style="margin-top:20px"><div class="al-list">
<div class="al-li">{icon("pin")}<span class="grow">Haštalská 795/1, 110 00 Praha 1</span></div>
<div class="al-li">{icon("clock")}<span class="grow soft">Keine Öffnungszeiten hinterlegt</span></div>
<div class="al-li">{icon("link")}<span class="grow">Quelle · prague.eu</span>{icon("ext")}</div>
<div class="al-li">{icon("photo")}<span class="grow soft" style="font-size:14px">Foto: Bild der Quelle · Prague City Tourism</span></div>
</div></div>
<div class="al-page" style="margin-top:16px;display:flex;gap:10px"><span class="al-btn small" style="flex:1">{icon("pencil")}Bearbeiten</span><span class="al-btn small" style="flex:1">{icon("inbox-full")}In Sammlung</span></div>'''

detail_visited = f'''<div style="position:absolute;left:0;right:0;top:0;height:400px">{photo("letna","r0","position:absolute;inset:0")}
<span class="al-iconbtn lg on-photo" style="position:absolute;left:20px;top:62px">{icon("chev-l")}</span><span class="al-iconbtn lg on-photo" style="position:absolute;right:20px;top:62px">{icon("more")}</span></div>
{sheet_open(372, f"""<div class="in" style="padding-top:26px"><div style="display:flex;justify-content:space-between;align-items:flex-start"><div class="t-place-xl">Letná Park</div><span class="al-badge ok" style="margin-top:12px">{icon("check")}Besucht</span></div>
<div class="t-meta" style="display:flex;gap:8px;align-items:center;margin-top:14px;font-size:16px">{icon("binoculars")}Aussicht</div>
<p class="t-body" style="margin:16px 0 4px">Park mit Blick über die Moldau.</p><div class="t-meta" style="font-size:16px">Dienstag, 6. Oktober</div>
<div class="al-tiles" style="--n:2;margin-top:20px"><div class="al-tile">{icon("nav")}Route</div><div class="al-tile primary">{icon("camera")}Foto ergänzen</div></div>
<div class="al-visit done" style="margin-top:20px"><span class="knob">{icon("check")}</span>Besucht · Di, 6. Oktober</div></div>""", card=True)}
<div style="position:absolute;left:20px;right:20px;bottom:34px;z-index:30"><div class="al-toast">{icon("check")}<span class="grow">Besucht</span><span class="act">{icon("undo")}Rückgängig</span></div></div>'''

screen("ScreenOrtsdetail", "Screens · Kern", """
# Ortsdetail

Ort öffnen: großes Foto, darüber ein Blatt mit Ortsname, Kategorie, Beschreibung, Tag, Aktionskacheln und dem Schieber „Als besucht markieren“.

**Referenz:** `approved-native-design.png` (rechts) + `2026-10-04-reference-detail.png` · **SwiftUI:** Detail in `TripMapView.swift`, `PlaceEditor.swift`, `VisitedTrack.swift`

- Foto beginnt unter einem Kartenstreifen (Detail öffnet aus der Karte) mit `radius-floating` oben. Zurück und „…“ als 50-pt-Kreise.
- Blatt überlappt das Foto, Greifer zentriert, Titel `place-xl`, Kategorie mit `pin-ell`-Symbol in `ink-soft`.
- Aktionskacheln: „Route“ und „Plan ändern“ (Hellblau). Mit Quelle zusätzlich „Teilen“ und „Website“.
- Weiter unten: Fotos/Galerie, Adresse, Öffnungszeiten (nur wenn vorhanden, sonst „Keine Öffnungszeiten hinterlegt“), Quelle, Bildnachweis, „Bearbeiten“, „In Sammlung“.
- Besucht: Badge, Schieber in `teal`, Undo-Toast. Danach schlägt die Hauptkachel „Foto ergänzen“ vor (Erinnerungen).
- **Weggelassen aus dem Mockup:** Sterne/„4.8 (12K)“, erfundene Beschreibungen. Text kommt aus `Place.note`.
""", phone(detail_main, label="Ortsdetail · Referenz") + phone(detail_more, label="Ortsdetail · Quelle, Adresse, Credits") + phone(detail_visited, on_photo=True, label="Ortsdetail · besucht + Undo"), 960)

# =============================================================== Ideen
ideen_main = f'''{top(54)}{navtitle("Ideen", large=True, right=f'<span class="al-iconbtn">{icon("plus")}</span>')}
<div class="al-page" style="margin-top:4px"><div class="al-seg"><span class="on">Entdecken</span><span>Sammlung</span></div></div>
<div class="al-page" style="margin-top:12px;display:flex;justify-content:space-between;align-items:center"><span class="t-meta">81 Ideen warten</span><span class="al-textbtn" style="min-height:32px">{icon("undo")}Rückgängig</span></div>
<div class="al-page" style="margin-top:6px"><div class="al-stack"><div class="behind b2"></div><div class="behind"></div><article class="al-idea">{photo("bridge","","height:270px")}<div class="body"><div class="src"><span class="al-badge line">{icon("link")}TikTok</span><span class="al-badge sky">{icon("columns")}Sehenswert</span></div><div class="t-place-l">Karlsbrücke</div><div class="t-body" style="font-size:16px;line-height:21px">Von Mia eingeworfen · Beschreibung aus dem Link, höchstens drei Zeilen …</div></div></article></div></div>
<div class="al-page" style="margin-top:28px"><div class="al-decide"><button class="al-btn no">{icon("x")}Nein</button><button class="al-btn">{icon("send")}Offen</button><button class="al-btn yes">{icon("check")}Ja</button></div></div>
{fab("bottom:110px")}{tabbar("ideen")}'''

ideen_drag = f'''{top(54)}{navtitle("Ideen", large=True, right=f'<span class="al-iconbtn">{icon("plus")}</span>')}
<div class="al-page" style="margin-top:4px"><div class="al-seg"><span class="on">Entdecken</span><span>Sammlung</span></div></div>
<div class="al-page" style="margin-top:50px"><div class="al-stack"><div class="behind"></div><article class="al-idea" style="transform:rotate(-6deg) translateX(-38px)"><span class="stampw no">Nein</span>{photo("cafe","","height:270px")}<div class="body"><div class="src"><span class="al-badge line">{icon("link")}Instagram</span><span class="al-badge rose">{icon("fork")}Essen</span></div><div class="t-place-l">Café Slavia</div><div class="t-meta">Von Mia eingeworfen</div></div></article></div></div>
<div class="al-page" style="margin-top:30px"><div class="al-decide"><button class="al-btn no grown">{icon("x")}Nein</button><button class="al-btn recede">{icon("send")}Offen</button><button class="al-btn yes recede">{icon("check")}Ja</button></div></div>
<div style="position:absolute;left:20px;right:20px;bottom:104px;z-index:25"><div class="al-toast">{icon("check")}<span class="grow">„Petřín“: Ja</span><span class="act">{icon("undo")}Rückgängig</span></div></div>
{tabbar("ideen", badge="79")}'''

ideen_done = f'''{top(54)}{navtitle("Ideen", large=True, right=f'<span class="al-iconbtn">{icon("plus")}</span>')}
<div class="al-page" style="margin-top:4px"><div class="al-seg"><span class="on">Entdecken</span><span>Sammlung</span></div></div>
<div class="al-page" style="margin-top:22px"><div class="al-card"><div class="al-empty" style="padding:20px 8px"><span class="well">{icon("check")}</span><h4 class="t-section">Alles entschieden</h4><p class="t-meta" style="margin:0">Neue Ideen erscheinen hier, sobald jemand einen Link einwirft.</p><span class="al-btn small primary">{icon("plus")}Idee einwerfen</span></div></div></div>
<div class="al-page" style="margin-top:24px"><div class="al-section"><h3>Entschieden</h3><span class="t-meta">Wiederfinden</span></div>
<div class="al-chips" style="margin-top:12px"><span class="al-chip sm on">Ja</span><span class="al-chip sm">Nein</span><span class="al-chip sm">Offen</span></div>
<div style="margin:10px -8px 0">
<div class="al-row">{photo("letna","","width:52px;height:52px")}<div class="tx"><span class="t-place-s">Petřín</span><span class="t-meta" style="font-size:13px">Aussicht · Ja</span></div><span class="al-textbtn" style="font-size:13px">Ändern</span></div>
<div class="al-row">{photo("cafe","","width:52px;height:52px")}<div class="tx"><span class="t-place-s">Café Louvre</span><span class="t-meta" style="font-size:13px">Essen &amp; Trinken · Ja</span></div><span class="al-textbtn" style="font-size:13px">Ändern</span></div>
</div></div>
{fab("bottom:110px")}{tabbar("ideen", badge="")}'''

screen("ScreenIdeen", "Screens · Unterstützend", """
# Ideen · Entdecken

Ideenstapel zum gemeinsamen Entscheiden. Wischen oder Knöpfe: rechts = Ja, links = Nein, oben = Offen. Undo ist immer erreichbar.

**SwiftUI:** `InboxView.swift` (Picker „Entdecken“/„Sammlung“), `LetterSlot.swift` · Status: **neu abgeleitet**

- Großer Titel „Ideen“ in `display` (30 pt) mit „+“ als „Idee einwerfen“. Darunter der segmentierte Picker.
- Zähler „81 Ideen warten“ links, „Rückgängig“ rechts als Textaktion.
- Karte: IdeaCard mit zwei Stapelkanten. Darunter die DecisionBar mit drei gleichwertigen Kacheln.
- Beim Ziehen erscheint der Stempel, die passende Kachel wächst. Nach der Entscheidung kommt der Undo-Toast über der Tab-Leiste, und der Tab-Badge zählt herunter.
- **Weggewischt bleibt auffindbar:** Unter „Entschieden“ stehen Filter Ja / Nein / Offen, jede Idee lässt sich ändern. „Offen“ gilt nur für den aktuellen Durchgang.
- Leer: „Alles entschieden“ mit „Idee einwerfen“ als Primäraktion.
""", phone(ideen_main, label="Entdecken") + phone(ideen_drag, label="Ziehen nach links · Undo") + phone(ideen_done, label="Alles entschieden · Wiederfinden"), 960)

# =============================================================== Sammlung
samm_list = f'''{top(54)}{navtitle("Ideen", large=True, right=f'<span class="al-iconbtn">{icon("plus")}</span>')}
<div class="al-page" style="margin-top:4px"><div class="al-seg"><span>Entdecken</span><span class="on">Sammlung</span></div></div>
<div class="al-page" style="margin-top:14px"><div class="al-search flat" style="height:44px">{icon("search")}<span class="grow">In der Sammlung suchen</span></div></div>
<div class="al-page" style="margin-top:14px;display:flex;flex-direction:column;gap:12px">
<article class="al-post"><div class="head"><span class="al-avatar sm">LU</span><div style="flex:1"><div class="t-label">Luke</div><div class="t-foot soft">vor 2 Std.</div></div></div>
<div class="prev">{photo("bridge")}<div style="min-width:0"><div class="t-label">TikTok · @creator</div><div class="t-foot soft">Beschreibung aus oEmbed, auf zwei Zeilen gekürzt …</div></div></div>
<div class="places"><span class="al-chip sm">{icon("pin")}Karlsbrücke</span></div>
<div class="foot"><span class="liked">{icon("heart-fill")} 2</span><span>{icon("bubble")} 1</span><span style="margin-left:auto">{icon("ext")} Quelle</span></div></article>
<article class="al-post"><div class="head"><span class="al-avatar sm b">MI</span><div style="flex:1"><div class="t-label">Mia</div><div class="t-foot soft">gerade eben</div></div><span class="al-badge sel">{icon("sync")}Ausstehend</span></div>
<div class="txt t-body" style="padding-bottom:2px">Kafka Museum unbedingt, Cihelná 2b!</div>
<div class="foot"><span>{icon("heart")} 0</span><span>{icon("bubble")} 0</span><span style="margin-left:auto">{icon("pin")} Ort hinzufügen</span></div></article>
</div>
{fab("bottom:110px")}{tabbar("ideen")}'''

samm_detail = f'''{top(54)}{navtitle("Beitrag", left=f'<span class="al-textbtn">{icon("chev-l")}Sammlung</span>', right=f'<span class="al-iconbtn" style="width:36px;height:36px;box-shadow:none;background:none">{icon("more")}</span>')}
<div class="al-page">{photo("bridge","","height:200px")}
<div class="t-label" style="margin-top:12px;font-size:17px">TikTok · @creator</div><div class="t-foot soft" style="margin-top:2px">Beschreibung aus oEmbed … <b style="color:var(--ink)">Mehr anzeigen</b></div>
<div style="display:flex;gap:8px;margin-top:10px"><span class="al-btn small" style="flex:1">{icon("ext")}Quelle öffnen</span><span class="al-btn small" style="flex:1">{icon("sync")}Vorschau aktualisieren</span></div></div>
<div class="al-page" style="margin-top:20px"><div class="al-section"><h3>Orte aus dem Beitrag</h3></div><div class="t-foot soft">Aus Titel und Beschreibung erkannt. Wähle den passenden Ort.</div>
<div class="al-list" style="margin-top:10px"><div class="al-li">{icon("pin")}<div class="grow"><div>Karlsbrücke</div><div class="t-foot soft">Karlův most, Praha 1</div></div><span class="al-btn small" style="min-height:34px;padding:4px 12px">Als Ort speichern</span></div>
<div class="al-li">{icon("pin")}<div class="grow"><div>Altstädter Brückenturm</div><div class="t-foot soft">Karlův most, Praha 1</div></div><span class="al-btn small" style="min-height:34px;padding:4px 12px">Als Ort speichern</span></div></div></div>
<div class="al-page" style="margin-top:20px"><div class="al-section"><h3>Kommentare</h3><span class="liked coral t-label">{icon("heart-fill")} 2</span></div>
<div style="display:flex;gap:10px;margin-top:10px"><span class="al-avatar sm b">MI</span><div class="al-msg bot" style="max-width:none;flex:1;font-size:15px">Abends mit Lichtern!</div></div></div>
<div style="position:absolute;left:20px;right:20px;bottom:30px"><div class="al-composer"><span class="grow">Kommentar schreiben</span><span class="send">{icon("send")}</span></div></div>'''

samm_add = f'''<div class="al-modal"></div>{sheet_open(110, f"""{navtitle("Sammeln", left='<span class="al-textbtn">Abbrechen</span>', right='<span class="al-textbtn">Sammeln</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:14px;padding-top:6px">
<div class="al-field"><span class="lbl">Link oder Nachricht</span><div class="al-input area" style="min-height:90px">https://www.tiktok.com/@creator/video/…</div><span class="hint">TikTok-Vorschau kommt per oEmbed. Instagram wird nicht ausgelesen.</span></div>
<div class="al-post"><div class="prev" style="margin:12px">{photo(None)}<div style="flex:1;display:flex;flex-direction:column;gap:8px;justify-content:center"><div class="al-skel" style="height:14px;width:80%"></div><div class="al-skel" style="height:11px;width:55%"></div><span class="t-foot soft">Vorschau wird geladen …</span></div></div></div>
<div class="al-field"><span class="lbl">Kommentar (optional)</span><div class="al-input"><span class="ph">Was gefällt dir daran?</span></div></div>
<div class="al-banner">{icon("wifi-off")}<span class="grow">Offline: wird sofort lokal gesammelt und später abgeglichen.</span></div>
<button class="al-btn primary block">Sammeln</button></div>""")}'''

screen("ScreenSammlung", "Screens · Unterstützend", """
# Sammlung

Geteilte Inspirations- und Beitragsliste unter „Ideen“ → „Sammlung“. Beiträge entstehen aus URL, Text oder Bild und sind sofort lokal gespeichert.

**SwiftUI:** `CollectionViews.swift`, `CollectionStore.swift`, `CollectionPlaceSuggestions.swift` · Status: **neu abgeleitet**

- Liste: CollectionPost-Karten, Suche oben, Sync-Badge nur bei „Ausstehend“ oder Fehler.
- Beitrag: Vorschau groß, „Quelle öffnen“, „Vorschau aktualisieren“, Abschnitt **Orte aus dem Beitrag** (Vorschläge aus Titel/Beschreibung via Apple Karten). Der Nutzer wählt; „Als Ort speichern“ öffnet den vorhandenen Ortseditor.
- Kommentare und Herzen sind eigene Datensätze. Kommentar löschen erfolgt mit Bestätigung.
- Sammeln-Blatt: Link oder Text, Skeleton während `metadataState = pending`, Offline-Hinweis. Kein Pflichtort.
- Mehrere Orte pro Beitrag sind möglich. „Kein Ort erkannt“ ist ein neutraler Zustand, kein Fehler.
""", phone(samm_list, label="Sammlung") + phone(samm_detail, label="Beitrag · Orte vorschlagen") + phone(samm_add, label="Sammeln · lädt / offline"), 960)

# =============================================================== Editor
ed_link = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Idee einwerfen", left='<span class="al-textbtn">Abbrechen</span>', right='<span class="al-textbtn">Speichern</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:14px;padding-top:4px">
<div class="al-photo" style="height:190px"><img src="{IMG["oldtown"]}" alt=""><span class="al-credit">Bild der Quelle · prague.eu</span><span class="al-btn small" style="position:absolute;right:10px;top:10px;min-height:34px;padding:4px 12px;z-index:3">{icon("photo")}Bild wählen</span></div>
<div class="al-field"><span class="lbl">Link</span><div class="al-input">{icon("link")}<span style="overflow:hidden;white-space:nowrap;text-overflow:ellipsis">prague.eu/en/objevujte/speculum-alchemiae…</span></div><span class="hint" style="color:var(--teal)">{icon("check")} Titel, Bild und Beschreibung übernommen</span></div>
<div class="al-field"><span class="lbl">Name der Idee</span><div class="al-input">Speculum Alchemiae</div></div>
<div class="al-field"><span class="lbl">Kategorie</span><div class="al-chips" style="flex-wrap:wrap"><span class="al-chip sm">{icon("fork")}Essen</span><span class="al-chip sm on">{icon("columns")}Sehenswert</span><span class="al-chip sm">{icon("binoculars")}Aussicht</span><span class="al-chip sm">{icon("bag")}Shopping</span><span class="al-chip sm">{icon("bed")}Unterkunft</span></div></div>
<div class="al-field"><span class="lbl">Warum möchtet ihr dorthin?</span><div class="al-input area" style="min-height:70px">Alchemie-Museum in der Prager Altstadt.</div></div>
<div class="al-field"><span class="lbl">Ort</span><div class="al-input">{icon("pin")}Haštalská 795/1, 110 00 Praha 1</div></div>
</div>""", card=False)}'''

ed_search = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Ort suchen", left=f'<span class="al-textbtn">{icon("chev-l")}</span>')}
<div class="al-page"><div class="al-search flat" style="height:46px">{icon("search")}<span class="grow" style="color:var(--ink)">Café Savoy</span>{icon("x")}</div>
<div class="t-eyebrow" style="margin:18px 0 8px">Apple Karten · Prag</div>
<div class="al-list"><div class="al-li">{icon("pin")}<div class="grow"><div>Café Savoy</div><div class="t-foot soft">Adresse aus Apple Karten</div></div></div>
<div class="al-li">{icon("pin")}<div class="grow"><div>Weiterer Treffer „Savoy“</div><div class="t-foot soft">Ähnlicher Name · bitte prüfen</div></div></div></div>
<div style="position:relative;height:200px;border-radius:22px;overflow:hidden;margin-top:16px">{mapbg()}{pin(150,130,cat="Essen & Trinken",sel=True)}</div>
<div class="t-foot soft" style="margin-top:8px">Koordinaten werden erst beim Speichern übernommen.</div>
<button class="al-btn primary block" style="margin-top:14px">Ort übernehmen</button></div>""")}'''

ed_image = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Bild wählen", left='<span class="al-textbtn">Abbrechen</span>', right='<span class="al-textbtn">Fertig</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:12px">
<div class="al-banner">{icon("info")}<span class="grow">Prüfe, ob das Foto wirklich Altstädter Ring zeigt.</span></div>
<div class="al-pick">
<div class="al-cand on"><span class="tick">{icon("check")}</span>{photo("oldtown")}<div class="meta"><span class="t-label" style="font-size:13px">Linkvorschau</span><span class="t-caption soft">Bild der Quelle</span></div></div>
<div class="al-cand">{photo("bridge")}<div class="meta"><span class="t-label" style="font-size:13px">Wikimedia</span><span class="al-badge warn" style="height:20px;font-size:11px">{icon("warn")}Bitte prüfen</span></div></div>
<div class="al-cand"><div class="al-photo" style="height:116px;border-radius:0"><div class="empty">{icon("camera")}</div></div><div class="meta"><span class="t-label" style="font-size:13px">Eigenes Foto wählen</span><span class="t-caption soft">ohne EXIF · max. 2048 px</span></div></div>
<div class="al-cand"><div class="al-photo" style="height:116px;border-radius:0"><div class="al-lookaround"></div></div><div class="meta"><span class="t-label" style="font-size:13px">Apple-Karten-Vorschau</span><span class="t-caption soft">Straßenansicht</span></div></div></div>
<div class="t-foot soft">Tripadvisor ist vorbereitet und ausgeschaltet.</div>
<span class="al-textbtn coral">{icon("trash")}Bild entfernen</span></div>""")}'''

screen("ScreenEditor", "Screens · Unterstützend", """
# Hinzufügen und Bearbeiten

Orts- und Ideen-Editor: Link, automatische Metadaten, Name, Kategorie, Beschreibung, Ort sowie die Bildwahl.

**SwiftUI:** `PlaceEditor.swift`, `PlaceImageService.swift`, `LINK-ENRICHMENT-PLAN.md` · Status: **neu abgeleitet**

- Modales Blatt mit „Abbrechen“ / „Idee einwerfen“ / „Speichern“. Oben das gewählte Bild mit Credit-Kapsel und „Bild wählen“.
- Link zuerst: Nach dem Einfügen ergänzt die App Titel, Bild und Beschreibung und bestätigt das in `teal`. Fehler stehen inline am Feld.
- Kategorie als Chips (Essen, Sehenswert, Aussicht, Shopping, Unterkunft). Ohne Wahl gilt „Idee“.
- Ortssuche: Apple-Karten-Treffer mit Adresse, ähnliche Namen als „bitte prüfen“, Kartenvorschau mit gewähltem Pin. Koordinaten werden erst beim Speichern übernommen.
- Bild wählen: Quellenreihenfolge, unsichere Fotos manuell bestätigen, Credits sichtbar, „Bild entfernen“.
- Instagram wird nicht gescrapt. Aus Social-Captions wird nie automatisch ein Ort gesetzt.
""", phone(ed_link, label="Idee einwerfen · Link erkannt") + phone(ed_search, label="Ort suchen") + phone(ed_image, label="Bild wählen"), 960)

# =============================================================== Unterlagen
unt_list = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Unterlagen", left='<span class="al-textbtn">Schließen</span>', right=f'<span class="al-textbtn">{icon("plus")}</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:12px">
<div class="al-section"><h3>Reisedaten</h3><span class="al-textbtn">Bearbeiten</span></div>
<div class="al-ticket empty"><div class="main"><div class="t-eyebrow">Hinflug · So, 4. Okt</div><div class="route"><span class="code">—</span><span class="rt">{icon("plane")}</span><span class="code">PRG</span></div><div class="kv"><div><span>Flug</span><b>—</b></div><div><span>Ab</span><b>—</b></div><div><span>An</span><b>—</b></div></div></div><div class="stub"><span class="t-eyebrow" style="font-size:11px">Buchung</span><b class="t-mono soft">—</b></div></div>
<div class="al-ticket"><div class="main" style="flex-direction:row;align-items:center;gap:12px"><span style="width:44px;height:44px;border-radius:12px;background:var(--mat-lilac);display:grid;place-items:center;font-size:22px">{icon("bed")}</span><div><div class="t-place-s">Hotel Urban Crème</div><div class="t-meta" style="font-size:13px">Unterkunft</div></div></div><div class="stub"><span class="t-eyebrow" style="font-size:11px">Buchung</span><b class="t-mono soft">—</b></div></div>
<div class="al-section" style="margin-top:8px"><h3>PDFs</h3></div>
<div class="al-doc"><span class="ic">PDF</span><div class="grow"><span class="t-label">Prag Urlaub.pdf</span><span class="t-foot soft">Noch nicht ausgelesen</span></div><span class="al-textbtn" style="font-size:14px">Auslesen</span></div>
<div class="al-doc"><span class="ic">PDF</span><div class="grow"><span class="t-label">Buchungsbestätigung.pdf</span><div class="al-progress"><i style="width:64%"></i></div><span class="t-foot soft">Wird hochgeladen · 64 %</span></div></div>
<div class="t-foot soft" style="display:flex;gap:6px;align-items:center">{icon("lock")} Privat gespeichert, nur für euch beide.</div>
<button class="al-btn block">{icon("import")}PDF hinzufügen</button></div>""")}'''

unt_extract = f'''<div class="al-modal"></div>{sheet_open(160, f"""{navtitle("Aus dem PDF gelesen", left='<span class="al-textbtn">Nicht jetzt</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:12px">
<div class="al-banner">{icon("info")}<span class="grow">Bitte prüfen. Übernommen wird erst nach „Speichern“.</span></div>
<div class="al-list"><div class="al-li">{icon("plane")}<div class="grow"><div>Hinflug</div><div class="t-foot soft">Flugnummer, Zeiten und Route aus dem PDF</div></div>{icon("check")}</div>
<div class="al-li">{icon("plane")}<div class="grow"><div>Rückflug</div><div class="t-foot soft">Flugnummer, Zeiten und Route aus dem PDF</div></div>{icon("check")}</div>
<div class="al-li">{icon("bed")}<div class="grow"><div>Hotel Urban Crème</div><div class="t-foot soft">Adresse, Check-in, Check-out</div></div>{icon("check")}</div>
<div class="al-li">{icon("doc")}<span class="grow">Buchungsnummer</span><span class="al-textbtn" style="min-height:auto;font-size:14px">Kopieren</span></div></div>
<div class="t-eyebrow" style="margin-top:4px">Inklusive</div><div class="t-foot soft">Leistungen aus der Buchung, z. B. Frühstück – nur wenn im PDF genannt.</div>
<button class="al-btn primary block">Speichern</button></div>""")}'''

unt_reader = f'''{top(54)}{navtitle("Prag Urlaub.pdf", left=f'<span class="al-textbtn">{icon("chev-l")}</span>', right=f'<span class="al-textbtn">{icon("share")}</span>')}
<div style="position:absolute;left:0;right:0;top:110px;bottom:0;background:var(--paper-deep);padding:20px;display:flex;flex-direction:column;gap:16px;align-items:center">
<div style="width:300px;height:410px;background:#fff;border-radius:4px;box-shadow:var(--elevation-pinned);padding:28px 24px;display:flex;flex-direction:column;gap:10px">
<div class="al-skel" style="height:18px;width:60%;background:#e7e9ee"></div><div class="al-skel" style="height:10px;background:#eef0f3"></div><div class="al-skel" style="height:10px;width:90%;background:#eef0f3"></div><div class="al-skel" style="height:10px;width:80%;background:#eef0f3"></div>
<div style="height:16px"></div><div style="padding:6px;border-radius:4px;background:color-mix(in srgb,var(--mat-butter) 80%,#fff)"><div class="al-skel" style="height:10px;background:#eadfb9"></div></div><div class="al-skel" style="height:10px;width:70%;background:#eef0f3"></div></div>
<span class="al-badge on-photo">Seite 1 von 3</span>
<div class="al-banner" style="width:100%">{icon("quote")}<span class="grow">Markierte Stelle wurde vom Reise-Assistenten zitiert.</span></div></div>'''

screen("ScreenUnterlagen", "Screens · Unterstützend", """
# Unterlagen

PDFs importieren und privat speichern, Flüge, Hotel und Buchung automatisch extrahieren, Details prüfen und im PDF-Reader lesen.

**SwiftUI:** `TripDocumentsView.swift`, `TripDocumentParser.swift`, `ExtractedTripSheet` (TripDataViews.swift), `BoardingPass.swift` · Status: **neu abgeleitet**

- Erreichbar über „Unterlagen“ auf „Reise“ und aus Ticketkarten. Modales Blatt „Unterlagen“.
- Oben Reisedaten als TicketCards. Solange nichts ausgelesen ist, bleiben die Werte Gedankenstriche. Hotelname aus `TripInfo`.
- PDF-Liste mit DocumentCard-Zuständen: nicht ausgelesen (Aktion „Auslesen“), lädt hoch (Fortschritt), offline (wartet), Fehler (Banner).
- „Aus dem PDF gelesen“: Prüfblatt mit Häkchen pro Fund, „Kopieren“ für Buchungsnummern, Übernahme erst mit „Speichern“.
- Reader: PDFKit auf `paper-deep`, Seitenanzeige als dunkle Kapsel. Zitate des Assistenten sind markiert.
- Leerzustand: „Füg deine Buchungsbestätigung als PDF hinzu, dann steht alles hier.“
""", phone(unt_list, label="Unterlagen · Reisedaten + PDFs") + phone(unt_extract, label="Aus dem PDF gelesen") + phone(unt_reader, label="PDF-Reader · Zitat"), 960)

# =============================================================== Assistent
as_chat = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Reise-Assistent", left='<span class="al-textbtn">Schließen</span>', right=f'<span class="al-textbtn">{icon("sliders")}</span>')}
<div class="al-page al-chat" style="padding-top:4px">
<div class="t-foot soft" style="text-align:center">{icon("lock")} Privat · Verlauf bleibt offline verfügbar.</div>
<div class="al-msg me">Was passt heute Abend in der Altstadt?</div>
<div class="al-msg bot">Aus euren Ideen passt die Geister- und Legenden-Tour. Treffpunkt ist Kožná 500/6 <span class="al-cite">1</span>.
<div class="al-sources"><div class="al-source"><span class="n">1</span><span>Gespeicherte Idee · spectrumtours.cz</span></div></div></div>
<div class="al-action"><div class="hd">{photo("cafe")}<div style="flex:1;min-width:0"><div class="t-place-s">Café Savoy</div><div class="t-meta" style="font-size:13px">Neu recherchiert · prague.eu</div></div></div><div class="ft"><button class="al-btn small">{icon("map")}Auf Karte</button><button class="al-btn small primary">{icon("plus")}Als Idee speichern</button></div></div>
<div class="al-msg bot typing">Ich sehe kurz nach …</div></div>
<div style="position:absolute;left:20px;right:20px;bottom:34px;display:flex;flex-direction:column;gap:10px"><div class="al-suggest"><span class="al-chip sm">Was passt jetzt?</span><span class="al-chip sm">Regen-Alternative</span><span class="al-chip sm">{icon("globe")}Web</span></div><div class="al-composer"><span class="grow">Womit soll ich helfen?</span>{icon("mic")}<span class="send">{icon("send")}</span></div></div>""")}'''

as_plan = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Reise-Assistent", left='<span class="al-textbtn">Schließen</span>')}
<div class="al-page al-chat">
<div class="al-msg me">Plan für Montag, eher entspannt</div>
<div class="al-action" style="padding:14px"><div class="t-eyebrow">Planvorschlag · Mo, 5. Okt</div>
<div style="margin:8px 0 12px">
<div class="al-row" style="padding:6px 0"><span class="al-num">1</span><div class="tx"><span class="t-place-s">Altstädter Ring</span><span class="t-meta" style="font-size:13px">vormittags</span></div></div>
<div class="al-row" style="padding:6px 0"><span class="al-num">2</span><div class="tx"><span class="t-place-s">Speculum Alchemiae</span><span class="t-meta" style="font-size:13px">Öffnungszeiten werden geprüft …</span></div></div>
<div class="al-row" style="padding:6px 0"><span class="al-num">3</span><div class="tx"><span class="t-place-s">Café Savoy</span><span class="t-meta" style="font-size:13px">nachmittags · neu</span></div></div></div>
<button class="al-btn primary block">Plan prüfen und übernehmen</button></div>
<div class="al-banner err">{icon("warn")}<span class="grow">Der Plan wurde inzwischen auf dem anderen iPhone geändert. Bitte erneut prüfen.</span></div>
</div>""")}
<div class="al-alert"><div class="b"><span class="t-label" style="font-size:17px">Plan übernehmen?</span><span class="t-foot">Der Plan wird gegen die aktuelle Reise geprüft und erst jetzt gespeichert.</span></div><div class="a"><span>Abbrechen</span><span>Übernehmen</span></div></div>'''

as_prefs = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Meine Vorlieben", left=f'<span class="al-textbtn">{icon("chev-l")}</span>', right='<span class="al-textbtn">Fertig</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:14px">
<div class="al-card"><div class="t-label">Als persönliche Vorliebe merken?</div><div class="t-foot soft" style="margin:4px 0 12px">„Wir laufen lieber, statt Tram zu fahren.“</div><div style="display:flex;gap:8px"><span class="al-btn small" style="flex:1">Nicht merken</span><span class="al-btn small primary" style="flex:1">Merken</span></div></div>
<div class="al-list"><div class="al-li"><span class="grow">Lieber zu Fuß als mit der Tram</span>{icon("trash")}</div><div class="al-li"><span class="grow">Cafés mit Sitzplätzen draußen</span>{icon("trash")}</div></div>
<div class="t-foot soft">Vorlieben sind privat und werden nur nach deiner Zustimmung gemerkt. Private Chats der anderen Person sind kein Kontext.</div>
<div class="al-list" style="margin-top:6px"><div class="al-li">{icon("globe")}<span class="grow">Web-Recherche</span><i class="al-toggle on"></i></div><div class="al-li">{icon("nav")}<span class="grow">Standort nur auf Nachfrage</span><i class="al-toggle"></i></div></div>
<span class="al-textbtn coral">{icon("trash")}Unterhaltung löschen</span></div>""")}'''

screen("ScreenAssistent", "Screens · Unterstützend", """
# Reise-Assistent

Privater Chat mit gemeinsamem Reisekontext: Fragen zu Reise und Dokumenten mit Quellen, Web-Recherche, Orts- und Planvorschläge. Aktionen werden immer bestätigt.

**SwiftUI:** `AssistantView.swift`, `AssistantSession.swift`, `AssistantActions.swift`, `AssistantService.swift`, `CHATBOT-PLAN.md` · Status: **neu abgeleitet**

- Geöffnet über den KI-Kreis. Blatt mit „Schließen“, Titel und Einstellungen (Vorlieben). Oben der Hinweis auf Privatsphäre und Offline-Verlauf.
- Antworten kurz, Zitate als nummerierte Kapseln mit Quellenblock. Neue Orte als Ortskarten mit „Auf Karte“ und „Als Idee speichern“.
- Planvorschlag mit „Plan prüfen und übernehmen“, dann Bestätigungsdialog und Revalidierung. Konflikte erscheinen als Banner und überschreiben nichts.
- Vorlieben: sichtbar merken, bearbeiten, löschen. Web-Recherche und Standort sind getrennt schaltbar.
- Zustände: Laden („Ich sehe kurz nach …“, abbrechbar), Offline (Frage bleibt), Fehler („Erneut versuchen“), Quote erreicht (Banner, kein Absturz).
""", phone(as_chat, label="Chat · Quelle + Ortskarte") + phone(as_plan, label="Planvorschlag · Bestätigen · Konflikt") + phone(as_prefs, label="Meine Vorlieben"), 960)

# =============================================================== Tagesplan
tp_suggest = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Vorschlag", left='<span class="al-textbtn">Abbrechen</span>', right='<span class="al-textbtn">Übernehmen</span>')}
<div class="al-page"><div class="t-meta">Aus euren Ja-Ideen, Start jeweils am Hotel Urban Crème. Bitte prüfen, bevor ihr übernehmt.</div>
<div class="al-days" style="margin:14px -20px 0 0"><div class="al-chip sm on">So 4.</div><div class="al-chip sm">Mo 5.</div><div class="al-chip sm">Di 6.</div><div class="al-chip sm">Mi 7.</div><div class="al-chip sm">Do 8.</div><div class="al-chip sm">Fr 9.</div></div>
<div class="al-card" style="margin-top:14px;padding:8px">
<div class="al-row"><span class="al-num">1</span>{photo("oldtown","","width:52px;height:52px;border-radius:12px")}<div class="tx"><span class="t-place-s">Altstädter Ring</span><span class="t-meta" style="font-size:13px">vormittags</span></div></div>
<div class="al-row"><span class="al-num">2</span>{photo(None,"","width:52px;height:52px;border-radius:12px")}<div class="tx"><span class="t-place-s">Speculum Alchemiae</span><span class="t-meta" style="font-size:13px">Öffnungszeiten werden geprüft …</span></div></div>
<div class="al-row"><span class="al-num">3</span>{photo(None,"","width:52px;height:52px;border-radius:12px")}<div class="tx"><span class="t-place-s">Old Czech Chimney Cake</span><span class="t-meta" style="font-size:13px">Karlova 145/25</span></div></div>
<div class="al-row" style="opacity:.7"><span class="al-num" style="background:var(--paper-deep);color:var(--ink-soft)">–</span><div class="tx"><span class="t-label">Frei</span><span class="t-meta" style="font-size:13px">abends</span></div></div></div>
<div style="position:relative;height:170px;border-radius:22px;overflow:hidden;margin-top:14px">{mapbg()}<svg style="position:absolute;inset:0" width="362" height="170"><path class="m-route" d="M60 120 C 120 60, 200 110, 300 50"/></svg>{pin(60,120,"oldtown")}{pin(300,60,cat="Sehenswert")}</div>
<button class="al-btn primary block" style="margin-top:14px">Übernehmen</button></div>""")}'''

tp_day = f'''{top(54)}{navtitle("Mo, 5. Oktober", left=f'<span class="al-textbtn">{icon("chev-l")}Reise</span>', right='<span class="al-textbtn">Ordnen</span>')}
<div class="al-days" style="padding:0 20px;margin-bottom:12px"><div class="al-chip sm">So 4.</div><div class="al-chip sm on">Mo 5.</div><div class="al-chip sm">Di 6.</div><div class="al-chip sm">Mi 7.</div><div class="al-chip sm">Do 8.</div></div>
<div class="al-page"><div class="al-section"><h3>Tag 2 von 6</h3><span class="t-meta">3 Orte</span></div>
<div class="al-card" style="margin-top:12px;padding:8px">
<div class="al-row"><span class="al-num done">✓</span>{photo("oldtown","","width:56px;height:56px;border-radius:12px")}<div class="tx"><span class="t-place-s" style="color:var(--ink-soft)">Altstädter Ring</span><span class="t-meta" style="font-size:13px">Besucht · vormittags</span></div></div>
<div class="al-row" style="background:var(--selection);border-radius:16px"><span class="al-num">2</span>{photo(None,"","width:56px;height:56px;border-radius:12px")}<div class="tx"><span class="t-place-s">Speculum Alchemiae</span><span class="t-meta" style="font-size:13px">Als Nächstes</span></div><span class="coral">{icon("walk")}</span></div>
<div class="al-row"><span class="al-num">3</span>{photo("cafe","","width:56px;height:56px;border-radius:12px")}<div class="tx"><span class="t-place-s">Café Savoy</span><span class="t-meta" style="font-size:13px">nachmittags</span></div><span class="coral">{icon("walk")}</span></div></div>
<button class="al-btn block" style="margin-top:14px">{icon("plus")}Ort hinzufügen</button></div>
{fab()}{tabbar("reise")}'''

screen("ScreenTagesplan", "Screens · Unterstützend", """
# Tagesplan

Automatisch vorgeschlagene Tagespläne werden vor der Übernahme bestätigt. Danach zeigt die Tagesansicht die Stopps mit „Als Nächstes“.

**SwiftUI:** `DayPlanGenerator.swift`, `DayPlanPreview.swift`, `PlacesDrawer` („Tage planen“), `ReiseView` · Status: **neu abgeleitet**

- „Tage planen“ (Koralle) öffnet das Blatt „Vorschlag“: Tageschips So 4. bis Fr 9., nummerierte Stopps, freie Zeitfenster als „Frei“, Kartenausschnitt mit gezeichneter Route.
- Start am Hotel Urban Crème (`TripInfo.hotel`). Öffnungszeiten werden geprüft; ohne Daten erscheint keine Angabe.
- „Übernehmen“ speichert atomar. Danach folgt der Toast „Plan für Mo, 5. Okt übernommen“ mit „Rückgängig“.
- Tagesansicht: Fortschritt über besuchte Orte (`teal`), der nächste Stopp liegt auf `selection` mit Wegsymbol. „Ordnen“ für die Reihenfolge per Ziehen.
- Entfernungen nur bei freigegebenem Standort.
""", phone(tp_suggest, label="Tage planen · Vorschlag") + phone(tp_day, label="Tag · unterwegs"), 960)

# =============================================================== Teilen / Einstellungen
set_main = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Teilen", left='<span class="al-textbtn">Schließen</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:16px">
<div class="al-card" style="display:flex;gap:14px;align-items:center">{photo("bridge","thumb","width:64px;height:64px")}<div><div class="t-title" style="font-size:20px">Prag 2026</div><div class="t-meta">4.–9. Oktober · Album</div></div></div>
<div class="al-section"><h3>Teilnehmende</h3><span class="t-meta">1 von 2</span></div>
<div class="al-list"><div class="al-li"><span class="al-avatar sm">LU</span><span class="grow">Luke <span class="soft">(du)</span></span><span class="val">{icon("pencil")}</span></div>
<div class="al-li"><span class="al-avatar sm pending">?</span><span class="grow soft">Zweite Person</span><span class="al-badge">Eingeladen</span></div></div>
<button class="al-btn primary block">{icon("share")}Einladung senden</button>
<div class="t-foot soft" style="margin-top:-6px">Der private Link gilt nur für diese Reise. Wer ihn öffnet, wird zweite Person.</div>
<div class="al-section" style="margin-top:6px"><h3>Abgleich</h3></div>
<div class="al-list"><div class="al-li">{icon("check")}<span class="grow">Zuletzt abgeglichen</span><span class="val">vor 3 Min.</span></div>
<div class="al-li">{icon("sync")}<span class="grow">Jetzt abgleichen</span>{icon("chev-r")}</div>
<div class="al-li">{icon("import")}<span class="grow">Album-Backup exportieren</span>{icon("chev-r")}</div></div>
<div class="t-foot soft">Offline zuerst: Alles bleibt auf diesem iPhone. Bei Konflikten gewinnt die neuere Änderung.</div></div>""")}'''

set_invite = f'''<div style="position:absolute;inset:0;background:var(--paper)"></div>
<div style="position:absolute;left:20px;right:20px;top:120px;display:flex;flex-direction:column;align-items:center;gap:18px;text-align:center">
<div class="al-stamp" style="width:220px;transform:rotate(-3deg)"><div class="mat" style="background:var(--mat-sky)">{photo("cover","","height:170px")}</div></div>
<div class="t-display" style="font-size:30px;line-height:36px">Komm in unser Prag-Album</div>
<div class="t-body soft">4.–9. Oktober 2026. Ideen einwerfen, gemeinsam entscheiden, alles wiederfinden.</div>
<button class="al-btn primary block">Beitreten</button><span class="al-textbtn">Nicht jetzt</span></div>'''

set_sync = f'''{top(54)}{header_album()}
<div style="position:absolute;left:50%;top:116px;transform:translateX(-50%);z-index:12"><span class="al-island err"><i class="dot"></i>Nicht abgeglichen · Erneut</span></div>
<div class="al-page" style="margin-top:6px">{photo("bridge","grad","height:300px",'<div class="over"><div class="t-hero">Prag</div><div class="t-callout">4.–9. Oktober · Tag 1 von 6</div></div>')}</div>
<div class="al-page al-people" style="margin-top:18px"><div class="al-avatars"><span class="al-avatar">LU</span><span class="al-avatar b">MI</span></div><span class="al-badge warn">{icon("warn")}2 Änderungen warten</span></div>
<div class="al-page" style="margin-top:18px;display:flex;flex-direction:column;gap:10px">
<div class="al-banner err">{icon("wifi-off")}<span class="grow">Abgleich fehlgeschlagen. Deine Änderungen bleiben auf diesem iPhone.</span></div>
<div class="al-banner ok">{icon("check")}<span class="grow">3 neue Ideen von Mia</span><span class="al-textbtn" style="min-height:auto">Ansehen</span></div></div>
{fab()}{tabbar("reise")}'''

screen("ScreenTeilen", "Screens · Unterstützend", """
# Teilen und Zusammenarbeit

Name, privater Einladungslink für die zweite Person, genau zwei Teilnehmende, Sync-Status und „Jetzt abgleichen“.

**SwiftUI:** `AlbumSettings.swift`, `InvitationMoment.swift`, `SyncIsland.swift`, `SupabaseSync.swift` · Status: **neu abgeleitet**

- Blatt „Teilen“: Reisekarte („Prag 2026“), Teilnehmende (1 von 2), Primäraktion „Einladung senden“ (Share-Sheet mit privatem Link), Abschnitt Abgleich.
- Einladung empfangen: Briefmarke mit Prag-Foto, „Komm in unser Prag-Album“, „Beitreten“. Hier ist die Briefmarken-Metapher bewusst erlaubt.
- Sync-Fehler auf „Reise“: Abgleich-Insel oben, Banner mit dem Satz, dass nichts verloren ist, und ein Badge an der Teilnehmerzeile.
- Offline zuerst, anonyme Anmeldung. Der Anzeigename ist keine Berechtigung.
""", phone(set_main, label="Teilen · Einladung · Abgleich") + phone(set_invite, label="Einladung empfangen") + phone(set_sync, label="Sync ausstehend / Fehler / neu"), 960)

# =============================================================== Erststart & Erinnerungen
first_name = f'''<div style="position:absolute;inset:0;background:var(--paper)"></div>
<div class="al-page" style="position:absolute;left:0;right:0;top:110px;display:flex;flex-direction:column;gap:16px">
<svg width="84" height="84" viewBox="0 0 84 84" style="transform:rotate(-12deg);color:var(--red)"><circle cx="42" cy="42" r="40" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="42" cy="42" r="34" fill="none" stroke="currentColor" stroke-opacity=".7"/><text x="42" y="38" text-anchor="middle" font-family="ui-monospace,monospace" font-weight="700" font-size="12.5" fill="currentColor" letter-spacing="1.5">PRAHA</text><rect x="21" y="43" width="42" height="1" fill="currentColor"/><text x="42" y="56" text-anchor="middle" font-family="ui-monospace,monospace" font-weight="600" font-size="10.5" fill="currentColor">4.–9.10.</text></svg>
<div class="t-display">Wie heißt du?</div><div class="t-body soft">Dein Name steht an den Ideen, die du einwirfst.</div>
<div class="al-input rail is-focus">Lu<i class="carriage" style="left:36px"></i></div>
<button class="al-btn primary block">Los geht’s</button></div>
<div style="position:absolute;left:0;right:0;bottom:0;height:290px;background:#d1d5db;z-index:5"></div>'''

mem_main = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Prag, wie es war", right='<span class="al-textbtn">Fertig</span>')}
<div class="al-page"><div class="t-meta">6 Tage · 4 besuchte Orte</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:22px 16px;margin-top:18px">
<div style="display:flex;flex-direction:column;gap:6px"><div class="al-stamp" style="transform:rotate(-2deg)"><div class="mat" style="background:var(--mat-sky)">{photo("oldtown","","height:120px")}</div></div><span class="t-place-s">Altstädter Ring</span><span class="t-foot soft">Mo, 5. Okt</span></div>
<div style="display:flex;flex-direction:column;gap:6px"><div class="al-stamp" style="transform:rotate(2deg)"><div class="mat" style="background:var(--mat-butter)">{photo("letna","","height:120px")}</div></div><span class="t-place-s">Letná Park</span><span class="t-foot soft">Di, 6. Okt</span></div>
<div style="display:flex;flex-direction:column;gap:6px"><div class="al-stamp" style="transform:rotate(1deg)"><div class="mat" style="background:var(--mat-rose)">{photo("cafe","","height:120px")}</div></div><span class="t-place-s">Café Savoy</span><span class="t-foot soft">Di, 6. Okt</span></div>
<div style="display:flex;flex-direction:column;gap:6px"><div class="al-stamp" style="transform:rotate(-1.5deg)"><div class="mat" style="background:var(--mat-sky)"><div class="al-photo" style="height:120px;border-radius:2px;display:grid;place-items:center"><span class="al-btn small" style="position:relative;z-index:2;min-height:34px;padding:4px 10px;font-size:13px">{icon("camera")}Foto ergänzen</span></div></div></div><span class="t-place-s">Speculum Alchemiae</span><span class="t-foot soft">Mo, 5. Okt</span></div>
</div></div>""")}'''

mem_empty = f'''<div class="al-modal"></div>{sheet_open(54, f"""{navtitle("Prag, wie es war", right='<span class="al-textbtn">Fertig</span>')}
<div class="al-page" style="padding-top:60px"><div class="al-empty"><span class="well">{icon("photo")}</span><h4 class="t-section">Noch keine besuchten Orte</h4><p class="t-meta" style="margin:0">Markiert Orte unterwegs als besucht. Hier entsteht dann euer Album.</p><span class="al-btn small">{icon("map")}Karte öffnen</span></div></div>""")}'''

screen("ScreenErststartErinnerungen", "Screens · Unterstützend", """
# Erststart und Erinnerungen

Namenseingabe beim ersten Start und das Erinnerungsalbum nach der Reise.

**SwiftUI:** `NamePrompt`, `StitchTextField` (AlbumRoot.swift), `TripMemoriesView.swift`, `PhotoStack.swift` · Status: **Bestand; angleichen**

- Erststart: Poststempel, „Wie heißt du?“ (`display`), ein Satz, Eingabe mit Schreibmaschinen-Schiene, „Los geht’s“ (deaktiviert bis Text vorhanden). Blatt nicht wegwischbar.
- Erinnerungen: „Prag, wie es war“, besuchte Orte als Briefmarken mit Kategorie-Passepartout, Ortsname in `place-s`, Datum. Fehlt ein eigenes Foto, erscheint „Foto ergänzen“ im Platzhalter.
- Leer: „Noch keine besuchten Orte“ mit „Karte öffnen“.
- Erreichbar über „Erinnerungen ansehen“ auf „Reise“ (ab dem ersten besuchten Ort).
""", phone(first_name, label="Erststart · Name") + phone(mem_main, label="Erinnerungen") + phone(mem_empty, label="Erinnerungen · leer"), 960)

# =============================================================== Share Extension & Randzustände
share_ext = f'''<div style="position:absolute;inset:0;background:#2a2a2e"></div>
<div style="position:absolute;left:0;right:0;top:60px;height:300px;opacity:.5">{photo("bridge","r0","position:absolute;inset:0")}</div>
{sheet_open(380, f"""{navtitle("Album", left='<span class="al-textbtn">Abbrechen</span>', right='<span class="al-textbtn">Sammeln</span>')}
<div class="al-page" style="display:flex;flex-direction:column;gap:14px">
<div class="al-post"><div class="prev" style="margin:12px">{photo("bridge")}<div style="min-width:0"><div class="t-label">TikTok-Link</div><div class="t-foot soft">tiktok.com · Vorschau folgt in Album</div></div></div></div>
<div class="al-field"><span class="lbl">Kommentar (optional)</span><div class="al-input"><span class="ph">Was gefällt dir daran?</span></div></div>
<div class="t-foot soft" style="display:flex;gap:6px">{icon("inbox-full")} Landet in „Prag 2026 · Sammlung“. Vervollständigen kannst du es später in Album.</div>
<button class="al-btn primary block">Sammeln</button></div>""", card=True)}'''

share_queue = f'''{top(54)}{navtitle("Ideen", large=True, right=f'<span class="al-iconbtn">{icon("plus")}</span>')}
<div class="al-page" style="margin-top:4px"><div class="al-seg"><span>Entdecken</span><span class="on">Sammlung</span></div></div>
<div class="al-page" style="margin-top:14px;display:flex;flex-direction:column;gap:12px">
<div class="al-banner ok">{icon("check")}<span class="grow">2 geteilte Beiträge übernommen</span></div>
<div class="al-banner err">{icon("warn")}<span class="grow"><b>Geteilten Beitrag nicht importiert</b><br>Er gehört zu einer anderen Reise und bleibt in der Warteschlange.</span></div>
<article class="al-post"><div class="head"><span class="al-avatar sm">LU</span><div style="flex:1"><div class="t-label">Luke</div><div class="t-foot soft">aus TikTok geteilt</div></div><span class="al-badge sel">{icon("sync")}Ausstehend</span></div>
<div class="prev">{photo("bridge")}<div style="min-width:0"><div class="t-label">TikTok · @creator</div><div class="t-foot soft">Kein Ort erkannt</div></div></div>
<div class="places"><span class="al-chip sm">{icon("plus")}Ort hinzufügen</span></div><div class="foot"><span>{icon("heart")} 0</span><span>{icon("bubble")} 0</span></div></article></div>
{fab("bottom:110px")}{tabbar("ideen")}'''

screen("ScreenShareExtension", "Screens · Unterstützend", """
# Share Extension

Links und Bilder aus TikTok, Instagram, Safari oder Fotos an Album übergeben. Die Queue ist verlustfrei, vervollständigt wird später in Album.

**SwiftUI:** `ShareExtension/ShareViewController.swift`, `Shared/ShareInbox.swift`, `drainShareQueue()` · Status: **neu abgeleitet**

- Kompaktes Blatt über der Quell-App: Vorschau ohne Netzwerkaufruf (nur Host und Typ), optionaler Kommentar, Ziel „Prag 2026 · Sammlung“, „Sammeln“.
- Beim nächsten Öffnen von Album wird die Queue übernommen: Banner „2 geteilte Beiträge übernommen“. Beiträge für eine andere Reise bleiben erhalten und erscheinen als Hinweis.
- IDs sind deterministisch, eine Wiederholung erzeugt keine Dubletten.
""", phone(share_ext, on_photo=True, home_light=True, label="Teilen aus TikTok") + phone(share_queue, label="Album · Queue übernommen"), 960)

edge_offline = f'''{top(54)}{header_album()}
<div class="al-page" style="margin-top:6px">{photo("bridge","grad","height:300px",'<div class="over"><div class="t-hero">Prag</div><div class="t-callout">4.–9. Oktober · Tag 1 von 6</div></div>')}</div>
<div class="al-page" style="margin-top:14px"><div class="al-banner">{icon("wifi-off")}<span class="grow">Offline. Alles Gespeicherte ist da; Änderungen werden später abgeglichen.</span></div></div>
<div class="al-page" style="margin-top:14px"><div class="al-section"><h3 style="font-size:24px">Heute</h3></div><div class="t-meta">Sonntag, 4. Oktober</div>
<div class="al-card" style="margin-top:10px;padding:8px"><div class="al-row"><span class="al-num">1</span>{photo("oldtown","","width:56px;height:56px;border-radius:12px")}<div class="tx"><span class="t-place-s">Altstädter Ring</span><span class="t-meta" style="font-size:13px">Route in Apple Karten öffnen</span></div></div></div></div>
{fab()}{tabbar("reise")}'''

edge_map = f'''{mapbg()}
<div style="position:absolute;left:20px;right:20px;top:62px;z-index:8"><div class="al-search">{icon("search")}<span class="grow">Prag durchsuchen</span>{icon("sliders")}</div></div>
{sheet_open(450, f"""<div class="in" style="padding-top:18px"><div class="t-sheet">0 Orte</div><div class="t-meta">Noch nichts beschlossen</div>
<div class="al-empty" style="padding:20px 10px 0"><span class="well">{icon("pin")}</span><p class="t-meta" style="margin:0">Ideen mit „Ja“ erscheinen hier als Pins. Oder sucht direkt einen Ort.</p><div style="display:flex;gap:10px;flex-wrap:wrap;justify-content:center"><span class="al-btn small">{icon("tray")}Zu den Ideen</span><span class="al-btn small primary">{icon("plus")}Idee einwerfen</span></div></div></div>""")}
{fab("bottom:auto;top:426px")}{tabbar("karte", badge="")}'''

edge_load = f'''{top(54)}{navtitle("Ideen", large=True, right=f'<span class="al-iconbtn">{icon("plus")}</span>')}
<div class="al-page" style="margin-top:4px"><div class="al-seg"><span class="on">Entdecken</span><span>Sammlung</span></div></div>
<div class="al-page" style="margin-top:28px"><div class="al-idea"><div class="al-skel" style="height:270px;border-radius:0"></div><div class="body"><div class="al-skel" style="height:22px;width:40%"></div><div class="al-skel" style="height:30px;width:75%"></div><div class="al-skel" style="height:14px"></div><div class="al-skel" style="height:14px;width:60%"></div></div></div></div>
<div class="al-page" style="margin-top:16px"><div class="al-banner err">{icon("warn")}<span class="grow">Ortsfotos konnten nicht geladen werden.</span><span class="al-textbtn" style="min-height:auto">Erneut</span></div></div>
{tabbar("ideen")}'''

screen("ScreenRandzustaende", "Screens · Randzustände", """
# Randzustände

Offline, leere Karte, Laden und Fehler. Alle nutzen StateView, Banner und Skeletons, damit kein Zustand improvisiert aussieht.

**SwiftUI:** quer durch `ReiseView`, `TripMapView`, `InboxView`, `AlbumStore` · Status: **neu**

- **Offline (Reise):** Inhalte bleiben, Banner oben. Routen öffnen Apple Karten, die Ortssuche sagt, dass sie Netz braucht.
- **Leere Karte:** Das Blatt steht auf 0 Orte mit Erklärung und zwei Wegen: „Zu den Ideen“ und „Idee einwerfen“.
- **Laden (Ideen):** Skeleton in Kartenform statt Spinner. Ein Bildfehler erscheint als Banner mit „Erneut“, ohne den Stapel zu blockieren.
- Weitere Zustände: Sync ausstehend, Fehler und erfolgreich (siehe Teilen), fehlende Bildquelle (PhotoCard-Platzhalter, Look Around), manueller Bildentscheid (ImageChoice), Bestätigung und Undo (Toast, ConfirmDialog).
- Große Dynamic Type: Zeilen wachsen in der Höhe, Kacheln brechen um, nichts wird abgeschnitten. VoiceOver-Labels stehen in den Komponenten-READMEs.
""", phone(edge_offline, label="Offline · Reise") + phone(edge_map, label="Leere Karte") + phone(edge_load, label="Laden · Bildfehler"), 960)
