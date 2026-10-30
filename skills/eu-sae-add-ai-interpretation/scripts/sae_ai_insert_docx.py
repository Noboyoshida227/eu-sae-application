import json, re, sys, docx
import io, zipfile
from insertion_checks import validate, guard_docx
LABELS = {"overview": "Overview", "normality": "Normality Diagnostics", "rates": "Poverty Rate Comparisons",
          "precision": "MSE, RMSE, and CV Comparisons", "change_significance": "Statistical Significance of Poverty Changes",
          "poverty_maps": "Poverty Maps", "change_maps": "Poverty Change Maps", "recommendation": "AI Recommendation: UFH or MFH"}
STATUS = "AI interpretations were not requested or were intentionally excluded from this report."
src, spec_path, out = sys.argv[1:4]
spec = json.load(open(spec_path, encoding="utf-8")); meta, qa, why = spec.get("meta", {}), spec.get("numeric_qa", {}), spec.get("reasons", {})
validate(src, out, spec)
LABELS.update(spec.get("labels", {}))
d = docx.Document(src); guard_docx(d); P = d.paragraphs
style = "Body Text" if "Body Text" in [s.name for s in d.styles] else "Normal"
htext = lambda p: re.sub(r"^[\d.]+\s+", "", p.text.strip())
def find(pat, start=0):
    for i in range(start, len(P)):
        if P[i].style.name.startswith("Heading") and re.search(pat, htext(P[i])): return i
    raise SystemExit(f"anchor not found: {pat}")
def nxt(i, lvl=None):
    for k in range(i+1, len(P)):
        s = P[k].style.name
        if s.startswith("Heading") and (lvl is None or int(s.split()[-1]) <= lvl): return k
    raise SystemExit("no following heading")
def par(text, st=None, bold=False, italic=False):
    p = d.add_paragraph(style=st or style); r = p.add_run(text)
    if bold: r.bold = True          # leave the style's own weight alone otherwise (headings stay bold)
    if italic: r.italic = True
    e = p._p; e.getparent().remove(e); return e
def block(k):
    t = spec.get(k); els = [par(f"{LABELS[k]} | {'Generated' if t else 'Not generated'}", bold=True)]
    els += [par(x.strip()) for x in re.split(r"\n\s*\n", t.strip()) if x.strip()] if t else \
           [par("Interpretation not generated: " + why.get(k, "the inputs for this section were not available."), italic=True)]
    return els + [par(f"Provider: {meta.get('provider', 'not recorded')} (added after the run) | Model: {meta.get('model', 'not recorded')} | Generated: "
                      f"{meta.get('generated_utc', 'not recorded')} | Language: {meta.get('language', 'English')} | Numeric QA: "
                      f"{qa.get(k, 'not_applicable')} (checked against {meta.get('sources', 'the report')}) | Human review: not recorded")]
srcs = meta.get("sources", "the final report")
note = par(f"These AI interpretations were added after the run, from {srcs}. The workbench run itself did not generate "
           "them, so the Run Setup table still records AI as not included. The statistical tables, figures and estimates are unchanged.", italic=True)
comp = find(r"^Comparison of UFH and MFH$")
status = next((i for i in range(comp, len(P)) if re.sub(r"\s+", " ", P[i].text).strip() == STATUS), None)
rate = find(r"^Rate, MSE, RMSE, and CV Comparisons$"); ci = find(r"^Distribution of 95% confidence-interval widths$")
sig_at = nxt(ci)   # workbench puts this block after the Excel links, before the "Change maps use..." note
sig_at = next((k for k in range(ci+1, sig_at) if P[k].text.strip().startswith("Change maps")), sig_at)
sess = find(r"^Session Information$"); m = re.match(r"^(\d+)\s", P[sess].text.strip()); n = None  # Preserve original section numbers and cross-references.
rec = [par(f"{n} AI Recommendation: UFH or MFH" if n else "AI Recommendation: UFH or MFH", st="Heading 1"),
       par("This is advisory interpretation for analyst review, not automatic model selection or official statistical "
           "approval. The numerical results remain unchanged.")]
before = [(P[rate]._p, block("normality")), (P[nxt(rate, 2)]._p, block("rates") + block("precision")),
          (P[find(r"^RMSE Maps$")]._p, block("poverty_maps")), (P[sig_at]._p, block("change_significance")),
          (P[sess]._p, block("change_maps") + rec + block("recommendation"))]
for anchor, els in before:
    for e in els: anchor.addprevious(e)
ref = P[status]._p if status is not None else P[comp+1]._p
for e in [note] + block("overview"): ref.addnext(e); ref = e
if status is not None: P[status]._p.getparent().remove(P[status]._p)
if n:
    for r in P[sess].runs:
        if r.text.strip().startswith(str(n)): r.text = r.text.replace(str(n), str(n+1), 1); break
# Preserve every original package member except the modified main document.
buffer = io.BytesIO()
d.save(buffer)
with zipfile.ZipFile(buffer) as updated, zipfile.ZipFile(src) as original, zipfile.ZipFile(out, "w") as target:
    for item in original.infolist():
        target.writestr(item, updated.read("word/document.xml") if item.filename == "word/document.xml" else original.read(item.filename))
print("saved", out)
