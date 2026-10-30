"""Shared fail-before-write guards for the adapted Claude insertion helpers."""
from pathlib import Path
from datetime import datetime

KEYS = ("overview", "normality", "rates", "precision", "poverty_maps",
        "change_significance", "change_maps", "recommendation")


def validate(src, out, spec):
    if Path(src).resolve() == Path(out).resolve() or Path(out).exists():
        raise ValueError("Preserve originals: choose a new output path")
    for key in KEYS:
        if key not in spec or (spec[key] is not None and not isinstance(spec[key], str)):
            raise ValueError(f"Missing/invalid section: {key}")
        if not spec[key] and not spec.get("reasons", {}).get(key):
            raise ValueError(f"Missing reason for unavailable section: {key}")
        if spec.get("numeric_qa", {}).get(key) not in ("passed", "limited", "warning"):
            raise ValueError(f"Missing/invalid QA status: {key}")
    meta = spec.get("meta", {})
    for key in ("provider", "model", "generated_utc", "language", "sources"):
        if not isinstance(meta.get(key), str) or not meta[key].strip():
            raise ValueError(f"Missing provenance: {key}")
    datetime.strptime(meta["generated_utc"], "%Y-%m-%d %H:%M:%S UTC")


def guard_docx(d):
    text = " ".join(p.text for p in d.paragraphs)
    if "(added after the run)" in text or "| Generated" in text or "Provider:" in text:
        raise ValueError("Existing AI content: use targeted edits; do not insert duplicate blocks")


def guard_html(soup):
    if soup.select(".ai-interpretation-block") or any(soup.find(id="ai-"+k) for k in KEYS):
        raise ValueError("Existing AI content: use targeted edits; do not insert duplicate blocks")
