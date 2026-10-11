#!/usr/bin/env python3
"""Merge v5.0 item JSON + v5.1 batch JSON (files, directories or ZIPs).

No external dependencies. Duplicate IDs are detected rather than silently summed.
Usage: python tools/merge_items.py dd2_dumper1.zip new_batch.json -o DD2_items_merged.json
"""
import argparse
import json
import zipfile
from pathlib import Path


def entries(paths):
    for src in paths:
        p = Path(src)
        if p.is_dir():
            for child in sorted(p.rglob('*.json')):
                yield from entries([str(child)])
        elif p.suffix.lower() == '.zip':
            with zipfile.ZipFile(p) as z:
                for name in sorted(z.namelist()):
                    if name.lower().endswith('.json'):
                        yield f'{p.name}:{name}', z.read(name)
        elif p.suffix.lower() == '.json':
            yield str(p), p.read_bytes()
        else:
            raise ValueError(f'Unsupported input: {p}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs', nargs='+', help='JSON files, ZIP archives, or folders')
    parser.add_argument('-o', '--output', default='DD2_items_merged.json')
    opts = parser.parse_args()
    rows_by_id = {}
    provenance = []
    collisions = []
    for src, blob in entries(opts.inputs):
        try:
            data = json.loads(blob)
        except Exception as exc:
            print(f'WARNING: invalid JSON {src}: {exc}')
            continue
        if data.get('kind') not in ('item-catalog-best-effort', 'item-catalog-batch'):
            continue
        rows = data.get('rows', [])
        if not isinstance(rows, list):
            print(f'WARNING: invalid rows in {src}')
            continue
        accepted = 0
        for r in rows:
            key = r.get('id', r.get('_Id'))
            if not isinstance(key, int):
                print(f'WARNING: item with invalid ID in {src}')
                continue
            if key in rows_by_id:
                left = dict(rows_by_id[key]); right = dict(r)
                for k in ('index', 'batchIndex'): left.pop(k, None); right.pop(k, None)
                if left != right:
                    collisions.append({'id': key, 'secondSource': src})
                continue
            rows_by_id[key] = r
            accepted += 1
        provenance.append({'source': src, 'recordsInFile': len(rows), 'newIds': accepted})
    result = {
        'kind': 'merged-item-catalog', 'uniqueItemCount': len(rows_by_id),
        'conflictingDuplicateCount': len(collisions), 'conflicts': collisions[:200],
        'sources': provenance, 'rows': [rows_by_id[k] for k in sorted(rows_by_id)],
    }
    out = Path(opts.output)
    if out.exists():
        raise SystemExit(f'Refusing to overwrite {out}; choose a new -o path')
    out.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f'Saved {len(rows_by_id)} unique item IDs to {out}; {len(collisions)} differing duplicate rows')
    for src in provenance:
        print(f"  {src['newIds']} new / {src['recordsInFile']} records: {src['source']}")


if __name__ == '__main__':
    main()
