"""Create and verify OOXML tracked text revisions against preserved DOCX files.

Usage: python tools/make_w5p_redlines.py baseline_directory output_directory
For the local w5p prose-only surgery: structure/equations/styles must match.
Never use this script for inserted/deleted paragraphs or layout rewrites.
"""
from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E
from copy import deepcopy
import sys,io,json,hashlib
from revise_w5p_guidance import NS
ROOT=Path(__file__).resolve().parents[1]
W='{'+NS['w']+'}'
baseline=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
changes=json.loads(Path(__file__).with_name('w5p_guidance_changes.json').read_text(encoding='utf-8'))
def content(root):
    return [E.tostring(n,method='c14n') for n in root.xpath('.//w:body',namespaces=NS)]
def resolve(root,accept):
    root=deepcopy(root)
    for n in list(root.xpath('.//w:ins|.//w:del',namespaces=NS)):
        parent=n.getparent();idx=parent.index(n)
        keep=(n.tag==W+'ins')==accept
        if keep:
            for child in list(n):
                if not accept:
                    for t in child.iter(W+'delText'):t.tag=W+'t'
                parent.insert(idx,child);idx+=1
        parent.remove(n)
    return root
receipt=[]
for rel in changes:
    final=ROOT/rel;prior=baseline/rel
    with ZipFile(final) as z:members=[(i,z.read(i.filename)) for i in z.infolist()]
    with ZipFile(prior) as z:old=E.fromstring(z.read('word/document.xml'))
    new=E.fromstring(dict((i.filename,b) for i,b in members)['word/document.xml'])
    br=old.xpath('.//w:r',namespaces=NS);fr=new.xpath('.//w:r',namespaces=NS)
    if len(br)!=len(fr):raise ValueError(f'{rel}: run structure changed; use Word comparison')
    tracked=deepcopy(new);tr=tracked.xpath('.//w:r',namespaces=NS);count=0
    for original,current,destination in zip(br,fr,tr):
        if E.tostring(original,method='c14n')==E.tostring(current,method='c14n'):continue
        # A run can retain formatting and tabs; equations remain sibling OMML.
        if original.xpath('.//w:drawing|.//w:object',namespaces=NS) or current.xpath('.//w:drawing|.//w:object',namespaces=NS):
            raise ValueError('Drawing-run edit is not a prose revision')
        parent=destination.getparent();idx=parent.index(destination)
        for kind,run in [('del',original),('ins',current)]:
            revision=E.Element(W+kind)
            revision.set(W+'id',str(count*2+(kind=='ins')))
            revision.set(W+'author','Revision')
            revision.set(W+'date','2026-10-28T12:00:00Z')
            r=deepcopy(run)
            if kind=='del':
                for t in r.iter(W+'t'):t.tag=W+'delText'
            revision.append(r);parent.insert(idx,revision);idx+=1
        parent.remove(destination);count+=1
    accepted=resolve(tracked,True);rejected=resolve(tracked,False)
    if content(accepted)!=content(new):raise ValueError(f'{rel}: accepting does not reproduce clean XML')
    if content(rejected)!=content(old):raise ValueError(f'{rel}: rejecting does not reproduce baseline XML')
    dest=out/(final.stem+'_tracked.docx');buf=io.BytesIO()
    with ZipFile(buf,'w') as z:
        for info,data in members:
            z.writestr(info,E.tostring(tracked,xml_declaration=True,encoding='UTF-8',standalone=True) if info.filename=='word/document.xml' else data)
    dest.write_bytes(buf.getvalue())
    receipt.append({'file':rel,'revision_pairs':count,'accept_body_matches_clean':True,'reject_body_matches_baseline':True,
                    'equations':len(new.xpath('.//m:oMath',namespaces=NS)),
                    'baseline_sha256':hashlib.sha256(prior.read_bytes()).hexdigest(),
                    'clean_sha256':hashlib.sha256(final.read_bytes()).hexdigest(),
                    'tracked_sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
(out/'redline_verification.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt,indent=2))
