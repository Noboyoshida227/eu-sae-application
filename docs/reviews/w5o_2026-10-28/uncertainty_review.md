# w5o uncertainty, benchmark and change review

> Amended October 28, 2026 following independent evaluation. This remains a review of the original w5o commit, not a statement of the repaired w5p state. Read the [correction addendum](../w5p_2026-10-28/REVIEW_CORRECTIONS.md) and [implementation ledger](../w5p_2026-10-28/CORRECTION_LEDGER.md) for corrected scope, source locators and repair evidence.

Reviewed current root sources at release commit e5319826a1; no production code changed. Bounded reproduction: `probe_benchmark_inputs.R` in this directory, run with R 4.5.2. No full simulation rerun was needed for these findings.


Amended input scope: the named-year bug affects R matrices in RDS/RData, while table readers already match years by name. Both target and population long/wide readers lack unique-key checks at the w5o baseline. Sex/age population rows must be aggregated to the required grain before upload; w5p rejects duplicates even when values agree.

## Confirmed production defects

### P2 — Honor year names when reading external target matrices

- Locations: `scripts/01_ufh.R:678–683`; `scripts/02_mfh.R:2234–2237`.
- Both loaders reorder rows by group, but leave matrix columns in their supplied order and overwrite their names with `years_keep`.
- Reproduction: a supported RDS matrix with named columns `2013=.30, 2012=.20`, requested analysis years `2012,2013`, becomes `2012=.30, 2013=.20` in both UFH and MFH. No warning is issued.
- Impact: all final estimates are benchmarked to the wrong years' targets; reported changes and uncertainty can be materially wrong. Both pipelines agreeing does not validate the target assignment.
- Fix: validate unique/nonmissing column names and subset by `as.character(years_keep)` before conversion. If unnamed matrices remain supported, explicitly document positional semantics; never silently override contradictory names. Add a reversed-column regression case.
- Related population-matrix defect is covered by the estimation reviewer.

### P2 — Reject conflicting duplicate external target keys

- Locations: long input `scripts/01_ufh.R:713–716`, `scripts/02_mfh.R:2269–2272`; wide input `scripts/01_ufh.R:730–731`, `scripts/02_mfh.R:2291–2292`.
- The loaders use `match()` without first verifying uniqueness of group/year keys (or group keys for wide tables).
- Reproduction: rows `(all,2012,.20)`, `(all,2012,.90)`, `(all,2013,.30)` are accepted. Reversing the first two rows changes the 2012 target from .20 to .90.
- Impact: benchmarked levels, changes and inference depend on file row order instead of a uniquely defined external target. This is separate from w5o's survey domain-to-group conflict check.
- Fix: reject duplicate keys before matching, with group/year and conflicting values in the message. For this repair, reject all duplicate required keys, including equal-valued duplicates; do not aggregate or deduplicate silently. Validate duplicate matrix row names too.

## Secondary output consistency issue

### P2/P3 — Standalone MFH-stage significance plots omit provisional boundary labels

- Example location: `scripts/02_mfh.R:3265–3271`; parallel paths around 3176–3180 and 3314–3320, and their histogram outputs.
- `mfh_change_unbench_points.png`, `mfh_change_bench_points.png`, previews and histograms use unconditional 'Significant' labels and nominal 95% captions even when `.inference_status == "boundary_sensitive"`.
- The stage log warns earlier, and the final report plus Comparison plots do correctly qualify these results. The omission concerns standalone stage PNGs shared without their log/report.
- Fix: propagate `.inference_warning` into plot subtitle/caption and provisional significance labels. This is a communication inconsistency, not a moment-arithmetic defect.

## Documentation claim checked against executable code

The MSE technical note's claim that ratio benchmarking keeps rates nonnegative is false for an identity-scale Gaussian fit with negative estimates. The production UFH helper maps estimates `(-.1,.3)` and direct values `(.1,.3)` with equal populations to `(-.2,.6)`. MFH applies the same unconstrained ratio logic. Ratio benchmarking itself is correctly computed; revise the guarantee to require nonnegative component estimates and a nonnegative factor, and also disclose that an upper bound of one is not guaranteed. Guidance reviewer owns the document location.

## Alignment with Molina and Romero (29 January 2025 manuscript)

- **MCPE bootstrap is an explicit extension, with sound core arithmetic.** Page 36 gives `MSE(change)=MSE1+MSE2−2MCPE` and says MCPE bootstrap methodology/software needs development. Current `sae_mfh_bootstrap()` computes annual squared errors and cross products from identical accepted draws, refits the selected model, and performs inverse transformations and benchmarking within draws. This directly supports the change-MSE identity. Error second moments are correctly uncentered, and invalid joint moments are not silently replaced with independence.
- **Normal intervals are permitted approximations, not coverage guarantees.** Page 36 explicitly presents the normal-quantile interval as approximate and mentions bootstrap intervals as an alternative. Existing QER evidence shows undercoverage in low-signal/boundary designs, which is a substantive documented limitation, not by itself a new arithmetic defect. The 87.4% low-signal and 65.2% correlation-limit results cannot be repaired merely by increasing bootstrap draws.
- **Multiplicity language should be stronger.** Page 37 says all-D-area hypothesis testing should use Bonferroni alpha/D and cautions against many-area testing. Pointwise-primary flags with BH/Bonferroni supplemental exports are a documented departure, defensible for clearly exploratory/per-area interpretation but not for familywise-confirmatory claims. The alignment note's phrase 'warns about multiple comparisons' understates the paper's specific recommendation.
- **Benchmarking and nonlinear log-MFH prediction are extensions.** The paper does not prescribe the package's ratio benchmarking or conditional-lognormal currency predictor. They are mathematically coherent under the stated conditional model, but the current evidence does not establish coverage with final benchmarking, estimated sampling covariance/GVF, variable selection or complex survey designs.
- **Bootstrap remains conditional on the selected structure.** It holds covariates, formulas, populations and fitted sampling-covariance inputs fixed and refits the chosen MFH type. It does not repeat the MFH3-to-MFH2 model-selection rule on every draw. Document this model-selection-conditioning limitation alongside the already disclosed formula/GVF-selection conditioning.
- **Rejected draws require continued scrutiny.** The shared engine reports successful draws, failures and accepted covariance boundaries and withholds uncertainty if it cannot reach the requested accepted count. This is sound execution accounting, but resampling until success does not prove the omitted-fit cases are innocuous. Larger MFH1/MFH3 studies remain a validation need.

## Latent helper cleanup, lower priority

`scripts/mcpe_functions.R::pbmcpeMFH2()` is still shipped and sourced but has no current production callsite. It retains the obsolete formula rebuild, which turns an intercept-only formula into invalid `Y1 ~ ` and loses no-intercept semantics, and repairs sampling covariance for simulation without updating refit inputs. Production uses `pbmcpe_with_existing()` and the shared corrected engine. Remove/deprecate this legacy function or delegate it to the shared implementation; do not conflate this dormant path with current pipeline uncertainty.

## Overall scope conclusion

No additional main-path arithmetic defect was identified in the joint MFH bootstrap, reported-scale benchmark error products, change-MSE identity, or percentage-change delta calculations. Confirmed external-target input defects and the standalone-plot qualification gap remain. This bounded code review does not certify absence of all defects or nominal frequentist coverage.
