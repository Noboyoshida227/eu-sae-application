# QER evidence summary

EU SAE Workbench QER-RC4 | Version `5.2.0-rc.6-wizard.5.20` | Pre-release, not for official statistics | Prepared November 2, 2026

The evidence supports specified software behavior, and it describes how the method performs in one synthetic scenario. It does not establish coverage or validity for the complete survey-to-report workflow. In that scenario the point estimates were sound, but stated uncertainty was too small: all four gate coverage results fall below the 93-97% flagging band.

Evidence is grouped by age and scope. Nothing below has been relabeled as fresher or wider than it is.

## Candidate

| Item | Value |
|---|---|
| Release name | `EU_SAE_520_w5t` |
| Commit | `b8eaac342d728aa6612ab53e0fdc66f04c0dfb19`, tag `v5.2.0-rc.6-wizard.5.20` |
| Archive SHA-256 | `4a680028d2ba53ada01a6c4eb3633719ae8b62530621002a985df1420ae4630e`, 33,912,783 bytes |
| Environment | Windows 11, R 4.5.2, dependency lock of 46 entries |
| CI | `quality` passed on `main` at `bd3464c`, which adds one literature page after the frozen commit. CI uses current packages and has no country survey data, so it does not replace the checks below |

## A. Fresh results on QER-RC4, November 1-2, 2026

### Known-truth simulation

Survey rows are simulated, then direct estimates, variances, the sampling correlation, `sm_out` smoothing, REML and the joint bootstrap run through production functions. MFH2, 60 domains of 4 to 18 PSUs, two years, continuous outcome, true rho .6, true q .04, 500 bootstrap draws. The project owner reduced the gate's 2,000 outer samples to 500 per design. The gate's flagging band and aim for precision did not change.

| Measure | Linked | Independent | Gate band |
|---|---|---|---|
| Samples completed | 500 | 500 | 2,000 reduced to 500 |
| Level coverage | 88.3% (SE .14) | 88.7% (SE .13) | 93-97%: flagged |
| Change coverage | 90.9% (SE .16) | 91.5% (SE .17) | 93-97%: flagged |
| Estimated / actual level MSE | .74 | .76 | |
| Estimated / actual change MSE | .81 | .83 | |
| Mean bias | .00064 (SE .00068) | .00054 (SE .00056) | |
| MFH / direct actual change MSE | .66 | .52 | |
| Mean estimated rho (true .6) | .59 | .53 | |
| Mean estimated q (true .04) | .046 | .046 | |
| Boundary fits | 0 | 0 | |
| Failed fits or bootstrap draws | 0 | 0 | |

The flags are not a matter of simulation noise: the closest result is about 9 Monte Carlo SEs below the band. The gate treats a flag as a matter for owner review and disclosure, not as an automatic failure.

Same 500 samples, QER-RC3 against QER-RC4, linked design:

| Measure | RC3 | RC4 | Paired difference (SE) |
|---|---|---|---|
| Sampling correlation (true .467) | .671 | .464 | |
| Level coverage | 87.9% | 88.3% | +.40 (.05) |
| Change coverage | 84.0% | 90.9% | +6.89 (.16) |
| Estimated / actual change MSE | .56 | .81 | |
| Actual change MSE | .01433 | .01313 | |

The independent design does not use the correlation, and its results match RC3 exactly.

### Scenario limits

One synthetic continuous outcome with no strata. Not covered: model selection, benchmarking, transformations, partial PSU overlap and MFH1 or MFH3.

### Software and pipeline checks

| Check | Result |
|---|---|
| Ten release test commands | All exited 0 on the stamped tree |
| 37 pipeline cases | 34 completed. S1, S5a and P5b stop as intended |
| CSV tables against RC3 | 466 of 732 identical. The other 266 differ, and all differences were traced to the correlation or the rounding fix |
| Cases that do not use the correlation | 11 of 11 unchanged |
| Same-seed repeat | Identical |
| Integration | Passed |
| Comparison without both models | Rejected on all three step combinations; existing output preserved |
| Network, AI off and on | No non-loopback connections observed. Sampled every .5 seconds, so very short connections could be missed |
| AI payloads to a local stub | 8 requests; no planted markers or API key |
| Planted markers in outputs and run folders | None, including inside compressed files |

### Effect of the correlation change on case outputs

| Case | Correlation, national | Correlation, RC4 | Median change MSE ratio, RC4 / RC3 | Significance flips |
|---|---|---|---|---|
| Spain, poverty `sm_out` | .561 | .555 | 1.00 | 0 of 52 |
| Spain, anchored `sm_out` | .548 | .542 | 1.00 | 0 of 52 |
| Spain, mean welfare `sm_out` | .677 | .763 | .81 | 1 of 52 |
| R5a synthetic | .748 | .307 | 2.13 | 4 of 40 |
| S2_exact_0_1 | .696 | .233 | 1.83 | 2 of 40 |

The correlation can rise as well as fall. Selected MFH2 fits at the correlation limit rose from 1 to 4 of the cases (S2g 25%, 50% and 75%, and S6b). All four carry the boundary-sensitive label and the report warns, but their intervals and significance labels are still shown. Change MSE falls in those fits, with a median ratio of .44 in S2g 25%.

## B. Exploratory studies on QER-RC3, November 1, 2026

These used 100 paired samples per version, with changes applied only inside test scripts. They explain the gate results but are not gate evidence.

Continuous outcome, restoring true inputs:

| Version | Level coverage | Change coverage |
|---|---|---|
| Linked baseline, national correlation | 87.8% | 84.4% |
| True correlation | 88.1% | 91.2% |
| True correlation and variances | 94.5% | 94.7% |
| Independent baseline | 89.1% | 91.4% |
| Independent, true variances | 94.6% | 93.5% |

With the continuous outcome, the model and bootstrap are calibrated when sampling inputs are right. Direct variances are noisy, and without strata that separate domains they run about (n-1)/n of their true value for n PSUs: .71 at 4 PSUs and .95 at 18. Level coverage was 82.7% with 4-6 PSUs and 93.0% with 14-18 in the RC3 linked baseline.

Binary poverty outcome, linked design, within-domain correlation in a test script:

| Model | Level coverage | Change coverage | Actual level MSE | Actual change MSE |
|---|---|---|---|---|
| MFH2 | 92.8% | 92.5% | .00229 | .00292 |
| UFH, no transformation | 92.7% | 96.5% | .00240 | .00341 |
| UFH, arcsine | 90.1% | 94.0% | .00240 | .00368 |

- True inputs do not restore calibration with this outcome. Coverage in domains at 30% poverty or more stays near 85-88% in MFH2 and UFH alike, and low-poverty domains are over-covered. The likely cause, not tested, is a common random-effect variance on the rate scale.
- UFH change intervals are wider than needed when years are positively correlated, because UFH assumes period independence.
- Arcsine change coverage partly reflects offsetting errors.
- `sm_all` raised average coverage but moved variances further from the truth at every poverty level.

The within-domain correlation estimator tracked the truth with and without household overlap and PSU persistence: .546 against .552, .443 against .446, .094 against .106 and -.010 against 0.

## C. Carried forward from QER-RC1 to RC3, October 30, 2026

| Evidence | Result | Status on RC4 |
|---|---|---|
| Direct estimates and variances against hand Taylor linearization | 4.3e-15 at most, tolerance 1e-8 | Not repeated |
| Benchmark constraints, national and grouped | 4.4e-16 at most, tolerance 1e-8 | Not repeated |
| UFH against `sae::eblupFH` | 4.13e-4, tolerance 1e-5: **miss**. A direct likelihood solve matches `sae`, so the gap comes from the `emdi` optimizer | Open, see the decision register |
| Row-level data in saved objects | Found on RC1, fixed on RC2 | Marker search repeated on RC4 |
| Spain_2y shipped examples against saved outputs | Identical on RC1 and RC2 | Changed on RC4 by the correlation change |

## D. Historical evidence

These dated studies keep their original scope. See `MCPE_VALIDATION_STATUS.md`, `Historical_QER_VALIDATION_RECEIPT.md` and `W5P_VALIDATION_RECEIPT.md` in `04_Validation_evidence`.

- The 2,100-outer-simulation MFH2 study used fixed covariates and known sampling covariances. Nominal 95% absolute-change coverage was about 94.3-94.9% in ordinary scenarios, 87.4% in a low-signal scenario and 65.2% among correlation-limit fits. Its known-input design is why it looks better than section A.
- The October 28 and 29 receipts describe earlier code, and they are not results for RC4.

## E. Not done

| Item | Status |
|---|---|
| Full workflow simulation with model selection and benchmarking | Not run. Scope awaits an owner decision |
| Partly overlapping design simulation | Not run |
| §8 final AI review on the frozen candidate | Not run |
| E1 clean machine, E2 offline, E3 wizard against dashboard | Not run |
| E4 macOS and Linux | Not tested |
| UI-driven checks | Not run. Readiness and wizard rules are covered by tests of their logic |
| S7 failed-refit path, S8 invalid joint moments, P-6 legacy mapping | Unit tests only |
| Formal Monte Carlo assessment of the different-seed run | Output exists; not assessed |
| Molina-Romero authors' code comparison | Code not available in the repository |
| Native review of Polish and Greek slide text | Pending |

## Prior AI-assisted review

AI-assisted reviews examined code, documents and consistency, and they informed revisions. They prepare for expert review and do not certify the method. They cannot be certified as comprehensive. The review ledger gives the scope.
