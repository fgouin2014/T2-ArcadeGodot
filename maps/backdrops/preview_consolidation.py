import os
import json

base_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'
level1_dir = os.path.join(base_dir, 'level1')

other_folders = ['level2', 'level3', 'level4', 'level6', 'level7', 'xroad', 'placeholder']

files_to_copy = []
for folder in other_folders:
    fpath = os.path.join(base_dir, folder)
    if os.path.exists(fpath):
        for root, dirs, files in os.walk(fpath):
            for f in files:
                src = os.path.join(root, f)
                dst = os.path.join(level1_dir, f)
                files_to_copy.append((src, dst, f))

print(f'Total files from other folders that would be copied into level1: {len(files_to_copy)}')
