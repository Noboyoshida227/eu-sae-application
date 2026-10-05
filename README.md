# EU SAE Application Package 5.2.0-rc.6

## Start here

Download the package from the [Releases page](https://github.com/Noboyoshida227/eu-sae-application/releases): under **Assets**, take
the application zip (`EU_SAE_520_….zip`), not the automatic "Source code"
archives. Compare its SHA-256 with the value on the release page, then extract
the whole zip. This is an independent project maintained by Nobuo Yoshida, not a
World Bank Group repository. The package is a release candidate for review and
testing. Whether to publish estimates as official statistics is for each
national statistical office to decide.

Install **R 4.2 or later** and run `install_packages.R` once to install the
required packages. Use the newest R version that your organization has approved
and made available; installing the absolute latest release is not required.
Report rendering needs Pandoc: the launcher reuses one already installed
(RStudio Desktop, Quarto, Positron, Homebrew, or [standalone
Pandoc](https://pandoc.org/installing.html)) and otherwise downloads a pinned,
checksum-verified copy into your user profile on first run (no administrator
rights). Without it the analysis still runs and the report is skipped; see
`Start_Here/README.md`. The `sf` package also needs its
platform-specific system libraries. Keep the launcher window open while using
the application.

| Interface | Launch |
|---|---|
| Guided wizard (recommended on Windows) | Double-click `Start_Here/Start_Wizard.bat`; normally port 7788 |
| Classic dashboard on Windows | Double-click `Start_Here/Start_Dashboard.bat`; normally port 7777 |
| Guided wizard on macOS | Double-click `Start_Here/Start_Wizard.command` |
| Classic dashboard on macOS | Double-click `Start_Here/Start_Dashboard.command` |
| Guided wizard on Linux | Run `bash Start_Here/Start_Wizard.command` |
| Classic dashboard on Linux | Run `bash Start_Here/Start_Dashboard.command` |

On Windows or macOS, open the **Start_Here** folder and choose a launcher. Keep
this folder inside the extracted package; it runs the application from its
parent directory. On first use, macOS may require Control-clicking the launcher
and choosing **Open**. See `Start_Here/README.md` for Gatekeeper and executable-
permission help.

Ports advance if occupied. There is no supplied wizard shell launcher; manual
launch through R remains possible from the package root using
`source("app_wizard.R")` after installing dependencies.

- [Download and verification instructions](docs/instructions/EU_SAE_Download_Instructions_5_2_0_rc_6_wizard_5_11.pdf)
- [Wizard reference](docs/README_WIZARD.md) and [slide guide](docs/instructions/EU_SAE_User_Guide_5_2_0_rc_6_wizard_5_11.pptx)
- [Methodological guidance](docs/guidance/guidelines_v5_2_0_rc6_wizard.docx)
- [Examples and your own input folders](Data/README.md)


This is a revised release candidate based on the exact v5.1.0 tag. It includes
the Shiny dashboard, UFH/MFH analysis scripts, reporting, audit controls, tests,
and guidance. The open review items are listed in `docs/REVISION_STATUS.md`
and `docs/RELEASE_CHECKLIST.md`.

## HTML and Word reports

Completed runs keep `outputs/final_report.html` and also create
`outputs/final_report.docx`. Word contains the same findings, figures, full result
tables and labelled AI interpretations (when requested), with editable text and
tables. Wide tables are arranged into readable panels with identifier columns
repeated; single-record diagnostics use a field/value layout. Figures are
embedded images. The HTML remains the interactive version, and Excel links need
the adjacent `outputs/data/` folder. The Word export uses the same Pandoc as the
HTML report, plus the R packages `xml2` and `zip` installed by
`install_packages.R`. A conversion failure is logged without discarding the HTML.
If Word is missing, check the run log, resolve missing dependencies, and
regenerate the report. Save a separate Word working copy before editing; later
runs replace current outputs. Archived copies are under
`app_runs/<timestamp>_<run_label>/outputs/`. The clean ZIP does not include
generated reports.

Comparison runs also produce a distribution and paired-domain plot of estimated
changes in `outputs/figures/change_comparisons/`, alongside the existing
confidence-interval-width figures. Data and summaries are in
`outputs/data/change_estimate_comparison.xlsx` and `EU_SAE_results.xlsx`.

## Required inputs

Browse to three approved local inputs in the dashboard:

1. household survey microdata;
2. domain-level auxiliary covariates;
3. domain geometry.

Tabular formats: RDS/RData, CSV/TSV/TXT/DAT, Stata, SPSS, SAS, Parquet,
Feather, and Excel. Text files are read as UTF-8 when they are valid UTF-8 (a
byte-order mark is removed) and otherwise as Latin-1 with a warning, so no rows
are lost; set `SAE_INPUT_ENCODING` before launch to force a specific source
encoding. Geometry formats: sf
RDS/RData, zipped ESRI shapefile, GeoPackage, GeoJSON, KML, and GML.

The review candidate includes the documented Spain example and fully synthetic
examples under `Data/Spain/` and `Data/simulated/`. Neither provides real
estimates. This candidate uses documented IGN/CNIG CartoBase ANE boundaries
under CC BY 4.0; survey derivation and other release approvals remain open.
See [data limitations and map attribution](Data/Spain/README.md) and `THIRD_PARTY_NOTICES.md`.

## Readiness check, runs and maps

- **1. Check Data Readiness** loads the inputs and checks columns, years, domain
  keys, missing direct estimates and national totals. Its *Auxiliary Covariate
  Summary* shows, for each covariate, the mean, its standard error and the
  correlation with the target indicator, with the two-sided p-value of that
  correlation and significance codes (`***` p < 0.001, `**` p < 0.01, `*`
  p < 0.05, `.` p < 0.1), by year and pooled; covariates are listed from the
  most to the least significant. Treat these as a screening aid only: model
  selection happens in UFH/MFH. The readiness tables are written to
  `outputs/tables/` (`aux_covariate_summary.csv` and others), refreshed when a
  run starts, and archived with the run.
- **2. Run Analysis** runs UFH, MFH, Comparison and the report in a separate R
  process, so the page stays responsive and the log follows the run live. A
  second click on **Run Analysis** is refused while a run is active. Do not
  start analyses from two browser pages, or from the wizard and the dashboard,
  at the same time: they share `outputs/`. **Stop** ends a run, which then
  finishes as *Stopped by user*.
- **Maps** use one colour scheme. Level maps (poverty rates, RMSE, mean
  welfare) run from light (lower) to dark (higher); change maps use
  blue–white–red with white at zero. In the final report, all poverty maps
  (every method, both years) share one legend range, all RMSE maps share
  another, and the poverty-change maps share one range centred on zero, so the
  same colour means the same value on every map of that kind. The UFH and MFH
  step figures in `outputs/figures/` use one range across both years within
  their own step. Domains without an estimate are grey.

## Reproducibility controls

- `Analysis seed` controls LASSO folds and MFH bootstrap draws.
- `MCPE bootstrap replicates` defaults to 200 for interaction; production runs
  should use at least 500 only after a stability study.
- Each run records VERSION, config, input filenames and SHA-256 hashes, package
  versions, R session information, seed, and MCPE count.
- UFH change inference explicitly states its period-independence assumption.
- The primary change status and red/gray figures use pointwise inference at
  alpha = 0.05, matching whether the pointwise 95% confidence interval excludes
  zero. Change tables and the final report also show Benjamini-Hochberg- and
  Bonferroni-adjusted p-values and flags as supplementary sensitivity
  information. These domain-change adjustments are separate from the MFH3
  reference-variance test adjustment.
- When a custom covariate list is supplied, it is the LASSO candidate pool if
  LASSO is enabled and the fixed model specification if LASSO is disabled.
- If MFH3 is requested but does not converge, the report and run artifacts say
  so explicitly before using MFH2. Computational MFH3 errors are labeled
  separately rather than being reported as non-convergence.
- If a boundary MFH fit cannot produce benchmarked estimates, Comparison
  continues with unbenchmarked estimates and records the reason in
  `outputs/tables/benchmark_status.csv`.

Generated files are placed in `outputs/` and archived under `app_runs/`. Input
files are not copied into a run archive. `Save Current Setup` is the only
user-initiated feature that makes local convenience copies under
`app_runs/_last_setup_files`.

The Comparison step also creates `outputs/data/EU_SAE_results.xlsx`, a
consolidated workbook containing domain/year estimates, the complete pointwise,
BH, and Bonferroni significance table, significance counts, and UFH-MFH
confidence-interval width tables. `outputs/data/ci_width_comparison.xlsx`
contains the interval-width domain table and distribution/paired summaries.
The corresponding distribution and paired-domain figures are integrated into
both `final_report.html` and `final_report.docx`.

## Optional AI

AI is off by default and requires a separate external-transfer acknowledgment.
Comparison prompts omit geographic identifiers, but still contain unpublished
aggregate estimates and diagnostics. Review `docs/SECURITY_AND_AI.md`. An approved
gateway can be selected with `SAE_OPENAI_BASE_URL` or
`SAE_ANTHROPIC_BASE_URL`.

When AI is requested, both report formats place each distinctly labelled AI
interpretation beside the statistical section it discusses. Every expected
section is marked generated, failed, or disabled; partial provider failures
cannot appear as silent gaps. Each block records provider/model and generation
metadata and requires human review before dissemination.
`outputs/data/ai_interpretations.rds` contains the structured audit state. A
separate `comparison_ai_note.html` is no longer produced.

## Verification and release

Run:

```text
Rscript tests/run_tests.R
Rscript scripts/check_dependency_lock.R
Rscript scripts/build_clean_release.R
```

The authoritative builder includes only `scripts/release_inventory.csv` and
excludes internal notes, arbitrary user Data folders, local libraries,
credentials, run histories, generated outputs and non-inventory literature.
It creates fresh staging, a manifest, a ZIP and `SHA256SUMS.txt` under
`dist/reorganized_candidate/` when called directly; an existing destination is never overwritten.
The ZIP contains one package folder with unchanged version identifiers.
Run `Rscript scripts/verify_release.R` from an extracted clean package to
verify both its full file set and hashes. Passing verification does not approve
the methods or official statistical use; see `docs/RELEASE_CHECKLIST.md`.

## Main contents

- `app.R`, `app_support.R`, `report.Rmd`, `install_packages.R`
- `R/` application helpers
- `scripts/` analysis and release tools
- `tests/` targeted regression/static tests
- `outputs/{data,tables}/.gitkeep`
- `docs/guidance/Technical notes/` and user instructions
- release, privacy, support, data-rights, and issue-status documentation

Rights and governance: read `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`,
`docs/GOVERNANCE.md`, and `docs/HISTORY_REMEDIATION.md`. The MIT grant applies only to
software source code; it does not license documentation, data, media, or
third-party material.

## Reading the change figures

The estimated-change plots show later year minus earlier year in percentage
points for poverty, using the same finite matched domains and unbenchmarked
UFH/MFH estimates. Negative values indicate a decrease. Their spread across
domains is not the MSE of a domain estimate. A tighter MFH distribution is
consistent with temporal borrowing and shrinkage, but does not prove greater
accuracy or a statistically significant variance reduction. Use the separate
CI-width figures, MSE/MCPE diagnostics, and model sensitivity checks to assess
uncertainty. See Section 11.9 of the guidance note.

### Short release packages

Run `Release.ps1` from a clean, committed source folder to create
`dist/<RELEASE_NAME>/<RELEASE_NAME>.zip` and its matching application folder.
`RELEASE_NAME` controls these short names; `WIZARD_VERSION` retains the full version.
Use `tools/bump_version.py <new-version> --release-name <new-short-name>` for later releases.
