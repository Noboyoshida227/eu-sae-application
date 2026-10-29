# Input data

These examples are for learning and testing, not for producing real estimates.

| Folder | Purpose and limitations |
|---|---|
| [Spain_2y](Spain_2y/README.md) | Bundled synthetic 2012–2013 teaching example, verified through UFH → MFH2 → Comparison for original-line poverty, anchored poverty and CPI-adjusted mean welfare. Includes restored `povline_anchored`, a teaching CPI and six explicit run configurations. [Start here](Spain_2y/START_HERE.md) for tested settings and [verification](Spain_2y/verification/ANCHOR_AND_WELFARE.md) for results and limitations. Deliberately altered samples/incomes; not official statistics or a reproduction of historical guidance results. Survey/auxiliary data retain GPL-2; geometry and the teaching CPI retain their documented CC BY 4.0 terms. |
| [simulated](simulated/README.md) | Fully synthetic survey, auxiliary covariates, and abstract geometry. The included seeded Python generator reproduces these files; see its README for mapping instructions. |

The original `Data/Spain/` is retained in the maintainer's repository working copy for provenance and historical reproduction. It is **excluded from the w5p release package**. Its historical README is preserved at [Spain_2y/provenance/original_README.md](Spain_2y/provenance/original_README.md); references there describe the original layout, not the current release contents.

For your own analysis, create a clearly named folder such as `Data/Romania_2025/`
and group your approved survey, auxiliary, and geometry inputs there. Browse
can also select files elsewhere on your computer. Generated results belong in
`outputs/`, not in your input folder. User-created Data folders are excluded
from the release builder's explicit file inventory.

## Existing setups

Package-relative references beginning with `data/` or `example_data/` are
resolved to the corresponding file under `Data/Spain/` or `Data/simulated/`
only when that file exists. A message records this path migration. Because the
original Spain folder is excluded from this release, an old `data/` or
`Data/Spain/` reference must be reselected explicitly; it is never redirected
silently to the different Spain_2y data. Bare saved filenames resolve only if
unambiguous in Data, Spain, Spain_2y or simulated.
Absolute paths and missing user inputs are never replaced with example data.
If an old absolute path or temporary upload is unavailable, Browse to the
intended file and save the setup again. Saved copies under
`app_runs/_last_setup_files/` retain their existing behavior.

Standalone UFH/MFH/Comparison scripts with no input path configured use the
Spain_2y example files. An explicitly configured missing path causes an error.
For the tested workflow, load one of the explicit configurations in
`Data/Spain_2y/` rather than relying on unspecified model settings.
