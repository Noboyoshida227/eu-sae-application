# Independent follow-up review: sm_all defaults and the two-year publication rationale

Date: October 28, 2026. Candidate: `EU_SAE_520_w5p`, `5.2.0-rc.6-wizard.5.16`, still uncommitted. This review covers the owner's subsequent request to default to full variance smoothing and explain the official-statistics rationale for T = 2. It supplements, rather than replaces or retrospectively changes, [the initial independent review](INDEPENDENT_REVIEW.md).

The reviewer did not implement the production changes. Findings were communicated to the code, documentation and coordinating agents; the reviewer inspected the resulting changes and independently executed the focused variance-default test. No commit, push, publication or statistical coverage campaign was performed.

## Code review and findings

No unresolved material coding finding was identified in the reviewed follow-up source snapshot. The following issues were specifically traced and addressed:

| Review point | Resolution |
|---|---|
| Updating a visible default alone would leave other defaults/fallbacks inconsistent. | Shared policy helpers resolve missing/NULL/empty/NA settings to `sm_all`. Validation, standalone scripts, dashboard setup collection/restoration and analysis serialization use the same policy. An omitted MFH covariance follows the effective variance: `sm_all`/`rho_sm_all`, `sm_out`/`rho_sm_out`, or `direct`/`rho_dir`. Explicit settings and the legacy `rho_sm` meaning are retained. |
| Log-UFH previously hid its variance control and the app forced `sm_out`, although the estimator could honor other choices. | Both interfaces now expose the selector for identity and log models. Pipeline YAML and the analysis brief report the selected policy. Actual log variance smoothing applies to the delta-method sampling variance of the log arithmetic area mean. Arcsine remains separate and uses `1/(4*n_eff)`. |
| Restoring an older dashboard log setup can activate a formerly hidden choice that was not previously applied. | The stored choice is preserved, with a load-time notice explaining that older dashboards actually used `sm_out` for log runs. Newly saved setups carry a metadata marker for the visible-policy interface. The documentation distinguishes dashboard inputs from the actual prior pipeline configuration; preservation of a hidden value is not represented as guaranteed numerical reproduction. No guessed migration is applied. |
| Changing variance could overwrite an explicit compatible MFH covariance choice. | The observer retains `direct` or `zero` when compatible, and otherwise selects the matching pooled-correlation option. Saved setup policy fields are normalized before merging defaults, so an old explicit variance is not silently paired with the new default covariance. |
| Full smoothing must not contaminate the raw Direct uncertainty labels. | Actual identity/log UFH test fits retain identical raw Direct MSE across working-variance policies. Arcsine point estimates and its variance audit remain independent of the new GVF default. |

The reviewer examined the follow-up diffs against the earlier repaired source snapshot, including `R/variance_policy.R`, both interfaces, configuration validation, `R/brief_generator.R`, both estimation scripts, test registration and the new tests. The independent command was:

```text
Rscript --vanilla tests/test_variance_defaults.R
```

Using R 4.5.2 and the session's configured library through `R_LIBS_USER`, it completed with **66 passed checks and exit status 0**. Tests use isolated temporary artifacts. Checks exercise actual setup collection/restoration prefixes, legacy notices, covariance-observer behavior, rendered controls in both interfaces, YAML serialization, generated briefs, production MFH column selection and actual identity/log/arcsine UFH fits. They establish that omitted UFH settings match explicit `sm_all` in these fixtures and that explicit alternatives retain their behavior. Windows locale and native-encoding warnings for existing en-dash labels were reported; they did not cause failed checks.

This reviewer did not rerun the full regression suite. Fresh full-suite, dependency and package-build results belong to the coordinating agent's follow-up receipt and must not be attributed to this 66-check execution.

## Two-year rationale and methodology review

The revised deviations note, alignment register and README explain a deliberate publication policy, rather than claiming that the general MFH model requires two periods. Successive available survey-year windows can revise each newly reported estimate once, then retain it as final. They need not be consecutive calendar years. The texts explicitly assign scheduling, vintage archives, freezing and exceptional reopening to the statistical office; the application does not enforce adjacency or a publication freeze.

The reviewer raised an additional coherence condition that is now disclosed: the shared-year estimate changes between successive windows. A historical annual series assembled from frozen estimates can therefore combine different fits. Within-window MSE/MCPE supports the two estimates from that same fit; it does not automatically supply uncertainty for a difference between estimates from different windows. Pair-specific levels, changes and joint uncertainty must remain associated with their window and vintage. This qualification is also present in the revised guide material.

The `sm_all` default is correctly described as closer to the manuscript's full-smoothing illustration, not as a universal requirement or a proof of improved accuracy. The separate GVF lognormal retransformation, pooled sampling correlation and conditional-input bootstrap assumptions remain visible. Optional `sm_out` retains its original cutoff; its earlier illustrative replacement counts and the earlier explicit-`sm_out` baseline comparison are not relabeled as evidence for the new default. New/default-omitted runs may intentionally change model estimates, selection, uncertainty and significance.

## Documentation and translation checks

The reviewer read every entry in the follow-up Office change register and all **31 changed/new English, Polish and Greek translation units** side by side. The following corrections were requested and verified in the final change registers:

- The arcsine text no longer implies that raw sampling variances are backfilled. It identifies the distinct effective-sample-size working variance and fallback to observed sample size when the estimated effective sample size is invalid.
- Office change locators use stable section/phrase descriptions; extraction indices are separate internal metadata.
- The publication-policy headline now says “Revise each annual estimate once,” avoiding an interpretation of repeated yearly revisions.
- The Polish boundary-significance wording explicitly means provisional rather than merely conditional.

No material mistranslation remained identified in those 31 units. This is an independent semantic check, not country-team linguistic certification. The root Markdown also correctly qualifies smoothing for log models as smoothing the sampling variance of log area means and explains the legacy-dashboard caveat.

Final regenerated Office/guide layout, tracked-change reversibility and active-PDF synchronization are subject to the artifact follow-up below. Semantic approval of source text does not by itself establish the rendered layout.

## Integration evidence reviewed and limitations

The reviewer inspected the updated integration runner and its saved logs. `--variance-policy=default` actually omits the UFH/MFH variance and MFH covariance YAML fields; it does not substitute explicit `sm_all` before execution. Assertions check the effective `sm_all`/`rho_sm_all` artifact settings and variance audit. The completed default poverty and log runs each record 50 accepted and zero failed draws, with 3 and 8 accepted covariance-boundary draws respectively. The explicit-`sm_out` poverty continuity run records 50 accepted, zero failed and 6 boundary draws. Those integrations were executed by the coordinating agent, not independently rerun here.

The final comparison script, detailed CSV, summary CSV and explicit-policy compatibility CSV were reviewed. Independently recalculating all eight summary rows from the detailed CSV reproduced their record counts, counts changing above `1e-10` and maximum absolute changes. The five poverty/log fixture inputs were byte-identical between the earlier and new-default integrations. For both scenarios, the saved configurations also matched after removing the variance/covariance policy keys and normalizing the fixture paths. These are checks of the recorded comparison, not new model runs. The four explicit-`sm_out` compatibility workbooks are reported as matching at tolerance `1e-8`; the new-default results intentionally differ.

The final [portable validation receipt](../../W5P_VALIDATION_RECEIPT.md) and [follow-up revision record](SM_ALL_REVISION.md) distinguish the coordinating agent's fresh 487/0/0 main-suite result, 46/46 dependency check, 40 background checks and UI parity result from the earlier repair-only evidence. Their integration counts and policy-change descriptions agree with the reviewed evidence. Their complete 50-/48-page report layout review belongs to the coordinating agent. This reviewer did not repeat those full suites, report renders or bootstrap integrations.

These small integrations assess execution and numerical invariants. They do not demonstrate that the new default uniformly improves stability or coverage. GVF adequacy, estimated-input/selection uncertainty, survey dependence, boundary undercoverage and mixed-vintage inference remain conditional or unresolved matters. T = 2 supports a controlled publication workflow but is not an optimality result. The earlier explicit-`sm_out` equivalence results and historical coverage studies retain their original scope.

## Reviewed source snapshot

These SHA-256 values identify the local contents reviewed; they do not identify a new commit. Later changes require the affected checks again.

| Repository path | SHA-256 |
|---|---|
| `R/variance_policy.R` | `9fb6af45718ccdb63e9eaf5f1c63dca6788e27f861566e74b33beec8896190b2` |
| `R/brief_generator.R` | `a15182132a548a7f9cdb1e38a0b2215c4f4d2ad449224fae3b79235b3fc2b1b5` |
| `app.R` | `38349608df31591a3cb69df8f147fba8defb1f21152d7f96513fddec616e6dde` |
| `app_wizard.R` | `aa9ab3f116f40475cd44997283787155a14a75e292e15969e66cd48aab503d68` |
| `app_support.R` | `b2f4345372585b0efea40829c874157113ed149f6a86db137a86e949f8c9d457` |
| `scripts/01_ufh.R` | `6d945b1d6a8c37c70cf0d8a01b9a9a715b73be4a643f49efa01ff757fa5ee2a0` |
| `scripts/02_mfh.R` | `a0ed0f3e0acc7a92f811d03a3cc7e3faae197d6a37d13b9eaa636d1aa2bcccf2` |
| `tests/test_variance_defaults.R` | `cd2d64a29603e2be1bf4d37dfd01201ef3dea532ee46e23f22de27bfc403e867` |
| `tests/test_w5p_integration.R` | `67f86c717ac5ca4a2f1d26bf0247a41d6cf002f00612936f3b4b1baa07544176` |
| `docs/MOLINA_ROMERO_DEVIATIONS_w5p.md` | `3f7472445ace73c0d2527bc50b5c83daae33f462c42609daf3148ba40a9bdbc5` |

## Final artifact follow-up

Closed on October 28, 2026, after the final documentation repairs and before the revised private verification build. No further material source, methodology-description or artifact finding remained identified within this review's scope.

- Independently inspected the final guidelines pages 108–109. Section 15.2 now correctly distinguishes a valid zero random-effect variance boundary from inadmissible covariance values and directs readers to the boundary-inference qualification. The two-year revision sequence, alternative latest-year-only publication policy, NSO controls and uncertainty limitation for estimates from different runs are readable and consistent. The main deviations note describes the one-scheduled-revision policy; the guidelines additionally explain the alternative policy without claiming that either is enforced by the application.
- Inspected final Polish and Greek Guide 3 slides 19 and 21 and Guide 2 slide 10. The shortened historical-example labels fit without overlap; the publication-policy slide and current `sm_all`/`rho_sm_all` default explanation are legible. The retained old screenshot is expressly labeled as historical. The final translation register also preserves the alternative-policy cross-reference in the publication-policy speaker note.
- Independently reconstructed all three tracked Word documents against each of two baselines: original w5o and the earlier repaired w5p. Accepting every change reproduced the exact canonical clean document-body XML, including tables; rejecting every change reproduced the corresponding baseline body XML. All 168 guidelines equations, 46 sampling-covariance-note equations and 32 MSE-note equations remained exactly unchanged. Current clean/tracked file hashes matched the verification records. The latest redlines contain 244/56/5 changed-run pairs against w5o and 173/26/0 against the prior w5p, respectively.
- Verified that both updated active PDFs are byte-identical to their final rendered counterparts. The 141-page guidelines PDF has SHA-256 `58d0c69ebb64cefeb31918c8fc08a0919469f93bc0b7caf0d3c4aa3ca9606190`; the sampling-covariance PDF has SHA-256 `586d9fc16b6f14fd29fd75b68152d43b8bc18604c624394ff405941c7c1b15fb`. All 18 active guide PDF/PPTX files match the final guide-deliverable manifest. All ten source hashes listed above remained current at closure.

The retained artifact evidence is under `Claude outputs/w5p_review/followup_sm_all/`, including `guide_translation_changes.json`, `guide_deliverable_manifest.json`, the rendered page/slide images and redlines from both baselines. This independent review is a targeted code, semantic and artifact check. It is not full statistical certification or a new complete-page review of every document. Final source-kit/archive construction and package verification remain the coordinating agent's responsibility; no archive verification or publication is claimed here.
