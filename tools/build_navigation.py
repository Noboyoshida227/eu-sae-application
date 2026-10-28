"""Build offline navigation and its printable guide from navigation.json.

Run from any directory: python tools/build_navigation.py [--pandoc PATH]
Requires reportlab and Pandoc for authoring only, not for opening the HTML.
"""
from pathlib import Path
import argparse, csv, html, json, os, posixpath, re, shutil, subprocess
from urllib.parse import quote, unquote

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/maintenance/navigation.json'
CSS = '''
:root{--ink:#182d40;--muted:#526476;--teal:#006b70;--line:#d8e2e8;--wash:#f1f6f8}
*{box-sizing:border-box}body{margin:0;background:#fff;color:var(--ink);font:17px/1.6 system-ui,-apple-system,"Segoe UI",sans-serif}
header{background:var(--ink);color:white;padding:42px max(24px,calc((100vw - 1080px)/2)) 34px}
header p{max-width:820px;margin:9px 0}header .eyebrow{font-size:13px;letter-spacing:.1em;text-transform:uppercase;color:#b7dadd}
h1{font-size:38px;line-height:1.2;margin:10px 0}h2{font-size:27px;line-height:1.3;margin:42px 0 16px}h3{font-size:21px;margin:20px 0 8px}
main{max-width:1128px;margin:auto;padding:0 24px 48px}nav{display:flex;flex-wrap:wrap;gap:10px 22px;padding:19px 0;border-bottom:1px solid var(--line)}
a{color:var(--teal);text-underline-offset:3px}a:hover{text-decoration-thickness:2px}a:focus-visible{outline:3px solid #ecb900;outline-offset:3px}
.intro{font-size:20px}.note{background:var(--wash);border-left:4px solid var(--teal);padding:16px 20px;margin:20px 0}
.steps{display:grid;grid-template-columns:1fr 1fr;gap:8px 34px}.step{border-top:2px solid var(--line)}
table{border-collapse:collapse;width:100%;margin:14px 0 24px}th,td{text-align:left;vertical-align:top;padding:13px 12px;border-bottom:1px solid var(--line)}th{background:var(--wash);font-size:15px}
td:first-child{width:33%}code{font:14px/1.5 Consolas,monospace;overflow-wrap:anywhere;background:var(--wash);padding:2px 4px}p{margin:8px 0 14px}
.meta{font-size:14px;color:var(--muted)}.format{display:inline-block;margin:4px 14px 0 0;font-size:15px}.language{font-weight:600;font-size:19px}.catalogue-item{padding:18px 0;border-bottom:1px solid var(--line)}
.catalogue-item h3{margin:0;font-size:20px}.catalogue-item p{margin:6px 0}.badge{font-size:12px;padding:2px 7px;border:1px solid var(--line);border-radius:3px;margin-left:7px}
details{margin:22px 0;padding:15px 20px;background:var(--wash)}summary{cursor:pointer;font-size:19px;font-weight:600}footer{border-top:1px solid var(--line);padding-top:22px;margin-top:34px;font-size:14px;color:var(--muted)}
@media(max-width:700px){h1{font-size:30px}.steps{grid-template-columns:1fr}th,td{padding:10px 6px}td:first-child{width:38%}body{font-size:16px}}
@media print{header{padding:10px 0;background:white;color:black}nav{display:none}main{padding:0}a{color:black}h2,h3{break-after:avoid}.catalogue-item,tr{break-inside:avoid}.steps{display:block}}
'''
E = html.escape

def href(path, output):
    return quote(posixpath.relpath(path, posixpath.dirname(output) or '.'), safe='/._-#')

def shell(title, body, version):
    return f'<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{E(title)}</title><style>{CSS}</style></head><body>{body}</body></html>\n'

def render_guide(d, output, catalogue=False):
    title='Documentation catalogue' if catalogue else 'Start here'
    version=(ROOT/'WIZARD_VERSION').read_text().strip()
    sections=['start','guides','results','folders']+(['guidance','validation','maintenance'] if catalogue else [])
    labels=['Start','Guides by language','Find results','Folder map']+(['Methods','Validation','Maintainers'] if catalogue else [])
    body=f'<header><p class="eyebrow">{E(d["title"])} · {E(version)}</p><h1>{title}</h1><p>{E(d["subtitle"])}</p></header><main><nav aria-label="On this page">'
    body+=''.join(f'<a href="#{id}">{label}</a>' for id,label in zip(sections,labels))+'</nav>'
    body+=f'<section id="start"><h2>Start an analysis</h2><p class="intro">{E(d["introduction"])}</p><div class="steps">'
    for i,s in enumerate(d['steps'],1):body+=f'<div class="step"><h3>{i}. {E(s["title"])}</h3><p>{E(s["text"])}</p></div>'
    body+='</div><table><thead><tr><th>Computer</th><th>Guided launcher</th><th>How to open it</th></tr></thead><tbody>'
    for r in d['launchers']:body+=f'<tr><td>{E(r["os"])}</td><td><code>{E(r["command"])}</code></td><td>{E(r["action"])}</td></tr>'
    body+='</tbody></table><p class="meta">The classic dashboard has the same settings; its Start_Dashboard launchers are beside the guided launchers.</p></section>'
    body+='<section id="guides"><h2>Read the guides in your language</h2><p>Read the PDFs. The PowerPoint copies contain the same guide in editable form.</p>'
    body+='<nav aria-label="Guide languages">'+''.join(f'<a href="#lang-{lang.lower()}">{label}</a>' for lang,label in [('English','English'),('Polish','Polski'),('Greek','Ελληνικά')])+'</nav>'
    for lang in ['English','Polish','Greek']:
        body+=f'<h3 id="lang-{lang.lower()}">{lang}</h3><table><thead><tr><th>Guide</th><th>Purpose</th><th>Formats</th></tr></thead><tbody>'
        for r in d['items']:
            if r['id'].startswith('guide') and r['id']!='guidelines' and r['language']==lang:
                body+=f'<tr><td>{E(r["title"])}</td><td>{E(r["purpose"])}</td><td><a href="{href(r["path"],output)}">PDF</a> · <a href="{href(r["editable"],output)}">PowerPoint</a></td></tr>'
        body+='</tbody></table>'
    body+=f'<p>Additional references are currently in English. <a href="{href("docs/instructions/English/QUICK_START.pdf",output)}">Print the two-page quick start</a>.</p></section>'
    body+='<section id="results"><h2>Find your results</h2>'+f'<p class="note">{E(d["result_notice"])}</p><table><thead><tr><th>What you need</th><th>Location and use</th></tr></thead><tbody>'
    for r in d['results']:body+=f'<tr><td>{E(r["title"])}</td><td><code>{E(r["path"])}</code><br>{E(r["description"])}</td></tr>'
    body+='</tbody></table><p>Use the application’s <strong>Open the report</strong>, <strong>Open the output folder</strong> and <strong>Open the run folder</strong> controls. The guide lists locations rather than linking to reports that do not exist before your first run.</p></section>'
    body+='<section id="folders"><h2>Understand the folders</h2><table><thead><tr><th>Folder</th><th>Purpose</th></tr></thead><tbody>'
    for r in d['folders']:body+=f'<tr><td><code>{E(r["path"])}</code></td><td>{E(r["purpose"])}</td></tr>'
    body+='</tbody></table></section>'
    if catalogue:
        for group in d['groups']:
            gid=group['id'];body+=f'<section id="{gid}"><h2>{E(group["title"])}</h2><p>{E(group["description"])}</p>'
            if gid=='maintenance':body+='<details><summary>Show maintenance documents</summary>'
            for r in d['items']:
                if r['group']!=gid or (r['id'].startswith('guide') and r['id']!='guidelines'):continue
                primary=r['path'];web=primary[:-3]+'.html' if primary.endswith('.md') else primary
                body+=f'<article class="catalogue-item"><h3>{E(r["title"])}<span class="badge">{E(r["status"])}</span></h3><p>{E(r["purpose"])}</p><p class="meta">For {E(r["audience"].lower())} · {E(r["language"])}</p><a class="format" href="{href(web,output)}">Read {"HTML" if web.endswith(".html") else Path(web).suffix[1:].upper()}</a>'
                if r['editable']:body+=f'<a class="format" href="{href(r["editable"],output)}">Editable {Path(r["editable"]).suffix[1:].upper()}</a>'
                if primary.endswith('.md'):body+=f'<a class="format" href="{href(primary,output)}">Markdown source</a>'
                body+='</article>'
            if gid=='maintenance':body+='</details>'
            body+='</section>'
    else:
        body+=f'<section><h2>Methods, validation and more help</h2><p><a href="{href("docs/INDEX.html",output)}">Open the full documentation catalogue</a> for the guidelines, deviations from Molina and Romero, validation evidence, AI guidance and maintenance records.</p></section>'
    body+=f'<section><h2>If something goes wrong</h2><p>{E(d["troubleshooting"])}</p></section><footer>Local review candidate. The responsible statistical office decides whether findings are suitable for official publication. All paths are relative to the extracted package. This page requires no internet connection.</footer></main>'
    return shell(title+' | '+d['title'],body,version)

def build_pdf(d):
    from reportlab.lib import colors
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak,KeepTogether
    out=ROOT/'docs/instructions/English/QUICK_START.pdf'
    styles=getSampleStyleSheet()
    styles.add(ParagraphStyle(name='Text',fontName='Helvetica',fontSize=9.3,leading=13,spaceAfter=7,textColor=colors.HexColor('#182d40')))
    styles.add(ParagraphStyle(name='Head',fontName='Helvetica-Bold',fontSize=14,leading=18,spaceBefore=11,spaceAfter=7,textColor=colors.HexColor('#006b70')))
    styles.add(ParagraphStyle(name='SmallText',parent=styles['Text'],fontSize=8.2,leading=11))
    para=lambda t,style='Text':Paragraph(E(t),styles[style])
    def table(rows,widths):
        t=Table([[para(a,'SmallText'),para(b,'SmallText')] for a,b in rows],colWidths=widths,hAlign='LEFT')
        t.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,-1),.4,colors.HexColor('#d8e2e8')),('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]));return t
    story=[Paragraph('EU SAE Workbench',styles['Title']),para('Quick start and folder map'),para('Open START_HERE.html in the package for clickable guides and the full documentation catalogue.','SmallText')]
    for i,s in enumerate(d['steps'][:3],1):story.append(KeepTogether([para(f'{i}. {s["title"]}','Head'),para(s['text'])]))
    story.append(table([(r['os'],r['command']) for r in d['launchers']],[30*mm,144*mm]))
    story += [para('Read Guides 1, 2 and 3','Head'),para('Open docs/instructions/English/, Polish/ or Greek/. Each language has the three guides as PDF and editable PowerPoint. The PDFs are the reading copies. Additional references are currently in English.'),para('Find current and saved results','Head'),para(d['result_notice'])]
    story.append(PageBreak())
    story += [para('Review and retain your results','Head'),para(d['steps'][3]['text']),table([(r['title'],r['path']+' - '+r['description']) for r in d['results']],[43*mm,131*mm]),para('Folder map','Head'),table([(r['path'],r['purpose']) for r in d['folders']],[66*mm,108*mm]),para('Help','Head'),para(d['troubleshooting'],'SmallText')]
    def page(c,doc):
        c.setFont('Helvetica',8);c.setFillColor(colors.HexColor('#526476'));c.drawString(18*mm,12*mm,'EU SAE Workbench | '+(ROOT/'WIZARD_VERSION').read_text().strip());c.drawRightString(192*mm,12*mm,str(doc.page))
    SimpleDocTemplate(str(out),pagesize=A4,rightMargin=18*mm,leftMargin=18*mm,topMargin=16*mm,bottomMargin=19*mm,title='EU SAE Workbench Quick start',author='EU SAE Workbench').build(story,onFirstPage=page,onLaterPages=page)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--pandoc');ap.add_argument('--html-only',action='store_true');a=ap.parse_args()
    pandoc=a.pandoc or shutil.which('pandoc')
    if not pandoc and os.environ.get('RSTUDIO_PANDOC'):pandoc=str(Path(os.environ['RSTUDIO_PANDOC'])/('pandoc.exe' if os.name=='nt' else 'pandoc'))
    if not pandoc or not Path(pandoc).is_file():raise SystemExit('Supply --pandoc or RSTUDIO_PANDOC; no download is attempted.')
    d=json.loads(SOURCE.read_text(encoding='utf-8'))
    mdpaths=[p for p in (ROOT/'docs').rglob('*.md') if '/reviews/' not in p.as_posix() and '/literature/' not in p.as_posix()]
    for p in mdpaths:
        text=p.read_text(encoding='utf-8-sig')
        def web_link(m):
            label,t=m[1],m[2];path,sep,frag=t.partition('#')
            if re.match(r'\w+:|/|#',t):return m[0]
            target=(p.parent/unquote(path)).resolve()
            # The application serves docs only. Keep code/data references useful
            # as package-relative paths without producing broken HTTP links or
            # exposing the package root (which may contain private user data).
            if target.is_relative_to(ROOT) and not target.is_relative_to(ROOT/'docs'):
                rel=target.relative_to(ROOT).as_posix()
                return f'{label} (`{rel}` in the extracted package)'
            if target in mdpaths:path=path[:-3]+'.html'
            return '['+label+']('+path+(sep+frag if sep else '')+')'
        text=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',web_link,text)
        fragment=subprocess.run([pandoc,'--from=gfm','--to=html5','--mathml','--wrap=none'],input=text,text=True,encoding='utf-8',capture_output=True,check=True).stdout
        target=p.with_suffix('.html');rel=target.relative_to(ROOT).as_posix()
        nav=f'<main><nav><a href="{href("docs/INDEX.html",rel)}">Documentation catalogue</a></nav>'
        target.write_text(shell(p.stem,nav+fragment+'</main>',''),encoding='utf-8')
    for rel,cat in [('START_HERE.html',False),('docs/INDEX.html',True)]:
        (ROOT/rel).write_text(render_guide(d,rel,cat),encoding='utf-8')
    readme='# EU SAE Workbench\n\n**Start with [START_HERE.html](START_HERE.html)**. Double-click that file in the extracted package to open the offline guide. It explains startup, the language-specific instructions, results and folder purposes.\n\n- [Documentation catalogue](docs/INDEX.html)\n- [Printable quick start](docs/instructions/English/QUICK_START.pdf)\n- [Launcher troubleshooting](Start_Here/README.md)\n- [Technical package reference](docs/maintenance/PACKAGE_REFERENCE.md)\n\n'+f'Current candidate: `{(ROOT/"WIZARD_VERSION").read_text().strip()}` / `{(ROOT/"RELEASE_NAME").read_text().strip()}`. This is a local review candidate. Read the [validation receipt](docs/validation/W5P_VALIDATION_RECEIPT.md) and [methodological qualifications](docs/guidance/MOLINA_ROMERO_DEVIATIONS_w5p.md) before using results.\n\n'+'`outputs/` holds the current working results and is reused by later runs. `app_runs/` holds archived run folders. Save a separate copy of editable reports before changing them.\n\nLicensing and provenance: [LICENSE](LICENSE), [NOTICE](NOTICE), [third-party notices](THIRD_PARTY_NOTICES.md). This is an independent project maintained by Nobuo Yoshida. Official-statistics publication decisions belong to the responsible national statistical office.\n'
    (ROOT/'README.md').write_text(readme,encoding='utf-8')
    if not a.html_only:build_pdf(d)
    print('Built offline starting page, documentation catalogue, readable references and quick start.')

if __name__=='__main__':main()
