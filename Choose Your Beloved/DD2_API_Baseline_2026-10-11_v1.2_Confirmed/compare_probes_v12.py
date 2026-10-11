#!/usr/bin/env python3
"""Compare two REFramework Beloved API snapshots (supports v1.0, v1.1, v1.2).

Usage: python compare_probes_v12.py BEFORE.json AFTER.json
Exit 0: no detected material API delta; 1: differences; 2: usage/invalid input.

A probe-version upgrade can expose previously hidden metadata; this is NOT by
itself evidence of game API changes. Comparison is always read-only.
"""
from __future__ import annotations
import json
import sys
from collections import Counter
from pathlib import Path


def available_methods(record):
    return [m for m in (record or {}).get('methods', []) or [] if isinstance(m, dict)]


def signature_inventory(record):
    """Only compare complete signatures if both snapshots provide them."""
    inventory = Counter()
    for m in available_methods(record):
        if m.get('signatureStatus') == 'resolved' and m.get('signature'):
            inventory[(m['signature'], m.get('returnType'), m.get('isStatic'))] += 1
    return inventory


def method_names(record):
    return set(m.get('name') for m in available_methods(record) if m.get('name'))


def compare(old, new):
    changes = []
    warnings = []
    oldver = old.get('probeVersion', '?')
    newver = new.get('probeVersion', '?')
    if oldver != newver:
        warnings.append(f'Probe version {oldver} -> {newver}: reflection behavior may differ; do NOT interpret new signatures as a DD2 patch.')
    def delta(label, a, b):
        if a != b: changes.append(f'{label}: {a!r} -> {b!r}')
    delta('TDB version', old.get('tdbVersion'), new.get('tdbVersion'))
    for k in ('gameName', 'commitHash'):
        delta('REFramework ' + k, (old.get('reframeworkInfo') or {}).get(k), (new.get('reframeworkInfo') or {}).get(k))
    for group in ('sdk','re','draw','imgui','json','reframework'):
        before = (old.get('engine') or {}).get(group) or {}
        after = (new.get('engine') or {}).get(group) or {}
        for key in sorted(set(before) | set(after)):
            if key in before and key in after:
                delta(f'engine.{group}.{key}', before[key], after[key])
            else:
                warnings.append(f'engine.{group}.{key} captured by only one probe; not compared')
    oldtypes = old.get('types') or {}
    newtypes = new.get('types') or {}
    for type_name in sorted(set(oldtypes) | set(newtypes)):
        a = oldtypes.get(type_name) or {}
        b = newtypes.get(type_name) or {}
        if type_name not in oldtypes or type_name not in newtypes:
            changes.append(f'Type {type_name}: only present in one snapshot')
            continue
        delta(f'{type_name}.exists', a.get('exists'), b.get('exists'))
        if a.get('enumerationStatus') != 'ok' or b.get('enumerationStatus') != 'ok':
            warnings.append(f'{type_name}: at least one enumeration incomplete; method-missing claims are NOT reliable')
        if a.get('exists') and b.get('exists'):
            if a.get('enumerationStatus') == 'ok' and b.get('enumerationStatus') == 'ok':
                an, bn = method_names(a), method_names(b)
                if an - bn: changes.append(f'{type_name}: method names disappeared: {sorted(an-bn)}')
                if bn - an: changes.append(f'{type_name}: method names appeared: {sorted(bn-an)}')
                # Only compare enum counts if same probe version; v1.0 was known-broken.
                if oldver == newver and oldver == '1.2':
                    delta(f'{type_name}.enumeratedMethodCount', a.get('enumeratedMethodCount'), b.get('enumeratedMethodCount'))
                    for name in sorted(set((a.get('overloadsByName') or {})) | set((b.get('overloadsByName') or {}))):
                        if name in (a.get('overloadsByName') or {}) and name in (b.get('overloadsByName') or {}):
                            delta(f'{type_name}.overloadCount.{name}', a['overloadsByName'][name], b['overloadsByName'][name])
                    # If BOTH captures fully resolved a name, check overload signatures.
                    for name in sorted(an & bn):
                        aa = [m for m in available_methods(a) if m.get('name') == name]
                        bb = [m for m in available_methods(b) if m.get('name') == name]
                        if aa and bb and all(m.get('signatureStatus') == 'resolved' for m in aa+bb):
                            sa = Counter((m['signature'],m.get('returnType'),m.get('isStatic')) for m in aa)
                            sb = Counter((m['signature'],m.get('returnType'),m.get('isStatic')) for m in bb)
                            delta(f'{type_name}.signatures.{name}', dict(sa), dict(sb))
                        else:
                            warnings.append(f'{type_name}.{name}: incomplete parameter signature in one/both snapshots')
            fieldsA, fieldsB = a.get('fields') or {}, b.get('fields') or {}
            for key in sorted(set(fieldsA) & set(fieldsB)):
                delta(f'{type_name}.fields.{key}', fieldsA[key], fieldsB[key])
    runtimeA = old.get('runtime') or {}
    runtimeB = new.get('runtime') or {}
    for name in sorted(set(runtimeA) & set(runtimeB)):
        if runtimeA[name] != runtimeB[name]:
            warnings.append(f'Runtime scene-dependent {name}: {runtimeA[name]} -> {runtimeB[name]} (not necessarily a broken API)')
    return changes, sorted(set(warnings))


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip())
        return 2
    try:
        old = json.loads(Path(sys.argv[1]).read_text(encoding='utf8'))
        new = json.loads(Path(sys.argv[2]).read_text(encoding='utf8'))
    except (OSError, ValueError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 2
    changes, warnings = compare(old, new)
    print('Beloved API Probe comparison')
    print(f"BEFORE: probe {old.get('probeVersion')}, TDB {old.get('tdbVersion')}")
    print(f"AFTER : probe {new.get('probeVersion')}, TDB {new.get('tdbVersion')}")
    if changes:
        print('\nPOTENTIAL API / ENVIRONMENT CHANGES:')
        for x in changes: print(' - ' + x)
    else:
        print('\nNo detectable API/environment changes under comparable fields.')
    if warnings:
        print('\nNOTES / NOT VERIFIED:')
        for x in warnings: print(' - ' + x)
    print('\nNo API difference does not guarantee game behavior is unchanged.')
    return 1 if changes else 0


if __name__ == '__main__':
    raise SystemExit(main())
