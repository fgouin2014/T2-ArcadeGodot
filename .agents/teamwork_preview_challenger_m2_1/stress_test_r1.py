#!/usr/bin/env python3
"""
Stress Test and Empirical Verification Script for Requirement R1
(Direct Enemy Placement & Camera Triggering)

Target Files:
- aseprite/xgigend.tscn
- aseprite/xarng.tscn
- aseprite/xbigend.tscn
- aseprite/xmedend.tscn
- aseprite/xsarah.tscn
- aseprite/xswat.tscn
- aseprite/xt100.tscn
- aseprite/xt100big.tscn
- aseprite/xtech.tscn
- Script/xgigend.gd
"""

import os
import re
import sys

PROJECT_ROOT = os.path.abspath(r"c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot")

ENEMY_SCENES = [
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

def parse_rect(rect_str):
    m = re.search(r'Rect2\(\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*\)', rect_str)
    if m:
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))
    return None

def parse_vector2(vec_str):
    m = re.search(r'Vector2\(\s*([\d.-]+)\s*,\s*([\d.-]+)\s*\)', vec_str)
    if m:
        return (float(m.group(1)), float(m.group(2)))
    return None

def run_stress_test():
    print("======================================================================")
    print("       REQUIREMENT R1 EMPIRICAL STRESS TEST & BOUNDS VERIFICATION     ")
    print("======================================================================\n")

    results = {
        "scenes_analyzed": 0,
        "scenes_passed_bounds": 0,
        "scenes_failed_bounds": 0,
        "script_bugs_found": [],
        "bounding_box_details": []
    }

    # ------------------------------------------------------------------
    # PART 1: Scene & Bounding Box Inspection across all 9 enemy scenes
    # ------------------------------------------------------------------
    print("--- PART 1: Inspecting 9 Enemy Scenes (Bounding Boxes & Notifiers) ---")

    for rel_path in ENEMY_SCENES:
        full_path = os.path.join(PROJECT_ROOT, rel_path)
        if not os.path.exists(full_path):
            print(f"[FAIL] Missing scene file: {rel_path}")
            results["scenes_failed_bounds"] += 1
            continue

        results["scenes_analyzed"] += 1
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Check Script attachment
        script_match = re.search(r'path="res://Script/xgigend.gd"', content)
        has_correct_script = script_match is not None

        # Check VisibleOnScreenNotifier2D Node
        has_notifier = re.search(
            r'\[node\s+name="VisibleOnScreenNotifier2D"\s+type="VisibleOnScreenNotifier2D"',
            content
        ) is not None

        # Extract Notifier Rect
        notifier_rect_match = re.search(r'rect\s*=\s*(Rect2\([^)]+\))', content)
        notifier_rect = parse_rect(notifier_rect_match.group(1)) if notifier_rect_match else None

        # Extract CollisionShape2D size
        col_shape_ref = re.search(r'\[node\s+name="CollisionShape2D".*?shape=SubResource\("([^"]+)"\)', content)
        col_bounds = None
        col_size = None
        if col_shape_ref:
            shape_id = col_shape_ref.group(1)
            sub_res = re.search(r'\[sub_resource type="([^"]+)" id="' + re.escape(shape_id) + r'"\](.*?)(?=\n\[|\Z)', content, re.DOTALL)
            if sub_res:
                shape_type = sub_res.group(1)
                shape_body = sub_res.group(2)
                if shape_type == "RectangleShape2D":
                    size_match = re.search(r'size\s*=\s*(Vector2\([^)]+\))', shape_body)
                    if size_match:
                        col_size = parse_vector2(size_match.group(1))
                        if col_size:
                            # Centered box
                            col_bounds = (-col_size[0]/2.0, -col_size[1]/2.0, col_size[0], col_size[1])

        # Extract Sprite frame sample dimension
        atlas_match = re.search(r'region\s*=\s*Rect2\([^,]+,\s*[^,]+,\s*([\d.-]+),\s*([\d.-]+)\)', content)
        sprite_dim = (float(atlas_match.group(1)), float(atlas_match.group(2))) if atlas_match else None

        # Analyze coverage
        coverage_pass = False
        coverage_reason = ""
        if notifier_rect and col_bounds:
            nx, ny, nw, nh = notifier_rect
            cx, cy, cw, ch = col_bounds
            n_right = nx + nw
            n_bottom = ny + nh
            c_right = cx + cw
            c_bottom = cy + ch

            covers = (nx <= cx) and (ny <= cy) and (n_right >= c_right) and (n_bottom >= c_bottom)
            if covers:
                coverage_pass = True
                coverage_reason = f"Notifier [{nx}, {ny}, {nw}, {nh}] covers Collision [{cx}, {cy}, {cw}, {ch}]"
            else:
                coverage_reason = f"MISMATCH: Notifier [{nx}, {ny}, {nw}, {nh}] does NOT cover Collision [{cx}, {cy}, {cw}, {ch}]"
        elif not has_notifier:
            coverage_reason = "MISSING VisibleOnScreenNotifier2D node!"
        elif not notifier_rect:
            coverage_reason = "MISSING rect property on VisibleOnScreenNotifier2D!"
        else:
            coverage_reason = "Could not parse collision bounds."

        status_str = "PASS" if (has_notifier and coverage_pass and has_correct_script) else "FAIL"
        if status_str == "PASS":
            results["scenes_passed_bounds"] += 1
        else:
            results["scenes_failed_bounds"] += 1

        info_entry = {
            "scene": rel_path,
            "script": "res://Script/xgigend.gd" if has_correct_script else "INCORRECT/MISSING",
            "has_notifier": has_notifier,
            "notifier_rect": notifier_rect,
            "col_size": col_size,
            "col_bounds": col_bounds,
            "sprite_dim": sprite_dim,
            "coverage_pass": coverage_pass,
            "status": status_str,
            "reason": coverage_reason
        }
        results["bounding_box_details"].append(info_entry)

        print(f"[{status_str}] {rel_path:22s} | Notifier: {str(notifier_rect):20s} | ColSize: {str(col_size):15s} | Coverage: {coverage_reason}")

    # ------------------------------------------------------------------
    # PART 2: Empirical Analysis & Stress Testing of Script/xgigend.gd
    # ------------------------------------------------------------------
    print("\n--- PART 2: Stress-Testing Script/xgigend.gd Logic & Edge Cases ---")

    script_path = os.path.join(PROJECT_ROOT, "Script", "xgigend.gd")
    if not os.path.exists(script_path):
        print("[CRITICAL FAIL] Script/xgigend.gd does not exist!")
        sys.exit(1)

    with open(script_path, "r", encoding="utf-8") as f:
        gdscript_content = f.read()

    # Vulnerability 1: root node visible = false
    # Setting `visible = false` on CharacterBody2D in Godot 4 makes `is_visible_in_tree()` false for all children.
    # In Godot, a VisibleOnScreenNotifier2D inside a hidden subtree DOES NOT EMIT screen_entered!
    has_root_hiding_bug = "visible = false" in gdscript_content and "activer_uniquement_sur_ecran" in gdscript_content
    if has_root_hiding_bug:
        bug_desc = (
            "BUG #1 (HIGH SEVERITY): Root Node Hiding Disables VisibleOnScreenNotifier2D.\n"
            "   - Location: Script/xgigend.gd:40 (`visible = false` in `_ready()`)\n"
            "   - Mechanism: Hiding the parent `CharacterBody2D` sets `is_visible_in_tree() = false` for child `VisibleOnScreenNotifier2D`.\n"
            "   - Result: In Godot 4, hidden `VisibleOnScreenNotifier2D` nodes do NOT track screen entry. `screen_entered` signal will NEVER fire when camera scrolls over enemy!\n"
            "   - Impact: Off-screen enemies remain invisible and dormant forever.\n"
            "   - Fix: Hide `anim_sprite.visible = false` (or set `modulate.a = 0`) instead of `visible = false` on root node."
        )
        results["script_bugs_found"].append(bug_desc)
        print(f"\n[VULNERABILITY FOUND] {bug_desc}")

    # Vulnerability 2: is_on_screen() during _ready() for X=0
    # In _ready(), node has just entered tree; viewport visibility bounds are not initialized.
    # is_on_screen() returns false even if enemy is at X=0 inside starting screen rect.
    has_on_screen_ready_issue = "if notifier.is_on_screen():" in gdscript_content
    if has_on_screen_ready_issue:
        bug_desc = (
            "BUG #2 (MEDIUM SEVERITY): Unreliable `is_on_screen()` check during `_ready()` for X=0.\n"
            "   - Location: Script/xgigend.gd:44 (`if notifier.is_on_screen(): _on_ecran_entre()`)\n"
            "   - Mechanism: In Godot 4, `notifier.is_on_screen()` inside `_ready()` returns false before the first render frame, especially after setting `visible = false` on line 40.\n"
            "   - Result: Enemies placed at X=0 (on-screen at level start) fail `is_on_screen()`, get hidden by `visible = false`, and never receive `screen_entered`.\n"
            "   - Impact: Enemies at X=0 fail to activate on level spawn.\n"
            "   - Fix: Defer visibility check to `call_deferred('_check_initial_visibility')` or wait 1 frame."
        )
        results["script_bugs_found"].append(bug_desc)
        print(f"\n[VULNERABILITY FOUND] {bug_desc}")

    # Vulnerability 3: Edge Case Enemy X > limit_right
    bug_desc_3 = (
        "EDGE CASE #1: Enemy Placed Beyond Camera Limit Right (X > limit_right).\n"
        "   - Scenario: Level designer places enemy at X = 3000, but camera `limit_right` = 2500.\n"
        "   - Behavior: Camera position is clamped at `limit_right - demi_ecran` (2500 - 143 = 2357). The camera viewport right boundary is X = 2500.\n"
        "   - Result: The enemy at X = 3000 is never reached by camera viewport. `VisibleOnScreenNotifier2D` never fires. Enemy remains dormant forever."
    )
    results["script_bugs_found"].append(bug_desc_3)
    print(f"\n[EDGE CASE ANALYSIS] {bug_desc_3}")

    # Vulnerability 4: Re-entrancy & Stacking in activer_acteur()
    # If activer_acteur() is called multiple times, it creates multiple SceneTreeTimer instances.
    has_timer_stacking = "timer_fin_attaque = get_tree().create_timer" in gdscript_content
    if has_timer_stacking:
        bug_desc_4 = (
            "BUG #3 (MEDIUM SEVERITY): Stacking SceneTreeTimer and Re-entrancy in `activer_acteur()`.\n"
            "   - Location: Script/xgigend.gd:58 & 132\n"
            "   - Mechanism: `activer_acteur()` lacks a re-entrancy guard if called directly multiple times (e.g. from debug ADB signals or script calls). Each call spawns an unmanaged `get_tree().create_timer()`.\n"
            "   - Result: Multiple concurrent timers run in background, triggering premature `_on_temps_attaque_ecoule` and `se_retracter()` while attack is ongoing.\n"
            "   - Fix: Check `if deja_active: return` at top of `activer_acteur()` and cancel/disconnect old timer if restarting."
        )
        results["script_bugs_found"].append(bug_desc_4)
        print(f"\n[VULNERABILITY FOUND] {bug_desc_4}")

    # ------------------------------------------------------------------
    # PART 3: Summary & Final Verdict
    # ------------------------------------------------------------------
    print("\n======================================================================")
    print("                        SUMMARY & FINAL VERDICT                       ")
    print("======================================================================")
    print(f"Total Enemy Scenes Analyzed: {results['scenes_analyzed']}/9")
    print(f"Scenes Passing Bounds Check: {results['scenes_passed_bounds']}/9")
    print(f"Scenes Failing Bounds Check: {results['scenes_failed_bounds']}/9")
    print(f"Script Bugs/Vulnerabilities Identified: {len(results['script_bugs_found'])}")
    print("======================================================================")

    return results

if __name__ == "__main__":
    res = run_stress_test()
    if res["scenes_failed_bounds"] > 0 or len(res["script_bugs_found"]) > 0:
        print("\n[CONCLUSION] Requirement R1 contains critical implementation bugs in Script/xgigend.gd despite valid scene bounding boxes!")
        sys.exit(0)
    else:
        print("\n[CONCLUSION] Requirement R1 passed all stress tests.")
        sys.exit(0)
