# EU SAE Workbench release gate for QER

**Status:** approved by the owner on 30 October 2026, including the tolerances, thresholds and the name QER-RC1. Prepared against commit `c8989d4`. The "not specified" decision was approved separately. Two items still need an owner decision: macOS and Linux testing (§4, E4) and the scope of the full-workflow simulation (§6).
Tolerances and thresholds apply as approved. Changes after this point need the owner’s approval and an entry in the ledger.

This gate sets the rules for circulating a candidate to QER. It does not replace the production gates in [RELEASE_CHECKLIST.md](../../maintenance/RELEASE_CHECKLIST.md). This document records rules and repository facts; it is not validation evidence.

**Evidence labels:** **Verified** means read in the repository or run in a temporary copy. **Assumed** means not confirmed. **To record** means the value is set at freeze.

## Known before RC1 can freeze

| # | Item | Evidence | Status |
|---|---|---|---|
| P1 | All six Spain_2y configurations and the synthetic integration test stop because they declare no PSU design. | Verified by running both in a temporary copy. See the [decision note](PSU_NOT_SPECIFIED_DECISION_NOTE_DRAFT.md). | Fixed in the working tree, uncommitted; retest at freeze |
| P2 | `QER_package_2026-10-30` was packaged from `d06fed1` with uncommitted changes, before `c8989d4`. | `PACKAGE_PROVENANCE.json` fields `git_head` and `git_status_at_packaging`. | Do not circulate; rebuild |
| P3 | The QER note and receipts describe w5n or w5p evidence that predates `c8989d4`. | [QER_README.md](../../validation/QER/QER_README.md), [VALIDATION_RECEIPT.md](../../validation/QER/VALIDATION_RECEIPT.md) | Refresh after the run |
| P4 | `Unreleased` in the changelog does not describe `c8989d4`, and tag `v…wizard.5.16` does not exist. | [CHANGELOG.md](../../maintenance/CHANGELOG.md); `git tag` | Resolve at version stamp |

## 1. Candidate identity

"RC1" is easy to confuse with the existing `5.2.0-rc.6` version, so this gate uses **QER-RC1**. Each QER candidate maps to one stamped version.

| Item | Current state (verified) | How it is recorded |
|---|---|---|
| Commit | `c8989d4` is the head; not yet the candidate | To record at freeze: full SHA from a clean tree, in `RELEASE_INFO.txt` |
| Version | `5.2.0-rc.6-wizard.5.16`; release name `EU_SAE_520_w5p` | To record at freeze: new stamp with `tools/bump_version.py`, because code changed after 5.16 was first stamped |
| Tag | Latest is `v5.2.0-rc.6-wizard.5.15` | To record at freeze: `v<WIZARD_VERSION>` on the frozen commit |
| Archive | None for this candidate | To record at freeze: ZIP SHA-256 and manifest from `Release.ps1` |
| Dependencies | 46 entries in `dependencies.lock.csv`; `scripts/check_dependency_lock.R` compares them | To record at freeze: passing output retained |
| Runtime and OS | Lock names R 4.5.2. Windows 11 is available locally | To record at freeze: `sessionInfo()`, OS build, Pandoc version and source |
| Seeds | Spain_2y configurations use seed 123 | To record at freeze: seed for every case in §4 |
| Test data | `survey.rds` and `auxiliary.rds` are git-ignored but listed in the release inventory | To record at freeze: SHA-256 of every input file |

**Note:** CI installs current packages on the latest R release and has no Spain_2y survey data ([quality.yml](../../../.github/workflows/quality.yml)). A green CI run therefore checks neither the lock nor the bundled data, and it cannot stand in for §4.

## 2. Severity rules

| Class | Definition | Effect |
|---|---|---|
| **Blocker** | A wrong result presented as valid; a breach of data locality; a documented workflow that cannot complete; a claim in reports or guidance that contradicts the calculation; a candidate that cannot be reproduced from its record | Stops circulation until fixed and retested |
| **Non-blocking defect** | A real defect that leaves results and their interpretation correct, or that fails clearly and has a documented workaround | Recorded in the ledger and disclosed to QER |
| **Optional enhancement** | Anything that is not a defect | Deferred until after QER |

Methodological disagreement is not a defect class. It goes to the decision register unless the code contradicts its own documentation.

**Who decides:** the owner classifies each finding and records the reason in the ledger. A reviewer's severity is advisory.

**Disagreements:** if a reviewer contests a classification, the finding must be reproduced by a test or traced calculation, and the owner then decides. If the disagreement is about method rather than behaviour, it goes to QER as an open question, and it cannot be closed by agreement among AI reviewers.

## 3. Revised candidates

Fixes after freeze produce QER-RC2 and so on, each with a new commit, version stamp, tag and archive. Earlier archives are kept and never rebuilt.

| Change type | Retesting required |
|---|---|
| Can affect estimates, uncertainty, benchmarking or reported interpretation, including report text, `report.Rmd`, `scripts/`, estimation helpers, configurations and dependencies | **Full rerun** of §4, plus the §6 checks for that component |
| Build, launcher or install only | Parity and startup tests, build, and clean-machine smoke test |
| Documentation only, with no change to meaning | Navigation check and owner review |

If the class of a change is unclear, treat it as requiring a full rerun.

## 4. Test matrix

All cases run on the frozen candidate through the real entry points. Retain the configuration, log, output hashes, `sessionInfo()`, and the report or error shown. "Assumed" under data source means the fixture does not exist yet.

### Representative cases

Pass rule for R1–R5: the run completes with a report, published invariants hold, and the §6 comparisons pass.

| ID | Purpose | Data source | Settings |
|---|---|---|---|
| R1 | Original-line poverty | Spain_2y | `sm_out`, MFH2, linked, 500 draws |
| R2 | Same, alternative variance | Spain_2y | `sm_all`, MFH2, linked, 500 draws |
| R3 | Anchored poverty | Spain_2y | `povline_anchored`, both variance options, linked |
| R4 | Mean welfare with CPI and log model | Spain_2y | Both variance options, linked |
| R5 | Stratified design, benchmarked | `Data/simulated` | Strata mapped, national and grouped benchmarks, survey and uploaded targets |
| R6 | Person-row survey | Synthetic integration fixture | `survey_unit = person`, external targets |
| R7 | MFH3-first path | Spain_2y | Selection rule and fallback recorded |

### Stress cases

Pass rule: the run either gives correct results with the documented warning, or stops with a clear message before overwriting outputs. **Plausible output with no warning is a failure.** All of these need new synthetic fixtures.

| ID | Case | Expected behaviour |
|---|---|---|
| S1 | Sparse domains: very few households or one PSU | Domain handling matches the guidance and is reported |
| S2 | Direct estimates of exactly 0 or 1, and near those values | Transformation and variance rules behave as documented; no silent loss of domains |
| S3 | Zero, missing or unstable direct variances | `sm_out` and `sm_all` rules apply; replaced values appear in the audit |
| S4 | Singleton PSU in a stratum, in one year or both | Runs under `lonely.psu = "adjust"`; the handling is disclosed |
| S5 | Unbalanced years: domain or PSU present in only one year | Domain alignment is correct and exclusions are reported |
| S6 | MFH boundary: zero variance and correlation near ±1 | Boundary-sensitive status appears in tables, figures and reports |
| S7 | Non-convergence, including failed bootstrap refits | Stated clearly; no unchecked fit is reported |
| S8 | Invalid joint moments | Inference shows as unavailable, with no substitute independence assumption |

### PSU settings and recent-fix interactions

| ID | Case | Data source | Expected and pass rule |
|---|---|---|---|
| P-1 | Linked | Spain_2y | Same direct estimates and covariance as the earlier pooled design |
| P-2 | Independent | Synthetic with unequal PSU counts | Annual variances match separate-year designs; covariance is 0; random-effect covariance is not constrained |
| P-3 | Independent with accidentally reused PSU codes | Synthetic | Results do not depend on the codes |
| P-4 | Not specified, MFH selected | Spain_2y | Blocked at readiness and at the script, for every entry point |
| P-5 | Not specified, UFH only, and UFH plus Comparison | Spain_2y | Runs; report shows the period-independence assumption |
| P-6 | Legacy checked, legacy unchecked, and absent | Saved-setup fixtures | Map to linked, not specified and not specified; the effect appears in the log |
| P-7 | Declaration conflicts with the data | Synthetic | Behaviour follows the decision note |
| X-1 | Missing outcomes with independent design | Synthetic | UFH sample counts use nonmissing outcomes; MFH alignment holds |
| X-2 | Independent design with each transformation and each benchmark type | Synthetic | Report wording reflects zero sampling covariance |
| X-3 | Cautious precision text across all three PSU settings | Spain_2y and synthetic | Report, workbook and AI context agree |

### Environment cases

| ID | Case | Pass rule |
|---|---|---|
| E1 | Windows clean machine, from the ZIP | Starts and finishes R1 with both reports |
| E2 | Offline run | Finishes as documented when Pandoc is unavailable |
| E3 | Wizard and classic dashboard | Same R1 configuration gives matching estimates |
| E4 | macOS and Linux | Run, or disclosed to QER as not tested. **Owner decides** |

### Test suites

Run on the frozen candidate: the nine commands in [HOW_TO_RELEASE.md](../../../HOW_TO_RELEASE.md), `tests/test_w5p_integration.R` for both scenarios, and `tools/check_ui_parity.R`. `test_w5p_integration.R` is not in that list today, and its configuration needs the update described in the decision note.

## 5. Component checks

Each check names a question that the §4 evidence must answer.

| Component | Questions |
|---|---|
| **UFH estimates and uncertainty** | Do working-scale inputs match direct estimates after transformation? Do back-transformed estimates and MSEs match the references? Does change inference state its independence assumption? |
| **MFH covariance** | Does the covariance option used match the one reported, including the zero override? Are logged-scale covariances correctly converted? Is the sampling covariance matrix valid per domain? |
| **MFH fit and convergence** | Do endpoints pass independent checks? Do original fits and bootstrap refits use the same rule? Are boundary fits labelled everywhere? |
| **MFH change uncertainty** | Do annual MSEs and MCPE come from one joint bootstrap? Does invalid inference stay unavailable? Are Monte Carlo errors reported? |
| **Alignment** | Are weights, domains, years, PSUs and strata matched by identity, not row order, across survey, auxiliary, geometry, population and target files? |
| **Benchmarking** | Do constraints hold on the reporting scale? Is the benchmark repeated inside each draw? Are survey targets treated as random and uploaded targets as fixed, as documented? |
| **Documentation and UI** | Do UI text, reports, guides and the deviations note describe what the code does? Do the English, Polish and Greek materials agree? |

## 6. Reference comparisons

Passing a comparison shows agreement with that reference, not validity of the method.

| Component | Reference | Shares code or assumptions? | Proposed tolerance and rationale |
|---|---|---|---|
| Direct estimates and covariance | Hand-coded Taylor linearization from PSU totals | No code shared; same design assumptions | Relative 1e-8; both are closed-form |
| UFH point estimates | `sae::eblupFH` where the model matches | Different code. It is in the lock but no `eblupFH(` call appears in the repository | Relative 1e-5; both use iterative fitting. Applies to untransformed models |
| UFH corrections | `emdi::fh` | **Shares code:** production wraps emdi. This checks the wrapper only | Relative 1e-10; existing tests use 1e-12 |
| MFH fit | Block and dense REML algebra in the tests | Independent of msae, but written within this project | Relative 1e-6 on the likelihood and parameters |
| MFH original procedure | Molina-Romero authors' code, if obtainable | Would be the only truly external reference | Decide after obtaining it. **Not available in the repository** |
| Benchmarking | Closed-form ratio constraint | No | Relative 1e-8 on the constraint |
| Rerun reproducibility | Same seed, same environment | Same code | Relative 1e-10; only floating-point noise should remain |
| Cross-platform reproducibility, if E4 runs | Windows output | Same code | Relative 1e-6; numerical libraries differ. Larger differences are disclosed |
| Bootstrap quantities | Rerun with a different seed | Same code | Within 3 Monte Carlo standard errors; this is noise, not an exact target |

**Where no reference exists, use known-truth simulation.** The full workflow has no reference: complex design, estimated variances and covariances, model selection and benchmarking together. [MCPE_VALIDATION_STATUS.md](../../validation/MCPE_VALIDATION_STATUS.md) and the deviations note both record this as unestablished.

| Simulation target | Measures | Proposed threshold and rationale |
|---|---|---|
| Independent-design MFH (new, no existing study) | Bias, MSE ratio, 95% coverage of level and change | At least 2,000 outer samples, giving a Monte Carlo SE near 0.5 points. Flag coverage outside 93–97%, about ±4 SE, for owner review |
| Linked design with estimated covariance | Same | Same |
| Partly overlapping design | Same, under each available declaration | Reported as evidence for QER, no pass mark |
| Full workflow with benchmarking | Same | **Scope and time need owner decision** |

The band is a flagging rule based on simulation precision and was not tuned to earlier results. The published low-signal and boundary scenarios fall outside it, so the owner must decide how they are presented. The proposed approach is disclosure to QER, not a pass.

## 7. Data locality

The claim to verify is that confidential data stays on the analyst's computer unless the analyst explicitly enables AI.

| Path | What the code shows (verified) | Verification at freeze | Pass rule |
|---|---|---|---|
| Local server | Binds to `127.0.0.1` | Inspect listening sockets during a run | No non-loopback listener |
| AI off | `llm_enabled` default off; consent resets when a setup loads | Monitor outbound connections during R1 with AI off | No outbound connection except the listed downloads |
| AI on | `httr::POST` in `R/llm_assistant.R`; comments say only aggregates are sent, which **is not yet verified** | Point `SAE_OPENAI_BASE_URL` and `SAE_ANTHROPIC_BASE_URL` at a local stub on synthetic data, and capture every payload | No row-level value. Domain-level content matches what the consent text says |
| API key | Removed from saved setups; passed to the background run through an environment variable | Search all run outputs for a dummy key | Key appears nowhere |
| Pandoc | Pinned, checksum-verified download on first use; `EU_SAE_PANDOC_OFFLINE=1` forbids it | Confirm disclosure and offline behaviour | Sends no survey data; disclosed |
| Package install | Uses CRAN at install time | Confirm disclosure | Sends no survey data |
| Logs and temporary files | Scripts print diagnostics; `app_runs/_last_setup_files/` keeps copied inputs | Plant marker values in synthetic microdata and search `app_runs/`, `outputs/`, logs and temp folders | Copies stay local and are documented. No marker in anything meant to be shared |
| Reports and exports | Contain domain-level results | Search for markers; review small-domain output | No microdata. Small-domain disclosure is stated as the analyst's responsibility |
| Git safeguards | Hooks are local to the maintainer's machine | Run the marker search on the built ZIP | No country data in the ZIP |

## 8. Final AI review round

There is one bounded round, on the frozen candidate, after §4 has run. Reviewers get the code and fixed questions, not earlier conclusions.

- **Questions:** those in §5, one review per component. Priority goes first to `c8989d4` and its interactions with earlier fixes.
- **Valid finding:** includes a reproducible test or a traced calculation. Anything else is not counted.
- **Methodological opinions:** go to the decision register, not the defect list.
- **After a blocker fix:** re-review only the affected scope.
- **Stop:** every question has been answered once and all findings are resolved. "No more findings" is not the stopping rule.

## 9. Exit criteria for QER circulation

All must be true:

- [ ] Every §1 item is recorded for one candidate, and all documents name it.
- [ ] No confirmed blocker is open, and P1–P4 are closed.
- [ ] §4 is complete. Every case not run is disclosed with its reason.
- [ ] §6 comparisons are complete or disclosed as unavailable, and §7 has passed.
- [ ] The §8 round has reached its stopping point.
- [ ] Review ledger exists: reviewed, fixed, deferred and not covered. It says prior reviews cannot be certified as comprehensive.
- [ ] Methodological decision register exists: Molina-Romero approach, implementation, changes, justification, evidence, limitations and expert questions, with sensitivity results for material choices.
- [ ] Evidence summary separates fresh results from historical ones, without relabelling them.
- [ ] Reviewers, terms of reference, the four classifications, and how each outcome will be resolved are agreed.
- [ ] Candidate and package are labelled **pre-release, not for official statistics**.
- [ ] The package contains no confidential data, and the owner has approved circulation.
