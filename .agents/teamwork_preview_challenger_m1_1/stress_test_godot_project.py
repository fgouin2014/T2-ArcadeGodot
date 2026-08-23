import os
import sys
import json
import struct
from pathlib import Path

WORKSPACE = Path(r"c:\androidProject\lastchance")
GODOT_ROOT = WORKSPACE / "DukeSoundboard" / "T2-ArcadeGodot"
TSJ_DIR = GODOT_ROOT / "tsj"
MAPS_DIR = GODOT_ROOT / "maps"

report_lines = []

def log(msg):
    print(msg)
    report_lines.append(msg)

def verify_png(file_path):
    """Verifies PNG header, readability, and extracts dimensions without external libraries."""
    if not file_path.exists():
        return False, f"File does not exist: {file_path}", None
    
    if file_path.stat().st_size < 24:
        return False, f"File size too small ({file_path.stat().st_size} bytes)", None

    try:
        with open(file_path, "rb") as f:
            header = f.read(24)
        
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return False, f"Invalid PNG magic bytes: {header[:8].hex()}", None
        
        if header[12:16] != b"IHDR":
            return False, f"First chunk is not IHDR: {header[12:16]}", None
        
        width, height = struct.unpack(">II", header[16:24])
        return True, "Valid PNG", (width, height)
    except Exception as e:
        return False, f"Exception reading PNG: {e}", None

def run_tests():
    log("==================================================")
    log("GODOT 4 PROJECT (T2-ArcadeGodot) SPECIFIC AUDIT")
    log("==================================================")

    godot_tmjs = list(MAPS_DIR.rglob("*.tmj"))
    godot_tsjs = list(TSJ_DIR.rglob("*.tsj"))
    godot_pngs = list(TSJ_DIR.rglob("*.png"))

    log(f"Godot active TMJ maps: {len(godot_tmjs)}")
    log(f"Godot active TSJ tilesets: {len(godot_tsjs)}")
    log(f"Godot co-located PNG assets in res://tsj/: {len(godot_pngs)}")

    # Audit Godot TMJ Maps
    log("\n--- 1. AUDITING GODOT TMJ MAP TILESET REFERENCES ---")
    tmj_ref_errors = []
    tmj_path_warnings = []
    gid_errors = []

    for tmj_path in sorted(godot_tmjs):
        rel_p = tmj_path.relative_to(GODOT_ROOT)
        with open(tmj_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        tilesets = data.get("tilesets", [])
        log(f"\nMap: res://{rel_p.as_posix()} (contains {len(tilesets)} tileset refs)")

        gid_ranges = []
        for ts in tilesets:
            firstgid = ts.get("firstgid", 0)
            source = ts.get("source", "")
            name = ts.get("name", "")

            if source:
                target = (tmj_path.parent / source).resolve()
                if not target.exists():
                    msg = f"MISSING TSJ: '{source}' -> {target}"
                    tmj_ref_errors.append((rel_p, source, msg))
                    log(f"  ❌ [{firstgid}] source='{source}' -> BROKEN (File not found!)")
                    tcount = 0
                else:
                    log(f"  ✅ [{firstgid}] source='{source}' -> OK")
                    try:
                        with open(target, "r", encoding="utf-8") as tsf:
                            tsdata = json.load(tsf)
                        tcount = tsdata.get("tilecount", 0)
                    except Exception:
                        tcount = 0
            else:
                log(f"  ℹ️ [{firstgid}] Embedded tileset '{name}'")
                tcount = ts.get("tilecount", 0)

            lastgid = firstgid + tcount - 1 if tcount > 0 else firstgid
            gid_ranges.append((firstgid, lastgid, source or name, tcount))

        # Check GID references in layers
        gid_ranges.sort(key=lambda x: x[0])
        for layer in data.get("layers", []):
            l_name = layer.get("name", "")
            l_type = layer.get("type", "")
            if l_type == "tilelayer":
                for idx, r_gid in enumerate(layer.get("data", [])):
                    if r_gid == 0: continue
                    clean_gid = r_gid & 0x1FFFFFFF
                    if not any(r[0] <= clean_gid <= r[1] for r in gid_ranges if r[3] > 0):
                        gid_errors.append((rel_p, l_name, clean_gid, r_gid))
                        log(f"  ❌ Orphan GID {clean_gid} (raw {r_gid}) in layer '{l_name}'")

    # Audit Godot TSJ Tilesets & Image references
    log("\n--- 2. AUDITING GODOT TSJ TILESETS & IMAGE REFERENCES ---")
    tsj_img_missing = []
    tsj_dim_mismatches = []
    tsj_rel_path_issues = []

    for tsj_path in sorted(godot_tsjs):
        rel_p = tsj_path.relative_to(GODOT_ROOT)
        with open(tsj_path, "r", encoding="utf-8") as f:
            tsdata = json.load(f)

        top_img = tsdata.get("image")
        if top_img:
            # Check for path prefix anomalies (e.g. starting with ../ or absolute or backslashes)
            if "\\" in top_img:
                tsj_rel_path_issues.append((rel_p, f"Backslash in image path: '{top_img}'"))

            img_file = (tsj_path.parent / top_img).resolve()
            valid, msg, dims = verify_png(img_file)
            if not valid:
                tsj_img_missing.append((rel_p, top_img, msg))
                log(f"  ❌ TSJ res://{rel_p.as_posix()}: Image '{top_img}' BROKEN ({msg})")
            else:
                exp_w = tsdata.get("imagewidth")
                exp_h = tsdata.get("imageheight")
                if exp_w and exp_h and dims:
                    if dims[0] != exp_w or dims[1] != exp_h:
                        tsj_dim_mismatches.append((rel_p, top_img, (exp_w, exp_h), dims))
                        log(f"  ⚠️ TSJ res://{rel_p.as_posix()}: Image '{top_img}' Dims TSJ=({exp_w}x{exp_h}) vs PNG=({dims[0]}x{dims[1]})")

        # Collection tiles
        for tile in tsdata.get("tiles", []):
            t_id = tile.get("id")
            t_img = tile.get("image")
            if t_img:
                img_file = (tsj_path.parent / t_img).resolve()
                valid, msg, dims = verify_png(img_file)
                if not valid:
                    tsj_img_missing.append((rel_p, f"Tile {t_id}: {t_img}", msg))
                    log(f"  ❌ TSJ res://{rel_p.as_posix()} Tile {t_id}: Image '{t_img}' BROKEN ({msg})")

    # Audit PNG Assets in res://tsj/
    log("\n--- 3. AUDITING PNG ASSET INTEGRITY IN res://tsj/ ---")
    png_corruptions = []
    for png_path in godot_pngs:
        rel_p = png_path.relative_to(GODOT_ROOT)
        valid, msg, dims = verify_png(png_path)
        if not valid:
            png_corruptions.append((rel_p, msg))
            log(f"  ❌ PNG res://{rel_p.as_posix()} CORRUPTED: {msg}")

    log("\n==================================================")
    log("GODOT 4 PROJECT AUDIT SUMMARY")
    log("==================================================")
    log(f"TMJ Missing TSJ References: {len(tmj_ref_errors)}")
    log(f"TMJ Layer Orphan GIDs: {len(gid_errors)}")
    log(f"TSJ Broken Image References: {len(tsj_img_missing)}")
    log(f"TSJ Image Dimension Mismatches: {len(tsj_dim_mismatches)}")
    log(f"TSJ Path Anomaly Warnings: {len(tsj_rel_path_issues)}")
    log(f"res://tsj/ Corrupted PNGs: {len(png_corruptions)}")

    output_path = GODOT_ROOT / ".agents" / "teamwork_preview_challenger_m1_1" / "godot_audit_summary.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(report_lines))
    print(f"\nWrote summary to {output_path}")

if __name__ == "__main__":
    run_tests()
