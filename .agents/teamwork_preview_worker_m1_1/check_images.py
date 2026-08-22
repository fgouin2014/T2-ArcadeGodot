import os
import json

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
TSJ_DIR = os.path.join(ROOT, 'tsj')

broken_images = []
relative_outside_images = []
colocated_images = []
all_image_refs = []

# First, let's collect all TSJ files in tsj/ (including any that should be copied there)
tsj_files = [os.path.join(TSJ_DIR, f) for f in os.listdir(TSJ_DIR) if f.endswith('.tsj')]

# Also include the 11 missing ones for checking:
missing_paths = [
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
for rel in missing_paths:
    p = os.path.join(ROOT, rel)
    if os.path.exists(p) and p not in tsj_files:
        tsj_files.append(p)

print(f"Total TSJ files to check: {len(tsj_files)}")

for tsj_path in tsj_files:
    dir_of_tsj = os.path.dirname(tsj_path)
    with open(tsj_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # TSJ can have single "image" or tiles with "image"
    images_in_file = []
    if "image" in data:
        images_in_file.append(data["image"])
    if "tiles" in data:
        for tile in data["tiles"]:
            if isinstance(tile, dict) and "image" in tile:
                images_in_file.append(tile["image"])
    
    for img_rel in images_in_file:
        all_image_refs.append((tsj_path, img_rel))
        # Resolve image relative to dir_of_tsj
        resolved = os.path.normpath(os.path.join(dir_of_tsj, img_rel))
        # Also check relative to TSJ_DIR if we were to move TSJ to TSJ_DIR
        resolved_tsj_dir = os.path.normpath(os.path.join(TSJ_DIR, img_rel))
        
        exists_current = os.path.exists(resolved)
        exists_tsj_dir = os.path.exists(resolved_tsj_dir)
        
        # Check if the filename itself exists in TSJ_DIR
        img_name = os.path.basename(img_rel)
        tsj_colocated_img = os.path.join(TSJ_DIR, img_name)
        exists_colocated = os.path.exists(tsj_colocated_img)
        
        if not exists_current and not exists_tsj_dir and not exists_colocated:
            broken_images.append((os.path.basename(tsj_path), img_rel, resolved))
        else:
            if "/" in img_rel or "\\" in img_rel:
                relative_outside_images.append((os.path.basename(tsj_path), img_rel, exists_current, exists_tsj_dir, exists_colocated))
            else:
                colocated_images.append((os.path.basename(tsj_path), img_rel))

print(f"Total image refs: {len(all_image_refs)}")
print(f"Co-located simple filename refs: {len(colocated_images)}")
print(f"Relative path refs: {len(relative_outside_images)}")
print(f"Broken image refs: {len(broken_images)}")

if broken_images:
    print("\nBROKEN IMAGES:")
    for tsj_name, img_rel, res in broken_images[:20]:
        print(f"  {tsj_name}: '{img_rel}' -> {res}")

if relative_outside_images:
    print("\nSAMPLE RELATIVE PATH REFS:")
    for tsj_name, img_rel, ex_cur, ex_tsj, ex_col in relative_outside_images[:20]:
        print(f"  {tsj_name}: '{img_rel}' (ex_cur={ex_cur}, ex_tsj={ex_tsj}, ex_colocated_in_tsj={ex_col})")
