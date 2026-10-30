import html, json, re, sys
from insertion_checks import validate, guard_html
from bs4 import BeautifulSoup
LABELS = {"overview": "Overview", "normality": "Normality Diagnostics", "rates": "Poverty Rate Comparisons",
          "precision": "MSE, RMSE, and CV Comparisons", "change_significance": "Statistical Significance of Poverty Changes",
          "poverty_maps": "Poverty Maps", "change_maps": "Poverty Change Maps", "recommendation": "AI Recommendation: UFH or MFH"}
STATUS = "AI interpretations were not requested or were intentionally excluded from this report."
AI_CSS = (".ai-assurance-banner{background:#fff4ce;border-left:6px solid #a15c00;padding:16px 18px;margin:18px 0 24px 0;line-height:1.5;}"
          ".ai-status-box{background:#eef3f8;border-left:5px solid #486581;padding:14px 16px;margin:16px 0;}"
          ".ai-interpretation-block{background:#f5f9fc;border:1px solid #c9d7e3;border-left:5px solid #486581;border-radius:3px;padding:16px 18px;margin:18px 0 24px 0;}"
          ".ai-interpretation-block.ai-failed{background:#fff5f5;border-left-color:#b42318;}"
          ".ai-interpretation-block.ai-disabled{background:#f4f4f4;border-left-color:#777;}"
          ".ai-block-title{font-size:1.2em;font-weight:700;margin-bottom:10px;}"
          ".ai-section-status{float:right;font-size:.72em;font-weight:600;text-transform:uppercase;letter-spacing:.04em;color:#52606d;}"
          ".ai-block-footer{border-top:1px solid #d9e2ec;margin-top:14px;padding-top:8px;font-size:.82em;color:#52606d;}")

src, spec_path, out = sys.argv[1:4]
text = open(src, encoding="utf-8", newline="").read()
spec = json.load(open(spec_path, encoding="utf-8"))
validate(src, out, spec)
meta, qa, why = spec.get("meta", {}), spec.get("numeric_qa", {}), spec.get("reasons", {})
LABELS.update(spec.get("labels", {}))
soup = BeautifulSoup(text, "html.parser")
guard_html(soup)

line_start = [0] + [m.end() for m in re.finditer("\n", text)]
def pos(tag):
    """Absolute offset of the tag's '<' in the original text."""
    p = line_start[tag.sourceline - 1] + tag.sourcepos
    assert text.startswith("<" + tag.name, p), f"position check failed for <{tag.name}>"
    return p
def sect(sid):
    t = soup.find("div", id=sid)
    if t is None: raise SystemExit(f"anchor not found: div#{sid}")
    return t
def close_of(tag):
    """Offset of the closing </div> of a section div: the last '</div>' before its next element sibling."""
    nxt = tag.find_next_sibling(True)
    if nxt is None: raise SystemExit(f"no element after #{tag.get('id')}")
    p = text.rfind("</div>", pos(tag), pos(nxt))
    assert p > 0 and text[p + 6:pos(nxt)].strip() == "", f"cannot locate closing tag of #{tag.get('id')}"
    return p
def htext(h): return re.sub(r"^[\d.]+\s+", "", re.sub(r"\s+", " ", h.get_text(" ", strip=True)))

def block(k):
    t = (spec.get(k) or "").strip()
    cls = "ai-generated" if t else "ai-disabled"
    status = "Generated" if t else "Not generated"
    body = ([f"<p>{html.escape(x.strip())}</p>" for x in re.split(r"\n\s*\n", t) if x.strip()] if t else
            [f"<p><em>Interpretation not generated: {html.escape(why.get(k, 'the inputs for this section were not available.'))}</em></p>"])
    footer = (f"Provider: {meta.get('provider', 'not recorded')} (added after the run) | Model: {meta.get('model', 'not recorded')} | Generated: "
              f"{meta.get('generated_utc', 'not recorded')} | Language: {meta.get('language', 'English')} | Numeric QA: "
              f"{qa.get(k, 'not_applicable')} (checked against {meta.get('sources', 'the report')}) | Human review: not recorded")
    return (f'\n<section id="ai-{k}" class="ai-interpretation-block {cls}">\n'
            f'<div class="ai-block-title">{html.escape(LABELS[k])} <span class="ai-section-status">{status}</span></div>\n'
            + "\n".join(body) + f'\n<div class="ai-block-footer">{html.escape(footer)}</div>\n</section>\n')

srcs = meta.get("sources", "the final report")
note = (f'<p class="ai-added-note"><em>{html.escape("These AI interpretations were added after the run, from " + srcs + ". The workbench run itself did not generate them, so the Run Setup table still records AI as not included. The statistical tables, figures and estimates are unchanged.")}</em></p>')

# ---- anchors (same as the .docx script) ----
comp = sect("comparison-of-ufh-and-mfh")
status = next((d for d in comp.find_all("div", class_="ai-status-box") if re.sub(r"\s+", " ", d.get_text(" ", strip=True)) == STATUS), None)   # the source may wrap the line
banner = comp.find("div", class_="ai-assurance-banner")
normal, rate = sect("normality-diagnostics"), sect("rate-mse-rmse-and-cv-comparisons")
povmap = soup.find("div", id="poverty-maps") or sect("mean-welfare-maps")   # mean-welfare reports use their own id
rmse, ci, sess = sect("rmse-maps"), sect("distribution-of-95-confidence-interval-widths"), sect("session-information")
assert povmap.find_next_sibling(True) is rmse, "Poverty Maps is not directly followed by RMSE Maps"
change_note = next((p for p in ci.find_all("p", recursive=False) if p.get_text(" ", strip=True).startswith("Change maps")), None)
links = ci.find("div", class_="excel-output-links")
span = sess.h1.find("span", class_="header-section-number")
n = None  # Added recommendation is unnumbered; preserve original cross-references.

edits = []   # (start, end, replacement) on the original text
if status is not None:
    s0 = pos(status); s1 = text.index("</div>", s0) + len("</div>")
    assert "<div" not in text[s0 + 4:s1], "status box has nested divs"
    edits.append((s0, s1, note + block("overview")))
else:   # no status box: put the note and overview after the AI banner (or after the section heading)
    anchor = banner if banner is not None else comp.h1
    a1 = text.index(f"</{anchor.name}>", pos(anchor)) + len(anchor.name) + 3
    edits.append((a1, a1, "\n" + note + block("overview")))
edits.append((close_of(normal), close_of(normal), block("normality")))
edits.append((close_of(rate), close_of(rate), block("rates") + block("precision")))
edits.append((close_of(povmap), close_of(povmap), block("poverty_maps")))
if change_note is not None:
    edits.append((pos(change_note), pos(change_note), block("change_significance") + "\n"))
else:   # fall back to after the Excel links, else to the end of the CI-width subsection
    p = (text.index("</div>", pos(links)) + 6) if links is not None else close_of(ci)
    edits.append((p, p, block("change_significance")))
edits.append((close_of(comp), close_of(comp), block("change_maps")))
rec_title = f"{n} AI Recommendation: UFH or MFH" if n else "AI Recommendation: UFH or MFH"
num_attr = f' number="{n}"' if n else ""
rec = (f'<div class="section level1 unnumbered" id="ai-recommendation-ufh-or-mfh"{num_attr}>\n<h1>'
       + (f'<span class="header-section-number">{n}</span> ' if n else "") + "AI Recommendation: UFH or MFH</h1>\n"
       "<p>This is advisory interpretation for analyst review, not automatic model selection or official statistical "
       "approval. The numerical results remain unchanged.</p>\n" + block("recommendation") + "</div>\n\n")
edits.append((pos(sess), pos(sess), rec))
if n:
    sp = pos(span); inner = text.index(">", sp) + 1
    assert text[inner:inner + len(str(n))] == str(n)
    edits.append((inner, inner + len(str(n)), str(n + 1)))
    m = re.match(r'<div[^>]*\snumber="(\d+)"', text[pos(sess):text.index(">", pos(sess)) + 1])
    if m and m.group(1) == str(n):
        a = pos(sess) + m.start(1); edits.append((a, a + len(m.group(1)), str(n + 1)))
if ".ai-interpretation-block" not in text:
    h = text.index("</head>"); edits.append((h, h, f"<style>{AI_CSS}</style>\n"))

edits.sort(key=lambda e: (e[0], e[1]))
for a, b in zip(edits, edits[1:]): assert a[1] <= b[0], "overlapping edits"
outtext = text
for s0, s1, rep in reversed(edits): outtext = outtext[:s0] + rep + outtext[s1:]
open(out, "w", encoding="utf-8", newline="").write(outtext)
json.dump([[s0, s1, len(rep)] for s0, s1, rep in edits], open(out + ".edits.json", "w"))
print(f"saved {out} ({len(edits)} edits; Session Information renumbered {n} -> {n + 1 if n else None})")
