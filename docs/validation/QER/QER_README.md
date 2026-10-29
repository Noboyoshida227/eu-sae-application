# QER review package — w5n

**Default restored to `sm_out`, October 29, 2026.** New or omitted variance settings again resolve to `sm_out`, with matching MFH `rho_sm_out`. Explicit saved choices, including `sm_all`/`rho_sm_all`, are preserved and remain available. Full smoothing predicts variances from sample size alone, so for poverty rates it overstates the variances of low-poverty areas (guidelines Section 6.6). This supersedes the w5p default described in the next paragraph. The historical studies below are unchanged, and this note adds no coverage evidence.

**Subsequent w5p default-policy revision (superseded on October 29).** The owner changed applicable new/missing variance defaults to `sm_all` and matching MFH `rho_sm_all`. This can change fitted estimates and bootstrap uncertainty for newly configured runs; it is not covered by an unchanged-results claim for the earlier explicit `sm_out` integrations. Existing explicit policies are preserved. The historical studies below retain their original inputs/settings and do not establish full-workflow coverage under the new default. T=2 now has an explicit NSO publication-revision rationale; that documentation change does not alter the two-year estimator.

**w5p follow-up, October 28, 2026.** Input-year/key repairs can change estimates for affected external populations/targets; the historical fixed-input simulation designs below do not exercise those defects. Direct-variance relabeling, logged factors, figure captions and removal of an unused bootstrap entry point do not change the maintained model/bootstrap definitions. The new readiness checks reject unsupported or ambiguous runs. See the [w5p receipt](../W5P_VALIDATION_RECEIPT.md) and [deviations note](../../guidance/MOLINA_ROMERO_DEVIATIONS_w5p.md). No historical coverage result is relabeled as fresh w5p validation.

Prepared 10 October 2026. Application: **5.2.0-rc.6-wizard.5.14**;
package name: **EU_SAE_520_w5n**. This is a local candidate for methodological
review. It is circulated as a GitHub pre-release (tag
v5.2.0-rc.6-wizard.5.14) for review by the Polish and Greek teams.

**w5o note (13 October 2026).** w5o (5.2.0-rc.6-wizard.5.15) is built on this
candidate for the review meeting and keeps the methods reviewed here; see
`docs/guidance/METHODOLOGY_ALIGNMENT.md` and `docs/maintenance/CHANGELOG.md` for its changes. The
evidence below refers to w5n.

## What has been revised

A follow-up mapping correction was made after the first w5n archive was sent
for independent review. Reusing one source column for multiple roles now
preserves every role consistently in readiness, UFH and MFH. Missing required
mappings or invalid readiness weights stop estimation clearly. This addresses
the reported case with both strata and household size mapped to `hhsize`;
the user confirmed that strata should instead be `region`. The original
review archive is retained; the follow-up build is identified by its separate
directory and checksum. Its validation is recorded in VALIDATION_RECEIPT.md.

MFH2 remains the default, as requested after the Spanish and Polish MFH3
convergence difficulties. MFH3-first remains an explicit option, using the
documented variance-structure selection and fallback rules.

- UFH now models the logarithm of each area's direct **arithmetic mean**;
  it retains zero and negative household incomes when constructing that mean.
  Corrected log predictions use native EMDI Slud–Maiti correction with ML.
- MFH uses independently checked restricted-likelihood endpoints, refits MFH2
  when necessary, and retains genuine zero-variance optima. Original and
  bootstrap fits use the same acceptance criteria.
- Annual MSE and cross-year MCPE come from coherent joint bootstrap errors.
  Log predictions and benchmarking are evaluated on the reported indicator
  scale, including the full benchmark operation in every draw. Impossible
  covariance produces unavailable inference, without an independence substitute.
- MFH residual diagnostics account for sampling and fitted fixed effects.
  Separate UFH and Direct change inference still assumes period independence.
- **Bootstrap replicates** now controls UFH, MFH and benchmarking, defaulting
  to 500. Explicit saved settings are retained. Monte Carlo precision and
  accepted-bootstrap covariance-boundary diagnostics are exported.
- Covariance-boundary MFH fits retain their estimates and audit p-values but
  receive **boundary_sensitive** inference status. Reports and significance
  figures prominently label their inference provisional.
- The English guidelines, four technical notes, 57-slide guide, download
  instructions, app help and report text have been revised. Earlier numerical
  illustrations in the manuals are labeled as such. The Polish and Greek
  user guides were updated to 5.14 on 11 October 2026.

The supplied references are *Comparable Small Area Estimates over Time*
(Isabel Molina and Eva Romero, 2025 manuscript) and *A Framework for Producing
Small Area Estimates Based on Area-Level Models in R* (the supplied EMDI note).
The [methodology mapping](../../guidance/METHODOLOGY_ALIGNMENT.md) distinguishes the
references' specifications from implementation extensions, including covariance
regularization, log MFH prediction, benchmarking uncertainty, and the disclosed
EMDI arcsine paper-versus-package discrepancy.

## What the evidence establishes

The [validation report](../MCPE_VALIDATION_STATUS.md) records numerical identities,
installed-package agreement, zero-variance/correlation-limit tests, independent
oracle simulations and **2,100 MFH2 outer simulations** with 500–1,000 bootstrap
draws. Independent fitter comparisons and 300 further production endpoint checks
passed. Reproduction scripts and aggregate simulation CSVs accompany this package.

For nominal 95% absolute-change intervals, ordinary designs achieved approximately
94.3–94.9% coverage. The low-signal design achieved **87.4%**; among its 110 fitted
correlation-limit cases, coverage was **65.2%**. These are scenario-specific
findings. They demonstrate that a numerically valid boundary fit is insufficient
to justify unqualified significance conclusions. Increasing the number of draws
alone does not repair this problem. No arbitrary MSE inflation was introduced.

The Spanish integration fixtures use the bundled example, survey years 2012–2013,
fixed covariates `gen` and `educ1`, and seed 62401. They check poverty with UFH
arcsine transformation and unbenchmarked MFH2, and log mean welfare with national
survey-target benchmarking. Mean welfare is in current prices: no illustrative
CPI values are represented as an official Spanish deflator. Reports and test
outputs are kept separately from the clean application archive. These examples
test execution and consistency; they do not establish survey validity or coverage.
Both principal runs completed all 500 requested MFH draws without rejected
refits. The poverty fit is boundary-sensitive (291/500 bootstrap fits also reached
a covariance boundary); the log mean-welfare fit has regular approximate inference.
An MFH3-first example also completed the documented MFH2 fallback. The
[validation receipt](VALIDATION_RECEIPT.md) records the checks, precision results,
report verification and separate benchmark-bootstrap diagnostics.

## Will earlier results change?

Yes, potentially materially. On the saved Spanish poverty fitting frame, with
formulas and sampling covariance held fixed, the checked MFH2 fit improves the
restricted log-likelihood from 170.397 to 172.771. The largest annual estimate
revision is **8.05 percentage points**, and the largest revision to an estimated
year-to-year change is **5.16 percentage points**. Its correlation reaches the
numerical stationary limit, so the new provisional-inference warning is relevant.
See [comparison evidence](evidence/saved_spain/saved_spain_summary.csv) and
[provenance limitation](evidence/saved_spain/saved_spain_provenance.txt).

Log-welfare estimates, MSEs/CVs, confidence intervals, p-values and significance
counts can also change. Bootstrap count changes alone change simulation noise,
not the fitted point estimator. Rerun and review each production setup rather
than replacing previously circulated conclusions using these example differences.

## Decisions and evidence still needed at QER

1. Agree how boundary-sensitive change inference will be used or withheld before
   external conclusions; compare Direct and admissible alternative models.
   Uniform nominal coverage is not established, including for interior fits.
2. Obtain and rerun the Polish data/settings. They were not available in the
   supplied workspace; their results have not been validated in this session.
3. Plan validation with actual complex survey designs, estimated sampling
   covariances, variable/GVF selection, benchmarking and multiple testing.
   Larger fitted-model studies for MFH1 and MFH3 remain outstanding.
4. Complete normal institutional release decisions and actual macOS/Linux smoke
   tests. Local Windows/R checks do not certify those environments. Polish
   and Greek user guides were updated to 5.14 on 11 October 2026.

## Disclosed testing incident

A pre-existing background-driver regression test supplied an incomplete YAML
configuration expecting failure. The validator accepted defaults and started
an analysis in the current workspace, replacing files in `outputs/`. The test
was stopped; its partial outputs were retained privately and the current output
folder was reset to empty placeholders. All `app_runs/` saved histories remain
intact. An exact backup of the former current-output folder was not located;
the before/after Spanish comparison CSVs had already been calculated and saved,
but the original current artifact is no longer available for independent replay.

The defect is repaired: incomplete or missing-input configurations are rejected
before output cleanup. The background regression test now uses an isolated
application copy and verifies preservation of an existing result on failure.
Its 40 checks pass. Later integration runs verify that the current output folder
is unchanged. This incident is recorded separately from the statistical evidence
and is not concealed as a successful preservation check.
