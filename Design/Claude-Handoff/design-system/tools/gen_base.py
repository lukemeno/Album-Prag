"""Gemeinsame Bausteine für die Vorschau-Generierung: Icons, Fotos, Karte, Telefonrahmen."""
import os, re

ROOT = os.path.join(os.path.dirname(__file__), "..", "project")

IMG = {
    "bridge": "/_blob/12bd731b2c4ef10b148cfadcfaa06d92",   # imgPhotoCharlesBridge
    "letna": "/_blob/0cb9dbd029776913d652efc75416bfc5",    # imgPhotoLetna
    "oldtown": "/_blob/632bd7fba453c6b00d3c4afaec62bddc",  # imgPhotoOldTown
    "cover": "/_blob/d96ce5b4af7bc0e3235d71b1e291ed10",    # imgPragueCover (Thomas Fabian, CC BY-SA 2.0)
    "cafe": "/_blob/9a5302d55f68eca26aa14e22e425912d",     # imgThumbCafe
}

L, F = "line", "fill"
ICONS = {
    "search": (L, '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 20 20"/>'),
    "sliders": (L, '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>'),
    "chev-l": (L, '<path d="M15 5l-7 7 7 7"/>'),
    "chev-r": (L, '<path d="M9 5l7 7-7 7"/>'),
    "chev-d": (L, '<path d="M5 9l7 7 7-7"/>'),
    "more": (F, '<circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/>'),
    "plus": (L, '<path d="M12 5v14M5 12h14"/>'),
    "people": (F, '<circle cx="9" cy="8" r="3.6"/><circle cx="16.6" cy="8.6" r="3"/><path d="M2.4 19.5c0-3.7 2.9-6.3 6.6-6.3s6.6 2.6 6.6 6.3z"/><path d="M16 13.3c3.4-.4 5.6 2 5.6 5.4v.8h-4.4c0-2.5-.4-4.6-1.2-6.2z"/>'),
    "people-add": (L, '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 19.5c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6z"/><circle cx="16.5" cy="8.5" r="3"/><path d="M17 13.5c2.6 0 4.5 2 4.5 6h-4"/>'),
    "calendar": (L, '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/><path d="M7.5 13h.01M12 13h.01M16.5 13h.01M7.5 16.5h.01M12 16.5h.01" stroke-width="2.6"/>'),
    "suitcase": (F, '<path d="M9 2.8h6A2.2 2.2 0 0 1 17.2 5v2h-2V4.8H8.8V7h-2V5A2.2 2.2 0 0 1 9 2.8z"/><rect x="2.5" y="7.5" width="19" height="13.5" rx="2.6"/>'),
    "tray": (F, '<path fill-rule="evenodd" d="M5.2 4h13.6l3.2 8.5V18a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-5.5zM4.5 12.4h4a3.5 3.5 0 0 0 7 0h4L17.4 6H6.6z"/>'),
    "map": (F, '<path d="M2.5 5.6 8.6 3v16.4l-6.1 2.6zM9.9 3l4.2 2v16.4l-4.2-2zM15.4 5l6.1-2.6v16.4L15.4 21.4z"/>'),
    "sparkles": (F, '<path d="M13 5.5c.65 4.6 2.8 6.75 7.4 7.4-4.6.65-6.75 2.8-7.4 7.4-.65-4.6-2.8-6.75-7.4-7.4 4.6-.65 6.75-2.8 7.4-7.4z"/><path d="M6 2c.3 1.9 1.2 2.8 3.1 3.1-1.9.3-2.8 1.2-3.1 3.1-.3-1.9-1.2-2.8-3.1-3.1C4.8 4.8 5.7 3.9 6 2z"/><path d="M4.5 10.5c.2 1.2.75 1.75 1.95 1.95-1.2.2-1.75.75-1.95 1.95-.2-1.2-.75-1.75-1.95-1.95 1.2-.2 1.75-.75 1.95-1.95z"/>'),
    "fork": (L, '<path d="M7 3v6.5a2 2 0 0 0 2 2V21M11 3v6.5a2 2 0 0 1-2 2M9 3v5.5M17 21V3c-2 1-3 4-3 7.5S15 15 17 15"/>'),
    "columns": (L, '<path d="M3.5 9 12 4l8.5 5M4 20h16M6.5 10.5v7M10.2 10.5v7M13.8 10.5v7M17.5 10.5v7M3.5 9.5h17M5 18h14"/>'),
    "binoculars": (L, '<circle cx="6.5" cy="15.5" r="3.5"/><circle cx="17.5" cy="15.5" r="3.5"/><path d="M10 15h4M3.6 13.6 6 5h3l1 10M20.4 13.6 18 5h-3l-1 10"/>'),
    "bed": (L, '<path d="M3 19V6M3 14h18v5M21 14v-1a3 3 0 0 0-3-3h-7v4"/><circle cx="7" cy="10.5" r="2"/>'),
    "bag": (L, '<path d="M5 8h14l-1 12.5H6zM9 8V6.5a3 3 0 0 1 6 0V8"/>'),
    "sparkle-cat": (L, '<path d="M12 4c.5 3.5 2 5 5.5 5.5-3.5.5-5 2-5.5 5.5-.5-3.5-2-5-5.5-5.5C10 9 11.5 7.5 12 4z"/>'),
    "nav": (L, '<path d="M20 4 4 11l7.2 1.8L13 20z"/>'),
    "walk": (L, '<circle cx="13.5" cy="4.5" r="1.7" fill="currentColor"/><path d="M9.5 21l2.6-6.6 2.6 2.4V21M7.5 12.5 11 8.3l3 1.9 2.5 3M12.1 14.4l1.2-5.2"/>'),
    "x": (L, '<path d="M6 6l12 12M18 6 6 18"/>'),
    "check": (L, '<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
    "undo": (L, '<path d="M9 14 4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>'),
    "link": (L, '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'),
    "share": (L, '<path d="M12 3.5v11M8 7.5l4-4 4 4M7.5 10.5H6v10h12v-10h-1.5"/>'),
    "compass": (L, '<circle cx="12" cy="12" r="9"/><path d="M15.6 8.4l-2.1 5.1-5.1 2.1 2.1-5.1z"/>'),
    "globe": (L, '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.4 2.5 3.7 5.5 3.7 9s-1.3 6.5-3.7 9c-2.4-2.5-3.7-5.5-3.7-9S9.6 5.5 12 3z"/>'),
    "heart": (L, '<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.4 4.3 4.3 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>'),
    "heart-fill": (F, '<path d="M12 20.5s-8-4.8-8-10.6a4.6 4.6 0 0 1 8-3 4.6 4.6 0 0 1 8 3c0 5.8-8 10.6-8 10.6z"/>'),
    "bubble": (L, '<path d="M4 5h16v11H9.5L4 20z"/>'),
    "doc": (L, '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>'),
    "wifi-off": (L, '<path d="M2 8.5a15 15 0 0 1 5.5-3.1M22 8.5A15 15 0 0 0 11 4.6M5.5 12a10 10 0 0 1 3.6-2.2M18.5 12a10 10 0 0 0-2.1-1.5M9 15.5a5 5 0 0 1 6 0M3 3l18 18"/>'),
    "sync": (L, '<path d="M19.5 10.5A7.8 7.8 0 0 0 5.6 7M4.5 3.8V7.5h3.7M4.5 13.5A7.8 7.8 0 0 0 18.4 17M19.5 20.2v-3.7h-3.7"/>'),
    "photo": (L, '<rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.8"/><path d="M21 15.5 16 11l-8.5 8"/>'),
    "camera": (L, '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>'),
    "pin": (L, '<path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0 1 13 0c0 5-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>'),
    "pin-ell": (L, '<circle cx="12" cy="6" r="2.6"/><path d="M12 8.6v7M6 17.5c-1.3.5-2 1.1-2 1.8 0 1.5 3.6 2.7 8 2.7s8-1.2 8-2.7c0-.7-.7-1.3-2-1.8"/>'),
    "mic": (L, '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>'),
    "send": (L, '<path d="M12 19V5.5M6.5 11 12 5.5l5.5 5.5"/>'),
    "forward": (L, '<path d="M5 6l6 6-6 6M12 6l6 6-6 6"/>'),
    "lock": (L, '<rect x="5" y="10.5" width="14" height="10" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>'),
    "plane": (F, '<path d="M21 15.6v-2l-8-5V4.2a1.5 1.5 0 0 0-3 0v4.4l-8 5v2l8-2.5v5.2l-2 1.5V21l3.5-1 3.5 1v-1.2L13 18.3v-5.2z"/>'),
    "info": (L, '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5h.01"/>'),
    "warn": (L, '<path d="M12 3.8 2.6 20h18.8z"/><path d="M12 10v4.5M12 17.4h.01"/>'),
    "pencil": (L, '<path d="M4 20l1-4.2L16 4.8l3.2 3.2L8.2 19z"/>'),
    "trash": (L, '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>'),
    "bookmark": (F, '<path d="M6.5 3h11v18L12 16.8 6.5 21z"/>'),
    "bookmark-l": (L, '<path d="M6.5 3.5h11v17L12 16.3l-5.5 4.2z"/>'),
    "clock": (L, '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
    "eye-off": (L, '<path d="M3 3l18 18M10.6 5.1A9.7 9.7 0 0 1 12 5c5 0 9 4.5 10 7a12.5 12.5 0 0 1-3 4M6.6 6.6C4.4 8 2.9 10 2 12c1 2.5 5 7 10 7 1.7 0 3.2-.5 4.6-1.3M9.9 9.9a3 3 0 0 0 4.2 4.2"/>'),
    "quote": (F, '<path d="M4.5 17.5h4l2-4v-6h-6v6h3zM13.5 17.5h4l2-4v-6h-6v6h3z"/>'),
    "import": (L, '<path d="M12 4v11M7 10l5 5 5-5M5 19.5h14"/>'),
    "person": (L, '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7"/>'),
    "ext": (L, '<path d="M7 17 17 7M9 7h8v8"/>'),
    "list": (L, '<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01" />'),
    "inbox-full": (L, '<path d="M5.2 4h13.6l3.2 8.5V18a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-5.5zM2.5 12.5h6a3.5 3.5 0 0 0 7 0h6M8 8h8M8.8 10h6.4"/>'),
    "pdf": (L, '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4"/>'),
    "cloud-up": (L, '<path d="M7 18a4.5 4.5 0 0 1-.6-9A6 6 0 0 1 18 9.5a4 4 0 0 1-.5 8.5M12 12v8M9 15l3-3 3 3"/>'),
    "wand": (L, '<path d="M4 20 15 9M14 4v3M19 9h-3M17.5 5.5l-2 2M10 4.5l.01.01M19.5 13.5l.01.01"/>'),
    "flag": (L, '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>'),
}

def icon(name, cls=""):
    kind, body = ICONS[name]
    return f'<svg class="al-ico {kind} {cls}" viewBox="0 0 24 24" aria-hidden="true">{body}</svg>'

CAT = {
    "Essen & Trinken": ("fork", "rose", "Essen"),
    "Sehenswert": ("columns", "sky", "Sehenswert"),
    "Aussicht": ("binoculars", "butter", "Aussicht"),
    "Unterkunft": ("bed", "lilac", "Unterkunft"),
    "Shopping": ("bag", "mint", "Shopping"),
    "Idee": ("sparkle-cat", "", "Idee"),
}

def photo(key=None, cls="", style="", inner="", alt="Ortsfoto"):
    img = f'<img src="{IMG[key]}" alt="{alt}">' if key else f'<div class="empty">{icon("photo")}</div>'
    return f'<div class="al-photo {cls}" style="{style}">{img}{inner}</div>'

SIG = ('<svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor" aria-hidden="true"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5.5" width="3" height="6.5" rx="1"/><rect x="10" y="3" width="3" height="9" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>'
       '<svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor" aria-hidden="true"><path d="M8 12 5.6 9.2a3.4 3.4 0 0 1 4.8 0zM3.4 7a6.6 6.6 0 0 1 9.2 0l-1.4 1.6a4.5 4.5 0 0 0-6.4 0zM1 4.4a10 10 0 0 1 14 0l-1.4 1.6a7.9 7.9 0 0 0-11.2 0z"/></svg>')

def status(on_photo=False, time="9:41"):
    return (f'<div class="al-status{" on-photo" if on_photo else ""}"><span>{time}</span>'
            f'<span class="sig">{SIG}<i class="bat"></i></span></div>')

def phone(inner, on_photo=False, land=False, home_light=False, label=None, time="9:41"):
    cap = f'<p class="al-cap">{label}</p>' if label else ""
    st = "" if land else status(on_photo, time)
    return (f'<div class="al-cell">{cap}<div class="al-phone{" land" if land else ""}"><div class="scroll">{inner}</div>{st}'
            f'<i class="al-home{" light" if home_light else ""}"></i></div></div>')

def tabbar(active="reise", badge="81", compact=False, static=False):
    tabs = [("reise", "suitcase", "Reise"), ("ideen", "tray", "Ideen"), ("karte", "map", "Karte")]
    out = []
    for key, ic, lab in tabs:
        b = f'<i class="al-count">{badge}</i>' if key == "ideen" and badge else ""
        out.append(f'<div class="al-tab{" on" if key == active else ""}">{icon(ic)}{b}<span>{lab}</span></div>')
    cls = "al-tabbar" + (" compact" if compact else "") + (" static" if static else "")
    return f'<nav class="{cls}" aria-label="Tabs">{"".join(out)}</nav>'

def fab(style="", static=False):
    return f'<div class="al-fab{" static" if static else ""}" style="{style}" aria-label="Reise-Assistent">{icon("sparkles")}</div>'

def map_svg():
    blocks = []
    import random
    rnd = random.Random(7)
    for gx in range(200, 420, 26):
        for gy in range(330, 640, 24):
            if rnd.random() < .78:
                w, h = rnd.randint(14, 22), rnd.randint(12, 19)
                blocks.append(f'<rect class="m-block" x="{gx + rnd.randint(0,4)}" y="{gy + rnd.randint(0,4)}" width="{w}" height="{h}" rx="2"/>')
    for gx in range(0, 120, 24):
        for gy in range(250, 420, 22):
            if rnd.random() < .6:
                blocks.append(f'<rect class="m-block" x="{gx + 4}" y="{gy + 3}" width="{rnd.randint(12,18)}" height="{rnd.randint(10,16)}" rx="2"/>')
    return f'''<svg class="base" viewBox="0 0 402 874" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
<rect class="m-land" width="402" height="874"/>
<path class="m-park" d="M-10 40 C 80 20, 200 30, 300 90 C 260 150, 140 170, 40 170 C 0 160, -20 120, -10 40z"/>
<path class="m-park" d="M-20 470 C 40 440, 90 470, 92 540 C 95 620, 40 660, -20 650z"/>
{''.join(blocks)}
<path class="m-road minor" d="M180 300 L420 360 M200 520 L420 470 M240 320 L210 700 M330 300 L320 720 M0 240 L170 330 M0 430 L120 420 M60 700 L200 640 L402 690"/>
<path class="m-road major" d="M-10 200 C 120 230, 260 240, 420 220 M150 880 C 190 700, 200 520, 280 300 S 360 120, 420 80"/>
<path class="m-river" stroke-width="44" d="M430 150 C 320 175, 200 170, 150 260 S 175 470, 130 600 S 80 820, 60 900"/>
<path class="m-road major" d="M120 438 L215 452"/>
<text class="m-label" x="30" y="122">LETNÁ</text>
<text class="m-label" x="18" y="372">MALÁ STRANA</text>
<text class="m-label" x="258" y="560">STARÉ MĚSTO</text>
<text class="m-label" x="138" y="540" transform="rotate(-78 138 540)">VLTAVA</text>
</svg>'''

def mapbg():
    return f'<div class="al-map">{map_svg()}</div>'

def pin(x, y, key=None, cat=None, sel=False, visited=False, dim=False):
    cls = "al-pin" + (" sel" if sel else "") + (" visited" if visited else "") + (" dim" if dim else "")
    if key:
        face = f'<img src="{IMG[key]}" alt="">'
    else:
        ic, mat, _ = CAT[cat]
        face = f'<div class="cat" style="background:var(--mat-{mat or "sky"})">{icon(ic)}</div>'
    return f'<div class="{cls}" style="left:{x}px;top:{y}px"><div class="face">{face}</div></div>'

def cluster(x, y, a, b, n):
    return (f'<div class="al-cluster" style="left:{x}px;top:{y}px"><div class="face b"><img src="{IMG[b]}" alt=""></div>'
            f'<div class="face"><img src="{IMG[a]}" alt=""></div><i class="n">{n}</i></div>')

def doc(marker, body, style=""):
    """Ganzes preview.html: Markerzeile, dann ein Wurzelelement."""
    return f'{marker}\n<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div class="al-stage" style="{style}">{body}</div></body></html>\n'

def cell(label, body, style=""):
    return f'<div class="al-cell" style="{style}"><p class="al-cap">{label}</p>{body}</div>'

def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(text)
