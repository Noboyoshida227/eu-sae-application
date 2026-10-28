# w5p software validation receipt

**Date:** October 28, 2026. **Candidate:** `EU_SAE_520_w5p`, version `5.2.0-rc.6-wizard.5.16`, including the `sm_all` default, T=2 publication-policy revision, optional AI recommendation on UFH or MFH, and documentation navigation revision.

The current candidate passed a fresh regression suite and mocked AI-report checks. The earlier default-policy integrations remain applicable: new/missing variance settings resolve to `sm_all`, with matching MFH `rho_sm_all`; explicit saved alternatives remain available. Arcsine UFH retains its separate effective-sample-size treatment. These checks verify software execution and numerical consistency, not statistical coverage, survey validity or a real AI provider's judgment. See the [deviations and justification note](../guidance/MOLINA_ROMERO_DEVIATIONS_w5p.md).

## Current navigation and language-folder validation

The package now starts with `START_HERE.html` and a two-page printable quick start. `docs/INDEX.html` groups documents by purpose, with Guides 1-3 in separate English, Polish and Greek folders. Each guide has a PDF reading copy and an editable PowerPoint copy. Other references are currently in English. A single catalogue supplies the HTML pages, folder map and application menu; current results and archived runs are explained separately.

| Check | Result |
|---|---|
| Main suite, `tests/run_tests.R` | **522 pass, 0 fail, 0 skip** |
| Dependency lock | **46/46 match** |
| Background execution | **40 pass** |
| UI element parity and shared navigation/menu checks | **Pass** |
| Saved QER evidence audit | **300 endpoints pass**; historical provenance preserved |
| Report export with relocated Word template | **HTML and Word pass**; 51 numerical CSV/RDS/Excel artifacts unchanged |
| Offline navigation checks | **32 catalogue entries, nine guide pairs, 277 local links pass** |

The final isolated regression snapshot contains 240 files. Its manifest SHA-256 is `f309ffe46022f10a2c6b23d52b05c51a1202fbbc33fba438b27e71ce71960a52`. Tests completed at `2026-10-28T20:41:17.879446+00:00`; all listed processes exited zero and no snapshot file changed. R 4.5.2, the locked installed library and Pandoc 3.8.3 were used. The known Windows locale/encoding and emdi binary-build warnings did not cause failures or skips. Later changes are documentation receipts and the download-PDF generator, which was run and visually checked separately; no later application or test change is included without its own verification.

An initial evidence check rejected the changed QER runner hash. The runner differs from the original only in its default output directory. The corrected audit verifies the original bytes by reversing that exact literal, while retaining the original design hashes. All saved evidence files remain unchanged after relocation. This is a provenance compatibility check and a repeat endpoint audit, not a new coverage study.

The template smoke check re-rendered a copied synthetic poverty run without fitting models or calling AI. Its 51 numerical CSV/RDS/Excel files retained their hashes. The earlier AI-on/off/failure checks and statistical limitations below retain their original scope.

Five Word documents received path-reference edits. Native equations and layout properties were preserved. The guidelines still have 141 pages and their TOC references did not change; the three existing guidance PDFs were regenerated and the changed pages inspected. The nine guide PDFs and visible PowerPoint slides are unchanged; six decks have updated speaker-note paths. All nine decks rebuilt from an updated source kit with identical slide, note, media, layout and theme parts. The download instructions were also corrected to state the current sm_all/rho_sm_all defaults, visible UFH log selector, distinct arcsine policy, AI advice and NSO revision policy.

The starting page and catalogue were checked for local targets, anchors, offline assets and compatibility with the application's docs-only static mount. The in-app browser rejected local-file URLs, so live browser visual inspection was unavailable. The two-page quick start, three-page download instructions and changed Word-document pages received PDF visual inspection. Package manifests, archive contents and extracted links receive a separate build check in `w5p_verification_build_navigation`. Existing user outputs and prior verification archives are retained. No commit, push, tag or publication is part of this revision.

**Subsequent documentation clarification, October 28, 2026:** the maintainer confirmed the EMDI recommendation for benchmarking and the Polish/Greek requests for anchored poverty and mean welfare. The deviations and alignment notes now state that provenance and the conditions of these extensions. This clarification changes documentation only; the tested production code and test sources are unchanged. The Markdown/HTML notes and links were checked, with a separate private verification build in `w5p_verification_build_stakeholder_rationale`. At that stage, the 521-pass suite below was the latest code validation; it was not rerun or relabeled for that prose-only change. The subsequent navigation validation above supersedes it for the current package.

## Earlier AI-report follow-up validation

| Check | Result |
|---|---|
| Main suite, `tests/run_tests.R` | **521 pass, 0 fail, 0 skip** |
| New AI recommendation checks, included above | **34 pass**; independently repeated successfully |
| Retained variance-default checks, included above | **66 pass** |
| Dependency lock | **46/46 match** |
| Background execution | **40 pass** |
| UI element parity | **Pass** |

The new checks cover actual workbook loading and inference-status propagation, matched finite pairs, reporting units, incomplete/duplicate inputs, aggregate-only payloads, boundary and unavailable inference, language, consent, provider failure, metadata, numeric provenance warnings and the actual conditional report section. AI-off reports omit the recommendation; missing evidence does not force a winner. The recommendation does not alter model settings or numerical results.

The isolated source snapshot contained 252 files, was created at `2026-10-28T19:19:06Z`, and completed testing at `19:21:27Z`. Its manifest SHA-256 is `0d57b6c3c374167ab4038cba1bf04f98ad1e62f6facc1a5cea2e3efddf2d26e5`. No snapshot file changed and no tested code/lock/version input drifted. Subsequent README and validation-document edits were checked separately. Runtime was R 4.5.2 with the installed locked library and Pandoc 3.8.3. All listed processes exited zero; the Word fixture ran. Known locale/encoding, intentional invalid-log and emdi binary-build warnings retained the scope described below.

Three isolated report checks reused the saved synthetic full-smoothing poverty outputs without refitting estimators: AI-on, AI-off with cached generated state, and provider failure. Each produced HTML and editable Word with the expected recommendation, absence or labelled failure. All 186 numerical artifacts per fixture retained their SHA-256 hashes. The AI-on Word report rendered to 53 PDF pages; all pages were inspected in contact sheets and the recommendation on page 51 was checked at full-page resolution. A literal title/status separator keeps the labels readable in Word. An initial failure-check assertion needed whitespace normalization for Pandoc line wrapping; the corrected harness and all three scenarios passed on the final source.

Independent recalculation against both saved poverty and log-welfare workbooks confirmed the new matched precision and change-MSE summaries, selected-model status and completeness counts. Guidelines §§11.7/11.9 now describe the advice in HTML/Word. The clean 141-page PDF, TOC, equations/styles and all six tracked-copy reconstructions passed; technical notes and the nine guide pairs/source kit were unchanged by this AI follow-up.

Providers were deterministic mocks: no external transfer or API charge occurred. These checks do not certify actual provider responses, statistical reasoning or language quality. Recommendations require analyst review and can state no clear preference or insufficient usable evidence. The warning-only numeric check is not a validation of AI conclusions. The earlier numerical integrations and coverage limitations below are preserved as earlier evidence; no new simulation campaign is claimed. Detailed source/test/report/Office receipts and independent review are retained in the local audit, outside the portable package. The fresh private verification build uses `w5p_verification_build_ai_recommendation`; previous verification builds remain preserved.

## Earlier default-policy validation

| Check | Result |
|---|---|
| Main suite, `tests/run_tests.R` | **487 pass, 0 fail, 0 skip** |
| New default-policy regressions, included above | **66 pass**; also independently repeated successfully |
| Dependency lock | **46/46 match** |
| Background execution | **40 pass** |
| UI element parity | **Pass** |

The focused checks cover new/reset/missing settings, actual UFH identity/log fits, MFH variance/covariance pairing, saved configuration restoration and serialization, visible log variance selection, and unchanged arcsine behavior. An older dashboard log setup could contain a hidden choice that the old interface ignored in favor of `sm_out`; the revised interface honors the visible stored choice and issues a legacy review notice. Actual saved pipeline configurations preserve their explicit policy. The notice does not silently migrate or overwrite a choice.

The fresh isolated snapshot contained 239 files, was created at `2026-10-28T18:47:44Z`, and completed tests at `18:50:14Z`. Baseline Git HEAD remains `e5319826a1a8bc306c842b6a8745173045caf028`; the candidate is uncommitted. Its source-manifest SHA-256 is `2cbebf59d8ad80681c9253032c8ae0e4e38c033f6f57f8ad6cfaa6bccee0fadc`. No snapshot file or tested code/lock/version input drifted during validation. Documentation edits received separate verification.

Runtime: R 4.5.2, installed locked library selected through `R_LIBS_USER`, Pandoc 3.8.3 through `RSTUDIO_PANDOC`, normal Windows process access for process/hash fixtures. The Word fixture ran rather than skipping. All processes exited zero. Logs retain unavailable C.UTF-8 locale settings, native FGT-label encoding warnings, the expected invalid-log-fixture NaN warning and emdi's R 4.5.3 binary-build warning. None caused a failure or skip. The six unchanged optional scripts' earlier 87 passes are retained below as earlier evidence, not counted as fresh follow-up execution.

## Default-policy integrations and policy effects

The default-policy runner omitted UFH/MFH variance and MFH covariance keys from the configuration, then checked that production artifacts resolved them to `sm_all`/`rho_sm_all`. Both scenarios completed UFH, MFH, Comparison and HTML/editable-Word report generation. They used fixed seed 62401, fixed covariates, 40 domains and 50 accepted MFH draws per scenario, with no failed draws. Both original MFH2 fits had regular status; accepted boundary draws were counted separately.

| Scenario | Policy | Benchmark | Accepted / failed / boundary draws |
|---|---|---|---|
| Household FGT1, identity scale | Omitted settings resolve to full smoothing | Survey national target | 50 / 0 / 3 |
| Equivalent person-row log arithmetic welfare | Omitted settings resolve to full smoothing | Fixed external national currency targets | 50 / 0 / 8 |
| Household FGT1 compatibility run | Explicit `sm_out` / `rho_sm_out` | Survey national target | 50 / 0 / 6 |

The compatibility run reproduced all four earlier explicit-sm_out UFH/MFH/comparison workbooks within tolerance 1e-8. Input-file hashes and normalized configurations matched. This establishes continuity for the tested explicit policy, not an unchanged-results claim for the new default.

In both full-smoothing scenarios, all 80 domain-year model estimates and MSEs differed from the earlier same-input sm_out results above tolerance 1e-10. Raw Direct variances stayed unchanged. Maximum absolute changes in unbenchmarked estimates were 0.06187 (UFH) / 0.06419 (MFH) for the synthetic FGT1 proportion and 1450.03 / 1591.52 currency units for synthetic log welfare. These are fixture-specific sensitivity results, not country findings or evidence that one policy is uniformly superior. Benchmark constraints, row-unit Direct-design equivalence, shared-draw moments, inference status and model uncertainty exports passed.

Reports rendered to 50-page poverty and 48-page log-welfare PDFs. Complete page sets were inspected in contact sheets with full-page checks of executive/setup sections; the exploratory-pointwise qualifications remain visible. Source and report hashes are retained in the follow-up audit. Fifty bootstrap draws are execution checks, insufficient for coverage or production precision claims. No large coverage campaign was run, and historical undercoverage remains open.

Reproduce from the repository root with the approved R library and Pandoc configured:

```text
Rscript tests/test_w5p_integration.R --variance-policy=default --replicates=50 --render=true --output-parent=<fresh-scratch-parent>
Rscript tests/test_w5p_integration.R --variance-policy=sm_out --scenario=poverty --replicates=50 --render=false --output-parent=<another-fresh-scratch-parent>
```

The dated repository audit retains comparison CSVs, input/source provenance and independent review; it is excluded from the portable package. The earlier verification ZIP is preserved. The revised private build and its TEST_BUILD receipt use a separate `w5p_verification_build_sm_all` directory; neither is a committed or published release.

## Earlier repair-only evidence retained for provenance

The following results precede the owner's default-policy revision and remain evidence for their original sources and explicit settings. They are not relabeled as fresh validation of the new default. The current checks above supersede them where the default changed.

### Fresh regression and environment checks

| Check | Result |
|---|---|
| Main suite, `tests/run_tests.R` | **421 pass, 0 fail, 0 skip** |
| Dependency lock, `scripts/check_dependency_lock.R` | **46 of 46 entries match** |
| Background execution, `tests/test_background_run.R` | **40 checks pass** |
| Seven additional regression scripts | **88 checks pass** |

Every listed process exited successfully. The additional checks comprised step completion and failure handling (8), startup failure paths (9), readiness-table preservation (10), Pandoc selection and failure handling (29), MFH coefficient tables (17), input encodings (14), and UI element parity (1). Startup and download branches used stubs; these checks did not install packages or download tools.

The main suite included all 62 input/preflight checks, including the final saved-configuration regressions for blank method settings and global/legacy fallbacks. It also exercised raw Direct versus working variance, transformation and benchmark cases, shared MFH moments, endpoint handling, and standalone figure qualifications. The Word report fixture ran with Pandoc available; it was not skipped. UI parity confirmed that each original app element appears exactly once in the wizard.

The runtime was **R 4.5.2** with the existing package library selected through `R_LIBS_USER`, and **Pandoc 3.8.3** selected through `RSTUDIO_PANDOC`. All locked package versions matched. The execution paths are environment settings rather than hardcoded test dependencies.

The logs retain Windows warnings that `C.UTF-8` could not be used for several locale categories, native-encoding warnings for en-dash FGT labels, an expected `NaNs produced` warning in an intentionally invalid log-change fixture, and a warning that the installed `emdi` binary was built under R 4.5.3. The suite also reports an aggregate of 18 startup/source warnings. These warnings did not cause a failed or skipped check; the `emdi` package version still matched the lock. Windows child-process and process-inspection fixtures used normal local process access, with test artifacts confined to isolated or temporary directories and review logs.

### Source provenance and isolation

The main checks used a fresh isolated copy of the working tree created at `2026-10-28T17:49:51Z`. The copy contained 226 files: tracked and intended new source files plus the public Spain inputs needed by the fixtures. The baseline Git commit was `e5319826a1a8bc306c842b6a8745173045caf028`; the tested candidate included the uncommitted w5p revisions.

The retained `final_test_source_manifest.json` records the size and SHA-256 of every copied file. Its SHA-256 is:

```text
dfb8e00c0b377e02b57820cde054e67a7e4d8553a400ff36444161236965e1a2
```

After all listed regression checks, at `2026-10-28T17:55:45Z`, none of those snapshot files had changed. The tested code, dependency-lock, and version inputs still matched the working tree. Subsequent documentation and release packaging are outside that source snapshot and receive separate verification.

The full logs, machine-readable results, and source manifest are retained in the dated local review audit. They are not required to run the portable release and are excluded from that package. No existing analytical result was used as a substitute for a fresh regression result.

### Bounded end-to-end integrations

Three scenarios completed UFH, MFH, Comparison, and HTML/Word report generation. They used fixed seed 62401, fixed covariates, MFH2, `sm_out`, `rho_sm_out`, and 50 accepted MFH bootstrap draws per scenario. No LLM calls were made.

| Scenario | Indicator and survey rows | National benchmark | Domains | Accepted / failed / boundary draws |
|---|---|---|---:|---:|
| w5p poverty | Identity FGT1; synthetic household rows | Survey-derived | 40 | 50 / 0 / 6 |
| w5p log welfare | Log arithmetic mean welfare; equivalent person rows | Fixed uploaded currency targets | 40 | 50 / 0 / 0 |
| Matched w5o baseline | Same poverty inputs, configuration, and seed | Same survey-derived target | 40 | 50 / 0 / 6 |

All original fitted MFH2 covariance statuses were `regular`; the accepted bootstrap boundary draws remain explicitly recorded. Each scenario produced 80 domain-year records. Benchmark constraints, joint prediction-error moments, model-MSE exports, inference-status propagation, residual diagnostics, and report generation passed. Both candidate UFH Direct-variance exports agreed with the raw MFH survey-design variances.

Against the matched w5o poverty run, FH, benchmarked FH, and MFH point estimates and model uncertainty were unchanged within tolerance `1e-8`. The intended reporting repair corrected **73 of 80** UFH domain-year Direct-MSE entries. The matched household/person fixture also confirmed equivalent Direct means and design variances for FGT0, FGT1, FGT2, and welfare using the production stratum recoding. This does not establish invariance of GVF or other procedures that depend on row counts.

The first restricted-environment attempt stopped before estimation because Windows rejected a readable input during hashing; normal local execution resolved that issue. An integration-harness edit during execution caused a trailing parse error after the scenarios and checks had completed. A fresh verification-only process using the final, parseable runner exited successfully and reasserted the saved-result invariants. The final saved-configuration preflight was rerun up to the point before cleanup for both candidate configurations, preserving result hashes. Final report wording was regenerated without changing model results. These events and source hashes are retained in the dated integration audit rather than treated as an uninterrupted first-pass run.

Fifty draws support this bounded execution check; they are insufficient to establish coverage or production Monte Carlo precision. Historical coverage evidence remains separately identified in [MCPE validation status](MCPE_VALIDATION_STATUS.md) and the [historical QER receipt](QER/VALIDATION_RECEIPT.md).

### Selective-variance frequency check

The production Direct/GVF paths were also evaluated for the shipped Spain and simulated examples, with household rows, supplied poverty-line columns, identity proportion scale, and the recorded survey designs. No model fitting or bootstrap was performed. UFH and MFH gave identical replacement counts:

| Example/year | Domains | FGT0 replaced | FGT1 replaced | FGT2 replaced |
|---|---:|---:|---:|---:|
| Spain 2012 | 52 | 8 (15.4%) | 28 (53.8%) | 41 (78.8%) |
| Spain 2013 | 52 | 8 (15.4%) | 26 (50.0%) | 40 (76.9%) |
| Simulated 2022 | 40 | 7 (17.5%) | 37 (92.5%) | 39 (97.5%) |
| Simulated 2023 | 40 | 11 (27.5%) | 36 (90.0%) | 40 (100.0%) |

Every eligible variance was finite and strictly below 0.001, and every requested replacement succeeded. There were no nonfinite requests or failed replacements. Input hashes, source hashes, design settings, and separate path counts are retained in the dated audit. These illustrative frequencies do not establish country-wide prevalence or justify the fixed cutoff for other indicators, scales, or surveys.

### Interpretation and companion verification

The checks support the specific software repairs and tested numerical invariants. They do not close the historical low-signal or covariance-boundary coverage limitations, validate the full survey-to-report workflow, or supply the outstanding larger fitted-model studies for MFH1/MFH3. Selection uncertainty, estimated sampling inputs, benchmarking, and many-area inference still require the qualifications in the deviations note.

Document and package verification are recorded in separate companion review/build receipts. This receipt makes no claim that a release was committed, pushed, or published.
