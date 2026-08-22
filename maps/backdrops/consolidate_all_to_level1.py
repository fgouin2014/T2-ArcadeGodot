import os
import shutil
import hashlib
import json
import re

base_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'
level1_dir = os.path.join(base_dir, 'level1')

source_folders = ['level2', 'level3', 'level4', 'level6', 'level7', 'xroad', 'placeholder']

def get_md5(filepath):
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

print("==========================================================")
print(" STEP 1: CONSOLIDATING ASSETS (.PNG, .TSJ, .TSX) TO LEVEL1")
print("==========================================================")

copied_count = 0
identical_skipped = 0
conflict_count = 0

for folder in source_folders:
    folder_path = os.path.join(base_dir, folder)
    if not os.path.exists(folder_path):
        continue
    
    print(f"\nScanning folder: maps/backdrops/{folder}/ ...")
    for root, dirs, files in os.walk(folder_path):
        for f in files:
            src_file = os.path.join(root, f)
            dst_file = os.path.join(level1_dir, f)
            
            if os.path.exists(dst_file):
                src_hash = get_md5(src_file)
                dst_hash = get_md5(dst_file)
                
                if src_hash == dst_hash:
                    identical_skipped += 1
                    # Identical file already in level1, skip copy
                else:
                    conflict_count += 1
                    print(f"  [CONFLICT] File '{f}' exists in level1 with DIFFERENT contents!")
                    print(f"             Source: {src_file}")
                    print(f"             Dest:   {dst_file}")
            else:
                shutil.copy2(src_file, dst_file)
                copied_count += 1
                print(f"  [COPIED] {f} -> level1/")

print(f"\n[Step 1 Summary] Copied: {copied_count} | Identical Skipped: {identical_skipped} | Conflicts: {conflict_count}")

print("\n==========================================================")
print(" STEP 2: CLEANING RELATIVE PATHS IN .TMJ MAPS & .TX / .TSJ")
print("==========================================================")

path_patterns = [
    r'\.\./level2/', r'\.\./level3/', r'\.\./level4/', r'\.\./level6/', r'\.\./level7/', r'\.\./xroad/', r'\.\./placeholder/',
    r'level2/', r'level3/', r'level4/', r'level6/', r'level7/', r'xroad/', r'placeholder/'
]

cleaned_files = 0

for root, dirs, files in os.walk(level1_dir):
    for f in files:
        if f.endswith('.tmj') or f.endswith('.tx') or f.endswith('.tsj') or f.endswith('.tsx') or f.endswith('.json'):
            file_path = os.path.join(root, f)
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            modified_content = content
            for pat in path_patterns:
                modified_content = re.sub(pat, '', modified_content)
            
            if modified_content != content:
                with open(file_path, 'w', encoding='utf-8') as file:
                    file.write(modified_content)
                cleaned_files += 1
                print(f"  [CLEANED PATHS] {f}")

print(f"\n[Step 2 Summary] Total files with cleaned relative paths: {cleaned_files}")

print("\n==========================================================")
print(" STEP 3: VERIFYING ASSET INTEGRITY IN LEVEL1")
print("==========================================================")

missing_assets = 0

for f in os.listdir(level1_dir):
    if f.endswith('.tmj'):
        map_path = os.path.join(level1_dir, f)
        try:
            with open(map_path, 'r', encoding='utf-8') as map_file:
                data = json.load(map_file)
            for ts in data.get('tilesets', []):
                source = ts.get('source', '')
                if source:
                    target = os.path.join(level1_dir, source)
                    if not os.path.exists(target):
                        missing_assets += 1
                        print(f"  [WARNING] Missing tileset source in {f}: {source}")
                if 'image' in ts:
                    target = os.path.join(level1_dir, ts['image'])
                    if not os.path.exists(target):
                        missing_assets += 1
                        print(f"  [WARNING] Missing image in {f}: {ts['image']}")
                for tile in ts.get('tiles', []):
                    if 'image' in tile:
                        target = os.path.join(level1_dir, tile['image'])
                        if not os.path.exists(target):
                            missing_assets += 1
                            print(f"  [WARNING] Missing tile image in {f}: {tile['image']}")
        except Exception as e:
            print(f" Error parsing {f}: {e}")

print(f"[Step 3 Summary] Missing asset references: {missing_assets}")

print("\n==========================================================")
print(" STEP 4: CLEANING EMPTY FOLDERS (level2..level7, xroad)")
print("==========================================================")

for folder in source_folders:
    folder_path = os.path.join(base_dir, folder)
    if os.path.exists(folder_path):
        try:
            shutil.rmtree(folder_path)
            print(f"  [REMOVED FOLDER] maps/backdrops/{folder}/")
        except Exception as e:
            print(f"  Error removing folder {folder}: {e}")

print("\nCONSOLIDATION COMPLETED SUCCESSFULLY!")
