import os
import re

code_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\java'
maps_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'

print('=== 1. SEARCHING KOTLIN CODE FOR DIRECT ASSET PATHS ===')
kotlin_files = []
for root, dirs, files in os.walk(code_dir):
    for f in files:
        if f.endswith('.kt') or f.endswith('.java'):
            kotlin_files.append(os.path.join(root, f))

image_patterns = [
    'level2', 'level4', 'level7',
    'xhid', 'xl4', 'xfback', 'xfgird', 'xfurnb', 'foundry', 'xskydoor', 'xskynt'
]

matches_found = []

for kf in kotlin_files:
    fname = os.path.basename(kf)
    with open(kf, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        for i, line in enumerate(lines):
            for pat in image_patterns:
                if pat in line and not line.strip().startswith('//') and not line.strip().startswith('*'):
                    matches_found.append((fname, i + 1, pat, line.strip()))

print(f'Total occurrences of level2/4/7 assets found in Kotlin code: {len(matches_found)}')
for fname, line_num, pat, line_str in matches_found[:25]:
    print(f'  [{fname}:{line_num}] (match: "{pat}") -> {line_str[:100]}')

print('\n=== 2. CHECKING TILED MAPS IN LEVEL1 FOR EMBEDDED IMAGE PATHS ===')
level1_dir = os.path.join(maps_dir, 'level1')
for map_file in sorted(os.listdir(level1_dir)):
    if map_file.endswith('.tmj'):
        map_path = os.path.join(level1_dir, map_file)
        with open(map_path, 'r', encoding='utf-8') as f:
            content = f.read()
            for pat in ['level2/', 'level4/', 'level7/']:
                if pat in content:
                    print(f'  Map {map_file} contains string "{pat}"')
