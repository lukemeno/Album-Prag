"""Fasst die Messläufe zusammen und baut results/bericht.html (Bildübersicht zum Durchsehen).
Aufruf: python3 make_report.py results/neu-....json results/live-alt-....json"""
import json, sys, html, collections
neu, alt = (json.load(open(p, encoding="utf-8")) for p in sys.argv[1:3])
A = {r["id"]: r for r in alt["results"]}
GOOD = {"treffer", "ok_nur_vorschlag", "ok_kein_bild"}
BAD = {"abweichend_sicher", "falsch_zu_sicher"}
LABEL = {"treffer": "Treffer", "treffer_unsicher": "Treffer, aber nur Vorschlag", "treffer_nur_kandidat": "richtig, aber nicht oben",
 "abweichend_sicher": "ANDERER Ort, sicher gewählt", "abweichend_unsicher": "anderer Ort, nur Vorschlag", "kein_bild": "kein Bild",
 "fehler": "Quelle nicht erreichbar", "falsch_zu_sicher": "FALSCH: sicheres Bild trotz Mehrdeutigkeit/Gericht", "luecke_unsicher": "Lücke: nur unsichere Ortsbilder",
 "luecke_kein_bild": "Lücke: kein Bild", "ok_nur_vorschlag": "ok: nur Vorschläge", "ok_kein_bild": "ok: kein Bild", "pruefen": "prüfen: sicheres Bild bei Kette",
 "ohne_referenz": "ohne Beleg: von Hand beurteilen"}
def table(run):
    c = collections.defaultdict(collections.Counter)
    for r in run["results"]: c[r["kind"]][r["status"]] += 1
    return c
def summary(run, title):
    out = [f"### {title} ({len(run['results'])} Fälle)", ""]
    ref = [r for r in run["results"] if r["expected_qid"] and r["kind"] in ("landmark", "venue", "variant")]
    cnt = collections.Counter(r["status"] for r in ref)
    out.append(f"Fälle mit Beleg: {len(ref)}")
    for s in ("treffer", "treffer_unsicher", "treffer_nur_kandidat", "abweichend_sicher", "abweichend_unsicher", "kein_bild", "fehler"):
        out.append(f"- {LABEL[s]}: {cnt[s]} ({round(100 * cnt[s] / max(len(ref), 1))} %)")
    for kind in ("dish", "ambiguous", "chain"):
        sub = [r for r in run["results"] if r["kind"] == kind]
        c = collections.Counter(r["status"] for r in sub)
        out.append(f"- {kind} ({len(sub)}): " + ", ".join(f"{LABEL[s]} {n}" for s, n in c.items()))
    nr = collections.Counter(r["status"] for r in run["results"] if r["status"] == "ohne_referenz")
    out.append(f"- Lokale/Orte ohne Beleg (von Hand zu beurteilen): {nr['ohne_referenz']}")
    return "\n".join(out)
text = summary(neu, "Neue Fassung (Repo, mit Region)") + "\n\n" + summary(alt, "Ältere Fassung (läuft live)")
changed = [(r, A[r["id"]]) for r in neu["results"] if r["id"] in A and r["status"] != A[r["id"]]["status"]]
text += f"\n\nUnterschiede neu ↔ alt: {len(changed)} Fälle\n" + "\n".join(f"- {r['query']} ({r['region']}): alt {LABEL[a['status']]} → neu {LABEL[r['status']]}" for r, a in changed)
open("results/zusammenfassung.txt", "w", encoding="utf-8").write(text)
def card(r, a):
    def img(x): return f'<a href="{html.escape(x["source_url"])}"><img loading="lazy" src="{html.escape(x["image_url"])}" alt=""></a>' if x else '<div class="none">kein Bild</div>'
    flag = "bad" if r["status"] in BAD else ("ok" if r["status"] in GOOD else "")
    return (f'<div class="card {flag}"><b>{html.escape(r["query"])}</b> <small>{r["id"]} · {html.escape(r["region"])} · {r["kind"]}{" · Koordinaten Ersatz" if r["stand_in_coords"] else ""}</small>'
            f'<div class="row"><figure>{img(r["best"])}<figcaption>neu: {LABEL[r["status"]]}<br>{html.escape((r["best"] or {}).get("caption", "") or "")}</figcaption></figure>'
            f'<figure>{img(a["best"])}<figcaption>alt: {LABEL[a["status"]]}<br>{html.escape((a["best"] or {}).get("caption", "") or "")}</figcaption></figure></div></div>')
cards = "\n".join(card(r, A[r["id"]]) for r in neu["results"] if r["id"] in A)
page = f'''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Bildauswahl Messlauf</title>
<style>body{{font:15px system-ui;margin:16px;max-width:1100px}}pre{{background:#f4f6f3;padding:12px;border-radius:8px;white-space:pre-wrap}}.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(340px,1fr));gap:12px}}
.card{{border:1px solid #ddd;border-radius:10px;padding:10px}}.card.bad{{border-color:#b00;background:#fff4f4}}.card.ok{{border-color:#2a7}}small{{color:#666}}
.row{{display:flex;gap:8px;margin-top:6px}}figure{{margin:0;flex:1}}img{{width:100%;height:150px;object-fit:cover;border-radius:6px}}figcaption{{font-size:12px;color:#444;margin-top:2px}}.none{{height:150px;background:#eee;display:grid;place-items:center;color:#888;border-radius:6px}}</style>
<h1>Bildauswahl: Messlauf {neu["run_at"][:10]}</h1><pre>{html.escape(text)}</pre><p>Grün = gut, rot = falsch. Jede Karte zeigt links die neue Fassung, rechts die ältere (live). Bilder: Wikimedia Commons, Quelle verlinkt.</p><div class="grid">{cards}</div>'''
open("results/bericht.html", "w", encoding="utf-8").write(page)
print(text)
