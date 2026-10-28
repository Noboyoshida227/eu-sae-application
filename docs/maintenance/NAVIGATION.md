# Maintaining the package navigation

The user entry point is `START_HERE.html` at the package root. `docs/INDEX.html` is the complete offline catalogue. Both work without R or internet access. The application serves only the documentation folder and links its **Guides and notes** menu to the same catalogue.

Edit `docs/maintenance/navigation.json` for the starting-guide text, folder descriptions, document titles, languages, audiences and menu choices. This is the shared source for the HTML starting page, catalogue, root README, printable quick start and application menu. Substantive manuals remain their own sources; the catalogue links to them instead of duplicating them.

Run from the repository root with Python, reportlab and the approved Pandoc available:

```text
python tools/build_navigation.py --pandoc <path-to-pandoc>
python tools/check_navigation.py
Rscript tests/test_navigation.R
```

The builder also renders readable HTML copies of Markdown references. Use `--html-only` when only regenerating those pages; the final build still needs the current quick-start PDF. The builder does not install dependencies or contact the internet. Inspect the quick-start PDF and HTML after content changes, and update the explicit release inventory for any added/renamed generated files. Normal package users do not need Python or reportlab.

HTML documentation links stay inside `docs/` so they work both offline and through the application's documentation menu. References to code or example data outside that folder display their package-relative paths; Markdown sources retain their file links. Do not expose the package root as a Shiny resource path, because it can contain private inputs and results.

Instructions are grouped in `English`, `Polish` and `Greek` folders. English guide names have no language suffix; Polish and Greek retain `_PL` and `_GR` so copies remain identifiable outside their folders. Additional reference documents are currently in English. When adding a translation, record its language and formats in the catalogue. Do not label an English document as a translated version.

Keep `Start_Here`, `outputs`, `app_runs`, `Data`, `R`, `scripts` and `www` in their existing relationships. The Word report template is `docs/templates/report_reference.docx`; the report exporter and isolated fixtures use that location. The version-bump tool recognizes the language folders and regenerates navigation after a version change.

The dated `docs/reviews/` records remain repository-only historical evidence. They retain their original source names and hashes and are excluded from the package. A relocation does not retroactively change a historical receipt. Current links and the release inventory point to the new locations.

The QER simulation evidence also retains its original design hashes. Its runner's only change is the default output directory, from `docs/QER/evidence` to `docs/validation/QER/evidence`. The evidence audit accepts the current runner hash or verifies the exact original bytes by reversing that single literal. It does not regenerate simulation evidence or replace historical hashes.
