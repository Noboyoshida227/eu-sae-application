"""Verify catalogue, language folders and portable local documentation links."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit
import csv,json,re,sys

ROOT=Path(__file__).resolve().parents[1]
class Links(HTMLParser):
    def __init__(self):super().__init__();self.links=[];self.ids=set();self.remote_assets=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if 'id' in a:self.ids.add(a['id'])
        if tag=='a' and 'href' in a:self.links.append(a['href'])
        if tag in ['script','link','img']:
            value=a.get('src',a.get('href',''))
            if value.startswith(('http:','https:','//')):self.remote_assets.append(value)

def main():
    inv=[r['path'] for r in csv.DictReader((ROOT/'scripts/release_inventory.csv').open(encoding='utf-8-sig'))]
    d=json.loads((ROOT/'docs/maintenance/navigation.json').read_text(encoding='utf-8'))
    errors=[];count=0;cache={}
    def require(ok,msg):
        if not ok:errors.append(msg)
    require(len({r['id'] for r in d['items']})==len(d['items']),'duplicate catalogue IDs')
    for r in d['items']:
        for p in [r['path'],r.get('editable')]:
            if p:require(p in inv and (ROOT/p).is_file(),'catalogue file missing from inventory: '+p)
        if r['path'].endswith('.md'):require(r['path'][:-3]+'.html' in inv,'catalogue HTML absent: '+r['path'])
    for lang in ['English','Polish','Greek']:
        guides=list((ROOT/'docs/instructions'/lang).glob('EU_SAE_Workbench_Guide_*.pdf'))
        require(len(guides)==3,f'{lang}: expected three reading guides')
        for p in guides:require(p.with_suffix('.pptx').exists(),'editable guide missing: '+p.name)
    require(not list((ROOT/'docs/instructions').glob('*.pdf')),'instructions PDFs must be in language folders')
    require(not list((ROOT/'docs').glob('*.md')),'top-level docs Markdown has not been categorized')
    for rel in inv:
        p=ROOT/rel
        if p.suffix not in ['.html','.md']:continue
        text=p.read_text(encoding='utf-8-sig')
        if p.suffix=='.html':
            parser=Links();parser.feed(text);cache[p.resolve()]=parser
            links=parser.links
            if rel in ['Start_Here/START_HERE.html','docs/INDEX.html']:require(not parser.remote_assets,'offline entry page has remote assets: '+rel)
        else:links=re.findall(r'\]\(([^)]+)\)',text)
        for link in links:
            u=urlsplit(link)
            if u.scheme or u.netloc:continue
            if not u.path and p.suffix=='.md':continue
            target=(p.parent/unquote(u.path)).resolve() if u.path else p.resolve()
            require(target.is_relative_to(ROOT),'link leaves package: '+rel+' -> '+link)
            if rel.startswith('docs/') and p.suffix=='.html':
                require(target.is_relative_to(ROOT/'docs'),'HTML link leaves the app documentation mount: '+rel+' -> '+link)
            if not target.is_relative_to(ROOT):continue
            trel=target.relative_to(ROOT).as_posix()
            require(target.exists(),'broken link: '+rel+' -> '+link)
            if target.is_file():require(trel in inv,'link target not packaged: '+rel+' -> '+link)
            if target.suffix=='.html' and u.fragment and target.exists():
                if target not in cache:
                    q=Links();q.feed(target.read_text(encoding='utf-8'));cache[target]=q
                require(unquote(u.fragment) in cache[target].ids,'missing anchor: '+rel+' -> '+link)
            count+=1
    if errors:
        print('\n'.join(errors));raise SystemExit(f'{len(errors)} navigation error(s)')
    print(f'PASS: {len(d["items"])} catalogue entries; nine guide pairs; {count} local links; offline entry pages.')

if __name__=='__main__':main()
