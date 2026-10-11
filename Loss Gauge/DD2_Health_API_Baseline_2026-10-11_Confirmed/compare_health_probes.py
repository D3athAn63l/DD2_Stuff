#!/usr/bin/env python3
"""Compare two Health API Probe v1.0 JSON files.

Usage: python compare_health_probes.py BASELINE.json NEW.json
Exit 0: no detectable structural changes; 1: structural differences; 2: error.
Runtime HP numbers are intentionally NOT compared (change with gameplay).
"""
from __future__ import annotations
import json
import sys
from collections import Counter
from pathlib import Path


def signatures(rec):
    methods = (rec or {}).get('methods') or []
    if (rec or {}).get('enumerationStatus') != 'ok':
        return None
    if any(m.get('signatureStatus') != 'resolved' for m in methods):
        return None
    return Counter((m.get('signature'), m.get('returnType'), m.get('isStatic')) for m in methods)


def compare(a, b):
    changes, notes = [], []
    def diff(label, old, new):
        if old != new:
            changes.append(f'{label}: {old!r} -> {new!r}')

    diff('RE Engine TDB', a.get('tdbVersion'), b.get('tdbVersion'))
    for key in ('gameName', 'commitHash'):
        diff(f'REFramework {key}', (a.get('reframeworkInfo') or {}).get(key),
             (b.get('reframeworkInfo') or {}).get(key))
    va, vb = a.get('probeVersion'), b.get('probeVersion')
    if va != vb:
        notes.append(f'Probe version {va} -> {vb}; changes in extraction logic may mimic API changes.')
    for group in ('sdk', 're', 'json'):
        before = ((a.get('engine') or {}).get(group) or {})
        after = ((b.get('engine') or {}).get(group) or {})
        for key in sorted(set(before) & set(after)):
            diff(f'engine.{group}.{key}', before[key], after[key])
    at, bt = a.get('types') or {}, b.get('types') or {}
    for name in sorted(set(at) | set(bt)):
        if name not in at or name not in bt:
            changes.append(f'type inventory {name}: present in one capture only (may be scene-dependent)')
            continue
        x, y = at[name], bt[name]
        diff(f'{name}.exists', x.get('exists'), y.get('exists'))
        fields1, fields2 = x.get('fields') or {}, y.get('fields') or {}
        for field in sorted(set(fields1) & set(fields2)):
            for key in ('exists', 'type', 'declaringType', 'isStatic'):
                if key in fields1[field] and key in fields2[field]:
                    diff(f'{name}.field.{field}.{key}',fields1[field][key],fields2[field][key])
        if x.get('enumerationStatus')=='ok' and y.get('enumerationStatus')=='ok':
            diff(f'{name}.methodCounts',x.get('overloadsByName'),y.get('overloadsByName'))
            s1, s2=signatures(x), signatures(y)
            if s1 is not None and s2 is not None:
                if s1 != s2:
                    gone, added = s1-s2, s2-s1
                    for sign, count in gone.items(): changes.append(f'{name}: removed/changed x{count}: {sign}')
                    for sign, count in added.items(): changes.append(f'{name}: added/changed x{count}: {sign}')
            else:
                notes.append(f'{name}: at least one unresolved overload; signature comparison skipped.')
        else:
            notes.append(f'{name}: method enumeration incomplete; disappearance claims not reliable.')
    ar, br = a.get('runtime') or {}, b.get('runtime') or {}
    paths = ('playerReadPath', 'hitControllerTypeResolved', 'pawnListAvailable',
             'pawnListReadPath', 'pawnListType', 'pawnListCountReadPath', 'battleModeReadPath',
             'pausedReadPath')
    for key in paths:
        if key in ar and key in br: diff(f'runtime.{key}', ar[key], br[key])
        else: notes.append(f'runtime.{key} only available in one capture (scene dependent)')
    for key in ('character','pawn','battle','gui'):
        am=(ar.get('managers') or {}).get(key); bm=(br.get('managers') or {}).get(key)
        if am is not None and bm is not None:
            if am != bm: notes.append(f'Manager {key} availability changed: {am} -> {bm} (scene-dependent).')
    playera, playerb=ar.get('player') or {}, br.get('player') or {}
    for key in ('hitAvailable', 'hitBackingFieldAccessible','hitAccessPath','hitRuntimeType',
                'hpRead','originalMaxHpRead','reducedMaxHpRead'):
        if key in playera and key in playerb:
            diff(f'player.{key}',playera[key],playerb[key])
        else: notes.append(f'player.{key} not present in both captures (potential title-screen capture).')
    notes.append('HP, gauge deficits, pawn count and combat-mode values deliberately ignored.')
    notes.append('No structural difference DOES NOT prove setter behavior or post-update gameplay compatibility.')
    return changes, sorted(set(notes))


def main(argv):
    if len(argv)!=3:
        print(__doc__.strip()); return 2
    try:
        before=json.loads(Path(argv[1]).read_text('utf-8'))
        after=json.loads(Path(argv[2]).read_text('utf-8'))
    except (OSError,ValueError) as exc:
        print(f'ERROR: {exc}',file=sys.stderr); return 2
    changes,notes=compare(before,after)
    print(f'Health API comparison: {before.get("probeVersion")} -> {after.get("probeVersion")}')
    if changes:
        print('\nPOTENTIAL STRUCTURAL/API CHANGES:')
        for item in changes: print(' -',item)
    else:
        print('\nNo detectable structural/API changes in comparable fields.')
    print('\nNOTES:')
    for item in notes: print(' -',item)
    return 1 if changes else 0

if __name__=='__main__':
    raise SystemExit(main(sys.argv))
