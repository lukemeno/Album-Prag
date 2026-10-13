import json, os
from gen_base import write, ROOT
from gen_components import C
from gen_screens import S

names = []
for name, group, height, readme, body, style in C:
    write(f"components/{name}/README.md", readme)
    write(f"components/{name}/preview.html",
          f'<!-- @dsCard group="{group}" height={height} -->\n<!doctype html><html lang="de"><head><meta charset="utf-8"></head><body>'
          f'<div class="al-stage" style="{style}">{body}</div></body></html>\n')
    names.append(name)

for name, group, height, readme, body in S:
    n_land = body.count('al-phone land')
    n = body.count('class="al-phone')
    width = (n - n_land) * 402 + n_land * 874 + (n - 1) * 36 + 80
    write(f"components/{name}/README.md", readme)
    write(f"components/{name}/preview.html",
          f'<!-- @dsCard group="{group}" height={height} width={width} -->\n<!doctype html><html lang="de"><head><meta charset="utf-8"></head><body>'
          f'<div class="al-stage" style="padding:30px 40px;gap:36px;flex-wrap:nowrap">{body}</div></body></html>\n')
    names.append(name)

print(len(names), "cards")
