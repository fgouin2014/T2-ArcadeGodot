import os
import json

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
TSJ_DIR = os.path.join(ROOT, 'tsj')
TMJ_DIR = os.path.join(ROOT, r'maps\backdrops\level1')

errors = []
warnings = []

print("=== VERIFICATION TEST 1: Explorer 1 Path Resolution Test ===")
test_tsj = 'test_enemies_collection.tsj'
rel_path = os.path.relpath(os.path.join(TSJ_DIR, test_tsj), TMJ_DIR).replace('\\', '/')
expected_rel = "../../../tsj/test_enemies_collection.tsj"
if rel_path == expected_rel:
    print(f"PASS: Calculated relative path matches expected: '{rel_path}'")
else:
    errors.append(f"Calculated relative path '{rel_path}' != expected '{expected_rel}'")

godot_tmj_base = "res://maps/backdrops/level1"
godot_combined = f"{godot_tmj_base}/{rel_path}"
parts = godot_combined.split('/')
stack = []
for p in parts:
    if p == '..':
        if stack and stack[-1] != 'res:':
            stack.pop()
    elif p != '.' and p != '':
        stack.append(p)
godot_canonical = stack[0] + '//' + '/'.join(stack[1:])
print(f"Godot res:// canonical path: '{godot_canonical}'")
if godot_canonical == f"res://tsj/{test_tsj}":
    print("PASS: Godot YATI canonicalization correct")
else:
    errors.append(f"Godot canonicalization error: '{godot_canonical}'")

print("\n=== VERIFICATION TEST 2: TMJ Map References ===")
tmj_files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    if '.git' in dirpath or '.godot' in dirpath: continue
    for f in filenames:
        if f.endswith('.tmj'):
            tmj_files.append(os.path.join(dirpath, f))

print(f"Total .tmj map files found: {len(tmj_files)}")
tmj_tsj_sources = 0

for tmj_path in tmj_files:
    rel_tmj = os.path.relpath(tmj_path, ROOT)
    with open(tmj_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    tilesets = data.get('tilesets', [])
    for idx, ts in enumerate(tilesets):
        src = ts.get('source')
        if src:
            tmj_tsj_sources += 1
            # Must start with relative path to tsj/
            dir_tmj = os.path.dirname(tmj_path)
            target_tsj_path = os.path.normpath(os.path.join(dir_tmj, src))
            exists = os.path.exists(target_tsj_path)
            in_tsj_dir = target_tsj_path.startswith(TSJ_DIR)
            
            if not exists:
                errors.append(f"[{rel_tmj}] Tileset source '{src}' does NOT exist at {target_tsj_path}")
            elif not in_tsj_dir:
                errors.append(f"[{rel_tmj}] Tileset source '{src}' does NOT resolve inside res://tsj/ ({target_tsj_path})")
            else:
                print(f"  [{rel_tmj}] '{src}' -> EXISTS in res://tsj/ ({os.path.basename(target_tsj_path)})")

print(f"Total external TSJ sources across all TMJs: {tmj_tsj_sources}")

print("\n=== VERIFICATION TEST 3: TSJ Files & Image Path Resolution ===")
tsj_files = [f for f in os.listdir(TSJ_DIR) if f.endswith('.tsj')]
print(f"Total TSJ files in res://tsj/: {len(tsj_files)}")

missing_images_count = 0
for tsj_name in tsj_files:
    tsj_path = os.path.join(TSJ_DIR, tsj_name)
    with open(tsj_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
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
            errors.append(f"[tsj/{tsj_name}] Image reference '{img_ref}' not found at {img_path}")
            missing_images_count += 1

if missing_images_count == 0:
    print("PASS: ALL TSJ image references resolve to existing files in res://tsj/")
else:
    print(f"FAIL: {missing_images_count} broken image references found in TSJ files")

print("\n=== VERIFICATION TEST 4: No Scattered TSJ Files ===")
scattered = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    if dirpath.startswith(TSJ_DIR) or '.git' in dirpath or '.godot' in dirpath:
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            scattered.append(os.path.join(dirpath, f))

if len(scattered) == 0:
    print("PASS: Zero .tsj files found outside res://tsj/")
else:
    errors.append(f"Scattered .tsj files still exist: {scattered}")

print("\n=== VERIFICATION TEST 5: Tiled Project Configuration ===")
tiled_proj_path = os.path.join(ROOT, r'maps\backdrops\levels.godot.tiled-project')
with open(tiled_proj_path, 'r', encoding='utf-8') as f:
    proj_data = json.load(f)
folders = proj_data.get('folders', [])
print(f"levels.godot.tiled-project folders: {folders}")
if "../../tsj" in folders and "." in folders:
    print("PASS: Tiled project folders correctly configured")
else:
    errors.append(f"Tiled project folders invalid: {folders}")

print("\n=== VERIFICATION SUMMARY ===")
if not errors:
    print("SUCCESS: ALL 5 VERIFICATION TESTS PASSED PERFECTLY (0 ERRORS)")
else:
    print(f"FAILED with {len(errors)} errors:")
    for err in errors:
        print(f"  - ERROR: {err}")
