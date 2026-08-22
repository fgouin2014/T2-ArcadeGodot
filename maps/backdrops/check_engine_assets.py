import os
import re
import json

code_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\java'
assets_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets'
backdrops_dir = os.path.join(assets_dir, 'maps', 'backdrops')

print('=== 1. CHECKING CODE FOR LEVEL2-7 FOLDER STRINGS ===')
code_refs = {}
for root, dirs, files in os.walk(code_dir):
    for f in files:
        if f.endswith('.kt') or f.endswith('.java'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
                for lvl in ['level2', 'level3', 'level4', 'level6', 'level7', 'xroad', 'placeholder']:
                    if lvl in content:
                        code_refs.setdefault(lvl, []).append(f)

for lvl, files in code_refs.items():
    print(f'Folder "{lvl}" is referenced in code: {sorted(list(set(files)))}')

print('\n=== 2. CHECKING IF .TMJ MAPS OR .TSJ TILESETS REFERENCE IMAGES IN LEVEL2-7 ===')
image_refs = set()

def check_json(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # check image field
            if 'image' in data:
                image_refs.add((filepath, data['image']))
            # check tilesets
            for ts in data.get('tilesets', []):
                if 'image' in ts:
                    image_refs.add((filepath, ts['image']))
    except Exception as e:
        pass

for root, dirs, files in os.walk(backdrops_dir):
    for f in files:
        if f.endswith('.tmj') or f.endswith('.tsj') or f.endswith('.json'):
            check_json(os.path.join(root, f))

level2_7_img_refs = [r for r in image_refs if any(lvl in r[1] for lvl in ['level2', 'level3', 'level4', 'level6', 'level7', 'xroad', 'placeholder'])]

print(f'Total image references pointing to level2-7 folders: {len(level2_7_img_refs)}')
for src, img in level2_7_img_refs[:20]:
    print(f'  From {os.path.basename(src)} -> Image: "{img}"')
