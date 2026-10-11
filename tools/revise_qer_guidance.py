"""Apply reviewed QER methodology corrections, preserving original OOXML.

Run from the repository root with bundled Python. Originals are retained in
_private_build/qer_guidance_20261010 (excluded by the explicit release inventory).
Paragraph indices refer to those preserved originals; reruns are deterministic.
"""
from pathlib import Path
from zipfile import ZipFile
from copy import deepcopy
import shutil
import sys
import re
from lxml import etree

ROOT = Path(__file__).resolve().parents[1]
BACKUP = ROOT / '_private_build/qer_guidance_20261010/originals'
NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math'}
def tag(name):
    prefix, local = name.split(':')
    return '{%s}%s' % (NS[prefix], local)

def refresh_manual_toc():
    from pypdf import PdfReader
    path = ROOT / 'docs/guidance/guidelines_v5_2_0_rc6_wizard.docx'
    pdf = PdfReader(ROOT / '_private_build/qer_guidance_20261010/render/manual/guidelines_v5_2_0_rc6_wizard.pdf')
    normalize = lambda text: re.sub(r'[^a-z0-9]', '', text.lower())
    pages = {}
    def visit(items):
        for item in items:
            if isinstance(item, list): visit(item)
            else: pages[normalize(item.title)] = pdf.get_destination_page_number(item) + 1
    visit(pdf.outline)
    with ZipFile(path) as z: members = [(i, z.read(i.filename)) for i in z.infolist()]
    root = etree.fromstring(dict((i.filename, data) for i, data in members)['word/document.xml'])
    changed = 0; missing = []
    for p in root.xpath('.//w:p', namespaces=NS):
        styles = p.xpath('./w:pPr/w:pStyle/@w:val', namespaces=NS)
        if not styles or not styles[0].startswith('TOC'): continue
        ts = p.xpath('.//w:t', namespaces=NS)
        if not ts or not (ts[-1].text or '').isdigit(): continue
        title = ''.join(t.text or '' for t in ts[:-1])
        page = pages.get(normalize(title))
        if page is None: missing.append(title); continue
        ts[-1].text = str(page); changed += 1
    if missing: raise ValueError('Unmatched TOC headings: ' + repr(missing))
    temporary = path.with_suffix('.qer.tmp.docx')
    with ZipFile(temporary, 'w') as z:
        for info, data in members:
            z.writestr(info, etree.tostring(root, xml_declaration=True, encoding='UTF-8', standalone=True)
                       if info.filename == 'word/document.xml' else data)
    temporary.replace(path)
    print('Refreshed', changed, 'TOC page references from verified render')

if '--refresh-toc' in sys.argv:
    refresh_manual_toc()
    raise SystemExit(0)

def rewrite(path, changes, equations=None, additions=None):
    if '--only' in sys.argv and sys.argv[sys.argv.index('--only') + 1] not in path:
        return
    path = ROOT / path
    backup = BACKUP / path.relative_to(ROOT)
    backup.parent.mkdir(parents=True, exist_ok=True)
    if not backup.exists():
        shutil.copy2(path, backup)
    with ZipFile(backup) as z:
        members = [(i, z.read(i.filename)) for i in z.infolist()]
    root = etree.fromstring(dict((i.filename, data) for i, data in members)['word/document.xml'])
    paragraphs = root.xpath('.//w:p', namespaces=NS)
    original_math = len(root.xpath('.//m:oMath', namespaces=NS))
    def replace(p, text, math=False):
        props = p.find(tag('w:pPr'))
        text_runs = p.xpath('./w:r[w:t]', namespaces=NS)
        body_run = max(text_runs, key=lambda r: len(''.join(r.xpath('./w:t/text()', namespaces=NS))), default=None)
        first_run_props = body_run.find(tag('w:rPr')) if body_run is not None else None
        props = deepcopy(props) if props is not None else None
        rp = deepcopy(first_run_props) if first_run_props is not None else None
        for child in list(p):
            p.remove(child)
        if props is not None: p.append(props)
        if math:
            om = etree.SubElement(p, tag('m:oMath'))
            run = etree.SubElement(om, tag('m:r'))
            etree.SubElement(run, tag('m:t')).text = text
        else:
            run = etree.SubElement(p, tag('w:r'))
            if rp is not None: run.append(rp)
            t = etree.SubElement(run, tag('w:t'))
            t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
            t.text = text
    for index, text in changes.items(): replace(paragraphs[index], text)
    for index, text in (equations or {}).items(): replace(paragraphs[index], text, True)
    if path.name == 'Note on Estimating the Sampling-Error Covariance Matrix (revised).docx':
        p = paragraphs[143]
        # This was a colored code listing; revised prose uses body style.
        for prop in p.xpath('./w:r/w:rPr', namespaces=NS): prop.getparent().remove(prop)
        pp = p.find(tag('w:pPr'))
        if pp is not None:
            for child in list(pp): pp.remove(child)
            ps = etree.SubElement(pp, tag('w:pStyle')); ps.set(tag('w:val'), 'Normal')
    for index, texts in (additions or {}).items():
        anchor = paragraphs[index]
        for text in texts:
            p = etree.Element(tag('w:p'))
            # Body style avoids inherited heading or table numbering.
            pp = etree.SubElement(p, tag('w:pPr'))
            ps = etree.SubElement(pp, tag('w:pStyle')); ps.set(tag('w:val'), 'Normal')
            replace(p, text)
            anchor.addnext(p); anchor = p
    for t in root.xpath('.//w:t', namespaces=NS):
        if t.text: t.text = t.text.replace('EU_SAE_520_w5m', 'EU_SAE_520_w5n')
    updated = etree.tostring(root, xml_declaration=True, encoding='UTF-8', standalone=True)
    temporary = path.with_suffix('.qer.tmp.docx')
    with ZipFile(temporary, 'w') as z:
        for info, data in members:
            z.writestr(info, updated if info.filename == 'word/document.xml' else data)
    temporary.replace(path)
    print(path.relative_to(ROOT), 'changed paragraphs', len(changes), 'native equations',
          original_math, '->', len(root.xpath('.//m:oMath', namespaces=NS)))

LOG_UFH = ('Log mean welfare uses the log of the survey-weighted arithmetic Direct area mean, '
    'with sampling variance V/mean². Zero and negative individual welfare values remain in the '
    'arithmetic mean; the area mean must be positive and finite. UFH bias correction uses native '
    'emdi Slud–Maiti bc_sm with ML fitting and its original-scale analytical MSE. The naive '
    'option exponentiates the same fitted log-area mean and uses bootstrap MSE; it does not '
    'change the target into a geometric mean.')
LOG_MFH = ('MFH log models also transform the arithmetic Direct area means. Corrected currency '
    'predictions use the Gaussian conditional mean exp(eta + v/2), where v is the diagonal of '
    'G − G(G + R)⁻¹G. The naive option uses exp(eta). This multivariate extension is distinct '
    'from emdi’s univariate Slud–Maiti method; saved MFH settings named bc_sm are accepted as '
    'a legacy alias. Original-scale MSE and MCPE are estimated after inverse transformation '
    'inside the bootstrap.')
BOOT = ('The bootstrap simulates Gaussian random effects and sampling errors under the fitted '
    'model, refits the same estimator, and repeats back-transformation and the final ratio '
    'benchmark in reported units. Survey-derived targets are recomputed from the same replicate’s '
    'Direct estimates in both UFH and MFH. Uploaded targets remain fixed, so their own uncertainty '
    'is excluded. Errors are measured against the unbenchmarked synthetic area truth. Auxiliary '
    'variables, selected formulas, populations and estimated sampling covariance inputs are held '
    'fixed; variable-selection and variance-smoothing uncertainty are not included.')
JOINT = ('MFH annual MSEs and cross-year MCPE come from the same jointly accepted bootstrap draws. '
    'The change MSE is MSE1 + MSE2 − 2 MCPE. These are prediction-error second moments, not '
    'centered sample covariances. Invalid joint moments, unavailable moments or zero inferential '
    'variance produce unavailable inference with a diagnostic; they never trigger an invented '
    'independence fallback. Direct and separately fitted UFH changes retain the explicitly '
    'reported period-independence assumption, which needs care with overlapping surveys.')
GATE = ('The numerical check assesses REML score, local curvature and feasible boundary directions '
    'in addition to the package convergence flag. A positive variance alone does not establish '
    'convergence. MFH2 is refitted when necessary using the same REML objective, exact gradients '
    'and several feasible starts; a usable original fit is preserved and an inferior refit is '
    'rejected. A valid zero random-effect covariance is allowed, including in bootstrap refits. '
    'The AR(1) correlation is bounded numerically at ±0.999999; an accepted endpoint approximates '
    'a limiting stationary fit and warrants sensitivity review.')
BOUNDARY = ('Boundary-sensitive inference. If the original MFH fit has zero random-effect '
    'covariance or reaches the numerical correlation limit, point estimates are retained and '
    'inference_status is boundary_sensitive. Normal or delta-method intervals and p-values '
    'are provisional: numerical convergence does not establish their coverage. Reports flag '
    'this condition and record the count and fraction of accepted bootstrap fits at a boundary. '
    'Increasing the bootstrap count reduces Monte Carlo error but does not remedy boundary '
    'undercoverage. Review the current validation status and assess model sensitivity before '
    'using these results for substantive significance claims.')
QUALIFY = ('The implementation checks and simulation evidence are documented in '
    'docs/METHODOLOGY_ALIGNMENT.md and docs/MCPE_VALIDATION_STATUS.md. Numerical agreement and '
    'Monte Carlo precision do not certify interval coverage for all survey designs. Review '
    'model assumptions, boundary sensitivity and any undercoverage before dissemination. '
    'Use the latest validation status for current experiment counts and results.')

rewrite('docs/guidance/guidelines_v5_2_0_rc6_wizard.docx', {
7: 'Candidate 5.2.0-rc.6-wizard.5.14 (w5n) • October 2026',
246: 'Explains the independent REML endpoint checks and constrained refitting used for MFH2. The safeguard preserves usable fits, checks positive and zero variance endpoints, rejects inferior refits, and records numerical diagnostics. Bootstrap uncertainty does not require an available analytic g3 term.',
252: 'Documents analytical or bootstrap UFH MSE by transformation, jointly bootstrapped MFH MSE and MCPE, final original-scale benchmarking inside every replicate, and coherent uncertainty for changes and percentage changes. Pointwise significance remains primary; BH and Bonferroni are supplementary.',
431: 'For mean welfare, benchmark targets must share the input survey welfare price basis. If the app converts welfare to constant prices, it applies the same CPI factors to uploaded targets. When welfare is already in constant prices, targets must use those same prices. Benchmarking requires usable estimates and positive population weights for the requested benchmark population; incomplete coverage must be resolved, not silently scaled to a whole-area target.',
681: 'Figure 2. Earlier-run illustration of 2013 Direct, FH and MFH estimates, ordered by Direct poverty rate. Regenerate these estimates with the current revision before interpreting numerical differences.',
759: 'Figure 3. Earlier-run illustration of UFH residual diagnostics for 2013. Current numerical diagnostics must be regenerated with the revised estimator.',
460: 'For poverty, welfare and the poverty line define each household’s indicator. For mean welfare, the app first estimates the survey-weighted arithmetic area mean, including individual zero and negative values. An optional log model transforms that area mean after aggregation.',
717: LOG_UFH + ' The arcsine option follows the installed emdi point estimator; its upper-boundary limitation is disclosed in Annex G.4.',
769: BOOT + ' The shared Bootstrap replicates control defaults to 500 for UFH, MFH and benchmarking; explicit counts restored from older setups are retained. Successful finite replicates and rejected fits are counted; insufficient draws make uncertainty unavailable. More draws improve Monte Carlo precision, not model validity or guaranteed coverage.',
773: 'Mean welfare fitted in logs. ' + BOOT + ' There is no separate post-bootstrap currency adjustment and no reuse of a log-scale coefficient of variation as the MSE of the final estimator.',
828: 'MFH2 uses a stationary AR(1) area-effect covariance with common innovation variance. Its marginal variance is innovation variance divided by (1 − rho²). MFH2 remains the default because MFH3 failed to converge in the Spanish and Polish applications. The numerical safeguard checks the same REML model; it does not add an adjusted likelihood.',
830: 'MFH3 permits time-varying innovation variances and uses u0 ~ N(0,1), with u1 = rho × u0 + a1. The fit and bootstrap use this same initial state. Its fixed initial variance makes the model sensitive to outcome measurement scale and can complicate fitting. An unusable MFH3 endpoint leads to MFH2 with the reason recorded.',
834: 'MFH2 is the default. Selecting MFH3 starts the Molina–Romero sequence: fit MFH3, require a usable numerical endpoint, and retain it only if an adjusted reference-variance contrast rejects equality at alpha = 0.05. Otherwise select MFH2. A computational error and a failed convergence check are recorded separately.',
876: LOG_MFH + ' CPI conversion precedes direct estimation and serves a different purpose from the model transformation.',
894: GATE + ' The selected model’s annual uncertainty is bootstrapped; missing analytic Fisher-information or g3 calculations are disclosed without preventing an otherwise valid bootstrap.',
896: 'Figure 5. Earlier-run MFH residual plots for 2013. These images predate the revised standardization; current plots use the model-based residual variance described above.',
921: 'Figure 6. Earlier-run illustration of benchmarked MFH poverty changes and pointwise significance, 2012–2013. Rerun the revised estimator and joint uncertainty before interpreting significance.',
998: 'Figure 7. Earlier-run illustration of RMSE by method in 2013. These values predate the methodology revision and do not establish the current relative precision of Direct, UFH and MFH.',
1085: 'Figure 8a. Earlier-run maps of Direct and benchmarked MFH poverty in 2013, using a common color scale. Smoothness alone does not establish greater accuracy. Regenerate current estimates before use. Boundaries: Obra derivada de CartoBase ANE 2006-2024 CC-BY 4.0 ign.es.',
1089: 'Figure 8b. Earlier-run Direct and benchmarked MFH RMSE maps for 2013. Current uncertainty must be regenerated with the revised estimator. Boundaries: Obra derivada de CartoBase ANE 2006-2024 CC-BY 4.0 ign.es.',
1094: 'Figure 9. Earlier-run benchmarked MFH change map, 2012–2013. Blue denotes decreases and red increases. Rerun current estimates and uncertainty before drawing conclusions. Boundaries: Obra derivada de CartoBase ANE 2006-2024 CC-BY 4.0 ign.es.',
1100: 'The EU SAE wizard guides the full workflow: direct estimation, UFH, MFH, comparison, benchmarking, maps, diagnostics, and reports. Sections 11.1 to 11.9 explain the general workflow from installation to retaining outputs. Read it once, then use one of the three examples in Sections 11.10 to 11.12 to set the indicator and price basis; Section 11.13 explains how to read the change outputs. The classic dashboard remains available; the wizard is the recommended interface for routine use. These instructions refer to application 5.2.0-rc.6-wizard.5.14 (w5n). Earlier screenshots use the Spain example (survey years 2012 and 2013); the worked examples use 2022 and 2023.',
911: JOINT + ' The companion MSE note documents this calculation. The distinct sampling-error covariance supplied to the model is described in the sampling-covariance note. Annex H records bootstrap provenance and validation limits.',
913: 'Changes in mean welfare are reported as 100 × (later mean / earlier mean − 1). The interval and p-value use a first-order log-ratio variance calculated from coherent original-scale annual MSEs and MCPE. The interval is asymmetric and bounded below by −100%. Currency differences remain in fields ending in _eur. Old MFH outputs without joint annual moments must be rerun before change inference.',
1136: LOG_UFH + ' MFH uses its separate conditional-lognormal correction, described in Annex G.4. Check the recorded method after restoring an older setup.',
1137: 'For MFH, review covariates, selection criterion, LASSO, variance and compatible sampling-covariance options, model, variance-test adjustment and bootstrap count. Poverty uses the identity scale. Mean welfare can use log with conditional-lognormal correction. MFH2 remains default; selecting MFH3 tries it first and retains it only after numerical checks and adjusted variance-test support. Also fit MFH3 adds a comparison fit without changing the selected model.',
1139: 'Bootstrap replicates defaults to 500 and applies to UFH bootstrap MSE, MFH MSE/MCPE and both benchmark paths. Explicit older saved counts are retained; check the restored value. More draws reduce Monte Carlo error but do not guarantee coverage. Pointwise significance remains primary; BH and Bonferroni are supplementary sensitivities.',
1141: 'Figure 14. Earlier interface illustration of Step 4. The current control is Bootstrap replicates, default 500, and the log corrections are model-specific as described in the text.',
1183: 'A fall from 20% to 18% is −2 percentage points, or a −10% relative change. Current change maps, significance plots, report significance tables and change-comparison summaries display headcount changes in percentage points. The underlying significance workbook and raw change fields retain proportions: −0.020 is −2.0 points (Section 11.13). Review estimates, RMSEs, intervals and pointwise significance from the actual run. A contemporaneous relative line moves with the income distribution, so the change describes poverty under each year’s threshold.',
1273: 'Step 4 Models. Keep UFH, MFH, and Comparison selected. If a log model is appropriate, retain individual zero and negative welfare in the arithmetic Direct means and verify positive finite area means. UFH correction is native emdi Slud–Maiti with ML fitting; MFH correction is conditional lognormal. The naive option keeps the same area-mean target but omits the correction. Compare with no transformation when model assumptions are doubtful.',
1274: 'MFH2 is the initial model. Review variance and covariance choices, bootstrap failures and Monte Carlo stability. Use at least 500 replications for final inference after a stability study. Benchmarking is optional; supplied targets must share the survey’s input price basis. CPI conversion applies the same factors to welfare and targets. The complete currency estimator and benchmark are recomputed within every replicate.',
1275: 'Steps 5 and 6. Leave AI off unless wanted and authorized. Confirm survey and income years, price basis, CPI values, base year, currency, log-model and correction choices, and benchmark targets. Run Check Data Readiness, resolve errors, then Run Analysis. Confirm the report states the intended price basis and actual estimator.',
1277: 'Levels and level RMSEs use currency units of the constant-price year. UFH corrected log MSE uses emdi’s Slud–Maiti calculation; UFH naive and selected MFH log uncertainty use original-scale bootstrap errors. Main change outputs report 100 × (later mean / earlier mean − 1), with log-ratio intervals. A common positive rescaling leaves a given pair’s percentage change unchanged; refitting MFH3 can be scale-sensitive because its initial variance is fixed.',
1280: 'The change box plots compare Direct, UFH, the selected MFH model, and benchmarked estimates when enabled. For poverty, the box plots, change_rmse_by_method.csv and the Change and RMSE by method and Change and RMSE summary sheets show changes and RMSEs in percentage points. The Domain changes sheet of change_estimate_comparison.xlsx shows unbenchmarked UFH and MFH changes and intervals in percentage points, without RMSEs. Current change maps, significance plots and report significance tables also display percentage points. The report multiplies stored changes and interval endpoints by 100, and stored MSE by 10,000 to show squared percentage points (pp²). The statistical_significance_comparison.xlsx workbook and raw change/interval fields in the underlying CSV exports retain proportions, and their MSE fields retain squared proportions: −0.020 represents −2.0 percentage points. Mean-welfare box plots use the raw log ratio ln(later mean / earlier mean), with RMSE on that log scale; neither is multiplied by 100. For small changes, 100 times the log ratio approximates a percentage change; the exact percentage is 100 × (exp(log ratio) − 1). Main mean-welfare change maps and tables report the exact percentage change.',
1325: 'Use arcsine with package bias correction for UFH headcounts, BIC for UFH selection, AIC for MFH selection and MFH2 as starting settings; review diagnostics and sensitivity. Log mean-welfare models target arithmetic area means. UFH uses emdi Slud–Maiti correction and MFH uses conditional-lognormal correction. For MFH, sm_out with rho_sm_out is a starting choice when sampling dependence is plausible and Direct covariance estimates are unstable. The 0.001 variance threshold is an application rule, on the modeled response scale. Use zero covariance only for independent rounds or a documented sensitivity. The shared Bootstrap replicates default is 500; inspect Monte Carlo error, convergence and boundary sensitivity.',
1435: 'REML (Restricted Maximum Likelihood). The variance-fitting criterion used for ordinary UFH and MFH. Corrected and naive UFH log models use ML to match emdi’s Slud–Maiti implementation.',
1441: 'Numerical safeguard. Independent REML endpoint checks and constrained MFH2 refitting when needed. Valid positive or zero variance fits may be retained; a package convergence flag alone is insufficient.',
1443: 'Log transformation. The log of an arithmetic Direct area mean, with delta sampling variance. It requires a positive area mean, while retaining individual zero and negative welfare. UFH uses emdi Slud–Maiti correction; MFH uses conditional-lognormal correction. Neither model fits household log welfare.',
1570: '☐ Model endpoint is usable; positive or zero variance is supported by numerical checks and sensitivity review.',
1572: '☐ Normality plots reviewed as descriptive diagnostics; correlated residuals do not supply exact independent-sample normality tests.',
1578: '☐ MFH REML score, curvature, boundary checks and refit diagnostics reviewed; selected annual MSE and MCPE use accepted joint bootstrap draws.',
1594: 'Step 4 Models. Keep UFH, MFH, and Comparison selected. Review transformations, model-specific corrections, covariates, variance and covariance inputs, benchmarking, MFH selection and bootstrap settings.',
1600: 'Apply the quality and reporting checks in Sections 12 and 13. Confirm units before interpreting results: current poverty-change maps, plots and report tables display percentage points, while the underlying significance workbook and raw change fields retain proportions; real mean-welfare changes use percent and mean-welfare box plots use raw log ratios (Section 11.13).',
1616: 'MFH endpoint fails its numerical checks',
1617: 'Weak identification, difficult optimization or unstable sampling covariance',
1618: 'Inspect score, curvature, boundary and covariance diagnostics; assess MFH2 or UFH sensitivity. Zero variance alone is not failure.',
1662: 'The implementation returns exp(fitted log variance + residual variance/2), a lognormal correction to the displayed basic GVF. With too little training variation, a constant-variance fallback is flagged. The sm_out threshold of 0.001 is application-specific; for log means it applies to the sampling variance of the log area mean. Arcsine fitting instead uses 1/(4 n_eff). Estimated working variances remain fixed in the bootstrap.',
1665: 'Log mean welfare. Both UFH and MFH transform the arithmetic Direct area mean after survey aggregation. The delta sampling variance is V/mean²; cross-year covariance becomes C/(mean1 × mean2). Individual zero and negative welfare is retained. Each modeled area mean must be positive and finite.',
1667: 'Here eta is the fitted log-area predictor, A is the UFH random-effect variance, gamma = A/(A + D), and D is the log-scale sampling variance. Native emdi bc_sm uses ML and its Slud–Maiti analytical MSE. Naive UFH uses exp(eta) from the same ML fit and original-scale bootstrap MSE. Neither uses empirical micro-log smearing.',
1668: LOG_MFH + ' Native emdi bc_sm leaves corrected log predictions for unsampled areas unavailable. Benchmarking cannot proceed for an incomplete requested population; no ad hoc correction is substituted.',
1677: BOOT,
1681: 'For log mean welfare, these ratio formulas use currency-scale predictions and currency targets after back-transformation. The complete adjustment is repeated inside every bootstrap draw. Original-scale MSE and MCPE describe that same final estimator.',
1687: 'MCPE is estimated by the package bootstrap, building on code supplied by Prof. Isabel Molina, refined by Ifeanyi Nzegwu Edochie and integrated by the maintainer. All three joint moments use the same accepted draws. Pointwise raw tests remain the primary significance display; BH and Bonferroni sensitivity fields are exported. Area-level multiplicity differs from the MFH variance-structure test in Section 8.6. ' + QUALIFY,
1694: 'The interval is asymmetric and bounded below by −100%. MFH uses the jointly exported annual_mse_y1, annual_mse_y2 and annual_mcpe from the same final-estimator bootstrap. It never reconstructs MCPE by mixing analytic level MSE with a bootstrap change MSE. Invalid joint moments or nonpositive inferential variance produce unavailable inference. Direct and UFH use the explicitly reported zero-MCPE assumption.',
1698: GATE,
1699: 'The numerical check changes the optimization route, not the MFH2 likelihood or covariance model. Sampling covariance matrices are repaired, if required, once before the original fit, and the exact same matrices are used for simulation and refitting. Repairs and endpoint checks are retained with run diagnostics. Increasing bootstrap replication cannot correct a misspecified model or an unusable fitted endpoint.',
1738: 'MFH2 remains default because MFH3 failed to converge in the Spanish and Polish applications. Selecting MFH3 invokes the paper’s sequence, with independent numerical endpoint checks and adjusted variance contrasts; MFH2 is selected if the endpoint or contrast evidence is insufficient. Bonferroni is default; BH is a sensitivity option.',
1744: 'The bootstrap extends the supplied manuscript, which does not specify a complete implementation. It now uses matching MFH covariance structures, full original-scale estimators and common accepted draws for annual MSE and MCPE. Structural tests and simulation evidence are documented separately; they do not guarantee coverage under every design.',
1750: 'The package checks numerical endpoints, permits valid zero variance, refits MFH2 when necessary, and repairs sampling covariance once before original fitting. Invalid joint uncertainty is reported as unavailable. These implementation choices are logged and remain subject to model and inferential review.',
1763: '5. Calculate MSE(change) = MSE1 + MSE2 − 2 MCPE from the same accepted draws. Check the joint matrix for valid finite nonnegative diagonal moments and feasible cross-products. Invalid or zero inferential variance gives unavailable intervals and p-values with a recorded reason; no independence replacement is made.',
1766: QUALIFY + ' Native emdi point and MSE checks, independent joint-bootstrap identities, dense-versus-block REML checks, endpoint tests and fitted-model simulations support the current revision. The latest status file distinguishes exact-parameter checks from fitted-model coverage experiments.',
1769: '• Review failed refits, repaired covariance matrices, boundary endpoints, insufficient successful replicates and unavailable inference; retain diagnostic counts with the report.'
}, equations={1666: 'UFH bc_sm:  μ̂ = exp{η̂ + ½ Â(1 − γ̂)}'}, additions={
195: ['QER methodology revision. This manual describes candidate 5.2.0-rc.6-wizard.5.14 (w5n). It corrects log-area estimation, bootstrap benchmarking, numerical convergence and joint uncertainty. Historical screenshots and country-example figures illustrate the workflow; regenerate country results with this revision before using their numerical conclusions. ' + QUALIFY],
894: [BOUNDARY, 'MFH residual plots standardize Direct minus EBLUP by sqrt(diag(R P R)), where P accounts for fitted fixed effects. The residuals remain correlated. Q–Q plots, Shapiro–Wilk and residual-versus-fitted regressions are descriptive checks, not exact independent-sample tests.'],
1664: ['EMDI compatibility limit. The supplied note displays a full-real-line corrected arcsine integral; tested emdi 2.2.3 integrates only over [0, pi/2]. The package preserves that point rule and warns when fitted Gaussian mass above pi/2 exceeds 1%. Its bootstrap evaluates the same estimator against clamped latent truth. The naive inverse clamps to [0, pi/2] before sin² in both point estimates and replicates. Consistency of that calculation does not establish unbiasedness near boundaries.'],
1674: ['MFH2 uses stationary initialization, so its marginal variance is innovation variance/(1 − rho²). MFH3 starts from u0 ~ N(0,1), then u1 = rho × u0 + a1. This initial-state convention is used in fitting and simulation and makes MFH3 sensitive to the outcome scale.']
})

rewrite('docs/guidance/Technical notes/Note on MSE Estimation - Levels and Changes.docx', {
2: 'October 2026 • revised for 5.2.0-rc.6-wizard.5.14 (w5n)',
4: BOOT,
10: 'The sampling layer has independent normal errors with known working variances; the linking layer has normal area effects and fixed auxiliary covariates. Ordinary UFH variance components are fitted by REML. Log-area-mean UFH uses ML to match emdi bc_sm. The EBLUP combines the Direct and regression predictors with precision-dependent weights.',
13: LOG_UFH + ' Identity-scale UFH uses the analytical Prasad–Rao/Datta–Lahiri MSE. Arcsine UFH uses the package-compatible point estimator and a consistent original-scale parametric bootstrap.',
20: 'The package estimates final-estimator MSE by a Gaussian model-based bootstrap. It draws random effects with fitted variance and sampling errors with the fixed working sampling variance, on the model scale. It does not divide empirical residuals by an estimated standard deviation; genuine zero random-effect variance is therefore supported. Each draw has a synthetic area truth and Direct observation:',
22: 'The same estimator is refitted and transformed to the reporting scale. Survey-derived benchmark targets are recomputed from the same replicate Direct values; uploaded targets remain fixed. Benchmarking follows back-transformation, including for log means. Squared errors compare the final original-scale predictor with original-scale latent truth:',
24: 'All requested draws are checked for finite predictions and errors. UFH requires at least 90% successful finite replicates, otherwise uncertainty fails explicitly. Successful counts and failure reasons are recorded; MSE = FALSE leaves benchmark MSE unavailable. Final currency benchmarking is repeated inside every replicate, with no post-hoc coefficient-of-variation rescaling.',
29: 'Selected MFH annual MSEs and cross-year MCPE are computed jointly by parametric bootstrap. Random effects and sampling errors follow the fitted Gaussian covariance model. The same estimator, inverse transformation and optional final benchmark are applied in every accepted draw. MCPE is the expected product of prediction errors; it need not equal their centered covariance.',
32: 'MFH3 uses u0 ~ N(0,1), then u1 = rho × u0 + a1 and the time-varying innovation recursion. MFH1 draws independent effects with a separate variance for each year. These definitions match the fitted covariance, including zero random-effect covariance.',
36: 'Refit the same MFH variant and require usable numerical endpoint checks and finite predictions for all included domains and periods. Failed draws are counted and retried up to the attempt limit. A draw is accepted jointly; all annual MSE and MCPE entries share the same accepted draws and divisor.',
39: 'The joint second-moment matrix supplies both selected annual MSEs and MCPE. Original point estimates come from the original fit. Requested and successful counts, attempts and Monte Carlo errors are recorded. The shared Bootstrap replicates control defaults to 500 for UFH, MFH and benchmarking, while preserving explicit older saved counts. Select replication after stability checks; a larger count does not guarantee coverage.',
40: GATE + ' Analytic g3/Fisher-information availability is separately reported. A valid bootstrap can provide uncertainty even when analytic g3 is unavailable.',
42: 'Benchmarking applies a ratio adjustment separately by group and year to the final reporting-scale estimates, using the requested population coverage and positive aggregation weights:',
47: 'The survey target in each draw is recomputed from that draw’s Direct estimates. Uploaded targets remain fixed. For log means, Direct observations, predictions and truth are first returned to currency units, then benchmarked; MSE and MCPE are computed from final currency-scale errors. These errors are measured against unbenchmarked synthetic truth:',
49: 'Benchmarked MSE includes the adjustment’s variability and prediction bias under the bootstrap model. The seed and requested replication count are configurable and retained. The same fixed sampling covariance inputs drive the original fit, simulated data and each refit.',
55: 'Pointwise 95% intervals and raw p-values remain the primary display. BH and Bonferroni adjusted p-values and significance flags support sensitivity statements across areas. Positive MCPE reduces the change MSE when annual MSEs are held fixed, but its sign is estimated, not assumed. Unavailable or invalid joint moments produce unavailable inference.',
57: 'Joint-moment guard. All three moments must come from the same accepted draws. A valid second-moment matrix obeys |MCPE| ≤ sqrt(MSE1 × MSE2), up to roundoff. The implementation checks this bound and finite nonnegative diagonal entries. It does not replace invalid moments with independence.',
58: 'MFH: invalid joint moments ⇒ unavailable uncertainty; Direct/UFH: MCPE = 0 is an explicit period-independence assumption.',
59: 'Unavailable moments, invalid joint moments and zero inferential variance are recorded with diagnostic status and unavailable intervals or p-values. A higher bootstrap count may reduce simulation error, but does not repair model misspecification. Period independence for Direct and UFH requires separate justification when surveys overlap.',
60: LOG_MFH + ' Currency changes use the joint currency moments directly:',
62: 'Percentage mean-welfare change is 100 × (mean2/mean1 − 1). Its log-ratio variance is approximately MSE1/mean1² + MSE2/mean2² − 2 MCPE/(mean1 × mean2), using the same original-scale joint bootstrap moments for MFH and explicit MCPE = 0 for UFH. The interval is formed on the log-ratio scale and exponentiated. Missing legacy MFH moments require a rerun; they are never reconstructed by mixing analytical level MSE with bootstrap change MSE. Currency differences remain in fields ending in _eur.',
67: 'UFH level identity / corrected log',
68: 'Identity: analytical Prasad–Rao/Datta–Lahiri; log bc_sm: native emdi Slud–Maiti (ML)',
69: 'Gaussian full-estimator bootstrap; final benchmark in reporting units each draw',
70: 'UFH level arcsine / naive log',
71: 'Original-scale bootstrap matching the point estimator',
72: 'Same bootstrap with final original-scale benchmark',
74: 'Joint parametric bootstrap; shared Bootstrap replicates control, default 500',
75: 'Same final-estimator bootstrap with reporting-scale benchmark each draw',
78: 'Same coherent joint formula and validity check for benchmarked moments',
79: BOOT,
82: 'Bootstrap accuracy depends on the fitted model and fixed sampling covariance approximating the data-generating process. Failed refits and insufficient successful draws require review. ' + QUALIFY,
83: 'Comparing benchmarked and unbenchmarked uncertainty',
84: 'Both calculations use the shared full-estimator bootstrap machinery. Record seeds and successful-draw sets when comparing MSEs: failed refits or different requested counts can change the accepted draws. Differences should be assessed with the exported Monte Carlo diagnostics.',
91: 'Slud, E. V. and Maiti, T. (2006). Mean-squared error estimation in transformed Fay–Herriot models. Journal of the Royal Statistical Society, Series B, 68(2), 239–257.'
}, equations={61: 'MSE(Δ) = MSE₁ + MSE₂ − 2 MCPE₁₂'}, additions={
5: ['QER revision for 5.2.0-rc.6-wizard.5.14 (w5n), October 2026. This note describes the final-estimator bootstrap and current joint-moment rules. ' + QUALIFY],
40: [BOUNDARY]
})

rewrite('docs/guidance/Technical notes/Note on eblupMFH2_robust.R.docx', {
1: 'Checking REML endpoints and refitting the same MFH2 model when necessary',
3: 'October 2026 • revised for 5.2.0-rc.6-wizard.5.14 (w5n)',
5: GATE,
6: 'A valid original endpoint, including zero variance, is retained. A candidate refit must pass the same numerical checks and cannot have an inferior REML objective. A failed check is explicitly recorded; positivity of refvar is not a convergence certificate.',
9: 'Zero variance is a possible likelihood optimum, not automatic evidence of software failure. The safeguard checks whether a feasible direction or alternative endpoint improves the same REML objective. It does not force positive variance or introduce an adjusted likelihood.',
10: 'Score and curvature diagnostics distinguish an admissible likelihood endpoint from a merely positive returned variance. Boundary checks include feasible directions, with special treatment of parameters unidentified at zero random-effect covariance.',
17: 'Original MFH2 fits and bootstrap refits use the same wrapper and endpoint checks. This keeps parameter estimation consistent between the reported estimator and the uncertainty calculation.',
29: 'The pipeline checks both positive and zero variance endpoints. A true zero covariance produces a regression-synthetic predictor and remains eligible for bootstrap calculation, with inference explicitly flagged as boundary-sensitive. An unusable endpoint is not accepted merely because no better numerical fit was found.',
30: 'Numerical tolerances govern feasible parameters, scaled scores and local curvature; they are not substantive thresholds for area heterogeneity. Review recorded tolerances and endpoint diagnostics with the fitted variance and correlation.',
33: 'The wrapper obtains the original or patched package fit and evaluates its REML endpoint independently. A usable result is retained unless a supported refit improves the objective; a positive refvar alone no longer bypasses checking.',
35: 'When refitting is required, the optimizer reconstructs the response, design and covariance inputs:',
37: 'the year-specific design matrices, using block calculations equivalent to the stacked formulation;',
46: 'Optimization uses a dimensionless marginal-variance scale and a bounded correlation:',
48: 'Bounded optimization with exact REML gradients includes zero marginal variance and limits correlation to ±0.999999. Non-positive-definite marginal covariance or fixed-effect information invalidates a trial. The numerical correlation bound approximates the stationary limit.',
49: 'The optimizer includes an exact zero-variance candidate, rather than searching only the positive interior. Feasible boundary derivatives and curvature are checked. At zero covariance, correlation is unidentified and is handled accordingly.',
51: 'L-BFGS-B optimization uses several starting values and an exact zero-variance candidate. Each supported candidate is evaluated against the original endpoint on the same REML objective; an inferior refit cannot replace a valid original fit.',
55: 'The fit records independent convergence checks, boundary status, refit use and failure reasons, covariance-inversion diagnostics and analytic g3 availability. The pipeline writes numerical diagnostics and metadata with the selected fit. Missing analytic g3 does not disable a valid joint parametric bootstrap.',
58: 'The safeguard retains the stationary AR(1) MFH2 model and REML/EBLUP framework. It changes numerical optimization and endpoint verification, including checking positive package endpoints that can otherwise be mistaken for convergence.',
61: 'The wrapper optimizes the unchanged REML likelihood under valid constraints. It neither applies a likelihood adjustment nor forces a strictly positive variance. Valid zero covariance remains an eligible solution.',
63: 'Constrained covariance estimation is standard mixed-model practice. This implementation optimizes scaled marginal variance and bounded correlation directly, with exact gradients and explicit zero-variance candidates.',
65: 'If an alternative endpoint passes the checks and improves the REML objective, the original numerical solution was inadequate. This conclusion applies to positive as well as zero returned variances.',
66: 'If the original zero-variance endpoint passes the score, curvature and feasible-direction checks, it remains eligible. Failure to find a positive solution alone is not proof that a boundary is correct.',
67: 'The retained solution must be numerically supported under the same likelihood. This safeguard reduces false convergence but does not establish that the covariance model or resulting inference is substantively correct.',
69: GATE + ' ' + QUALIFY
}, equations={47: 'Aₘ = σ²ᵤ/(1 − ρ²),  a = Aₘ/s,  a ≥ 0,  |ρ| ≤ 0.999999'}, additions={
23: ['Here σ²ᵤ is innovation variance; Aₘ is marginal random-effect variance and s is the positive scale used for numerical optimization. Confusing these variances changes both fitting and bootstrap covariance.'],
53: ['The selected model’s reporting-scale annual MSE and MCPE are supplied by the common accepted bootstrap draws. Analytic g3 diagnostics remain informative but are not substituted for those joint moments.', BOUNDARY]
})

rewrite('docs/guidance/Technical notes/Note on Estimating the Sampling-Error Covariance Matrix (revised).docx', {
3: 'June 2026 • implementation updated October 2026 for wizard.5.14 (w5n)',
141: '12 Implementation workflow',
142: 'The following workflow summarizes the current production code; it is not a standalone executable listing.',
103: 'The package retains a nationally pooled correlation, estimated with the survey design and PSUs declared as first-stage units, and applies it to area-specific working variances without an additional household-overlap factor. This is a project implementation choice. Its adequacy depends on consistent PSU identifiers, survey design and the plausibility of a common correlation; it should be checked against design information and sensitivity results.',
105: 'Under a persistent cluster-effect model, reused PSUs can induce covariance even without re-interviewing the same households. Its magnitude and sign depend on the actual design and population; PSU reuse alone is not an empirical covariance estimate.',
143: 'The illustrative R workflow is: construct population_weight = weight × household size; declare the supplied PSU and optional strata design with survey::svydesign; compute arithmetic Direct means or FGT indicators by domain and year with survey::svyby; obtain cross-year design covariance from the joint design; and apply the selected area-variance and correlation policy. The production implementation is scripts/02_mfh.R. For log means, transform only after arithmetic aggregation: variance V/mean² and covariance C/(mean1 × mean2). Validate the assembled covariance matrices once before fitting, retain the repaired matrices, and use those exact inputs for every bootstrap simulation and refit.'
}, additions={
10: ['QER implementation scope. This note concerns covariance of Direct sampling errors, not MCPE of model prediction errors. The latter and annual MSE are estimated jointly by the final-estimator bootstrap described in the companion MSE note. ' + QUALIFY],
98: ['For log mean welfare, individual zero and negative welfare contributes to the arithmetic Direct mean; positive finite area means are required before logging. The delta transformation applies to the full covariance matrix. Any admissibility repair is performed once before the original MFH fit, recorded in mfh_sampling_covariance.csv and held fixed throughout the bootstrap. GVF and estimated correlation uncertainty are conditional inputs, not additional resampled components.']
})

rewrite('docs/guidance/Technical notes/FH_prediction_covariance_paper_with_annex_REVISED_section11_annexA.docx', {
518: 'For production, assess temporal and spatial dependence and the uncertainty added by estimating a richer covariance model. Use design-supported sampling covariances rather than automatically imposing independence. Missing-area prediction can borrow observed years through the partitioned predictor only when the covariance structure is credible and the chosen implementation supports it. Distinguish observed-area, temporally borrowed and synthetic predictions in reporting. The gains in this paper’s simulation are conditional on its design and are not a universal guarantee that MFH improves on UFH.'
}, additions={
2: ['Implementation scope for wizard.5.14 (w5n), October 2026. This paper develops working-covariance theory and reports its own Monte Carlo experiment. Its historical simulation numbers are not validation results for the current Dashboard bootstrap. The theoretical missing-area predictor below describes what a suitable implementation could calculate; it does not imply that every Dashboard path supports incomplete area-years. In particular, native emdi bc_sm does not return corrected log predictions for unsampled areas. ' + QUALIFY],
134: ['The experiment in this section is retained as evidence about covariance misspecification under its stated design. It should not be cited as a coverage certificate for the released implementation, its transformations, benchmarking or its current numerical optimizer. Those require the separate fitted-model validation recorded with the release.']
})
