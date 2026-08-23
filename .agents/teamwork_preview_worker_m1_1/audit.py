import os
import json
import hashlib

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
TSJ_DIR = os.path.join(ROOT, 'tsj')

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

print("--- AUDITING ALL .tsj FILES ---")
all_tsj = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    # skip .git or .godot
    if '.git' in dirpath or '.godot' in dirpath:
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            all_tsj.append(os.path.join(dirpath, f))

print(f"Total .tsj files found: {len(all_tsj)}")
tsj_by_name = {}
for p in all_tsj:
    name = os.path.basename(p)
    tsj_by_name.setdefault(name, []).append(p)

print(f"Unique .tsj filenames: {len(tsj_by_name)}")

outside_tsj_dir = [p for p in all_tsj if not p.startswith(TSJ_DIR)]
print(f"Total .tsj files outside {TSJ_DIR}: {len(outside_tsj_dir)}")

missing_in_tsj_dir = []
for name, paths in tsj_by_name.items():
    in_tsj_dir = any(p.startswith(TSJ_DIR) for p in paths)
    if not in_tsj_dir:
        missing_in_tsj_dir.append((name, paths))

print(f"TSJ filenames missing from res://tsj/: {len(missing_in_tsj_dir)}")
for name, paths in missing_in_tsj_dir:
    print(f"  - {name}: {paths}")

# Inspect differing TSJ files
differing = []
for name, paths in tsj_by_name.items():
    tsj_dir_path = os.path.join(TSJ_DIR, name)
    if os.path.exists(tsj_dir_path):
        h_tsj = sha256_file(tsj_dir_path)
        for p in paths:
            if p != tsj_dir_path:
                if sha256_file(p) != h_tsj:
                    differing.append((name, p, tsj_dir_path))

print(f"Differing copies vs tsj/: {len(differing)}")
for name, p, tsj_dir_path in differing[:10]:
    print(f"  - {name} @ {os.path.relpath(p, ROOT)} vs {os.path.relpath(tsj_dir_path, ROOT)}")

print("\n--- AUDITING ALL .tmj FILES ---")
all_tmj = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    if '.git' in dirpath or '.godot' in dirpath:
        continue
    for f in filenames:
        if f.endswith('.tmj'):
            all_tmj.append(os.path.join(dirpath, f))

print(f"Total .tmj files found: {len(all_tmj)}")
for p in all_tmj:
    print(f"TMJ: {os.path.relpath(p, ROOT)}")
    with open(p, 'r', encoding='utf-8') as f:
        data = json.load(f)
    tilesets = data.get('tilesets', [])
    for ts in tilesets:
        print(f"  - source: {ts.get('source')} | firstgid: {ts.get('firstgid')}")
