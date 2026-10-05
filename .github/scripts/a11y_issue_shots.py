"""Legt zu jedem Accessibility-Fund die Beschreibung und die Bildschirmfotos von XCTest in einen Ordner.

Aufruf: python3 .github/scripts/a11y_issue_shots.py <Exportordner> <Zielordner>
XCTest hängt pro Fund „Complete Issue Description“, „App Screenshot“ (Element markiert) und
oft „Element Screenshot“ an, in dieser Reihenfolge.
"""
import json
import os
import re
import shutil
import subprocess
import sys

source, target = sys.argv[1], sys.argv[2]
os.makedirs(target, exist_ok=True)
try:
    manifest = json.load(open(os.path.join(source, 'manifest.json')))
except Exception as error:
    print('Kein Manifest:', error)
    raise SystemExit

for test in manifest:
    name = re.sub(r'\W+', '', test.get('testIdentifier', 'test').split('/')[-1].replace('testAccessibilityAudit', ''))
    issue = 0
    for item in test.get('attachments', []):
        label = item.get('suggestedHumanReadableName', '')
        path = os.path.join(source, item['exportedFileName'])
        if label.startswith('Complete Issue Description'):
            issue += 1
            shutil.copy(path, os.path.join(target, f'{name}-{issue:02d}.txt'))
        elif issue and (label.startswith('App Screenshot') or label.startswith('Element Screenshot')):
            kind = 'app' if label.startswith('App') else 'element'
            out = os.path.join(target, f'{name}-{issue:02d}-{kind}.jpg')
            subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '70', '-Z', '900', path, '--out', out],
                           check=False, capture_output=True)
print('\n'.join(sorted(os.listdir(target))))
