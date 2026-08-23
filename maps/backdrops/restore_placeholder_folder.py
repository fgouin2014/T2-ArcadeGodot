import os
import shutil

base_dir = r'C:\androidProject\lastchance\DukeSoundboard\app\src\main\assets\maps\backdrops'
placeholder_dir = os.path.join(base_dir, 'placeholder')
level1_dir = os.path.join(base_dir, 'level1')

os.makedirs(placeholder_dir, exist_ok=True)

print("==========================================================")
print(" RESTORING maps/backdrops/placeholder/ FOLDER")
print("==========================================================")

restored_count = 0
for root, dirs, files in os.walk(base_dir):
    # Avoid copying from placeholder itself
    if os.path.normpath(root) == os.path.normpath(placeholder_dir):
        continue
    for f in files:
        if 'placeholder' in f.lower():
            src_file = os.path.join(root, f)
            dst_file = os.path.join(placeholder_dir, f)
            shutil.copy2(src_file, dst_file)
            restored_count += 1
            print(f"  [RESTORED TO placeholder/] {f}")

print(f"\nSUCCESS: Restored {restored_count} placeholder files in maps/backdrops/placeholder/")
