# EU SAE Workbench — guided version (wizard)

Wizard version: **5.2.0-rc.6-wizard.5.17**
Underlying EU SAE package: **5.2.0-rc.6**

w5p validates consumed population/target keys and MFH panel completeness before output cleanup. Named matrix years are matched by label; duplicate required keys are rejected. UFH exports raw Direct uncertainty and separately records its working variances in `outputs/tables/ufh_variance_audit.csv`. Standalone MFH figures retain pointwise and inference-status qualifications. See [methodological departures and their justification](../../guidance/MOLINA_ROMERO_DEVIATIONS_w5p.md) and the [fresh validation receipt](../../validation/W5P_VALIDATION_RECEIPT.md).

This is the clean 5.2.0-rc.6 application package with an additional guided
front end. The statistical pipeline and the classic dashboard remain in
`app.R`; `app_wizard.R`, the guided version, presents the same inputs as seven
sequential steps and reuses the same server logic.

## Included entry points

| File | Purpose |
|---|---|
| `Start_Here/Start_Wizard.bat` | Launches the seven-step guided version on Windows, normally on localhost port 7788 |
| `Start_Here/Start_Wizard.command` | Launches the seven-step guided version on macOS or Linux |
| `app_wizard.R` | Guided version (wizard) front end |
| `Start_Here/Start_Dashboard.bat` | Launches the classic dashboard on Windows, normally on localhost port 7777 |
| `Start_Here/Start_Dashboard.command` | Launches the classic dashboard on macOS or Linux |
| `app.R` | 5.2.0-rc.6 classic dashboard and shared server |

Both interfaces may run at the same time because they use different ports.

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
is occupied. Keep the launcher window open while using the Workbench. On the
front page, choose **New model run** (default settings) or **Load saved
configuration**. As an alternative, open `app_wizard.R` in RStudio and select **Run App**.

Two example datasets are included, both for learning and testing only.
`Data/simulated/` holds fully synthetic files built by an included seeded script.
`Data/Spain_2y/` holds the synthetic 2012–2013 Spain teaching example, derived
from the GPL-2 `sae` example -- see `Data/Spain_2y/START_HERE.md` for its tested
configurations and `Data/Spain_2y/README.md` for attribution and limitations.
The original `Data/Spain/` remains in the repository working copy but is excluded
from the release. Spain_2y does not reproduce historical guidance results.
Neither example may feed a real estimate. For actual
analyses, select your own survey, auxiliary-covariate, and geometry files in
step 1.

## The seven steps

Required fields carry a red asterisk.

1. **Input data** — survey, auxiliary, geometry, and optional population
   files. For mean welfare in constant prices, an optional **Consumer price
   index** file holds one country's CPI by year (see Configure analysis).
2. **Map variables** — survey columns, **Each row of the survey file is** (a
   household or a person), an optional household ID, and the
   auxiliary/geometry join keys. With a household, population_weight = weight
   × household size; with a person, the weight is used as it is and household
   size is not needed. Choosing a household for a file with one row per person
   would count each person once per household member; with a household ID,
   readiness Test 0f stops the run in that case.
3. **Configure analysis** — the two analysis years (chosen from the years found
   in the survey file), country or territory, reproducibility seed, and the
   indicator: poverty (FGT) or mean welfare and its required settings.
   For mean welfare, **Welfare in the survey data is in** says which prices
   the survey's income or expenditure is in:
   - **current prices: convert with a price index**: give a consumer price
     index (for example the CPI or HICP), and the app expresses welfare in
     constant prices of a base year (below);
   - **current prices: no conversion** (the default): welfare is used as it
     is, so changes between years include inflation;
   - **constant (real) prices already**: the survey's welfare has already been
     adjusted for inflation, so no price index is needed or applied;
     optionally give the year of those prices (for example 2017), used only
     in labels such as "constant 2017 prices as provided in the survey data".
     All years must then be in the prices of the same year (and, if spatial
     price adjustments were made, on the same basis); the app cannot check
     this.

   For poverty indicators welfare is never converted: the welfare variable
   and the poverty line must already be in the same prices in each year.

   With the first choice, **Price index values** says where the index comes from:
   typed in by year, or read from the CPI file chosen in Step 1, Input data. The
   CPI file has one row per year, with a year column (for example 2013, or
   text such as 2013A00) and one or more CPI columns; you choose the **Year
   column** and the **CPI column**, and the app takes the years it needs and
   shows them, or the years that are missing. CSV files separated by commas or
   semicolons and numbers with a decimal comma (101,4) are accepted.
   **Incomes refer to** says which year's prices the incomes are in: **the
   survey year** (the default, for surveys of current income or consumption)
   or **the calendar year before the survey** (for example EU-SILC, whose 2013
   survey asks about incomes of 2012). With the second choice the app uses the
   index of 2012 for the 2013 survey; index values, the base year and
   "constant 2012 prices" then refer to the year of the incomes (the income
   year), while results keep the survey years as labels.
   **How the CPI is organised** says how the values are reported:
   - **Index, fixed reference year** (for example 2015 = 100): the index level
     for each income year;
   - **Index, previous year = 100**: annual-average indices against the year
     before (for example 103.6 for 3.6% inflation, as in Statistics Poland's
     annual table);
   - **Annual change in %**: the same as a rate (for example 3.6).

   Annual changes are needed for every year after the earliest and up to the
   latest income or base year; the app chains them into price levels.
   Welfare is multiplied by the price level of the base year / the price level
   of its income year, so all mean-welfare levels are in prices of the base
   year and changes are real changes. **Price base year** is the first income
   year by default; choose **Another year** to use, for example, 2017 prices
   or the prices of the last income year. With a fixed-reference index, the
   base year needs its own index level, from the same series (typed in, or
   found in the CPI file). Percentage changes between years are the same
   whatever the base year; only the levels change. Use annual averages for
   annual incomes, not December-on-December or monthly indices. The two
   **Incomes refer to** choices cover calendar years only: for a fiscal year,
   a rolling 12-month period before the interview, or reference periods that
   differ between households, deflate welfare before uploading the survey
   (for example household by household with the index of its own period) and
   choose **constant (real) prices already**. The run log, the readiness
   messages, the review page and the report name the CPI file and column.
4. **Configure model** — UFH and MFH choices, Bootstrap replicates (default
   500), benchmarking, covariate selection, and cross-year PSU design.

   Choose **Same identifiers represent the same PSUs across years** only when
   PSU identifiers (and stratum codes, if used) have stable meanings across years.
   Choose **The two surveys are independently sampled** only when the sampling
   design confirms independence: MFH then uses year-specific PSU groups and
   strata and forces cross-year sampling-error covariance to zero. This does
   not force the MFH random-effect covariance to zero. Choose **Not specified**
   when overlap is unknown or cannot be linked; MFH is blocked pending design
   advice. To run UFH alone, deselect MFH; its change inference assumes independent
   years. If linked PSUs are chosen but none is shared across years, readiness and
   the report give a warning. Identical code values alone do not establish linkage or independence.
   Old unchecked settings load as **Not specified**; old checked settings load
   as linked. The choice is saved with the setup and recorded in MFH outputs.
5. **Add AI assistant** — optional external-transfer consent, API key, and
   output language.
6. **Review configuration** — configuration summary, the data files of the
   configuration, and **Check data readiness** (Preflight and Data Readiness
   tabs).
7. **Run model** — optional run label, **Run model** and **Stop**, a progress
   panel with the stages of the run, then the result with buttons to open the
   report or the output folder and to view the configuration.

The default variance option is **`sm_out`** for identity/log UFH and MFH: each
direct variance is kept unless it is missing/non-finite or strictly below 0.001.
MFH defaults to **`rho_sm_out`** for the corresponding pooled-correlation
covariance. **`sm_all`** replaces all working variances with GVF predictions.
Because the GVF uses sample size only, it gives areas of similar size similar
variances whatever their poverty rate, so it can overstate the variances of
low-poverty areas; use it when direct variances are broadly unstable and the GVF
fits well (guidelines, Section 6.6). UFH log models expose the variance selector
and apply it on the log scale; arcsine UFH keeps its distinct
effective-sample-size variance. Explicit policies in saved configurations are
preserved. Changing the default can change fitted estimates and uncertainty;
raw Direct MSE remains the observed survey-design variance.

When restoring an older dashboard setup for log UFH, review the now-visible
variance choice. Older interfaces could store a hidden `sm_all` or `direct`
choice while actually applying `sm_out` to the log run. The revised interface
honors the visible stored choice and flags this legacy case. To reproduce
that earlier run, use its actual saved pipeline configuration or explicitly
select `sm_out`. This distinction concerns older dashboard setup files;
explicit policies in actual run configurations remain reproducible.

The `sm_out` policy has one simple rule: replace a direct variance
only when it is missing/non-finite or strictly below 0.001. A direct variance
equal to 0.001 is retained. Under benchmarking, choose **National** to make the
population-weighted average of the domain estimates equal the direct national
estimate, or choose **Grouped by a survey variable** and map a higher-level
survey variable to apply the constraint separately within each group. Each
domain must belong to exactly one group in the analysis years; otherwise
readiness Test 0g and the UFH and MFH steps stop with a message that names the
domain, its group codes, the years and the number of rows. A **Benchmark Target Database**
replaces the survey's figures as targets; its figures must be in the same
prices as the survey's welfare, and when the app converts welfare with a price
index they are converted in the same way. For mean welfare fitted
in logs, the benchmarking is done in currency after the back-transform: each
domain estimate is multiplied by its group's target divided by the
population-weighted average of the domain estimates in the group, so the
domain estimates average exactly to the target. Annual MSE and cross-year prediction-error moments come from a joint bootstrap
that repeats fitting, back-transformation and the final currency-scale benchmark
adjustment. Survey-derived targets are recomputed in every replicate; uploaded
targets are held fixed, so uncertainty in externally supplied targets is excluded.
Matching a target alone does not validate uncertainty.

The two-year window supports a controlled revision policy for official
statistics. For example, use (2022, 2024), then (2024, 2025), then (2025, 2026).
First publish the later year's estimate provisionally, revise it once when it
becomes the earlier year in the next pair, and then freeze it for routine
releases. Each release then revises at most one previously published year.
This avoids repeated routine revisions to several overlapping years in a
longer moving window. The NSO must manage successive windows, release vintages
and frozen figures; the app does not freeze publications automatically.
Exceptional data/method corrections follow the NSO's separate policy. Retain
each pair's joint change and uncertainty together, because annual estimates
drawn from different frozen vintages do not automatically share that inference.

In **Configure model**, the AIC/BIC *Model selection criterion* is used only for
stepwise covariate selection. If LASSO is off and covariates are entered for
both years of a model, that model uses exactly those covariates: its
criterion box shows "Not used: covariates fixed for both years", and the run
records the criterion as `none` (not used). If covariates are entered for one
year only, the criterion applies to the other year, and a note under the box
says so. With LASSO on, the entered covariates are a candidate pool and the
criterion is always used.

The step buttons are clickable. Green indicates a complete step, amber indicates
an outstanding item, and blue indicates the current step.

Selecting another survey, auxiliary or geometry file in step 1 (for example
switching from `Data/Spain_2y/` to `Data/simulated/`) updates the settings that
depend on it. A column mapping keeps its column when the new file has it;
otherwise the usual column name for that variable is chosen if the file has one
(for example `domain` or `prov`, `psu` or `ea_id`), and the field is cleared if
it does not. Covariates that the new auxiliary file lacks are removed from the
covariate lists. The analysis years keep the chosen years that the new survey
file has; a file with exactly two years supplies both, and with more years you
choose the pair. A notification lists every change. A step stays amber while a
required field is empty or a field names a column or year that the selected
files do not have. Loading a configuration is not treated as a data change: its
saved mapping is restored as it is, and a column the files lack is marked.

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
coverage. See `docs/validation/MCPE_VALIDATION_STATUS.md` for the completed checks, skipped
dependency-dependent tests, and remaining validation work.

### MFH convergence check

The MFH step independently checks the REML score, local curvature and boundary
conditions. A failed endpoint cannot support inference. MFH2 is refitted with
constrained REML when needed; all bootstrap replicates use the same acceptance
rule. A genuine zero-variance boundary is allowed. Selected-model annual MSE and
cross-year moments come from the same joint bootstrap, including correlation
boundary fits. Diagnostics are saved in `outputs/tables/mfh_convergence_check.csv`.
The auxiliary msae UFH comparison is labelled `UFH_untransformed` or `UFH_log`;
the latter is a naive log prediction and does not replace the corrected emdi UFH.

See [Methodology alignment and QER notes](../../guidance/METHODOLOGY_ALIGNMENT.md) for the
paper-to-code mapping, explicit extensions and remaining validation limits.

### Validation and consent

Navigation is deliberately soft: **Next** remains available when a step is
incomplete, and each step lists its outstanding items. **Run model** is
disabled until the three data files and the two analysis years are set, and a
run starts only after a data readiness check without ERROR. The shared rc.6
server performs its own configuration and readiness checks before analysis.

### Data Readiness

**Check data readiness** (Step 6; **1. Check data readiness** in the classic
dashboard), and every **Run model**, which repeats the check first, writes the
readiness tables to `outputs/tables/`:
`aux_covariate_summary.csv`, `national_poverty.csv`, `domain_poverty_rates.csv`,
`domain_consistency.csv`, `readiness_messages.txt` and, when cells are missing,
`missing_poverty.csv`. They are kept through the run and archived with it.
Test 0f reports the weighted population total and, when a household ID is
mapped, checks that the rows match **Each row of the survey file is**; with
grouped benchmarking, Test 0g checks that each domain belongs to one group.
Changes to the data files, mapping, years, indicator, model transformations,
LASSO, seed, bootstrap replicates, steps, benchmarking or the price settings
of mean welfare ask for a new check.

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

**Run model** (Step 7; **2. Run model** in the classic dashboard) starts the
UFH / MFH / Comparison steps, the optional AI
interpretation, the report and the archive copy in a separate R process
(`scripts/run_pipeline_bg.R`). The page stays responsive while it works: a
progress panel shows each stage with a progress bar, and the run log (a
collapsible section) follows `app_runs/<run>/run.log` live. A second click on
**Run model** is refused until the current run has ended. Do not start model
runs from two browser pages, or from the guided version and the classic
dashboard, at the same time: they share `outputs/`,
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
When welfare is converted with a price index, or is already in constant
prices (see **Configure analysis** above), these are real changes. With current prices
and no conversion they include inflation, and Data Readiness says so.

### Maps

All maps use one colour scheme (`R/map_style.R`). Level maps (poverty rates,
RMSE, mean welfare) use the reversed magma scale, lighter = lower and darker =
higher; change maps (poverty change, growth rates) use a blue–light grey–red scale
with light grey at zero. In the final report (Comparison step), all poverty maps
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
If AI is requested, both final report formats include labelled
interpretation blocks with their corresponding statistical sections and record
their statuses and provider/model metadata. Failed sections are shown
explicitly. The statistical results remain authoritative, and every AI block
requires human review before dissemination. The change-significance section
includes the complete pointwise/BH/Bonferroni table, the change-and-RMSE box
plots, the paired UFH-MFH figures of changes and interval widths, and links to the consolidated Excel result tables in
`outputs/data/`.

The final HTML and editable Word reports also include an **AI recommendation
on UFH or MFH**. It weighs the available aggregate evidence on fit and
convergence, matched precision, change uncertainty, diagnostic limitations and
data completeness. It can prefer UFH or MFH, find no clear preference, or
explain that the available evidence is insufficient. It distinguishes annual
levels from changes over time and treats failed or boundary-sensitive inference
appropriately. Lower estimated MSE, narrower intervals, closer agreement with
Direct estimates or more significant domains alone do not establish a better
model. The recommendation is advisory and does not change the fitted model,
estimates or statistical selection settings. The analyst remains responsible
for model choice and release decisions. Provider failures are shown explicitly;
turning AI report writing off omits this recommendation.

### Saving and loading configurations

**Save configuration** records the data files, the variable mapping and the
analysis and model settings, and copies files selected with Browse to
`app_runs/_last_setup_files`. A successful run also saves its configuration,
and each run folder holds its own `model_run_configuration.yml`. **Load
configuration** (on every step) restores the last saved configuration or a
configuration file, which must contain an `inputs` section; on the front page,
**Load saved configuration** does the same. After a successful load, the guided
version moves to Step 6, Review configuration, and both versions warn when a
data file has changed since the configuration was saved (SHA-256 checksums).
**Reset to defaults** deletes the last saved configuration and its file copies.
API keys and external-transfer consent are not persisted and must be entered
again for each session.

### Guides and About

The **Guides and notes** menu opens the three guides in `docs/instructions`
(Guide 1, Install and start; Guide 2, Running the Workbench; Guide 3,
Estimating poverty and welfare), in English and, under their own headings,
in Polish (`_PL` files) and Greek (`_GR` files), then the download
instructions, the guidelines note, the methodology mapping, the validation
status and the changelog.
**About**, at the top right of the front page and of the configuration pages,
shows the version.

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

See `docs/maintenance/WIZARD_RELEASE_NOTICE.txt` and `docs/maintenance/RELEASE_CHECKLIST.md`. This is a
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
