"""Apply reviewed prose corrections without rebuilding the existing Word files.

Run with bundled Python from any directory. The adjacent JSON records exact
old/new phrases and stable section locators. Existing equations, drawings,
styles, relationships and non-document XML parts are preserved. Re-running
an applied correction is a no-op. A missing or ambiguous phrase stops the run.
Snapshot the documents before first use; render and verify after applying.
"""
from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E
import json, io, argparse

ROOT=Path(__file__).resolve().parents[1]
NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'm':'http://schemas.openxmlformats.org/officeDocument/2006/math'}

def replace_in_paragraph(p, old, new):
    nodes=p.xpath('.//w:t',namespaces=NS)
    text=''.join(n.text or '' for n in nodes)
    start=text.find(old)
    if start<0:return False
    end=start+len(old);offset=0;inserted=False
    for n in nodes:
        value=n.text or '';nend=offset+len(value)
        if nend>start and offset<end:
            left=value[:max(0,start-offset)]
            right=value[max(0,end-offset):] if nend>end else ''
            n.text=left+(new if not inserted else '')+right
            n.set('{http://www.w3.org/XML/1998/namespace}space','preserve')
            inserted=True
        offset=nend
    return True

def apply(path, changes, dry=False):
    with ZipFile(path) as z: members=[(i,z.read(i.filename)) for i in z.infolist()]
    xml=dict((i.filename,b) for i,b in members)['word/document.xml']
    root=E.fromstring(xml)
    before=[E.tostring(n,method='c14n') for n in root.xpath('.//m:oMath',namespaces=NS)]
    paragraphs=root.xpath('.//w:p',namespaces=NS)
    applied=[]
    for c in changes:
        texts=[''.join(p.xpath('.//w:t/text()',namespaces=NS)) for p in paragraphs]
        matches=[p for p,t in zip(paragraphs,texts) if c['old'] in t and c['new'] not in t]
        # A later, explicitly recorded follow-up can supersede this wording.
        # Keep the cumulative original-to-final recipe replayable and idempotent.
        final_phrases=[c['new']]+c.get('already_applied',[])
        if not matches and sum(any(s in t for s in final_phrases) for t in texts)>=c.get('count',1):continue
        if len(matches)!=c.get('count',1):
            raise ValueError(f"{path.name}: {c['locator']}: expected {c.get('count',1)} matches, found {len(matches)}")
        for p in matches:
            replace_in_paragraph(p,c['old'],c['new'])
            # Full-paragraph rewrites may retain an emphasized lead-in in a
            # different run from the regular body. Preserve those run styles.
            if 'new_text_nodes' in c:
                nodes=p.xpath('.//w:t',namespaces=NS)
                values=c['new_text_nodes']
                if len(values)>len(nodes) or ''.join(values)!=c['new']:
                    raise ValueError('Invalid explicit text-node mapping')
                for idx,node in enumerate(nodes):
                    node.text=values[idx] if idx<len(values) else ''
                    node.set('{http://www.w3.org/XML/1998/namespace}space','preserve')
        applied.append(c['locator'])
    after=[E.tostring(n,method='c14n') for n in root.xpath('.//m:oMath',namespaces=NS)]
    if before!=after:raise ValueError('Equation structure changed')
    if applied and not dry:
        buf=io.BytesIO()
        with ZipFile(buf,'w') as z:
            for i,b in members:
                z.writestr(i,E.tostring(root,xml_declaration=True,encoding='UTF-8',standalone=True) if i.filename=='word/document.xml' else b)
        path.write_bytes(buf.getvalue())
    return {'file':path.relative_to(ROOT).as_posix(),'changes':applied,'equations_preserved':len(before),'dry_run':dry}

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--dry-run',action='store_true');args=ap.parse_args()
    changes=json.loads(Path(__file__).with_name('w5p_guidance_changes.json').read_text(encoding='utf-8'))
    print(json.dumps([apply(ROOT/f,c,args.dry_run) for f,c in changes.items()],ensure_ascii=False,indent=2))
