# Corrections to the w5o review and scope of the w5p repair

October 28, 2026. This addendum corrects the review of `EU_SAE_520_w5o`, version `5.2.0-rc.6-wizard.5.15`, commit `e5319826a1a8bc306c842b6a8745173045caf028`. It incorporates the independent evaluation supplied by the owner and checks against the implementation. Original w5o findings remain historical; the [ledger](CORRECTION_LEDGER.md) records repairs and new evidence.

1. The year-relabeling defect is confined to R matrices loaded from RDS/RData. Ordinary CSV/Excel table readers matched year names already. The new parser now validates labels and required keys consistently.
2. Duplicate keys affect population and benchmark-target tables. Population breakdowns by sex/age are a realistic trigger. The repair rejects duplicate required keys, including equal-valued rows, rather than choosing or summing them.
3. The Direct-MSE mislabeling affects identity UFH values replaced by sm_all, sm_out or safety backfills. The 0.001 cutoff is an SE of 3.1623 percentage points on a proportion scale. Its frequency is dataset-dependent. The fresh illustrative counts below do not justify an “almost every domain” claim across applications.
4. The incorrect benchmark factor is a P3 printed UFH step-log diagnostic; final point estimates, bootstrap moments, exported estimate tables and final report were not computed from that diagnostic. The repair uses the operation's actual target/factor. Degenerate zero/zero handling differs: UFH outputs zero and records an undefined ratio; MFH uses factor 1, within each helper's numerical tolerance.
5. Manuscript p37 accepts individual-area comparison, explains Bonferroni for a family of tests, then cautions against many-area testing because power is poor. Bonferroni outputs already exist. The departure is prominent pointwise counts across areas, now labeled exploratory.
6. The variance-contrast multiplicity discussion is on manuscript p23, not p22. This is distinct from area-change multiplicity.
7. Only guidelines §8.7's unconditional positive-PSU-covariance explanation required that correction. Annex G.8 already states a model condition; it has been preserved.
8. The manuscript permits LASSO and Annex H already says “LASSO screening.” No missing phrase or intrinsic LASSO violation is claimed.
9. BH-only passages were also present in §8.12 and its interpretation heading, Annex H's change-significance row, and §H.4 and its heading. All now describe pointwise, BH and Bonferroni.
10. Private extraction paragraph IDs have been removed from amended review prose. Use the section, baseline page and identifying phrase below; the regenerated document's contents and headings locate current pages.
11. The private manuscript's personal filesystem location was redacted from guidance_review.md. Private references and review archives do not ship in the release.

## Stable baseline document locators

| Document/section | Baseline page where applicable | Identifying phrase and correction |
|---|---|---|
| Guidelines §7.12 | 52 | “factor is set to 1”; reject nonfinite/impossible targets and explain explicit degenerate cases. Qualify the nonnegative-rate claim. |
| Guidelines §8.7 | 59 | “become positively correlated”; distinguish persistent positive cluster effects from a universal design claim. |
| Guidelines §8.12 | 64–65 | “Pointwise and Benjamini-Hochberg”; include Bonferroni and the distinct inferential questions. |
| Guidelines Annex G.8 | 130 | “Under a cluster random-effects model”; preserve the existing model qualification. |
| Guidelines Annex H, change-significance row | 134 | “both pointwise and Benjamini-Hochberg”; include Bonferroni and the p37 caution. |
| Guidelines §H.4 | 136 | “Pointwise and BH reporting”; revise heading, field names and interpretation. |
| Sampling-covariance note §8 | Section locator | “far above the smoothed value” and “weights = ~weight”; correct sm_out and population-weight definitions. |
| Sampling-covariance note, relation to Boonstra and van den Brakel | Section locator | “intra-PSU correlation is large”; make the application assumption conditional and distinguish PSU adaptation. |
| Sampling-covariance note §12 | Section locator | “population_weight = weight × household size”; distinguish household and person rows. |
| MSE note Part I | Section locator | “keeps benchmarked rates non-negative”; a positive ratio preserves only already nonnegative predictions and does not impose an upper bound. |

## Illustrative variance-policy audit

The portable [audit script](checks/measure_sm_out_examples.R) executes the actual Direct-estimation and variance-policy source path on the shipped examples without model fitting or bootstrap draws. [Counts](evidence/sm_out/sm_out_counts.csv) and [configuration/input/source hashes](evidence/sm_out/sm_out_provenance.json) record every path, year, indicator and denominator. UFH and MFH counts agree in these configurations.

| Example/year | Domains | FGT0 replacements | FGT1 replacements | FGT2 replacements |
|---|---:|---:|---:|---:|
| Spain 2012 | 52 | 8 (15.4%) | 28 (53.8%) | 41 (78.8%) |
| Spain 2013 | 52 | 8 (15.4%) | 26 (50.0%) | 40 (76.9%) |
| Simulated 2022 | 40 | 7 (17.5%) | 37 (92.5%) | 39 (97.5%) |
| Simulated 2023 | 40 | 11 (27.5%) | 36 (90.0%) | 40 (100.0%) |

All replacements in these runs were finite variances strictly below 0.001 on the identity proportion scale; no nonfinite replacement requests or failed GVF replacements occurred. Household rows use survey weight times household size, the supplied poverty-line columns, and the recorded PSU/strata configuration. These are illustrative examples, not general survey-population frequency estimates or coverage evidence.
