import os

ROOT = r'c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot'
PARENT_ROOT = r'c:\androidProject\lastchance\DukeSoundboard'

missing_list = [
    'xethrow_centered.png',
    'xmedend_wide_frame_0.png',
    'xmedend_wide_frame_1.png',
    'xmedend_wide_frame_2.png',
    'xmedend_wide_frame_3.png',
    'xmedend_wide_frame_4.png',
    'xmedend_wide_frame_5.png',
    'xmedend_wide_frame_6.png',
    'xmedend_wide_frame_7.png',
    'xmedend_walk_59px.png',
    'xsarah_die.png',
    'xsarah_drop.png',
    'xsarah_idle.png',
    'xswatrolattck_centered.png',
    'xswatshoot_crouch_centered.png',
    'xt100frm_form_composite.png',
    'xt100spt_split.png',
    'xt100sms_effect.png'
]

print("Searching in parent directory:", PARENT_ROOT)
for target in missing_list:
    found = []
    base_name_no_ext = os.path.splitext(target)[0]
    prefix = base_name_no_ext.split('_')[0]
    for dirpath, dirnames, filenames in os.walk(PARENT_ROOT):
        if '.git' in dirpath or '.godot' in dirpath:
            continue
        for f in filenames:
            if target.lower() in f.lower() or (len(prefix) >= 4 and prefix.lower() in f.lower()):
                if f.lower().endswith('.png') or f.lower().endswith('.tsj'):
                    found.append(os.path.join(dirpath, f))
    print(f"\nSearch for '{target}':")
    if found:
        for p in found[:10]:
            print(f"  Found: {os.path.relpath(p, PARENT_ROOT)}")
    else:
        print("  NONE FOUND")
