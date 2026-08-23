import os
import json

base_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'
level1_dir = os.path.join(base_dir, 'level1')

print('=== 1. SCANNING ALL .TSJ AND .PNG FILES IN LEVEL2 TO LEVEL7 ===')
outside_tilesets = []
for root, dirs, files in os.walk(base_dir):
    rel = os.path.relpath(root, base_dir)
    if rel != '.' and not rel.startswith('level1') and not rel.startswith('leveldev'):
        for f in files:
            if f.endswith('.tsj') or f.endswith('.tsx') or f.endswith('.png'):
                full_p = os.path.join(root, f)
                outside_tilesets.append((rel, f, full_p))
                print(f'  [Outside File] {rel}\\{f}')

print(f'Total tileset/png files found outside level1: {len(outside_tilesets)}')

print('\n=== 2. AUDITING TILESET REFERENCES (.TSJ / .PNG) IN LEVEL1 MAPS ===')
level1_maps = [f for f in os.listdir(level1_dir) if f.endswith('.tmj')]

broken_count = 0
ok_count = 0

for map_file in sorted(level1_maps):
    map_path = os.path.join(level1_dir, map_file)
    print(f'\n--- MAP: {map_file} ---')
    try:
        with open(map_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        tilesets = data.get('tilesets', [])
        for ts in tilesets:
            source = ts.get('source', '')
            firstgid = ts.get('firstgid', 0)
            if source:
                target_path = os.path.normpath(os.path.join(level1_dir, source))
                exists = os.path.exists(target_path)
                if exists:
                    ok_count += 1
                    status = 'OK'
                else:
                    broken_count += 1
                    status = 'BROKEN / MISSING!'
                print(f'  - firstgid: {firstgid} | source: "{source}" -> [{status}] (Resolved: {target_path})')
                
                # If source TSJ exists, check its internal image reference!
                if exists and (target_path.endswith('.tsj') or target_path.endswith('.json')):
                    try:
                        with open(target_path, 'r', encoding='utf-8') as tsf:
                            tsdata = json.load(tsf)
                            img = tsdata.get('image', '')
                            if img:
                                img_target = os.path.normpath(os.path.join(os.path.dirname(target_path), img))
                                img_exists = os.path.exists(img_target)
                                img_status = 'OK' if img_exists else 'BROKEN IMAGE!'
                                print(f'      └─ TSJ Image: "{img}" -> [{img_status}] ({img_target})')
                    except Exception as e:
                        print(f'      └─ Error reading TSJ {target_path}: {e}')
            else:
                print(f'  - Embedded Tileset firstgid: {firstgid} name: {ts.get("name")}')
    except Exception as e:
        print(f'  Error parsing map {map_file}: {e}')

print('\n=== AUDIT SUMMARY ===')
print(f'Valid tileset references: {ok_count}')
print(f'Broken tileset references: {broken_count}')
