# Decision note: the "not specified" PSU setting — DRAFT

**Status:** the owner approved option (a) and the §5 work on 30 October 2026. Sections 1–5 record the position at commit `c8989d4`; see "Rollout status" at the end.

## Summary

- **"Not specified" already blocks MFH.** The behaviour of option (a) is in place at `c8989d4`, enforced in the UI, in configuration validation, in the script and in the design helper. UFH-only runs continue.
- **The rollout is incomplete.** All six bundled Spain_2y configurations and the synthetic integration test now stop, because neither declares a design.
- **Recommendation:** keep option (a), and finish the rollout before QER-RC1 is frozen.
- **Main open question for QER:** surveys that partly overlap, or overlap without linkable PSUs, currently have no MFH route.

## 1. Current behaviour

Paths are relative to the repository root. All statements in this section were verified by reading the code at `c8989d4`.

| Stage | What happens when the setting is "not specified" | Location |
|---|---|---|
| UI | Default selection in both interfaces. Label: "Not specified: overlap exists but cannot be linked, or I am unsure" | [app.R:261](../../../app.R:261), [app.R:1429](../../../app.R:1429), [app_wizard.R:1028](../../../app_wizard.R:1028), [pipeline_helpers.R:1454](../../../R/pipeline_helpers.R:1454) |
| Saved setups | `psu_design` wins; if absent, a legacy `TRUE` means linked; anything else means not specified | [pipeline_helpers.R:1425](../../../R/pipeline_helpers.R:1425), [app.R:297](../../../app.R:297), [app.R:2572](../../../app.R:2572) |
| Readiness | `PSU design: ERROR` when MFH is selected. A note on the independence assumption when it is not | [pipeline_helpers.R:1463](../../../R/pipeline_helpers.R:1463), [app.R:4280](../../../app.R:4280) |
| Run start | `validate_app_config` rejects the whole configuration if MFH is among the steps, so UFH does not start either | [app_support.R:64](../../../app_support.R:64), [app.R:4763](../../../app.R:4763) |
| MFH script | Stops before reading data, including for direct or background runs | [02_mfh.R:134](../../../scripts/02_mfh.R:134) |
| Design helper | Refuses to build a design | [pipeline_helpers.R:1478](../../../R/pipeline_helpers.R:1478) |
| Direct estimates, sampling covariance, MFH fit, change uncertainty | Not reached | Follows from the stops above |
| UFH-only run | Runs. Direct and UFH change inference assume independent years | [change_comparison.R:101](../../../R/change_comparison.R:101), [release_controls.R:111](../../../R/release_controls.R:111) |
| Report | PSU row shows "Not recorded" for a UFH-only run, because only the MFH step writes the label. The row is headed "(MFH)". The UFH assumption has its own row | [02_mfh.R:1776](../../../scripts/02_mfh.R:1776), [report.Rmd:304](../../../report.Rmd:304) |
| Analysis brief | Records the choice and says MFH needs confirmation | [brief_generator.R:111](../../../R/brief_generator.R:111) |

## 2. Comparison of the three settings

| | Not specified | Linked | Independent |
|---|---|---|---|
| Assumption | None; the analyst has not confirmed the design | PSU and stratum codes mean the same units in both years | Surveys were sampled independently |
| MFH | Blocked | Runs | Runs |
| Survey design | None | One pooled design, as before this change | Year-specific PSUs and strata |
| Sampling covariance | Not reached | Chosen option, using estimated covariance or national correlation | Forced to zero, whatever was requested |
| Random-effect covariance | Not reached | Estimated | Estimated, not constrained |
| Readiness text | ERROR | Asks the analyst to confirm stable codes | States zero covariance and no random-effect constraint |
| Direct and UFH change | Independent years | Independent years | Independent years |

Locations: [pipeline_helpers.R:1477](../../../R/pipeline_helpers.R:1477), [02_mfh.R:992](../../../scripts/02_mfh.R:992), [02_mfh.R:1448](../../../scripts/02_mfh.R:1448).

## 3. Legacy impact

Before `c8989d4`, the checkbox was only recorded and did not affect estimates ([CHANGELOG.md:89](../../maintenance/CHANGELOG.md:89)). Every MFH run used the pooled design, which is what "linked" now does.

| Earlier setting | Now maps to | Effect |
|---|---|---|
| Checked | Linked | Same direct estimates and covariance, per `tests/test_psu_design.R`. Traced, and not compared end to end on a full MFH run |
| Unchecked (the old default) | Not specified | MFH is blocked until the analyst chooses |
| Key absent | Not specified | MFH is blocked until the analyst chooses |
| Unchecked, then analyst chooses linked | Linked | Same as the earlier run |
| Unchecked, then analyst chooses independent | Independent | Results can change: sampling covariance becomes zero, so fitted values and change uncertainty can shift |

**Result change:** a legacy setting never silently changes a result. It either reproduces or stops. A change requires a new explicit choice of "independent".

**One other change:** with strata mapped but entirely missing, the old MFH script fell back to an unstratified design, while it now stops at [pipeline_helpers.R:1481](../../../R/pipeline_helpers.R:1481). UFH still falls back at [01_ufh.R:620](../../../scripts/01_ufh.R:620). Traced only.

### How much the declaration matters

This check used the bundled synthetic Spain_2y survey with original-line poverty and no strata, in a temporary copy. It compares direct estimates only and did not fit MFH.

| Measure | Result |
|---|---|
| PSUs per year, and shared | 442, 442, all 442 shared |
| National estimates, linked and independent | Identical: 0.20567 and 0.21382 |
| Annual domain variances, independent ÷ linked | 1.0000 in every domain |
| National sampling correlation | 0.561 linked, 0 independent |
| Domain sampling correlation, linked | Median 0.696; range −0.298 to 0.994 |
| Direct change variance, using covariance ÷ assuming none | Median 0.362; mean 0.403; range 0.012 to 1.253 |

In this teaching example, wrongly declaring independence would make the median direct change variance about 2.8 times too large (1 ÷ 0.362). This is one synthetic dataset, selected for moderate correlation, so it shows that the choice matters but does not estimate a typical effect.

## 4. Options

| | (a) Require a choice before MFH | (b) Continue with defined behaviour and warnings | (c) Default to linked or independent, with a warning |
|---|---|---|---|
| **Statistical implications** | No unconfirmed design assumption enters MFH | Needs a new defined behaviour, such as bracketing results across zero and estimated covariance. No such method exists in the package | Linked may use meaningless cross-year matches. Independent drops real covariance |
| **Risk of misleading results** | Lowest. The remaining risk is an analyst choosing an answer just to proceed | Moderate. Numbers circulate with a warning that may be lost | Highest. A plausible result rests on an assumption nobody confirmed |
| **Effect on non-technical analysts** | One clear question, and a stop if unsure. Some cannot run MFH until they get advice | Fewest stops, but they must interpret two sets of results | Easiest, and it hides the decision |
| **Effect on legacy use** | Old unchecked setups stop until answered | Old setups run, possibly differently | Linked reproduces earlier results. Independent changes them |
| **Implementation size** | Already implemented. Small rollout work remains | Large: new method, reporting and validation | Small code change, plus reversal of tests and guidance |
| **Tests needed** | Bundled configurations, integration, and data-conflict cases | All of those, plus simulation of the new method | Reversal of the blocking tests, plus default-specific tests |
| **Documentation or wording** | Rollout list in §5 | New method section, report labels, guidance and deviations entry | New stated default and deviation in every guide |

**Variant of (c), rejected:** a default to linked would reproduce legacy results, but `c8989d4` deliberately stated that an unchecked box never established a design.

## 5. Recommendation

**Keep option (a).** The cross-year design is a fact about the survey that software cannot infer, and shared code values prove neither linkage nor independence. Stopping is the only option that never gives a plausible number on an unconfirmed assumption. It needs the least new method, which suits a candidate about to be frozen.

### Work needed before freeze

These are small, but they are code or data changes that need the owner's approval.

| # | Change | Why |
|---|---|---|
| 1 | Add `psu_design: linked` to the six Spain_2y configurations | They all fail validation now. `GENERATION.md` records 442 paired PSUs, and the verified runs used the pooled design |
| 2 | Refresh the Spain_2y receipts that record configuration hashes | Item 1 changes those files |
| 3 | Add `psu_design` to `tests/test_w5p_integration.R` | The test stops at `02_mfh` |
| 4 | Add a test that every bundled configuration passes validation | No test caught this. CI has no `survey.rds`, but the configurations are tracked |
| 5 | Add the PSU step to `Data/Spain_2y/START_HERE.md` and fix `Data/simulated/README.md` line 26 | One omits the choice. The other still refers to the old "PSU-consistency question" |
| 6 | Warn when "linked" finds no shared PSU across years, or no shared stratum–PSU pair | Otherwise covariance is near zero with no explanation. See §7 |
| 7 | Tell the analyst to deselect MFH to run UFH alone | The current message does not say so, and the default steps stop the whole run |
| 8 | Update the deviations note, methodology alignment, guidelines, slide guides, Polish and Greek guides, and changelog | Only `README_WIZARD` and `PACKAGE_REFERENCE` changed in `c8989d4` |

Item 6 is the only one that changes decision logic, and it warns without blocking. Whether the "Not recorded" report row should be filled in is minor and can wait.

### Questions for QER

1. **Partial overlap.** Surveys with rotating or partly overlapping samples may fit neither option. Is the pooled "linked" design acceptable when only some PSUs are shared, and when should it be avoided?
2. **Overlap that cannot be linked.** MFH is currently unavailable here. Should that stand, or is there an acceptable route, such as a design-informed covariance or a sensitivity bracket?
3. **Direct and UFH change.** Both assume independent years even when the analyst has declared linked PSUs. Is that acceptable, given that the report compares them with MFH?
4. **Random effects under independence.** Is leaving the MFH random-effect covariance unconstrained appropriate for independently sampled surveys?
5. **Covariance options.** With linked data, when is the national correlation preferable to domain-level covariance?

## 6. Acceptance criteria

All must pass on the frozen candidate before this decision is closed:

1. `not_specified`, a missing key and a legacy `FALSE` each block MFH in the wizard, the dashboard, `validate_app_config`, `run_pipeline_from_config`, the background run and direct execution of `02_mfh.R`.
2. Each block happens before existing outputs are overwritten.
3. UFH-only and UFH-plus-Comparison runs complete, and reports state the independence assumption.
4. Legacy `TRUE` maps to linked, and an explicit `psu_design` overrides any legacy key.
5. All six Spain_2y configurations pass validation and run to completion.
6. Spain_2y linked results match the pre-`c8989d4` verified outputs within gate tolerance, for all six configurations.
7. The integration test passes both scenarios.
8. With independent selected, every requested covariance option resolves to zero, and the report, workbook and brief state zero.
9. Independent annual variances match separate-year designs, including singleton strata and unequal PSU counts.
10. The conflict warning appears when "linked" finds no shared units, and does not appear for Spain_2y.
11. UI text, reports, guides and the deviations note describe the same behaviour, in all languages supplied.

## 7. Evidence and limits

### Commands run

All were run from a `git archive HEAD` copy in the temporary session folder, so the repository was not touched. The copy read `Data/Spain_2y/survey.rds` from the repository, which is synthetic.

| Command | Result |
|---|---|
| `Rscript tests/test_psu_design.R` | Displayed output ended in PASS lines with no error. Only the last eight lines were captured |
| `validate_app_config(yaml::read_yaml(f))` for each `Data/Spain_2y/run_config_*.yml` | **All six invalid**, with the "MFH requires a specified cross-year PSU design" message |
| `Rscript tests/test_w5p_integration.R --variance-policy=sm_out --scenario=poverty --replicates=50 --render=false --output-parent=<temp>` | **Failed** at `poverty/02_mfh` with the same message; exit status 1 |
| Temporary script comparing linked and independent designs on Spain_2y | Figures in §3 |
| Temporary synthetic script with a stratum that is singleton in one year, under `lonely.psu = "adjust"` | Independent annual and domain variances matched separate-year designs (ratio 1.0000), and cross-year covariance was about −7e−21. This checked a concern and **found no problem**, in one fixture only |

### Not done

- No MFH model was fitted under the three settings on Spain_2y, so the effect on final MFH estimates and change intervals is unmeasured.
- The full test suite and the end-to-end release were not run.
- Item 6 was not prototyped; it rests on reading the design code, which uses `nest = TRUE`, so a PSU that changes stratum is treated as a different unit.
- The linked claim for `Data/simulated` rests on its README and was not checked in its data.
- Polish and Greek guides and the slide decks were not read in detail. A text search of `docs` for the new wording found it only in the English wizard README.
- Whether partial overlap applies to any target survey was not established.

## Rollout status

Applied to the working tree on 30 October 2026, uncommitted.

| §5 item | Status |
|---|---|
| 1. Declare linked in six configurations | Done |
| 2. Receipts | Done with a new [bridge receipt](../../../Data/Spain_2y/verification/psu_design_bridge_receipt.json). Historical receipts were left unedited |
| 3. Integration test | Done; both scenarios pass with 50 draws |
| 4. Bundled-configuration test | Done, in `tests/test_psu_design.R` |
| 5. Data guides | Done |
| 6. Linked-conflict warning | Done for readiness, the MFH log and the report |
| 7. "Deselect MFH" message | Done |
| 8. Documentation | Done, except that the Polish and Greek Guide 2 PDFs still show old text. PowerPoint here cannot open those decks, including the committed Polish version, so the PDFs were not regenerated. The new Polish and Greek slide text needs a native speaker's review and a render check |

**Rerun check:** `run_config_sm_out.yml` matched its saved outputs in 22 of 22 CSV tables, and `run_config_mean_welfare_sm_out.yml` in 20 of 20. The other four configurations pass validation but were not rerun. Acceptance criterion 6 stays open until the frozen-candidate rerun.
