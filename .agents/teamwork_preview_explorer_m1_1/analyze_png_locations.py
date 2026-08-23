import os
import json

root = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
excluded_folders = {'.git', '.godot', '.agents', 'android', 'build'}

# Find all PNG files in workspace
all_png_files = {}
for dirpath, dirnames, filenames in os.walk(root):
    parts = set(os.path.normpath(dirpath).split(os.sep))
    if excluded_folders.intersection(parts):
        continue
    for f in filenames:
        if f.lower().endswith('.png'):
            abs_p = os.path.join(dirpath, f)
            rel_p = os.path.relpath(abs_p, root)
            all_png_files.setdefault(f.lower(), []).append(rel_p)

print(f'Total PNG files found in repo (excluding android/build/godot): {sum(len(v) for v in all_png_files.values())}')
print(f'Unique PNG filenames: {len(all_png_files)}')

# Audit all TSJ files in repo
tsj_files = []
for dirpath, dirnames, filenames in os.walk(root):
    parts = set(os.path.normpath(dirpath).split(os.sep))
    if excluded_folders.intersection(parts):
        continue
    for f in filenames:
        if f.endswith('.tsj'):
            tsj_files.append(os.path.join(dirpath, f))

print(f'\nTotal TSJ files: {len(tsj_files)}')

report_data = []

for tsj in sorted(tsj_files):
    rel_tsj = os.path.relpath(tsj, root)
    tsj_dir = os.path.dirname(tsj)
    with open(tsj, 'r', encoding='utf-8', errors='ignore') as fp:
        try:
            data = json.load(fp)
            main_img = data.get('image')
            tiles = data.get('tiles', [])
            
            img_refs = []
            if main_img:
                img_refs.append(('main', main_img))
            for idx, t in enumerate(tiles):
                if 'image' in t:
                    img_refs.append((f'tile_{t.get("id", idx)}', t['image']))
            
            for ref_type, img_path in img_refs:
                # 1. Resolve relative to TSJ location
                abs_resolved = os.path.normpath(os.path.join(tsj_dir, img_path))
                exists = os.path.exists(abs_resolved)
                rel_resolved = os.path.relpath(abs_resolved, root) if exists else None
                
                # 2. Check if PNG filename exists anywhere in repo
                base_img_name = os.path.basename(img_path).lower()
                matches_in_repo = all_png_files.get(base_img_name, [])
                
                report_data.append({
                    'tsj': rel_tsj,
                    'ref_type': ref_type,
                    'raw_path': img_path,
                    'exists_at_raw': exists,
                    'resolved_path': rel_resolved,
                    'matches_in_repo': matches_in_repo
                })
        except Exception as e:
            print(f'Error parsing TSJ {rel_tsj}: {e}')

broken_raw = [r for r in report_data if not r['exists_at_raw']]
print(f'\nTotal TSJ image references evaluated: {len(report_data)}')
print(f'References pointing to existing file directly: {len(report_data) - len(broken_raw)}')
print(f'Broken raw references: {len(broken_raw)}')

# How many broken references have matching PNG files elsewhere in repo?
fixable_in_repo = [r for r in broken_raw if len(r['matches_in_repo']) > 0]
unfixable_in_repo = [r for r in broken_raw if len(r['matches_in_repo']) == 0]

print(f'  - Broken but matching PNG exists elsewhere in repo: {len(fixable_in_repo)}')
print(f'  - Broken and PNG NOT found in repo (missing asset): {len(unfixable_in_repo)}')

if unfixable_in_repo:
    print('\nSample unfixable missing PNGs (first 10):')
    for r in unfixable_in_repo[:10]:
        print(f'  TSJ: {r["tsj"]} -> raw: "{r["raw_path"]}" (basename: {os.path.basename(r["raw_path"])})')

