# Map and diagnostic presentation refresh

On October 29, 2026, the four anchored-poverty and mean-welfare runs were refreshed from their saved estimates and diagnostics. No estimation, bootstrap, data generation or data editing was repeated.

## Changes

- Mean-welfare maps use currency labels with thousands separators. Horizontal colour bars are wider, with the concise title above the bar. Comparison maps and their HTML legend assets identify the currency; level and RMSE maps retain their original values, shared ranges and palette.
- MFH residual-fitted plots show **2012** and **2013**, with **Fitted log mean welfare** for log-welfare runs and **Fitted poverty rate (proportion)** for these poverty runs. Residual histograms, QQ plots and random-effect histograms also show years instead of internal `poor_*` column names.
- Internal model column names and exported regression formulas remain unchanged. A formula containing `poor_2012` is still the model's stored formula, not a diagnostic plot label.
- The four HTML reports and their editable Word versions were regenerated. Previous outputs were backed up before replacement.

## Reports

| Indicator | MFH variance policy | HTML | Word |
|---|---|---|---|
| Mean welfare | sm_all | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/mean_welfare__sm_all/outputs/final_report.html) | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/mean_welfare__sm_all/outputs/final_report.docx) |
| Mean welfare | sm_out | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/mean_welfare__sm_out/outputs/final_report.html) | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/mean_welfare__sm_out/outputs/final_report.docx) |
| Anchored poverty | sm_all | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/anchored_poverty__sm_all/outputs/final_report.html) | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/anchored_poverty__sm_all/outputs/final_report.docx) |
| Anchored poverty | sm_out | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/anchored_poverty__sm_out/outputs/final_report.html) | [Report](../../../Claude%20outputs/spain_regeneration/anchored_welfare_20261029/runs/anchored_poverty__sm_out/outputs/final_report.docx) |

These links point to local verification outputs, which are not part of the release package. The corrected standalone MFH diagnostic plots are in each run's `outputs/figures/` folder. The final reports use the existing Comparison diagnostic plots, which already displayed years.

## Verification and preservation

All files under the original `Data/Spain/` are unchanged. The Spain_2y survey, auxiliary data, shapefile, CPI, crosswalk, generation files and run configurations are unchanged. Only documentation and the new presentation receipt were added or amended in Spain_2y.

Every saved model, bootstrap object, numerical table and workbook in the four runs is byte-for-byte unchanged. Every HTML report table matches its previous version exactly. Each refreshed report contains 51 HTML images and 37 Word media files; embedded currency legends and Word map grids were checked against the regenerated PNG hashes. Representative maps and all four types of MFH diagnostic plot were visually checked. Word pagination was not reviewed page by page.

The [presentation receipt](presentation_refresh_receipt.json) records source hashes, changed-output hashes and preservation checks. The earlier [restoration receipt](anchor_welfare_receipt.json) remains a historical record; its two presentation findings are resolved by this refresh. Numerical findings and statistical limitations in [the anchored-poverty and mean-welfare note](ANCHOR_AND_WELFARE.md) are unchanged.

The local audit folder is `Claude outputs/spain_regeneration/presentation_refresh_20261029/`. Its `before/` directory contains four complete output ZIP backups, and its `runs/` directories contain the amended presentation sources, render logs and content checks. The original `anchored_welfare_20261029/final_manifest.json` is preserved; `presentation_refresh_manifest.json` records the current output hashes. No commit, push, publication or release build was performed.
