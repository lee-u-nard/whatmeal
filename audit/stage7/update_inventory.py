import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rows = json.loads((ROOT / 'audit/stage6/requirements.json').read_text())
for row in rows:
    if row['id'] in {'R008','R009','R015','R019'}:
        row['evidence'] = '65/65 unchanged security cases pass; separate real Auth emulator two-account create/join/remove/rejoin/leave workflow passes'
    if row['id'] in {'R030','R088'}:
        row['evidence'] = 'Two Auth emulator accounts observe bidirectional pantry writes through authenticated REST; repository stream tests also pass'
        row['status'] = 'PARTIALLY IMPLEMENTED'
        row['action'] = 'No Android device/AVD available; REST does not prove two-device SDK listeners, offline recovery or UI parity'
    if row['id'] in {'R060','R063','R064','R069'}:
        row['evidence'] = 'Explicit plan paths in detail/history/calendar/home/generated routes and operations; duplicate IDs, successor favorites, cycles and stale A-logout-A sessions tested'
        row['action'] = 'Verify navigation and dialogs on device; remaining reused-plan/history interactions need UI coverage'
    if row['id'] in {'R074','R077'}:
        row['evidence'] = 'Household meal events carry plan path and meal ID into guarded detail resolution; route tests pass'
    if row['id'] == 'R050':
        row['evidence'] = 'Bundled Gemini/Unsplash literals removed; optional image key uses build configuration; existing owner-only cloud provider key storage unchanged'
        row['action'] = 'Owner credential rotation and separate secure-storage migration decision remain; build defines are extractable'
    if row['id'] == 'R084':
        row['evidence'] = 'Explicit tester-signing opt-in and optional ignored release-key configuration added; see Stage 7 build log for actual build result'
        row['action'] = 'Supply release keystore; no device/AVD exists here to install and verify tester APK'
    if row['id'] == 'R089':
        row['evidence'] = 'Stage 7 preserves historical results and records 175 passing Flutter tests, clean analysis and local backend acceptance'

(ROOT / 'audit/stage7/requirements.json').write_text(json.dumps(rows, indent=2)+'\n', encoding='utf-8')
out = ['# WhatMeal functionality reconciliation — Stage 7', '',
       'Updated 2026-10-11. [Detailed results](audit/stage7/REPORT.md), [tester setup and remaining device checks](audit/stage7/TESTER.md). Historical inventories are preserved.', '',
       '**175 Flutter tests pass; analysis is clean; all 65 existing security cases pass.** A separate two-account Auth/Firestore emulator REST workflow also passes. These results do not establish live provider, native notification, offline SDK or two-device behavior. The full application is not certified complete.', '',
       'IMPLEMENTED describes bounded evidence; PARTIALLY IMPLEMENTED retains concrete verification/implementation gaps. Production was not modified or deployed.', '']
for area in dict.fromkeys(row['area'] for row in rows):
    out += [f'## {area}', '', '| ID / behavior | Status | Evidence | Remaining action |', '|---|---|---|---|']
    for r in rows:
        if r['area'] == area:
            out.append(f"| {r['id']} {r['feature']} | {r['status']} | {r['evidence']} | {r['action']} |")
    out.append('')
out += ['Maintain through `audit/stage7/update_inventory.py`. All 89 requirement groups remain tracked; counts are not counts of individual defects.', '']
(ROOT / 'WHATMEAL_FUNCTIONALITY.md').write_text('\n'.join(out), encoding='utf-8')
