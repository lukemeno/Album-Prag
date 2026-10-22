"""Gleicht die Referenzorte aus seed.py mit Wikidata ab und schreibt ../golden.json.
Beleg gilt nur, wenn ein Wikidata-Eintrag mit passendem Namen höchstens 300 m (Flächenobjekte 600 m) von der Referenzkoordinate liegt.
Aufruf: python3 resolve_wikidata.py   (braucht Netz, nur lesende Wikidata-Abfragen)"""
import json, math, time, urllib.parse, urllib.request, os
exec(open(os.path.join(os.path.dirname(__file__), "seed.py"), encoding="utf-8").read())
UA = {"User-Agent": "AlbumGoldenSet/1.0 (private travel app; contact via repo)"}
def get(params, need=None):
    """Mit Wiederholung bei Netz-, Rate-Limit- oder Teilfehlern; need = Schlüssel, der in der Antwort stehen muss."""
    url = "https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode({**params, "format": "json", "maxlag": "5"})
    for attempt in range(8):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as r: data = json.load(r)
            if "error" not in data and (need is None or need in data): return data
        except Exception:
            pass
        time.sleep(2 * (attempt + 1))
    raise SystemExit(f"Wikidata nicht erreichbar für {params.get('search') or params.get('ids')}")
def dist(a, b, c, d):
    p = math.pi / 180; x = (math.sin((c - a) * p / 2)) ** 2 + math.cos(a * p) * math.cos(c * p) * (math.sin((d - b) * p / 2)) ** 2
    return 12742000 * math.asin(math.sqrt(x))
def coords(entity):
    for c in entity.get("claims", {}).get("P625", []):
        v = c["mainsnak"].get("datavalue", {}).get("value")
        if v: return v["latitude"], v["longitude"]
def has_image(entity): return bool(entity.get("claims", {}).get("P18"))
out, report = [], []
for i, e in enumerate(L, 1):
    row = {"id": f"g{i:03d}", **{k: e[k] for k in ("query", "region", "kind", "category", "tags")}, "same_as": e["same_as"], "note": e["note"]}
    exp = {"label_status": "needs-human-label"}
    if e["kind"] == "variant":
        exp["label_status"] = "same-as"
    elif e["kind"] in ("dish",):
        exp.update(photo_kind="dish", policy="free_generic_image", label_status="rule")
    elif e["kind"] == "ambiguous":
        exp.update(policy="ask_user_or_generic", label_status="rule")
    elif e["kind"] == "chain":
        exp.update(policy="branch_or_neutral", label_status="rule")
    elif e["wd"]:
        found = get({"action": "wbsearchentities", "search": e["wd"], "language": e["lang"], "uselang": e["lang"], "type": "item", "limit": 20}, need="search")
        ids = [x["id"] for x in found.get("search", [])]
        ents = get({"action": "wbgetentities", "ids": "|".join(ids), "props": "claims|labels|descriptions", "languages": "en|de|" + e["lang"]}, need="entities").get("entities", {}) if ids else {}
        best = None
        want = e["wd"].casefold()
        def labels(ent): return [v["value"].casefold() for v in ent.get("labels", {}).values()]
        for qid in ids:
            c = coords(ents.get(qid, {}))
            if c and e["lat"] is not None:
                d = dist(e["lat"], e["lng"], *c)
                if d > e["tol"]: continue
                names = labels(ents[qid])
                prio = 0 if want in names else 1  # exakter Namenstreffer vor Teilübereinstimmung
                cand = (prio, d, qid, c)
                if best is None or cand < best: best = cand
        if best: best = (best[1], best[2], best[3], best[0])
        if best and best[0] <= e['tol']:
            ent = ents[best[1]]; lab = (ent.get("labels", {}).get("en") or ent.get("labels", {}).get("de") or {}).get("value", "")
            exp.update(wikidata=best[1], wikidata_label=lab, lat=round(best[2][0], 5), lng=round(best[2][1], 5), distance_m=round(best[0]), has_commons_image=has_image(ent), match="exact" if best[3] == 0 else "partial", tolerance_m=e['tol'], label_status="verified-wikidata")
            exp["photo_kind"] = "exterior_or_view"
        else:
            exp["wikidata_candidates_unverified"] = ids[:3]
            report.append((row["id"], e["query"], "KEIN Treffer ≤300 m", [(q, round(dist(e["lat"], e["lng"], *coords(ents[q]))) if e["lat"] is not None and coords(ents.get(q, {})) else None) for q in ids[:3]]))
            if e["lat"] is not None: exp.update(lat=e["lat"], lng=e["lng"], coords_note="Referenz von Hand, nicht belegt")
        if e["kind"] == "venue" and exp["label_status"] == "verified-wikidata":
            exp["photo_kind"] = "exterior_or_dish"
    exp["must_not"] = ["logo", "menu", "map", "people_dominant", "wrong_city"]
    row["expected"] = exp; out.append(row)
    time.sleep(0.6)
json.dump({"version": 1, "created": "2026-10-22", "cases": out}, open(os.path.join(os.path.dirname(__file__), "..", "golden.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("verified:", sum(1 for r in out if r["expected"]["label_status"] == "verified-wikidata"), "von", len(out))
for r in report: print(r)
