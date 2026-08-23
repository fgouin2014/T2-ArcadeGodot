import os
import json
import shutil

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
PARENT_ROOT = r'c:\androidProject\lastchance\DukeSoundboard'
TSJ_DIR = os.path.join(ROOT, 'tsj')

os.makedirs(TSJ_DIR, exist_ok=True)

# 1. Copy missing TSJs
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

print("1. Copying missing TSJ files to tsj/...")
for rel in missing_tsjs:
    src = os.path.join(ROOT, rel)
    dest = os.path.join(TSJ_DIR, os.path.basename(rel))
    if os.path.exists(src) and not os.path.exists(dest):
        shutil.copy2(src, dest)
        print(f"  Copied {rel}")

# 2. Build PNG lookup map
png_lookup = {}
for search_root in [ROOT, PARENT_ROOT]:
    for dirpath, dirnames, filenames in os.walk(search_root):
        if '.git' in dirpath or '.godot' in dirpath:
            continue
        for f in filenames:
            if f.lower().endswith('.png'):
                png_lookup.setdefault(f, []).append(os.path.join(dirpath, f))

def fix_image_path(tsj_name, img_ref):
    img_name = os.path.basename(img_ref)
    dest_png = os.path.join(TSJ_DIR, img_name)
    
    if os.path.exists(dest_png):
        return img_name, (img_ref != img_name)
    
    found_src = None
    rel_tsj = os.path.normpath(os.path.join(TSJ_DIR, img_ref))
    if os.path.exists(rel_tsj):
        found_src = rel_tsj
    elif img_name in png_lookup:
        found_src = png_lookup[img_name][0]
        
    if found_src and os.path.exists(found_src):
        shutil.copy2(found_src, dest_png)
        return img_name, True
    else:
        print(f"  WARNING: Missing image '{img_ref}' in '{tsj_name}'")
        return img_name, False

print("2. Standardizing TSJ image paths and co-locating images in tsj/...")
tsj_files = [os.path.join(TSJ_DIR, f) for f in os.listdir(TSJ_DIR) if f.endswith('.tsj')]
mod_tsj_count = 0
for tsj_path in tsj_files:
    tsj_name = os.path.basename(tsj_path)
    with open(tsj_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    modified = False
    if "image" in data:
        new_img, is_mod = fix_image_path(tsj_name, data["image"])
        data["image"] = new_img
        if is_mod: modified = True
            
    if "tiles" in data:
        for tile in data["tiles"]:
            if isinstance(tile, dict) and "image" in tile:
                new_img, is_mod = fix_image_path(tsj_name, tile["image"])
                tile["image"] = new_img
                if is_mod: modified = True
                
    if modified:
        with open(tsj_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        mod_tsj_count += 1

print(f"  Standardized image refs in {mod_tsj_count} TSJ files.")

print("3. Updating TMJ files to point to res://tsj/...")
tmj_files = [
    r'maps\backdrops\level1\t2_hideout.tmj',
    r'maps\backdrops\level1\t2_stage3.tmj',
    r'maps\backdrops\level1\t2_starter_blank.tmj',
    r'maps\backdrops\level1\t2_starter_canvas.tmj',
    r'maps\backdrops\level1\t2_testchamber.tmj',
    r'maps\backdrops\level1\t2_xfback2.tmj',
    r'maps\backdrops\level1\t2_xl1bck.tmj',
    r'maps\backdrops\level1\t2_xl1bck1.tmj',
    r'maps\backdrops\level1\t2_xl4skynt1.tmj',
    r'maps\backdrops\level1\t2_xroad.tmj',
    r'maps\backdrops\level1\exported\t2_starter_blank_embeded.tmj',
]

mod_tmj_count = 0
for rel_tmj in tmj_files:
    tmj_path = os.path.join(ROOT, rel_tmj)
    if not os.path.exists(tmj_path):
        continue
    
    tmj_dir = os.path.dirname(tmj_path)
    rel_to_tsj = os.path.relpath(TSJ_DIR, tmj_dir).replace('\\', '/')
    
    with open(tmj_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    tilesets = data.get('tilesets', [])
    modified_tmj = False
    for ts in tilesets:
        if 'source' in ts and ts['source']:
            old_src = ts['source']
            ts_filename = os.path.basename(old_src)
            new_src = f"{rel_to_tsj}/{ts_filename}"
            if old_src != new_src:
                ts['source'] = new_src
                modified_tmj = True
                
    if modified_tmj:
        with open(tmj_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        mod_tmj_count += 1
        print(f"  Updated TMJ: {rel_tmj}")

print(f"  Updated {mod_tmj_count} TMJ files.")

print("4. Updating levels.godot.tiled-project...")
tiled_proj_path = os.path.join(ROOT, r'maps\backdrops\levels.godot.tiled-project')
if os.path.exists(tiled_proj_path):
    with open(tiled_proj_path, 'r', encoding='utf-8') as f:
        proj_data = json.load(f)
    folders = proj_data.get('folders', [])
    if "../../tsj" not in folders:
        folders.append("../../tsj")
        proj_data['folders'] = folders
        with open(tiled_proj_path, 'w', encoding='utf-8') as f:
            json.dump(proj_data, f, indent=4)
        print("  Updated levels.godot.tiled-project folders array.")

print("5. Removing scattered duplicate .tsj files outside res://tsj/...")
removed_count = 0
for dirpath, dirnames, filenames in os.walk(ROOT):
    if dirpath.startswith(TSJ_DIR) or '.git' in dirpath or '.godot' in dirpath:
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            filepath = os.path.join(dirpath, f)
            os.remove(filepath)
            removed_count += 1
print(f"  Removed {removed_count} duplicate .tsj files.")
print("=== PIPELINE EXECUTION COMPLETE ===")
