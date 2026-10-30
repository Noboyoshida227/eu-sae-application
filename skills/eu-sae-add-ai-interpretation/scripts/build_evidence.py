"""Aggregate exported results without inferring design/settings from equality."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import openpyxl
import pandas as pd


def stats(values):
    v = pd.Series(values, dtype=float)
    v = v[np.isfinite(v)]
    return {"n": len(v), **{k: (float(f(v)) if len(v) else None) for k, f in {
        "mean": np.mean, "median": np.median, "min": np.min, "max": np.max,
        "p25": lambda x: x.quantile(.25), "p75": lambda x: x.quantile(.75)}.items()}}


def numeric(df, column):
    if column not in df:
        return pd.Series(np.nan, index=df.index, dtype=float)
    raw = df[column]
    result = pd.to_numeric(raw, errors="coerce")
    if (raw.notna() & result.isna()).any():
        raise ValueError(f"Nonnumeric populated cells in {column}")
    return result.astype(float).replace([np.inf, -np.inf], np.nan)


def flags(series):
    def one(v):
        if pd.isna(v):
            return np.nan
        if isinstance(v, str):
            text = v.strip().lower()
            if text in ("true", "1"): return 1.0
            if text in ("false", "0"): return 0.0
        elif v in (True, False, 0, 1):
            return float(v)
        raise ValueError(f"Invalid significance flag: {v!r}")
    return series.map(one)


def key_check(df, keys):
    if any(k not in df for k in keys):
        raise ValueError(f"Required keys missing: {keys}")
    for k in keys:
        if df[k].isna().any() or df[k].astype(str).str.strip().eq("").any():
            raise ValueError(f"Missing {k} keys")
        if k != "year": df[k] = df[k].astype(str).str.strip()
    if df.duplicated(keys).any():
        raise ValueError(f"Duplicate keys: {keys}; matching is ambiguous")


def statuses(df):
    cols = [c for c in df if "inference_status" in c or c.endswith("fit_failed")]
    return {c: {str(k): int(v) for k, v in df[c].fillna("not_recorded").value_counts().items()}
            for c in cols} or {"status": "not_recorded"}


def evidence(path, indicator, unit, benchmark):
    if indicator == "poverty" and unit not in ("proportion", "percentage_point"):
        raise ValueError("Poverty requires verified proportion or percentage_point change units")
    if indicator == "mean_welfare" and unit not in ("percent", "currency", "log"):
        raise ValueError("Mean welfare requires verified percent, currency or log change units")
    wb = openpyxl.load_workbook(path, read_only=True, data_only=False)
    try:
        for sheet in ("Estimate comparison", "Statistical significance"):
            if sheet not in wb.sheetnames: raise ValueError(f"Missing sheet: {sheet}")
            if any(c.data_type == "f" for row in wb[sheet] for c in row):
                raise ValueError(f"Formula cells in {sheet}; supply a verified values-only export")
    finally:
        wb.close()
    frames = pd.read_excel(path, sheet_name=["Estimate comparison", "Statistical significance"],
                           dtype={"domain": str})
    cmp = frames["Estimate comparison"]
    sig = frames["Statistical significance"]
    key_check(cmp, ["domain", "year"])
    key_check(sig, ["domain", "method"])
    cmp["year"] = numeric(cmp, "year")
    if cmp.year.isna().any() or not cmp.year.mod(1).eq(0).all():
        raise ValueError("Invalid analysis years")
    key_check(cmp, ["domain", "year"])
    if cmp.year.nunique() != 2: raise ValueError("Expected exactly two analysis years")
    for c in ("Direct", "FH", "MFH", "Direct_MSE", "FH_MSE", "MFH_MSE"):
        if c not in cmp: raise ValueError(f"Missing required column {c}")
    for c in ("diff", "mse", "lb", "ub"):
        if c not in sig: raise ValueError(f"Missing change column {c}")
        sig[c] = numeric(sig, c)
    mult = 100 if unit == "proportion" else 1
    out = {"workbook_sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
           "settings": {"indicator": indicator, "raw_change_unit": unit,
                        "display_change_unit": "percentage_point" if unit == "proportion" else unit,
                        "benchmark": benchmark, "years": sorted(cmp.year.astype(int).unique().tolist()),
                        "settings_source": "operator verified from supplied report"},
           "notes": ["Marginal means are unweighted across domains; paired comparisons use shared finite rows.",
                     "Status counts are not validity certification; check diagnostics before interpreting precision."],
           "levels": [], "paired_levels": [], "benchmark_shifts": [], "changes": [],
           "paired_changes": [], "inference": statuses(cmp)}
    methods = ["Direct", "FH", "MFH"] + ([] if benchmark == "off" else ["FH_Bench", "MFH_Bench"])
    for year, d in cmp.groupby("year", sort=True):
        for m in methods:
            v, mse, cv = (numeric(d, m+s) for s in ("", "_MSE", "_CV"))
            out["levels"].append({"year": int(year), "method": m, "total": len(d),
                "level": stats(v), "mse": stats(mse.where(mse >= 0)),
                "rmse": stats(np.sqrt(mse.where(mse >= 0))), "cv": stats(cv.where(cv >= 0)),
                "below_zero": int((v < 0).sum()), "above_one": int((v > 1).sum()) if indicator == "poverty" else None,
                "zero_level": int(v.eq(0).sum()), "negative_mse": int((mse < 0).sum()),
                "absolute_deviation_from_Direct": stats((v-numeric(d, "Direct")).abs())})
        for scope, u, m in [("unbenchmarked", "FH", "MFH"), ("benchmarked", "FH_Bench", "MFH_Bench")]:
            if scope == "benchmarked" and benchmark == "off": continue
            a, b = numeric(d, u+"_MSE"), numeric(d, m+"_MSE")
            ok = a.notna() & b.notna() & a.ge(0) & b.ge(0) & numeric(d, u).notna() & numeric(d, m).notna()
            cu, cm = numeric(d, u+"_CV"), numeric(d, m+"_CV")
            cvok = ok & cu.ge(0) & cm.ge(0) & numeric(d, u).ne(0) & numeric(d, m).ne(0)
            out["paired_levels"].append({"year": int(year), "scope": scope, "eligible": int(ok.sum()),
                "excluded": int((~ok).sum()), "UFH_mse": stats(a[ok]), "MFH_mse": stats(b[ok]),
                "UFH_rmse": stats(np.sqrt(a[ok])), "MFH_rmse": stats(np.sqrt(b[ok])),
                "UFH_cv": stats(cu[cvok]), "MFH_cv": stats(cm[cvok]),
                "MFH_to_UFH_mse_ratio": stats(b[ok & a.gt(0)] / a[ok & a.gt(0)]),
                "MFH_mse_higher": int((b[ok] > a[ok]).sum())})
        if benchmark != "off":
            for m in ("FH", "MFH"):
                a, b = numeric(d, m), numeric(d, m+"_Bench")
                mask = a.notna() & b.notna()
                out["benchmark_shifts"].append({"year": int(year), "method": m,
                    "signed": stats((b-a)[mask]), "absolute": stats((b-a)[mask].abs()),
                    "factor": stats(b[mask & a.ne(0)] / a[mask & a.ne(0)])})
    fs = ["significant_unadjusted", "significant_bh", "significant_bonferroni"]
    for f in fs:
        sig[f] = flags(sig[f]) if f in sig else np.nan
        sig["reported_"+f] = sig[f]
    # Retain exported counts for report matching, but never treat unusable joint
    # inference as tested merely because an exported flag happens to be present.
    invalid = sig[["diff", "mse", "lb", "ub"]].isna().any(axis=1) | sig.mse.lt(0) | sig.ub.lt(sig.lb)
    for c in ("inference_status", "joint_moment_status"):
        if c in sig:
            invalid |= sig[c].fillna("").astype(str).str.contains("invalid|unavailable|failed", case=False)
    global_bad = any(cmp[c].fillna("").astype(str).str.contains("invalid|unavailable|failed", case=False).any()
                     for c in ("MFH_inference_status",) if c in cmp)
    if global_bad: invalid |= sig.method.str.startswith("MFH")
    sig["invalid_inference"] = invalid
    sig.loc[invalid, fs] = np.nan
    sig.loc[invalid, ["mse", "lb", "ub"]] = np.nan
    if benchmark == "off": sig = sig[~sig.method.str.contains("Benchmarked", case=False)].copy()
    for method, d in sig.groupby("method", sort=True):
        width = (d.ub-d.lb).where(d.ub >= d.lb) * mult
        out["changes"].append({"method": method, "total": len(d),
            "invalid_inference": int(d.invalid_inference.sum()),
            "reported_flags": {f: {"tested": int(d["reported_"+f].notna().sum()),
                "significant": int(d["reported_"+f].sum()) if d["reported_"+f].notna().any() else None} for f in fs},
            "flags": {
            f: {"tested": int(d[f].notna().sum()), "significant": int(d[f].sum()) if d[f].notna().any() else None,
                "untested": int(d[f].isna().sum())} for f in fs},
            "change": stats(d["diff"]*mult), "absolute_change": stats(d["diff"].abs()*mult),
            "mse": stats(d.mse.where(d.mse >= 0)*mult**2), "width": stats(width), "inference": statuses(d)})
    for suffix in ("", " Benchmarked"):
        a, b = (sig[sig.method == m+suffix].set_index("domain") for m in ("FH", "MFH"))
        if a.empty or b.empty: continue
        j = a.join(b, how="inner", lsuffix="_u", rsuffix="_m", validate="one_to_one")
        wu, wm = (j.ub_u-j.lb_u)*mult, (j.ub_m-j.lb_m)*mult
        ok = wu.notna() & wm.notna() & wu.ge(0) & wm.ge(0)
        su, sm = j.significant_unadjusted_u, j.significant_unadjusted_m
        tested = su.notna() & sm.notna()
        out["paired_changes"].append({"scope": "benchmarked" if suffix else "unbenchmarked",
            "matched": len(j), "UFH_unmatched": len(a)-len(j), "MFH_unmatched": len(b)-len(j),
            "UFH_width": stats(wu[ok]), "MFH_width": stats(wm[ok]),
            "MFH_narrower": int((wm[ok] < wu[ok]).sum()), "MFH_wider": int((wm[ok] > wu[ok]).sum()),
            "width_reduction_percent": stats(100*(1-wm[ok & wu.gt(0)]/wu[ok & wu.gt(0)])),
            "jointly_tested": int(tested.sum()), "both_significant": int((tested & su.eq(1) & sm.eq(1)).sum()),
            "UFH_only": int((tested & su.eq(1) & sm.eq(0)).sum()),
            "MFH_only": int((tested & su.eq(0) & sm.eq(1)).sum()),
            "agreement": int((tested & su.eq(sm)).sum())})
    return out


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("workbook"); p.add_argument("output")
    p.add_argument("--indicator", required=True, choices=["poverty", "mean_welfare"])
    p.add_argument("--change-unit", required=True, choices=["proportion", "percentage_point", "percent", "currency", "log"])
    p.add_argument("--benchmark", required=True, choices=["on", "off", "unknown"])
    args = p.parse_args()
    if Path(args.output).exists(): p.error("Output exists; choose a new evidence path")
    result = evidence(args.workbook, args.indicator, args.change_unit, args.benchmark)
    Path(args.output).write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
