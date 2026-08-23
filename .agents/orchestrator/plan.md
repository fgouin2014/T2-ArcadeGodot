# Plan: T2-ArcadeGodot Map Architecture & Enemy Placement

## Plan Overview
1. **Milestone 1: TSJ Isolation & Tiled Integration (R3, R4)**
   - Audit current `.tsj` and image locations across `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\`.
   - Move/group all `.tsj` tileset files and associated image assets into `tsj/` (`res://tsj/`).
   - Configure/fix references in `levels.godot.tiled-project` and `.tmj` maps for Godot 4 TMJ/TSJ import pipeline compatibility.
   - Verify no broken references or missing assets upon opening in Godot 4.

2. **Milestone 2: Direct Enemy Placement & Triggering (R1)**
   - Audit enemy scenes (e.g. `xgigend.tscn`) and map `.tscn` files.
   - Implement direct enemy placement in `.tscn` map scenes.
   - Add/configure `VisibleOnScreenNotifier2D` on enemy scenes/maps so enemies trigger sequence/behaviour only when reached by camera screen view.

3. **Milestone 3: Perpetual Parallax Looping (R2)**
   - Examine `t2_stage3` and `t2_xroad` scenes and parallax implementations.
   - Implement continuous looping parallax scrolling for both stages.
   - Connect loop stopping logic to Boss defeat event.

4. **Milestone 4: Verification & Acceptance Gate**
   - Reviewer + Challenger + Forensic Auditor verification across all 4 requirements R1-R4.
