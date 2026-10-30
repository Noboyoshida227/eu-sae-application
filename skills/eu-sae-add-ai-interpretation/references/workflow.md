# Helper commands and output contract

## Evidence

```text
python scripts/report_tools.py inspect final_report.html report_evidence.json
python scripts/build_evidence.py EU_SAE_results.xlsx evidence.json --indicator poverty --change-unit proportion --benchmark on
```

`--indicator`: `poverty` or `mean_welfare`. Record the precise poverty indicator
separately in the audit and prose. `--change-unit` describes the raw `diff/lb/ub/mse`
columns of the Statistical significance sheet:

- `proportion`: multiply changes/widths by 100 and MSE by 10,000; output percentage points.
- `percentage_point`: already in percentage points; no scaling.
- `percent`: already percentage change; no scaling.
- `currency`: absolute welfare difference; no scaling.
- `log`: log difference; no scaling, not silently called percent.

`--benchmark`: `on`, `off`, `unknown`. Always set from report facts. Unknown
produces separate benchmark-column summaries but does not assert benchmarking was
applied. Missing columns produce nulls. Helpers never evaluate spreadsheet formulas
or execute embedded report code. Formula cells require recalculated saved values;
the evidence helper rejects formulas in its two source sheets to prevent silently
using absent/stale caches. Request a values-only export or verify/recalculate in a
trusted spreadsheet workflow if this occurs.

`build_evidence.py` expects rc.6 sheets `Estimate comparison` and `Statistical
significance`. It rejects missing keys, duplicate domain/year or method/domain keys,
invalid boolean flags and nonnumeric populated metric cells. IDs remain strings.
It emits aggregate JSON and a workbook SHA-256; original sheets stay unchanged.
Null means not available. Its marginal summaries are intended for report matching;
method comparisons use paired finite masks. `reported_flags` retain exported counts for report matching; `flags` exclude known invalid inference and missing/nonfinite uncertainty. If these disagree, disclose the inconsistency before interpreting significance. Status summaries flag concerns but do
not certify inference validity: inspect table-level/row-level statuses before using
precision claims. Missing diagnostics are not passes. Add calculations needed by a
particular report in a temporary script, preserving the same checks and recording
formulas, scope, denominator and units in the audit.

The report extractor returns all paragraphs, table captions/cells, and image hashes.
For Word it does not merge split panels. For HTML it does not execute JavaScript or
fetch linked resources. Do not include the full extracted text in external requests.

## sections.json

All eight content keys are required. Use a string for supported commentary, or null
with a specific `reasons` entry when no interpretation can be written. For a partly
supported block, write the supported part with the limitation and QA `limited`.

```json
{
  "meta": {
    "provider": "OpenAI",
    "model": "not recorded",
    "generated_utc": "ACTUAL UTC TIME",
    "language": "English",
    "sources": "the submitted final report and matching EU_SAE_results.xlsx"
  },
  "numeric_qa": {
    "overview": "limited", "normality": "limited", "rates": "limited",
    "precision": "limited", "poverty_maps": "limited",
    "change_significance": "limited", "change_maps": "limited",
    "recommendation": "limited"
  },
  "reasons": {},
  "labels": {},
  "overview": null, "normality": null, "rates": null, "precision": null,
  "poverty_maps": null, "change_significance": null, "change_maps": null,
  "recommendation": null
}
```

Replace the example time and empty contents before insertion. Use `labels` to set
indicator-appropriate titles, e.g. `rates: Mean Welfare Comparisons`, `poverty_maps:
Mean Welfare Maps`, and mean-welfare change titles. Text is plain paragraphs; HTML
is escaped. Do not set QA to passed merely because the script completed.

Audit minimum: source filenames and SHA-256; indicator/units/settings with source
locations; same-run comparisons (report cell, workbook metric, rounding, result);
quantitative claims (block, quantity, source JSON path or table cell, method, year,
scope, denominator, units, displayed value); diagnostic limitations; preservation
and visual checks; human-review status. Record calculations for derived claims.

## Insertion and preservation

Insertion scripts are adapted from the supplied Claude v3.1 package. They support
the English rc.6 anchors. They do not validate statistical assertions. They add
advisory notes and footers, remove only the obsolete AI-not-requested placeholder,
and insert an unnumbered recommendation section to preserve original numbered
sections and cross-references. Verify navigation/TOC behavior in the viewer.

The DOCX script changes only `word/document.xml` in the ZIP package; all other
members remain byte-identical. HTML splices into the original text rather than
reserializing images/scripts. Never overwrite originals or add duplicate blocks.
The `verify` command checks that original report tables and images remain and that
the original text sequence remains apart from the obsolete status line. For DOCX,
it also checks all ZIP parts other than document.xml byte-for-byte; for HTML it
checks original scripts and link targets. It requires eight AI blocks and a post-run
note, but placement, factual accuracy and visual layout still need inspection.
