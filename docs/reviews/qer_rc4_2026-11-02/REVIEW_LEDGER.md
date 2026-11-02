# Review ledger

EU SAE Workbench QER-RC4 | Version `5.2.0-rc.6-wizard.5.20` | Pre-release, not for official statistics | Prepared November 2, 2026

This ledger records what was reviewed, fixed, deferred and not covered. **Prior reviews cannot be certified as comprehensive.** Earlier reviews, including AI-assisted ones, had limited scope, and passing them does not show that no defects remain.

## Findings

Class follows the gate: blocker, non-blocking defect, or optional enhancement. Methodological disagreement goes to the decision register. "Proposed" means the owner has not yet classified the finding.

| # | Finding | Found on | Class | Outcome |
|---|---|---|---|---|
| P1 | Spain_2y configurations and the integration test stopped because they declared no PSU design | Pre-freeze | Blocker | Fixed before RC1 |
| P2 | Earlier QER package was built from uncommitted work | Pre-freeze | Blocker | Fixed: this package replaces it |
| P3 | QER note and receipts described earlier evidence | Pre-freeze | Non-blocking, proposed | Open in part: older receipts keep their dates and are grouped as historical. See "Known document issues" |
| P4 | Changelog and tag did not match the code | Pre-freeze | Non-blocking, proposed | Fixed at version stamp |
| F1 | `mfh_artifacts.rds` held row-level survey data | RC1 | Blocker | Fixed in RC2; no probe values found since |
| F2 | UFH plus Comparison failed with a raw file error | RC1 | Blocker | Fixed in RC2: rejected early with a clear message |
| F3 | Variance smoothing exploded and the run stopped | RC1 | Non-blocking, proposed | Fixed in RC4. Cause was a rounding residue treated as a positive variance; the same fault stopped 17-20% of simulated poverty samples |
| F4 | UFH differs from `sae::eblupFH` beyond tolerance | RC1 | Non-blocking, proposed | Open: decision register D11 |
| F5 | Reports did not say how many variances were replaced | RC1 | Non-blocking, proposed | Fixed in RC3 |
| F6 | Polish and Greek Guide 2 PDFs showed old text | RC1 | Non-blocking, proposed | Fixed in RC2; native review of slide text pending |
| F8 | UFH selection stops with a raw "computationally singular" error when candidates include very large columns such as population counts, with LASSO off. No estimates are produced. Reported by a country team on an older version; the selection code is unchanged in RC4, and synthetic data gave the same stop in 5 of 5 samples and none with counts logged | RC4 | Non-blocking, proposed | Open. It does not meet the gate's "clear stop" wording. Workaround: remove or log such columns, or use a fixed formula. MFH selection not checked. A fix changes estimation code, so it needs a new candidate |
| C1 | National correlation overstated without strata that separate domains | RC3 simulation | Methodological | Changed in RC4: decision register D1 |
| C2 | All four coverage results below 93-97% | RC3 and RC4 | Gate flag | Open: decision register D2, D4, D5 |
| C3 | High-poverty coverage near 85-88% even with true inputs | RC3 exploratory | Methodological | Open: decision register D4 |

## Candidates

| Candidate | Version | Change |
|---|---|---|
| QER-RC1 | 5.17 | First frozen candidate |
| QER-RC2 | 5.18 | Fixed F1, F2, F6; F3 given a plain message |
| QER-RC3 | 5.19 | Fixed F5 |
| QER-RC4 | 5.20 | Within-domain correlation; rounding fix closes F3 |

## Coverage by component

| Component | Reviewed on the candidates | Not covered |
|---|---|---|
| UFH | Pipeline cases; simulated comparison with MFH2 on RC3 | RC4 reference comparison with `sae` not repeated |
| MFH covariance | Cases on RC4; known-truth simulation | Strata that cross domains; partial overlap |
| MFH fit and convergence | Cases; test suite | Failed-refit path in a real run (unit tests only) |
| MFH change uncertainty | Cases; simulation; same-seed repeat | Formal different-seed assessment; invalid joint moments in a real run |
| Alignment | Cases; test suite | No separate review on RC4 |
| Benchmarking | Cases R5 and X2; constraints on RC1 | Not in the simulation; constraints not repeated on RC4 |
| Documentation and UI | Navigation check; report line for correlation | §8 review; UI-driven checks; native language review |
| Data locality | Network, payload and marker checks on RC4 | Short-lived connections between samples; clean machine |

## Earlier reviews

| Review | Scope | Limits |
|---|---|---|
| w5o, October 28, 2026 | Estimation, uncertainty, guidance | Earlier code |
| w5p independent reviews, October 28, 2026 | w5p revisions, `sm_all`, AI recommendation | Earlier code; the `sm_all` default has since been reversed |
| AI-assisted reviews before QER | Code, documents and consistency | Not every suggestion was validated. Not a comparison with the authors' code |

The gate's §8 final AI review on the frozen candidate has not been run.

## Deferred or not run

- Full workflow simulation with selection and benchmarking.
- Partly overlapping design simulation.
- E1 clean machine, E2 offline, E3 wizard against dashboard, E4 macOS and Linux.
- UI-driven checks.
- Formal Monte Carlo assessment of the different-seed run.
- Comparison with the Molina-Romero authors' code, which is not available in the repository.
- The 2,000-sample simulation in the gate. The owner reduced it to 500 samples per design; the achieved Monte Carlo SE was .13 to .17 points.

## Known document issues

These are in the frozen candidate, so they stay until a later candidate.

- The sampling-covariance note inside the application ZIP still describes the national correlation in Section 8. The emailed ZIP holds a revised draft for expert review, and the ZIP will take the agreed version in a later candidate.
- The deviations note still says that the release "remains an uncommitted local review candidate". RC4 is committed and tagged.
- The deviations note and `MCPE_VALIDATION_STATUS.md` were frozen before the gate simulation, so they do not hold its results. See `Validation_summary.pdf`.
- `QER_README.md` inside the application folder describes historical studies and adds no coverage evidence for RC4.
