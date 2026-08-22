# TSJ Isolation & Godot 4 Import Pipeline Analysis (R3 & R4)

## Executive Summary
This report presents the findings of Explorer 1 for Milestone 1 (TSJ Isolation & Godot 4 Tiled Import Pipeline).
The objective is to analyze requirements **R3** (Isolate `.tsj` tilesets and assets in `res://tsj/`) and **R4** (Update Tiled project `.tiled-project` and `.tmj` file references so Godot 4 imports them seamlessly without breaking).

---

## 1. Audit of `.tsj` Files & Image Asset Distribution (Requirement R3)

### 1.1 TSJ File Inventory Across Repository
A workspace-wide scan identified **501 total `.tsj` files** (268 unique TSJ file names) distributed across 10 directories:

| Directory Path | File Count | Notes / Status |
|----------------|-----------:|----------------|
| `tsj/` (`res://tsj/`) | 233 | Primary target folder. Contains 233 TSJ files and 321 PNG images. |
| `maps/backdrops/level1/` | 231 | Duplicate TSJ files from legacy Android assets. 197 are identical to `tsj/`, 34 differ in image paths or gids. |
| `maps/backdrops/` | 15 | Root backdrop TSJs (`xarng.tsj`, `xbigend.tsj`, `xgigend.tsj`, `xmedend.tsj`, etc.). |
| `maps/tilesets/personages/xmedend/` | 11 | Character TSJ variants (`xmedend_walk.tsj`, `xmedend_shoot_front.tsj`, etc.). |
| `maps/tilesets/objets/xskynt2/` | 4 | Object TSJs (`xskynt2_00.tsj`, `xskynt2_01.tsj`, etc.). |
| `maps/tilesets/objets/xskydoor/` | 2 | Door TSJs (`xskydoor_00.tsj`, `xskydoor_01.tsj`). |
| `maps/tilesets/objets/xskynt1/` | 2 | Sky TSJs (`xskynt1.tsj`, `xskynt1_03.tsj`). |
| `maps/tilesets/decors/xskynt3/` | 1 | Decor TSJ (`xskynt3_00.tsj`). |
| `maps/animations/xenfwrd2/` | 1 | Animation TSJ (`xenfwrd2.tsj`). |
| `maps/` | 1 | Master tileset (`Terminator.tsj`). |
| **Total** | **501** | **268 unique TSJ filenames across workspace.** |

### 1.2 Comparison between `maps/backdrops/level1/` and `tsj/`
- **In both directories**: 231 TSJ files.
- **Identical contents**: 197 TSJ files are byte-for-byte identical (`SHA-256` match).
- **Differing contents**: 34 TSJ files differ. The `tsj/` versions contain co-located image paths or updated tile properties.
- **Only in `tsj/`**: 2 files (`xgigend.tsj`, `xt100sms_effect.tsj`).
- **Outside both `maps/backdrops/level1/` and `tsj/`**: 37 TSJ files located in `maps/backdrops/`, `maps/tilesets/`, `maps/animations/`, and `maps/`.

### 1.3 Audit of PNG Images & Image Path References in TSJ Files
- Total PNG images in repository: **2,026 files** (1,252 unique filenames).
- In `tsj/` (`res://tsj/`): **321 PNG files** are co-located alongside the TSJ files.
- In TSJ JSON definitions across the repository, 659 total image references were evaluated:
  1. **Co-located / Filename-only** (e.g. `"image": "xarng.png"` or `"image": "frame_0000.png"`): **202 references**. Resolves cleanly when TSJ and PNG are in `res://tsj/`.
  2. **Relative project paths to `maps/`** (e.g. `"image": "../../animations/xarng/xarng_idle.png"`): **180+ references**. Points to `maps/animations/` or `maps/tilesets/`.
  3. **Broken/External legacy paths** (e.g. `"image": "../../../../../../../../t2_extracted/..."`): **23 references**. Points to external folders outside the git repository.

---

## 2. Audit of `.tmj` Files & Tiled Project References (Requirement R4)

### 2.1 TMJ Map Audit
The workspace contains **11 `.tmj` map files** located in `maps/backdrops/level1/`:
1. `t2_hideout.tmj`
2. `t2_stage3.tmj`
3. `t2_starter_blank.tmj`
4. `t2_starter_canvas.tmj`
5. `t2_testchamber.tmj`
6. `t2_xfback2.tmj`
7. `t2_xl1bck.tmj`
8. `t2_xl1bck1.tmj`
9. `t2_xl4skynt1.tmj`
10. `t2_xroad.tmj`
11. `exported/t2_starter_blank_embeded.tmj`

### 2.2 TMJ Tileset Reference Breakdown
In the 10 root level TMJ map files, tilesets are referenced in the `"tilesets"` JSON array via `"source"` properties:
- **Legacy Android project references**: 8 TMJ files (`t2_hideout.tmj`, `t2_stage3.tmj`, `t2_testchamber.tmj`, `t2_xfback2.tmj`, `t2_xl1bck.tmj`, `t2_xl1bck1.tmj`, `t2_xl4skynt1.tmj`, `t2_xroad.tmj`) contain external relative paths pointing to the old Android directory:
  - `"source": "../../../../app/src/main/assets/maps/backdrops/level1/test_enemies_collection.tsj"`
  - `"source": "../../../../app/src/main/assets/maps/backdrops/level1/xtinhk_00.tsj"`
  - `"source": "../../../../app/src/main/assets/maps/backdrops/level1/xmidhk_00.tsj"`
  - `"source": "../../../../app/src/main/assets/maps/backdrops/level1/xbighk.tsj"`
  - `"source": "../../../../app/src/main/assets/maps/backdrops/level1/xfrdfhk_composite_demo.tsj"`
  - `"source": "../../../../app/src/main/assets/maps/backdrops/level1/xl1ghk_assembled_preview.tsj"`
- **Co-located level1 references**: 2 TMJ files (`t2_starter_blank.tmj`, `t2_starter_canvas.tmj`) reference tilesets in the same directory:
  - `"source": "test_enemies_collection.tsj"`
  - `"source": "level1_decor.tsj"`

### 2.3 Required TMJ Path Updates for `res://tsj/`
To point `.tmj` files located in `res://maps/backdrops/level1/` to TSJ tilesets isolated in `res://tsj/`:
- **Relative Path Calculation**:
  - From `maps/backdrops/level1/`:
    - `..` -> `maps/backdrops/`
    - `../..` -> `maps/`
    - `../../..` -> root (`T2-ArcadeGodot/`)
    - `../../../tsj/<filename>.tsj` -> `tsj/<filename>.tsj`
- **Target `"source"` format**:
  - `"source": "../../../tsj/test_enemies_collection.tsj"`
  - `"source": "../../../tsj/level1_decor.tsj"`
  - `"source": "../../../tsj/xtinhk_00.tsj"`
  - `"source": "../../../tsj/xmidhk_00.tsj"`
  - `"source": "../../../tsj/xbighk.tsj"`
  - `"source": "../../../tsj/xfrdfhk_composite_demo.tsj"`
  - `"source": "../../../tsj/xl1ghk_assembled_preview.tsj"`

---

## 3. Godot 4 Import Pipeline Analysis (YATI Importer)

### 3.1 Importer Discovery
`project.godot` configures the YATI plugin (`res://addons/YATI/plugin.cfg`):
```ini
[editor_plugins]
enabled=PackedStringArray("res://addons/AsepriteWizard/plugin.cfg", "res://addons/YATI/plugin.cfg", "res://addons/addons/nklbdev.aseprite_importers/plugin.cfg")
```

### 3.2 YATI Import Mechanism
- **Extension Recognition**: `addons/YATI/Importer.gd` registers extensions `["tmx", "tmj"]`.
- **Import Flow**:
  1. Godot scans `.tmj` files (e.g. `res://maps/backdrops/level1/t2_xl1bck1.tmj`).
  2. `TilemapCreator.gd` sets `_base_path = source_file.get_base_dir()` (`res://maps/backdrops/level1`).
  3. `TilesetCreator.gd` loads each TSJ from `_base_path.path_join(tile_set["source"])`.
     When `"source"` is `"../../../tsj/test_enemies_collection.tsj"`, Godot canonicalizes `res://maps/backdrops/level1/../../../tsj/test_enemies_collection.tsj` to `res://tsj/test_enemies_collection.tsj`.
  4. `TilesetCreator.gd` computes `_base_path_tileset = "res://tsj"`.
  5. `DataLoader.load_image(tile_set["image"], _base_path_tileset)` loads the image relative to `res://tsj`.
  6. Scene generated as `.tscn` resource in Godot `.godot/imported/`.

### 3.3 Tiled Project Configuration (`levels.godot.tiled-project`)
- `maps/backdrops/levels.godot.tiled-project` currently contains:
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
- Because `"folders"` is set to `["."]`, opening `levels.godot.tiled-project` in Tiled only exposes `maps/backdrops/` in Tiled's sidebar view.
- **Required Update for Tiled**:
  Update `"folders"` in `levels.godot.tiled-project` to include `../../tsj`:
  ```json
  "folders": [
      ".",
      "../../tsj"
  ]
  ```
  This ensures Tiled displays both the level maps and the isolated `tsj` tileset directory.

---

## 4. Implementation Step-by-Step Action Plan (for Implementer)

### Step 1: TSJ Consolidation to `res://tsj/`
1. Copy the 37 TSJ files located outside `tsj/` (in `maps/backdrops/`, `maps/tilesets/`, `maps/animations/`, `maps/`) into `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj\`.
2. For the 34 differing TSJ files between `maps/backdrops/level1/` and `tsj/`, verify that `tsj/` versions are preserved as the single source of truth.
3. Ensure all PNG images referenced by TSJs are present in `res://tsj/` (or correct relative paths from `res://tsj/` are set).
4. Update any `"image"` references inside `.tsj` JSON files in `res://tsj/` pointing to external paths (`../../../../../../../../t2_extracted/...`) or outdated relative paths to point to co-located image files in `res://tsj/`.

### Step 2: Update TMJ Tileset References
1. In all 10 `.tmj` files under `maps/backdrops/level1/`:
   Replace any `"source"` containing `app/src/main/assets/maps/backdrops/` or co-located level1 TSJ names with `"../../../tsj/<tsj_filename>"`.
2. Example script edit for `.tmj` JSON:
   `"source": "../../../../app/src/main/assets/maps/backdrops/level1/xtinhk_00.tsj"` -> `"source": "../../../tsj/xtinhk_00.tsj"`.

### Step 3: Update Tiled Project File
1. Edit `maps/backdrops/levels.godot.tiled-project` to update `"folders"`:
   `"folders": [ ".", "../../tsj" ]`.

### Step 4: Cleanup Duplicate TSJs (Post-Verification)
1. After verifying Godot import and Tiled editor functionality, delete or archive the duplicate `.tsj` files in `maps/backdrops/level1/` and other subdirectories to prevent path drift.

---

## 5. Verification Matrix

| Requirement | Target File / Area | Verification Test | Expected Result |
|-------------|--------------------|-------------------|-----------------|
| R3 (TSJ Isolation) | `res://tsj/` | Inspect `tsj/` directory contents | All unique TSJs present in `tsj/`, image references valid |
| R4 (TMJ References) | `.tmj` files in `maps/backdrops/level1/` | Audit `"source"` fields in JSON | All tileset sources start with `"../../../tsj/"` and file exists |
| R4 (Godot Import) | Godot 4 / YATI Importer | Run Godot headless/import check or YATI loader | Maps import cleanly without missing tileset errors |
| R4 (Tiled GUI) | `levels.godot.tiled-project` | Check project file `folders` array | Contains `.` and `../../tsj` |

