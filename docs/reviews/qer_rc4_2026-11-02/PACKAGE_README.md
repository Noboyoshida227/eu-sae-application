# QER package guide

EU SAE Workbench QER-RC4 | Version `5.2.0-rc.6-wizard.5.20` | Prepared November 2, 2026 | **Pre-release, not for official statistics**

This package supports an expert Quality Enhancement Review of the Workbench's methodology, implementation and usability. Begin here, then read the validation summary and the materials for your review area. The intended outcome is an agreed list of priority improvements, owners and acceptance criteria before broader operational use.

## Background and objective

The Workbench implements UFH and MFH approaches discussed by Molina and Romero (2025), with documented adaptations and extensions. A guided interface enables analysis without writing code. Local execution supports government analysts where confidentiality restrictions prevent World Bank teams from accessing survey microdata, and provides a platform for training officials in small area estimation. Survey design, diagnostics and publication decisions still require statistical judgment. Optional AI assistance is separate and requires institutional consideration of external transfers of unpublished aggregate information.

Reviewers should assess fidelity to the reference, the justification and evidence for changes, correctness of computation, treatment of uncertainty, and usability for government analysts. Reviewers are not being asked to presume that every addition improves statistical performance.

## What to know first

- **Coverage is below target in simulation.** In the known-truth simulation on this candidate, nominal 95% intervals covered 88.3-88.7% for levels and 90.9-91.5% for change. Bias was negligible. Stated uncertainty is too small, mainly because estimated direct variances are noisy and treated as known.
- **The sampling correlation changed in this candidate.** It is now estimated from within-domain residuals. The package includes a revised draft of the sampling-covariance note for expert review, with Section 8 rewritten to match. See decision D1.
- **Coverage for the full workflow is not established.** Model selection and benchmarking were not simulated.

## Package and release status

Application: `EU_SAE_520_w5t`, version `5.2.0-rc.6-wizard.5.20`, commit `b8eaac3`, ZIP SHA-256 `4a680028d2ba53ada01a6c4eb3633719ae8b62530621002a985df1420ae4630e`. This package holds review materials only: no runnable application code and no example data. The application ZIP is distributed separately. In that distribution, open `Start_Here/START_HERE.html`.

The reference is the privately supplied January 29, 2025 manuscript, not a 2015 publication. The manuscript and the authors' code are not included. The additional-code inventory is a functional account of Workbench additions, not a verified file-by-file difference from the authors' code.

Copied documents come from the frozen RC4 archive, so a few statements in them are out of date. The review ledger lists these under "Known document issues". The sampling-covariance note is the exception: the package holds the revised draft, while the application ZIP keeps the earlier version until the note is agreed. See `PACKAGE_PROVENANCE.json` for sources and `PACKAGE_MANIFEST.csv` for file hashes.

## Folder structure

| Location | Contents and use |
|---|---|
| README.html and README.pdf | This guide |
| 01_Email_attachments | Guidelines, deviations note, additional-code inventory, validation summary, decision register, review ledger, quick start, installation instructions and reviewer form |
| 02_User_guides | Guides 1, 2 and 3 in English, Polish and Greek. Native review of the Polish and Greek slide text is pending |
| 03_Technical_references | Revised draft of the sampling-covariance note, as tracked changes and as a clean PDF; MSE note, robust MFH2 note and companion covariance derivations |
| 04_Validation_evidence | Dated validation records, which keep their original scope |
| 05_Editable_sources | Markdown sources. Relative links in them are for provenance |

## Review responsibilities

| Reviewer | Main focus |
|---|---|
| Isabel Molina Peralta | Guidelines: fidelity to Molina and Romero (2025), justification and evidence for adaptations |
| Nikos Tzavidis | Guidelines: methodological choices, assumptions, diagnostics and inference |
| Ifeanyi Nzegwu Edochie | MFH code and general comments on the user interface |
| Sylvia Harmening | UFH code, including transformations and uncertainty; additional MFH comments |
| Ervin Dervisevic | Application code, reliability, maintainability and workflow integration |
| Giulio Barcaroli | Sampling design and estimation of the sampling-error covariance matrix |
| Maarten Lambrechts | Interface design, navigation, clarity of settings and presentation of results |

## Suggested reading routes

All reviewers: this guide, `Validation_summary.pdf`, `Decision_register.pdf` and the short deviations note. Comments outside your primary area are welcome.

- **Isabel and Nikos:** guidelines, deviations note, decision register D1 to D5 and D7 to D10, then the relevant technical notes.
- **Ifeanyi:** additional-code inventory, MFH bootstrap and robust fitting sections, MSE and robust MFH2 notes, and the matching code.
- **Sylvia:** additional-code inventory, guidelines on UFH transformations, benchmarking and uncertainty, MSE note, decision D9 and D11, and the matching code.
- **Ervin:** additional-code inventory, review ledger, installation and user guides, validation evidence, and the frozen source release.
- **Giulio:** revised sampling-error covariance note, including the questions at the end of its Section 8 evidence subsection, decisions D1, D2 and D6, and the variance policy discussion.
- **Maarten:** quick start and Guides 1 to 3, then the public or synthetic example in the application.

## Questions and feedback

1. Does the implementation faithfully represent the intended UFH and MFH models and change uncertainty?
2. Are the MFH2 default, two-year window, variance smoothing and covariance assumptions justified for the intended applications?
3. Is the within-domain sampling correlation sound, and what should replace or extend it for stratified or partly overlapping designs?
4. How should the coverage shortfall be addressed or disclosed, especially for domains with few PSUs and high poverty?
5. Are transformations, benchmarking and conditional bootstrap limitations sufficiently explained and validated?
6. Which numerical or statistical issues require resolution before broader use, especially low-signal and covariance-boundary inference?
7. Can government analysts understand the settings, identify unsuitable results and retain a reproducible record?

Use `Reviewer_feedback_template.docx`, one finding page per issue. Cite the section or the code file and function, describe the consequence, and separate observed defects from requests for evidence and suggested enhancements. Return it to [COORDINATOR EMAIL] by [FEEDBACK DEADLINE]. Do not send confidential microdata; use a public or synthetic reproducer or a permitted aggregate description.

## Proposed meeting

Meeting: [DATE], [TIME AND TIME ZONE], [MEETING LINK]. Suggested 90 minutes: context 10; demonstration 15; adaptations and validation gaps 20; reviewer discussion 30; agreed actions 15. At the meeting, assign each accepted action an owner, deadline and acceptance criterion.
