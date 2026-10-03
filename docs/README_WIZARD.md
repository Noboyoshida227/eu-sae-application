# EU SAE Dashboard — Wizard edition

Wizard version: **5.2.0-rc.6-wizard.5.10**
Underlying EU SAE package: **5.2.0-rc.6**

This is the clean 5.2.0-rc.6 application package with an additional guided
front end. The statistical pipeline and the classic dashboard remain in
`app.R`; `app_wizard.R` presents the same inputs as six sequential steps and
reuses the same server logic.

## Included entry points

| File | Purpose |
|---|---|
| `Start_Here/Start_Wizard.bat` | Launches the six-step wizard on Windows, normally on localhost port 7788 |
| `Start_Here/Start_Wizard.command` | Launches the six-step wizard on macOS or Linux |
| `app_wizard.R` | Wizard front end |
| `Start_Here/Start_Dashboard.bat` | Launches the classic dashboard on Windows, normally on localhost port 7777 |
| `Start_Here/Start_Dashboard.command` | Launches the classic dashboard on macOS or Linux |
| `app.R` | 5.2.0-rc.6 classic dashboard and shared server |

Both dashboards may run at the same time because they use different ports.

## Run the wizard

Download the application zip from the Releases page,
<https://github.com/Noboyoshida227/eu-sae-application/releases> (under **Assets**; not the automatic "Source code"
archives), and extract the whole zip into a new folder.

R 4.2.0 or later is required. Use the newest version that your organization has
approved and made available; the absolute latest R release is not required. On
a managed computer, keep the approved R 4.2+ installation unless IT directs an
upgrade.

Report creation also needs Pandoc. Nothing to install in advance: the launcher
reuses a Pandoc that is already on the computer (RStudio Desktop, Quarto,
Positron, Homebrew or [standalone Pandoc](https://pandoc.org/installing.html))
and otherwise downloads a pinned, checksum-verified copy into your user profile
the first time (26-42 MB, no administrator rights). Without internet access the
analysis still runs and the run ends as *Analysis completed - report
unavailable*; see `Start_Here/README.md`.

On Windows, double-click:

```bat
Start_Here/Start_Wizard.bat
```

On macOS, double-click `Start_Here/Start_Wizard.command`. The first launch may
require Control-clicking the file and choosing **Open**. On Linux, run
`bash Start_Here/Start_Wizard.command`. See `Start_Here/README.md` for macOS
Gatekeeper and executable-permission help.

The launcher opens `http://127.0.0.1:7788` and tries successive ports if 7788
is occupied. Keep the launcher window open while using the dashboard. As an
alternative, open `app_wizard.R` in RStudio and select **Run App**.

Two example datasets are included, both for learning and testing only.
`Data/simulated/` holds fully synthetic files built by an included seeded script.
`Data/Spain/` holds the Spain province example used in the guidance notes, derived
from the GPL-2 `sae` package -- see `Data/Spain/README.md` for its attribution,
licence and open provenance item. Neither may feed a real estimate. For actual
analyses, select your own survey, auxiliary-covariate, and geometry files in
step 1.

## Wizard steps

1. **Data** — country or territory, analysis years, reproducibility seed, run
   label, and survey, auxiliary, geometry, and optional population files. For
   mean welfare in constant prices, an optional **Consumer price index** file
   holds one country's CPI by year (see the Indicator step).
2. **Mapping** — survey columns and the auxiliary/geometry join keys.
3. **Indicator** — poverty (FGT) or mean welfare and its required settings.
   For mean welfare, tick **Express welfare in constant prices** when the
   survey welfare is in current prices, and give a consumer price index (for
   example the CPI or HICP). **Price index values** says where it comes from:
   typed in by year, or read from the CPI file chosen in the Data step. The
   CPI file has one row per year, with a year column (for example 2013, or
   text such as 2013A00) and one or more CPI columns; you choose the **Year
   column** and the **CPI column**, and the app takes the years it needs and
   shows them, or the years that are missing. CSV files separated by commas or
   semicolons and numbers with a decimal comma (101,4) are accepted.
   **How the CPI is organised** says how the values are reported:
   - **Index, fixed reference year** (for example 2015 = 100): the index level
     for each analysis year;
   - **Index, previous year = 100**: annual-average indices against the year
     before (for example 103.6 for 3.6% inflation, as in Statistics Poland's
     annual table);
   - **Annual change in %**: the same as a rate (for example 3.6).

   Annual changes are needed for every year after the earliest and up to the
   latest analysis or base year; the app chains them into price levels.
   Welfare is multiplied by the price level of the base year / the price level
   of its own year, so all mean-welfare levels are in prices of the base year
   and changes are real changes. **Price base year** is the first analysis
   year by default; choose **Another year** to use, for example, 2017 prices
   or the prices of the last analysis year. With a fixed-reference index, the
   base year needs its own index level, from the same series (typed in, or
   found in the CPI file). Percentage changes between years are the same
   whatever the base year; only the levels change. Use annual averages for
   annual incomes, not December-on-December or monthly indices, and if incomes
   refer to an earlier period than the survey year (in EU-SILC, the previous
   calendar year), use the index of that period. The run log, the readiness
   messages, the review page and the report name the CPI file and column.
4. **Models** — UFH and MFH choices, MCPE bootstrap replicates, benchmarking,
   covariate selection, and PSU consistency.
5. **AI Assistant** — optional external-transfer consent, API key, and output
   language.
6. **Review & Run** — settings summary, preflight/readiness checks, and run.

For UFH and MFH, `sm_out` now has one simple rule: replace a direct variance
only when it is missing/non-finite or strictly below 0.001. A direct variance
equal to 0.001 is retained. Under benchmarking, choose **National** to make the
population-weighted average of the domain estimates equal the direct national
estimate, or choose **Grouped** and map a higher-level survey variable to apply
the constraint separately within each group.

In **Models**, the AIC/BIC *Model selection criterion* is used only for
stepwise covariate selection. If LASSO is off and covariates are entered for
both years of a model, that model uses exactly those covariates: its
criterion box shows "Not used: covariates fixed for both years", and the run
records the criterion as `none` (not used). If covariates are entered for one
year only, the criterion applies to the other year, and a note under the box
says so. With LASSO on, the entered covariates are a candidate pool and the
criterion is always used.

The breadcrumb is clickable. Green indicates a complete step, amber indicates
an outstanding item, and blue indicates the current step.

### MFH3/MFH2 model-selection rule

**MFH2 is the default MFH model.** If the user selects MFH3, the app follows the
Molina-Romero sequence: it fits MFH3 first; if MFH3 errors or does not converge,
the run explicitly records the problem and uses MFH2. If MFH3 converges, the app
evaluates the equality of its time-specific random-effect variances. MFH3 is
retained only when at least one contrast remains significant after the selected
adjustment; otherwise the app uses MFH2. Bonferroni is the default
model-selection adjustment. The raw, Bonferroni-adjusted, and BH-adjusted
p-values are all saved in
`outputs/tables/mfh_variance_structure_selection.csv`. With two years there is
only one contrast, so the adjustments are identical.
When MFH1 or MFH2 is chosen, the rule is not run: the report's "MFH Variance
Structure" section then describes only the chosen model and does not discuss
MFH3.

This MFH3 control is shown only when MFH3 is selected or requested as a
sensitivity fit. It does **not** adjust poverty-change tests across geographic
domains. Poverty-change figures and headline counts use pointwise p-values and
95% confidence intervals; the final report and exported comparison table also
show BH and Bonferroni domain-level sensitivity results.

MFH1 remains available as a sensitivity model. It uses
time-specific but mutually independent random effects; it does not use an
unstructured random-effects covariance matrix.

The MCPE bootstrap saves execution and Monte Carlo standard-error diagnostics
in `outputs/tables/mfh_mcpe_validation.csv`. These diagnostics support run-level
review but do not replace independent validation of MCPE bias and interval
coverage. See `docs/MCPE_VALIDATION_STATUS.md` for the completed checks, skipped
dependency-dependent tests, and remaining validation work.

### MFH convergence check

The MFH variance parameters are msae's estimates. After fitting, the MFH step
checks each fitted model (MFH1, MFH2 and, when fitted, MFH3) at msae's
reported parameters: it computes the REML score and the Newton decrement,
which are zero at a REML maximum. The result is in
`outputs/tables/mfh_convergence_check.csv` and the report's "MFH Convergence
Check" section, with status `ok`, `not_at_maximum` (msae reported convergence
at a point that is not a maximum) or `not_converged` (msae stopped at its
iteration limit). If the selected model is not `ok`, the run shows a warning
and the report asks for review. The UFH that the MFH step fits with msae is
labelled `UFH_untransformed` (or `UFH_log`) in `pov_mfh.xlsx` and the MFH
figures, to distinguish it from the UFH step's model.

### Validation and consent

Navigation is deliberately soft: **Next** remains available when a step is
incomplete, and the wizard lists the outstanding items. The final run control
is disabled until the fatal data prerequisites are present. The shared rc.6
server performs its own configuration and readiness checks before analysis.

### Data Readiness

**1. Check Data Readiness** (and every **Run Analysis**, which repeats the
check first) writes the readiness tables to `outputs/tables/`:
`aux_covariate_summary.csv`, `national_poverty.csv`, `domain_poverty_rates.csv`,
`domain_consistency.csv`, `readiness_messages.txt` and, when cells are missing,
`missing_poverty.csv`. They are kept through the run and archived with it.

The *Auxiliary Covariate Summary* reports, for each covariate and each analysis
year plus "All years", the mean, standard error, number of domains and the
correlation with the target indicator, together with the two-sided p-value of
the Pearson correlation test (`cor_pvalue`) and significance codes
(`cor_signif`: `***` p < 0.001, `**` p < 0.01, `*` p < 0.05, `.` p < 0.1).
Covariates are listed from the most to the least significant pooled
correlation, with each covariate's year rows kept together. These bivariate
tests are a screening aid; they do not replace the model-based covariate
selection in UFH and MFH.

### Running and stopping

**2. Run Analysis** starts the UFH / MFH / Comparison steps, the optional AI
interpretation, the report and the archive copy in a separate R process
(`scripts/run_pipeline_bg.R`). The page stays responsive while it works: the
log pane follows `app_runs/<run>/run.log` live and the progress bar follows
the step in progress. A second click on **Run Analysis** is refused until the
current run has ended. Do not start analyses from two browser pages, or from
the wizard and the classic dashboard, at the same time: they share `outputs/`,
and the second run clears the first run's files. **Stop** ends
the run: the R process of the current step is terminated and the run
finishes with the status *Stopped by user*. Files written before the stop
remain in `outputs/` until the next run; nothing is archived and no report is
produced. Press **Stop** before closing the black launcher window.

### Changes in mean welfare

In mean-welfare runs the report gives each change between the two years as a
percentage change of the estimated mean, 100 × (mean in the later year /
mean in the earlier year − 1). The 95% interval and the p-value come from the
log of that ratio, using the MSEs of the two estimates and their covariance
(from the MCPE for MFH; UFH treats the years as independent), so the interval
is not symmetric around the estimate. Change maps, significance plots, the
significance table and the change and interval-width comparisons use these
percentage changes; the difference in currency units is kept in
`statistical_significance_comparison.xlsx` (columns ending in `_eur`). The UFH
and MFH step figures in `outputs/figures/` still show currency differences.
With a price index (see **Indicator** above) these are real changes; without
one they include inflation, and Data Readiness says so.

### Maps

All maps use one colour scheme (`R/map_style.R`). Level maps (poverty rates,
RMSE, mean welfare) use the reversed magma scale, lighter = lower and darker =
higher; change maps (poverty change, growth rates) use a blue–white–red scale
with white at zero. In the final report (Comparison step), all poverty maps
(every method, both years) share one legend range, all RMSE maps share
another, and the poverty-change maps share one range that is symmetric around
zero, so the same colour means the same value on every map of that kind. The
UFH and MFH step figures in `outputs/figures/` use one range across both years
within their own step; the growth-rate maps have their own scale. Domains
without an estimate are grey. Maps drawn on the bundled Spain boundary carry
the IGN credit required by its CC BY 4.0 licence.

The report (HTML and Word) shows the poverty maps and the RMSE maps as grids:
one row per estimation method and one column per year, so differences between
methods read down a column and changes over time along a row. The rows are
Direct, UFH and the selected MFH model; with benchmarking on, UFH benchmarked
follows UFH and the benchmarked MFH row follows MFH (5 rows). The grids are
saved as `grid_estimates.png` in `outputs/figures/poverty_maps/` and
`grid_rmse.png` in `outputs/figures/rmse_maps/`. The single maps are still
saved in the same folders.

In the HTML report, each grid has a **Methods** drop-down list with one tick
box per method. Only the ticked methods are shown, so a reader can compare,
for example, UFH with UFH benchmarked, or Direct, UFH and MFH2; **Select all**
and **Clear** reset the list. The poverty and RMSE grids have separate lists.
The panels for this view are in the `grid_panels/` subfolders. The Word report
cannot run the list and shows the full grid.

The report also shows, in one row, box plots of the change between the two
years across domains and of the RMSE of that change, with one box per method:
Direct, UFH, the selected MFH model and, with benchmarking on, UFH benchmarked
and MFH benchmarked. For poverty indicators both are in percentage points; for
mean welfare the change is in ln mean welfare (ln of the later mean minus ln of
the earlier mean) and the RMSE is on the same log scale. The RMSE of a direct
change adds the two years' direct MSEs; UFH also treats the years as
independent, and MFH uses the covariance between the years. In the HTML report
a **Methods** list selects the boxes shown, the axes fit the selected methods,
and hovering over a point shows its domain and value; the Word report shows all
methods. The values are in `outputs/tables/change_rmse_by_method.csv` and in
the "Change and RMSE" sheets of `change_estimate_comparison.xlsx` and
`EU_SAE_results.xlsx`; the figure is
`outputs/figures/change_comparisons/change_rmse_boxplots.png`.

### AI assistance

AI assistance is optional. When enabled, it requires both an API key and a
separate acknowledgement that aggregate estimates, uncertainty measures,
diagnostics, and analysis context will be sent to the chosen external provider.
Raw microdata are not sent; comparison prompts remove geographic identifiers.
If AI is requested, both final report formats interleave all seven labelled
interpretation blocks with their corresponding statistical sections and records
their statuses and provider/model metadata. Failed sections are shown
explicitly. The statistical results remain authoritative, and every AI block
requires human review before dissemination. The change-significance section
includes the complete pointwise/BH/Bonferroni table, UFH-MFH confidence-interval
width figures, estimated-change distribution and paired-domain figures, and links to the consolidated Excel result tables in
`outputs/data/`.

### Loading a saved setup

**Load Last Setup** is available from every step. After a successful load, the
wizard moves to the review step. API keys and external-transfer consent are not
persisted and must be entered again for each session.

## Architecture and maintenance rule

At launch, `app_wizard.R` parses `app.R`, evaluates its top-level definitions
except the classic `ui` and launcher, and reuses `app.R`'s `server()` function.
The input IDs in the two interfaces must remain in parity.

The steps use `tabsetPanel(type = "hidden")`, which keeps off-screen inputs in
the browser DOM. Do not replace the step bodies with on-demand `renderUI` /
`uiOutput` construction: doing so can make off-screen inputs `NULL` and break
the shared server contract.

## Verification

From this folder, run:

```text
Rscript tests/run_tests.R
Rscript tools/check_ui_parity.R
```

The first command covers the rc.6 package tests plus wizard parsing, version,
and required-control checks. The second renders both interfaces and verifies
that every classic-dashboard element ID appears exactly once in the wizard.

See `docs/WIZARD_RELEASE_NOTICE.txt` and `docs/RELEASE_CHECKLIST.md`. This is a
release candidate published for review and testing. Whether to publish estimates
as official statistics is for each national statistical office to decide.

## Input folder migration

See `Data/README.md` for the new example layout and saved-setup compatibility.
The user-facing folder is `Data/`; outputs remain under `outputs/`.

## HTML and editable Word outputs

After a successful run, open `outputs/final_report.html` in a browser or
`outputs/final_report.docx` in Word. Both contain the same findings and labeled
AI interpretations when requested. Word text and tables are editable; figures
are embedded images. Save a separate working copy before editing. Later runs
replace current outputs; archived copies are retained under
`app_runs/<timestamp>_<run_label>/outputs/`. Keep `outputs/data/` with the reports
for Excel links. The clean distribution contains no generated reports.

Both formats require Pandoc, found or downloaded automatically as described
above; the Word report needs Pandoc 2.17 or later. If only an older Pandoc is
available and a newer one cannot be downloaded, the HTML report is produced and
the log explains why the Word report was skipped. Word formatting also requires
`xml2` and `zip`, installed by `install_packages.R`. If Word is missing, inspect the run
log, resolve the conversion warning, and regenerate; the completed HTML is
retained.
The new figures are in `outputs/figures/change_comparisons/`, with values in
`outputs/data/change_estimate_comparison.xlsx` and `EU_SAE_results.xlsx`.
They compare signed estimated changes, not CI widths. A tighter distribution
across domains alone does not establish smaller MSE or statistical significance.
