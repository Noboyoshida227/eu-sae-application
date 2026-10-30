# Run the two-year Spain teaching example

Choose one of the three modes below. All use the same `survey.rds`, `auxiliary.rds` and `shapefile.rds`. [Additional verification results](verification/ANCHOR_AND_WELFARE.md) cover anchored poverty and mean welfare.

## Original-line poverty

1. In the Workbench, load this folder's `survey.rds`, `auxiliary.rds` and `shapefile.rds`. Select household rows and years **2012 and 2013**.
2. Set the variable mappings below. Leave strata and household linkage blank. Select poverty FGT(0), seed **123**, benchmarking **off**, AI **off**, and CPI/price transformation **off**.
3. UFH: **arcsin**, bias correction **bc**, **BIC**, LASSO off and **500** bootstrap attempts. The sampling-variance smoothing selector is inactive on this scale.
4. MFH: **MFH2**, **no transformation**, **AIC**, LASSO off, MFH3 off and **500** successful joint-bootstrap draws. Choose **Same identifiers represent the same PSUs across years**: this example has 442 paired PSUs, and MFH does not run until the cross-year PSU design is chosen. Leave fixed-formula overrides empty. Use either **sm_out / rho_sm_out** or **sm_all / rho_sm_all**; both were verified. The sm_out configuration is a convenient starting example, not evidence that it is statistically superior.
5. Run **UFH → MFH → Comparison** and generate the final reports. Use the run's output links to open the HTML/Word reports, workbook, maps and diagnostics.

| Setting | Column |
|---|---|
| Year | `year` |
| Domain; auxiliary and geometry join | `prov` |
| PSU | `ea_id` |
| Household weight | `weight` |
| Household size | `hhsize` |
| Welfare | `income` |
| Poverty-line column | `povline` |

Person analysis weights are `weight * hhsize`; poverty uses the strict comparison `income < povline`. No CPI file is needed for the original-line settings above.

## Anchored poverty

Keep the original-line poverty settings, but select **`povline_anchored`** as the poverty-line column for both methods. Keep CPI conversion **off**: the column already expresses the fixed-purchasing-power line in each year's nominal prices. The lines are 6,477.484 (2012) and 6,801.358 (2013). Use [sm_all](run_config_anchored_poverty_sm_all.yml) or [sm_out](run_config_anchored_poverty_sm_out.yml). These vary the MFH policy; UFH uses arcsin/BIC in both.

## Mean welfare in 2012 prices

Choose **mean welfare**, welfare column `income`, and enable **log modeling and bias correction** for both methods. Use UFH **BIC**, **sm_all**, Slud–Maiti correction (`bc_sm`); and MFH2 **AIC**, with its conditional lognormal correction. Keep the same two years, mappings, seed 123, no strata/linkage, no LASSO, no formula overrides, benchmarking off and AI off.

Choose **current prices: convert with a price index**. Select `CPI_Spain_teaching.csv`, year column `year`, value column `CPI`, fixed-reference index, income period **survey year**, base year **2012**. The 2013 conversion factor is 92.717 / 97.35285 = **1/1.05**. The stored incomes remain nominal.

Use [MFH sm_all](run_config_mean_welfare_sm_all.yml) or [MFH sm_out](run_config_mean_welfare_sm_out.yml). **UFH remains sm_all in both**; UFH sm_out for mean welfare was not separately verified. UFH uses analytical Slud–Maiti MSE, so its bootstrap-count control is inactive on this path. MFH uses **500 successful joint-bootstrap draws**. Levels are arithmetic means in 2012 prices after back-transformation, not geometric means. The final comparison reports percentage changes with log-ratio inference; currency-unit changes remain in the exports.

## Saved configurations and outputs

All six YAML configurations preserve the tested statistical settings. The [original-line sm_out](run_config_sm_out.yml) and [original-line sm_all](run_config_sm_all.yml) configurations keep their original names. Input paths are relative to the **Workbench root**, not to this data folder. Run saved configurations with the working directory set to the Workbench root. If selecting files through the UI, reload all three inputs and check both methods' settings instead of reusing an old run's mappings.

For an R session at the Workbench root, `source("app_support.R")` exposes `run_pipeline_from_config()`. Pass one of these YAML paths with `render_report = TRUE` and `include_ai = FALSE`. This entry point refreshes the root `outputs/` directory, so preserve any existing root outputs first. The UI manages separate run folders under `app_runs/`.

Within a completed run, reports are `outputs/final_report.html` and `outputs/final_report.docx`; Excel results are `outputs/data/EU_SAE_results.xlsx`; maps and diagnostics are in `outputs/figures/`; detailed tables are in `outputs/tables/`.

The already completed validation runs remain in the local audit package `Claude outputs/spain_regeneration/moderate_correlation_20261029/runs/candidate_01/`. Subfolder `sens2` is sm_out and `principal` is sm_all. These historical reports are not copied into the input-data folder or release inventory. Their results and variance checks are documented in [verification/README.md](verification/README.md).

The four additional runs are in `Claude outputs/spain_regeneration/anchored_welfare_20261029/runs/`, under `anchored_poverty__sm_all`, `anchored_poverty__sm_out`, `mean_welfare__sm_all` and `mean_welfare__sm_out`. Each has its own `outputs/` and verification receipts.

The report's **Sigma** is a companion OLS residual standard deviation, not the random-effect standard deviation. MFH2 reports innovation variance `a`; its marginal variance is `a/(1-rho^2)`. UFH random-effect variances are on the arcsin scale. The [README](README.md) gives the expected values and the limits of the verification.
