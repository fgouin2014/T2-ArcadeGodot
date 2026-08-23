# Handoff Report — Explorer 1 (Milestone 1: TSJ Isolation & Godot 4 Import Pipeline)

## 1. Observation

Direct observations made during the audit of `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\`:

1. **TSJ Distribution across Workspace**:
   - Total `.tsj` files found: **501 files** (268 unique TSJ file names).
   - `tsj/` (`res://tsj/`): Contains **233 `.tsj` files** and **321 `.png` images**.
   - `maps/backdrops/level1/`: Contains **231 `.tsj` files**.
     - 197 files are byte-for-byte identical to their counterparts in `tsj/`.
     - 34 files differ between `maps/backdrops/level1/` and `tsj/` (e.g. `test_enemies_collection.tsj` contains 13 tile images in `tsj/` vs 6 tile images in `level1/`).
     - 2 files (`xgigend.tsj`, `xt100sms_effect.tsj`) exist in `tsj/` but not in `level1/`.
   - 37 `.tsj` files exist in other subdirectories: `maps/backdrops/` (15), `maps/tilesets/personages/xmedend/` (11), `maps/tilesets/objets/xskynt2/` (4), `maps/tilesets/objets/xskydoor/` (2), `maps/tilesets/objets/xskynt1/` (2), `maps/tilesets/decors/xskynt3/` (1), `maps/animations/xenfwrd2/` (1), `maps/Terminator.tsj` (1).

2. **TMJ File References (`tilesets` array)**:
   - 11 `.tmj` map files exist in `maps/backdrops/level1/`.
   - Inspection of `t2_hideout.tmj`, `t2_stage3.tmj`, `t2_testchamber.tmj`, `t2_xfback2.tmj`, `t2_xl1bck.tmj`, `t2_xl1bck1.tmj`, `t2_xl4skynt1.tmj`, `t2_xroad.tmj` shows external relative paths pointing to the old Android directory:
     ```json
     "source": "../../../../app/src/main/assets/maps/backdrops/level1/test_enemies_collection.tsj"
     ```
     ```json
     "source": "../../../../app/src/main/assets/maps/backdrops/level1/xtinhk_00.tsj"
     ```
   - Inspection of `t2_starter_blank.tmj` and `t2_starter_canvas.tmj` shows co-located relative paths:
     ```json
     "source": "test_enemies_collection.tsj"
     ```
     ```json
     "source": "level1_decor.tsj"
     ```

3. **Godot 4 Importer (YATI) Configuration & Behavior**:
   - `project.godot` lines 27-28 enable YATI:
     ```ini
     [editor_plugins]
     enabled=PackedStringArray("res://addons/AsepriteWizard/plugin.cfg", "res://addons/YATI/plugin.cfg", "res://addons/addons/nklbdev.aseprite_importers/plugin.cfg")
     ```
   - `addons/YATI/Importer.gd` lines 32-33:
     ```gdscript
     func _get_recognized_extensions() -> PackedStringArray:
         return PackedStringArray(["tmx", "tmj"])
     ```
   - `addons/YATI/TilesetCreator.gd` lines 93 & 105:
     ```gdscript
     var source_file: String = tile_set["source"]
     _base_path_tileset = _base_path_map.path_join(source_file).get_base_dir()
     ```
   - YATI resolves `.tsj` paths relative to the `.tmj` file directory `_base_path_map`.

4. **Tiled Project Configuration**:
   - File: `maps/backdrops/levels.godot.tiled-project`
     ```json
     {
         "automappingRulesFile": "",
         "commands": [],
         "compatibilityVersion": 1100,
         "extensionsPath": "extensions",
         "folders": [
             "."
         ],
         "properties": [],
         "propertyTypes": []
     }
     ```
   - Currently specifies `"folders": ["."]`, limiting Tiled view to `maps/backdrops/`.

5. **TSJ Image Path Audit**:
   - 659 image references evaluated across `.tsj` files:
     - 202 references use filename-only (co-located PNG in `res://tsj/`).
     - 180+ references use relative paths to `maps/animations/` or `maps/tilesets/`.
     - 23 references use broken legacy external paths (`../../../../../../../../t2_extracted/...`).
   - 321 `.png` files are already co-located in `tsj/`.

---

## 2. Logic Chain

1. **Premise 1 (R3 Goal)**: Requirement R3 requires all `.tsj` tileset files to be isolated in `res://tsj/` (`c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj\`).
   - **Observation Ref**: Observation 1 shows 233 TSJs already exist in `tsj/`, but 37 unique TSJs remain scattered in `maps/backdrops/`, `maps/tilesets/`, `maps/animations/`, and `maps/`.
   - **Reasoning**: To complete R3, all 37 remaining TSJ files must be moved/copied to `res://tsj/`, and `tsj/` versions must be established as the single canonical source of truth.

2. **Premise 2 (R4 TMJ Reference Update)**: `.tmj` files located in `maps/backdrops/level1/` currently reference TSJ files via outdated relative paths (`../../../../app/src/main/assets/maps/backdrops/level1/...` or `test_enemies_collection.tsj`).
   - **Observation Ref**: Observation 2 quotes exact `"source"` fields from TMJ files.
   - **Reasoning**: The relative path from `maps/backdrops/level1/` to `tsj/` is `../../../tsj/`. Updating all `"source"` fields in `.tmj` files to `"../../../tsj/<filename>.tsj"` correctly targets `res://tsj/`.

3. **Premise 3 (YATI Godot Import Pipeline Safety)**: Godot 4 imports `.tmj` files using YATI (`addons/YATI`).
   - **Observation Ref**: Observation 3 quotes `TilesetCreator.gd` lines 93 & 105. `_base_path_map.path_join("../../../tsj/filename.tsj")` resolves in Godot to `res://tsj/filename.tsj`.
   - **Reasoning**: Because YATI canonicalizes relative paths via Godot's `String.path_join()`, changing `"source"` to `"../../../tsj/filename.tsj"` in `.tmj` files will allow YATI to load tilesets directly from `res://tsj/` without requiring any changes to the YATI GDScript addon code.

4. **Premise 4 (Tiled Editor GUI Compatibility)**: Tiled uses `levels.godot.tiled-project` to manage project folders.
   - **Observation Ref**: Observation 4 shows `"folders": ["."]`.
   - **Reasoning**: Adding `"../../tsj"` to `"folders"` in `levels.godot.tiled-project` ensures Tiled displays both `maps/` and `tsj/` in its file navigator.

5. **Premise 5 (TSJ Image Co-location / Path Standardization)**:
   - **Observation Ref**: Observation 5 shows 23 broken image paths pointing to external legacy directories (`t2_extracted`) and 321 PNG files already inside `tsj/`.
   - **Reasoning**: Standardizing image paths inside TSJs in `res://tsj/` to co-locate images or use valid relative paths from `res://tsj/` ensures TSJs load their textures without missing file errors during YATI scene imports.

---

## 3. Caveats

1. **Duplicate Cleanup Timing**: Duplicate `.tsj` files exist in `maps/backdrops/level1/`. Deleting them before updating `.tmj` references will temporarily break TMJs. Duplicate cleanup should strictly be performed after updating TMJ references.
2. **34 Differing TSJ Files**: 34 TSJ files differ between `maps/backdrops/level1/` and `tsj/`. The `tsj/` version is more complete (e.g. `test_enemies_collection.tsj` in `tsj/` has 13 tile images vs 6 in `level1/`), but each should be verified against map usages during implementation.
3. **23 External Legacy Images**: 23 TSJ files contain broken references to an external `t2_extracted` folder. The matching PNG files exist in `maps/animations/` or `tsj/` under slightly different relative paths and need image path re-linking in the TSJ JSON.

---

## 4. Conclusion

- Requirements **R3** and **R4** can be achieved cleanly without modifying the YATI Godot addon or breaking Godot 4 scene imports.
- **R3 Action**: Consolidate all 268 unique TSJ files into `res://tsj/` (`c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj\`) and standardize internal `"image"` paths.
- **R4 Action 1**: Update all 10 `.tmj` map files in `maps/backdrops/level1/` so their `"tilesets"` array sources point to `"../../../tsj/<filename>.tsj"`.
- **R4 Action 2**: Update `maps/backdrops/levels.godot.tiled-project` folder array to `[ ".", "../../tsj" ]`.
- Detailed breakdown, file lists, and audit tables are documented in `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\.agents\teamwork_preview_explorer_m1_1\tsj_isolation_analysis.md`.

---

## 5. Verification Method

### 1. Verify Path Resolution via Python Audit
Run the verification script from the working directory:
```powershell
python .agents/teamwork_preview_explorer_m1_1/verify_paths.py
```
**Expected Result**: Confirms `../../../tsj/<filename>.tsj` resolves to `tsj\<filename>.tsj` on disk and canonicalizes to `res://tsj/<filename>.tsj` in Godot.

### 2. Verify TMJ Source Updates
Inspect any updated `.tmj` file (e.g. `maps/backdrops/level1/t2_xl1bck1.tmj`):
```powershell
python -c "import json; data=json.load(open('maps/backdrops/level1/t2_xl1bck1.tmj')); print([ts.get('source') for ts in data['tilesets']])"
```
**Expected Result**: All external sources begin with `"../../../tsj/"` and every target file exists in `tsj/`.

### 3. Verify Tiled Project Config
Inspect `maps/backdrops/levels.godot.tiled-project`:
**Expected Result**: `"folders": [ ".", "../../tsj" ]`.

### 4. Verify Godot 4 YATI Import Execution
Open `T2-ArcadeGodot` in Godot 4 or run Godot import command:
**Expected Result**: All 10 `.tmj` maps import cleanly into `.godot/imported/` without missing tileset or image errors.

