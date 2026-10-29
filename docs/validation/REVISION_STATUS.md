# Revision status against the merged issue register

Baseline: EU SAE application package v5.1.0. Current local review candidate: 5.2.0-rc.6-wizard.5.16 (w5p), revising w5o (5.15) and the QER candidate w5n (5.14).

w5p repairs matrix-year/key validation, pre-cleanup readiness, raw Direct uncertainty, logged benchmark factors and standalone MFH figure qualifications. It retires the dormant bootstrap implementation and synchronizes methodology guidance. See [the deviations note](../guidance/MOLINA_ROMERO_DEVIATIONS_w5p.md) and [fresh validation receipt](W5P_VALIDATION_RECEIPT.md). The historical issue register and coverage limitations below remain in force.

The older issue register is retained below. The current technical disposition and evidence are in [QER review note](QER/QER_README.md) and [methodology alignment](../guidance/METHODOLOGY_ALIGNMENT.md); open institutional approvals are not software defects that a local revision can close.

Since October 29, 2026, new or omitted variance settings resolve to `sm_out`, with matching MFH `rho_sm_out`. This reverses the w5p follow-up that had made `sm_all`/`rho_sm_all` the defaults: full smoothing predicts variances from sample size alone, so for poverty rates it overstates the variances of low-poverty areas. Explicit saved policies, including `sm_all`, are preserved, and arcsine UFH keeps its distinct variance treatment. The `sm_out` validation limitation under B3 remains. T=2 is a deliberate publication-policy choice: successive windows and freezing each year after its second appearance limit routine revisions; the app does not manage the NSO's publication register.

`Implemented` means the candidate contains a code or documentation change for
the finding; it is not a production-method approval. `Partial` identifies work
done but an unresolved decision or validation. `Open` means no substantive
closure is claimed.

| ID | Status | Disposition in 5.2.0-rc.6 |
|---|---|---|
| B1 | Implemented | LASSO folds use and record a deterministic analysis seed. |
| B2 | Implemented | Removed the unreachable covariance branch; UFH change inference labels period independence and exports raw and BH-adjusted p-values. |
| B3 | Partial | The default policy, sm_out, uses the absolute 0.001 cutoff (log-scale variance for log means). It is disclosed as an implementation choice, not prescribed by Molina–Romero or EMDI; representative policy validation remains open. |
| B4 | Implemented | AI prompts are evidence-conditional and no longer assert fixed conclusions or eight combinations. |
| B5 | Partial | Added explicit external-transfer consent, prompt minimization, a prompt-injection guard and configurable gateway URLs. Lawful basis, provider/retention terms and institutional approval remain open. |
| B6 | Partial—blocks production/official release | Non-inventory literature files are excluded. The candidate includes only listed Spain RDS and simulated examples; the replacement Spain map has documented IGN/CNIG CC BY 4.0 provenance; the survey derivation remains missing. The canonical repository was restarted with a fresh history on 17 Sep 2026 and the previous one deleted on 27 Sep 2026 (`docs/maintenance/HISTORY_REMEDIATION.md`); older repositories still need review, and non-code rights remain unapproved. |
| B7 | Implemented | Added targeted tests and CI; this is code QA, not statistical validation. |
| B8 | Implemented | Removed hard-coded Greece labels and added a country/territory input. |
| H1 | Implemented | Input-load failure is blocking. |
| H2 | Implemented with limits | Shared Bootstrap replicates defaults to 500 for UFH, MFH and benchmarking; explicit saved counts are preserved, counts/precision exported. The larger MFH2 study compares 500/1,000 draws; it does not certify all settings. |
| H3 | Implemented | MFH annual and change MSE/MCPE use the same joint bootstrap. Impossible covariance or unavailable moments produce unavailable inference, never an independence substitute. Boundary-sensitive intervals remain provisional. |
| H4 | Partial | UFH/MFH results include BH adjustment and explicit variance handling; the multiplicity family and covariance policy need approval. |
| H5 | Implemented with limits | UFH models log arithmetic Direct means with native emdi ML/bc_sm; MFH uses conditional-lognormal prediction. Original-scale bootstrap, package agreement and oracle tests added; finite-sample coverage limits disclosed. |
| H6 | Implemented with limits | Independent REML endpoint/curvature checks and bounded MFH2 refit retain legitimate zero-variance boundaries. Original/replicate covariance boundaries are diagnosed; boundary-sensitive inference is explicitly provisional. |
| H7 | Partial | Native emdi corrected-log predictions remain unavailable for unsampled areas; benchmarking requires complete predictions. No invented correction is substituted. Wider nonsampled-domain validation remains open. |
| H8 | Partial | Joint original-scale bootstrap identities and installed-model behavior pass. Larger MFH2 studies identify undercoverage at covariance boundaries and normal/delta approximation limits. Uniform inference validity is not claimed. |
| H9 | Implemented | Run metadata and input hashes are captured before one final report render. MFH inversion, robust-refit, condition-number-method, and g3/MSE availability diagnostics are added after the MFH step and explicitly printed in the report. |
| H10 | Implemented | UFH complete-case filtering uses required estimation fields and logs excluded domain IDs. |
| H11 | Partial | Diagnostics are more visible, but no institutionally approved warning/action policy or thresholds exist. |
| H12 | Implemented | Delimited inputs are read as UTF-8 when valid and as Latin-1 otherwise, without re-encoding, so no rows are lost; `SAE_INPUT_ENCODING` overrides. |
| H13 | Partial | Quality indicators are exported, but publication thresholds and actions remain unapproved. |
| H14 | Implemented | Duplicate rendering was removed; the final report follows completed run metadata. |
| H15 | Implemented | Missing normality p-values are reported as unavailable rather than failed. |
| H16 | Partial | A direct dependency snapshot/check exists; reproducible cross-platform restoration remains open. |
| H17 | Implemented | Added clean-release tooling, manifests/checksums and complete output placeholders. |
| H18 | Implemented with limits | Guarded inversions, constrained marginal-variance REML refits, zero-G and correlation-limit fixtures, non-inferior likelihood checks and standardized residual diagnostics pass. Selected uncertainty uses joint bootstrap; a valid optimization endpoint alone does not guarantee nominal interval coverage. |
| H19 | Open | Remote branches/tags and publication workflow require repository-owner action. |
| H20 | Implemented | Added VERSION/changelog and replaced country-specific labels. |
| H21 | Implemented | English guidelines, four technical notes, 57-slide guide, download PDF and help/report prose revised for w5n. In w5o the guidelines note, download PDF and READMEs follow the EU SAE Workbench interface, and three short guides, in English, Polish and Greek, replace the 57-slide guide and its Polish and Greek versions. Historical figures are labeled illustrative. |
| H22 | Partial | The canonical repository (eu-sae-application) was started with a fresh history that contains none of the prohibited binaries; the previous repository was deleted on 27 Sep 2026. Older repositories that predate the fresh start still need review (`docs/maintenance/HISTORY_REMEDIATION.md`). |
| M1 | Partial | Numerical/package/oracle checks and 2,100 MFH2 outer simulations completed. Complex-survey, selection, benchmarking and large MFH1/MFH3 coverage studies remain open. |
| M2 | Implemented | User-authorized MFH2 default retained; users can explicitly choose MFH3-first, with documented selection/fallback rules. |
| M3 | Implemented | Clean exports omit run histories and input-file copies. |
| M4 | Implemented | Convenience copies of browsed input files are made only when a configuration is saved (**Save configuration**, and the configuration each model run records) and are excluded from clean exports. |
| M5 | Partial | Added R-object/type, duplicate-column and ZIP-isolation checks; a full adversarial input review remains open. |
| M6 | Open | No substantive closure is claimed; requires owner decision and validation. |
| M7 | Open | No substantive closure is claimed; requires owner decision and validation. |
| M8 | Open | No substantive closure is claimed; requires owner decision and validation. |
| M9 | Implemented | Approved API gateways can be configured without code changes; provider approval remains under B5. |
| M10 | Open | No substantive closure is claimed; requires owner decision and validation. |
| M11 | Open | No substantive closure is claimed; requires owner decision and validation. |
| M12 | Open | Full UI translation/localization coverage has not been completed. |
| M13 | Implemented | README and the explicit release inventory describe required inputs and include the listed Spain and simulated examples for learning and testing only. |
| M14 | Open | No substantive closure is claimed; requires method-owner validation. |
| M15 | Open | No substantive closure is claimed; requires method-owner validation. |
| M16 | Open | No substantive closure is claimed; requires method-owner validation. |
| M17 | Partial—blocks production/official release | Added scoped LICENSE, NOTICE, third-party inventory and governance file. Institutional copyright/release authority, asset ownership and disclaimer approval remain unresolved. |
| M18 | Implemented | Robust MFH2 refit now applies one shared complete-case mask. |
| L1 | Implemented | Bootstrap time-loop construction now handles `nT = 1`; convergence checks use `isTRUE`. |
| L2 | Open | Canonical remote tag/case cleanup remains repository-owner work. |
| L3 | Open | No substantive closure is claimed. |
| L4 | Implemented | Root junk is excluded from the clean build and covered by ignore/release rules. |
| L5 | Open | No substantive closure is claimed. |
| L6 | Partial | Metadata for the revised guidance and technical notes was refreshed. Ownership fields in unchanged documents and institutional metadata policy still require rights-holder decisions. |
| L7 | Open | Full accessibility remediation remains incomplete. |
| L8 | Open | Remaining statistical/documentation convention requires owner decision. |

## Public sharing

The maintainer publishes the package as a release candidate on the GitHub
Releases page, https://github.com/Noboyoshida227/eu-sae-application/releases, for
review and testing. M17 (document, asset and institutional release authority)
remains open. Passing tests and checksums does not by itself validate
estimators, privacy basis or data rights. Whether to publish estimates as
official statistics is for each national statistical office to decide.
