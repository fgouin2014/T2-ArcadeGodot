import os
import json
import shutil
import hashlib

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
PARENT_ROOT = r'c:\androidProject\lastchance\DukeSoundboard'
TSJ_DIR = os.path.join(ROOT, 'tsj')

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

print("=== STEP 1: AUDIT & COPY MISSING TSJ FILES TO res://tsj/ ===")
missing_tsjs = [
    r'maps\Terminator.tsj',
    r'maps\backdrops\xenjump_placeholder.tsj',
    r'maps\tilesets\decors\xskynt3\xskynt3_00.tsj',
    r'maps\tilesets\objets\xskydoor\xskydoor_00.tsj',
    r'maps\tilesets\objets\xskydoor\xskydoor_01.tsj',
    r'maps\tilesets\objets\xskynt1\xskynt1.tsj',
    r'maps\tilesets\objets\xskynt1\xskynt1_03.tsj',
    r'maps\tilesets\objets\xskynt2\xskynt2_00.tsj',
    r'maps\tilesets\objets\xskynt2\xskynt2_01.tsj',
    r'maps\tilesets\objets\xskynt2\xskynt2_05.tsj',
    r'maps\tilesets\objets\xskynt2\xskynt2_13.tsj',
]

for rel_path in missing_tsjs:
    src_path = os.path.join(ROOT, rel_path)
    dest_path = os.path.join(TSJ_DIR, os.path.basename(rel_path))
    print(f"Missing TSJ: {rel_path} -> dest exists: {os.path.exists(dest_path)}")

print("\n=== STEP 2: CHECK IMAGE RESOLUTION FOR TSJS IN res://tsj/ ===")
all_tsj_names = [f for f in os.listdir(TSJ_DIR) if f.endswith('.tsj')] + [os.path.basename(p) for p in missing_tsjs]
all_tsj_names = sorted(list(set(all_tsj_names)))
print(f"Total unique TSJs that will be in res://tsj/: {len(all_tsj_names)}")

# Collect all PNG files in project and parent
png_locations = {}
for search_root in [ROOT, PARENT_ROOT]:
    for dirpath, dirnames, filenames in os.walk(search_root):
        if '.git' in dirpath or '.godot' in dirpath:
            continue
        for f in filenames:
            if f.lower().endswith('.png'):
                png_locations.setdefault(f, []).append(os.path.join(dirpath, f))

print(f"Unique PNG filenames cataloged: {len(png_locations)}")

# Check each TSJ in tsj/ (or missing_tsjs)
tsj_image_updates = {} # tsj_filename -> list of (old_img, new_img, status)

for tsj_name in all_tsj_names:
    tsj_path = os.path.join(TSJ_DIR, tsj_name)
    if not os.path.exists(tsj_path):
        # Find source
        for rel in missing_tsjs:
            if os.path.basename(rel) == tsj_name:
                tsj_path = os.path.join(ROOT, rel)
                break
    
    with open(tsj_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    tsj_dir = os.path.dirname(tsj_path)
    images_in_tsj = []
    if "image" in data:
        images_in_tsj.append(("image", None, data["image"]))
    if "tiles" in data:
        for idx, tile in enumerate(data["tiles"]):
            if isinstance(tile, dict) and "image" in tile:
                images_in_tsj.append(("tile", idx, tile["image"]))
                
    updates_for_this_tsj = []
    for img_kind, tile_idx, img_ref in images_in_tsj:
        # Check if img_ref resolves directly from TSJ_DIR
        resolved_tsj_dir = os.path.normpath(os.path.join(TSJ_DIR, img_ref))
        resolved_orig_dir = os.path.normpath(os.path.join(tsj_dir, img_ref))
        img_name = os.path.basename(img_ref)
        path_co_located = os.path.join(TSJ_DIR, img_name)
        
        if os.path.exists(resolved_tsj_dir):
            updates_for_this_tsj.append((img_kind, tile_idx, img_ref, img_ref, "RESOLVED_AS_IS"))
        elif os.path.exists(path_co_located):
            # The image is co-located in tsj/ under img_name
            updates_for_this_tsj.append((img_kind, tile_idx, img_ref, img_name, "UPDATE_TO_COLOCATED"))
        elif os.path.exists(resolved_orig_dir):
            # Resolves from orig dir, let's copy image to tsj/ or make relative path
            # If we copy image to tsj/
            rel_from_tsj = os.path.relpath(resolved_orig_dir, TSJ_DIR).replace('\\', '/')
            updates_for_this_tsj.append((img_kind, tile_idx, img_ref, img_name, f"COPY_IMAGE_TO_TSJ_AND_COLOCATE ({resolved_orig_dir})"))
        elif img_name in png_locations:
            # Found PNG elsewhere in repo!
            found_png = png_locations[img_name][0]
            updates_for_this_tsj.append((img_kind, tile_idx, img_ref, img_name, f"COPY_FOUND_PNG_TO_TSJ ({found_png})"))
        else:
            updates_for_this_tsj.append((img_kind, tile_idx, img_ref, img_ref, "BROKEN_NOT_FOUND"))
            
    if updates_for_this_tsj:
        tsj_image_updates[tsj_name] = updates_for_this_tsj

# Summarize results
statuses = {}
for tsj_name, updates in tsj_image_updates.items():
    for img_kind, tile_idx, old_img, new_img, status in updates:
        stat_key = status.split(' (')[0]
        statuses[stat_key] = statuses.get(stat_key, 0) + 1

print("\nIMAGE STATUS BREAKDOWN:")
for k, v in statuses.items():
    print(f"  {k}: {v}")

print("\nDETAILS FOR NON-RESOLVED_AS_IS IMAGES:")
for tsj_name, updates in tsj_image_updates.items():
    non_as_is = [u for u in updates if u[4] != "RESOLVED_AS_IS"]
    if non_as_is:
        print(f"\nTSJ: {tsj_name}")
        for img_kind, tile_idx, old_img, new_img, status in non_as_is:
            print(f"  [{img_kind} {tile_idx}] '{old_img}' -> '{new_img}' | {status}")
