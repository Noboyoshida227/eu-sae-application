# MCPE bootstrap validation status

Date: 2026-08-24, updated 2026-10-10
Build: 5.2.0-rc.6-wizard.5.14 / EU_SAE_520_w5n

## Purpose and provenance

The package estimates the mean crossed-product error (MCPE) needed for uncertainty about changes over time by parametric bootstrap. Prof. Isabel Molina provided the basic code, Ifeani improved it, and the package maintainer modified it further for MFH1/MFH2/MFH3 dispatch, reproducible seeds, refit handling, diagnostics, and reporting. Responsibility for the adapted implementation and its validation remains with the package team.

## Checks completed in this revision

- Corrected the MFH3 bootstrap data-generating process so the first simulated random effect contains the initial state: `u0 ~ N(0, 1)` and `u1 = rho * u0 + a1`.
- Added a large-sample moment test comparing the empirical MFH3 random-effect covariance with its theoretical covariance. The test uses 100,000 simulations and a 0.02 absolute tolerance.
- Added deterministic tests for the MFH3-selected Molina-Romero procedure and explicit MFH3 non-convergence fallback; MFH2 remains the application default.
- Added run-level Monte Carlo diagnostics: requested and successful replications, attempts, refit failures, covariance-matrix repairs, seed, and Monte Carlo standard errors for MSE and MCPE.
- Confirmed that, in the current two-year workflow, raw, Bonferroni-adjusted, and BH-adjusted MFH reference-variance-test p-values are identical because there is only one variance contrast.
- All targeted package tests passed. The runtime compatibility check for `msae::eblupMFH3()` and the execution test for deterministic LASSO were skipped in the test environment because `msae` and `glmnet` were not installed.

## Update 2026-09-01

- The first complete run of `tests/run_tests.R` in continuous integration
  (previously it had never run to completion there) found that
  `.safe_sym_inverse()` in `scripts/eblupMFH2_robust.R` could report an
  inverse as *available* for a matrix containing non-finite values on R/LAPACK
  builds where `chol()` does not signal an error for such input. The resulting
  all-NaN inverse would have propagated silently into g3 and MSE. Non-finite
  input is now rejected before any decomposition and reported unavailable,
  making the behaviour identical on every platform. No estimates in earlier
  builds are known to have been affected; the condition arises only when a
  Fisher-information or covariance matrix already contains NaN/Inf.

## QER implementation and validation update — 2026-10-10

The source changes and departures from the supplied references are documented
in [Methodology alignment](METHODOLOGY_ALIGNMENT.md). MFH2 remains the default.
The implementation now uses one joint bootstrap for annual MSE and MCPE,
repeats inverse transformations and final benchmarking inside each replicate,
and rejects invalid numerical endpoints and incoherent prediction-error
moments. These repairs can change estimates and significance.

Completed on R 4.5.2, emdi 2.2.3 and msae 0.1.5:

- The aggregate `tests/run_tests.R` passes, including 19 UFH methodology
  checks, 23 MFH bootstrap checks and 12 convergence checks. Installed emdi
  predictions and analytical log MSE are checked directly against the wrapper.
- Independent block REML calculations agree with dense matrix algebra;
  stationary minima, stale approvals and inferior refits are rejected. Zero
  variance and both near-unit correlation boundaries are exercised.
- With 30,000 independent known-parameter draws per model, Gaussian change
  interval coverage was 95.037% (MFH1), 94.927% (MFH2), and 94.967% (MFH3).
  Exact transformed-normal annual interval coverage ranged from 95.003% to
  95.230%. Original-scale MSE/MCPE agree with independent lognormal identities
  within Monte Carlo tolerance. These are **oracle checks**, not coverage
  results for estimated models or the production delta-method change interval.
- All three installed MFH estimators complete intercept-only bootstrap checks
  on identity and log scales (20 accepted draws each). MFH3 rejected four of
  24 attempts in this fixture; those rejections are visible diagnostics.
  Survey-derived and fixed-target log benchmarking checks also pass.
- Isolated full Spanish pipeline runs (UFH, MFH2, Comparison) pass for poverty
  and log mean welfare with national benchmarking: 52 domains, 104 annual
  rows, 50 accepted MFH draws and no rejected draws per scenario. Exported
  annual estimates/MSE match the joint bootstrap. These isolated runs left
  repository output hashes unchanged when completed. They check execution
  and consistency, not coverage.

Reproduce the targeted tests with `Rscript tests/run_tests.R`; the installed
packages are required. CI now installs emdi, msae, survey and dplyr so these
statistical regressions cannot silently skip. For local integration use
`Rscript tests/test_pipeline_methodology.R`; the Spanish example data and
full application dependencies must be installed. For fitted-model simulation
use `Rscript tests/test_methodology_simulation.R --coverage --outer=100 --bootstrap=100`.
The scripts accept `--library=/path/to/R/library` where documented.

## Initial fitted-model pilot — 2026-10-10

The final frozen implementation also completed 20 independent outer samples,
30 accepted bootstrap draws per outer sample, and 60 domains, for each of
six model/scale combinations. All original fits and bootstrap runs completed.

| Model | Gaussian absolute-change coverage | Currency absolute-change coverage after log fit | Percentage-change coverage after log fit |
|---|---:|---:|---:|
| MFH1 | 94.75% | 93.50% | 97.08% |
| MFH2 | 92.00% | 91.08% | 93.50% |
| MFH3 | 93.25% | 92.67% | 95.92% |

All intervals target 95%. Percentage-change coverage Monte Carlo standard
errors, computed across independent outer samples, were 0.43, 0.84 and
0.56 percentage points respectively. MFH1/MFH2 rejected no bootstrap draws;
MFH3 rejected 79 of 679 attempts (11.63%) per scale. Failed draws are not
counted as successes or silently reused.

Estimated/empirical absolute-change MSE ratios were 0.992/1.125 for MFH1,
0.885/0.885 for MFH2, and 0.950/1.198 for MFH3 (identity/log scales).
The pilot therefore exposes **undercoverage of normal absolute-change
intervals in this scenario**. This is not a successful coverage-validation
result. Thirty bootstrap draws are below the production recommendation;
20 outer samples, sizeable log-scale variation and fixed known sampling
covariances also limit interpretation. These results do not by themselves
identify an additional coding defect or justify an arbitrary MSE inflation.
The larger MFH2 study below supersedes this pilot for its tested scenarios.
The MFH1/MFH3 pilot remains too small for strong coverage claims.

## Larger MFH2 study completed — 2026-10-10

The study uses 60 domains, two time periods, an intercept and one fixed
covariate per period, normal random effects/sampling errors, and known
sampling covariance. It re-estimates both regression coefficients and
covariance parameters in every outer and bootstrap sample. Log predictions
use the implemented conditional-lognormal correction. Annual and change
intervals use the same uncentered bootstrap error moments as the application;
percentage intervals use its first-order log-ratio variance. No selection,
GVF fitting or benchmarking is included in this coverage experiment.

Four balanced scenarios each use **500 independent outer samples and 1,000
bootstrap draws**, also recording the first 500 draws for a paired count
comparison. The heterogeneous log scenario uses **100 outer samples and 500
draws**. Its sampling variances vary 25-fold in year one and 40.6-fold across
both years. These are designed model experiments, not replications of a
particular country's survey. Seeds, model parameters, software version,
source hashes, outer-sample statistics and summaries are saved under
[QER/evidence](QER/evidence/).

The table reports coverage percentages and Monte Carlo standard errors
(MCSE) in percentage points. Standard errors use independent **outer
samples**, accounting for shared fitted parameters across domains. Target
coverage is 95%; the estimates below do not establish uniform coverage.

| Scenario | Outer / bootstrap | Annual coverage ± MCSE | Absolute-change coverage ± MCSE | Percentage-change coverage ± MCSE |
|---|---:|---:|---:|---:|
| Identity | 500 / 1,000 | 95.01 ± 0.10 | 94.64 ± 0.17 | — |
| Moderate log variation | 500 / 1,000 | 94.68 ± 0.10 | 94.44 ± 0.15 | 94.61 ± 0.15 |
| Large log variation | 500 / 1,000 | 94.57 ± 0.09 | 94.32 ± 0.12 | 96.60 ± 0.11 |
| Low signal, frequent covariance boundaries | 500 / 1,000 | 92.59 ± 0.35 | **87.40 ± 0.66** | **87.26 ± 0.66** |
| Heterogeneous sampling variances, moderate log variation | 100 / 500 | 94.66 ± 0.23 | 94.93 ± 0.32 | 95.13 ± 0.30 |

Estimated/empirical absolute-change MSE ratios (and MCSEs) are respectively
0.997 (0.010), 0.980 (0.009), 1.035 (0.015), 0.956 (0.026), and 1.029
(0.025). Average point-estimate biases are within two MCSEs of zero in all
five designs. This average-bias check is not an area-specific bias guarantee.
Increasing the balanced runs from 500 to 1,000 draws changes average
absolute-change coverage by at most 0.14 percentage points and mean estimated
change MSE by at most 0.044%. More draws improve Monte Carlo precision;
they do **not** remove the boundary-inference problem.

### Independent fitting checks and computation

The large study uses simulation-only, independently derived two-period MFH2
fitters. Balanced designs diagonalize into sum/difference regressions, with
exact REML variance solutions and one-dimensional optimization at the same
correlation bounds as production. Heterogeneous designs use the full block
REML likelihood and analytic gradient, with constrained multiple-start
optimization. Neither fitter enters the application or changes its estimator.

- All 42 production-equivalence fixtures pass the production endpoint gate,
  including zero variance and both correlation limits. Restricted likelihood
  differences are below 2e-8. Balanced and block predictions differ by less
  than 7e-9. Production-point differences below 5e-5 are consistent with the
  native msae rounding of returned predictions.
- Three same-seed production/bootstrap comparisons, 30 draws each, complete
  without rejected draws. Maximum MSE differences are below 0.1%; MCPE
  differences are below 0.06% of mean annual MSE. These checks quantify the
  small numerical/rounding difference rather than assert bitwise identity.
- An additional 300 heterogeneous-study fits—all 100 original fits and the
  first/last bootstrap fit from each—pass the production REML endpoint
  validator. All requested outer samples and bootstrap samples complete;
  none is silently replaced. File completeness and source hashes also pass.

See [fitter equivalence](QER/evidence/mfh2_fitter_equivalence.csv),
[bootstrap equivalence](QER/evidence/mfh2_bootstrap_equivalence.csv),
[endpoint audit](QER/evidence/heterogeneous_endpoint_audit.csv),
[balanced results](QER/evidence/balanced_summary.csv),
[heterogeneous results](QER/evidence/heterogeneous_summary.csv), and
[bootstrap-count sensitivity](QER/evidence/bootstrap_count_sensitivity.csv).

### Why the remaining coverage differences occur

An independent oracle calculation uses **300,000 draws per scenario**, known
parameters, precision-addition posterior formulas and exact analytic
unconditional MSE/MCPE. With large log variation, ordinary normal
absolute-change coverage is 94.319% (MCSE 0.043 points) and delta-method
percentage-change coverage is 96.803% (0.032 points). The fitted-model results
are similar even though their MSE estimates are slightly above empirical
MSE. The interval approximations therefore account for this discrepancy;
arbitrary MSE inflation would not repair both directions. Exact Gaussian
model-scale change intervals achieve approximately 95% in the same oracle.
See [oracle evidence](QER/evidence/oracle_inference.csv).

In the low-signal design, 22.2% of original fits reach a covariance boundary;
28.9% of bootstrap fits do so. Among the **110 original correlation-limit
fits**, absolute-change coverage is **65.21% (MCSE 0.89 points)**. Among the
389 interior fits it is 93.74% (0.43 points). There is only one original
zero-variance fit, insufficient to estimate its separate coverage. These
post-fit conditional rates describe this experiment and are not universal
boundary coverage rates. They nevertheless show why a satisfactory numerical
endpoint is not sufficient evidence for nominal interval coverage. The
known-parameter oracle for this design has 95.04% absolute-change coverage.
At the positive correlation limit, the fitted model assigns almost no
domain-specific random-effect variance to change. The plug-in bootstrap
generates data from that estimated covariance; refitting those draws does
not guarantee adequate allowance for a small but nonzero true change
variance. This explains the poor conditional coverage without treating a
legitimate constrained likelihood maximum as a numerical failure.
See [boundary stratification](QER/evidence/boundary_stratification.csv).

No additional arithmetic defect was identified by these experiments. They
identify limitations of plug-in inference with estimated covariance near a
boundary, and of normal/delta approximations for nonlinear outcomes. Such
limitations are recognized in [Chatterjee, Lahiri and Li (2008)](https://math.umd.edu/~plahiri/pdfs/ChatterjeeLahiriLi2008.pdf).
An exploratory studentized model-scale bootstrap comparison is recorded in
the CSVs, following the construction of
[Saegusa, Sugasawa and Lahiri (2020), section 2.3](https://arxiv.org/html/2006.14820v1).
It is **not a production repair**: the reference requires positive-definite
estimated random-effect covariance, and the diagnostic is unavailable for
most low-signal outer samples because some refits have zero variance.
Results conditional on its availability cannot validate the omitted cases.
It also does not solve general currency differences or final benchmarking.

### Reproduction

From the repository root, with application packages installed, run:

```r
Rscript tests/run_qer_coverage.R --mode=equivalence --library=/path/to/R/library
Rscript tests/run_qer_coverage.R --mode=balanced --outer=500 --bootstrap=1000
Rscript tests/run_qer_coverage.R --mode=heterogeneous --outer=100 --bootstrap=500
Rscript tests/run_qer_oracle_inference.R
Rscript tests/summarize_qer_coverage.R
Rscript tests/test_qer_evidence.R --library=/path/to/R/library
```

These evidence scripts write only the documented `docs/QER/evidence` files
(or the explicit `--output` directory accepted by the main runner). They do
not run the production pipeline or overwrite analysis outputs. No external
packages were installed for this study.

## Validation limits

A fitted-model simulation is separate from oracle checks. Neither software
regression tests nor exact-parameter identities certify nominal coverage of
plug-in bootstrap/normal-approximation intervals. The completed MFH2 study
tests fixed known sampling covariances and five designs. Coverage with actual
complex survey designs, estimated sampling covariances, variable selection,
GVF fitting, final benchmarking and simultaneous/multiple-testing procedures
remains unestablished. Larger MFH1/MFH3 fitted-model studies are also pending.
Polish production inputs were not rerun in this repair session. Runtime
compatibility has been exercised on the versions above; other dependency
versions and operating systems need their normal release checks.

## Operational recommendation

This implementation is suitable for QER methodological review with these
limitations disclosed. Retain MFH2 as default and MFH3 as an optional starting
model. Use at least 500 bootstrap replications, check Monte Carlo stability,
and retain MCPE and covariance-boundary diagnostics. Boundary estimates can
be numerically valid while their normal/delta intervals substantially
understate uncertainty about change. Flag such inference as provisional;
do not present unqualified significance conclusions. Compare Direct results
and alternative admissible models before external conclusions, and report
sensitivity when results are near a decision threshold. Increasing draw
counts is not a remedy for this limitation. Do not describe the process as
uniformly validated or certified, and do not inflate MSEs to fit this study.
