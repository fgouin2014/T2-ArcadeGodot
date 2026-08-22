import os
import json

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
TSJ_DIR = os.path.join(ROOT, 'tsj')
MAPS_DIR = os.path.join(ROOT, 'maps')

# Build an index of all png files in the repository
png_index = {} # filename -> list of absolute paths
for dirpath, dirnames, filenames in os.walk(ROOT):
    if '.git' in dirpath or '.godot' in dirpath:
        continue
    for f in filenames:
        if f.lower().endswith('.png'):
            p = os.path.join(dirpath, f)
            png_index.setdefault(f, []).append(p)

print(f"Total PNG files found in repo: {sum(len(v) for v in png_index.values())}")
print(f"Unique PNG filenames found in repo: {len(png_index)}")
print(f"PNG files in tsj/: {len([f for f in os.listdir(TSJ_DIR) if f.lower().endswith('.png')])}")

# Now let's list all 244 unique TSJ files across the project
tsj_by_name = {}
for dirpath, dirnames, filenames in os.walk(ROOT):
    if '.git' in dirpath or '.godot' in dirpath:
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            p = os.path.join(dirpath, f)
            tsj_by_name.setdefault(f, []).append(p)

missing_images = []
found_in_tsj = 0
found_in_repo = 0
found_by_path = 0

for tsj_name, paths in tsj_by_name.items():
    # Pick canonical TSJ (prefer one in TSJ_DIR if exists, else first)
    tsj_path = next((p for p in paths if p.startswith(TSJ_DIR)), paths[0])
    dir_of_tsj = os.path.dirname(tsj_path)
    
    with open(tsj_path, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except Exception as e:
            print(f"Error loading {tsj_path}: {e}")
            continue
            
    images_to_check = []
    if "image" in data:
        images_to_check.append(("image", None, data["image"]))
    if "tiles" in data:
        for idx, tile in enumerate(data["tiles"]):
            if isinstance(tile, dict) and "image" in tile:
                images_to_check.append(("tile", idx, tile["image"]))
                
    for img_type, idx, img_ref in images_to_check:
        # Check 1: direct relative path from TSJ_DIR
        path_from_tsj_dir = os.path.normpath(os.path.join(TSJ_DIR, img_ref))
        # Check 2: direct relative path from current TSJ dir
        path_from_cur_dir = os.path.normpath(os.path.join(dir_of_tsj, img_ref))
        # Check 3: filename in TSJ_DIR
        img_basename = os.path.basename(img_ref)
        path_basename_tsj = os.path.join(TSJ_DIR, img_basename)
        
        if os.path.exists(path_from_tsj_dir):
            found_by_path += 1
        elif os.path.exists(path_from_cur_dir):
            found_by_path += 1
        elif os.path.exists(path_basename_tsj):
            found_in_tsj += 1
        elif img_basename in png_index:
            found_in_repo += 1
        else:
            missing_images.append((tsj_name, img_ref, img_basename))

print(f"\nResults across all {len(tsj_by_name)} TSJ files:")
print(f"  - Image found via existing relative path: {found_by_path}")
print(f"  - Image filename already present in tsj/: {found_in_tsj}")
print(f"  - Image found elsewhere in repo: {found_in_repo}")
print(f"  - Image missing completely from repo: {len(missing_images)}")

if missing_images:
    print("\nMISSING IMAGES (not anywhere in repo):")
    for tsj_name, img_ref, img_basename in missing_images[:30]:
        print(f"  {tsj_name}: '{img_ref}' (basename: {img_basename})")
