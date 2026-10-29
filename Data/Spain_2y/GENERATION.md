# Generation, selection and deviations

## What was installed

On October 29, 2026, the verified moderate-correlation `candidate_01` replaced the active `Data/Spain_2y`. The user authorized this replacement after the candidate had completed both workflows. Its three RDS files were copied without editing; hashes are recorded in [acceptance_receipt.json](verification/acceptance_receipt.json) and [installation_receipt.json](verification/installation_receipt.json). The original `Data/Spain` and the full previous active version are preserved.

Later that day, at the user's request, **`povline_anchored` was restored** from the backed-up covariate-signal version. This adds one column to the 12-column moderate-correlation survey and changes no pre-existing values or attributes. The current survey hash is in [anchor_welfare_receipt.json](verification/anchor_welfare_receipt.json); older receipts retain their historical hashes. Four new full workflows verify anchored poverty and mean welfare. See [ANCHOR_AND_WELFARE.md](verification/ANCHOR_AND_WELFARE.md).

Two different earlier versions must be distinguished. The moderate-correlation generator revises the earlier **staged `workbench_goal`** example. Against that staged example, only 1,691 income values in 2013 change within the original 12-column schema; 2012 and all other existing survey columns are identical. The version that occupied **active `Data/Spain_2y`** before this installation was a different `v10_covariate_signal` variant. It added a covariate-linked income signal, a 12% poor-household cap rule and `povline_anchored`. Its income signal, cap rule and broader validation claims were not carried into the moderate-correlation candidate. Only the optional anchored-line column was subsequently restored and separately verified. The statement “only 2013 changes” does not describe the comparison with that formerly active version.

## Construction from the preserved original example

1. Retain the original synthetic example's 2012 and 2013 rows. There are 1,716 households and 442 paired PSUs per year. Keep identifiers and poverty lines. Auxiliary data retain the two years; geometry is copied unchanged.
2. Reallocate whole PSUs in both years together. Fill the smallest provinces first to at least 25 households and 3 PSUs; donors retain at least 25 households and 6 PSUs. Choose the nearest eligible donor within the region using 36 standardized baseline auxiliary covariates, then another region if no eligible same-region donor exists. Select the largest PSU that fits the shortfall, otherwise the smallest; break ties by codes. Allocation does not inspect income, poverty status or fitted results. The recorded outcome is 54 moved PSUs / 329 paired households, 27 recipients, 21 donors, 48 affected provinces and 12 cross-region transfers.
3. Update province, province label and region consistently. Preserve each original province-year `sum(weight * hhsize)`: recipients receive equal household weights within province-year; donors are rescaled by a province-year factor. Weights may differ between years. These preserved totals are synthetic, not official population totals. No households are added, removed or duplicated.
4. Reuse generation seed **20261028** and the saved centered normal vectors `z1c` and `z2c`. With **tau = 0.25** and **r_gen = 0.3**, set `u2012 = tau*z1c` and `u2013 = tau*(r_gen*z1c + sqrt(1-r_gen^2)*z2c)`.
5. Apply `income_new = income_baseline * exp(clamp(u + c_year, L, U))` to the redistributed data. Bounds use **delta = 0.01** and preserve at least one sampled poor/nonpoor household where that class was present after redistribution. Choose the annual calibration constant to attain the closest feasible original person-weighted national headcount; the discrete sample generally prevents exact equality. The record contains the bounds, constants and final multipliers. Two province-year upper bounds bind.

| Year | Original headcount target | Attained headcount | Difference, percentage points |
|---|---:|---:|---:|
| 2012 | 0.205868358460 | 0.205666640844 | −0.020172 |
| 2013 | 0.213862615359 | 0.213815212411 | −0.004740 |

The construction parameter `r_gen` is the correlation parameter of the added log-income perturbations. It is not a known or imposed MFH2 poverty random-effect correlation. Baseline income dependence, capping, poverty classification and estimation distinguish the two quantities.

## Selection and what the evidence establishes

After seeing high fitted correlations in an earlier example, the user requested fitted MFH2 correlations in **[0.3, 0.7]**. The revised finite search and its acceptance rules were frozen before generating candidates: tau = 0.25, 0.35, 0.45, 0.55, and within each tau, r_gen = 0.3, 0, −0.3, −0.6. Stop at the first complete pass. **The first candidate passed; no later candidate was generated.** This is outcome-conditioned synthetic-data design and is disclosed as such.

Both sm_out/AIC and sm_all/AIC required interior original-fit MFH2 covariance, moderate fitted correlation, nondegenerate residuals, valid sampling covariance, unclipped poverty estimates in [0,1], valid annual MSE and cross-year MCPE, positive usable change variances and all 52 provinces. UFH required arcsin/BIC fits with independently checked positive interior variances in both years. Both full workflows completed 500-draw uncertainty calculations and produced maps, Excel exports and HTML/Word reports. Statistical application sources were unchanged. Fresh-process regeneration reproduced the data exactly, and both MFH fit-only reproductions matched.

Positive random effects in every bootstrap draw, earlier signal-share/SD thresholds and an arbitrary maximum boundary-draw fraction were not requirements of this practical protocol. The sm_all bootstrap accepted 24 boundary draws out of 500 (4.8%); sm_out accepted none. Boundary draws are disclosed, not edited or discarded to improve presentation. Full receipts are in [verification/](verification/README.md).

## Relation to Molina and Romero (2025)

This synthetic regeneration, PSU reallocation, weighting adjustment, capped income perturbation and selection for moderate fitted correlation are **project teaching choices**, not instructions attributed to Molina and Romero (2025). Their purpose is to provide an example that completes the implemented two-year workflow with informative, nonzero variance components. They do not establish substantive Spanish poverty patterns or the statistical merits of either smoother.

This note describes dataset construction. It does not replace the package's methodological deviations note. Benchmarking and the additional anchored-poverty/mean-welfare features are separate project extensions. Anchored poverty and mean welfare now have their own verification runs; benchmarking remains off. The anchored line is constructed from the 2012 threshold and the retained teaching CPI, with 2010 used only as a price basis. Mean welfare is analyzed in 2012 prices. Bootstrap uncertainty conditions on selected formulas and estimated sampling matrices; log UFH with Slud–Maiti correction uses analytical MSE. UFH change uncertainty assumes year independence, whereas MFH uses cross-year MCPE. Coverage and model superiority have not been established by this demonstration.

## Reproducibility and history

See [generation/README.md](generation/README.md) for the installed audit records. The complete original generation code, baseline archive, frozen application, environment, fixtures, logs and outputs remain unchanged in the local maintainer audit package `Claude outputs/spain_regeneration/moderate_correlation_20261029/`. Its [frozen protocol](generation/protocol_frozen.md) records the earlier staging-only authorization; the later explicit replacement authorization is recorded in the installation receipt. Historical receipts are preserved rather than rewritten as if installation had already occurred.

Exact reproduction begins from the preserved project baseline. Its upstream derivation from `sae::incomedata` remains unverified pending the creator's transformation code. Survey/auxiliary and generation material retain GPL-2; geometry retains separate IGN/CNIG CC BY 4.0 provenance. The teaching CPI does not enter the income generator; it is used for the optional anchored line and for mean-welfare price conversion. After reproducing the original 12-column candidate, [add_anchored_line.R](generation/add_anchored_line.R) reproduces the current 13-column survey byte-for-byte with the retained CPI and recorded R version.
