import os
import json

root = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
tmj_dir = os.path.join(root, r'maps\backdrops\level1')

print('=== DETAILED TMJ TILESET AUDIT ===')

for f in sorted(os.listdir(tmj_dir)):
    if f.endswith('.tmj'):
        p = os.path.join(tmj_dir, f)
        print(f'\n--- FILE: maps/backdrops/level1/{f} ---')
        with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
            data = json.load(fp)
            tilesets = data.get('tilesets', [])
            for ts in tilesets:
                firstgid = ts.get('firstgid')
                name = ts.get('name')
                source = ts.get('source')
                if source:
                    abs_src = os.path.normpath(os.path.join(tmj_dir, source))
                    exists = os.path.exists(abs_src)
                    rel_src = os.path.relpath(abs_src, root) if exists else 'BROKEN'
                    print(f'  firstgid={firstgid}: source="{source}"')
                    print(f'     -> resolved: "{rel_src}" (exists: {exists})')
                else:
                    print(f'  firstgid={firstgid}: embedded tileset "{name}"')

# Also check exported subfolder
exp_dir = os.path.join(tmj_dir, 'exported')
if os.path.exists(exp_dir):
    for f in sorted(os.listdir(exp_dir)):
        if f.endswith('.tmj'):
            p = os.path.join(exp_dir, f)
            print(f'\n--- FILE: maps/backdrops/level1/exported/{f} ---')
            with open(p, 'r', encoding='utf-8', errors='ignore') as fp:
                data = json.load(fp)
                tilesets = data.get('tilesets', [])
                for ts in tilesets:
                    firstgid = ts.get('firstgid')
                    name = ts.get('name')
                    source = ts.get('source')
                    if source:
                        abs_src = os.path.normpath(os.path.join(exp_dir, source))
                        exists = os.path.exists(abs_src)
                        rel_src = os.path.relpath(abs_src, root) if exists else 'BROKEN'
                        print(f'  firstgid={firstgid}: source="{source}"')
                        print(f'     -> resolved: "{rel_src}" (exists: {exists})')
                    else:
                        print(f'  firstgid={firstgid}: embedded tileset "{name}"')

