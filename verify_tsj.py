import os
import json
import sys

PROJECT_ROOT = r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot"
TSJ_DIR = os.path.join(PROJECT_ROOT, "tsj")
TMJ_DIR = os.path.join(PROJECT_ROOT, "maps")
TILED_PROJ = os.path.join(PROJECT_ROOT, "maps", "backdrops", "levels.godot.tiled-project")

def verify_tsj():
    print("=== STARTING VERIFICATION FOR TSJ ISOLATION & PROJECT INTEGRITY (R3) ===")
    errors = []

    # 1. Verify tsj directory exists
    if not os.path.isdir(TSJ_DIR):
        errors.append(f"MISSING DIRECTORY: {TSJ_DIR}")
        print(f"FAIL: {TSJ_DIR} does not exist!")
        sys.exit(1)

    tsj_files = [f for f in os.listdir(TSJ_DIR) if f.endswith('.tsj')]
    print(f"PASS: Found {len(tsj_files)} .tsj files in res://tsj/")

    if len(tsj_files) == 0:
        errors.append("No .tsj files found in res://tsj/")

    # 2. Verify all TSJ JSON syntax and image paths
    missing_images = 0
    invalid_json = 0
    for tsj_name in tsj_files:
        tsj_path = os.path.join(TSJ_DIR, tsj_name)
        try:
            with open(tsj_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            errors.append(f"[tsj/{tsj_name}] Invalid JSON: {e}")
            invalid_json += 1
            continue

        images_to_check = []
        if "image" in data:
            images_to_check.append(data["image"])
        if "tiles" in data:
            for tile in data["tiles"]:
                if isinstance(tile, dict) and "image" in tile:
                    images_to_check.append(tile["image"])

        for img_ref in images_to_check:
            img_path = os.path.normpath(os.path.join(TSJ_DIR, img_ref))
            if not os.path.exists(img_path):
                errors.append(f"[tsj/{tsj_name}] Image '{img_ref}' missing at {img_path}")
                missing_images += 1

    if invalid_json == 0 and missing_images == 0:
        print(f"PASS: 100% of {len(tsj_files)} TSJ files parse cleanly and resolve image references in res://tsj/")

    # 3. Check for scattered TSJ files in active Godot root
    scattered = []
    for dirpath, dirnames, filenames in os.walk(PROJECT_ROOT):
        if dirpath.startswith(TSJ_DIR) or '.git' in dirpath or '.godot' in dirpath:
            continue
        for f in filenames:
            if f.endswith('.tsj'):
                scattered.append(os.path.relpath(os.path.join(dirpath, f), PROJECT_ROOT))

    if not scattered:
        print("PASS: 0 scattered .tsj files found outside res://tsj/")
    else:
        errors.append(f"Scattered .tsj files present: {scattered}")

    # 4. Verify TMJ map tileset references
    tmj_files = []
    for dirpath, dirnames, filenames in os.walk(TMJ_DIR):
        if '.git' in dirpath or '.godot' in dirpath:
            continue
        for f in filenames:
            if f.endswith('.tmj'):
                tmj_files.append(os.path.join(dirpath, f))

    broken_tmj_refs = 0
    total_tsj_refs = 0
    for tmj_path in tmj_files:
        rel_tmj = os.path.relpath(tmj_path, PROJECT_ROOT)
        try:
            with open(tmj_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            errors.append(f"[{rel_tmj}] Invalid JSON map: {e}")
            continue

        tilesets = data.get('tilesets', [])
        for ts in tilesets:
            src = ts.get('source')
            if src:
                total_tsj_refs += 1
                dir_tmj = os.path.dirname(tmj_path)
                target_tsj = os.path.normpath(os.path.join(dir_tmj, src))
                if not os.path.exists(target_tsj):
                    errors.append(f"[{rel_tmj}] Referenced TSJ '{src}' missing at {target_tsj}")
                    broken_tmj_refs += 1
                elif not target_tsj.startswith(TSJ_DIR):
                    errors.append(f"[{rel_tmj}] Referenced TSJ '{src}' resolves outside res://tsj/")
                    broken_tmj_refs += 1

    if broken_tmj_refs == 0:
        print(f"PASS: All {total_tsj_refs} TSJ references across {len(tmj_files)} TMJ maps resolve correctly inside res://tsj/")

    # 5. Verify Tiled project file configuration
    if not os.path.exists(TILED_PROJ):
        errors.append(f"MISSING TILED PROJECT FILE: {TILED_PROJ}")
    else:
        try:
            with open(TILED_PROJ, 'r', encoding='utf-8') as f:
                proj_data = json.load(f)
            folders = proj_data.get('folders', [])
            if "." in folders and "../../tsj" in folders:
                print("PASS: levels.godot.tiled-project folders correctly configured ('.' and '../../tsj')")
            else:
                errors.append(f"levels.godot.tiled-project folders invalid: {folders}")
        except Exception as e:
            errors.append(f"Failed to parse levels.godot.tiled-project: {e}")

    print("=========================================================")
    if errors:
        print(f"VERIFICATION FAILED WITH {len(errors)} ERROR(S):")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("VERIFICATION SUCCESSFUL: TSJ isolation and project integrity 100% verified!")
        sys.exit(0)

if __name__ == "__main__":
    verify_tsj()
