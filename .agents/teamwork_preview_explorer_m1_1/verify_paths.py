import os
import json

root = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'

print('=== TESTING CANONICAL PATH RESOLUTION ===')

tmj_dir = os.path.join(root, r'maps\backdrops\level1')
tsj_dir = os.path.join(root, 'tsj')

# Test TMJ to TSJ path
test_tsj_filename = 'test_enemies_collection.tsj'
rel_from_tmj_dir = os.path.relpath(os.path.join(tsj_dir, test_tsj_filename), tmj_dir)
print(f'Relative path from maps/backdrops/level1/ to tsj/{test_tsj_filename}: "{rel_from_tmj_dir.replace(os.sep, "/")}"')

abs_check = os.path.normpath(os.path.join(tmj_dir, rel_from_tmj_dir))
print(f'  Resolves to: {os.path.relpath(abs_check, root)} (exists: {os.path.exists(abs_check)})')

# Test Godot res:// string manipulation equivalent
godot_tmj_base = "res://maps/backdrops/level1"
godot_rel_source = rel_from_tmj_dir.replace(os.sep, "/")
# Godot path_join:
godot_combined = f"{godot_tmj_base}/{godot_rel_source}"

# Simplify res:// path
parts = godot_combined.split('/')
stack = []
for p in parts:
    if p == '..':
        if stack and stack[-1] != 'res:':
            stack.pop()
    elif p != '.' and p != '':
        stack.append(p)
godot_canonical = stack[0] + '//' + '/'.join(stack[1:])
print(f'Godot res:// path canonicalized: "{godot_canonical}"')

