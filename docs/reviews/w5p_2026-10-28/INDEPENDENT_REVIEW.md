# Independent review of the w5p revisions

Date: October 28, 2026. Candidate: `EU_SAE_520_w5p`, version `5.2.0-rc.6-wizard.5.16`. Baseline: `e5319826a1a8bc306c842b6a8745173045caf028` (w5o).

This review was performed by a separate AI reviewer that did not implement the production changes. The reviewer read the final execution prompt, corrected starting review and deviations note, relevant tracked and untracked code/tests, and the revised documentation. The reviewer reported findings to the implementing agent, independently checked their disposition, and wrote this record. This is an independent implementation review, not external methodological certification. No commit, push, tag or publication was performed.

## Conclusion and findings

No unresolved material coding finding was identified in the reviewed changes at the source snapshot below. That conclusion is bounded by the checks described here; it is not a guarantee that every remaining bug has been excluded.

| Finding | Disposition and evidence |
|---|---|
| **P2: effective configuration differed between preflight and estimation.** Empty per-method benchmark settings could hide a relevant global/legacy input during preflight; estimation subsequently consumed that input. Inherited analysis years also differed. | **Closed.** `sae_resolve_method_input_config()` now resolves settings consistently for configuration validation, preflight and both estimation scripts. Blank/NA/NULL values are treated as unspecified; target precedence is method target, legacy method target, then global target. Years inherit method, global, then the standalone default, with exactly two distinct years required. Both scripts retain the resolved method configuration. Selected years are checked against survey and auxiliary data before cleanup. The independent bypass reproduction changed from reaching a stubbed cleanup function to rejecting the inherited missing file before cleanup. The independently executed preflight suite passed all 62 checks. |
| **Documentation: the zero-target/zero-model-mean convention was described as a common unit factor.** | **Closed.** The revised guidance and deviations note distinguish UFH's zero predictions with an undefined ratio from MFH's factor-one convention within numerical tolerance. They retain rejection of a nonzero target with a zero model aggregate. These conventions were checked against the helpers; they are not defended as generic fallbacks for invalid inputs. |
| **Documentation: one MSE-note sentence still listed only BH-adjusted results and “both” significance fields.** | **Closed.** The final Part III paragraph beginning “The same helper serves” explicitly lists raw, BH-adjusted and Bonferroni-adjusted p-values and their corresponding significance fields. The revised DOCX text was independently reread during closure. |
| **Deviations-note completeness: the residual-diagnostic limitation from the alignment register was implicit.** | **Closed.** The final note explicitly describes `(Direct - EBLUP)/sqrt(diag(RPR))`, correlated residuals, and Shapiro-Wilk/residual-versus-fitted checks as descriptive rather than exact independent-sample tests. |
| **Translation precision: three small Polish/Greek wording improvements.** | **Closed.** Polish passages 630/632 now use the intended execution terminology; Greek passage 633 explicitly refers to the variance used by the model. All 23 changed translation units received an independent semantic review; no material mistranslation was identified. |

The report's significance-summary caption now identifies pointwise counts as exploratory, distinguishes the adjusted counts, and retains the provisional MFH qualification when applicable. The two changed commentary instructions in `R/comparison_report_ai.R` likewise forbid a familywide interpretation of pointwise counts. Existing boundary-warning instructions remain present. This closure check was a review of source wording; no external AI commentary service was invoked or its future generated prose certified.

## Code and regression-review scope

- **R1-R2:** reviewed the shared population/target readers, named-year matching before relabeling, duplicate required-key rejection for long/wide/matrix forms, character identifiers, and the explicit positional policy for completely unnamed year columns. Inspected the associated regression cases and release inventory changes.
- **R3:** reviewed preservation and restoration of raw original-scale Direct variance by domain identity, its separation from model working variance, the audit output, and coverage of identity, log, arcsine, poverty and mean-welfare cases in the targeted tests. Inspected benchmarked and Comparison consumers; no additional ordering defect was found in the repair.
- **R4:** reviewed both interface paths, saved configurations, the background/direct entry path, relevant-input handling and the before-cleanup order. The additional configuration-resolution defect above was independently reproduced, then retested after repair.
- **R5:** reviewed use of the benchmark operation's actual reporting-scale target/factor in decomposition diagnostics, including the undefined zero/zero ratio. The change corrects diagnostic reporting, not the underlying point estimates or bootstrap moments.
- **R6:** reviewed the common MFH figure helper, regular/boundary/unavailable status propagation, pointwise/exploratory labels, preview/histogram call sites and their regression fixtures. Reviewed the final report caption and advisory-commentary instructions again at closure.
- **R7:** reviewed removal of the dormant bootstrap implementation/runtime source, explicit retained helper and dependency setup, test-runner changes and inventory removal. No active call site requiring the retired implementation was identified.

The independent execution used R 4.5.2 and the session's configured R library through `R_LIBS_USER`. It comprised the focused bypass probe and `Rscript --vanilla tests/test_input_preflight.R`, which reported **62 passed checks**. The probe substituted a stop-only cleanup stub and used isolated inputs; it did not clean production outputs. During final closure the resolver and its call sites were reread; the full test suite was **not** rerun by this reviewer. Full-suite, dependency, integration, preservation and package-build results belong to the implementing agent's fresh validation receipt and should not be attributed to this independent run.

## Documentation and evidence checks

The independent reviewer compared the final deviations note with the corrected w5o starting note and `docs/METHODOLOGY_ALIGNMENT.md`. It covers their substantive departures/extensions and now includes the residual-diagnostic qualification. It separates classification from justification, excludes STFH omission from the assessment, and keeps coding defects separate from methodological choices. The manuscript's p23 variance-contrast discussion and p37 individual-area/familywise distinction are represented without describing LASSO itself or absence of Bonferroni as a violation.

The note's illustrative `sm_out` table was checked against all 24 UFH/MFH/indicator/year evidence rows. Counts, denominators, finite-below-threshold reasons, successful replacements and zero failed replacements agree. The integration summary records 50 accepted draws per scenario. An independent recount of the saved baseline comparison found **73 changed Direct-MSE entries out of 80**, using an absolute tolerance of `1e-12`, matching the note. These checks verify the reported evidence summaries; this reviewer did not rerun those integrations or the historical coverage experiments.

The reviewer checked final methodology text at guidelines pp52, 59, 65, 131 and 134-137; sampling-covariance note pp6-7; and MSE note pp5-6. These checks covered benchmark bounds/zero cases, the qualified repeated-PSU explanation, retention of Annex G.8's existing model condition, full multiplicity descriptions, GVF retransformation, log-UFH ML/Slud-Maiti versus log-MFH prediction, and bootstrap conditioning on selected models and inputs. Full-resolution rendered spot checks of guidelines pp52/65/135, sampling p7 and MSE p6 found readable text/equations/tables without overlap or clipping. This was a targeted spot check, not this reviewer's all-page layout inspection.

At the reviewed tracked-document snapshot, the reviewer independently reconstructed accepting and rejecting the changes in all three edited DOCX files. Canonical document-body XML matched the clean and preserved baseline documents respectively, including tables, and equation XML was unchanged. The implementing agent owns subsequent final layout adjustments, rerendering and regenerated redline verification; the final artifact receipt must identify those final files. The closure review confirmed the later MSE Bonferroni wording directly in its current DOCX.

All 23 changed English/Polish/Greek units in the retained translation-change manifest were read side by side. This is a semantic review by an independent AI reviewer, not country-team linguistic certification. Final deck rebuilding and full rendered-slide verification belong to the guide revision receipt.

## Remaining limitations and completion boundary

- Statistical coverage remains unresolved for the complete combination of survey design, estimated GVFs/covariances, variable/model selection, benchmarking and multiple testing. Fixed-cutoff suitability, pooled-correlation adequacy, UFH/Direct period independence and covariance-boundary undercoverage remain application-level questions. Software tests do not settle them.
- The historical MFH2 coverage findings and remaining MFH1/MFH3 study needs retain their original scope and date. This review generated no new coverage study.
- The portable note's source/code links, including the subsequently saved validation receipt, resolve in the working tree. The deviations note, receipt and two new technical-note PDFs appear in the release inventory. Extracted-package link/hash checks, confidentiality exclusions and the local verification-build receipt remain the final build owner's checks; this review does not assert that an archive had already passed them.
- The working tree is uncommitted. Final guidance/redline closure is recorded below; verification packaging remained pending at this review's completion. Any subsequent substantive source or document edit requires the affected review/check again and, after packaging, a new verified build.

## Closure source snapshot

SHA-256 values bind the closure review of the configuration resolver, its consumers, report wording and deviations note to the following source contents. They identify local files, not a new commit.

| Repository path | SHA-256 |
|---|---|
| `R/input_preflight.R` | `6d8e0562975e6b12fd06b815571b24f628ece8364514e1dd4b805e3c8282beed` |
| `app_support.R` | `b9007c76f9a2833ce1946ca3a58546ad54f599afe9d2163b4a5f3ce86f3273c6` |
| `scripts/01_ufh.R` | `5cc9457db7f7540a9d0cb797dd6f958092d8455eb46aa66b019c11f426c90146` |
| `scripts/02_mfh.R` | `fb02795d860e95ad908daaf23ce1dc3cb904f925053fd62d3e4ed4a0692bb5ec` |
| `R/comparison_report_ai.R` | `fe4208eff4599be4c18c18e125b28e0e3f185ee44c8866a31cef3ee7bd2f73f2` |
| `report.Rmd` | `704d38db81d0add78cd176f91210526fa5de08edc1056dced8c621c8030f514f` |
| `docs/MOLINA_ROMERO_DEVIATIONS_w5p.md` | `f5370d6fc8ab595d820010eaf15a8e24952d014c29ed5e4cdd5c43ba63237db7` |

## Final document-artifact follow-up

The reviewer checked the subsequent prose-only shortening at the guidance-change locator “Opening release-update paragraph.” Its final sentence accurately directs readers to the separate deviations note without changing the statistical claims. In the final `guidelines_delivery` rendering, the complete paragraph fits on page 10 without clipping or a spill; page 11 retains only its page number. The 140-page delivery PDF has SHA-256 `4a1424c4a5d0e668dbe90c7addfcf50037be7e145ffa4399b88c4d5b43af74ef`. The current clean guidelines DOCX has SHA-256 `2f9d9f8120685ffe448a7b6bdf1a41f84acdaf241220c212d58f7e38e4c21eef`, and its `word/styles.xml` remains byte-identical to the preserved baseline.

The reviewer independently repeated the accept/reject reconstruction against the regenerated saved tracked files: all three canonical document bodies match the final clean and baseline bodies respectively. Equation XML remains unchanged, with counts of 168, 46 and 32. The latest redline receipt's clean/tracked hashes match the actual files. This closes the affected final paragraph/redline review; no broader tests were repeated.

The reviewer identified an older PDF still in the active guidelines path and notified the implementing agent. After synchronization, an independent byte comparison confirmed that all three active PDFs exactly match their reviewed render outputs. The final guidelines hash is the one above; the active covariance-note PDF has SHA-256 `50666b98e2e321af449f4237f06aa38f8930a9fa2565e2af5618ee0b11c227a4`, and the active MSE-note PDF has SHA-256 `db27100959a95148df11bc1c54843be36e8c629f1e21ea7299e84b6ef5e846fd`. This closes the synchronization reminder.

The completed correction ledger, document-verification receipt and fresh software-validation receipt were then read against the supporting summary files. The reported 36 visible correction entries, page/equation counts, 151/32/5 tracked-run pairs, and regression-summary totals agree with those records. No additional material mismatch was identified. Those totals remain the implementing agents' execution evidence, not newly executed tests by this reviewer. The verification build remains a subsequent, separate check; no publication or archive-validation claim is made here.

The final sanitation changes were also checked: `docs/RELEASING.md` replaces a personal repository location with an explicitly generic, quoted `Set-Location -LiteralPath` example. The historical w5o `probe_direct_variance.R` replaces its personal library-path override with normal-library/`R_LIBS_USER` guidance and identifies itself as historical evidence. All remaining probe lines are identical to the preserved baseline. These changes do not alter production estimation code or convert the historical probe into an acceptance test. No broader tests were needed or rerun for this sanitation follow-up. Independent review is closed for the reviewed pre-build state.
