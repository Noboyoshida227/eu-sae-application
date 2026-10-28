# w5p optional AI model-recommendation revision

Date: October 28, 2026. Candidate: `EU_SAE_520_w5p` / `5.2.0-rc.6-wizard.5.16`. This follow-up adds the owner's requested advice on choosing UFH or MFH when AI report writing is selected. The earlier T=2 publication-policy clarification and applicable `sm_all` / `rho_sm_all` defaults remain in place.

## Behavior and evidence

The final HTML and editable Word reports include a dedicated **AI Recommendation: UFH or MFH** section when AI writing is selected. The section is advisory and can recommend either method, no clear preference, or insufficient usable evidence. It distinguishes annual levels from changes within a common fitted window and data vintage. It does not select or refit an estimator, change settings, or modify numerical results.

The recommendation receives aggregate, matched comparisons from the actual saved run. Domain/year keys are used locally to match records and check duplicates; domain identifiers are excluded from its payload. Finite pair counts and exclusions accompany year-specific MSE/RMSE/CV summaries, with benchmarked and unbenchmarked results kept separate. Change-MSE and interval-width summaries include matching/completeness counts and inference qualifications. Selected-model convergence, boundary status, bootstrap failure/repair/boundary counts and Monte Carlo precision, and allowlisted fit and normality diagnostics provide context. Unknown and unusable information remains explicit. Ratios and reporting-scale units are identified.

The prompt does not permit lower estimated MSE, narrower intervals, closer agreement with noisy Direct estimates, or more significant domains alone to establish a preferred model. It describes UFH's period-independence assumption for reported change uncertainty and MFH's conditional use of cross-period prediction-error covariance. Boundary-sensitive inference remains provisional; additional draws do not cure undercoverage. A candidate's failure does not validate the other by elimination. Differences between frozen estimates from separate fits cannot inherit a within-fit joint change MSE.

The existing consent, provider/model, language, generation/status and human-review records apply to the new section. Provider errors produce a labelled failure rather than fabricated advice. AI-off reports omit the recommendation, even if cached generated state exists. Direct generator and background-driver consent checks are covered. Numeric QA remains a warning-only provenance check, not validation of AI conclusions.

## Documentation and methodological status

The wizard README, changelog, deviations note and guidelines §§11.7/11.9 explain the feature. It is an optional reporting aid, not a model-selection rule prescribed by Molina and Romero (2025). The clean guidelines were rendered and checked; actual tracked copies are retained against both w5o and the immediately preceding w5p candidate. No equation, technical-note text or translated guide needed an AI-feature revision. Earlier mathematical and publication-policy qualifications remain in force.

The [validation receipt](../../W5P_VALIDATION_RECEIPT.md) records the final tests and report checks. The [independent review](INDEPENDENT_REVIEW_ai_recommendation.md) records recalculation against both saved poverty and log-welfare fixtures and closes scoped code/document findings. Machine-readable test, source, report, Office and preservation receipts are retained in the local `followup_ai_recommendation` review folder, outside the portable package.

## Scope of assurance

Mock providers exercise software behavior without an external transfer or API charge. They cannot certify a real provider's statistical reasoning, language quality or future responses. Analysts must review and retain their substantive model/publication decision. No new estimator simulation or coverage study is claimed; the earlier numerical integration evidence retains its original scope. This follow-up creates a private verification build from the uncommitted working tree. It does not commit, push, tag or publish.
