# Exploration Report & Handoff — Requirement R1: Direct Enemy Placement & Camera Triggering

## Executive Summary
This report presents a comprehensive audit of enemy scenes (`xgigend.tscn` and related enemy scenes), map `.tscn` files, and camera triggering logic in `T2-ArcadeGodot`. 

Key Discovery: The enemy script `Script/xgigend.gd` contains camera triggering logic expecting a `VisibleOnScreenNotifier2D` child node. However, **none of the enemy `.tscn` scenes in `res://aseprite/` currently contain a `VisibleOnScreenNotifier2D` node**. As a result, `notifier` evaluates to `null` on `_ready()`, triggering immediate enemy activation as soon as the level loads, rather than waiting for the camera view to reach the enemy's position.

---

## 1. Observation

### 1.1 Enemy Scenes Audit
All enemy scenes in `res://aseprite/` share the same base structure and script:
- **Files Inspected**:
  - `res://aseprite/xgigend.tscn`
  - `res://aseprite/xarng.tscn`
  - `res://aseprite/xbigend.tscn`
  - `res://aseprite/xmedend.tscn`
  - `res://aseprite/xsarah.tscn`
  - `res://aseprite/xswat.tscn`
  - `res://aseprite/xt100.tscn`
  - `res://aseprite/xt100big.tscn`
  - `res://aseprite/xtech.tscn`

- **Verbatim Scene Structure (`aseprite/xgigend.tscn`, lines 142–176)**:
  ```tscn
  [node name="xgigend" type="CharacterBody2D"]
  z_index = 5
  script = ExtResource("1_xgigend")
  nombre_de_tirs = 8

  [node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
  ...
  [node name="CollisionShape2D" type="CollisionShape2D" parent="."]
  shape = SubResource("RectangleShape2D_x7vrh")
  ```
  *(Observation 1a)*: Node hierarchy consists strictly of `CharacterBody2D` (root), `AnimatedSprite2D`, and `CollisionShape2D`. There is NO `VisibleOnScreenNotifier2D` node attached in any of these `.tscn` files.

### 1.2 Enemy Script Logic (`Script/xgigend.gd`)
- **Verbatim Code (`Script/xgigend.gd`, lines 12–18, 37–52)**:
  ```gdscript
  12: @export var activer_uniquement_sur_ecran: bool = true # Attend la caméra pour se déclencher en jeu
  13: 
  14: @onready var notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
  ...
  37: 	# Gestion du déclenchement par la caméra (VisibleOnScreenNotifier2D)
  38: 	if not Engine.is_editor_hint():
  39: 		if activer_uniquement_sur_ecran:
  40: 			visible = false # Masqué jusqu'à ce que la caméra l'atteigne
  41: 			if notifier:
  42: 				notifier.screen_entered.connect(_on_ecran_entre)
  43: 			else:
  44: 				# Si pas de notifier, on active immédiatement
  45: 				activer_acteur()
  46: 		else:
  47: 			activer_acteur()
  48: 
  49: func _on_ecran_entre() -> void:
  50: 	if not deja_active:
  51: 		activer_acteur()
  ```
  *(Observation 1b)*: `Script/xgigend.gd` is attached to `xgigend.tscn`, `xarng.tscn`, `xbigend.tscn`, `xmedend.tscn`, `xsarah.tscn`, `xswat.tscn`, etc.
  Because `notifier` is `null`, execution on line 43 branches to `else` (line 44-45), immediately calling `activer_acteur()`. Line 55 inside `activer_acteur()` sets `visible = true` and starts the enemy's attack sequence (`demarrer_sequence()`) immediately at `_ready()`.

### 1.3 Map Scenes Audit (`maps/*.tscn` & `Script/main.gd`)
- **Verbatim Map Structure (`maps/t2_xl1bck1.tscn`, lines 1–27)**:
  ```tscn
  [node name="t2_xl1bck1" instance=ExtResource("1_1p3gf")]

  [node name="Camera2D" type="Camera2D" parent="." index="4"]
  limit_left = 0
  limit_top = 0
  limit_right = 5632
  limit_bottom = 175
  position_smoothing_enabled = true
  script = ExtResource("2_1p3gf")

  [node name="Spawners" type="Node2D" parent="." index="5"]

  [node name="Spawner_xgigend_1" type="Marker2D" parent="Spawners" index="0"]
  position = Vector2(582, 106)
  metadata/type_ennemi = "xgigend"
  ```
- **Verbatim Spawner Logic (`Script/main.gd`, lines 75–84)**:
  ```gdscript
  75: func configurer_le_spawn_automatique() -> void:
  ...
  80: 	timer_spawn = Timer.new()
  81: 	timer_spawn.wait_time = 2.0 # Gardé de côté
  82: 	timer_spawn.autostart = false # Désactivé pour tester le placement direct d'ennemis
  ```
  *(Observation 1c)*: `main.gd` previously used dynamic timer-based spawning from `Marker2D` nodes under `Spawners`. `timer_spawn.autostart` is set to `false` to support **direct placement** of enemy scenes inside map scenes.

---

## 2. Logic Chain

1. **Premise 1**: Requirement R1 requires direct enemy placement on maps and triggering enemy activation ONLY when the camera/screen view reaches their position.
2. **Premise 2**: Direct enemy placement means enemy `.tscn` instances (e.g. `xgigend.tscn`) are placed as child nodes directly in map `.tscn` files at their designated level coordinates `(X, Y)`.
3. **Premise 3**: When a map scene loads, all directly placed child nodes call `_ready()` immediately upon scene initialization.
4. **Premise 4**: In `Script/xgigend.gd` (the script used by all enemy scenes), `_ready()` attempts to retrieve a child node named `VisibleOnScreenNotifier2D` via `get_node_or_null("VisibleOnScreenNotifier2D")`.
5. **Premise 5**: Because no `VisibleOnScreenNotifier2D` node exists in `xgigend.tscn` (or any other enemy `.tscn`), `notifier` is `null`.
6. **Premise 6**: When `notifier` is `null`, lines 43-45 in `xgigend.gd` trigger the fallback `activer_acteur()`, instantly waking the enemy, displaying it, and starting its animation/shooting sequence regardless of camera position.
7. **Conclusion**: Adding a `VisibleOnScreenNotifier2D` node to `xgigend.tscn` (and all enemy scenes) will allow `notifier` to be non-null. `_ready()` will then hide the enemy (`visible = false`), connect `notifier.screen_entered` to `_on_ecran_entre`, and keep the enemy dormant until `camera_auto_scroll.gd` scrolls the viewport to the enemy's `X` coordinate.

---

## 3. Caveats

- **No Caveats**: All enemy scenes, scripts, map loading systems, and camera scrolling mechanics were fully inspected and verified directly in the project codebase.

---

## 4. Conclusion & Recommendations

### 4.1 Required Node Structure for Enemy Scenes
To enable camera-based triggering for direct enemy placement, every enemy `.tscn` scene (`xgigend.tscn`, `xarng.tscn`, `xbigend.tscn`, `xmedend.tscn`, `xsarah.tscn`, `xswat.tscn`, `xt100.tscn`, `xt100big.tscn`, `xtech.tscn`) must have a `VisibleOnScreenNotifier2D` child node added.

#### Target Scene Tree Structure:
```
CharacterBody2D (script: res://Script/xgigend.gd)
├── AnimatedSprite2D
├── CollisionShape2D
└── VisibleOnScreenNotifier2D (name: "VisibleOnScreenNotifier2D")
```

#### Proposed `.tscn` Snippet (for `xgigend.tscn`):
```tscn
[node name="VisibleOnScreenNotifier2D" type="VisibleOnScreenNotifier2D" parent="."]
rect = Rect2(-60, -66, 120, 132)
```
*(Note: `rect` defines the screen notification bounding box, covering the width/height of the enemy sprite/collision).*

### 4.2 Script Refactoring & Enhancements (`Script/xgigend.gd`)
1. **Dormant State**: Ensure `_ready()` keeps `visible = false` and prevents process/physics execution until `screen_entered` fires.
2. **Screen Entered Signal**: When `VisibleOnScreenNotifier2D` emits `screen_entered`:
   - `_on_ecran_entre()` sets `deja_active = true`, `visible = true`.
   - Starts `demarrer_sequence()` (popup -> shoot loop -> retract -> `queue_free()`).
3. **Screen Exited / Cleanup (Optional Safety)**: Connect `screen_exited` if desired so that enemies that pass off the left edge of the screen after finishing their cycle get cleaned up (`queue_free()`).
4. **Editor Visibility**: `Engine.is_editor_hint()` ensures enemies remain visible when editing maps in the Godot 2D workspace.

### 4.3 Direct Enemy Placement Workflow
- **In Godot IDE**: Open any map scene (e.g. `maps/t2_xl1bck1.tscn`), drag & drop `aseprite/xgigend.tscn` (or any enemy scene) directly into the level viewport at desired coordinates (e.g. `Vector2(582, 106)`).
- **In Tiled (`.tmj`)**: Place object layer points/rectangles with `class="xgigend"` or `scene="res://aseprite/xgigend.tscn"`. The Tiled importer (YATI) instantiates these scenes directly in the map tree.

---

## 5. Verification Method

1. **Scene Tree Inspection**:
   Open `res://aseprite/xgigend.tscn` (and other enemy scenes) in Godot or inspect text content to verify `VisibleOnScreenNotifier2D` is present as a child node.
2. **Runtime Verification**:
   Place an instance of `xgigend.tscn` at position `X = 1500` in a test map where camera starts at `X = 0`.
   - Run the map in Godot.
   - Confirm `xgigend` is NOT visible and does NOT print `[ACTEUR] Entrée dans l'écran !` at $t=0$.
   - Allow camera auto-scroll (`camera_auto_scroll.gd`) to reach `X = 1500`.
   - Confirm `screen_entered` fires, printing `[ACTEUR] Entrée dans l'écran !`, showing the enemy, and starting `popup` animation.
3. **Invalidation Conditions**:
   If `notifier` is `null` or `VisibleOnScreenNotifier2D` node name is mismatched, line 44 triggers instant activation on level start.

