# Guide d'Alignement et Pipeline Spritesheet (Aseprite CLI & Godot 4)

Ce document résume la méthodologie standardisée pour assembler, unifier et aligner les animations issues de sources Aseprite hétérogènes (différentes résolutions de canvas) afin de garantir un alignement parfait au sol et avec la `CollisionShape2D` dans Godot 4.

---

## 1. Problématique des canvas hétérogènes

Lorsqu'un personnage combine des animations provenant de fichiers `.ase` distincts :
- **Marche / Tir / Mort** (`xbigend.ase`) : Canvas **92 × 88 px** (sol à $y = 88$).
- **Chute complète** (`xendrop.ase`) : Canvas **36 × 144 px** (sol à $y = 144$).
- **Chute cadrée** (`xendropcropped.ase`) : Canvas **36 × 96 px** (sol à $y = 96$).

Par défaut, Godot centre chaque frame autour de $(0, 0)$ de son `AnimatedSprite2D`. Des hauteurs de frame différentes ($88$, $96$, $144$) placent donc la ligne de sol à des coordonnées $Y$ différentes ($+44$, $+48$, $+72$), provoquant un décalage visuel (pieds dans le vide ou enfoncés dans le sol).

---

## 2. Solution : Canvas unifié standardisé (92 × 144 px)

Toutes les frames de toutes les animations sont normalisées sur un canvas unique de **92 × 144 px** :
1. **Ancrage vertical** : Toutes les frames sont collées tout en bas du canvas ($y = 144$).
2. **Ancrage horizontal** : Toutes les frames sont centrées horizontalement ($x = 46$).

### Tableau des correspondances de collage
| Source | Taille originale | Position de collage sur canvas 92×144 | Marge haute ajoutée |
|---|---|---|---|
| `xbigend.ase` | 92 × 88 px | `(0, 56)` | 56 px |
| `xendropcropped.ase` | 36 × 96 px | `(28, 48)` | 48 px |
| `xendrop.ase` | 36 × 144 px | `(28, 0)` | 0 px |

---

## 3. Commandes Aseprite CLI

Exécutable utilisé :
```powershell
& "C:\androidProject\aseprite\build\bin\aseprite.exe"
```

### Export des frames unitaires
```powershell
& "C:\androidProject\aseprite\build\bin\aseprite.exe" -b source.ase --save-as temp_{frame00}.png
```

### Création du fichier .ase unifié
```powershell
& "C:\androidProject\aseprite\build\bin\aseprite.exe" -b unified_00.png unified_01.png ... --save-as xendrop_v2.ase
```

### Génération du spritesheet et du JSON de découpage
```powershell
& "C:\androidProject\aseprite\build\bin\aseprite.exe" -b xendrop_v2.ase --sheet xendrop_v2.png --data xendrop_v2.json --format json-array
```

---

## 4. Configuration dans Godot 4 (`xendrop_v2.tscn`)

### Positionnement des nœuds
- **Racine (`CharacterBody2D`)** : `position = (0, 0)`
- **`CollisionShape2D`** : `size = Vector2(36, 82)`
  - Haut de collision : $y = -41$
  - Bas de collision (sol) : $y = +41$
- **`AnimatedSprite2D`** : `position = Vector2(0, -31)`
  - Frame de hauteur 144 px (centre à $y = 72$).
  - Bas du sprite : $-31 + 72 = +41$ (s'aligne **exactement** avec le bas de la `CollisionShape2D`).

### Animations disponibles (48 frames au total)
| Animation | Plage de frames | Nb frames | Boucle | Vitesse |
|---|---|---|---|---|
| `walk_fwrd` | 0 .. 12 | 13 | Oui | 8.0 fps |
| `idle` | 13 | 1 | Oui | 8.0 fps |
| `shoot` | 14 .. 16 | 3 | Oui | 8.0 fps |
| `walk` | 17 .. 24 | 8 | Oui | 8.0 fps |
| `walk_shoot` | 25 .. 32 | 8 | Oui | 8.0 fps |
| `die` | 33 .. 37 | 5 | Non | 8.0 fps |
| `drop` | 38 .. 42 | 5 | Non | 8.0 fps |
| `xendrop` | 43 .. 47 | 5 | Non | 8.0 fps |

---

## 5. Comportement `drop_tir_face_puis_marche_stop_shoot`

Ce comportement (`EndropEnemy` / `WalkingEnemy`) orchestre la séquence suivante :
1. **Atterrissage (Drop)** : Exécute l'animation `drop` (ou `xendrop`) **1 seule fois** au début.
2. **Salve de face initiale** : Une fois au sol, joue `shoot` de face pour `nombre_de_tirs` coups.
3. **Boucle infinie tant que l'acteur est actif** :
   - Marche (`walk`) pendant `temps_entre_tirs` secondes.
   - Arrêt (`_arreter_deplacement()`).
   - Salve de face (`shoot`) pour `nombre_de_tirs` coups.
   - Pause courte, puis reprise de la marche.
