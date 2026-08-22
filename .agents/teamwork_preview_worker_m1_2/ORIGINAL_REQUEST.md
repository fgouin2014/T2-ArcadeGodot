## 2026-07-30T20:57:44Z
<USER_REQUEST>
You are Worker 2 for Milestone 1 Remediation (TSJ Metadata & TMJ Path Fixes).
Your working directory is: c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_worker_m1_2

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Objective:
Fix the defects identified by Challenger 1 (`c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_challenger_m1_1\handoff.md`):

1. **Fix Missing Tileset Path Prefixes in `t2_xl1bck1.tmj`**:
   Update all 16 tileset source references in `maps/backdrops/level1/t2_xl1bck1.tmj` so their `"source"` fields use `"../../../tsj/<filename>.tsj"`.

2. **Sync TSJ Metadata Dimensions with Physical PNG Images**:
   For all `.tsj` files in `res://tsj/` (`c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj\`), inspect the referenced PNG image dimensions on disk and update `imagewidth` and `imageheight` in the `.tsj` JSON files whenever they mismatch the actual PNG header width/height.

3. **Normalize Deep Relative Path Escapes**:
   Replace any legacy relative paths escaping `res://` (such as `../../../../app/src/main/assets/...`) inside `.tmj` and `.tsj` files with proper `res://` relative paths.

4. **Verification**:
   - Run `python c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_challenger_m1_1\stress_test_m1.py` and confirm zero TSJ/TMJ errors remain.
   - Run `python .agents/teamwork_preview_worker_m1_1/verify_all.py` to confirm all verification tests pass.

5. Write your handoff report to `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_worker_m1_2\handoff.md`.

</USER_REQUEST>
