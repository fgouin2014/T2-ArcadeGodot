# Project Rules: T2-ArcadeGodot (Godot 4 Engine)

## Architecture & Code Structure

- **Character & Actor Scenes**: Centralized in `res://aseprite/`. Every actor `.tscn` inherits a modular script class from `res://Script/`.
- **Modular Scripts (`res://Script/`)**:
  - `ActorBase` (`actor_base.gd`): Core class for screen detection (`VisibleOnScreenNotifier2D`), activation delay (`delai_activation_sec`), health (`pv_max`), shot impacts, bidirectional movement (`direction_deplacement`), and `inverser_visuel` Flip H toggle.
  - `PopupEnemy` (`popup_enemy.gd`): Séquence popup (`popup` ➔ `shoot` ➔ `retract`) pour `xgigend`, `xt100big`, `xarng`.
  - `WalkingEnemy` (`walking_enemy.gd`): Déplacement et tir continu au sol.
  - `CivilianAlly` (`civilian_ally.gd`): Civils non-attaquants (`xsarah`, `xjohn`).
  - `FlyingHK` (`flying_hk.gd`): Hunter-Killers (`xbighk` horizontal et `xfrdfhk` cabrage/montée y=0 avec `xmissile`).
  - `ProjectileActor` (`projectile_actor.gd`): Projectiles balistiques (`xflask`, `xengren`, `xmissile`).

## Tiled & Map Asset Organization

- Tiled Project: `res://maps/backdrops/levels.godot.tiled-project`.
- Gameplay Maps & Backdrop Scenes: Stored cleanly in `res://maps/` or subdirectories.
- Scene Naming Convention:
  - Scenery / Backdrop scenes: `t2_xl1bck1.tscn`, `t2_hideout.tscn`, `t2_stage3.tscn`, `t2_xl4skynt1.tscn`, `t2_xroad.tscn`, `t2_xfback2.tscn`, `t2_testchamber.tscn`.
  - Master Gameplay Scenes: `level1.tscn`, `level2.tscn`, `level3.tscn`, `level4.tscn`, `level6.tscn`, `level7.tscn`, `testchamber.tscn`.

## Camera Scroll Speed Formula

For constant scroll speed on level rails:

- Distance in columns: D_cols = D_px / Tile_Width
- Target speed: Speed_target = D_cols / (T * 60)
- If map height = 1 tile: scroll_speed = Speed_target / 0.008
- If map height > 1 tile: scroll_speed = Speed_target / 0.04

## Engine Executable Path

- **Godot 4.7 Executable**: `E:\Godot_v4.7.1-stable\Godot_v4.7.1-stable_win64.exe`
- **Godot 4.7 Executable**: `E:\Godot_v4.7.1-stable\godot.exe`
- **Aseprite Executable Path** : `C:\androidProject\aseprite\build\bin\aseprite.exe`

