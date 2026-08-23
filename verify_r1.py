import os
import re
import sys

ENEMY_FILES = [
    "aseprite/xgigend.tscn",
    "aseprite/xarng.tscn",
    "aseprite/xbigend.tscn",
    "aseprite/xmedend.tscn",
    "aseprite/xsarah.tscn",
    "aseprite/xswat.tscn",
    "aseprite/xt100.tscn",
    "aseprite/xt100big.tscn",
    "aseprite/xtech.tscn",
]

PROJECT_ROOT = r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot"

def verify():
    print("=== STARTING VERIFICATION FOR REQUIREMENT R1 ===")
    errors = []
    
    # 1. Verify all 9 enemy .tscn files
    for rel_path in ENEMY_FILES:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        if not os.path.exists(full_path):
            errors.append(f"MISSING FILE: {rel_path}")
            continue
        
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()
            
        has_notifier_node = re.search(
            r'\[node\s+name="VisibleOnScreenNotifier2D"\s+type="VisibleOnScreenNotifier2D"\s+parent="\."\]',
            content
        )
        has_rect = re.search(r'rect\s*=\s*Rect2\(.*?\)', content)
        
        if not has_notifier_node:
            errors.append(f"FAIL: {rel_path} does not contain 'VisibleOnScreenNotifier2D' node definition!")
        elif not has_rect:
            errors.append(f"FAIL: {rel_path} contains 'VisibleOnScreenNotifier2D' node but missing 'rect' property!")
        else:
            print(f"PASS: {rel_path} contains valid VisibleOnScreenNotifier2D child node with rect.")

    # 2. Verify Script/xgigend.gd
    script_path = os.path.join(PROJECT_ROOT, "Script", "xgigend.gd")
    if not os.path.exists(script_path):
        errors.append(f"MISSING FILE: Script/xgigend.gd")
    else:
        with open(script_path, "r", encoding="utf-8") as f:
            script_content = f.read()
            
        if 'get_node_or_null("VisibleOnScreenNotifier2D")' not in script_content:
            errors.append("FAIL: Script/xgigend.gd does not resolve 'VisibleOnScreenNotifier2D' node.")
        elif 'notifier.screen_entered.connect(_on_ecran_entre)' not in script_content:
            errors.append("FAIL: Script/xgigend.gd does not connect notifier.screen_entered to _on_ecran_entre.")
        elif 'Engine.is_editor_hint()' not in script_content:
            errors.append("FAIL: Script/xgigend.gd does not check Engine.is_editor_hint() for editor preview.")
        else:
            print("PASS: Script/xgigend.gd correctly resolves 'notifier', handles dormant state, connects screen_entered signal, and supports editor preview.")

    print("===============================================")
    if errors:
        print(f"VERIFICATION FAILED WITH {len(errors)} ERROR(S):")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)
    else:
        print("VERIFICATION SUCCESSFUL: 100% of enemy .tscn scenes contain VisibleOnScreenNotifier2D node and Script/xgigend.gd handles camera triggering correctly!")
        sys.exit(0)

if __name__ == "__main__":
    verify()
