"""Refresh existing Word TOC page numbers from the corresponding PDF outline.
Usage: python tools/refresh_guidance_toc.py document.docx rendered.pdf
Does not alter headings, formulas or layout; render again afterward.
"""
from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E
from pypdf import PdfReader
import sys,re,io
from revise_w5p_guidance import NS
doc=Path(sys.argv[1]);pdf=PdfReader(sys.argv[2]);pages={}
norm=lambda s:re.sub(r'[^a-z0-9]','',s.lower())
def visit(items):
    for item in items:
        if isinstance(item,list):visit(item)
        else:pages[norm(item.title)]=pdf.get_destination_page_number(item)+1
visit(pdf.outline)
with ZipFile(doc) as z:members=[(i,z.read(i.filename)) for i in z.infolist()]
root=E.fromstring(dict((i.filename,b) for i,b in members)['word/document.xml'])
changed=0;missing=[]
for p in root.xpath('.//w:p',namespaces=NS):
    styles=p.xpath('./w:pPr/w:pStyle/@w:val',namespaces=NS)
    if not styles or not styles[0].startswith('TOC'):continue
    ts=p.xpath('.//w:t',namespaces=NS)
    if not ts or not (ts[-1].text or '').isdigit():continue
    title=''.join(t.text or '' for t in ts[:-1]);page=pages.get(norm(title))
    if page is None:missing.append(title);continue
    if ts[-1].text!=str(page):ts[-1].text=str(page);changed+=1
if missing:raise ValueError('Unmatched TOC headings: '+repr(missing))
if changed:
    buf=io.BytesIO()
    with ZipFile(buf,'w') as z:
        for i,b in members:z.writestr(i,E.tostring(root,xml_declaration=True,encoding='UTF-8',standalone=True) if i.filename=='word/document.xml' else b)
    doc.write_bytes(buf.getvalue())
print(f'Updated {changed} TOC page references')
