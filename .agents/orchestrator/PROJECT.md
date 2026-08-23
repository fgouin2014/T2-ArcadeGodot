# Project Architecture & Plan: T2-ArcadeGodot

## Architecture Overview
This project targets Godot 4 map architecture, enemy placement & activation, TSJ tileset isolation, and Tiled import integration for T2-ArcadeGodot.

## Requirements Summary
- R1: Placement Direct et Déclenchement d'Ennemis (`xgigend.tscn` in `.tscn` maps with `VisibleOnScreenNotifier2D` camera triggering).
- R2: Niveaux à Parallax Perpétuel (`t2_stage3` & `t2_xroad` looping parallax until Boss defeat).
- R3: Sauvegarde et Isolation des Tuiles TSJ (move/group all `.tsj` files and associated images in `res://tsj/` / `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj\`).
- R4: Intégration du projet Tiled `levels.godot.tiled-project` for Godot 4 TMJ/TSJ import pipeline.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | TSJ Isolation & Tiled Integration | Isolate all `.tsj` tiles and images to `tsj/`, update Godot import pipeline & `levels.godot.tiled-project` | None | DONE |
| 2 | Direct Enemy Placement & Triggering | Place enemy scenes (`xgigend.tscn`) in `.tscn` maps, configure `VisibleOnScreenNotifier2D` auto-triggering | M1 | DONE |
| 3 | Perpetual Parallax Looping | Implement perpetual parallax looping for `t2_stage3` and `t2_xroad`, stopping only upon Boss defeat | M1 | DONE |
| 4 | Verification & Acceptance Gate | E2E verification of enemy activation, perpetual parallax, tsj isolation, and Godot 4 project load | M1, M2, M3 | DONE |

## Code Layout
- Root project directory: `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\`
- TSJ Directory: `c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj\`
- Maps / Scenes / Scripts: `maps/`, `Script/`, `GDScript/`, `aseprite/`, etc.
