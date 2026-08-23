import os
import json
import glob
import sys

project_root = r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot"
tsj_dir = os.path.join(project_root, "tsj")
level1_dir = os.path.join(project_root, "maps", "backdrops", "level1")

print("=== STARTING INDEPENDENT REVIEWER 2 VERIFICATION ===")

# Check 1: Find all .tsj files in repository
all_tsj_files = []
for root, dirs, files in os.walk(project_root):
    # skip .git or build dirs if any, but search everywhere
    if ".git" in root or "build" in root:
        continue
    for f in files:
        if f.endswith(".tsj"):
            all_tsj_files.append(os.path.join(root, f))

print(f"Total .tsj files found in project tree: {len(all_tsj_files)}")
tsj_in_tsj_dir = [f for f in all_tsj_files if os.path.dirname(f).lower() == tsj_dir.lower()]
tsj_outside = [f for f in all_tsj_files if os.path.dirname(f).lower() != tsj_dir.lower()]

print(f"Total .tsj files in res://tsj/ ({tsj_dir}): {len(tsj_in_tsj_dir)}")
print(f"Total .tsj files outside res://tsj/: {len(tsj_outside)}")

if tsj_outside:
    print("ERROR: Scattered .tsj files found outside res://tsj/:")
    for f in tsj_outside:
        print("  -", f)

# Check 2: Verify JSON structure of all 244 .tsj files in res://tsj/
tsj_parse_errors = 0
image_refs = []
tsj_filenames = set()

for tsj_path in tsj_in_tsj_dir:
    filename = os.path.basename(tsj_path)
    tsj_filenames.add(filename)
    try:
        with open(tsj_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERROR parsing {tsj_path}: {e}")
        tsj_parse_errors += 1
        continue
    
    # Extract top-level image reference
    if "image" in data and data["image"]:
        image_refs.append((tsj_path, data["image"]))
    
    # Extract tile-level image references if any
    if "tiles" in data and isinstance(data["tiles"], list):
        for tile in data["tiles"]:
            if isinstance(tile, dict) and "image" in tile and tile["image"]:
                image_refs.append((tsj_path, tile["image"]))

print(f"JSON validation: {len(tsj_in_tsj_dir) - tsj_parse_errors}/{len(tsj_in_tsj_dir)} TSJ files parsed successfully.")
print(f"Total image references collected: {len(image_refs)}")

# Check 3: Verify all image references resolve cleanly in res://tsj/
missing_images = []
invalid_path_formats = []

for tsj_path, img_ref in image_refs:
    # Check if image path contains parent directory navigation or absolute paths
    if "/" in img_ref or "\\" in img_ref:
        # Check if it's not filename-only
        invalid_path_formats.append((tsj_path, img_ref))
    
    # Target path in res://tsj/
    target_img_path = os.path.join(tsj_dir, os.path.basename(img_ref))
    if not os.path.exists(target_img_path):
        missing_images.append((tsj_path, img_ref, target_img_path))

print(f"Image path format check: {len(invalid_path_formats)} image references contain subdirectories/relative paths.")
if invalid_path_formats:
    for tsj_path, img_ref in invalid_path_formats[:5]:
        print(f"  Non-standard path in {os.path.basename(tsj_path)}: '{img_ref}'")

print(f"Image existence check: {len(image_refs) - len(missing_images)}/{len(image_refs)} resolve to existing PNG files.")
if missing_images:
    print("ERROR: Missing image files:")
    for tsj, ref, target in missing_images:
        print(f"  In {os.path.basename(tsj)}: reference '{ref}' -> missing at '{target}'")

# Check 4: Check TMJ map files in maps/backdrops/level1/ and across project
tmj_files = []
for root, dirs, files in os.walk(project_root):
    if ".git" in root or "build" in root:
        continue
    for f in files:
        if f.endswith(".tmj"):
            tmj_files.append(os.path.join(root, f))

print(f"Total .tmj map files found: {len(tmj_files)}")

tmj_parse_errors = 0
tmj_sources_checked = 0
tmj_sources_failed = 0
tmj_canonicalization_issues = 0

for tmj_path in tmj_files:
    rel_tmj = os.path.relpath(tmj_path, project_root).replace("\\", "/")
    try:
        with open(tmj_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERROR parsing {tmj_path}: {e}")
        tmj_parse_errors += 1
        continue
    
    tilesets = data.get("tilesets", [])
    for ts in tilesets:
        source = ts.get("source")
        if not source:
            # embedded tileset
            continue
        tmj_sources_checked += 1
        
        # Test YATI path canonicalization
        # For a TMJ in maps/backdrops/level1/, base_dir is "res://maps/backdrops/level1"
        # source is "../../../tsj/<filename>.tsj"
        # In Godot / normalized posix path:
        # normpath("maps/backdrops/level1/" + source)
        combined_path = os.path.normpath(os.path.join(os.path.dirname(tmj_path), source))
        
        # Check canonicalization to tsj/
        expected_tsj_path = os.path.join(tsj_dir, os.path.basename(source))
        if os.path.normpath(combined_path).lower() != os.path.normpath(expected_tsj_path).lower():
            print(f"Canonicalization mismatch in {rel_tmj}: source '{source}' resolved to '{combined_path}', expected '{expected_tsj_path}'")
            tmj_canonicalization_issues += 1
            
        if not os.path.exists(combined_path):
            print(f"ERROR in {rel_tmj}: source '{source}' does not exist at '{combined_path}'")
            tmj_sources_failed += 1

print(f"TMJ map validation: {len(tmj_files) - tmj_parse_errors}/{len(tmj_files)} TMJ files parsed successfully.")
print(f"TMJ TSJ source references: {tmj_sources_checked} checked, {tmj_sources_failed} failed resolution, {tmj_canonicalization_issues} canonicalization issues.")

# Summary of Findings
print("\n=== SUMMARY OF INDEPENDENT VERIFICATION ===")
print(f"1. Scattered TSJs outside res://tsj/: {len(tsj_outside)}")
print(f"2. TSJ JSON parse errors: {tsj_parse_errors}")
print(f"3. Non-standard image path formats in TSJs: {len(invalid_path_formats)}")
print(f"4. Missing texture images referenced by TSJs: {len(missing_images)}")
print(f"5. TMJ JSON parse errors: {tmj_parse_errors}")
print(f"6. TMJ TSJ source resolution failures: {tmj_sources_failed}")
print(f"7. TMJ TSJ canonicalization issues: {tmj_canonicalization_issues}")
