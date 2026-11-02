---
title: "How the EU SAE Workbench was tested against a known truth"
subtitle: "A plain guide to the simulation exercise and its results"
---

EU SAE Workbench QER-RC4, version 5.2.0-rc.6-wizard.5.20. Pre-release, not for official statistics. Prepared November 2, 2026.

# Summary

With real survey data we never know the true poverty rate of a domain, so we cannot check directly whether an estimate or its confidence interval is right. A known-truth simulation gets around this: we create an artificial population whose true values we set ourselves, draw artificial surveys from it, run the Workbench, and compare its results with the truth.

The main findings are:

- **Point estimates are sound.** Average error is close to zero, and the MFH model is more accurate than direct survey estimates.
- **Stated uncertainty is too small.** Intervals labeled 95% contained the truth about 88% of the time for levels and about 91% for change between years.
- **One cause was found and fixed.** The sampling correlation between years was overstated. Correcting it raised change coverage from 84.0% to 90.9% in the linked design.
- **Other causes remain.** Noisy direct variances are the main remaining cause for levels. In high-poverty domains, intervals stayed too narrow even when the correct sampling inputs were supplied.

These results come from synthetic scenarios. They show how the method behaves under known conditions, not how it will perform on a particular real survey. Model selection and benchmarking were not part of the exercise, so coverage for the complete workflow is not established.

# Why use a known truth?

A confidence interval makes a promise: about 95 of every 100 intervals should contain the true value. Software tests can show that a calculation runs and matches a formula, but they cannot show whether this promise holds. To check it, we need many repetitions in which the true value is known.

The rules for judging the results were set before testing began. Coverage outside 93-97% is flagged for review. A flag does not mean automatic failure, and the band was not adjusted to fit the results.

# How one run works

Each sample follows the same steps:

1. **Set the truth.** Create true values for 60 domains in 2 years. A **data-generating process (DGP)** is the set of rules used to create them.
2. **Draw a survey.** Simulate household rows within primary sampling units (PSUs), as a real survey would produce.
3. **Run the production code.** Compute direct estimates, variances and the sampling correlation, apply `sm_out` smoothing, fit MFH2 by REML, and run 500 joint bootstrap draws.
4. **Compare.** Check each estimate and interval against the truth set in step 1.
5. **Repeat.** Draw new truth and a new survey, and repeat with a new seed.

The final results average over all samples. Each sample gives 120 level intervals (60 domains in 2 years) and 60 change intervals. So 500 samples give 60,000 level and 30,000 change intervals per design.

# What the data-generating processes look like

All DGPs share one structure: 60 domains, 2 years and 8 households per PSU. Domains have 4, 6, 8, 10, 14 or 18 PSUs, in repeating order, so reliable and unreliable domains are both present. There is one covariate $x_d$, evenly spaced from -1 to 1. There are no survey strata. In DGPs 1 and 2, PSU weights take the values 1, 1.5 and 2.

## DGP 1: continuous outcome

This is used for the main run. The true value of domain $d$ in year $t$ is

$$\theta_{dt} = \beta_{0t} + \beta_{1t}\, x_d + u_{dt},$$

with $(\beta_{01},\beta_{11}) = (1.00,\ 0.50)$ and $(\beta_{02},\beta_{12}) = (1.05,\ 0.55)$. The domain effects $u_{dt}$ have variance $q = 0.04$ and correlation $\rho = 0.6$ between years. MFH2 is designed for this structure.

Household $h$ in PSU $j$ then has the value

$$y_{hjdt} = \theta_{dt} + a_{jt} + e_{hjt},$$

where $a_{jt}$ is a PSU effect with standard deviation 0.3 and $e_{hjt}$ is household noise with standard deviation 0.6.

Two survey designs are simulated:

- **Linked:** the same PSUs are used in both years, and each PSU effect persists with correlation 0.7. Households are new each year. This gives a true sampling correlation of 0.467, which is $0.7 \times 0.09 \,/\, (0.09 + 0.36/8)$.
- **Independent:** PSUs are drawn afresh each year, so the true sampling correlation is 0.

## DGP 2: poverty outcome

This is used for the exploratory poverty test. A household is poor if a hidden score is above zero:

$$\text{poor}_{hjdt} = 1 \ \text{ if } \ \eta_{dt} + a_{jt} + e_{hjt} > 0.$$

The score is $\eta_{dt} = \beta_{0t} + \beta_{1t}\, x_d + u_{dt}$, with $(\beta_{01},\beta_{11}) = (-0.90,\ 0.70)$ and $(\beta_{02},\beta_{12}) = (-0.85,\ 0.75)$. The domain effects have variance 0.09 and correlation 0.6. The PSU effect has standard deviation 0.3, and the household noise has variance 0.91. The true poverty rate is $\Phi(\eta_{dt})$, the normal probability of $\eta_{dt}$. The true sampling correlation is about 0.195 in the linked design.

This outcome is harder because a yes-or-no variable has a variance that depends on the rate, and the spread of true rates grows with the rate.

## DGP 3: household overlap and PSU persistence

This separate check tests only the sampling correlation, with no model fit. A continuous outcome is simulated in four cases, with PSU persistence switched on or off, and household overlap (75% of households retained) switched on or off. It shows whether the estimator keeps both sources of dependence.

# What we measure

| Measure | Question it answers | What is good |
|---|---|---|
| Bias | Are estimates right on average? | Close to 0 |
| Actual MSE | How large is the real average squared error? | Smaller is better |
| Estimated / actual MSE | Does the app state its uncertainty honestly? | Close to 1 |
| Coverage | How often does a 95% interval contain the truth? | 93-97% |
| Monte Carlo SE | How much do results vary because the number of samples is finite? | Small |

An interval is the estimate plus or minus 1.96 times the square root of the estimated MSE. For change between years, the estimated MSE is

$$\text{MSE}(\text{change}) = \text{MSE}_1 + \text{MSE}_2 - 2\,\text{MCPE}.$$

An MSE ratio below 1 means that the app understates its uncertainty.

# Results

## Main run on QER-RC4

This uses DGP 1, with 500 samples per design and 500 bootstrap draws per sample. All 1,000 samples completed, with no failed fits or draws.

| Measure | Linked | Independent | Target |
|---|---|---|---|
| Level coverage | 88.3% (SE .14) | 88.7% (SE .13) | 93-97%: flagged |
| Change coverage | 90.9% (SE .16) | 91.5% (SE .17) | 93-97%: flagged |
| Estimated / actual level MSE | .74 | .76 | Near 1 |
| Estimated / actual change MSE | .81 | .83 | Near 1 |
| Mean bias | .00064 (SE .00068) | .00054 (SE .00056) | Near 0 |
| MFH / direct actual change MSE | .66 | .52 | Below 1 |
| Mean estimated rho (true .6) | .59 | .53 | Near .6 |
| Mean estimated q (true .04) | .046 | .046 | Near .04 |

**How to read this.** Bias is within one Monte Carlo SE, and MFH reduces the actual error of change by 34-48% compared with direct estimates. But about 12 in 100 level intervals and 9 in 100 change intervals miss the truth, not the promised 5. The closest result is about 9 Monte Carlo SEs below the band, so a larger simulation would not change this conclusion.

## What the correlation change achieved

Earlier versions took the correlation between years from the national estimator. Without strata that separate domains, this counts lasting differences between domains as sampling correlation. QER-RC4 removes domain-year means first. The table compares the two on the same 500 linked samples.

| Measure | QER-RC3 | QER-RC4 | Paired difference (SE) |
|---|---|---|---|
| Sampling correlation (true .467) | .671 | .464 | |
| Level coverage | 87.9% | 88.3% | +.40 (.05) |
| Change coverage | 84.0% | 90.9% | +6.89 (.16) |
| Estimated / actual change MSE | .56 | .81 | |
| Actual change MSE | .01433 | .01313 | |

Independent-design results did not change, as expected, because that design does not use the correlation.

## Why coverage is still below target

To find the causes, a diagnostic run on QER-RC3 replaced estimated inputs with their true values, using 100 paired samples of DGP 1. This is exploratory and not part of the main run.

| Version | Level coverage | Change coverage |
|---|---|---|
| Linked, national correlation | 87.8% | 84.4% |
| Linked, true correlation | 88.1% | 91.2% |
| Linked, true correlation and variances | 94.5% | 94.7% |
| Independent, estimated variances | 89.1% | 91.4% |
| Independent, true variances | 94.6% | 93.5% |

With the correct inputs, coverage reaches the target. So for this outcome, the model and bootstrap are working, and the shortfall comes from treating estimated direct variances as if they were known. Domains with few PSUs suffer most: on QER-RC3, linked level coverage was 82.7% with 4-6 PSUs and 93.0% with 14-18 PSUs. Without strata that separate domains, direct variances also run low, at about .71 of the true value with 4 PSUs and .95 with 18.

## Poverty outcome

This uses DGP 2, with 100 paired samples on QER-RC3 and the changes applied only in test scripts. It is exploratory.

| Version, linked design | Level coverage | Change coverage |
|---|---|---|
| `sm_out`, national correlation | 92.7% | 89.9% |
| `sm_out`, within-domain correlation | 92.8% | 92.5% |
| `sm_all`, national correlation | 93.9% | 89.5% |
| True variances and correlation | 93.3% | 91.3% |

Average coverage hides a pattern across poverty levels:

| Version | Under 15% poverty | 15-30% | 30% or more |
|---|---|---|---|
| `sm_out`, national correlation | 97.8% | 92.7% | 85.1% |
| `sm_all`, national correlation | 98.4% | 94.7% | 86.5% |
| True variances and correlation | 95.4% | 95.2% | 87.8% |

Low-poverty domains are over-covered and high-poverty domains are under-covered. Unlike DGP 1, supplying true inputs does not fix this. The likely cause, not yet tested, is that the model assumes one random-effect variance on the rate scale. `sm_all` raised average coverage, but it moved variances further from the truth at every poverty level, so it is not recommended as a remedy.

## MFH2 against UFH on the poverty outcome

Same 100 linked samples, with UFH fitted to each year separately.

| Model | Level coverage | Change coverage | Actual level MSE | Actual change MSE |
|---|---|---|---|---|
| MFH2, within-domain correlation | 92.8% | 92.5% | .00229 | .00292 |
| UFH, no transformation | 92.7% | 96.5% | .00240 | .00341 |
| UFH, arcsine | 90.1% | 94.0% | .00240 | .00368 |

MFH2 is more accurate, by about 5% for levels and 14-21% for change in the linked design. UFH change intervals are too wide because UFH assumes that years are independent. High-poverty under-coverage appears in all three models.

## Does the correlation keep both sources of dependence?

This uses DGP 3, with 60 samples per case.

| PSU persistence | Household overlap | True correlation | National | Within-domain |
|---|---|---|---|---|
| Yes | Yes | .552 | .696 | .546 |
| Yes | No | .446 | .644 | .443 |
| No | Yes | .106 | .471 | .094 |
| No | No | 0 | .419 | -.010 |

The within-domain estimate follows the truth in all four cases. The national estimate stays near .42 even when nothing carries across years.

# What this exercise does not show

- **It is not the real world.** These are synthetic scenarios, and the size of each effect in a real survey is unknown.
- **The model is favorable.** The fitted model uses the correct covariate. Real analyses must choose covariates, which adds uncertainty.
- **The full workflow is untested.** Model selection, benchmarking and transformations were not included in the main run.
- **Some designs are untested.** There are no strata in these DGPs, so strata that cross domains were not studied. Partly overlapping designs, MFH1 and MFH3 were not studied either.
- **Exploratory results are smaller.** Tests with 100 samples have coverage SEs of about .2 to .9 points, and they ran on QER-RC3 with changes applied in test scripts.

# What this means in practice

- MFH estimates can be used with more confidence than their intervals.
- Treat stated precision as optimistic, especially for domains with few PSUs or high poverty.
- Treat a "significant" change as weaker evidence than its label suggests in those domains.
- Check boundary-sensitive results with particular care.

# Glossary

| Term | Meaning |
|---|---|
| Bootstrap | Re-creating many data sets from the fitted model to estimate uncertainty |
| Coverage | Share of intervals that contain the true value |
| DGP | Data-generating process: the rules used to create the artificial truth and data |
| Direct estimate | An estimate computed from survey data alone, without a model |
| Domain | A small area or group, such as a region, for which estimates are made |
| Linked design | The same PSUs are used in both years |
| MCPE | Mean cross-product of prediction errors between the two years |
| MFH2 / UFH | Multivariate model across years / univariate model for one year |
| Monte Carlo SE | Uncertainty in a simulation result due to the finite number of samples |
| MSE | Mean squared error: the average squared difference from the truth |
| PSU | Primary sampling unit: the cluster first selected in a survey |
| REML | Restricted maximum likelihood, the method used to fit the model |
| `sm_out` / `sm_all` | Replace only missing or very small variances / replace all variances with smoothed values |
