# Original User Request

## Initial Request — 2026-07-30T20:25:27Z

Architecture et intégration du système de cartes, placement direct d'ennemis, défilement perpétuel et vagues dans T2-ArcadeGodot.

Working directory: c:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot

## Requirements

### R1. Placement Direct et Déclenchement d'Ennemis
Intégration et placement direct des scènes d'ennemis (ex: `xgigend.tscn`) dans les cartes `.tscn` avec déclenchement automatique par la caméra via `VisibleOnScreenNotifier2D`.

### R2. Niveaux à Parallax Perpétuel (Stage 3 & Xroad)
Support du défilement perpétuel/bouclé (Looping Parallax) pour `t2_stage3` et `t2_xroad`, s'arrêtant uniquement lors de la défaite du Boss.

### R3. Sauvegarde et Isolation des Tuiles TSJ
Regroupement et mise à l'abri de l'ensemble des fichiers de tuiles `.tsj` et images associées dans le dossier dédié `tsj/` (`C:\androidProject\lastchance\DukeSoundboard\T2-ArcadeGodot\tsj`), indépendamment du pipeline actif.

### R4. Intégration du projet Tiled `levels.godot.tiled-project`
Support et compatibilité de la structure d'importation TMJ/TSJ Tiled spécifiquement adaptée pour Godot 4.

## Acceptance Criteria

### Verification
- [ ] Les ennemis placés directement dans les scènes `.tscn` déclenchent leurs séquences uniquement lorsque la caméra les atteint.
- [ ] Les cartes `t2_stage3` et `t2_xroad` défilent en boucle continue jusqu'à l'élimination du Boss.
- [ ] Les fichiers `.tsj` et leurs images sont isolés en sécurité dans `res://tsj/`.
- [ ] Aucun crash ou erreur de fichier manquant lors de l'ouverture de Godot 4.
