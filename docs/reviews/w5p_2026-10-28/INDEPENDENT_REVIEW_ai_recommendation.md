# Independent review: optional UFH-versus-MFH AI recommendation

Date: October 28, 2026. Candidate: `EU_SAE_520_w5p`, `5.2.0-rc.6-wizard.5.16`, uncommitted. Scope: the owner's subsequent request for an AI-assisted recommendation in the final HTML and editable Word reports. This supplements the preceding repair and `sm_all` reviews; it does not retrospectively change their source snapshots or conclusions.

The reviewer did not implement the production changes. Only this review receipt was edited. No live provider request, model estimation, large simulation, commit, push or publication was performed by this reviewer.

## Code and methodology review

No unresolved material code finding remains identified in the reviewed feature. The review covered `R/comparison_ai_recommendation.R`, its integration into `R/comparison_report_ai.R`, the dedicated `report.Rmd` section, background execution gates and focused tests.

The recommendation uses allowlisted aggregate evidence. Domain/year identifiers are used locally for matching and duplicate checks; the payload excludes domain identifiers, microdata, model objects, formulas, paths and secrets. Level comparisons use the same finite pairs, with coverage/exclusion counts and separate benchmark scopes. Change comparisons disclose matched and unmatched domains and retain unavailable-inference exclusions. CVs are explicitly ratios; level/change units and squared MSE units are identified.

The selected MFH model's status is distinguished from failed nonselected candidates. Unknown status is not a pass. A global covariance-boundary warning cannot overwrite a row's unavailable joint uncertainty. Bootstrap failures, repairs, accepted boundary draws and Monte Carlo precision are execution evidence rather than coverage certification. The prompt discloses the absence of an explicit UFH convergence record rather than treating finite outputs or companion diagnostics as proof of validity.

The prompt permits UFH, MFH, no clear preference or insufficient evidence, with potentially different advice for levels and changes. It rejects lower MSE/CV, narrower intervals, agreement with noisy Direct estimates or additional significant domains as sufficient reasons for selection. It distinguishes UFH's period-independence assumption from MFH's conditional within-window joint uncertainty and explains that frozen estimates from different runs need separate cross-run uncertainty. Incomparable annual/joint likelihood criteria and OLS companion R-squared are not used to rank estimators. The feature does not refit or switch models.

The reviewer identified and checked the following repairs during implementation:

- The existing AI loader had discarded inference status and converted missing significance flags to false. It now preserves qualifications and missingness and excludes invalid inference.
- Duplicate keys, incomplete change matching and zero MSE denominators are handled explicitly rather than multiplying observations or creating apparent precision gains.
- Per-domain unavailable joint moments take precedence over a global boundary status.
- The generator and background driver independently require consent; the driver also requires an AI request and the Comparison step. Disabled providers do not receive requests.
- The legacy overview now describes UFH as pooling across areas within separate annual fits. Benchmarking commentary no longer presumes an increase in uncertainty, and CV ratio/percentage units are distinguished.

Generated text retains provider/model/language/status metadata, warning-only numeric provenance QA, HTML escaping and human-review requirements. Recommendation failure is explicit and does not fabricate a substitute decision. AI-off rendering omits the recommendation even when generated state is available.

## Independent checks and attribution

Using R 4.5.2 with the session library selected through `R_LIBS_USER`, the reviewer independently ran:

```text
Rscript --vanilla tests/test_ai_recommendation.R
```

The final source passed **34/34 checks**, exit status zero. These are mocked, isolated tests of actual workbook loading, matched summaries, status precedence, privacy allowlists, language instructions, consent, unavailable inputs, failure handling, metadata, numeric QA and the actual report chunk. An earlier execution exposed repeated missing-file warnings; explicit existence checks resolved them. The final run reported only four existing Windows C.UTF-8 startup warnings. It did not contact a provider.

Separately, the reviewer recalculated every new level- and change-MSE summary directly from both retained synthetic poverty and log-welfare workbooks. All matched the new evidence loader. Each scenario had 80 matched domain-years, 40 matched change domains and a selected MFH2 fit with regular/passed status. The poverty fixture's nonselected MFH1 failure did not invalidate its selected MFH2 status. Bootstrap counts and fit/completeness fields agreed with their source artifacts. These were read-only checks of saved outputs, not new estimator runs.

The coordinating agent owns the fresh full suite, complete HTML/Word rendering and final package verification. Those executions must not be attributed to this focused independent run. Mock responses verify plumbing and presentation; they do not certify a real provider's statistical reasoning, translation quality or future compliance with the prompt. Substantive human model/publication review and the previously disclosed statistical limitations remain necessary.

## Documentation and artifacts

The updated README, changelog, deviations-note paragraph and feature revision record describe an optional reporting aid rather than a Molina-and-Romero model-selection rule. The two revised guideline paragraphs retain advisory status, incomplete/boundary-sensitive evidence qualifications, failure visibility and AI-off completeness. Final clean guideline pages 89 and 92 were independently inspected and are readable without clipping or overlap.

All six tracked Word copies were independently reconstructed against original w5o and the immediately preceding w5p. Accepting revisions reproduces the exact clean document-body XML; rejecting them reproduces the corresponding baseline body XML, including tables. Equations are unchanged at 168/46/32 across the guidelines and two technical notes. The follow-up has 6/0/0 changed-run pairs; cumulative w5o comparisons have 250/56/5. The active 141-page guideline PDF is byte-identical to its final render, SHA-256 `1d370ee4d6efc0c0f0176c8e073401a9637eb27f82fe96c3c21d4338ec010b56`. All 20 guide/source-kit preservation hashes remain unchanged.

The final rendered recommendation-section follow-up is recorded below. The retained document evidence is in `Claude outputs/w5p_review/followup_ai_recommendation/`.

## Reviewed source snapshot

These SHA-256 values identify local uncommitted content, not a new Git commit.

| Repository path | SHA-256 |
|---|---|
| `R/comparison_ai_recommendation.R` | `7cac541bd68d3e53bc76e3acd4b2704e8928876db37c37a4221cf06dd521e95b` |
| `R/comparison_report_ai.R` | `a1223bafb9402bbb9666f4506b5b0f9e01ae69a582d90ed675e4caff7cc979af` |
| `report.Rmd` | `f9b0aadd323feaa5bbd927e30834f4d212fac7aca6d11f4e09ea1f06b3133363` |
| `scripts/run_pipeline_bg.R` | `10aa2736372a1fb58388a76f9d8547e52a6189592ad662c493e2015a68a743e6` |
| `tests/test_ai_recommendation.R` | `ec6425639425857332a125a451a0bd8f016acade4300a9fa55bd8e7a94d5d528` |

## Final report follow-up

Closed on October 28, 2026, after the final title/status spacing repair and before package construction. No unresolved material finding remains identified within this review's scope.

The reviewer independently inspected page 51 of the final 53-page AI-on Word-to-PDF render. The dedicated heading, advisory qualification, three mock-response paragraphs, separated generated-status label and provider/model/language/numeric-QA/human-review footer are readable without clipping or overlap. The mock response is expressly identified as a software fixture rather than advice for publication.

Independent text assertions against all three final Word documents confirmed that AI-on contains the recommendation and metadata, AI-off omits it despite cached generated state, and provider failure contains an explicit failure reason without fabricated advice. All six HTML/Word file hashes match the coordinating agent's final report-verification receipt. The final PDF hash is `3b4d2da9f007ffd07d176d1519efa6bc684984aac8668ae48b5f9448140d28a2` and its physical page count is 53. All five reviewed source hashes above remained current at closure.

The coordinating agent's receipt separately records zero-exit renders and 186 unchanged numerical-artifact hashes per copied fixture. The reviewer inspected that evidence but did not rerun those renders or independently repeat the entire numerical-artifact manifest comparison. The AI-off render fixture deliberately uses cached generated state to test suppression; absence of provider calls without consent/eligibility is tested separately by the focused suite. No live external request was used for either verification path.

This is a scoped independent code, evidence and artifact review, not statistical certification or a full review of every rendered report page. No verification-build or archive claim is made by this receipt.
