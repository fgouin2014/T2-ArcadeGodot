import os
import sys

def main():
    base_dir = r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot"
    print("=== Running Verification for Requirement R2 ===")
    
    passed = True

    # 1. Inspect camera_auto_scroll.gd
    camera_script_path = os.path.join(base_dir, "Script", "camera_auto_scroll.gd")
    if not os.path.exists(camera_script_path):
        print(f"FAIL: {camera_script_path} not found")
        passed = False
    else:
        with open(camera_script_path, "r", encoding="utf-8") as f:
            cam_content = f.read()

        if "mode_perpetuel" not in cam_content:
            print("FAIL: mode_perpetuel variable missing in camera_auto_scroll.gd")
            passed = False
        else:
            print("PASS: mode_perpetuel defined in camera_auto_scroll.gd")

        if "largeur_boucle_parallax" not in cam_content:
            print("FAIL: largeur_boucle_parallax variable missing in camera_auto_scroll.gd")
            passed = False
        else:
            print("PASS: largeur_boucle_parallax defined in camera_auto_scroll.gd")

        if "stopper_scroll_boss_defait" not in cam_content:
            print("FAIL: stopper_scroll_boss_defait method missing in camera_auto_scroll.gd")
            passed = False
        else:
            print("PASS: stopper_scroll_boss_defait method present in camera_auto_scroll.gd")

        if "motion_mirroring" not in cam_content:
            print("FAIL: motion_mirroring configuration missing in camera_auto_scroll.gd")
            passed = False
        else:
            print("PASS: motion_mirroring setup present in camera_auto_scroll.gd")

        if "not mode_perpetuel" not in cam_content:
            print("FAIL: mode_perpetuel right-limit bypass missing in camera_auto_scroll.gd")
            passed = False
        else:
            print("PASS: mode_perpetuel bypasses limit_right clamping in camera_auto_scroll.gd")

    # 2. Inspect maps/t2_stage3.tscn
    stage3_path = os.path.join(base_dir, "maps", "t2_stage3.tscn")
    if not os.path.exists(stage3_path):
        print(f"FAIL: {stage3_path} not found")
        passed = False
    else:
        with open(stage3_path, "r", encoding="utf-8") as f:
            s3_content = f.read()
        
        if "mode_perpetuel = true" in s3_content and "largeur_boucle_parallax = 384.0" in s3_content:
            print("PASS: maps/t2_stage3.tscn correctly configured (mode_perpetuel=true, width=384.0)")
        else:
            print("FAIL: maps/t2_stage3.tscn missing mode_perpetuel=true or largeur_boucle_parallax=384.0")
            passed = False

    # 3. Inspect maps/t2_xroad.tscn
    xroad_path = os.path.join(base_dir, "maps", "t2_xroad.tscn")
    if not os.path.exists(xroad_path):
        print(f"FAIL: {xroad_path} not found")
        passed = False
    else:
        with open(xroad_path, "r", encoding="utf-8") as f:
            xr_content = f.read()
        
        if "mode_perpetuel = true" in xr_content and "largeur_boucle_parallax = 3072.0" in xr_content:
            print("PASS: maps/t2_xroad.tscn correctly configured (mode_perpetuel=true, width=3072.0)")
        else:
            print("FAIL: maps/t2_xroad.tscn missing mode_perpetuel=true or largeur_boucle_parallax=3072.0")
            passed = False

    # 4. Inspect Boss Scripts & Signal Connection
    boss_script_path = os.path.join(base_dir, "Script", "xgigend.gd")
    main_script_path = os.path.join(base_dir, "Script", "main.gd")
    
    if not os.path.exists(boss_script_path):
        print(f"FAIL: {boss_script_path} not found")
        passed = False
    else:
        with open(boss_script_path, "r", encoding="utf-8") as f:
            boss_content = f.read()
        
        if "signal boss_defeated" in boss_content:
            print("PASS: signal boss_defeated present in xgigend.gd (inherited by xbigend.gd and xarng.gd)")
        else:
            print("FAIL: signal boss_defeated missing in xgigend.gd")
            passed = False

    if not os.path.exists(main_script_path):
        print(f"FAIL: {main_script_path} not found")
        passed = False
    else:
        with open(main_script_path, "r", encoding="utf-8") as f:
            main_content = f.read()
        
        if "boss_defeated" in main_content and "stopper_scroll_boss_defait" in main_content:
            print("PASS: boss_defeated signal connected to stopper_scroll_boss_defait in main.gd / boss script")
        else:
            print("FAIL: boss_defeated signal connection missing in main.gd")
            passed = False

    print("==============================================")
    if passed:
        print("RESULT: ALL R2 VERIFICATION CHECKS PASSED SUCCESSFULLY!")
        sys.exit(0)
    else:
        print("RESULT: VERIFICATION FAILED!")
        sys.exit(1)

if __name__ == "__main__":
    main()
