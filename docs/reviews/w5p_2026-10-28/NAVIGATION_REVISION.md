# Navigation and language-folder revision — October 28, 2026

The owner requested a simple starting guide, clear document and result locations, and separate English, Polish and Greek instruction folders. This follow-up implements those changes on the uncommitted w5p candidate. It does not introduce a statistical-method change.

## Structure and reproducibility

The root START_HERE.html, docs/INDEX.html, short README and two-page quick-start PDF use docs/maintenance/navigation.json. The same catalogue drives the application menu. The 71 recorded file relocations preserve language suffixes and separate guidance, validation, maintenance and templates. Dated docs/reviews records remain repository-only historical evidence and are excluded from the portable package.

The report exporter and isolated fixtures use docs/templates/report_reference.docx. The build inventory, release checks, version-bump tooling, QER destinations, Markdown links and Office path references were updated. HTML links stay within the served documentation folder; code and example-data references outside it display their package-relative paths. User result/input directories are not exposed through a new static route.

Detailed evidence is in `Claude outputs/w5p_review/followup_navigation/`: baseline_manifest.json, path_migration.json, office_navigation_changes.json, final_test_source_manifest.json, final_test_summary.json, supplemental_test_summary.json, document_render_results.json and sourcekit_manifest.json. The initial provenance-audit failure and first-pass tests are preserved under first_pass/. Historical receipts retain their original names and hashes.

## Verification

The final full suite has 522 PASS, zero FAIL and zero SKIP. Dependency lock 46/46, background 40, UI parity and the 300-endpoint evidence audit pass. The final test-source manifest hash is `f309ffe46022f10a2c6b23d52b05c51a1202fbbc33fba438b27e71ce71960a52`. The copied report fixture rendered HTML and Word with the relocated template and preserved all 51 numerical CSV/RDS/Excel files. No provider calls or estimator refits were performed for that smoke check.

The download-PDF generator was corrected after the regression snapshot: its inherited text incorrectly described sm_out as mandatory under log UFH. It now describes the current defaults, log selector, saved-policy/legacy-setup behavior, arcsine treatment, AI advice and one-revision NSO policy. It was rebuilt and inspected separately. This documentation repair does not change estimation behavior.

Five DOCX files have path-only edits with all native equations and layout properties preserved. The guidelines remain 141 pages with unchanged TOC references. Existing guidance PDFs were regenerated; other pages in those PDFs match the prior render. Nine guide PDFs remain byte-identical. Six PPTX files change only speaker-note paths; all nine rebuilt decks match the package's slide, note, media, layout and theme parts. The new source kit is EU_SAE_Workbench_guides_build_kit_w5p_navigation.zip; its SHA-256 is `8f45fe9ac299d50d927abadd5469e3c46e149af6023c020d4d63e7c9d81f6081`. The earlier kit is preserved.

HTML validation is static: targets, anchors, package inclusion, no remote assets, and docs-mount compatibility. The in-app browser's security policy rejected file URLs, so no live browser preview is claimed. PDF visual inspection covers the quick start, download instructions, changed guidance pages and overview sheets for the two technical notes without prior PDFs.

The fresh private ZIP and separate TEST_BUILD receipt are under dist/w5p_verification_build_navigation. The build verifier binds the final source inventory and ZIP hashes, checks archive/extraction contents and launcher permissions, and checks existing outputs and old archives against their saved hashes. There is no commit, push, tag or publication. These checks do not alter the previously documented statistical limitations or certify nominal interval coverage.

## Final archive and concurrent run activity

The verification ZIP contains 222 inventory files plus its manifest. Its SHA-256 is `1ae4b627adcdbcf00878072ba513f5493599e18755a6a4e9f238fe095db7516a`. The independent archive verifier passed size/hash, extraction, launcher permission and all 277 local-link checks.

Two separate Spain application runs completed during this task: 20261028_160415_Spain_4 and 20261028_162403_Spain_4. Their logs record refresh of working outputs and successful archiving. They remain in place. All 3,924 files in earlier dated run archives retain their hashes. Compared with the earlier 4,177-file runtime baseline, there are 499 new files, 113 changed working-output/setup files and no missing files. These are recorded in runtime_delta.json; no claim of unchanged working outputs is made. All navigation tests and report smoke checks used isolated copies.
