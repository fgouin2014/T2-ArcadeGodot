## 2026-07-30T17:14:00Z
<USER_REQUEST>
You are Worker 3 for Milestone 2 (Direct Enemy Placement & Camera Triggering).
Your working directory is: c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_worker_m2_1

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Objective:
Implement Requirement R1 based on Explorer 2's handoff report (`c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_explorer_m1_2\handoff.md`):

1. **Add `VisibleOnScreenNotifier2D` to Enemy Scenes**:
   Attach a child node named `"VisibleOnScreenNotifier2D"` of type `VisibleOnScreenNotifier2D` to all enemy `.tscn` scenes in `res://aseprite/`:
   - `aseprite/xgigend.tscn`
   - `aseprite/xarng.tscn`
   - `aseprite/xbigend.tscn`
   - `aseprite/xmedend.tscn`
   - `aseprite/xsarah.tscn`
   - `aseprite/xswat.tscn`
   - `aseprite/xt100.tscn`
   - `aseprite/xt100big.tscn`
   - `aseprite/xtech.tscn`
   Configure the `rect` property (e.g., `Rect2(-60, -66, 120, 132)`) appropriately for each enemy sprite boundary.

2. **Refactor Enemy Activation Logic (`Script/xgigend.gd`)**:
   Ensure `_ready()` keeps enemies dormant (`visible = false`) when `activer_uniquement_sur_ecran = true` and `notifier` is non-null.
   Connect `notifier.screen_entered` to `_on_ecran_entre()`, activating the enemy (`activer_acteur()`) ONLY when the camera screen enters the enemy's bounding box.
   Ensure editor preview (`Engine.is_editor_hint()`) keeps enemies visible in Godot 2D workspace.

3. **Direct Enemy Placement**:
   Ensure enemy `.tscn` instances can be placed directly inside map `.tscn` scenes (e.g. `maps/t2_xl1bck1.tscn`).

4. **Verification**:
   Create and execute a verification script confirming that 100% of enemy `.tscn` scenes contain a `VisibleOnScreenNotifier2D` child node and that `notifier` resolves non-null.

5. Write a comprehensive handoff report to `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_worker_m2_1\handoff.md`.

</USER_REQUEST>
