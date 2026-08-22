import os
import json

level1_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops\level1'
target_maps = ['t2_xfback2.tmj', 't2_testchamber.tmj']

for map_file in target_maps:
    p = os.path.join(level1_dir, map_file)
    if os.path.exists(p):
        with open(p, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        modified = False
        for ts in data.get('tilesets', []):
            if ts.get('image'):
                old_img = ts['image']
                new_img = os.path.basename(old_img)
                if old_img != new_img:
                    ts['image'] = new_img
                    modified = True
            for tile in ts.get('tiles', []):
                if 'image' in tile:
                    old_img = tile['image']
                    new_img = os.path.basename(old_img)
                    if old_img != new_img:
                        tile['image'] = new_img
                        modified = True
        
        if modified:
            with open(p, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            print(f"[SUCCESS] Fixed image paths in {map_file}")
