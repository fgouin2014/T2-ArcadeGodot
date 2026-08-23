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
        
        # Check PNG Magic Bytes: 89 50 4E 47 0D 0A 1A 0A
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return False, f"Invalid PNG magic bytes: {header[:8].hex()}", None
        
        # Check IHDR Chunk Name (bytes 12..16)
        if header[12:16] != b"IHDR":
            return False, f"First chunk is not IHDR: {header[12:16]}", None
        
        width, height = struct.unpack(">II", header[16:24])
        return True, "Valid PNG", (width, height)
    except Exception as e:
        return False, f"Exception reading PNG: {e}", None


def run_tests():
    log("==================================================")
    log("MILESTONE 1 IMPORTER & ASSET STRESS TEST REPORT")
    log("==================================================")

    # Step 1: Scan all TMJ and TSJ files
    all_tmj = list(WORKSPACE.rglob("*.tmj"))
    all_tsj = list(WORKSPACE.rglob("*.tsj"))

    log(f"\n1. FOUND FILES:")
    log(f"   Total .tmj files found in workspace: {len(all_tmj)}")
    log(f"   Total .tsj files found in workspace: {len(all_tsj)}")

    # Group by location
    godot_tmj = [f for f in all_tmj if GODOT_ROOT in f.parents or f.parent == GODOT_ROOT]
    godot_tsj = [f for f in all_tsj if GODOT_ROOT in f.parents or f.parent == GODOT_ROOT]
    log(f"   Godot Project .tmj files: {len(godot_tmj)}")
    log(f"   Godot Project .tsj files: {len(godot_tsj)}")

    # Parse all TSJ files first to build a registry
    log("\n==================================================")
    log("2. TESTING EVERY TSJ FILE (TILED TILESETS)")
    log("==================================================")

    tsj_issues = []
    tsj_data_registry = {} # path -> json data

    for tsj_path in all_tsj:
        rel_path = tsj_path.relative_to(WORKSPACE)
        try:
            with open(tsj_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            tsj_data_registry[str(tsj_path.resolve()).lower()] = (tsj_path, data)
        except Exception as e:
            tsj_issues.append((rel_path, f"JSON Parse Error: {e}"))
            log(f"[FAIL] TSJ Parse Error: {rel_path} -> {e}")
            continue

        # Check required fields for TSJ
        t_type = data.get("type", "")
        tilewidth = data.get("tilewidth")
        tileheight = data.get("tileheight")
        tilecount = data.get("tilecount", 0)

        # Image check
        top_image = data.get("image")
        if top_image:
            img_path = (tsj_path.parent / top_image).resolve()
            valid, msg, dims = verify_png(img_path)
            if not valid:
                tsj_issues.append((rel_path, f"Top image broken '{top_image}': {msg}"))
                log(f"[FAIL] TSJ Top Image broken in {rel_path}: '{top_image}' -> {msg}")
            else:
                expected_w = data.get("imagewidth")
                expected_h = data.get("imageheight")
                if expected_w and expected_h and dims:
                    if dims[0] != expected_w or dims[1] != expected_h:
                        tsj_issues.append((rel_path, f"Image dims mismatch for '{top_image}': expected ({expected_w}x{expected_h}), disk ({dims[0]}x{dims[1]})"))
                        log(f"[WARN] TSJ Image dims mismatch in {rel_path}: expected ({expected_w}x{expected_h}), actual {dims}")

        # Collection of images check
        tiles = data.get("tiles", [])
        for tile in tiles:
            tile_id = tile.get("id")
            t_img = tile.get("image")
            if t_img:
                img_path = (tsj_path.parent / t_img).resolve()
                valid, msg, dims = verify_png(img_path)
                if not valid:
                    tsj_issues.append((rel_path, f"Tile {tile_id} image broken '{t_img}': {msg}"))
                    log(f"[FAIL] TSJ Tile {tile_id} Image broken in {rel_path}: '{t_img}' -> {msg}")
                else:
                    exp_w = tile.get("imagewidth")
                    exp_h = tile.get("imageheight")
                    if exp_w and exp_h and dims:
                        if dims[0] != exp_w or dims[1] != exp_h:
                            tsj_issues.append((rel_path, f"Tile {tile_id} dims mismatch: expected ({exp_w}x{exp_h}), disk ({dims[0]}x{dims[1]})"))

    log(f"Processed {len(all_tsj)} TSJ files. Total issues found: {len(tsj_issues)}")

    # Parse all TMJ files
    log("\n==================================================")
    log("3. TESTING EVERY TMJ FILE (TILED MAPS)")
    log("==================================================")

    tmj_issues = []

    for tmj_path in all_tmj:
        rel_path = tmj_path.relative_to(WORKSPACE)
        try:
            with open(tmj_path, "r", encoding="utf-8") as f:
                map_data = json.load(f)
        except Exception as e:
            tmj_issues.append((rel_path, f"JSON Parse Error: {e}"))
            log(f"[FAIL] TMJ Parse Error: {rel_path} -> {e}")
            continue

        # Check tilesets in map
        tilesets = map_data.get("tilesets", [])
        max_gid_map = 0

        gid_ranges = [] # list of (firstgid, lastgid, tileset_name, source_path, tilecount)

        for ts in tilesets:
            firstgid = ts.get("firstgid", 0)
            source = ts.get("source")

            if source:
                # External tileset reference
                ts_target = (tmj_path.parent / source).resolve()
                if not ts_target.exists():
                    tmj_issues.append((rel_path, f"Missing tileset reference '{source}' (resolved to {ts_target})"))
                    log(f"[FAIL] TMJ {rel_path}: Missing tileset reference '{source}'")
                    tilecount = 0
                else:
                    # Load tileset to get tilecount
                    try:
                        with open(ts_target, "r", encoding="utf-8") as ts_file:
                            ts_json = json.load(ts_file)
                        tilecount = ts_json.get("tilecount", 0)
                    except Exception as e:
                        tmj_issues.append((rel_path, f"Cannot parse tileset '{source}': {e}"))
                        tilecount = 0
            else:
                # Embedded tileset
                tilecount = ts.get("tilecount", 0)

            lastgid = firstgid + tilecount - 1 if tilecount > 0 else firstgid
            gid_ranges.append((firstgid, lastgid, source or ts.get("name", "embedded"), tilecount))

        # Sort GID ranges
        gid_ranges.sort(key=lambda x: x[0])

        # Validate layers and tile GIDs
        layers = map_data.get("layers", [])
        for layer in layers:
            l_name = layer.get("name", "<unnamed>")
            l_type = layer.get("type", "")

            if l_type == "tilelayer":
                data_gids = layer.get("data", [])
                for idx, raw_gid in enumerate(data_gids):
                    if raw_gid == 0:
                        continue # Empty tile
                    # Strip flip flags (bits 32, 31, 30, 29)
                    clean_gid = raw_gid & 0x1FFFFFFF
                    
                    # Check if clean_gid falls within any tileset range
                    match_ts = [r for r in gid_ranges if r[0] <= clean_gid <= r[1]]
                    if not match_ts and clean_gid > 0:
                        tmj_issues.append((rel_path, f"Layer '{l_name}' has invalid/orphan tile GID {clean_gid} (raw: {raw_gid}) at index {idx}"))
                        log(f"[FAIL] TMJ {rel_path}: Layer '{l_name}' orphan GID {clean_gid} (raw {raw_gid})")

            elif l_type == "objectgroup":
                objects = layer.get("objects", [])
                for obj in objects:
                    obj_id = obj.get("id")
                    obj_gid = obj.get("gid")
                    if obj_gid is not None and obj_gid > 0:
                        clean_gid = obj_gid & 0x1FFFFFFF
                        match_ts = [r for r in gid_ranges if r[0] <= clean_gid <= r[1]]
                        if not match_ts:
                            tmj_issues.append((rel_path, f"Object layer '{l_name}' obj {obj_id} has invalid/orphan GID {clean_gid}"))
                            log(f"[FAIL] TMJ {rel_path}: Obj layer '{l_name}' obj {obj_id} orphan GID {clean_gid}")

    log(f"Processed {len(all_tmj)} TMJ files. Total issues found: {len(tmj_issues)}")

    # Step 4: Verify image assets co-located in res://tsj/
    log("\n==================================================")
    log("4. TESTING CO-LOCATED IMAGES IN res://tsj/")
    log("==================================================")

    tsj_pngs = list(TSJ_DIR.glob("*.png"))
    log(f"Found {len(tsj_pngs)} PNG files in {TSJ_DIR}")

    png_issues = []
    for png_path in tsj_pngs:
        rel_p = png_path.relative_to(WORKSPACE)
        valid, msg, dims = verify_png(png_path)
        if not valid:
            png_issues.append((rel_p, msg))
            log(f"[FAIL] PNG Corrupted/Invalid: {rel_p} -> {msg}")
        else:
            # Check for non-standard or unusual dimensions
            w, h = dims
            if w <= 0 or h <= 0:
                png_issues.append((rel_p, f"Zero or negative dimensions ({w}x{h})"))
                log(f"[FAIL] PNG Invalid Dims: {rel_p} -> ({w}x{h})")

    log(f"Processed {len(tsj_pngs)} PNG files in res://tsj/. Total issues: {len(png_issues)}")

    # Step 5: Check edge case paths and YATI compatibility
    log("\n==================================================")
    log("5. CHECKING EDGE CASE PATHS & YATI COMPATIBILITY")
    log("==================================================")

    path_issues = []
    # Check all TSJ and TMJ file paths referenced inside Godot project maps
    godot_level1_tmj = list((MAPS_DIR / "backdrops" / "level1").glob("*.tmj"))
    for tmj_path in godot_level1_tmj:
        rel_p = tmj_path.relative_to(WORKSPACE)
        with open(tmj_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        
        for ts in data.get("tilesets", []):
            src = ts.get("source", "")
            if src:
                # Check for backslash usages
                if "\\" in src:
                    path_issues.append((rel_p, f"Tileset source contains backslashes: '{src}'"))
                    log(f"[WARN] TMJ {rel_p}: Tileset source has backslash: '{src}'")
                
                # Check if file exists
                target = (tmj_path.parent / src).resolve()
                if not target.exists():
                    path_issues.append((rel_p, f"Broken tileset link: '{src}'"))
                    log(f"[FAIL] TMJ {rel_p}: Broken tileset link '{src}'")

    log("\n==================================================")
    log("SUMMARY OF ALL ISSUES FOUND")
    log("==================================================")
    log(f"TSJ Issues: {len(tsj_issues)}")
    log(f"TMJ Issues: {len(tmj_issues)}")
    log(f"res://tsj PNG Issues: {len(png_issues)}")
    log(f"Path/Compatibility Issues: {len(path_issues)}")

    report_content = "\n".join(report_lines)
    output_path = GODOT_ROOT / ".agents" / "teamwork_preview_challenger_m1_1" / "test_results.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(report_content)
    print(f"\nSaved full output to {output_path}")

if __name__ == "__main__":
    run_tests()
