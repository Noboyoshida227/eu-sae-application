# Example data: Spain, two-year teaching variant (2012–2013)

This folder holds a **calibrated teaching version** of the Spain example, for
showing UFH and MFH side by side, for poverty and for mean welfare. With the
original example (`Data/Spain/`), the MFH2 fit for 2012–2013 sits on a
covariance boundary. With this variant, both methods complete for 2012 and
2013 with interior variance estimates. Covariate selection, with BIC as well as
AIC, keeps at least four covariates in every UFH and MFH model.

It was made by deliberately altering the original samples and incomes. Results
from it **do not reproduce the guidance notes** and do not describe Spanish
provinces. To reproduce published results, use `Data/Spain/`.

| File | What it is |
|---|---|
| `survey.rds` | 3,432 household records: 52 provinces × 2 years (2012, 2013), with the same columns as `Data/Spain/survey.rds` |
| `auxiliary.rds` | 104 province-year rows: the 2012 and 2013 rows of `Data/Spain/auxiliary.rds`, unchanged |
| `shapefile.rds` | Province boundaries: a byte-identical copy of `Data/Spain/shapefile.rds` (IGN/CNIG, CC BY 4.0) |
| `boundary_provenance.json` | A copy of the boundary's source, licence and modification record |
| `CPI_Spain_INE.csv` | Spain's consumer price index (INE), annual averages for 2010–2015, 2021 = 100, for mean welfare in constant prices |
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

**Mean welfare.** `income` is in current (nominal) prices. To map mean welfare
in constant prices:
1. Choose **current prices: convert with a price index**.
2. Select `CPI_Spain_INE.csv` as the CPI file, with year column `year` and CPI
   column `CPI`.
3. Keep the index type as a fixed reference year, with incomes referring to the
   survey year.

The default base year is 2012. The factor for 2013 is 92.717 / 94.023 = 0.9861.

## How it differs from `Data/Spain/`

It was built from the 2012 and 2013 rows of `Data/Spain/` in two steps.

**1. Whole-PSU redistribution.** The original samples have as few as 2 households
in a province-year. PSUs were moved, together with all their households and in both
years, so that every province has **at least 25 households and 6 PSUs**:
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
exp(λ), where λ is a capped province-year effect plus a national constant per
year. The effect has two parts:
- **Covariate signal:** 0.45·S. S is a unit-SD index of the province's
  standardized `educ3` (tertiary education share) and `labor1` (employment
  share) from `auxiliary.rds`. It raises incomes where both are high, and is the
  same in both years, as the covariates are.
- **Random part:** 0.35·z₁ in 2012 and 0.35·(0.6 z₁ + 0.8 z₂) in 2013, where z₁
  and z₂ are centred standard-normal draws (seed 20261028). The random parts
  correlate 0.6 across years.

The signal is what makes covariate selection keep covariates. Without it, BIC
selected intercept-only models for 2013.

The cap keeps at least k poor and k non-poor sampled households in every
province-year, where k = max(1, ⌈0.08 n⌉) and n is the number of households.
It bound in 24 of the 104 province-years. The national constant keeps the
headcount at its original value.

| | 2012 | 2013 |
|---|---|---|
| Person-weighted headcount (original) | 0.206 (0.206) | 0.214 (0.214) |
| Mean income, current prices (original) | 13,834 (12,368) | 14,731 (12,413) |
| Direct headcount by province (min–max) | 0.05–0.86 | 0.04–0.86 |
| Person-weighted population | 170.5 million (unchanged) | 172.2 million (unchanged) |

Province poverty is more spread out than in the original example (standard
deviation across province-years 0.21, against 0.13). This is the price of a
covariate signal strong enough for BIC.

Identifiers, PSU codes, household sizes, poverty lines and every auxiliary
variable are unchanged. As in `Data/Spain/`, the weighted population is a
property of the synthetic example, not an official total.

## Tested results

The full Workbench run (UFH → MFH → Comparison, 500 bootstrap replicates each)
was run through the application's own runner. It completed without error under
every setting below. UFH used the application defaults: arcsin and BIC for
poverty; log and BIC for mean welfare.

| Indicator | MFH settings | Covariates UFH 2012 / 2013 | Covariates MFH 2012 / 2013 | MFH ρ̂ |
|---|---|---|---|---|
| Poverty | sm_all, AIC | 4 / 5 | 12 / 13 | 0.72 |
| Poverty | sm_all, BIC | 4 / 5 | 5 / 7 | 0.80 |
| Poverty | sm_out, AIC | 4 / 5 | 12 / 13 | 0.74 |
| Poverty | sm_out, BIC | 4 / 5 | 5 / 7 | 0.80 |
| Poverty | sm_all, AIC, `region` as strata | 4 / 5 | 12 / 13 | 0.73 |
| Poverty | sm_all, BIC, national benchmarking | 4 / 5 | 5 / 7 | 0.80 |
| Mean welfare (log, CPI) | sm_all, AIC | 7 / 4 | 14 / 9 | 0.68 |
| Mean welfare (log, CPI) | sm_all, BIC | 7 / 4 | 12 / 4 | 0.68 |

In every run:
- MFH2 converged with interior covariance parameters, and its inference status is "regular";
- the MFH bootstrap completed 500/500 with no replicate on a covariance boundary, and the UFH poverty bootstrap completed 500/500 in both years;
- all 52 provinces have finite estimates and positive MSEs in both years;
- every poverty estimate lies between 0.042 and 0.86;
- the comparison table is complete.

The UFH poverty bootstrap was also traced: in both years, no replicate's
variance estimate was truncated at the end of emdi's search interval. The
earlier version of this folder had 27% truncated in 2013. The HTML/Word report
was not tested.

**Teaching note.** Under the default `sm_all` variance option, the median MFH
bootstrap RMSE for poverty is above the UFH RMSE: 0.082 and 0.073 against 0.071
and 0.062 (2012 and 2013). Under `sm_out`, the two are close (0.074 and 0.065).

## Provenance, licence and attribution

Provenance chain: `sae::incomedata` → `Data/Spain/` → this documented
redistribution and transformation. The first link is unverified (see
`Data/Spain/README.md`). Everything after it is recorded in `generation/`. The
generation scripts and the full test evidence are held outside the repository,
in the maintainer's working folder (`spain_regeneration/v9` for the
redistribution and `spain_regeneration/v10_covariate_signal` for the income
multipliers).

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
`shapefile.rds`, `boundary_provenance.json`, `CPI_Spain_INE.csv` and this
README are in the repository. After cloning, copy `survey.rds`, `auxiliary.rds`
and `generation/` into this folder from the `Data/Spain_2y/` folder of a
release archive.

The boundary file is the IGN/CNIG CartoBase ANE derivative described in
`Data/Spain/README.md`, under **CC BY 4.0**. It is not covered by GPL-2 or the
application's MIT licence. Its source GeoPackages, crosswalk and regeneration
script are in `Data/Spain/`. Required attribution:

> Obra derivada de CartoBase ANE 2006-2024 CC-BY 4.0 ign.es

Keep the IGN attribution, the [CC BY 4.0 link](https://creativecommons.org/licenses/by/4.0/)
and the description of modifications in `boundary_provenance.json` when sharing it.

`CPI_Spain_INE.csv` holds the annual average (mean of the 12 monthly values,
rounded to 3 decimals) of INE's national CPI series IPC251852, "Nacional. Índice
general. Índice." (base 2021 = 100). The monthly values were retrieved from the
INE API (`servicios.ine.es/wstempus`) on 29 October 2026. INE publishes its
statistics under **CC BY 4.0**. Required attribution:

> Elaboración propia con datos extraídos del sitio web del INE: www.ine.es
