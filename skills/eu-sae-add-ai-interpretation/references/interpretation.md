# Statistical interpretation and placement

These instructions take precedence over wording in old AI text or templates.

## Evidence rules

- Describe lower estimated MSE/RMSE/CV as conditional estimated precision, not
  demonstrated accuracy, unbiasedness or coverage. Absolute deviation from noisy
  Direct estimates is descriptive agreement, not error against truth.
- Compare matched domains, years, units, transformations, benchmark scopes and
  finite observations. Give eligible and excluded counts. Unpaired marginal means
  may describe each series but cannot establish a matched precision advantage.
- CV is a ratio; multiply by 100 only when expressing it as percent. Ratios require
  positive denominators; zero or negative MSE is not evidence of infinite gain.
  Report medians and tails if means are skewed. A large mean/median gap alone does
  not prove near-zero denominators caused it; check the relevant observations.
- Benchmarking is determined from Run Setup or explicit metadata, not whether
  benchmarked and raw estimates differ. Equal results can occur with benchmarking
  enabled. Missing benchmark columns are unavailable, never identical or zero.
  Distinguish shifts of estimates from changes in separately estimated uncertainty.
  A common positive multiplicative factor can preserve rankings; verify it across
  eligible domains before stating that. Do not infer satisfaction of constraints.
- Determine poverty indicator and units from report labels, not the filename.
  For proportion-scale FGT headcount/gap/severity, changes multiplied by 100 are
  percentage points; change MSE multiplies by 10,000. Mean-welfare changes may be
  percentage change, log change, or an absolute currency difference: inspect the
  actual exported table, period and configuration. Never mix log-scale change RMSE
  with percentage-change intervals. Currency and constant/current prices are
  separate facts; unknown currency must remain unknown.
- Count missing significance flags as untested, not false. Compare agreement only
  where both flags are present. Keep pointwise, BH and Bonferroni counts separate,
  with separate tested denominators. Pointwise counts are exploratory; BH concerns
  false discovery rate, Bonferroni family-wise error. Significance refers to changes,
  not the poverty or welfare level. More significant areas is not a selection rule.
- Treat failed/invalid joint moments as unusable inference even when numeric cells
  exist. Do not rehabilitate them with a regular global model label. Boundary-sensitive
  MFH intervals and p-values are provisional; narrower intervals do not establish
  reliable superiority. More bootstrap draws alone do not cure boundary problems.
  Missing convergence status is unknown. A variance rounded to zero is a possible
  boundary, not confirmed without diagnostic evidence. Bootstrap refits on boundaries
  warrant attention without automatically relabeling the selected fit.
- Distinguish sampling-error covariance, random-effect covariance and prediction-error
  covariance. MFH1 has independent random effects across years, MFH2 common variance
  with correlation, MFH3 year-specific variances with correlation (confirm the selected
  model's description). Record MFH3-to-MFH2 fallback only if documented.
- For new reports, independent-survey PSU choice sets sampling-error covariance to
  zero; it does not eliminate MFH random-effect or prediction-error covariance.
  Legacy unchecked PSU consistency is unspecified, not evidence of independence.
  UFH change variance assumes independent periods; overlap can violate it. Do not
  use MFH-implied prediction-error covariance as proof of the actual UFH error
  covariance or the direction of UFH miscalibration. MFH joint-fit change MSE does
  not automatically apply to frozen annual estimates from different fits/vintages.
- Normality: use supplied W/p for Shapiro-Wilk, not a Q-Q correlation threshold.
  Q-Q correlation, skewness and kurtosis require recorded diagnostics. Heuristic
  0.98/0.95 Q-Q thresholds are descriptive, not universal validity tests. Repeated
  diagnostics do not prove perfectly correlated random effects. MFH residual
  dependence limits naive normality-test interpretation. Describe plot shape only
  after viewing the plot; distinguish shape from scale.
- Bootstrap sample size and Monte Carlo error are numerical stability diagnostics,
  not coverage certification. Few successful draws or high reported Monte Carlo
  error warrant stability checks, particularly for borderline significance. Do not
  turn the Claude template's 200-draw/10% heuristics into universal acceptance rules.
- Do not compare AIC/BIC across different likelihoods/transformations or annual and
  joint fits. OLS companion R-squared is not SAE validation. Intercept-only UFH
  shrinks toward a common mean, not a covariate-specific predictor.
- If report tables conflict, identify the discrepancy for human review; do not
  silently select the more favorable value. Negative headcounts or values above one
  are invalid on the proportion scale. Poverty-gap/severity bounds depend on the
  indicator definition and welfare treatment. State suspicious outputs accurately.

## Eight blocks

Use concise plain paragraphs, without duplicated titles or lists inside blocks.
Lengths should follow the evidence, not a fixed word quota. Avoid domain names in
the advisory prose by default; use aggregate counts and ranks. Describe geographic
patterns only if the actual map has been inspected. Do not invent patterns from
ranked values alone.

| JSON key | Content | Position in rc.6 report |
|---|---|---|
| overview | Selected models, annual mean levels, benchmark setting, descriptive agreement, principal limitations | Start of Comparison of UFH and MFH, after AI banner |
| normality | Recorded diagnostics and inspected Q-Q/density shapes by method/year/component; missing evidence | End of Normality Diagnostics |
| rates | Matched absolute deviations from Direct; benchmark shifts and units | End of Rate, MSE, RMSE, and CV Comparisons |
| precision | MSE/RMSE/CV, paired coverage, median and tail behavior, benchmark scope and numerical stability | Immediately after rates |
| poverty_maps | Level magnitudes and verified map patterns, distinguishing the actual poverty indicator or mean welfare | End of Poverty Maps or Mean Welfare Maps, before RMSE Maps |
| change_significance | Pointwise/BH/Bonferroni counts, tested denominators, paired interval widths and status agreement | End of Distribution of 95% confidence-interval widths, after workbook links and before Change maps note |
| change_maps | Change ranges, direction, inspected patterns and supported benchmark comparisons; provisional status if applicable | End of comparison section after significance maps |
| recommendation | Conditional assessment for annual levels, then two-year changes, then diagnostic limitations and human checks | Own top-level section before Session Information |

Choose UFH, MFH, no clear preference, or insufficient usable evidence. Preferences
may differ for levels and changes. A preference requires more than lower estimated
MSE, closeness to Direct, narrower intervals or significance counts. State the
publication objective is unknown unless supplied. Clearly label advice as added
after the run and subject to human statistical review.

For boundary-sensitive or failed inference, include the limitation in overview,
change significance, change maps and recommendation. For unavailable plots or
diagnostics, state the limitation in the relevant block rather than describing
unseen graphics. Use informative precision and scientific notation for tiny nonzero
values; do not round tiny benchmark shifts to a claim of no effect.
