# Spain_2y: moderate-correlation teaching example

This is the active synthetic **2012–2013** example, installed on October 29, 2026. Start with [START_HERE.md](START_HERE.md). It has 1,716 households per year, 442 paired PSUs, 52 provinces, 104 auxiliary rows and 52 geometries.

The survey uses the verified moderate-correlation `candidate_01`, with **`povline_anchored` restored** on October 29, 2026. All 12 pre-existing columns and their attributes, including incomes and weights, are unchanged. Auxiliary data and geometry remain byte-identical to the accepted candidate. The current survey has 13 columns. See the [restoration and additional verification note](verification/ANCHOR_AND_WELFARE.md).

Both original-line poverty **UFH → MFH2 → Comparison** workflows completed before the column restoration, including uncertainty estimates, maps, Excel exports and HTML/Word reports. Adding an unused column leaves their analysis inputs unchanged. Their original results are:

| MFH2 sampling-variance policy | Fitted random-effect correlation | Innovation variance a | Marginal variance a/(1−rho²) | Successful bootstrap draws / attempts | Boundary draws |
|---|---:|---:|---:|---:|---:|
| sm_out / rho_sm_out | 0.57411 | 0.0040710 | 0.0060725 | 500 / 500 | 0 |
| sm_all / rho_sm_all | 0.65283 | 0.0032341 | 0.0056362 | 500 / 500 | 24 (4.8%) |

Four additional complete workflows verified the restored anchored line and mean welfare in 2012 prices. All have positive interior original-fit random-effect variances, nondegenerate residuals, valid estimates and uncertainty for all 52 provinces, and completed reports/workbooks. Their fitted MFH2 correlations are:

| Indicator | sm_all / rho_sm_all | sm_out / rho_sm_out |
|---|---:|---:|
| Anchored poverty | 0.65307 | 0.62789 |
| Mean welfare, log models and teaching CPI | 0.39184 | 0.42075 |

Each additional MFH run completed 500 successful bootstrap draws. Anchored-poverty UFH completed 500 draws per year; mean-welfare UFH used its production analytical Slud–Maiti MSE. Mean-welfare UFH uses **sm_all in both configurations**; the two columns above vary the MFH policy. These checks establish computational readiness under the stated settings, not model adequacy or interval coverage. See the verification note for boundary draws and the [presentation refresh](verification/PRESENTATION_REFRESH.md) for corrected map legends, diagnostic labels and regenerated reports.

UFH random-effect variances on the arcsin scale are **0.01396709 (2012)** and **0.02062090 (2013)**. Original fits have positive random-effect variances and nondegenerate residuals. UFH completed 500 bootstrap draws in each year. The 2013 UFH BIC selection is **intercept-only**; retaining covariates in every fitted model is not an acceptance requirement.

**These are deliberately selected synthetic teaching data, not official Spanish statistics.** Moderate fitted correlations and positive variances do not validate a smoothing policy, confidence-interval coverage or model superiority. The statistical estimators were unchanged. See [generation and deviations](GENERATION.md) and [verification evidence](verification/README.md).

## Files and scope

| File or folder | Purpose |
|---|---|
| `survey.rds`, `auxiliary.rds`, `shapefile.rds` | Load these three files in the Workbench. |
| [START_HERE.md](START_HERE.md) | Variable mapping, tested settings and where results appear. |
| `run_config_*.yml` | Explicit tested configurations for original-line poverty, anchored poverty and mean welfare, with paths relative to the Workbench root; see the starting guide. |
| [GENERATION.md](GENERATION.md) | Construction, selection, differences from previous examples and limitations. |
| [generation/README.md](generation/README.md) | Transfer, weighting, income-multiplier and generation audit records. |
| [verification/README.md](verification/README.md) | Acceptance, variance, reproduction and installation receipts. |
| [boundary_provenance.json](boundary_provenance.json), [province_crosswalk.csv](province_crosswalk.csv), [LICENSES/IGN_licence.pdf](LICENSES/IGN_licence.pdf) | Unchanged boundary attribution and province mapping. |
| [CPI_Spain_teaching.csv](CPI_Spain_teaching.csv) | Teaching CPI used to construct the anchored line and to express mean welfare in 2012 prices; retained unchanged. |

Validation covers original-line and anchored poverty FGT(0), UFH arcsin/BIC and untransformed MFH2/AIC; and mean welfare with log models, UFH BIC and MFH2 AIC. Benchmarking and AI are off. MFH BIC, other models, benchmarking and AI commentary are outside these runs. Changing settings or application versions can change the results.

Choose `povline` for the original-line poverty example, or `povline_anchored` for anchored poverty. The restored line is **6,477.484233 in 2012** and **6,801.358445 in 2013**, in each year's nominal prices. Compare nominal `income` directly with this column, leaving CPI conversion off for the supplied anchored-poverty configuration. The 2010 anchor is the 2012 poverty line expressed in 2010 prices; it is not an observed 2010 poverty threshold.

The retained CPI has annual 2010–2015 values. `CPI_INE` preserves the previously recorded INE national CPI annual averages (series IPC251852, base 2021=100); `CPI` is a teaching adaptation that gives 5% inflation from 2012 to 2013. It was retrieved for the earlier version on October 29, 2026. It does not change the stored incomes. Mean-welfare runs convert them during analysis using a 2013 factor of **1/1.05**, with 2012 as the price base. The teaching CPI values should not be presented as the published INE series.

## Preservation and attribution

`Data/Spain/` is unchanged. Complete backups preserve the formerly active covariate-signal version and the moderate-correlation version before column restoration. The [historical installation receipt](verification/installation_receipt.json) and [current restoration receipt](verification/anchor_welfare_receipt.json) record their paths and hashes. Earlier evidence is retained unchanged; the historical survey hashes refer to the pre-restoration schema. No release archive was built or published during that data-restoration task. The rebuilt w5p package now includes Spain_2y and excludes the original `Data/Spain/`; the original files remain in the repository working copy.

Survey, auxiliary data and derived generation records retain the **GPL-2** terms of the attributed source: Isabel Molina and Yolanda Marhuenda, *sae: Small Area Estimation*, R package 1.3. See [GPL-2](LICENSES/GPL-2.0.txt) and the [historical original README](provenance/original_README.md). The upstream derivation from `sae::incomedata` remains unverified until its creator supplies the transformation code; exact reproduction is established from the preserved project baseline.

Geometry has separate IGN/CNIG CC BY 4.0 terms: **Obra derivada de CartoBase ANE 2006-2024 CC-BY 4.0 ign.es**. Preserve its [licence](LICENSES/IGN_licence.pdf) and [provenance](boundary_provenance.json). The CPI adaptation retains CC BY 4.0 attribution: **Elaboración propia con datos extraídos del sitio web del INE: www.ine.es**. See also [third-party notices](../../THIRD_PARTY_NOTICES.md).
