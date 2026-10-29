# Verification evidence

The current survey includes the restored anchored-line column. Start with [the latest anchored-poverty and mean-welfare verification](ANCHOR_AND_WELFARE.md) and [restoration receipt](anchor_welfare_receipt.json). Four new full workflows passed the numerical checks. The map legend and diagnostic labels were subsequently corrected; [the presentation refresh](PRESENTATION_REFRESH.md) links the regenerated reports and preservation checks.

## Current evidence

`anchored_welfare/` contains each run's numerical JSON, variance CSV, report-content JSON and independently calculated direct-estimate CSV. The current receipt records the active hashes, configuration checks, source snapshot, original-Spain preservation, backup and exact anchored-column regeneration. The new runs use a frozen snapshot of the current local application; unrelated pre-existing UI/test edits were preserved.

## Historical original-line poverty evidence

| Record | Purpose |
|---|---|
| [acceptance_receipt.json](acceptance_receipt.json) | Original unedited acceptance of the 12-column candidate, before optional anchored-line restoration. |
| [variance_receipt_sm_out.csv](variance_receipt_sm_out.csv), [variance_receipt_sm_all.csv](variance_receipt_sm_all.csv) | Original-line poverty variance results. |
| [regeneration.json](regeneration.json), [fit_comparison.json](fit_comparison.json) | Exact regeneration and independent fit reproduction for the 12-column candidate. |
| [source_snapshot.json](source_snapshot.json), [package_versions.csv](package_versions.csv) | Original tested source and package records. |
| [installation_receipt.json](installation_receipt.json) | Historical installation of the 12-column candidate and backup of the former covariate-signal version. |

These historical receipts intentionally retain their original survey hashes. The latest restoration receipt bridges them to the 13-column survey: all original columns and attributes are identical; only `povline_anchored` is added. Existing original-line configurations do not select that column. Their earlier fitted correlations remain 0.57411 (sm_out) and 0.65283 (sm_all); their two bootstraps were not repeated merely for an unused-column addition.

Original-line outputs remain at `Claude outputs/spain_regeneration/moderate_correlation_20261029/runs/candidate_01/`, with `sens2` for sm_out and `principal` for sm_all. New outputs are in the separate `anchored_welfare_20261029` audit package. Older evidence and the original `Data/Spain` remain unchanged.

Validation is limited to the settings in [START_HERE.md](../START_HERE.md). Synthetic weighted totals are not official population totals; successful computation does not establish model adequacy or interval coverage.
