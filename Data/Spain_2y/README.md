# Example data: Spain, two-year teaching variant (2012–2013)

This folder holds a **calibrated teaching version** of the Spain example, for
showing UFH and MFH side by side, for poverty and for mean welfare. With the
original example (`Data/Spain/`), the MFH2 fit for 2012–2013 sits on a
covariance boundary. With this variant, both methods complete for 2012 and
2013 with interior variance estimates. Covariate selection, with BIC as well as
AIC, keeps covariates in every UFH and MFH model. For poverty, the model RMSEs
are clearly below the direct RMSEs. The survey also carries a poverty line
anchored at 2010 prices.

It was made by deliberately altering the original samples and incomes. Results
from it **do not reproduce the guidance notes** and do not describe Spanish
provinces. To reproduce published results, use `Data/Spain/`.

| File | What it is |
|---|---|
| `survey.rds` | 3,432 household records: 52 provinces × 2 years (2012, 2013), with the columns of `Data/Spain/survey.rds` plus `povline_anchored` (see "Anchored poverty line") |
| `auxiliary.rds` | 104 province-year rows: the 2012 and 2013 rows of `Data/Spain/auxiliary.rds`, unchanged |
| `shapefile.rds` | Province boundaries: a byte-identical copy of `Data/Spain/shapefile.rds` (IGN/CNIG, CC BY 4.0) |
| `boundary_provenance.json` | A copy of the boundary's source, licence and modification record |
| `CPI_Spain_teaching.csv` | An illustrative consumer price index for 2010–2015 (2021 = 100), for mean welfare in constant prices and the anchored poverty line. Column `CPI` is INE's index adjusted so that 2012–2013 inflation is 5%; column `CPI_INE` keeps INE's published values |
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

**Anchored poverty.** Map the poverty line (column) to `povline_anchored`
instead of `povline`.

**Mean welfare.** `income` is in current (nominal) prices. To map mean welfare
in constant prices:
1. Choose **current prices: convert with a price index**.
2. Select `CPI_Spain_teaching.csv` as the CPI file, with year column `year` and
   CPI column `CPI`.
3. Keep the index type as a fixed reference year, with incomes referring to the
   survey year.

The default base year is 2012. The factor for 2013 is 92.717 / 97.35285 =
1 / 1.05 = 0.952381.

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
- **Covariate signal:** 0.30·S. S is a unit-SD index of the province's
  standardized `educ3` (tertiary education share) and `labor1` (employment
  share) from `auxiliary.rds`. It raises incomes where both are high, and is the
  same in both years, as the covariates are.
- **Random part:** 0.22·z₁ in 2012 and 0.22·(0.6 z₁ + 0.8 z₂) in 2013, where z₁
  and z₂ are centred standard-normal draws (seed 20261028). The random parts
  correlate 0.6 across years.

The two parts are balanced against each other:
- **Signal:** it is what makes covariate selection keep covariates. Without
  it, BIC selected intercept-only models for 2013.
- **Random part:** it is what the models cannot explain, so it decides how far
  UFH and MFH can improve on the direct estimates. With a random part of 0.35,
  the model estimates stayed close to the direct ones. Below about 0.20, the
  MFH variance estimate reaches zero.

The cap keeps at least k poor and k non-poor sampled households in every
province-year, where k = max(1, ⌈0.12 n⌉) and n is the number of households.
It bound in 27 of the 104 province-years. The national constant keeps the
headcount at its original value.

| | 2012 | 2013 |
|---|---|---|
| Person-weighted headcount (original) | 0.206 (0.206) | 0.214 (0.214) |
| Mean income, current prices (original) | 13,007 (12,368) | 13,001 (12,413) |
| Direct headcount by province (min–max) | 0.07–0.71 | 0.06–0.63 |
| Person-weighted population | 170.5 million (unchanged) | 172.2 million (unchanged) |

Province poverty is about as spread out as in the original example (standard
deviation across province-years 0.15, against 0.13).

Identifiers, PSU codes, household sizes, poverty lines and every auxiliary
variable are unchanged. As in `Data/Spain/`, the weighted population is a
property of the synthetic example, not an official total.

## Anchored poverty line

`povline` is the original year-specific line. It rises 0.59% from 2012 to
2013, much less than prices (5% by the teaching CPI). `povline_anchored` holds
the line's purchasing power fixed at 2010 prices.

The 2010 anchor is the original 2012 line deflated to 2010 prices with column
`CPI` of `CPI_Spain_teaching.csv`. Each year's anchored line is that anchor in
the year's current prices, so it compares directly with the nominal `income`:

```
z_2010             = povline_2012 × CPI_2010 / CPI_2012 = 6,477.48 × 87.701 / 92.717 = 6,127.05
povline_anchored_t = z_2010 × CPI_t / CPI_2010
```

| Year | `povline` | `povline_anchored` | Headcount, original line | Headcount, anchored line |
|---|---|---|---|---|
| 2012 | 6,477.48 | 6,477.48 | 0.206 | 0.206 |
| 2013 | 6,515.86 | 6,801.36 | 0.214 | 0.225 |

Because the anchor comes from the 2012 line, the two lines coincide in 2012.
The choice of 2010 as the base year sets the price basis of the anchor (6,127.05
in 2010 prices) but does not change the lines.

## Tested results

The full Workbench run (UFH → MFH → Comparison, 500 bootstrap replicates each)
was run through the application's own runner. It completed without error under
every setting below. UFH used the application defaults: arcsin and BIC for
poverty; log and BIC for mean welfare.

| Indicator | MFH settings | Covariates UFH 2012 / 2013 | Covariates MFH 2012 / 2013 | MFH ρ̂ |
|---|---|---|---|---|
| Poverty | sm_all, AIC | 3 / 5 | 12 / 15 | 0.76 |
| Poverty | sm_all, BIC | 3 / 5 | 5 / 5 | 0.83 |
| Poverty | sm_out, AIC | 3 / 5 | 12 / 15 | 0.77 |
| Poverty | sm_out, BIC | 3 / 5 | 5 / 5 | 0.76 |
| Poverty | sm_all, AIC, `region` as strata | 3 / 5 | 12 / 15 | 0.77 |
| Poverty | sm_all, BIC, national benchmarking | 3 / 5 | 5 / 5 | 0.84 |
| Poverty, anchored line | sm_all, BIC, national benchmarking | 3 / 2 | 5 / 5 | 0.84 |
| Mean welfare (log, CPI) | sm_all, AIC | 7 / 5 | 13 / 7 | 0.66 |
| Mean welfare (log, CPI) | sm_all, BIC | 7 / 5 | 5 / 5 | 0.61 |

The anchored-line and mean-welfare runs used `CPI_Spain_teaching.csv`.

In every run:
- MFH2 converged with interior covariance parameters, and its inference status is "regular";
- the MFH bootstrap completed 500/500, with at most 10% of replicates on a covariance boundary;
- the UFH poverty bootstrap completed 500/500 in both years;
- all 52 provinces have finite estimates and positive MSEs in both years;
- every poverty estimate lies between 0.02 and 0.68;
- the comparison table is complete.

The UFH poverty bootstrap with the original line was also traced: in both
years, no replicate's variance estimate was truncated at either end of emdi's
search interval. The HTML/Word report was not tested.

### Precision: model against direct estimates (poverty)

Median RMSE across the 52 provinces, and the share of provinces where the
model RMSE is below the direct RMSE:

| MFH settings | Year | Direct | UFH | MFH | UFH < direct | MFH < direct |
|---|---|---|---|---|---|---|
| sm_all, BIC, national benchmarking | 2012 | 0.078 | 0.059 | 0.061 | 85% | 73% |
| | 2013 | 0.072 | 0.056 | 0.062 | 83% | 65% |
| sm_all, AIC | 2012 | 0.077 | 0.059 | 0.062 | 85% | 73% |
| | 2013 | 0.071 | 0.056 | 0.062 | 83% | 62% |
| sm_out, BIC | 2012 | 0.077 | 0.059 | 0.059 | 85% | 94% |
| | 2013 | 0.071 | 0.056 | 0.056 | 83% | 94% |
| sm_out, AIC | 2012 | 0.077 | 0.059 | 0.064 | 85% | 94% |
| | 2013 | 0.071 | 0.056 | 0.058 | 83% | 94% |
| Anchored line, sm_all, BIC, benchmarking | 2012 | 0.078 | 0.059 | 0.060 | 85% | 73% |
| | 2013 | 0.074 | 0.061 | 0.062 | 83% | 69% |

**Why MFH gains are smaller under `sm_all`.** `sm_all` replaces every sampling
variance with a fitted value from log(variance) ~ log(sample size), which does
not depend on the poverty rate. It also multiplies the fitted value by
exp(σ²/2), about 1.4–1.5 here. Provinces with low poverty have small direct
variances, so their smoothed variance, and therefore their MFH RMSE, can
exceed their direct RMSE. Under `sm_out`, which keeps the direct variances,
MFH beats the direct estimate in 94% of provinces.

**Mean welfare.** Precision gains are small: the median UFH RMSE is about 4%
above the direct RMSE, and the median MFH RMSE 2–6% below. Income levels
differ between provinces far more than the sampling error of a province's mean
income, so the models place most weight on the direct estimates.

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
`shapefile.rds`, `boundary_provenance.json`, `CPI_Spain_teaching.csv` and this
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

`CPI_Spain_teaching.csv` is adapted from INE's national CPI series IPC251852,
"Nacional. Índice general. Índice." (base 2021 = 100). The monthly values were
retrieved from the INE API (`servicios.ine.es/wstempus`) on 29 October 2026.
- **`CPI_INE`:** INE's annual averages (the mean of the 12 monthly values,
  rounded to 3 decimals).
- **`CPI`:** a teaching modification, **not an official INE figure**. It equals
  `CPI_INE` up to 2012. For 2013 it is set to 92.717 × 1.05 = 97.35285, so that
  2012–2013 inflation is exactly 5% (INE: 1.41%). Values for 2014 and 2015 are
  INE's multiplied by the same factor (97.35285 / 94.023), rounded to 3
  decimals, so their annual changes stay as published.

INE publishes its statistics under **CC BY 4.0**, which permits this adaptation
with attribution and an indication of the changes. Required attribution:

> Elaboración propia con datos extraídos del sitio web del INE: www.ine.es
