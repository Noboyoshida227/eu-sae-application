# Anchored poverty and mean-welfare verification

**Ready within the checked numerical scope.** On October 29, 2026, `povline_anchored` was restored and all four additional UFH → MFH2 → Comparison workflows completed. HTML and editable Word reports, Excel outputs and figures were generated for each. The subsequently identified map-legend and diagnostic-label issues have been corrected; see the [presentation refresh](PRESENTATION_REFRESH.md) for current reports.

## Restored column and preservation

The restored column is identical to the earlier backed-up column. Every pre-existing survey column and attribute is unchanged. The current 13-column survey SHA-256 is `19268db6ffd762eb81d5130529fe09ad3861ea490557802ccd72c043090942a2`. Auxiliary data, geometry and the teaching CPI are unchanged. A standalone regeneration of the column reproduced this complete survey byte-for-byte.

`z_2010 = povline_2012 × CPI_2010 / CPI_2012 = 6127.05161676527`. The nominal anchored line is `z_2010 × CPI_t / CPI_2010`: **6477.48423337962 (2012)** and **6801.3584450486 (2013)**. The 2010 amount is a price-basis conversion of the 2012 threshold, not an observed 2010 poverty line.

The pre-restoration moderate-correlation folder is preserved in the local backup `Claude outputs/data_preservation/Spain_2y_before_anchor_restore_20261029T203034Z`; its verified `Spain_2y.zip` SHA-256 is `7ea28aae56bee6ba7d89f7164061525783673d0d6b6f574c59cf214a2fe78af1`. The original `Data/Spain/` and earlier verification package remain unchanged. See [current receipt](anchor_welfare_receipt.json) and [restoration details](../generation/anchor_restoration.json).

## Settings and results

All runs use 2012–2013, household person weights `weight × hhsize`, no strata or household linkage, seed 123, automatic selection without LASSO or fixed formulas, MFH2/AIC, benchmarking off and AI off. Anchored poverty uses nominal income against `povline_anchored`, CPI conversion off, UFH arcsin/BIC with bias correction, and untransformed MFH2. Mean welfare uses log models, the teaching CPI with a 2012 price base, UFH BIC/sm_all with Slud–Maiti correction, and MFH2 conditional lognormal back-transformation. The **MFH** policy varies across each pair; **UFH mean-welfare smoothing remains sm_all**.

| Indicator | MFH policy | Fitted rho | Innovation variance a | Marginal variance q | MFH successes / attempts | Boundary draws |
|---|---|---:|---:|---:|---:|---:|
| anchored poverty | sm_all | 0.65307 | 0.0034828 | 0.0060729 | 500 / 500 | 25 (5.0%) |
| anchored poverty | sm_out | 0.62789 | 0.0039251 | 0.0064797 | 500 / 500 | 2 (0.4%) |
| mean welfare | sm_all | 0.39184 | 0.0263610 | 0.0311426 | 500 / 500 | 0 (0.0%) |
| mean welfare | sm_out | 0.42075 | 0.0262160 | 0.0318554 | 500 / 500 | 0 (0.0%) |

UFH random-effect variances are **0.0139670942 / 0.0223778461** for anchored poverty (2012 / 2013, arcsin scale) and **0.0349760842 / 0.0332121553** for mean welfare (log scale). They are not directly comparable across these scales. MFH innovation and marginal variances are on the proportion scale for poverty and log scale for welfare. All original fits are interior and all checked residual dispersions are positive.

Anchored-poverty UFH completed 500/500 bootstrap draws in each year. Log UFH uses production **analytical Slud–Maiti MSE**, not a 500-draw bootstrap; that count setting is inactive on this path. MFH completed 500/500 in each run. Valid bootstrap boundary fits are retained and disclosed; they are not a claim that the original fit lies on a boundary. The new indicators were not required to meet a correlation threshold, and no further income editing or candidate search occurred.

## Checks performed

- Independent weighted calculations match all 104 province-year direct estimates for both methods, including the anchored-line classification and the mean-welfare CPI factor of 1/1.05 in 2013.
- UFH variance estimates agree with independent ML/REML profile-likelihood searches and have positive interior optima. MFH fits pass the production convergence/score/curvature checks and have positive interior covariance parameters.
- All 52 provinces appear in both years; poverty point estimates lie in [0,1], welfare estimates are positive, annual MSEs are positive, joint MSE/MCPE matrices are positive semidefinite and usable change variances are positive.
- Level exports agree with fitted models and joint-bootstrap objects. Combined workbooks agree with detailed exports. Mean-welfare percentage changes, log-ratio intervals, p-values and adjusted p-values were recomputed independently from the annual moments.
- HTML and Word model-table values match exported diagnostics; required text and embedded image/media availability passed. Representative generated maps and a residual plot were inspected. Word layout was not reviewed page by page.

## Presentation refresh and scope limitations

The mean-welfare map legend and internal `poor_2012` / `poor_2013` diagnostic plot labels were corrected in a subsequent presentation-only refresh on October 29. Currency legends use readable spacing and thousands separators; diagnostic labels identify the years, indicator and working scale. All four HTML and Word reports were regenerated from saved outputs. The data, fitted models, bootstrap objects, numerical tables and workbooks are byte-for-byte unchanged. See the [refresh note and report links](PRESENTATION_REFRESH.md) and [receipt](presentation_refresh_receipt.json). The original restoration receipts and source snapshot remain historical evidence of the numerical runs; the refresh has its own source and output hashes.

These checks establish computational readiness for the supplied settings, not normality, model adequacy, predictive accuracy, interval coverage or official Spanish poverty/welfare. The inputs remain selected synthetic teaching data. Benchmarking, AI, MFH BIC, alternative MFH models and UFH sm_out for mean welfare were not verified. UFH changes assume year independence; MFH uses cross-year MCPE. Inference conditions on selected formulas and estimated sampling variances.

## Configurations and evidence

| Run | Portable configuration | Numerical receipt | Report-content receipt |
|---|---|---|---|
| anchored_poverty__sm_all | [YAML](../run_config_anchored_poverty_sm_all.yml) | [JSON](anchored_welfare/anchored_poverty__sm_all_verification.json) | [JSON](anchored_welfare/anchored_poverty__sm_all_report_qa.json) |
| anchored_poverty__sm_out | [YAML](../run_config_anchored_poverty_sm_out.yml) | [JSON](anchored_welfare/anchored_poverty__sm_out_verification.json) | [JSON](anchored_welfare/anchored_poverty__sm_out_report_qa.json) |
| mean_welfare__sm_all | [YAML](../run_config_mean_welfare_sm_all.yml) | [JSON](anchored_welfare/mean_welfare__sm_all_verification.json) | [JSON](anchored_welfare/mean_welfare__sm_all_report_qa.json) |
| mean_welfare__sm_out | [YAML](../run_config_mean_welfare_sm_out.yml) | [JSON](anchored_welfare/mean_welfare__sm_out_verification.json) | [JSON](anchored_welfare/mean_welfare__sm_out_report_qa.json) |

Full outputs and the frozen source snapshot are retained locally at `Claude outputs/spain_regeneration/anchored_welfare_20261029/`. Each named run is under `runs/` and has `outputs/final_report.html`, `outputs/final_report.docx`, `outputs/data/EU_SAE_results.xlsx`, figures and tables. The installed receipts also include variance and independent-direct-estimate CSVs. This local audit package is not included in the release inventory. No commit, push, publication or release build was performed.
