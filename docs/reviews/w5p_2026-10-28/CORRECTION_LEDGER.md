# w5p correction and validation ledger

**Subsequent owner revision:** this record covers the initial w5p repairs. The later T=2 publication-policy explanation and `sm_all` default are recorded in [SM_ALL_REVISION.md](SM_ALL_REVISION.md), with fresh tests and a separate verification build. Earlier counts and artifact hashes below retain their original scope.

Baseline: `EU_SAE_520_w5o`, `5.2.0-rc.6-wizard.5.15`, commit `e5319826a1a8bc306c842b6a8745173045caf028`. Target: `EU_SAE_520_w5p`, `5.2.0-rc.6-wizard.5.16`. Work began October 28, 2026. No commit, push, tag or publication is authorized.

This ledger records completed repairs and evidence, not statistical certification. Historical w5o review and QER evidence retain their original identities. The final methodology note was checked against the revised code after implementation. No commit, push, tag or publication was performed.

| Item | Status | Change and evidence |
|---|---|---|
| R1 matrix years/identifiers | Fixed and tested | Shared keyed parser validates labels before numeric conversion, matches named years/rows and retains text leading zeros. Unnamed years require exact count and warn about selected-year order. Regression fixtures include the 0.14 mean and .20/.30 targets. |
| R2 duplicate population/target keys | Fixed and tested | Reject ambiguous required keys, including identical duplicates, across long/wide/matrix inputs. UI help states input grain. Reader tests check row order and valid unique tables. |
| R3 raw Direct variance | Fixed and tested | Preserve raw design variance by domain separately from working input for all transformations; export the audit. Missing raw uncertainty stays missing. In the baseline integration 73/80 Direct-MSE values changed, with model results within 1e-8. |
| R4 readiness and output preservation | Fixed and tested | Validate consumed inputs before cleanup; MFH complete-panel gate across both interfaces, saved/background and direct entry paths. Final shared effective-config resolver closes the independent review finding about blank/global/legacy fallback. All 62 input/preflight checks pass. |
| R5 logged benchmark factor | Fixed and tested | Log the actual reported-scale applied factors, including group, uploaded and converted targets. Preserve estimator/uncertainty calculations and document degenerate zero conventions. |
| R6 standalone figure qualifications | Fixed and tested | Stage previews, points and histograms retain pointwise, provisional/boundary and unavailable status. Report counts are explicitly exploratory; BH and Bonferroni remain separate. No numerical decision rule changed. |
| R7 dormant bootstrap entry point | Retired and tested | Removed obsolete file, runtime sourcing and release entry. Maintained shared engine and MASS dependency remain. This was dormant code, not a production bootstrap defect. |
| Review corrections | Complete | Dated [correction addendum](REVIEW_CORRECTIONS.md) and amended historical records correct trigger scope, severity, multiplicity interpretation and manuscript/Word locators. Historical probes remain identified as reproductions; personal library path removed. |
| Guidelines and four notes | Complete | Inspected all four notes; revised guidelines and two affected notes with 36 prose correction entries. Other two notes retain valid theory. Equations/styles preserved; clean DOCX/PDF and three tracked copies verified. [Document receipt](DOCUMENT_VERIFICATION.md). |
| English/Polish/Greek guides | Complete | Nine PPTX/PDF pairs and portable source kit rebuilt from reconciled sources. Independent semantic review covered 23 changed translation units; 54 visible changes found in PDFs. Country-team style approval is not claimed. |
| Deviations note and alignment register | Complete | [Final note](../../MOLINA_ROMERO_DEVIATIONS_w5p.md) covers all starting choices plus residual diagnostics, separates classification from justification, excludes STFH omission and retains unresolved statistical questions. |
| Version/release preparation | Complete | Stamped w5p/.5.16, updated release inventory and active notices; protected historical QER/review evidence and private archives from bulk relabeling. Historical prose generator refuses w5p. |
| Tests and independent review | Complete | [Fresh receipt](../../W5P_VALIDATION_RECEIPT.md): 421/0/0 full suite, 46/46 lock matches, 40 background and 88 optional checks. [Integrations](INTEGRATION_RECEIPT.md) and [independent review](INDEPENDENT_REVIEW.md) record their scope and limitations. |
| Verification package | Separate build evidence | `dist/w5p_verification_build/TEST_BUILD.md` records the builder, extraction, inventory, sizes/hashes and exclusion checks. This is an uncommitted private verification package. `dist/EU_SAE_520_w5p` remains reserved for the owner. |

Baseline safeguards: 72 documentation/audit/evidence files copied into local review storage; SHA-256 manifest recorded. Hashes and sizes of 4,177 existing files under `outputs/` and `app_runs/` recorded for the final preservation check. Local scratch artifacts are excluded from the release inventory.

The item-level Word correction map is `tools/w5p_guidance_changes.json`, keyed by exact old/new text and stable section locators. The document receipt records visibility, equations and reversible tracked changes. The local review folder also retains guide translation/source reconciliation, final test logs, baseline copies and preservation hashes. Review material is intentionally excluded from the portable package.

Open statistical matters are not repair failures: full-workflow coverage, low-signal/correlation-boundary undercoverage, threshold suitability, sampling/model-selection uncertainty and larger MFH1/MFH3 fitted-model studies remain as described in the deviations note. Optional product-wide naming changes, replacement of Figure 6 and the CPI label are outside this run and are listed in the owner's handoff.
