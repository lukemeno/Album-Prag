"""Gibt die nicht unterdrückten Accessibility-Funde aus exportierten xcresult-Anhängen kompakt aus.

Aufruf: python3 .github/scripts/a11y_findings.py <Ordner aus `xcresulttool export attachments`>
"""
import json
import os
import re
import sys

folder = sys.argv[1] if len(sys.argv) > 1 else 'a11y'
try:
    manifest = json.load(open(os.path.join(folder, 'manifest.json')))
except Exception as error:
    print('Kein Manifest:', error)
    raise SystemExit

for test in manifest:
    for item in test.get('attachments', []):
        name = item.get('suggestedHumanReadableName', '')
        if not name.startswith('Accessibility findings'):
            continue
        lines = open(os.path.join(folder, item['exportedFileName']), errors='replace').read().split('\n')
        print('=====', test.get('testIdentifier', '?'), '|', name)
        for index, line in enumerate(lines):
            if re.search(r'\] suppressed=false$', line):
                print('  -', line)
                for extra in lines[index + 1:index + 6]:
                    print('     ', extra[:300])
                # Ohne Element steht direkt nach "<none>" die ausführliche Beschreibung von XCTest.
                if index + 7 < len(lines) and lines[index + 7].strip() == '<none>':
                    for extra in lines[index + 8:index + 11]:
                        if not extra.strip():
                            break
                        print('      »', extra[:400])
