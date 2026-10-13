# Methodology alignment and QER repair notes

Date: 2026-10-10. w5n pre-release (QER candidate); see `QER/VALIDATION_RECEIPT.md`
for validation evidence and the scope of the candidate build.

w5o (5.2.0-rc.6-wizard.5.15, 13 October 2026) keeps the estimation methods reviewed here. It
changes the interface (now the EU SAE Workbench), corrects the population weights of survey files
with one row per person (a new survey-unit setting; such files previously needed a household size
of 1) and stops runs in which a domain belongs to more than one benchmark group. With
household-level data its estimates are the same as w5n: in the Spain example check, all 117 output
tables were identical. In w5o the 57-slide guide and its Polish and Greek versions are replaced by
three short guides in English, Polish and Greek; see `CHANGELOG.md`.

The methodological references are Molina and Romero, *Comparable Small Area Estimates over Time*
(the 29 January 2025 manuscript supplied by the maintainer), and Harmening
and coauthors, *A Framework for Producing Small Area Estimates Based on
Area-Level Models in R* (the supplied EMDI note). These references define the
statistical principles. They do not specify every numerical, bootstrap or
application decision. The implementation distinguishes those decisions below.
Verification used R 4.5.2, emdi 2.2.3 and msae 0.1.5.

## Reference-to-implementation mapping

| Topic | Reference and implemented rule | Main source |
|---|---|---|
| Direct welfare | Survey-weighted arithmetic area mean; retain zero/negative individual welfare. The log model requires a positive finite area mean. Apply price conversion before aggregation. | `scripts/01_ufh.R`, `scripts/02_mfh.R`, `R/validation_checks.R` |
| UFH log | EMDI note p.4: log of arithmetic Direct mean with delta variance V/mean². Corrected predictions use native emdi Slud-Maiti `bc_sm`, fitted by ML. The naive option omits correction; it does not change the target into a geometric mean. | `scripts/ufh_functions.R`: `sae_ufh_fit` |
| UFH arcsine | Native emdi point predictions. The naive inverse is clamped to [0, pi/2] before sin², including in bootstrap replicates. Preserve actual Direct variances. | `sae_ufh_backtransform`, `sae_ufh_bootstrap` |
| MFH1 | Molina–Romero p.20: time-specific mutually independent random effects; diagonal G. | `R/mfh_bootstrap_helpers.R`, `R/mfh_convergence_check.R` |
| MFH2 | Stationary AR(1): G(st)=innovation variance × rho^abs(s−t)/(1−rho²). Innovation variance and marginal variance are different. | same sources; `scripts/eblupMFH2_robust.R` |
| MFH3 | Time-varying innovation variances; initial u0 ~ N(0,1), so u1=rho*u0+a1. Fitting and simulation use the same initial-state covariance. | `sae_mfh_random_effect_covariance`, `sae_simulate_mfh_random_effects` |
| Default model | MFH2 remains default because MFH3 failed to converge in the Spanish and Polish applications. Selecting MFH3 starts the p.21 variance-structure sequence, falling back to MFH2 if its endpoint is unusable or the variance contrast does not support MFH3. | `R/mfh_model_selection.R`, `scripts/02_mfh.R`, both app interfaces |
| Change uncertainty | M/R p.36: MSE(change)=MSE1+MSE2−2*MCPE. All three moments come from the same accepted bootstrap draws. Invalid joint moments yield unavailable inference, never an invented independence fallback. | `sae_mfh_bootstrap`, `sae_joint_error_moments` |
| Multiplicity | M/R p.37 warns about multiple comparisons. Pointwise tests remain the primary display by the maintainer's choice; BH and Bonferroni sensitivities are also exported. The MFH3 variance-structure test is separate. | `scripts/02_mfh.R`, `scripts/03_comparison.R` |

MFH3's fixed initial variance of one also makes its covariance family sensitive
to the measurement scale: for example, G11=innovation1+rho². This mathematical
feature can contribute to difficult fitting on proportion-scale outcomes; it
is not evidence that every MFH3 non-convergence is a software defect.

## Explicit extensions and assumptions

- **Bootstrap:** the supplied M/R manuscript does not develop a complete MCPE
  bootstrap. The package's extension generates correlated random effects and
  sampling errors, refits the same model and accumulates prediction-error
  products. MSE is a second moment, not a centered sample covariance. A draw
  is accepted jointly only when the fit and all predictions are usable.
- **MFH log prediction:** the paper's linear MFH formulas do not prescribe a
  bias-corrected currency estimator. The package uses the fitted Gaussian
  conditional mean `exp(eta + v/2)`, with
  `v=diag(G-G(G+R)^(-1)G)`. Annual MSE and MCPE are bootstrapped after inverse
  transformation. This is not emdi's univariate Slud-Maiti correction. Saved
  MFH settings named `bc_sm` are accepted as a legacy alias for this new method.
- **Benchmarking:** perform the final ratio adjustment in the reported units
  inside every bootstrap replicate. Recompute survey-derived targets from
  that replicate's direct estimates. Keep uploaded external targets fixed;
  their uncertainty is not modeled. Conditional bootstrap calculations hold
  auxiliary variables, chosen formulas, populations and sampling covariance
  estimates fixed; they do not include variable-selection or GVF-estimation
  uncertainty.
- **Numerical fitting:** a package convergence flag alone is insufficient.
  Check REML score, local curvature and feasible boundary directions. Refit
  MFH2 if needed, retain a valid original fit, and reject an inferior refit.
  True zero-variance endpoints remain eligible for bootstrap inference.
  The stationary AR(1) correlation is numerically bounded at ±0.999999; an
  accepted endpoint there approximates a limiting fit, not an interior
  maximum. Selected annual uncertainty uses bootstrap on both scales.
- **Sampling covariance:** repair invalid domain sampling covariance matrices
  once before original fitting, then use exactly those matrices for every
  bootstrap simulation and refit. Record changes in
  `mfh_sampling_covariance.csv`. Sampling-correlation smoothing and the
  application-specific `sm_out` threshold of 0.001 remain disclosed choices,
  not universal rules supplied by either reference. For log means the
  threshold applies to the log-scale variance.
- **UFH changes:** separate yearly UFH fits retain the explicitly exported
  `period_independence` assumption. A joint survey covariance model has not
  been invented for these fits. This limitation matters with overlapping
  samples or longitudinal dependence.
- **Mean percentage changes:** use a first-order log-ratio variance based on
  the same joint original-scale moments, and exponentiate the interval.
  Annual and change uncertainty must never be mixed across estimators.
- **Diagnostics:** MFH residual plots use
  `(Direct−EBLUP)/sqrt(diag(RPR))`, where P accounts for fitted fixed effects.
  Residuals remain correlated; Shapiro-Wilk and residual-versus-fitted
  regressions are descriptive checks, not exact independent-sample tests.

## EMDI discrepancies that must remain visible

The supplied note p.5 displays a full-real-line integral for corrected arcsine
prediction. The tested emdi 2.2.3 integrates over [0, pi/2]. The package retains
that point-estimator behavior for compatibility and bootstraps that same
estimator. It reports substantial Gaussian mass above pi/2 (over 1%) because
upper-boundary truncation can have a large effect. This is an upstream
paper-versus-package discrepancy, not evidence that the correction is
unbiased at every boundary. The naive bootstrap now uses the same clamp as
its point estimator, unlike the unclamped upstream bootstrap expression.

Native emdi `bc_sm` does not supply corrected log predictions for unsampled
areas. Those values remain unavailable; benchmarking requires complete
usable predictions for the requested benchmark population. No ad hoc
smearing factor is substituted.

## Evidence and implications for circulation

The added tests compare UFH predictions and MSE directly with installed emdi;
check MFH bootstrap identities independently; compare block REML algebra with
dense calculations; exercise zero/correlation boundaries and failed fits;
and verify final currency-scale benchmark constraints. The oracle simulation
uses independent Gaussian/lognormal formulas. Fitted simulation pilots are
separate from those exact-parameter checks. See `MCPE_VALIDATION_STATUS.md`
for the evidence and its limits. The larger MFH2 study uses 2,100 outer samples
and 500–1,000 bootstrap draws. Ordinary designs have approximately 94.3–94.9%
absolute-change coverage against nominal 95%. A low-signal design has 87.4%;
its 110 correlation-limit fits have 65.2%. These are scenario-specific results,
not universal rates. Boundary-sensitive inference is now explicitly flagged
as provisional. Increasing bootstrap draws alone cannot repair this limitation.

Revising documentation alone would not address these defects. Log-welfare
point estimates, uncertainty, change significance and some MFH2 poverty
estimates can change. On the saved Spanish fitting frame, the checked MFH2
restricted log-likelihood improves from 170.397 to 172.771 and the largest
annual point-estimate change is about 8.05 percentage points. This is a
specific saved-run comparison, not a forecast for every country or setup.
The fitted correlation reaches the numerical stationary limit; inspect its
bootstrap diagnostics and sensitivity before using the results externally.

The w5n QER candidate includes revised English guidelines, four technical notes,
the 57-slide guide, download instructions, app help and report prose. Historical
figures in the guidance are explicitly illustrative. New isolated Spanish example
runs exercise the revised calculations; archived country setups still require
review and rerunning before their results are circulated. The Polish and Greek
user guides were updated to 5.14 on 11 October 2026. This candidate is suitable for QER
methodological review, not a certification of frequentist coverage under all
survey designs. See `QER/QER_README.md` for the completed checks, remaining QER
decisions, and the disclosed background-test incident affecting current outputs.
