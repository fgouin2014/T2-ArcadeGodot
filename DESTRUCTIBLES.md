# Guide : Créer un élément destructible

> Utilise le script générique `res://Script/breakable_prop.gd`.  
> **Aucun code à écrire** pour ajouter un nouvel objet destructible.

---

## Structure de scène requise

```
MaPropScene.tscn  (Node2D)          ← breakable_prop.gd attaché ici
├── Morceau1  (Node2D)
│   ├── HitArea        (Area2D)     ← NOM EXACT requis
│   │   └── CollisionShape2D
│   └── DamagedSprite  (Sprite2D)   ← NOM EXACT requis
├── Morceau2  (Node2D)
│   ├── HitArea        (Area2D)
│   │   └── CollisionShape2D
│   └── DamagedSprite  (Sprite2D)
└── ...
```

> `AnimatedSprite2D` est aussi accepté à la place de `Sprite2D`.

---

## Règles

| Règle | Détail |
|---|---|
| **Noms exacts** | `HitArea` et `DamagedSprite` — cherchés par nom dans chaque morceau |
| **Pas de script** | Les morceaux enfants n'ont pas besoin de script |
| **Explosion** | L'effet est défini via l'export var `explosion_scene` sur la racine |
| **Indépendant du level** | La scène peut être instanciée dans n'importe quel level |
| **Aseprite OK** | Les animations importées depuis `.ase` fonctionnent sans modification |

---

## Étapes rapides

1. **Créer la scène** — racine `Node2D`, attacher `breakable_prop.gd`
2. **Ajouter les morceaux** — un `Node2D` par morceau
3. **Dans chaque morceau**, ajouter :
   - `Area2D` nommé `HitArea` + `CollisionShape2D`
   - `Sprite2D` (ou `AnimatedSprite2D`) nommé `DamagedSprite`
4. **Définir l'export** `explosion_scene` dans l'Inspector (ex: `effet_explosion.tscn`)
5. **Instancier** dans le level — dans un `ParallaxLayer` ou en scène directe

---

## Pickups et Loot

`breakable_prop.gd` intègre 3 modes pour faire spawner des pickups (`xpickup_XX`) :

| Mode | Configuration | Description |
|---|---|---|
| **1 — Aléatoire par pièce** | `pickup_scene` + `pickup_chance` (ex: `0.3`) | Chaque morceau cassé a X% de chance de spawner le pickup. |
| **2 — Sur groupe complet** | `pickup_sur_groupe = true` + `pickup_scene` | Spawne 1 pickup quand **toutes** les pièces du prop sont détruites. |
| **3 — Enfant direct (Déterministe)** | Glisser la scène pickup sous un morceau (ex: `p1 > xpickup_12_shotgun_shell`) | Spawne obligatoirement le pickup dès que cette pièce précise est touchée/cassée (détection auto sans config). |

> Les 3 modes sont **totalement combinables** sur une même scène. Le pickup spawné est automatiquement rattaché à la racine du niveau (`current_scene`) pour conserver ses collisions et sa physique sans décalage de parallax.

---

## Comportement custom (avancé)

Si tu veux un comportement supplémentaire (flammes, loot, son unique…),
**étends** le script sans toucher à l'original :

```gdscript
# ma_prop_speciale.gd
extends "res://Script/breakable_prop.gd"

func casse_morceau(morceau: Node) -> void:
    super.casse_morceau(morceau)   # comportement de base
    # ton code ici
    spawn_loot(morceau.global_position)
```

---

## Exemples existants

| Scène | Description |
|---|---|
| `aseprite/effect/cluster_lab1.tscn` | Cluster labo — fenêtres cassables |
| `aseprite/effect/cluster_lab2.tscn` | Cluster labo — mobilier |
| `Script/breakable_window.gd` | Variante fenêtre (même interface) |
