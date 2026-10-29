"""Reconcile evidence without modifying the historical Stage 4 inventory."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
rows = json.loads((ROOT / 'audit/stage4/requirements.json').read_text())

def update(ids, status, evidence, action):
    for row in rows:
        if row['id'] in ids.split():
            row.update(status=status, evidence=evidence, action=action)

update(' '.join(f'R{i:03}' for i in range(8, 22)), 'IMPLEMENTED',
       'Local v2 rules: 65/65 actual emulator acceptance cases passed; see Stage 6 report',
       'Local evidence only; client/device behavior and production migration/cutover remain separate')
update('R024', 'PARTIALLY IMPLEMENTED',
       'Stable participant IDs persisted and resolved for generation/replacement; absent profiles rejected',
       'Exercise edit/delete participant changes on device and resolve remaining meal-route identity ambiguity')
update('R025', 'PARTIALLY IMPLEMENTED',
       'Current nullable draft cuisine and explicit selection covered by local context tests',
       'Verify untouched and changed cuisine controls on device')
update('R027 R030', 'PARTIALLY IMPLEMENTED',
       'Atomic pantry/activity store; shared repository workflow and role-restricted emulator writes pass',
       'Real two-device updates and offline recovery remain unverified')
update('R032 R033 R036 R052 R059', 'PARTIALLY IMPLEMENTED',
       'Transactional stores have passing local regression tests; relevant schema and role emulator cases pass',
       'Exercise actual client contention and failure recovery; fake Firestore alone does not prove contention')
update('R034 R035', 'PARTIALLY IMPLEMENTED',
       'Manual grocery rename collision/field preservation tests pass; writes awaited before feedback',
       'Widget/device confirmation, error and retry interactions remain to be exercised')
update('R039 R040 R065', 'PARTIALLY IMPLEMENTED',
       'Accepted-meal projection and pantry shortage/replacement/deletion behavior pass shared workflow tests',
       'Verify real provider ingredient units and two-device UI behavior')
update('R042', 'PARTIALLY IMPLEMENTED',
       'Remote changes/deletion, pending writes and A-B-A scope tests pass',
       'Real multi-device secure provider-settings synchronization still unverified')
update('R051 R054', 'PARTIALLY IMPLEMENTED',
       'Generation failures have tested safe categories and redaction; adapter tests pass',
       'Complete all exception-path review and actual isolated provider calls')
update('R057 R058 R060 R061 R062 R063 R064', 'PARTIALLY IMPLEMENTED',
       'Persistence, nested streams, account guards and shared meal lifecycle tests pass; 21-meal batch passes emulator',
       'Device generation/navigation and explicit meal-detail plan identity remain to be verified/fixed')
update('R067', 'PARTIALLY IMPLEMENTED',
       'Home filters active meals by plan calendar date; local date/projection tests pass',
       'Verify recommendations and date rollover in the visible app')
update('R070 R071 R073', 'PARTIALLY IMPLEMENTED',
       'Shared activity/private receipts tested locally and in emulator; pantry mutation/event is atomic',
       'Device badge/read/navigation behavior and all event producers need end-to-end verification')
update('R074 R075 R076', 'PARTIALLY IMPLEMENTED',
       'Guarded target routing and queued notification handling implemented; session-version guard added',
       'Native foreground/background/cold-start and account-switch device tests pending')
update('R084', 'PARTIALLY IMPLEMENTED',
       'Release APK built (55.8 MB); process-local Java socket setting resolved build blocker',
       'Existing debug signing remains; isolated device install and proper release signing required')
update('R085', 'IMPLEMENTED',
       '65/65 actual Firestore emulator acceptance cases passed; security-acceptance.txt',
       'Keep regression suite current; no production deployment or live certification implied')
update('R089', 'IMPLEMENTED',
       'Historical reports retained; Stage 6 supersedes Java blocker and local security-unverified status',
       'Continue updating bounded evidence; do not label the entire app complete')

counts = Counter(row['status'] for row in rows)
(ROOT / 'audit/stage6/requirements.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
out = ['# WhatMeal functionality reconciliation — Stage 6', '',
       'Updated 2026-10-10. Source: [project context](WHATMEAL_CONTEXT.md). Latest evidence: [Stage 6 report](audit/stage6/REPORT.md). Historical inventories remain unchanged.', '',
       f'{len(rows)} tracked behavior groups. ' + '; '.join(f'{key}: {value}' for key, value in sorted(counts.items())) + '.', '',
       '**IMPLEMENTED** means the bounded behavior has the stated local evidence, not live device/provider/production verification. **PARTIALLY IMPLEMENTED** retains meaningful remaining gaps. C01/C02 now pass the local emulator security suite; deployed rules were not changed or verified.', '',
       'Current checks: 172 Flutter tests passed; analysis clean; 65/65 emulator cases passed; release APK built with existing debug signing. Full app completion remains unverified.', '']
for area in dict.fromkeys(row['area'] for row in rows):
    out += [f'## {area}', '', '| ID / behavior | Expected behavior | Status | Current evidence | Remaining action |', '|---|---|---|---|---|']
    for row in rows:
        if row['area'] == area:
            out.append(f"| {row['id']} {row['feature']} | {row['expected']} | {row['status']} | {row['evidence']} | {row['action']} |")
    out.append('')
out += ['Maintain with `audit/stage6/update_inventory.py`; machine-readable evidence is in `audit/stage6/requirements.json`. Counts describe requirement groups, not individual proven defects. Production migration/deployment and any breaking credential migration require separate approval.', '']
(ROOT / 'WHATMEAL_FUNCTIONALITY.md').write_text('\n'.join(out), encoding='utf-8')
print(json.dumps(dict(total=len(rows), statuses=counts)))
