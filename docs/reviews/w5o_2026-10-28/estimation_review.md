# Estimation review — w5o, 28 October 2026

> Amended October 28, 2026 following independent evaluation. This remains a review of the original w5o commit, not a statement of the repaired w5p state. Read the [correction addendum](../w5p_2026-10-28/REVIEW_CORRECTIONS.md) and [implementation ledger](../w5p_2026-10-28/CORRECTION_LEDGER.md) for corrected scope, source locators and repair evidence.

Scope: current root sources at e5319826a1; scripts/01_ufh.R, 02_mfh.R, ufh_functions.R, eblupMFH2_robust.R, population_helpers.R, R/indicator_helpers.R, variance_policy.R, mfh_model_selection.R, msae_compat.R and relevant validation logic. No production changes. Exact manuscript: 29 January 2025 supplied PDF; text in this review directory.


Amended input scope: the named-year bug affects R matrices in RDS/RData, while table readers already match years by name. Both target and population long/wide readers lack unique-key checks at the w5o baseline. Sex/age population rows must be aggregated to the required grain before upload; w5p rejects duplicates even when values agree.

## Confirmed coding findings

### P2 — Identity UFH exports smoothed working variances as Direct_MSE

- Location: scripts/01_ufh.R:981–990, with missing restoration at 1078–1079. Raw `vardir`/`SD` are replaced by GVF values; `sae_ufh_fit` and `estimators()` then export these as Direct MSE. Only the log branch restores `SD_arith^2`; arcsine bypasses smoothing.
- Trigger: identity-scale UFH (poverty without arcsine, FGT1/FGT2, or identity mean welfare), `sm_all`, or `sm_out` for replaced observations. Direct mode's zero/NA safety backfill has the same labelling issue.
- Reproduction: actual production `run_fh_year`, extracted without executing the surrounding pipeline, on 24 synthetic domains. Raw design variance for D01 is 0.006250934; `sm_all` exports 0.006750478 as Direct_MSE. `direct` returns the raw value. See `probe_direct_variance.R` and `.log`.
- Consequence: UFH-step Direct RMSE/CV and model-versus-direct comparisons represent a smoothed variance without identifying it as such. Main Comparison instead uses raw MFH direct variance (`scripts/03_comparison.R:473–479`), so the same run has inconsistent Direct uncertainty across artifacts. This does not alter UFH point estimates; modelling with a smoothed variance is legitimate, but it must remain distinct from raw Direct uncertainty.
- Repair: preserve raw variance independently for every indicator/transform and restore the Direct-MSE column by domain; keep selected model working variance in a separate diagnostic.

### P2 — A domain missing in one year passes readiness as a warning but aborts MFH GVF

- Location: scripts/02_mfh.R:837–853 invokes `varsmoothie_king` on all domain rows, including missing year-specific N; scripts/ufh_functions.R:52 rejects any missing/nonpositive sample size. The later missing-variance exclusion at scripts/02_mfh.R:1485 ff is never reached.
- Trigger: one domain sampled in 2019 but not 2020, while auxiliary data include both years. This is not an exotic numerical boundary.
- Reproduction: `probe_direct_variance.R` calls the real `assess_data_readiness` on 24 domains (one absent in year 2). It returns `estimates_available=TRUE`, “Domain variables are consistent across all datasets” and only “WARNING -- 1 domain-year(s) have missing poverty rates.” Executing unchanged MFH source expressions from year normalization through GVF stops with `GVF requires positive finite sample sizes` in year 2. Script catches this expected failure and exits successfully.
- Consequence: a run accepted past readiness cannot produce MFH results even for the 23 fully observed domains. Either make complete two-year sampling a blocking readiness requirement with affected IDs, or implement documented exclusion before GVF and retain explicit missing output rows. Do not invent nonsampled predictions; M/R p10 generally advises against them.
- A separate suspected downstream `V[1,2]` error was NOT confirmed: installed survey::vcov errors on a one-year svyby object and safe_svyby catches it. Do not report that separately.

### P2 — External population matrix year labels are overwritten instead of matched

- Location: scripts/population_helpers.R:117–122.
- Trigger: supported RDS population input containing a matrix with correctly labelled columns in a different order from analysis years, or labels for the wrong years but the same column count.
- Reproduction: `probe_population_input.R`: input columns 2020,2019 with populations A=(100,900), B=(900,100), requested years 2019,2020. Reader returns A=(100,900), B=(900,100), falsely relabelled 2019,2020, rather than reordering. A weighted mean of rates 0.1,0.5 becomes 0.46 instead of 0.14 for 2019.
- Consequence: both UFH and MFH benchmark weights/adjustments use the wrong year's population, silently. Rows are correctly matched by domain; columns must likewise be matched by year. Reject missing/duplicate year labels, with a separately explicit policy for unnamed matrices.
- Root's uncertainty reviewer is examining the corresponding benchmark-target matrix paths. Avoid counting duplicate manifestations as separate conceptual findings.

## Additional verified methodological observations

- M/R p10 explicitly permits LASSO and recommends BIC preferably. LASSO itself should not be described as departing from the paper. The app's MFH default AIC, screening thresholds, lambda choice, and sequential selection are implementation policies requiring disclosure/sensitivity, not automatic errors.
- M/R p12 example uses `exp(fitted(fit.var))`; `varsmoothie_king` lines 65–70 uses `exp(pred)*exp(residual_var/2)`. This is an additional retransformation choice. It has a conditional-mean justification under Gaussian homoscedastic log-GVF errors, unlike simply exponentiating the fitted log mean. It is not universally unbiased or automatically validated. The sampling-covariance technical note describes the correction; the deviation register should explicitly contrast it with the example and state its assumptions.
- The fixed sm_out threshold 0.001 is genuinely application-specific and documented as such. Its substantive suitability depends on scale/indicator; the same absolute cutoff is especially hard to generalize to identity welfare across currency units. Existing documentation correctly leaves representative validation open.
- MFH2 default versus optional MFH3 sequence is disclosed. The robust MFH2 refit preserves the stated covariance family and checks the REML endpoint; it is a justified numerical repair rather than a new statistical model. Fixed |rho| <= 0.999999 and boundary-inference limits remain real assumptions; do not present the refit as solving coverage.
- Joint bootstrap, conditional covariance treatment, original-scale retransformation, external-target uncertainty exclusion, and UFH temporal independence are disclosed extensions/assumptions in METHODOLOGY_ALIGNMENT.md. Their justification is conditional; disclosure alone does not establish coverage.
- Several potential ordering concerns in emdi were probed and NOT found: the installed package preserves input domain row order for both sampled and interspersed unsampled domains in identity/arcsine fits. Do not claim a domain-order bug there.

## Validation boundaries

Bounded synthetic probes only; no production datasets/output tables were modified. `probe_direct_variance.R` executes real helper/function bodies and actual MFH preprocessing expressions, with expected failures caught. `probe_population_input.R` exercises the actual public population reader. Full regression suite and source/release equality are owned by root. No claim that every remaining error has been excluded.
