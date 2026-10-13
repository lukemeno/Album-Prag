"""Erzeugt tools/tokens.css aus ../project/tokens.json (nur für lokale Vorschau-Screenshots; die Artefakt-Seite erzeugt ihr eigenes tokens.css)."""
import json, os
here = os.path.dirname(os.path.abspath(__file__))
t = json.load(open(os.path.join(here, "..", "project", "tokens.json"), encoding="utf-8"))
L, D = [':root, [data-theme="light"] {'], ['[data-theme="dark"] {']
for fam in ("color", "shadow"):
    for tok in t[fam]["tokens"]:
        v = tok["value"]
        if isinstance(v, str):
            L.append(f"--{tok['name']}:{v};")
        else:
            L.append(f"--{tok['name']}:{v['light']};"); D.append(f"--{tok['name']}:{v.get('dark', v['light'])};")
R = [":root{"] + [f"--{tok['name']}:{tok['value']};" for fam in ("spacing", "radius", "size", "opacity") for tok in t[fam]["tokens"]]
R += [f"--font-{k}:{v};" for k, v in t["type"]["families"].items()] + ["}"]
F = [f"@font-face{{font-family:'{f['family']}';src:url('/project/{f['file']}');font-weight:{f['weight']};}}" for f in t["type"]["fonts"]]
open(os.path.join(here, "tokens.css"), "w", encoding="utf-8").write("\n".join(L + ["}"] + D + ["}"] + R + F))
