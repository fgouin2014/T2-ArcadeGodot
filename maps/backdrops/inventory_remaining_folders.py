import os
import json

base_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'
target_folders = ['level2', 'level4', 'level7', 'leveldev']

print('=== DETAILED INVENTORY OF REMAINING FOLDERS (level2, level4, level7, leveldev) ===\n')

for folder in target_folders:
    folder_path = os.path.join(base_dir, folder)
    if os.path.exists(folder_path):
        files = os.listdir(folder_path)
        print(f'DOSSIER: maps/backdrops/{folder}/ ({len(files)} files) :')
        for f in sorted(files):
            fp = os.path.join(folder_path, f)
            size_kb = os.path.getsize(fp) / 1024
            print(f'   - {f:<30} ({size_kb:.1f} KB)')
    else:
        print(f'DOSSIER: maps/backdrops/{folder}/ (Inexistant)')
    print()
