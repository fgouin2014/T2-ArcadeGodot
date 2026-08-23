import os
import json
import hashlib

root = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
excluded_folders = {'.git', '.godot', '.agents', 'android', 'build'}

def hash_file(path):
    if not os.path.exists(path):
        return None
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

print('===========================================================')
print('=== 1. TMJ FILES AND THEIR TILESET REFERENCES ===')
print('===========================================================')

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
    print(f'\nTMJ: {rel_tmj}')
    with open(tmj, 'r', encoding='utf-8', errors='ignore') as fp:
        try:
            data = json.load(fp)
            tilesets = data.get('tilesets', [])
            for ts in tilesets:
                s = ts.get('source')
                firstgid = ts.get('firstgid')
                if s:
                    resolved = os.path.normpath(os.path.join(os.path.dirname(tmj), s))
                    exists = os.path.exists(resolved)
                    rel_resolved = os.path.relpath(resolved, root) if exists else 'NOT FOUND'
                    print(f'   firstgid {firstgid}: "{s}" -> resolved: {rel_resolved} (exists: {exists})')
                else:
                    print(f'   firstgid {firstgid}: embedded tileset "{ts.get("name")}"')
        except Exception as e:
            print(f'   ERROR parsing TMJ: {e}')

print('\n===========================================================')
print('=== 2. TSJ FILES DISTRIBUTION AND IMAGE REFERENCES ===')
print('===========================================================')

tsj_files = []
for dirpath, dirnames, filenames in os.walk(root):
    parts = set(os.path.normpath(dirpath).split(os.sep))
    if excluded_folders.intersection(parts):
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            tsj_files.append(os.path.join(dirpath, f))

tsj_by_dir = {}
for p in tsj_files:
    d = os.path.relpath(os.path.dirname(p), root)
    tsj_by_dir.setdefault(d, []).append(p)

for d, files in sorted(tsj_by_dir.items()):
    print(f'\nDirectory: {d} ({len(files)} TSJ files)')
    # sample print first 5 files
    for p in files[:5]:
        rel_p = os.path.relpath(p, root)
        with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
            try:
                data = json.load(fp)
                img = data.get('image', None)
                tiles = data.get('tiles', [])
                tile_imgs = [t.get('image') for t in tiles if 'image' in t]
                print(f'   {os.path.basename(p)} -> main image: {img}, tile images count: {len(tile_imgs)}')
            except Exception as e:
                print(f'   {os.path.basename(p)} -> ERROR: {e}')
    if len(files) > 5:
        print(f'   ... and {len(files)-5} more')

print('\n===========================================================')
print('=== 3. COMPARE MAPS/BACKDROPS/LEVEL1 TSJS VS TSJ/ TSJS ===')
print('===========================================================')

level1_tsjs = tsj_by_dir.get(r'maps\backdrops\level1', [])
tsj_folder_tsjs = tsj_by_dir.get('tsj', [])

level1_names = {os.path.basename(p): p for p in level1_tsjs}
tsj_folder_names = {os.path.basename(p): p for p in tsj_folder_tsjs}

only_in_level1 = set(level1_names.keys()) - set(tsj_folder_names.keys())
only_in_tsj_dir = set(tsj_folder_names.keys()) - set(level1_names.keys())
in_both = set(level1_names.keys()).intersection(set(tsj_folder_names.keys()))

print(f'TSJs in maps\\backdrops\\level1: {len(level1_names)}')
print(f'TSJs in tsj folder: {len(tsj_folder_names)}')
print(f'In both: {len(in_both)}')
print(f'Only in maps\\backdrops\\level1: {len(only_in_level1)}')
if only_in_level1:
    print(f'   Files: {sorted(list(only_in_level1))}')
print(f'Only in tsj folder: {len(only_in_tsj_dir)}')
if only_in_tsj_dir:
    print(f'   Files: {sorted(list(only_in_tsj_dir))}')

# Check hash comparison for files in both
identical_count = 0
different_files = []
for name in in_both:
    h1 = hash_file(level1_names[name])
    h2 = hash_file(tsj_folder_names[name])
    if h1 == h2:
        identical_count += 1
    else:
        different_files.append(name)

print(f'Identical files between maps\\backdrops\\level1 and tsj\\: {identical_count}')
print(f'Different files between maps\\backdrops\\level1 and tsj\\: {len(different_files)}')
if different_files:
    print(f'   Different files list: {different_files[:10]} ...')

print('\n===========================================================')
print('=== 4. OTHER TSJS OUTSIDE LEVEL1 AND TSJ/ ===')
print('===========================================================')
for d, files in sorted(tsj_by_dir.items()):
    if d not in [r'maps\backdrops\level1', 'tsj']:
        print(f'Directory {d}: {len(files)} files')
        for p in files:
            print(f'   {os.path.relpath(p, root)}')

