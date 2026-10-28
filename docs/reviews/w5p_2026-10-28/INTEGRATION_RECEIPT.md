# w5p bounded integration receipt

Date: October 28, 2026. Candidate: `5.2.0-rc.6-wizard.5.16` / `EU_SAE_520_w5p`. Baseline sources: commit `e5319826a1a8bc306c842b6a8745173045caf028`, extracted with `git archive` into an isolated scratch directory.

## Scope and result

All three scenarios completed UFH, MFH, Comparison and HTML/Word report generation. This is an execution and numerical-consistency check, not a coverage study. The test used R 4.5.2, the installed locked-package environment, fixed seed 62401, fixed covariates (`educ_secondary`, `unemp_rate`), MFH2, `sm_out`, `rho_sm_out`, and 50 bootstrap draws. No LLM calls were made.

| Scenario | Rows and indicator | Benchmark | Domains | Accepted MFH draws | Failed MFH draws | Boundary draws |
|---|---|---|---:|---:|---:|---:|
| Candidate poverty | Synthetic household rows; identity FGT1 | Survey-derived national target | 40 | 50 | 0 | 6 |
| Candidate log welfare | Equivalent synthetic person rows; log arithmetic mean welfare | Fixed uploaded national currency targets | 40 | 50 | 0 | 0 |
| w5o baseline poverty | Same household inputs/configuration/seed as candidate poverty | Same survey target | 40 | 50 | 0 | 6 |

All original fitted MFH2 covariance statuses were `regular`; accepted bootstrap boundary draws remain explicitly counted. Each scenario produced 80 domain-year records. Benchmark constraints, shared-draw joint moments, model-MSE exports, inference status propagation, standardized-residual normality diagnostics, and report generation passed. Both candidate UFH exports now agree with raw MFH survey-design Direct variances.

The baseline/current poverty comparison found unchanged FH, benchmarked FH and MFH estimates and model uncertainty within tolerance `1e-8`. The intended Direct-MSE repair changed 73 of 80 UFH domain-year Direct-MSE entries. The detailed deltas are in [baseline_direct_mse_correction.csv](evidence/integration/baseline_direct_mse_correction.csv).

The matched person fixture expands each shipped synthetic household into its `hhsize` persons, each retaining the original household sampling weight. Household population weights are `weight * hhsize`; person weights are `weight`. Direct means and design variances agree for FGT0/FGT1/FGT2 and welfare to floating-point tolerance using the production stratum recoding. This establishes Direct-design equivalence; it does not claim invariance of GVF/other sample-size-dependent procedures to changing the row unit.

## Commands and audit artifacts

Use the installed locked R library through `R_LIBS_USER` or the runner's `--library` option. Commands run from the repository root:

```text
Rscript tests/test_w5p_integration.R --replicates=50 --render=true --output-parent=tmp/w5p_integrations --baseline-root=tmp/w5p_integration_baseline
Rscript tests/test_w5p_integration.R --verify-existing=tmp/w5p_integrations/w5p_integration_7ae059ef1b4c
Rscript docs/reviews/w5p_2026-10-28/checks/check_final_integration_preflight.R tmp/w5p_integrations/w5p_integration_7ae059ef1b4c
Rscript docs/reviews/w5p_2026-10-28/checks/refresh_w5p_integration_reports.R tmp/w5p_integrations/w5p_integration_7ae059ef1b4c
```

The first sandbox attempt stopped before estimation because Windows `file.access()` rejected a readable input during hashing. Normal Windows execution, approved by the tool's automatic review, resolved that environment limitation. All computation/report child stages then exited successfully. A harness edit while Rscript was streaming the runner caused a trailing parse error after all scenario results and checks had completed. The final runner parses correctly; a fresh verification-only process exited successfully and reasserted every saved-result invariant without refitting. The parity fixture's initial character-stratum coercion warnings were removed by using the production stratum recoding, and the parity checks were rerun successfully. Locale startup warnings about unavailable `C.UTF-8` settings remain recorded in logs; they were not silently marked as test failures or suppressed in the validation record.

The final saved-config resolver repair did not alter effective inputs for these explicit configurations. The actual background-driver preflight prefix was rerun through the point before output cleanup for both candidates; both passed and all result hashes remained unchanged. Five staged source files were refreshed with original/final hashes in [final_preflight_source_receipt.csv](evidence/integration/final_preflight_source_receipt.csv). The final report-only wording changes were then regenerated with model result hashes preserved.

The retained scratch directory is `tmp/w5p_integrations/w5p_integration_7ae059ef1b4c/`. Full stage logs and generated files remain there. Portable summaries and clean verification logs are in [evidence/integration](evidence/integration/). The root `outputs/` manifest was unchanged across integration execution. The main validation receipt separately covers preservation of the wider workspace outputs and saved inputs/configurations.

## Report verification

Pandoc 3.8.3 produced both standalone HTML and editable DOCX reports for both candidates. The DOCX renderer produced PDFs and page PNGs with installed LibreOffice and bundled Poppler. Both complete page sets were reviewed in layout contact sheets, with full-page spot checks of the executive summary and scientific significance table. No clipping or overlapping content was identified in those checks. The refreshed executive caption explicitly labels pointwise counts exploratory and keeps BH/Bonferroni counts separate; the significance discussion now distinguishes familywide claims. Report hashes are recorded separately after the final render.

Full pipeline diagnostics are retained in the stage logs; execution success does not certify survey validity, complete statistical coverage, or the absence of every possible software defect. In particular, the historical low-signal and correlation-limit coverage limitations remain open.
