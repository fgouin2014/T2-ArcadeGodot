# Handoff Report: Requirement R2 (Perpetual Parallax & Boss Looping)

## 1. Observation

### Codebase Audit Findings
- **`maps/t2_stage3.tscn`**:
  - Inherits from backdrop `res://maps/backdrops/level1/t2_stage3.tmj` (Line 3).
  - Instantiates `Camera2D` (Lines 8-14) with script `res://Script/camera_auto_scroll.gd`.
  - `Camera2D` limits: `limit_left = 0`, `limit_right = 5632`, `limit_top = 0`, `limit_bottom = 175`.
  - Spawners included: `Spawner_xbigend_1` (x: 400, y: 100), `Spawner_xswat_1` (x: 800, y: 100).
  - TMJ Map Dimensions: 3 tiles wide × 1 tile high (tile width 128px) = **384px total width**.

- **`maps/t2_xroad.tscn`**:
  - Inherits from backdrop `res://maps/backdrops/level1/t2_xroad.tmj` (Line 3).
  - Instantiates `Camera2D` (Lines 8-15) with script `res://Script/camera_auto_scroll.gd`.
  - `Camera2D` limits: `limit_left = 0`, `limit_right = 5632`, `limit_top = 0`, `limit_bottom = 175`.
  - Spawners included: `Spawner_xarng_1` (x: 700, y: 100), `Spawner_xswat_1` (x: 1200, y: 100).
  - TMJ Map Dimensions: 12 tiles wide × 1 tile high (tile width 256px) = **3072px total width**.

- **Imported ParallaxBackground Structure (`.godot/imported/`)**:
  - Both `t2_stage3.tmj` and `t2_xroad.tmj` import into Godot as a `ParallaxBackground` root node containing `ParallaxLayer` children:
    - `sol_0 (PL)`, `sol_1 (PL)`, `sol_2 (PL)`, `sol_3 (PL)`, `skyline_0 (PL)`, `sky_0 (PL)`, `skyblack_ (PL)`.
  - `ParallaxLayer` `motion_scale` values range from `Vector2(0, 0)` up to `Vector2(0.8, 0)`.
  - **CRITICAL DEFECT**: `motion_mirroring` is `Vector2(0, 0)` on ALL layers. No horizontal tiling/mirroring is configured in the TMJ or scene files.
  - As a result, when the camera auto-scrolls past 384px (Stage 3) or 3072px (Xroad), the background completely disappears, leaving black void.

- **Camera Auto-Scroll Mechanism (`Script/camera_auto_scroll.gd`)**:
  - `_physics_process(delta)` (Line 56):
    - Increments `position.x += vitesse_auto * delta` when `not en_train_de_glisser and not verrouillee`.
    - Clamps `position.x` between `limit_left + demi_ecran` and `limit_right - demi_ecran` (Lines 70-73).
  - Functions `bloquer_camera()` and `debloquer_camera()` toggle `verrouillee`.

- **Boss & Enemy Lifecycle (`Script/xgigend.gd` & `Script/main.gd`)**:
  - Enemies transition: `popup` -> `shoot` (looping for `duree_attaque_secondes = 9.0`) -> `retract` -> `queue_free()`.
  - Neither `xgigend.gd` nor `main.gd` currently emit or handle a `boss_defeated` or `boss_vaincu` signal.

---

## 2. Logic Chain

1. **Observation**: `t2_stage3` and `t2_xroad` backgrounds end at 384px and 3072px respectively because `ParallaxLayer.motion_mirroring.x` is `0.0`.
   **Inference**: To enable perpetual parallax scrolling without black borders, `motion_mirroring.x` must equal the backdrop pattern repeat width (`384.0` for `t2_stage3`, `3072.0` for `t2_xroad`).

2. **Observation**: `Camera2D` in `camera_auto_scroll.gd` clamps `position.x` at `limit_right - demi_ecran` (5632px).
   **Inference**: For perpetual/infinite looping, `camera_auto_scroll.gd` must support an active looping state (`mode_perpetuel = true`) where `limit_right` clamping is disabled/bypassed, allowing `position.x` to increase indefinitely.

3. **Observation**: `xgigend.gd` calls `queue_free()` upon completing retract/defeat, but does not notify the camera or level manager.
   **Inference**: To stop perpetual parallax scrolling when the Boss is defeated:
   - A signal `signal boss_defeated` (or `tree_exited` listener) must be emitted when the Boss entity is defeated.
   - `camera_auto_scroll.gd` must listen to `boss_defeated` and invoke `bloquer_camera()` (or set `vitesse_auto = 0.0` / disable `mode_perpetuel`).

---

## 3. Caveats

- **Tiled Importer Regeneration**: Modifying imported files in `.godot/` directly is ephemeral (re-generated on reimport). The solution should configure `motion_mirroring` programmatically in script (e.g. in `_ready()` of `camera_auto_scroll.gd` or a level initializer script) or in the inherited `.tscn` files.
- **Boss Enemy Identity**: Different stages use different enemy types as bosses (`xbigend` in Stage 3, `xarng` in Xroad, `xgigend`, etc.). The defeat signal must be generalized or attached to the spawned boss instance in `main.gd`.

---

## 4. Conclusion & Recommended Implementation Plan

### Recommendation 1: Dynamic Parallax Motion Mirroring Setup
In `camera_auto_scroll.gd` (or a stage helper script attached to the `ParallaxBackground`), automatically compute or set `motion_mirroring.x` for all child `ParallaxLayer` nodes on `_ready()`:

```gdscript
# In camera_auto_scroll.gd or stage script
@export var largeur_boucle_parallax : float = 384.0 # 384.0 for t2_stage3, 3072.0 for t2_xroad

func _ready() -> void:
    # Existing setup...
    configurer_parallax_looping()

func configurer_parallax_looping() -> void:
    var parent_node = get_parent()
    if parent_node is ParallaxBackground:
        for child in parent_node.get_children():
            if child is ParallaxLayer:
                child.motion_mirroring = Vector2(largeur_boucle_parallax, 0)
```

### Recommendation 2: Perpetual Auto-Scroll Mode
Update `camera_auto_scroll.gd` to include a `mode_perpetuel` toggle and handle boss defeat:

```gdscript
@export var mode_perpetuel : bool = true
var boss_vaincu : bool = false

func stopper_scroll_boss_defait() -> void:
    boss_vaincu = true
    verrouillee = true
    print("[CAMÉRA] Boss vaincu ! Scroll perpétuel arrêté.")

func _physics_process(delta: float) -> void:
    if not is_inside_tree(): return
    temps_ecoule += delta

    if not en_train_de_glisser and not verrouillee and temps_ecoule >= delai_depart:
        position.x += vitesse_auto * delta
        position.x = round(position.x)
    
    var demi_ecran = largeur_lucarne / 2
    if position.x < limit_left + demi_ecran:
        position.x = limit_left + demi_ecran
    elif not mode_perpetuel and position.x > limit_right - demi_ecran:
        position.x = limit_right - demi_ecran
```

### Recommendation 3: Boss Defeat Signal Integration
1. Add `signal boss_defeated` in boss enemy scripts (`xgigend.gd`, `xbigend.gd`, etc.) or track boss instance destruction in `main.gd`.
2. Connect boss defeat to camera stop:
   ```gdscript
   boss_instance.boss_defeated.connect(camera.stopper_scroll_boss_defait)
   ```

---

## 5. Verification Method

1. **Scene Verification**:
   - Inspect `maps/t2_stage3.tscn` and `maps/t2_xroad.tscn` in Godot editor or run Godot debug.
2. **Parallax Looping Test**:
   - Launch `t2_stage3` or `t2_xroad` from `Main.tscn`.
   - Observe camera auto-scrolling beyond 384px (Stage 3) and 3072px (Xroad).
   - Verify background layers loop seamlessly with no black gaps or visual popping.
3. **Boss Defeat Test**:
   - Trigger boss defeat (or simulate `boss_defeated` signal).
   - Verify camera auto-scroll immediately stops and locks in position.
