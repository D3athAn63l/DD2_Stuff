#!/usr/bin/env python3
"""Offline merge/export for v5.2 detail batches. Uses standard Python only.

Examples:
  python merge_detail.py dd2_dumper_v52.zip --base DD2_Items_2152_Merged.json --output DD2_Detail
  python merge_detail.py batch1.json batch2.json batch3.json --output DD2_Detail
  python merge_detail.py ./my-dumps/ --names itemID2NameContainingDLC.json

Never downloads files or overwrites existing output files.
"""
import argparse
import csv
import io
import json
from pathlib import Path
from zipfile import ZipFile
from collections import Counter


def iter_json(sources):
    for raw in sources:
        path=Path(raw)
        if path.is_dir():
            yield from iter_json([str(x) for x in sorted(path.rglob('*.json'))])
        elif path.suffix.lower()=='.zip':
            with ZipFile(path) as z:
                for name in z.namelist():
                    if not name.lower().endswith('.json') or name.endswith('/'):
                        continue
                    try:
                        yield f'{path.name}!{name}',json.loads(z.read(name))
                    except (ValueError,UnicodeDecodeError):
                        pass
        elif path.suffix.lower()=='.json':
            yield str(path),json.loads(path.read_text(encoding='utf-8-sig'))


def load_community_names(path):
    if not path: return {}
    d=json.loads(Path(path).read_text(encoding='utf-8-sig'))
    out={}
    if isinstance(d,dict):
        for k,v in d.items():
            try: key=int(k)
            except (TypeError,ValueError): continue
            if isinstance(v,str): out[key]=v
            elif isinstance(v,dict):
                name=next((v[n] for n in ('name','Name','itemName','ItemName','en','english')
                           if isinstance(v.get(n),str)),None)
                if name:out[key]=name
    elif isinstance(d,list):
        for v in d:
            if not isinstance(v,dict):continue
            key=v.get('id',v.get('ID',v.get('itemID')))
            name=v.get('name',v.get('Name',v.get('itemName')))
            try:key=int(key)
            except (TypeError,ValueError):continue
            if isinstance(name,str):out[key]=name
    return out


def main():
    ap=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument('inputs',nargs='+',help='v5.2 JSON files, folders or ZIPs')
    ap.add_argument('--base',help='previous 2,152-item merged JSON, for coverage and ID validation')
    ap.add_argument('--names',help='optional externally supplied community JSON ID->name mapping')
    ap.add_argument('--output',default='DD2_Detailed_Items',help='output filename prefix (default DD2_Detailed_Items)')
    args=ap.parse_args()
    rows={}; sources=[];run_ids=set();signature=set(); batch_count=0
    duplicates=[]; errors=[]; reported_invalid=0
    for filename,data in iter_json(args.inputs):
        if not isinstance(data,dict) or data.get('kind')!='item-detail-batch':continue
        if data.get('schema')!=2:
            errors.append(f'{filename}: unexpected schema');continue
        batch_count+=1;sources.append(filename);run_ids.add(data.get('runId'))
        reported_invalid+=data.get('invalidSkipped',0) or 0
        tdb=data.get('captured',{}).get('tdbVersion')
        if tdb is not None:signature.add(tdb)
        for row in data.get('rows',[]):
            try:idx=int(row['id'])
            except (ValueError,TypeError,KeyError):
                errors.append(f'{filename}: invalid ID');continue
            if idx in rows:
                if rows[idx]!=row: duplicates.append(idx)
                continue
            rows[idx]=row
    if not rows:raise SystemExit('No v5.2 detailed item rows found.')
    if len(run_ids)>1:raise SystemExit(f'Different runIds detected ({len(run_ids)}). Pass batches from one run only.')
    if len(signature)>1:raise SystemExit('Different TDB versions detected; cannot merge across game updates.')
    if duplicates:raise SystemExit(f'{len(duplicates)} IDs have conflicting values, e.g. {duplicates[:10]}')
    baseline={}
    if args.base:
        d=json.loads(Path(args.base).read_text(encoding='utf-8-sig'))
        baseline={int(r['id']):r for r in d['rows']}
    names=load_community_names(args.names)
    allfields=set()
    for row in rows.values():
        for scope in ('common','specific'):
            allfields.update(scope+'.'+x for x in row.get(scope,{}))
    header=['id','name_from_external_source','valueType','fieldCount',*sorted(allfields)]
    output=Path(args.output)
    files=[output.with_suffix('.json'),output.with_suffix('.csv'),output.with_suffix('.audit.txt')]
    for file in files:
        if file.exists():raise SystemExit(f'Refusing to overwrite existing file: {file}')
    result={'kind':'detailed-item-catalog','itemCount':len(rows),'tdbVersions':sorted(signature),
            'runId':next(iter(run_ids)),'sourceFiles':sources,
            'communityNameSource':args.names or None,
            'namesMatched':sum(i in names for i in rows),
            'rows':[{**rows[i],**({'communityName':names[i]} if i in names else {})} for i in sorted(rows)]}
    files[0].write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    with files[1].open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=header);w.writeheader()
        for idx in sorted(rows):
            row=rows[idx]
            line={'id':idx,'valueType':row.get('valueType',''),
                  'name_from_external_source':names.get(idx,''),'fieldCount':row.get('fieldCount','')}
            for scope in ('common','specific'):
                line.update({scope+'.'+k:v for k,v in row.get(scope,{}).items()})
            w.writerow(line)
    bytype=Counter(r.get('valueType') for r in rows.values())
    missing=sorted(baseline.keys()-rows.keys())
    extra=sorted(rows.keys()-baseline.keys()) if baseline else []
    lines=[f'Detailed rows: {len(rows)}',f'Batches: {batch_count}',f'Run IDs: {len(run_ids)}',
        f'Reported skipped invalid entries: {reported_invalid}',f'Names matched (external source): {sum(i in names for i in rows)}',
        'Types: '+str(dict(sorted(bytype.items()))),
        f'Base catalog rows: {len(baseline)}',f'Missing vs base: {len(missing)}',f'Extra vs base: {len(extra)}',
        'Missing sample IDs: '+str(missing[:30]),'Extra sample IDs: '+str(extra[:30]),
        'Field coverage by type:']
    for typ in sorted(bytype):
        items=[r for r in rows.values() if r.get('valueType')==typ]
        for field in sorted({k for r in items for k in r.get('specific',{})}):
            covered=sum(field in r.get('specific',{}) for r in items)
            lines.append(f'  {typ}.{field}: {covered}/{len(items)}')
    lines+=['Warnings: fields reflect loaded in-game runtime values, not validated upgrade-roll pools.',
            'Weight units and current all-zero weight readings need independent verification.']
    if errors:lines.append('Errors: '+str(errors[:20]))
    files[2].write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('\n'.join(lines[:11]))
    print('Wrote:',', '.join(map(str,files)))

if __name__=='__main__': main()
