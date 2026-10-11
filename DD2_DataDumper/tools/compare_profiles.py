#!/usr/bin/env python3
"""Compare two DD2Dumper *_types_<group>.json captures. Python stdlib only."""
import argparse
import json
from pathlib import Path


def index(doc):
    if doc.get('kind') != 'type-profile':
        raise ValueError('Expected type-profile JSON; pass *_types_<group>.json files')
    return {r['name']: r for r in doc.get('rows', [])}


def sigs(row):
    return {str(m.get('signature', ''))+' -> '+str(m.get('returnType',''))
            for m in row.get('methods', [])}


def fields(row):
    return {str(f.get('name')):(f.get('type'), f.get('isStatic'))
            for f in row.get('fields', [])}


def compare(before, after):
    a, b = index(before), index(after)
    out=[]
    for name in sorted(set(a) | set(b)):
        old, new=a.get(name),b.get(name)
        if old is None or new is None:
            out.append(f'{name}: target added/removed from scraper target list')
            continue
        if old.get('exists') != new.get('exists'):
            out.append(f"{name}: exposed={old.get('exists')} -> {new.get('exists')}")
        if not old.get('exists') or not new.get('exists'):
            continue
        old_methods, new_methods=sigs(old),sigs(new)
        for method in sorted(old_methods - new_methods):
            out.append(f'{name}: METHOD REMOVED/CHANGED {method}')
        for method in sorted(new_methods - old_methods):
            out.append(f'{name}: METHOD ADDED/CHANGED {method}')
        old_fields, new_fields=fields(old),fields(new)
        for field in sorted(set(old_fields) | set(new_fields)):
            if old_fields.get(field) != new_fields.get(field):
                out.append(f'{name}: FIELD {field}: {old_fields.get(field)} -> {new_fields.get(field)}')
        if old.get('methodError') != new.get('methodError'):
            out.append(f"{name}: method enumeration diagnostic changed")
        if old.get('fieldError') != new.get('fieldError'):
            out.append(f"{name}: field enumeration diagnostic changed")
    return out


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('before',type=Path)
    ap.add_argument('after',type=Path)
    args=ap.parse_args()
    changes=compare(json.loads(args.before.read_text(encoding='utf-8')),
                    json.loads(args.after.read_text(encoding='utf-8')))
    if changes:
        print('\n'.join(changes))
        print(f'\n{len(changes)} observable difference(s).')
    else:
        print('No observable type/method/field changes in these two snapshots.')
    print('Reminder: unchanged reflection does not prove unchanged gameplay behavior.')

if __name__=='__main__': main()
