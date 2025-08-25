
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse, re
import pandas as pd
import numpy as np

def parse_mib(val):
    if pd.isna(val):
        return np.nan
    if isinstance(val, (int, float)):
        return float(val)
    m = re.search(r"([\d\.]+)\s*MiB", str(val))
    if m:
        return float(m.group(1))
    try:
        return float(val)
    except:
        return np.nan

def parse_seconds(val):
    if pd.isna(val):
        return np.nan
    s = str(val).strip()
    m = re.search(r"([\d\.]+)", s)
    if m:
        try:
            return float(m.group(1))
        except:
            return np.nan
    return np.nan

def load_vtr_results(path):
    df = pd.read_csv(path, sep="\t", engine="python")
    df.columns = [c.strip() for c in df.columns]
    return df

def enrich(df):
    out = df.copy()
    # elapsed
    if "vtr_flow_elapsed_time" in out.columns:
        out["elapsed_s"] = out["vtr_flow_elapsed_time"].map(parse_seconds)
    else:
        cand = [c for c in out.columns if "elapsed" in c.lower() or "time" in c.lower()]
        out["elapsed_s"] = out[cand[0]].map(parse_seconds) if cand else np.nan

    # mem
    candm = [c for c in out.columns if "mem" in c.lower()]
    chosen = None
    for c in ["vtr_max_mem", "max_vpr_mem", "vtr_max_mem_stage"]:
        if c in out.columns:
            chosen = c
            break
    if chosen is None and candm:
        chosen = candm[0]
    out["peak_mem_mib"] = out[chosen].map(parse_mib) if chosen else np.nan

    # status
    status_col = None
    for c in ["vpr_status","status","flow_status"]:
        if c in out.columns:
            status_col = c; break
    if status_col is None:
        s = [c for c in out.columns if "status" in c.lower()]
        status_col = s[0] if s else None
    out["status_norm"] = out[status_col].astype(str).str.lower().str.replace(r"\s+"," ", regex=True) if status_col else np.nan

    keys = [k for k in ["arch","circuit","script_params"] if k in out.columns]
    out["__key__"] = out[keys].astype(str).agg("|".join, axis=1) if keys else out.index.astype(str)
    return out

def summarize(df):
    cols = [c for c in ["arch","circuit","script_params","status_norm","elapsed_s","peak_mem_mib"] if c in df.columns]
    return df[["__key__"] + cols].copy()

def compare(a, b):
    A = summarize(enrich(a)).add_suffix("_A")
    B = summarize(enrich(b)).add_suffix("_B")
    m = A.merge(B, left_on="__key___A", right_on="__key___B", how="outer")
    if "elapsed_s_A" in m.columns and "elapsed_s_B" in m.columns:
        m["delta_elapsed_s"] = m["elapsed_s_B"] - m["elapsed_s_A"]
    if "peak_mem_mib_A" in m.columns and "peak_mem_mib_B" in m.columns:
        m["delta_peak_mem_mib"] = m["peak_mem_mib_B"] - m["peak_mem_mib_A"]
    if "status_norm_A" in m.columns and "status_norm_B" in m.columns:
        m["status_change"] = (m["status_norm_A"].fillna("") != m["status_norm_B"].fillna(""))
    return m

def main():
    # parser = argparse.ArgumentParser(description="View and compare VTR results (TSV).")
    # parser.add_argument("file1", default='parse_results.txt', required=False,  help="Path to first results file (TSV)")
    # parser.add_argument("--file2", required=False, help="Optional second results file (TSV) for comparison")
    # parser.add_argument("--out", required=False, help="Write merged comparison CSV/TSV to this path")
    # args = parser.parse_args()
    file1 = 'parse_results.txt'
    df1 = load_vtr_results(file1)
    e1 = enrich(df1)
    print("\n=== Summary of file1 ===")
    print(summarize(e1).head(50).to_string(index=False))

    # if args.file2:
    #     df2 = load_vtr_results(args.file2)
    #     e2 = enrich(df2)
    #     merged = compare(e1, e2)
    #     print("\n=== Comparison (first 100 rows) ===")
    #     print(merged.head(100).to_string(index=False))
    #     if args.out:
    #         if args.out.lower().endswith(".tsv"):
    #             merged.to_csv(args.out, sep="\t", index=False)
    #         else:
    #             merged.to_csv(args.out, index=False)
    #         print(f"\nWrote comparison to: {args.out}")

if __name__ == "__main__":
    main()
