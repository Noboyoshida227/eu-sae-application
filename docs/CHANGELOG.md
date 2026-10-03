# Changelog

## Unreleased (w5k)

- Mean welfare in constant prices (owner's decisions of 1 and 2 Oct): the Indicator step has a new **Express welfare in constant prices** box for mean-welfare runs, with a consumer price index (for example the CPI or HICP) entered in either of the two ways statistical offices publish it (**Price index type**): index levels with a fixed reference year (for example 2015 = 100), one for each analysis year, or annual-average indices with the previous year = 100 (for example 103.6 for 3.6% inflation, as in Statistics Poland's annual table), one for every year after the earliest and up to the latest analysis or base year, which the app chains into price levels. A **Price base year** sets the prices in which mean welfare is expressed: the first analysis year (default) or another year, for example 2017 or the last analysis year; with a fixed-reference index, a base year outside the analysis years needs its own index level, from the same series. Welfare is multiplied by the price level of the base year / the price level of its own year in Data Readiness and in the UFH and MFH steps, so all mean-welfare levels are in prices of the base year and changes are real changes; percentage changes do not depend on the base year. External mean-welfare benchmark targets are converted in the same way. The settings are saved with the dashboard setup, written to `app_config.yml` as `price_index` (enabled, index type, base year, values) and checked before a run (every needed index value present and positive; the base year a calendar year). The step logs, the run log, the readiness messages, the wizard review page and the report state the price basis; when the box is not ticked, Data Readiness notes that changes include inflation. Poverty runs are not affected. Helpers `sae_price_index_type()`, `sae_price_base_year()`, `sae_price_chain_years()`, `sae_price_levels()`, `sae_price_factors()`, `sae_apply_price_index()`, `sae_price_index_problems()` and `sae_price_basis_label()` in `R/pipeline_helpers.R`; UI helper `price_index_inputs()` in `app.R` (also listed in `tools/check_ui_parity.R`). On the Spain example (log models) every UFH estimate for the second year, and every direct estimate, is the nominal value times index(first year) / index(second year); MFH estimates agree to within 0.01%. With base year 2017 (index 104.9, against 100 in 2012 and 101.4 in 2013), every direct and UFH estimate is 1.049 times its value in 2012 prices and the UFH percentage changes are unchanged; MFH estimates agree to within 0.01% and MFH percentage changes to within 0.013 percentage points (msae's optimiser), with the same significant domains. Entering the same prices as annual indices (previous year = 100) gives the same results as the fixed-reference index.
- Report: box plots of changes and their RMSEs for every method (owner's request, 2 Oct). The box plots of UFH and MFH changes and of their 95% confidence-interval widths are replaced by box plots, side by side in one row, of the change between the two years across domains and of the RMSE of that change, with one box per method: Direct, UFH, the selected MFH model and, with benchmarking on, UFH benchmarked and MFH benchmarked. For poverty indicators both are in percentage points; for mean welfare the change is in ln mean welfare (ln of the later mean minus ln of the earlier mean) and the RMSE is the delta-method standard error of that log ratio. The RMSE of a direct change adds the two years' direct MSEs (independent samples); UFH also treats the years as independent and MFH uses the covariance between the years, as in the significance tests. In the HTML report a **Methods** drop-down list, as for the map grids, selects the boxes shown; the axes fit the selected methods, and hovering over a point shows its domain and value. The Word report shows all methods (`outputs/figures/change_comparisons/change_rmse_boxplots.png`). A table gives the median and interquartile range of the changes and the median and mean RMSE by method. The values are in `outputs/tables/change_rmse_by_method.csv` and in the new sheets "Change and RMSE by method" and "Change and RMSE summary" of `change_estimate_comparison.xlsx` and `EU_SAE_results.xlsx`. The paired UFH-MFH scatter plots of changes and of CI widths, and their tables, are unchanged; `change_distribution_ufh_mfh.png` and `ci_width_distribution_ufh_mfh.png` are no longer produced. Helpers `sae_change_rmse_by_method()`, `sae_plot_change_rmse_boxplots()` and `sae_method_colors()` in `R/change_comparison.R` and `sae_box_picker_html()` in `R/report_map_picker.R`. New checks in `tests/run_tests.R`.
- Mean-welfare changes are reported as percentage changes of the mean (owner's decision of 1 Oct): 100 × (mean in the later year / mean in the earlier year − 1), with the 95% interval and p-value from the log of the ratio. Its variance, MSE1/mean1² + MSE2/mean2² − 2·C/(mean1·mean2), uses the MSEs of the two estimates and their covariance C implied by the change MSE of the UFH and MFH steps (zero for UFH; as in the MFH step, the independence variance is used when the covariance-adjusted one is not above 1% of it). This applies to UFH, MFH and both benchmarked estimates in the change maps, significance plots, significance table and counts, `statistical_significance_comparison.xlsx`, `EU_SAE_results.xlsx` and the change and interval-width comparisons; the difference in currency units is kept in columns ending in `_eur`. Change figures are labelled "Change in mean welfare (%)". Helper `sae_percent_change()`; `sae_change_comparison()` gains `change_unit`. The difference of mean log welfare was not used because it measures the change in the geometric mean, which differs from the change in the mean by the change in the mean log deviation (on the Spain data, by up to 12 percentage points). New checks in `tests/run_tests.R`.
- Mean-welfare runs: the change figures and their headings no longer say "poverty" (request from the Polish team). The change maps were titled "Poverty Change Map" and the significance plots "Poverty changes", and the report headings 3.12.3 to 3.12.10 were the file names ("change map fh", "significance mfh"). They now read, for example, "Change in mean welfare, 2012 to 2013: UFH" and "Significance of changes in mean welfare: MFH2 benchmarked" ("poverty rate", "poverty gap" or "poverty severity" in poverty runs), with the method names of the map grids (UFH, UFH benchmarked, the selected MFH model). The section headings follow the indicator ("Mean Welfare Maps", "Statistical Significance of Mean Welfare Changes"), the change-map legend shows the currency for mean welfare ("Change (EUR)", whole units), and the significance plots order domains numerically (1, 2, ..., 10) instead of as text. The Comparison step writes the labels to `outputs/tables/indicator_info.csv` for the report; older runs without it are labelled as poverty, as before. New check in `tests/run_tests.R`.
- Fix: Data Readiness ignored the selected poverty line when the survey file also had a column named exactly `povline` (for example `povline` and `povline_2019`, with `povline_2019` selected). The readiness loader renamed the selected column to `povline` without removing the existing one, so the tables used the first `povline` column: the national and domain poverty rates in the Data Readiness tab, `national_poverty.csv` and `domain_poverty_rates.csv` did not change with the selection. The UFH and MFH steps were not affected; they already renamed the existing column to `povline_original`. `load_and_harmonize()` (in `app.R` and `app_support.R`) now does the same for every mapped role in the survey and auxiliary files, and the Data Readiness messages and the run log say which column was renamed. Found by the Polish team. New check in `tests/run_tests.R`.

## 5.2.0-rc.6-wizard.5.10 - 2026-10-01

- Map grids (request from the Polish team): the "Poverty Maps" and "RMSE Maps" sections of the report (HTML and Word) now show the maps as a table, with one row per estimation method and one column per year, so that differences between methods can be read down a column and changes over time along a row. The rows are Direct, UFH and the selected MFH model; with benchmarking on, UFH benchmarked follows UFH and the benchmarked MFH row follows MFH, so the grid has 5 rows and 2 columns. All panels of a grid share the family's legend range (as since wizard.5.8) and one colour bar. The Comparison step saves the grids as `outputs/figures/poverty_maps/grid_estimates.png` and `outputs/figures/rmse_maps/grid_rmse.png`. The single maps are still written to the same folders, and the report falls back to them if no grid was produced. `docs/README_WIZARD.md` and the figures README describe the grids.
- Method picker in the HTML report (request from the owner): above each map grid, a **Methods** drop-down list with one tick box per method selects the rows shown, so readers can compare, for example, UFH with UFH benchmarked only, or Direct, UFH and MFH2. **Select all** and **Clear** reset the list; the poverty and RMSE grids have separate lists. The Comparison step writes the panels for this view (one map per method and year, a colour bar and `manifest.csv`) to `grid_panels/` in `outputs/figures/poverty_maps/` and `outputs/figures/rmse_maps/`; the new `R/report_map_picker.R` embeds them in the HTML, so the report stays a single file. The Word report shows the full grid: `R/report_word.lua` drops blocks of class `sae-html-only`, and `sae_render_word_report()` removes them from a temporary copy of the HTML before Pandoc reads it (the original HTML is unchanged). The extra images add about 0.8 MB to the HTML report on the Spain example. New checks in `tests/run_tests.R`.
- Model selection criterion with fixed covariates (request from the Polish team): AIC/BIC is used only by stepwise covariate selection, so when LASSO is off and covariates are entered for both years of a model, the dashboard and the wizard replace that model's **Model selection criterion** box with a greyed "Not used: covariates fixed for both years" field. The run records `ic_criterion: none` in `app_config.yml`, the step log reads "Model-selection criterion: not used (covariates fixed for both years)", and the wizard's review page says the same. When covariates are fixed for one year only, the box stays active with a note that it applies to the other year; with LASSO on it is always active, because the entered covariates are then only a candidate pool. The scripts accept `none` only in that situation: `validate_app_config()` rejects it otherwise, and a run stops with an explanation if a year has no usable covariates after unknown names are dropped (before, the year fell back to automatic selection with the default criterion). Helpers `sae_effective_ic_criterion()`, `sae_ic_criterion_label()` and `sae_ic_none_problem()` in `R/pipeline_helpers.R`; UI helper `ic_criterion_input()` in `app.R` (also listed in `tools/check_ui_parity.R`). New checks in `tests/run_tests.R`.
- Word report: tall figures are scaled to fit the page with every supported Pandoc. The Word filter read image sizes only through `pandoc.image`, which needs Pandoc 3.1.13 or later; with an older Pandoc every figure was set 6.5 inches wide, so a tall figure such as a map grid ran past the bottom of the page. The filter now reads the size from the PNG header when `pandoc.image` is missing (checked with Pandoc 2.17.1.1, 3.1.3 and 3.11). New check in `tests/run_tests.R`.
- MFH convergence check (owner's decision of 30 Sep: keep msae's estimates and check them). After the MFH models are fitted, the MFH step evaluates, at msae's reported variance parameters, the REML log-likelihood, the REML score and the Fisher information (msae's own formulas for MFH1, MFH2 and MFH3 with two years) and the Newton decrement s' I^-1 s, which is zero at a maximum (parameters on a bound with an outward score are left out). Each fitted model gets a status: `ok`, `not_at_maximum` (msae reports convergence at a point that is not a REML maximum, as for MFH2 on the Spain example: Newton decrement 7.0, with the note that the maximum is probably on the boundary rho = 1) or `not_converged` (msae stopped at its iteration limit; before w5j a non-converged MFH1 was used without any message). Results go to the new `outputs/tables/mfh_convergence_check.csv`, the step log, `mfh_artifacts.rds` and a new "MFH Convergence Check" section of the report; when the selected model is not `ok`, the run issues a warning and the report asks for review. Estimates are unchanged. New file `R/mfh_convergence_check.R` (in the release inventory).
- The UFH that the MFH step fits with msae (MFH covariates, MFH scale) is renamed so it is not mistaken for the UFH step's model (emdi, arcsine, its own covariates): in `pov_mfh.xlsx` and the MFH step figures, `rate_UFH`, `mse_UFH`, `cv_UFH` and `rmse_UFH` become `rate_UFH_untransformed` etc. (`UFH_log` for mean welfare with the MFH log scale), and figure labels read "UFH, untransformed". Scripts that read the old column names from `pov_mfh.xlsx` need updating.
- Fix: the Comparison step deleted every file under `outputs/figures/`, including the UFH and MFH step figures (`ufh_*.png`, `mfh_*.png`), so after a full run they were in neither `outputs/` nor the run archive. Its clean-up now removes only its own subfolders and README; the figures README lists the step figures.
- Fix: the Word report needs Pandoc 2.17 or later, but any Pandoc 2.8 or later was accepted, so an older copy (for example an older RStudio's) was used and the Word export failed with "pandoc document conversion failed with error 83" while the pinned Pandoc 3.11 was never downloaded. The app now looks for Pandoc 2.17 or later first and downloads its pinned copy if none is found; only if that is impossible does it use an older Pandoc, for the HTML report only, and the log says why the Word report was skipped. `sae_render_word_report()` stops with the same explanation when called with an old Pandoc. The installer notes an HTML-only Pandoc.
- Fix: the Word conversion needed about 4 GB of memory with Pandoc 3.11 and 6 GB with Pandoc 2.17 on the Spain report, enough to fail on an 8 GB laptop. Pandoc now reads a temporary copy of the HTML report with the embedded images written to files (and the HTML-only map picker removed): about 0.5 GB and 6 seconds instead of 17-40 seconds, with the same Word file. The temporary files are removed afterwards; the HTML report is not modified.
- Fix: the benchmarking bootstrap for MFH3 (`scripts/bench_regional_mfh.R`) generated random effects without the rho * u0 term of msae's MFH3 (Var(u0) = 1), understating the first-period variance and the cross-time covariance of the bootstrap; it now uses the same generator as the MCPE bootstrap. MFH1 and MFH2 draws are unchanged (identical random numbers); only MSEs of benchmarked MFH3 estimates change.
- Fix: a covariate listed for MFH that is not numeric was dropped from a fixed formula without a message. The run now warns which covariates were not used, and says when no listed covariate was usable (intercept-only model for that year).
- `mfh.variance_lower_multiplier` is no longer validated: no step reads it (the only `sm_out` rule is the absolute 0.001 cutoff), so an old value no longer blocks a run; the MFH log notes that it is ignored.
- Benchmarking: when "National" is selected but a grouped benchmark variable is still selected, the dashboard and the wizard show a note that the variable is not used, and the run log says so.
- Report section 3.1 (owner's request): when MFH1 or MFH2 is chosen in the setup (MFH2 is the default), the MFH3/MFH2 variance-structure rule is not run, so the section is now headed "MFH Variance Structure" and says only which model was chosen and what it assumes, instead of describing the MFH3 procedure and showing an empty test table. The "Selected MFH model" note above it, the Run Setup table (no "MFH3 reference-variance test adjustment" row) and the significance section no longer mention MFH3 in that case. When MFH3 is requested, the section keeps the rule, now also states the outcome, omits the test-adjustment sentences when the test could not run, and drops empty columns from its table. The Run Setup row "Requested MFH rule" is renamed "Requested MFH model". New check in `tests/run_tests.R`.
- Release wording (owner's decision of 29 Sep): the package documents no longer say that the package is "not an official World Bank Group product" or "not approved for official statistics". They now say that the package is a release candidate for review and testing and that whether to publish estimates as official statistics is for each national statistical office to decide: `README.md`, `NOTICE`, `THIRD_PARTY_NOTICES.md`, `docs/GOVERNANCE.md`, `docs/README_WIZARD.md`, `docs/REVISION_STATUS.md`, `docs/WIZARD_RELEASE_NOTICE.txt`, the clean-release notice, the download-instructions PDF and the guidelines note. The landing-page footer reads "Release candidate for review and testing". The package remains an independent project maintained by Nobuo Yoshida, not a World Bank Group repository.
- No change to estimates or model selection. MSEs of benchmarked MFH3 estimates change (corrected bootstrap).

## 5.2.0-rc.6-wizard.5.9 - 2026-09-28

- Data Readiness tables are kept with the run. **Run Analysis** repeats the readiness check and then clears `outputs/` for the new run; that clean-up no longer deletes the readiness tables (`aux_covariate_summary.csv` with `cor_pvalue` and `cor_signif`, `national_poverty.csv`, `domain_poverty_rates.csv`, `domain_consistency.csv`, `readiness_messages.txt` and, when cells are missing, `missing_poverty.csv`). They stay in `outputs/tables/` and are archived with the run. A readiness check that finds no missing cells now also removes a `missing_poverty.csv` left by an earlier check. Runs started outside the app (scripts, tests) clear everything as before. New dev-only test `tests/test_readiness_tables.R` (10 checks).
- The package is published on GitHub Releases: https://github.com/Noboyoshida227/eu-sae-application/releases. The download instructions, READMEs, release notices, user guide and guidelines note now point there and no longer say that public sharing is blocked. The package remains a release candidate: it is not an official World Bank Group product and is not approved for official statistics.
- Documentation brought up to date with w5g and w5h: the background run and **Stop** button, the shared map colour scheme and legend ranges, and the p-values in the Data Readiness covariate summary are now described in the README, the wizard reference, the launcher README, the download instructions, the user guide (slides 26 and 28) and the guidelines note (Sections 5.7, 10.4, 11.1 and 11.8 and Annexes C and E). Figures 8a, 8b and 9 of the guidelines note were redrawn with the current maps and carry the IGN boundary credit. Stale folder names and examples were corrected.
- New landing-page and slide-guide illustration `www/cover_map_spain.png`, drawn by the package from the Spain example (`tools/make_cover_map.R`). It replaces the former EU map picture, whose source and licence were not recorded, on the landing page, in the slide guide, on the guidelines-note cover and in its Figure 10 (a new landing-page screenshot).
- `tools/bump_version.py` also replaces the old release name in the documents that mention it, and never touches the ignored `Claude outputs/` folder.
- The package is an independent project and will not become a World Bank Group repository. Removed: the World Bank contact addresses in `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md` (concerns and questions now go to the maintainer through GitHub), the "Official Use Only" label on the user-guide slides, the "World Bank Group" affiliation on the user-guide title slide, the World Bank e-mail contact on its last slide (now the GitHub issues page) and the "World Bank Group" footer on the landing page (now "Independent release candidate for review and testing"). `README.md`, `NOTICE`, `CONTRIBUTING.md` and `docs/GOVERNANCE.md` say so.
- Text inputs (CSV, TXT, TSV, DAT) are no longer cut short when they are not UTF-8. Since 5.2.0-rc.1 they were re-encoded with `fileEncoding = "UTF-8"`, which stops at the first byte that is not valid UTF-8 and keeps only the rows before it, with nothing more than a warning: a Windows-1252 or Windows-1250 CSV (Excel's default "CSV" on Windows) with one accented name lost every later row. Files are now read without re-encoding, as UTF-8 when they are valid UTF-8 (a byte-order mark is removed from the first column name) and otherwise as Latin-1 with a warning, so every row is kept. `SAE_INPUT_ENCODING` still forces an encoding. RDS, Stata, SPSS, SAS, Parquet, Feather and Excel inputs are not affected. New dev-only test `tests/test_input_encoding.R`.
- The *Analysis seed* tooltip now says what the seed controls: the LASSO folds and the MFH bootstrap draws. The UFH and benchmarking bootstraps use a fixed seed.
- Notes for users upgrading from v5.1.0 (no code change in 5.9):
  - UFH: a domain whose direct estimate is exactly 0 (or exactly 1 for the headcount ratio) stays in the UFH fit, with a variance based on its sample size (5.2.0-rc.1 and rc.4). v5.1.0 dropped such domains from the fit and gave them a synthetic estimate, so UFH estimates and MSEs change for every domain in a year that has such a domain. MFH kept them in both versions.
  - MFH change tests: the MCPE bootstrap uses 200 replicates by default (v5.1.0: 50, fixed), and its seed follows the analysis seed. Domains with a p-value close to 0.05 can change significance.
  - MFH3: v5.1.0 could not fit MFH3 (its msae patch made `eblupMFH3` fail, and the failure was reported as non-convergence), so MFH2 was always used. Since rc.5 MFH3 is fitted and chosen by the Molina-Romero rule.
  - MFH `sm_out`: direct variances larger than 5 times the smoothed variance are no longer replaced (post-rc.6 revision). This supersedes the rc.1 note on a "configurable relative rule": the only replacement rule is the absolute 0.001 cutoff, and the configuration key `mfh.variance_lower_multiplier` has no effect.
  - On the Spain example with the default settings, the direct estimates, the MFH2 estimates and MSEs and all selected covariates are identical to v5.1.0.
- No change to estimates, MSEs or model selection for inputs that were already read completely.

## 5.2.0-rc.6-wizard.5.8 - 2026-09-17

- Maps of one kind now share one legend range (`sae_shared_limits()` in `R/map_style.R`): all poverty maps (Direct, UFH, MFH, benchmarked variants, both years) use one value range, all RMSE maps another, and all change maps a symmetric range around zero, so the same colour means the same value on every map and colours can be compared across methods and years. Previously each map stretched the colours over its own minimum and maximum (announced with w5g but not included in that build). The UFH figures in `outputs/figures/` (`ufh_map_y*.png`, `ufh_rmse_map_y*.png`, EUR maps) follow the same rule across both years. Report captions updated.
- Data Readiness: the "Auxiliary Covariate Summary" table now reports, next to each correlation with the target indicator, the two-sided p-value of the Pearson correlation test and significance codes (*** p < 0.001, ** p < 0.01, * p < 0.05, . p < 0.1), for each year and pooled. Variables are listed from the most to the least significant pooled correlation (unavailable correlations last), with the year rows kept together under each variable. `outputs/tables/aux_covariate_summary.csv` gains `cor_pvalue` and `cor_signif` columns and is written in the same order.
- The package now lives at github.com/Noboyoshida227/eu-sae-application (fresh public repository; the maintainer guide `HOW_TO_RELEASE.md` points there). Country data folders (`Data/Greece/`) are excluded from the repository by `.gitignore`.
- No change to estimates, MSEs or model selection.

## 5.2.0-rc.6-wizard.5.7 - 2026-09-17

- The analysis now runs in a separate R process (`scripts/run_pipeline_bg.R`, started by the dashboard): the page stays responsive, the log pane follows `run.log` live, the progress bar follows the current step, and a second click on **Run Analysis** is refused while a run is active (previously the app was frozen for the whole run, the browser page could grey out, and a second click restarted the analysis). The optional AI interpretation, the report and the archive copy moved into that process; the API key is passed to it through its environment only and is never written to disk.
- New **Stop** button next to **Run Analysis** (dashboard and wizard). It ends the R process of the current step and the run finishes as *Stopped by user*; files written before the stop stay in `outputs/`, nothing is archived. Run folders gain `run_status.rds`, `driver_output.log`, `job.rds` and a `pids/` folder.
- One colour scheme for all maps (`R/map_style.R`): every level map (poverty rates, RMSE, mean welfare in EUR, the UFH and MFH level maps) uses the reversed magma scale, lighter = lower and darker = higher, with grey for domains without an estimate; every change map (poverty change, growth rates) uses the same blue-white-red diverging scale centred on zero. The UFH maps previously drawn by `emdi::map_plot()` (white-to-red) are now `ufh_map_y*.png` (Direct and FH estimates) and `ufh_rmse_map_y*.png` (their RMSEs) on that scale; the RMSE maps in the report switch from inferno to the shared scale. Report captions updated.
- Tests: new dev-only `tests/test_background_run.R` (36 checks: status file, PID bookkeeping, process checks, STOP marker, step wrapper, driver failure path); `tests/run_tests.R` checks the driver script instead of the removed dashboard code. `docs/RELEASE_CHECKLIST.md` lists the current test scripts and a manual Stop test.
- No change to estimates, MSEs or model selection.

## 5.2.0-rc.6-wizard.5.6 - 2026-09-15

- Comparison step: the run no longer fails with `arguments imply differing number of rows` when the selected MFH2 model came from the robust optim() refit (used when msae's `eblupMFH2()` returns a zero random-effect variance, as with the Greek NUTS3 data). The refit's coefficient matrix now carries the design-matrix term names like msae's, and the coefficient table in `03_comparison.R` is built by the new `sae_mfh_coef_table()` helper, which derives the term labels from the model formulas if they are missing and prints a note instead of stopping when the matrix cannot be split.
- New dev-only test `tests/test_mfh_coef_table.R` (17 checks) covering the helper and the labelled robust refit.
- No change to estimates, MSEs or model selection: the affected code only labels the coefficient table.

## 5.2.0-rc.6-wizard.5.5 - 2026-09-14

- Pipeline steps no longer fail when the step's R process finishes its work but exits with a non-zero status while shutting down (seen on a Windows laptop as `Step 'UFH' failed with exit status 255` with a complete child log and no R error). The step wrapper now prints a completion sentinel after the script has run to its end; if the sentinel is present and no `Error`/`Execution halted` line was printed, the run continues and the run log records a warning with the original exit status. A genuine script error or an early `quit()` still fails the step as before.
- Data Readiness: the "Auxiliary Covariate Summary" table now reports the mean, standard error, number of domains and correlation with the target indicator for each analysis year separately, followed by an "All years" row that pools every domain-year observation (the former single-row figure). Within-year correlations describe cross-domain association at a point in time; the pooled row also reflects between-year movement. `outputs/tables/aux_covariate_summary.csv` gains a `year` column.
- Poverty maps in the report (`outputs/figures/poverty_maps/`, Direct / UFH / MFH by year) now use a reversed magma scale: lighter colours for lower poverty rates, darker colours for higher rates, matching the MFH level maps. The report's "Poverty Maps" section states this convention. RMSE, change and growth-rate maps are unchanged.
- New dev-only test `tests/test_step_runner.R`.
- No change to statistical calculations, MCPE defaults or the Pandoc handling introduced in wizard.5.4.

## 5.2.0-rc.6-wizard.5.4 - 2026-09-14

- Pandoc is now obtained without the CRAN `pandoc`/`gh` packages. `R/pandoc_bootstrap.R` (base R only) reuses an existing Pandoc >= 2.8 (RStudio, Positron or Quarto bundles, PATH, Homebrew, the pandoc.org installer, or an earlier download) and otherwise downloads the pinned Pandoc 3.11 release for the platform into the user's R cache folder. Extraction happens only after the SHA-256 is computed and matches the pinned digest; the download timeout is bounded (`EU_SAE_PANDOC_TIMEOUT`, default 600 s) and a failed download is not retried within the same session. Fixes the macOS startup failure `could not find function "check_string"` (gh >= 1.6.0 with rlang < 1.2.0).
- A missing Pandoc no longer stops the launcher and no longer fails a run. The dashboard finishes as "Analysis completed - report unavailable", the run folder status names the reason, and the report step is shown as skipped; estimation outputs and Excel tables are kept. `render_final_report()` returns a status list instead of throwing.
- rmarkdown is pinned to the Pandoc folder selected by the launcher (`find_pandoc(dir = )`) and the selection is verified, so the reported and the rendering Pandoc are the same.
- macOS launchers write `startup_setup.log` like the Windows launchers; `Start_Here/README.md` describes the macOS 15 "Open Anyway" route first.
- Tests: `tests/test_startup.R` mocks the new helper; new `tests/test_pandoc_bootstrap.R` covers override and cache precedence, offline mode, unavailable and mismatching checksums, download and extraction failures, single-attempt behaviour, rmarkdown pinning and the skipped-report status.
- Offline use: `EU_SAE_PANDOC=<folder>` or a `tools/pandoc/` folder inside an already extracted package (local only; the release builder does not include it). Statistical calculations and MCPE defaults are unchanged from w5c.

## 5.2.0-rc.6-wizard.5.3 - 2026-09-13

- Included the Windows startup fix in the complete EU_SAE_520_w5c.zip; no separate patch is needed.
- Install missing/outdated R packages using Windows binaries, with visible download diagnostics.
- Detect an existing Pandoc >= 2.8 or install an official binary in the current user's storage.
- Verify package loading and stop setup on failure before opening the wizard; save startup_setup.log for troubleshooting.
- Statistical calculations and MCPE defaults are unchanged from w5b. Network or device policy can still prevent dependency installation.


## 5.2.0-rc.6-wizard.5.2 - 2026-09-12

- Removed dots from the release folder and ZIP basename: `EU_SAE_520_w5b/` and `EU_SAE_520_w5b.zip`. Only the file extension retains a dot.
- Release-name validation now permits letters, numbers, underscores and hyphens, preventing dotted package names in future builds.
- Full version identifiers remain inside the package. Statistical analysis code is unchanged.

## 5.2.0-rc.6-wizard.5.1 - 2026-09-12

- Final short-name package: `EU_SAE_5.2.0_w5a.zip`, containing `EU_SAE_5.2.0_w5a/`.
- Corrected the fresh-clone test to exercise output-directory creation and cleanup, rather than requiring generated folders to be committed.
- Includes the shorter-name release workflow from wizard.5; statistical analysis code remains unchanged.

## 5.2.0-rc.6-wizard.5 - 2026-09-12

- Shortened the distributable ZIP to `EU_SAE_5.2.0_w5.zip` and the application
  folder to `EU_SAE_5.2.0_w5`. Local releases now live under `dist/<RELEASE_NAME>/`.
- Added a validated `RELEASE_NAME` file, included in the release manifest, and
  a `--release-name` option for future version bumps. Full version identifiers
  and source commit metadata remain available for reproducibility.
- Updated the download instructions and release documentation for short names.
- Packaging-only release: no changes to statistical estimation or analysis settings.

## 5.2.0-rc.6-wizard.4-crossplatform - 2026-09-01

- Added macOS/Linux launchers `Start_Here/Start_Wizard.command` and
  `Start_Here/Start_Dashboard.command`, double-clickable in Finder. The former
  `Start_Dashboard.sh` had Windows line endings (its shebang failed), sat
  outside `Start_Here`, and had no wizard equivalent; it now hands over to the
  new launcher.
- The release builder marks the launchers executable inside the ZIP
  (`R/zip_permissions.R`). An archive written on Windows records no Unix
  permission bits, so the launchers would otherwise arrive unable to run.
- Fixed a platform-dependent gap in `scripts/eblupMFH2_robust.R`: a matrix
  containing non-finite values could pass `chol()` on some R/LAPACK builds and
  be returned as an available, all-NaN inverse instead of being reported
  unavailable. Non-finite input is now rejected before any decomposition.
- Documentation: launch instructions for all three platforms, including the
  macOS first-launch security prompt; the newest organisation-approved R 4.2+
  is sufficient; one Pandoc provider (RStudio Desktop, Quarto, or standalone
  Pandoc) is enough for report rendering.
- Continuous integration installs the packages the test suite needs, and the
  suite skips the Spain example-data checks in a clone (that data is excluded
  from the repository by licence). The suite had never previously run to
  completion; on its first full run it found the `chol()` gap above.
- Release process: `tools/bump_version.py` propagates the version to every
  file and filename that embeds it; `Release.ps1` refuses to build from an
  uncommitted tree, names the release folder by version, requires a CHANGELOG
  entry, and records the commit. See `docs/RELEASING.md`.

## 27 August 2026 — report formats and documentation

- Added editable Word reports alongside HTML, without recomputing estimates.
- Added distribution and paired-domain figures for signed estimated changes;
  retained the existing CI-width figures and exported their source values.
- Updated guidance, download instructions, slide guide, and operational notes
  for both formats, dependencies, archives, and conversion warnings.
- Clarified that dispersion across estimated changes is not prediction MSE.


## 5.2.0-rc.6-wizard.3-pointwise - 2026-08-25

- retained raw pointwise, BH-adjusted, and Bonferroni-adjusted poverty-change
  p-values and flags through the Comparison export and displayed them in the
  combined report while keeping pointwise inference primary;
- renamed and conditionally displayed the MFH3 reference-variance adjustment
  so it cannot be mistaken for geographic-domain change multiplicity; and
- preserved method labels as text rather than factor level numbers in XLSX
  exports;
- added UFH-MFH 95% confidence-interval width distribution and paired-domain
  figures to the combined report, with matched-domain summary statistics;
- replaced the 30-row significance preview with the complete scrollable table
  of pointwise, BH-adjusted, and Bonferroni-adjusted results;
- added `EU_SAE_results.xlsx` and `ci_width_comparison.xlsx` to the standard
  output set and linked them from the report; and
- extended the AI change-significance prompt so future AI-enabled runs discuss
  adjusted counts, interval-width distributions, and why narrower intervals do
  not necessarily produce more significant domains;
- restored MFH2 as the default MFH model in the classic and wizard interfaces;
- made an explicit MFH3 selection invoke the Molina-Romero sequence: fit MFH3,
  fall back to MFH2 on error or non-convergence, and otherwise use the adjusted
  MFH3 reference-variance test to choose MFH3 or MFH2;
- retained MFH1 as a manually selected sensitivity model and retained the
  optional MFH3 sensitivity-fit control without changing the selected model;
  and
- revised the guidance correspondence annex and internal-review documentation
  to state the corrected default and conditional MFH3 procedure.

## 5.2.0-rc.6-wizard.2-pointwise - 2026-08-24

- made the Molina-Romero MFH3/MFH2 sequence the default model rule;
- distinguished an MFH3 estimation error from a returned non-converged fit and
  selected MFH2 automatically in either case;
- used the converged MFH3 `refvarTest` contrasts for variance-structure
  selection, with Bonferroni as the conservative default and raw/BH results
  retained for review;
- corrected the wizard description of MFH1: its random-effects covariance is
  diagonal with time-specific variances, while sampling-error covariance may
  be full;
- corrected the MFH3 MCPE bootstrap to include the model's
  `u0 ~ N(0,1)` initial state before the AR(1) recursion; and
- added bootstrap Monte Carlo standard errors, refit counts, covariance-repair
  counts, and explicit assurance status to the final report and CSV outputs.

## Post-5.2.0-rc.6 working revision - 2026-08-24

- simplified `sm_out` for UFH and MFH: a missing/non-finite direct variance or
  a direct variance strictly below 0.001 is replaced by its smoothed variance;
  direct variances equal to or above 0.001 are retained;
- added an explicit National benchmarking level in both interfaces, alongside
  grouped benchmarking, so the population-weighted domain estimate is
  constrained to the direct national estimate; and
- updated the default Anthropic model to `claude-sonnet-4-6`, made OpenAI and
  Anthropic model IDs configurable by environment variable, and exposed useful
  provider error details without recording API keys;
- interleaved all seven AI interpretation blocks with their corresponding
  statistical sections in `final_report.html`; and
- retired the redundant `comparison_ai_note.html` transition output so a run
  produces one combined human-readable report.

## 5.2.0-rc.6 - 2026-08-23

- deferred the only `final_report.html` render until statistical processing and
  optional AI interpretation generation have both completed;
- merged AI interpretations into a clearly labelled appendix in the final
  report while retaining the standalone companion note for one deprecated
  transition release;
- added `outputs/data/ai_interpretations.rds` with provider/model metadata,
  consent and inclusion flags, timestamps, prompt/schema versions, human-review
  status, and explicit generated/failed/disabled status for all seven sections;
- made partial and total provider failures visible in the report rather than
  leaving silent gaps, with sanitized error summaries and stale-artifact cleanup;
- escaped all provider-generated text before HTML insertion and added a
  warning-only numeric-provenance check; and
- added mocked, network-free regression tests for AI-off, complete, partial-
  failure, secret-redaction, metadata persistence, and hostile-HTML cases.

## 5.2.0-rc.5 - 2026-08-23

- corrected the `msae::eblupMFH3` compatibility patch so missing call arguments
  remain missing and valid MFH3 calls are no longer corrupted;
- distinguished genuine MFH3 non-convergence from computational errors in the
  run log, artifacts, report warning, and fallback reason;
- made custom UFH and MFH covariate lists act as LASSO candidate pools when
  screening is enabled and as fixed specifications when it is disabled;
- allowed Comparison to continue with clearly labeled unbenchmarked estimates
  when a boundary MFH fit cannot supply benchmark inputs, and added
  `benchmark_status.csv`;
- removed avoidable log-transform warnings and made mean-welfare
  back-transformation messages state the selected bias-correction policy; and
- hardened wizard clean-manifest exclusions and expanded regression and option-
  matrix coverage for the corrected behavior.

## 5.2.0-rc.4 - 2026-08-21

- changed the primary domain-change decision rule and figure coloring to the
  pointwise two-sided test at alpha = 0.05, so red points correspond directly
  to pointwise 95% confidence intervals that exclude zero; retained BH-adjusted
  p-values and flags as supplementary sensitivity outputs;
- fixed run-metadata input-manifest construction when optional benchmark and
  population paths are absent, and persisted terminal pipeline errors in the
  per-run log;
- anchored UFH, MFH, Comparison, and final-report paths to the running package
  copy so nested clean/wizard builds cannot source stale parent-repository code;
- made arcsine UFH estimation robust to direct domain rates of exactly zero or
  one by replacing undefined design-effect calculations with the observed
  domain sample size and recording the affected domains in the step log;
- explicitly printed the MFH numerical-diagnostics table in the final report;
- recorded a labeled, low-cost condition-number estimate on successful
  Cholesky paths while retaining exact condition numbers on fallback paths;
- added the condition-number method to CSV and run-metadata diagnostics and
  hardened the no-extended-diagnostics robust-refit status;
- made clean-release document selection version-aware instead of maintaining a
  per-release exclusion list;
- expanded regression tests for ill-conditioned positive-definite matrices,
  report rendering, and qualified or bare unsafe convergence expressions;
- corrected the guidance cover version and refreshed the guidance, download
  instructions, dashboard guide, and technical-note version statements; and
- corrected the dashboard guide's title and contributor metadata.

## 5.2.0-rc.3 - 2026-08-21

- added a structured MFH numerical-diagnostics export and persisted inversion,
  robust-refit, and g3/MSE availability status in run metadata;
- surfaced MFH numerical warnings in the run log and final report;
- strengthened the bootstrap convergence regression test so it detects the
  formerly defective qualified expressions;
- changed the clean builder to allow only the literature inventory README and
  exclude every other file in that directory;
- documented the analysis seed, bootstrap-replication defaults and production
  guidance, and raw/BH-adjusted change-inference fields;
- refreshed Word metadata and the versioned guidance, download instructions,
  and dashboard guide; and
- moved exact condition-number calculation off the successful Cholesky path.

## 5.2.0-rc.2 - 2026-08-21

- scoped the MIT grant to software source code and added rights, governance,
  third-party, data-provenance, and Git-history remediation notices;
- corrected H18: robust MFH2 now reports failed Fisher-information inversion
  and unavailable g3/MSE instead of silently substituting zero;
- corrected M18 labeling and added a complete disposition for all 56 findings;
- made MFH bootstrap loops safe when only one period is supplied and hardened
  convergence checks;
- refreshed the guidance note, download instructions, and dashboard guide for
  the history-free 5.2.0-rc.2 clean distribution and AI-consent workflow;
- fixed root-manifest self-inclusion and excluded stale local diagnostics from
  the clean release.

## 5.2.0-rc.1 - 2026-08-21

Revision candidate based on the exact `v5.1.0` release commit
`cd04d479e0484ae98e3ef8299db29ac1f0f944b7`.

- made optional LASSO screening deterministic and recorded its seed;
- made the MFH MCPE bootstrap count configurable (interactive default: 200);
- replaced the MFH absolute lower-variance cutoff with a configurable relative
  rule, disabled for positive variances by default pending method-owner review;
- stated UFH period-independence change variance explicitly and added
  Benjamini-Hochberg-adjusted change-test results;
- exposed MFH covariance fallback inputs and decisions in output tables;
- stopped the pipeline when input loading fails;
- restricted complete-case filtering to required UFH estimation fields;
- used a shared complete-case mask in the robust MFH2 refit;
- added application version, input hashes, seed, package versions, and session
  information to every run before the report is rendered;
- removed the duplicate dashboard report render;
- added a country/territory field instead of hard-coded Greece labels;
- added explicit external-AI transfer consent, configurable API base URLs,
  neutral prompts, and anonymized geographic ranks/magnitudes;
- strengthened tabular and geometry input validation and ZIP isolation;
- added tests, CI, release-manifest tooling, governance notes, and a clean
  release builder.

This is a release candidate, not an approved production release. See
`docs/REVISION_STATUS.md` and `docs/RELEASE_CHECKLIST.md`.
