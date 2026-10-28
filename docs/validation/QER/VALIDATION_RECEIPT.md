# Local validation receipt — 10 October 2026

**Subsequent w5p default-policy revision.** The owner changed applicable new/missing variance defaults to `sm_all` and matching MFH `rho_sm_all`. This can change fitted estimates and bootstrap uncertainty for newly configured runs; it is not covered by an unchanged-results claim for the earlier explicit `sm_out` integrations. Existing explicit policies are preserved. The historical studies below retain their original inputs/settings and do not establish full-workflow coverage under the new default. T=2 now has an explicit NSO publication-revision rationale; that documentation change does not alter the two-year estimator.

**w5p follow-up, October 28, 2026.** The matrix-year/key repairs affect runs using misordered/ambiguous external inputs; they do not alter the fixed-input scenarios validated below. Raw Direct uncertainty, diagnostic factors and figure qualifications are reporting repairs; the maintained model/bootstrap definitions are unchanged and the retired implementation was unused. Readiness now blocks unsupported runs before cleanup. Fresh execution evidence is in the [w5p receipt](../W5P_VALIDATION_RECEIPT.md); statistical coverage limitations remain open.

Candidate: **EU_SAE_520_w5n**, application **5.2.0-rc.6-wizard.5.14**.
Validation used Windows, R 4.5.2, EMDI 2.2.3, msae 0.1.5 and survey 4.4.8.
The installed EMDI package reports that it was built with R 4.5.3; its numerical
agreement checks and the integration runs passed in the stated R 4.5.2 environment.

## Checks completed

- `tests/run_tests.R`: all targeted tests passed, including the UFH correction,
  joint MFH bootstrap moments, convergence/boundary diagnostics, invalid-moment
  handling, percentage-change status propagation, report inputs and release controls.
- `tests/test_startup.R`, `test_pandoc_bootstrap.R`, `test_step_runner.R`,
  `test_mfh_coef_table.R`, `test_readiness_tables.R` and `test_input_encoding.R`:
  passed. The repaired `test_background_run.R` passed all **40 checks** using an
  isolated application copy, including preservation of results on invalid input.
- `scripts/check_dependency_lock.R`: all **46 dependencies** matched the lock.
- Independent Gaussian/log identities used 30,000 draws per model; runtime
  MFH1/2/3 bootstrap checks and survey/fixed-target log benchmarking passed.
- The larger study contains **2,100 outer simulations**, independent fitter and
  bootstrap comparisons, **300 production endpoint checks**, and known-parameter
  simulations. See [coverage and methodological limitations](../MCPE_VALIDATION_STATUS.md)
  and the reproducible evidence in the [balanced study](evidence/balanced_summary.csv)
  and [heterogeneous study](evidence/heterogeneous_summary.csv).
- Final modified R files parsed successfully and the source whitespace check passed.

## Spanish integration runs

Both principal runs used the bundled Spanish example, survey years **2012–2013**,
**52 domains**, fixed covariates `gen` and `educ1`, seed **62401**, MFH2, and **500**
requested bootstrap draws. The pipeline completed UFH, MFH, comparisons, and HTML
and editable Word reports. Original-scale point estimates/MSEs, paired joint
moments, residual diagnostics and report/export units were checked.

| Setup | Accepted MFH draws | Rejected refits | Original-fit inference | Bootstrap covariance boundaries |
| --- | ---: | ---: | --- | ---: |
| Poverty, UFH arcsine, no benchmarking | 500 | 0 | Provisional: covariance boundary | 291/500 |
| Log mean welfare, national survey-target benchmarking | 500 | 0 | Regular approximate inference | 0/500 |

The benchmarked log estimator uses a separate bootstrap; its boundary count is
**3/500**, recorded in `log_mfh_benchmark_precision.csv`. This is distinct from
the unbenchmarked joint-moment bootstrap in the table. Median relative Monte
Carlo standard error of unbenchmarked MFH MSE was approximately **6.4%** for poverty
and **6.8%** for log mean welfare. These numbers measure simulation precision,
not uncertainty about the validity of the model or survey.

An additional poverty run requested **MFH3 first** with 50 draws. It completed
the documented fallback to MFH2, with 50 accepted draws, no rejected refits,
24 bootstrap covariance boundaries and provisional original-fit inference.
This checks the option/fallback; it is not a full MFH3 coverage study.

See [principal run summary](evidence/integration/spanish_b500_summary.csv),
[MFH3-first summary](evidence/integration/mfh3_first_summary.csv), and the accompanying
precision CSVs. HTML/Word figures and tables were refreshed after presentation
corrections; checksums confirmed that the fitted models and annual estimates did
not change during those refreshes. Word reports were rendered and visually checked;
HTML structure and numeric content were checked without a live browser visual test.
Reports and review workbooks are supplied separately from the clean application ZIP.

## Documents and scope

### Follow-up mapping regression, 10 October 2026

The current app reproduced the reported missing `hh_size` error when both
strata and household size selected `hhsize`: sequential readiness renaming
consumed the source column, while estimation's duplicate rename could drop
the strata role instead. All three paths now copy mapped values simultaneously.
Blank required mappings are rejected; unavailable/invalid readiness weights
return no estimates and do not overwrite existing tables.

The user confirmed `strata = region` and `household size = hhsize`. Restoring
that setting in the running app passed readiness: 52 domains, 1,716 households
in each selected year, no missing rates, and national rates 20.59% (2012) and
21.39% (2013). This verification did not initiate a model-estimation run.
Every mapped survey/auxiliary column for this corrected setting was identical
to the original w5n implementation. The fix adds 31 isolated regression checks
covering both app loaders, both estimation mapping blocks, shared and swapped
sources, missing mappings, independent rate calculations, and preservation of
existing outputs on failure. The 10 readiness-output lifecycle checks also pass.

The 57-slide English guide, including speaker notes, the 138-page guidelines,
four technical notes and download instructions were updated. Their rendered
layouts were inspected. Existing historical illustrations are explicitly labeled;
they are not presented as outputs from these final integration runs.

The [QER review note](QER_README.md) identifies decisions still required, including
boundary-sensitive inference, production Polish reruns, complex-survey validation,
translations and actual macOS/Linux tests. This receipt is evidence for a local
QER candidate, not institutional clearance for production publication.

The background-test incident and loss of the former current `outputs/` artifact
are disclosed in that note. Subsequent preservation checks apply to the reset
output folder; they do not establish recovery of its previous contents.

The clean archive is built solely from `scripts/release_inventory.csv`.
Its generated manifest records file hashes, and `SHA256SUMS.txt` beside the ZIP
records the archive hash. The builder verifies both staging and an independent
extraction before reporting success. There is no claim that this candidate has
been committed, tagged, published or tested on a production user's configuration.
