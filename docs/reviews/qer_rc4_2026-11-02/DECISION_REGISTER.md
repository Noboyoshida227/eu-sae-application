# Methodological decision register

EU SAE Workbench QER-RC4 | Version `5.2.0-rc.6-wizard.5.20` | Pre-release, not for official statistics | Prepared November 2, 2026

This register lists the method choices where reviewers' judgment matters most. The reference is the privately supplied Molina and Romero manuscript dated January 29, 2025. The full list of choices and their classifications is in `Deviations_from_Molina_Romero.pdf`. Evidence is in `Validation_summary.pdf`.

**Status** says who has decided what. "Owner decided" means the project owner chose it. "Open" means no decision has been made. No entry here is a claim that the choice is correct.

## Summary

| # | Decision | Status | Main expert |
|---|---|---|---|
| D1 | Sampling correlation from within-domain residuals | Owner decided November 1, 2026; departs from Section 8 of the owner's note | Barcaroli |
| D2 | Direct variances treated as known | Standing; shortfall measured | Barcaroli, Tzavidis |
| D3 | Selective smoothing, `sm_out`, by default | Owner decided October 29, 2026 | Molina, Tzavidis |
| D4 | Common random-effect variance on the rate scale | Open | Molina, Tzavidis |
| D5 | How flagged coverage is presented | Open | All methodological reviewers |
| D6 | Declared cross-year PSU design | Owner decided October 30, 2026; partial overlap open | Barcaroli |
| D7 | MFH2 default and two-year window | Owner decided | Molina |
| D8 | Joint bootstrap conditional on selected model and inputs | Standing | Tzavidis, Edochie |
| D9 | UFH and Direct change assume period independence | Standing | Harmening |
| D10 | Change inference near the covariance boundary | Open | Molina, Tzavidis |
| D11 | Accepting the `emdi` optimizer difference | Open | Harmening |
| D12 | Validation scope: platforms and full workflow | Open | Dervisevic |

## D1. Sampling correlation from within-domain residuals

- **Molina and Romero:** treat estimated domain sampling covariance matrices as known inputs (p20).
- **Owner's note, Section 8:** multiply the correlation of the national direct estimator by the domain standard errors.
- **Implementation in QER-RC4:** subtract each domain-year weighted mean, then run the same PSU-level national survey calculation on the residuals. The result, the pooled correlation, is multiplied by each domain's two standard errors. RC3 and earlier used Section 8 as written.
- **Relationship to the literature:** this adapts the pooled residual approach of Boonstra and van den Brakel (2019), sections 3.2 and 3.3. Their domain-specific overlap factor is deliberately left out, because an overlap-only correlation misses PSU persistence. The owner's sampling experts confirmed that the PSU-level survey calculation captures both household overlap and PSU persistence.
- **Why it changed:** without strata that separate domains, the national correlation counts lasting differences between domains as sampling correlation. In simulation it gave .67 against a true .47 for the continuous outcome, .49 against .20 for poverty, and about .42 when nothing at all carried across years.
- **Evidence:** the correlation now averages .464 against .467. Linked change coverage rose from 84.0% to 90.9%, and actual change MSE fell 8%.
- **Sensitivity on cases:** Spain poverty .561 to .555, no flips. Spain mean welfare .677 to .763, change MSE ratio .81, 1 flip of 52. R5a .748 to .307, change MSE ratio 2.13, 4 flips of 40.
- **Limits:** tested in a scenario with no strata. Surveys whose strata cross domains were not simulated. A single pooled correlation assumes domains are alike. Correlation-limit fits rose from 1 to 4 of the cases.
- **Note status:** the note in `03_Technical_references` still describes the national correlation. It needs revising with the sampling experts.

**Questions for experts:** Is the residual correlation the right quantity for stratified designs? Where domains are similar to strata, does it remain close to the true correlation? Should a domain-varying correlation be considered?

## D2. Direct variances treated as known

- **Molina and Romero:** treat sampling variances as known, and discuss smoothing for unstable values (pp10-12).
- **Implementation:** PSU-level design variances, with `sm_out` replacing missing or very small values.
- **Evidence:** with true variances, continuous-outcome coverage rises to about 94.5%. Without strata that separate domains, the design variance runs about (n-1)/n of its true value: .71 at 4 PSUs. Level coverage was 82.7% with 4-6 PSUs and 93.0% with 14-18, on RC3.
- **Limits:** this is the main reason for the level coverage shortfall, and RC4 does not change it. An n/(n-1) correction was not tested. The size of the effect in real surveys depends on how strata relate to domains.

**Questions for experts:** Should the Workbench apply a correction, warn for domains with few PSUs, or propagate variance uncertainty?

## D3. Selective smoothing by default

- **Molina and Romero:** illustrate full smoothing and do not prescribe the .001 cutoff.
- **Implementation:** `sm_out` keeps finite variances of at least .001 and replaces the rest. `sm_all` remains an option.
- **Why:** the sample-size GVF gives areas of similar size similar variances whatever their poverty rate.
- **Sensitivity, simulated poverty outcome, linked:**

| Version | Level coverage | Change coverage | Variance used / true: under 15% poverty | 30% or more |
|---|---|---|---|---|
| `sm_out` | 92.7% | 89.9% | 1.61 | .85 |
| `sm_all` | 93.9% | 89.5% | 1.82 | .56 |

  The same comparison on the continuous outcome favored `sm_all` (92.8% level against 87.8%), but there the true variance depends only on sample size, which is exactly what the GVF assumes.
- **Limits:** one synthetic scenario. The cutoff is scale-dependent.

**Question for experts:** Is a poverty-aware GVF worth developing, given that average coverage hides opposite errors at low and high poverty?

## D4. Common random-effect variance on the rate scale

- **Molina and Romero:** the MFH model has random effects with a shared covariance structure.
- **Implementation:** same, on the rate scale for poverty.
- **Evidence:** in the simulated poverty outcome, coverage in domains at 30% poverty or more stayed near 85-88% even with true sampling inputs, with MSE understated by about 40%. UFH showed the same pattern and arcsine did not resolve it.
- **Limits:** the likely cause was not tested. The probit design used contributes to the pattern, so its size in real data is unknown.

**Questions for experts:** Is a transformed MFH needed? Should high-poverty domains carry a warning in the meantime?

## D5. How flagged coverage is presented

The gate proposes disclosure to QER, not a pass. All four RC4 coverage results fall below 93-97%. Final reports warn about boundary-sensitive change results, but they do not state the coverage shortfall measured here.

**Question for experts:** What wording or restriction should reports carry until D2 and D4 are resolved?

## D6. Declared cross-year PSU design

- **Implementation:** MFH runs only after the analyst declares linked or independent PSUs, because software cannot infer the design from identifiers. A not-specified design blocks MFH.
- **Limits:** partly overlapping designs have no supported route and were not simulated. They stay blocked unless the analyst declares one of the two designs.

**Question for experts:** What should be done for partial overlap, or for overlap without linkable PSUs?

## D7. MFH2 default and two-year window

- **Molina and Romero:** the p21 sequence starts with MFH3, and the framework allows many periods.
- **Implementation:** MFH2 by default with optional MFH3-first; exactly two years, to support one scheduled revision per estimate.
- **Evidence:** recorded MFH3 convergence difficulties; the two-year window is a publication-policy choice, not an optimality claim.
- **Comparison:** in the simulated poverty outcome, MFH2 had about 5% lower level MSE and 14-26% lower change MSE than UFH. MFH1 and MFH3 coverage was not studied.

## D8. Joint bootstrap conditional on selected model and inputs

- **Molina and Romero:** p36 identifies bootstrap development as needed.
- **Implementation:** MSE and MCPE come from one joint parametric bootstrap, holding formulas, model type, auxiliary data, smoothed variances and sampling covariances fixed.
- **Limits:** uncertainty from selection and from estimated inputs is omitted. The RC4 results show that the omitted input uncertainty matters.

**Question for experts:** Should sampling inputs be re-estimated inside the bootstrap, or should the MSE be adjusted?

## D9. UFH and Direct change assume period independence

- **Implementation:** change MSE is the sum of the two yearly MSEs.
- **Evidence:** with positive correlation between years, simulated UFH change coverage was 96.5% and its MSE ratio 1.27. The tests are conservative, not more accurate.

**Question for experts:** Should UFH change results use the estimated sampling correlation as a sensitivity check?

## D10. Change inference near the covariance boundary

- **Evidence:** historical coverage among correlation-limit fits was 65.2%. On RC4, 4 cases end at the limit, and change MSE falls there (median ratio .44 in S2g 25%).
- **Implementation:** these results are labeled boundary-sensitive, and intervals and significance labels are still shown.

**Question for experts:** Should significance labels be withheld for boundary-sensitive fits?

## D11. `emdi` optimizer difference

UFH estimates differ from `sae::eblupFH` by up to 4.13e-4 against a tolerance of 1e-5, on one synthetic dataset. A direct likelihood solve matches `sae`. The gate tolerance was not changed. Recommendation to the owner: accept and disclose. No decision yet.

## D12. Validation scope

macOS and Linux are untested. Recommendation to the owner: disclose as untested. The scope of a full-workflow simulation is undecided. Coverage for the complete workflow remains unestablished.
