# Guide de Gestion des Tilesets Tiled (.tsj)

Ce document décrit les règles et conventions de structure appliquées aux fichiers `.tsj` (JSON Tilesets) utilisés dans les cartes de jeu de Tiled du projet.

## 1. Consolidation des Fichiers TSJ
Pour simplifier l'organisation et réduire le nombre de tilesets dans l'éditeur de Tiled, les animations individuelles de chaque modèle (personnage) partageant la même dimension de grille sont regroupées dans un unique fichier `.tsj` portant le nom du modèle.

### Exemple : `xbigend3` (Dimension 34x88)
Auparavant, chaque état possédait son propre fichier :
* `xbigend3_idle_front.tsj`
* `xbigend3_shoot_front.tsj`

Ils sont désormais regroupés dans un unique fichier consolidated :
* [xbigend3.tsj](file:///C:/androidProject/lastchance/DukeSoundboard/app/src/main/assets/maps/backdrops/level1/xbigend3.tsj)

---

## 2. Structure et Format d'un TSJ Consolidé
Chaque fichier TSJ consolidé référence une image combinée (`_combined.png`) contenant toutes les frames des différentes animations alignées horizontalement.

```json
{
  "columns": 3,
  "image": "xbigend3_combined.png",
  "imageheight": 88,
  "imagewidth": 102,
  "margin": 0,
  "name": "xbigend3",
  "spacing": 0,
  "tilecount": 3,
  "tileheight": 88,
  "tilewidth": 34,
  "type": "tileset",
  "version": "1.10",
  "tiles": [
    {
      "id": 1,
      "animation": [
        { "duration": 100, "tileid": 1 },
        { "duration": 100, "tileid": 2 }
      ]
    }
  ]
}
```

### Propriétés Clés :
* **`image`** : Pointeur vers l'image master combinant horizontalement toutes les poses (ex: `xbigend3_combined.png`).
* **`tilewidth` / `tileheight`** : Les dimensions d'une tuile de grille unique du modèle.
* **`tiles`** : Liste définissant les animations de tuiles. Chaque animation est assignée à un `id` de départ, et liste ses frames via des `tileid` et des durées en millisecondes.

---

## 3. Ajout d'un Nouveau Modèle
Lorsque vous ajoutez de nouvelles animations pour un modèle existant ou créez un nouveau personnage :
1. Assurez-vous d'exporter les frames d'animation en PNG avec des dimensions de tuiles identiques.
2. Lancez le script de consolidation [consolidate_tsj.py](file:///C:/androidProject/lastchance/t2_extracted/T2_sprites_truePalette/consolidate_tsj.py) pour reconstruire automatiquement le fichier `.tsj` consolidé et l'image `.png` combinée.
3. Utilisez le fichier `.tsj` unique comme source de tileset dans Tiled et placez les objets en pointant sur les bons identifiants de tuiles (GIDs) correspondants aux animations voulues.
