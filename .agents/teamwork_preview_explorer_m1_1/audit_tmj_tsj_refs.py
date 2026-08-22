import os
import json

root = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
excluded_folders = {'.git', '.godot', '.agents', 'android', 'build'}

print('=== ALL TMJ FILES & ALL TILESET REFS ===')
tmj_files = []
for dirpath, dirnames, filenames in os.walk(root):
    parts = set(os.path.normpath(dirpath).split(os.sep))
    if excluded_folders.intersection(parts):
        continue
    for f in filenames:
        if f.endswith('.tmj'):
            tmj_files.append(os.path.join(dirpath, f))

for tmj in sorted(tmj_files):
    rel_tmj = os.path.relpath(tmj, root)
    print(f'\nTMJ FILE: {rel_tmj}')
    with open(tmj, 'r', encoding='utf-8', errors='ignore') as fp:
        data = json.load(fp)
        for ts in data.get('tilesets', []):
            source = ts.get('source')
            firstgid = ts.get('firstgid')
            name = ts.get('name')
            if source:
                abs_ts_path = os.path.normpath(os.path.join(os.path.dirname(tmj), source))
                exists = os.path.exists(abs_ts_path)
                try:
                    rel_to_root = os.path.relpath(abs_ts_path, root)
                except ValueError:
                    rel_to_root = abs_ts_path
                print(f'  - firstgid: {firstgid}, source: "{source}"')
                print(f'    -> resolves to: "{rel_to_root}" (exists: {exists})')
            else:
                print(f'  - firstgid: {firstgid}, embedded tileset name: "{name}"')

print('\n=== IMAGE REFS IN TSJ FILES ===')
# Check image paths in all TSJs in maps/ and tsj/
tsj_files = []
for dirpath, dirnames, filenames in os.walk(root):
    parts = set(os.path.normpath(dirpath).split(os.sep))
    if excluded_folders.intersection(parts):
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            tsj_files.append(os.path.join(dirpath, f))

image_ref_patterns = {}
missing_images = []

for tsj in tsj_files:
    rel_tsj = os.path.relpath(tsj, root)
    with open(tsj, 'r', encoding='utf-8', errors='ignore') as fp:
        try:
            data = json.load(fp)
            tsj_dir = os.path.dirname(tsj)
            
            main_img = data.get('image')
            if main_img:
                abs_img = os.path.normpath(os.path.join(tsj_dir, main_img))
                exists = os.path.exists(abs_img)
                try:
                    rel_img = os.path.relpath(abs_img, root)
                except ValueError:
                    rel_img = abs_img
                if not exists:
                    missing_images.append((rel_tsj, main_img, rel_img))
                image_ref_patterns.setdefault(os.path.dirname(main_img), 0)
                image_ref_patterns[os.path.dirname(main_img)] += 1
                
            for tile in data.get('tiles', []):
                t_img = tile.get('image')
                if t_img:
                    abs_img = os.path.normpath(os.path.join(tsj_dir, t_img))
                    exists = os.path.exists(abs_img)
                    try:
                        rel_img = os.path.relpath(abs_img, root)
                    except ValueError:
                        rel_img = abs_img
                    if not exists:
                        missing_images.append((rel_tsj, t_img, rel_img))
                    image_ref_patterns.setdefault(os.path.dirname(t_img), 0)
                    image_ref_patterns[os.path.dirname(t_img)] += 1
        except Exception as e:
            print(f'Error reading TSJ {rel_tsj}: {e}')

print(f'\nImage reference directory patterns (relative to TSJ location):')
for d, count in sorted(image_ref_patterns.items(), key=lambda x: x[1], reverse=True):
    print(f'  "{d}": {count} references')

print(f'\nTotal missing image references: {len(missing_images)}')
if missing_images:
    print('Sample missing image references (first 10):')
    for tsj_rel, img_ref, res_rel in missing_images[:10]:
        print(f'  TSJ: {tsj_rel} -> img ref: "{img_ref}" -> expected: {res_rel}')

