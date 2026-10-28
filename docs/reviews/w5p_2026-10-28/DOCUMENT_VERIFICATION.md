# w5p document verification

**Subsequent owner revision:** this record covers the initial w5p repairs. The later T=2 publication-policy explanation and `sm_all` default are recorded in [SM_ALL_REVISION.md](SM_ALL_REVISION.md), with fresh tests and a separate verification build. Earlier counts and artifact hashes below retain their original scope.

Date: October 28, 2026. Candidate: `5.2.0-rc.6-wizard.5.16` / `EU_SAE_520_w5p`. Baseline copies and hashes were retained before edits.

## Word guidance

The clean guidelines, sampling-error covariance note and levels/changes MSE note were edited in place. All four technical notes were inspected; the two unaffected notes retain their valid theoretical statements. The 36 entries in `tools/w5p_guidance_changes.json` record exact old/new text and stable section locators. Existing equations, drawings, relationships and styles were preserved. The files contain 168, 46 and 32 OMML equations respectively, unchanged from baseline.

LibreOffice/Poppler rendered the revised documents into PDFs and page images: 140 pages for the guidelines, 11 for the covariance note and 8 for the MSE note. Complete page sets were inspected in contact sheets, with full-page checks of changed methodological passages and independent spot checks. This is not a claim that every page was proofread at full resolution. The blank numbered guidelines page 11 already existed in the baseline; a spill of new release text onto it was removed. The existing contents were reconciled with PDF bookmarks; the final check required zero further page-number changes. Every new correction phrase was found in rendered PDF text. No clipping or overlap was found in the inspected changes.

`tools/make_w5p_redlines.py` produced three real tracked-change DOCX copies with neutral revision metadata. Automated acceptance reproduces each clean document body; rejection reproduces its baseline body, including tables and equations. There are 151, 32 and 5 changed run pairs respectively. The local `redlines/redline_verification.json` records baseline/clean/tracked hashes. These tracked copies are for owner review; the clean documents and corresponding PDFs are the release inputs.

The exact final Word/PDF/source hashes and text checks are retained in the local `Claude outputs/w5p_review/` evidence folder. Historical review page locators remain explicitly identified as baseline locators. Generated PDFs are derived views; editable DOCX remains authoritative.

## Short guides and integration reports

All nine English/Polish/Greek PPTX/PDF pairs retain their slide counts (10, 19 and 21 per language) and approved presentation design. Before editing, all 50 English slides and notes rebuilt identically from the preserved source kit, preventing regression to older text. The revised kit is portable and retains original screenshot/example provenance. Two translation checks covered 619 units without structural errors. Independent review covered all 23 changed translation units; its Polish and Greek wording improvements were applied. All 54 visible changed passages were found in PDF text. Contact sheets and content-heavy slides were inspected for clipping/overlap.

The local `guides_revision_receipt.md`, translation-change register, deliverable manifest and source-kit ZIP retain reproduction details. Country-team editorial certification was not performed. Changed Polish/Greek terminology and explanatory sentences remain suitable for an optional country-team style review; no material translation defect remains identified.

The two bounded candidate integrations generated HTML and editable Word reports and rendered 50/48-page PDF previews. Contact sheets and full-page executive/significance sections were checked, including the final exploratory-pointwise caption. The [integration receipt](INTEGRATION_RECEIPT.md) distinguishes these execution checks from statistical coverage evidence.

## Limits and owner decisions

A product-wide naming pass was not undertaken: current user interfaces use EU SAE Workbench, while some historical/theoretical document titles still use Package/Application terminology. Figure 6 in the guidelines remains the existing historical example rather than a new w5p result. The app's CPI option still says “Read them from the CPI file (Data step)”. These three optional changes were explicitly outside the approved correction scope. No mathematical equation or existing numerical example was replaced to make the application appear more closely aligned with the manuscript.
