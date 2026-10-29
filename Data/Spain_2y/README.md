# Example data: Spain, two-year teaching variant (2012–2013)

This folder holds a **calibrated teaching version** of the Spain example, for
showing UFH and MFH side by side. With the original example (`Data/Spain/`), the
MFH2 fit for 2012–2013 sits on a covariance boundary. With this variant, both
methods complete for 2012 and 2013, with interior variance estimates.

It was made by deliberately altering the original samples and incomes. Results
from it **do not reproduce the guidance notes** and do not describe Spanish
provinces. To reproduce published results, use `Data/Spain/`.

| File | What it is |
|---|---|
| `survey.rds` | 3,432 household records: 52 provinces × 2 years (2012, 2013), with the same columns as `Data/Spain/survey.rds` |
| `auxiliary.rds` | 104 province-year rows: the 2012 and 2013 rows of `Data/Spain/auxiliary.rds`, unchanged |
| `shapefile.rds` | Province boundaries: a byte-identical copy of `Data/Spain/shapefile.rds` (IGN/CNIG, CC BY 4.0) |
| `boundary_provenance.json` | A copy of the boundary's source, licence and modification record |
| `generation/` | The construction record: PSU transfer list, weight factors, province composition before and after, and the income multipliers |

## Suggested variable mapping (Step 2)

The mapping is the same as for `Data/Spain/`, with strata left blank:

| App field | Column |
|---|---|
| year | `year` |
| domain | `prov` |
| psu | `ea_id` |
| weight | `weight` |
| household size | `hhsize` |
| welfare | `income` |
| poverty line (column) | `povline` |
| benchmark level (grouped) | `region` |
| auxiliary / geometry join key | `prov` |

The application's default analysis years (2012 and 2013) match this dataset.

## How it differs from `Data/Spain/`

It was built from the 2012 and 2013 rows of `Data/Spain/` in two steps.

**1. Whole-PSU redistribution.** The original samples have as few as 2 households
in a province-year. PSUs were moved, together with all their households and in both
years, so that every province has **at least 25 households and 6 PSUs**.
- 54 PSUs (329 households) moved;
- 27 provinces received households and 21 gave them;
- 12 moves crossed regions.

Moved households take their new province's `prov`, `provlab` and `region`, so
**each province's sample partly consists of households originally drawn for
other provinces**. In Soria, moved households carry 93% of the weight.

Weights were recalibrated so that each province-year keeps its original
person-weighted total: recipients have equal weights, and donors are rescaled.
A household's weight can therefore differ between 2012 and 2013.

**2. Province-year income multipliers.** Household incomes were multiplied by
exp(λ), where λ is a capped province-year effect plus a national constant.
Each province's effect is τ·z₁ in 2012 and τ·(0.6 z₁ + 0.8 z₂) in 2013, so the
effects correlate 0.6 across years. Here τ = 0.35, and z₁ and z₂ are centred
standard-normal draws (seed 20261028). The cap kept at least one poor and one
non-poor household in every province-year that had them before; it bound in
4 province-years. A national constant per year keeps the headcount close to the
original.

| | 2012 | 2013 |
|---|---|---|
| Person-weighted headcount (original) | 0.206 (0.206) | 0.215 (0.214) |
| Mean income (original) | 13,310 (12,368) | 13,563 (12,413) |
| Person-weighted population | 170.5 million (unchanged) | 172.2 million (unchanged) |

Identifiers, PSU codes, household sizes, poverty lines and every auxiliary
variable are unchanged. As in `Data/Spain/`, the weighted population is a
property of the synthetic example, not an official total.

## Tested results

The full Workbench run (UFH → MFH → Comparison, 500 bootstrap replicates each)
was run through the application's own runner. It completed without error under
five MFH settings:

| MFH settings | MFH ρ̂ | MFH bootstrap |
|---|---|---|
| sm_all, AIC | 0.83 | 500/500 |
| sm_all, BIC | 0.78 | 500/500 |
| sm_out, AIC | 0.83 | 500/500 |
| sm_out, BIC | 0.81 | 500/500 |
| sm_all, AIC, `region` as strata | 0.83 | 500/500 |

UFH was run with the application defaults (arcsin, BIC, no strata, no
benchmarking), and its bootstrap completed 500/500 in both years.

In every run:
- MFH2 converged with interior covariance parameters, and its inference status is "regular";
- all 52 provinces have UFH and MFH estimates in [0, 1], with finite, positive bootstrap MSEs;
- the comparison table is complete.

Benchmarked runs and the HTML/Word report were not tested.

**Known caveat (UFH 2013).** BIC selects an intercept-only UFH model for 2013,
and its variance estimate is close to the upper end of emdi's search interval.
The pipeline's UFH bootstrap reuses that interval, and in 27% of the 2013
replicates the variance estimate is truncated at it. The run completes, but the
2013 UFH bootstrap MSE may be somewhat understated. This is a useful teaching
point in itself.

## Provenance, licence and attribution

Provenance chain: `sae::incomedata` → `Data/Spain/` → this documented
redistribution and transformation. The first link is unverified (see
`Data/Spain/README.md`). Everything after it is recorded in `generation/`. The
generation scripts and the full test evidence are held outside the repository,
in the maintainer's working folder (`spain_regeneration/v9` and
`tau035_full_run`).

The survey and auxiliary data derive from the synthetic `incomedata` dataset in
the CRAN package **sae: Small Area Estimation**, by Isabel Molina and Yolanda
Marhuenda. **`sae` is distributed under GPL-2, so `survey.rds`, `auxiliary.rds`
and `generation/` are distributed under GPL-2**, not under the MIT grant that
covers this package's code. Keep this notice, and `LICENSES/GPL-2.0.txt`, with
the files if you pass them on.

> Molina, I. and Marhuenda, Y. *sae: Small Area Estimation.* R package
> version 1.3. https://CRAN.R-project.org/package=sae

Like their `Data/Spain/` counterparts, these GPL-2 files are **not stored in
the Git repository**. They ship inside the release archive instead.
`shapefile.rds`, `boundary_provenance.json` and this README are in the
repository. After cloning, copy `survey.rds`, `auxiliary.rds` and `generation/`
into this folder from the `Data/Spain_2y/` folder of a release archive.

The boundary file is the IGN/CNIG CartoBase ANE derivative described in
`Data/Spain/README.md`, under **CC BY 4.0**. It is not covered by GPL-2 or the
application's MIT licence. Its source GeoPackages, crosswalk and regeneration
script are in `Data/Spain/`. Required attribution:

> Obra derivada de CartoBase ANE 2006-2024 CC-BY 4.0 ign.es

Keep the IGN attribution, the [CC BY 4.0 link](https://creativecommons.org/licenses/by/4.0/)
and the description of modifications in `boundary_provenance.json` when sharing it.
