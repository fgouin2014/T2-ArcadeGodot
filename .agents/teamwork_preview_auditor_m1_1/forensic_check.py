import os
import sys
import json
from pathlib import Path

# Ensure UTF-8 output encoding for Windows stdout
if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

PROJECT_ROOT = Path(r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot").resolve()
TSJ_DIR = PROJECT_ROOT / "tsj"
MAPS_DIR = PROJECT_ROOT / "maps"

def main():
    print("=== FORENSIC INTEGRITY AUDIT — MILESTONE 1 ===")
    violations = []
    observations = []

    # -------------------------------------------------------------
    # CHECK 1: TSJ File Location Audit (Zero TSJ outside res://tsj/)
    # -------------------------------------------------------------
    print("\n--- Check 1: Scanning for .tsj files outside res://tsj/ ---")
    tsj_outside = []
    all_tsj_in_tsj_dir = []
    
    ignore_dirs = {".git", ".godot", ".agents", "export", "app", "java_pid"}
    
    for root, dirs, files in os.walk(PROJECT_ROOT):
        dirs[:] = [d for d in dirs if d not in ignore_dirs]
        rel_root = os.path.relpath(root, PROJECT_ROOT)
        
        for file in files:
            if file.endswith(".tsj"):
                full_path = Path(root) / file
                if rel_root == "tsj" or rel_root.startswith("tsj" + os.sep):
                    all_tsj_in_tsj_dir.append(full_path)
                else:
                    tsj_outside.append(full_path)

    print(f"Total .tsj files inside res://tsj/: {len(all_tsj_in_tsj_dir)}")
    print(f"Total .tsj files outside res://tsj/: {len(tsj_outside)}")

    if tsj_outside:
        msg = f"FOUND {len(tsj_outside)} .tsj files outside res://tsj/: {[str(p) for p in tsj_outside]}"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    else:
        obs = f"PASS: Zero .tsj files found outside res://tsj/. Exactly {len(all_tsj_in_tsj_dir)} .tsj files exist in res://tsj/."
        observations.append(obs)
        print(f"[OK] {obs}")

    # -------------------------------------------------------------
    # CHECK 2: Authenticity & Validity of .tsj files in res://tsj/
    # -------------------------------------------------------------
    print("\n--- Check 2: Verifying authenticity and JSON schema of .tsj files in res://tsj/ ---")
    corrupt_tsj = []
    fake_tsj = []
    missing_images = []
    total_images_checked = 0

    for tsj_file in all_tsj_in_tsj_dir:
        try:
            with open(tsj_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Check basic Tiled tileset schema
            if not isinstance(data, dict):
                corrupt_tsj.append((tsj_file.name, "JSON root is not an object"))
                continue
            
            ts_type = data.get("type")
            if ts_type != "tileset":
                if "tilewidth" not in data and "tileheight" not in data and "name" not in data:
                    fake_tsj.append((tsj_file.name, "Missing standard tileset properties (type, tilewidth, tileheight, name)"))
            
            # Check images
            images_to_check = []
            if "image" in data and data["image"]:
                images_to_check.append(data["image"])
            if "tiles" in data and isinstance(data["tiles"], list):
                for t in data["tiles"]:
                    if isinstance(t, dict) and "image" in t and t["image"]:
                        images_to_check.append(t["image"])
            
            for img in images_to_check:
                total_images_checked += 1
                img_path = TSJ_DIR / img
                if not img_path.exists():
                    missing_images.append((tsj_file.name, img, str(img_path)))

        except Exception as e:
            corrupt_tsj.append((tsj_file.name, str(e)))

    print(f"Checked {len(all_tsj_in_tsj_dir)} TSJ files.")
    print(f"Checked {total_images_checked} image references across TSJ files.")
    
    if corrupt_tsj:
        msg = f"Corrupt/Invalid JSON TSJ files ({len(corrupt_tsj)}): {corrupt_tsj[:5]}"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    elif fake_tsj:
        msg = f"Fake/Non-tileset TSJ files ({len(fake_tsj)}): {fake_tsj[:5]}"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    elif missing_images:
        msg = f"Missing TSJ Image References ({len(missing_images)}): {missing_images[:5]}"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    else:
        obs = f"PASS: All {len(all_tsj_in_tsj_dir)} .tsj files are authentic Tiled tilesets with valid JSON. All {total_images_checked} PNG image references exist in res://tsj/."
        observations.append(obs)
        print(f"[OK] {obs}")

    # -------------------------------------------------------------
    # CHECK 3: TMJ Map Source Reference Audit
    # -------------------------------------------------------------
    print("\n--- Check 3: Verifying TMJ source references ---")
    tmj_files = []
    for root, dirs, files in os.walk(MAPS_DIR):
        for file in files:
            if file.endswith(".tmj"):
                tmj_files.append(Path(root) / file)

    print(f"Found {len(tmj_files)} .tmj map files under maps/")
    tmj_errors = []
    total_tsj_refs = 0

    for tmj_file in tmj_files:
        try:
            with open(tmj_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            tilesets = data.get("tilesets", [])
            for ts in tilesets:
                source = ts.get("source")
                if source:
                    total_tsj_refs += 1
                    target_path = (tmj_file.parent / source).resolve()
                    if not target_path.exists():
                        tmj_errors.append((tmj_file.name, source, f"File does not exist: {target_path}"))
                    elif not str(target_path).startswith(str(TSJ_DIR)):
                        tmj_errors.append((tmj_file.name, source, f"Resolved outside res://tsj/: {target_path}"))
                    
                    rel_to_tmj = os.path.relpath(target_path, tmj_file.parent).replace("\\", "/")
                    if source != rel_to_tmj:
                        tmj_errors.append((tmj_file.name, source, f"Source path '{source}' does not match expected relative path '{rel_to_tmj}'"))

        except Exception as e:
            tmj_errors.append((tmj_file.name, "N/A", str(e)))

    print(f"Checked {len(tmj_files)} TMJ files and {total_tsj_refs} TSJ references.")

    if tmj_errors:
        msg = f"TMJ Source Reference Errors ({len(tmj_errors)}): {tmj_errors}"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    else:
        obs = f"PASS: All {total_tsj_refs} tileset source references across {len(tmj_files)} .tmj files correctly resolve to valid .tsj files inside res://tsj/ using canonical relative paths."
        observations.append(obs)
        print(f"[OK] {obs}")

    # -------------------------------------------------------------
    # CHECK 4: Tiled Project Configuration Audit
    # -------------------------------------------------------------
    print("\n--- Check 4: Verifying Tiled project configuration ---")
    tiled_proj_file = MAPS_DIR / "backdrops" / "levels.godot.tiled-project"
    if not tiled_proj_file.exists():
        tiled_proj_file = MAPS_DIR / "backdrops" / "levels.tiled-project"

    if not tiled_proj_file.exists():
        msg = "Tiled project file not found in maps/backdrops/"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    else:
        try:
            with open(tiled_proj_file, 'r', encoding='utf-8') as f:
                proj_data = json.load(f)
            
            folders = proj_data.get("folders", [])
            print(f"Tiled project ({tiled_proj_file.name}) folders: {folders}")
            
            if "../../tsj" not in folders and "../tsj" not in folders:
                msg = f"Tiled project '{tiled_proj_file.name}' folders does not contain TSJ directory: {folders}"
                violations.append(msg)
                print(f"[FAIL] {msg}")
            else:
                obs = f"PASS: Tiled project configuration '{tiled_proj_file.name}' correctly includes TSJ directory in folders: {folders}."
                observations.append(obs)
                print(f"[OK] {obs}")
        except Exception as e:
            msg = f"Failed to parse Tiled project file '{tiled_proj_file.name}': {e}"
            violations.append(msg)
            print(f"[FAIL] {msg}")

    # -------------------------------------------------------------
    # CHECK 5: Code Audit for Hardcoded Bypasses or Fake Verification
    # -------------------------------------------------------------
    print("\n--- Check 5: Code Audit for Hardcoded Bypasses or Fake Verification ---")
    worker_agent_dir = PROJECT_ROOT / ".agents" / "teamwork_preview_worker_m1_1"
    bypasses = []

    if worker_agent_dir.exists():
        for file in os.listdir(worker_agent_dir):
            if file.endswith(".py"):
                py_path = worker_agent_dir / file
                with open(py_path, 'r', encoding='utf-8') as f:
                    code_text = f.read()
                    if "return True # fake" in code_text or "mock" in code_text.lower() and "import mock" not in code_text:
                        bypasses.append(f"Suspicious construct in {file}")

    if bypasses:
        msg = f"Potential hardcoded bypasses found: {bypasses}"
        violations.append(msg)
        print(f"[FAIL] {msg}")
    else:
        obs = "PASS: No hardcoded bypasses or fake verification scripts detected in Worker 1 code."
        observations.append(obs)
        print(f"[OK] {obs}")

    # -------------------------------------------------------------
    # FINAL VERDICT
    # -------------------------------------------------------------
    print("\n=============================================================")
    if violations:
        print("FINAL VERDICT: INTEGRITY VIOLATION")
        print("Violations:")
        for v in violations:
            print(f"- {v}")
        sys.exit(1)
    else:
        print("FINAL VERDICT: CLEAN")
        print("Observations:")
        for o in observations:
            print(f"- {o}")
        sys.exit(0)

if __name__ == "__main__":
    main()
