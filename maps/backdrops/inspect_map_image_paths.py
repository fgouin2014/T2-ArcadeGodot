import os
import json

maps_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops\level1'

for map_name in sorted(os.listdir(maps_dir)):
    if map_name.endswith('.tmj'):
        map_path = os.path.join(maps_dir, map_name)
        with open(map_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        image_paths = []
        for ts in data.get('tilesets', []):
            if 'image' in ts:
                image_paths.append(ts['image'])
            for tile in ts.get('tiles', []):
                if 'image' in tile:
                    image_paths.append(tile['image'])
        
        print(f'Map: {map_name}')
        for img in set(image_paths):
            print(f'   -> {img}')
