# Analyse des Machines à États — 4 Véhicules T2 (`xcopter`, `xjug`, `xsvan`, `xtruck`)
**Source:** `VehicleChaseView.kt` (1971 lignes, 80 Ko)  
**Cible:** Godot 4.7

> [!IMPORTANT]
> Les maps `t2_stage3.tmj` et `t2_xroad.tmj` n'ont **aucun véhicule placé** dans leurs couches `Entities`. Toute la logique est hardcodée dans `VehicleChaseView.kt`. Les 4 véhicules distincts sont :
> - **`xcopter` / `xbighk`** : Boss Hélico / HK-Aerial
> - **`xjug`** : Boss Camion Benne / Juggernaut
> - **`xsvan`** : Fourgonnette SWAT du joueur (Level 1 & Level 2 / xroad)
> - **`xtruck`** : Pick-up / Camion du joueur (Level 3 / stage3)

---

## 1. Machine à États Globale — `BossPhase`

```
COPTER ──(copterHp <= 0)──► TRANSITION ──(timer <= 0)──► JUGGERNAUT ──(jugHp <= 0)──► VICTORY_TRANSITION ──(timer <= 0)──► VICTORY
```

| Phase | Durée | Condition de sortie |
|---|---|---|
| `COPTER` | Indéfinie | `copterHp <= 0` |
| `TRANSITION` | 360 frames (6 sec) | Timer = 0 |
| `JUGGERNAUT` | Indéfinie | `jugHp <= 0` |
| `VICTORY_TRANSITION` | 480 frames (8 sec) | Timer = 0 |

> **Note :** Toutes les durées sont en **frames à 60 FPS**. Convertir en secondes : `frames / 60`.

---

## 2. `xcopter` — Machine à États

### Variables

| Variable | Valeur | Description |
|---|---|---|
| `copterHp` | 1000 | Points de vie initiaux |
| `maxCopterHp` | 1000 | HP max |
| `copterTimer` | 0f | Horloge du mouvement sinusoïdal |
| `copterAttackTimer` | 0f | Horloge des tirs |
| `copterX` | `width * 0.5f` | Position X initiale |
| `copterY` | `height * 0.3f` | Position Y initiale |

### Mouvement (Phase `COPTER`)

```kotlin
copterTimer += 0.02f * dt                          // dt = 1.0f à 60fps
copterX = width * 0.5f + cos(copterTimer * 0.6f) * 160f
copterY = height * 0.3f + sin(copterTimer) * 50f
```

**En Godot (delta = 1/60) :**
```gdscript
timer += 0.02 * delta * 60.0
position.x = viewport_size.x * 0.5 + cos(timer * 0.6) * 160.0
position.y = viewport_size.y * 0.3 + sin(timer) * 50.0
```

> Amplitude H : ±160 px | Amplitude V : ±50 px | Fréquence X : 0.012 rad/frame | Fréquence Y : 0.02 rad/frame

### Attaques

- **Cadence :** toutes les 120 frames (2 secondes)
- **Dégâts au joueur :** 2 HP par tir
- **Projectile :** de `(copterX, copterY + 20)` vers `(width * 0.25, height * 0.75)`

### Hitbox (xcopter — niveau non-3)

```
RectF(copterX - 90*sc, copterY - 45*sc, copterX + 115*sc, copterY + 35*sc)
```
Soit : largeur = 205 unités scalées, hauteur = 80 unités scalées.

### Hitbox (HK-Aerial — niveau 3 / stage3)

```
RectF(copterX - 92*sc, copterY - 25*sc, copterX + 92*sc, copterY + 25*sc)
```
Soit : largeur = 184 unités scalées, hauteur = 50 unités scalées.

### Dégâts reçus

| Type projectile | Dégâts |
|---|---|
| Bullet | 5 HP |
| Rocket | 25 HP |

### Mort (déclenchement de TRANSITION)

```kotlin
transitionTimer = 360f  // 6 secondes
```
Spawn de débris (`Debris`) et de particules (`Spark`).

### Animation des pales (xcopter)

| Frame | Bitmap | Largeur sprite |
|---|---|---|
| 0 | `xcopter_00.png` | 190 px |
| 1 | `xcopter_01.png` | 181 px |
| 2 | `xcopter_02.png` | 177 px |

- **Durée par frame :** 80 ms
- **Offset pales vs corps :** `(-82, -37)` en coordonnées SVG
- **Corps :** `xcopter_03.png` — 109×32 px à `(0, 0)`

### Animation rotors (HK-Aerial)

- 4 frames L + 4 frames R (`xbighk_01..04.png`, `xbighk_05..08.png`)
- **Durée par frame :** 80 ms

---

## 3. `xjug` — Machine à États (Juggernaut)

### Variables

| Variable | Valeur | Description |
|---|---|---|
| `jugHp` | 1500 | Points de vie initiaux |
| `maxJugHp` | 1500 | HP max |
| `jugX` | `width + 100f` | Position X initiale (hors écran droite) |
| `jugY` | 0f | Offset vertical (utilisé pour vibrations) |
| `jugAttackTimer` | 0f | Timer avant ANTICIPATION |
| `jugStateTimer` | 0f | Timer des états temporisés |
| `ramTimer` | 0f | Safety timeout pour LUNGE |

### Calculs de scale et positionnement

```kotlin
val svgToPx = 3.7795275f
val jugScaleFactor = 0.82f
val finalScale = sc * svgToPx * jugScaleFactor  // sc = renderHeight / contentBottom
val jugWidth = 128.58f * finalScale
val vanX = renderWidth * 0.35f  // Position fixe du van en phase JUGGERNAUT
```

### Diagramme des états

```
         ┌─────────────────────────────────────────────────────────┐
         │                    CHASE                                │
         │  Target = vanX - jugWidth - 100                        │
         │  Vitesse approche : 6 px/frame (gauche), 10 (droite)   │
         │  ─────────────────────────────────────────────────────  │
         │  Condition : |jugX - target| < 10 → jugAttackTimer++   │
         └──────────────────(jugAttackTimer > 210)─────────────────┘
                                    │
                                    ▼
         ┌─────────────────────────────────────────────────────────┐
         │                 ANTICIPATION (60 frames = 1 sec)        │
         │  Target = vanX - jugWidth - 180 (recul !)               │
         │  Vitesse : 4 (gauche), 6 (droite)                      │
         │  jugY = bodyBounce * 1.5  (vibration moteur)           │
         └──────────────────(jugStateTimer <= 0)───────────────────┘
                                    │
                                    ▼
         ┌─────────────────────────────────────────────────────────┐
         │                      LUNGE                              │
         │  jugX += 16 * dt  (charge rapide !)                    │
         │  Collision si : jugX + jugWidth >= vanX + 10           │
         │  → playerHp -= 10, screenShake = 24, vanPush = 60      │
         │  → jugX = vanX - jugWidth - 120  (rebond)              │
         │  Safety : ramTimer > 80 → RETREAT sans collision        │
         └──────────(collision OR ramTimer > 80)───────────────────┘
                                    │
                                    ▼
         ┌─────────────────────────────────────────────────────────┐
         │                  RETREAT (150 frames = 2.5 sec)        │
         │  Target = vanX - jugWidth - 160                        │
         │  Vitesse : 4 px/frame (les deux sens)                  │
         └──────────────────(jugStateTimer <= 0)───────────────────┘
                                    │
                                    └──────────────► CHASE (jugAttackTimer = 0)
```

### Tableau des paramètres numériques

| Paramètre | Valeur | En secondes |
|---|---|---|
| Durée avant attaque (CHASE→ANTICI) | 210 frames | 3.5 sec |
| Durée anticipation (ANTICI→LUNGE) | 60 frames | 1.0 sec |
| Safety timeout LUNGE | 80 frames | 1.33 sec |
| Durée retreat (LUNGE→CHASE) | 150 frames | 2.5 sec |
| Vitesse LUNGE | 16 px/frame | — |
| Vitesse CHASE (gauche→droite) | 6 px/frame | — |
| Vitesse CHASE (droite→gauche) | 10 px/frame | — |
| Vitesse ANTICIPATION | 4-6 px/frame | — |
| Vitesse RETREAT | 4 px/frame | — |
| Distance chase target | jugWidth + 100 | — |
| Distance anticipation target | jugWidth + 180 | — |
| Distance rebound après impact | jugWidth + 120 | — |
| Distance retreat target | jugWidth + 160 | — |

### Dégâts

| Source | Dégâts joueur |
|---|---|
| Collision LUNGE | -10 HP |
| Bullet (joueur→jug) | -5 HP |
| Rocket (joueur→jug) | -25 HP |

### Hitbox Juggernaut (pour les tirs joueur)

```kotlin
val jugBox = RectF(
    jugX,
    targetY + 170f * finalScale,
    jugX + jugWidth,
    targetY + 214.4f * finalScale
)
```
(Zone inférieure du véhicule uniquement — châssis et roues)

### Corps du Juggernaut — 4 parties (SVG coords)

| Partie | Bitmap | X | Y | Largeur | Hauteur |
|---|---|---|---|---|---|
| Body Left | `xjug1_00.png` | 0 | 181.83 | 5.29 | 27.52 |
| Body Main | `xjug1_01.png` | 5.29 | 181.83 | 79.37 | 27.52 |
| Body Right | `xjug2_00.png` | 84.67 | 181.83 | 20.11 | 27.52 |
| Cabin | `xjug2_01.png` | 104.77 | 173.37 | 23.81 | 35.98 |

### Roues — 5 positions X

`17.70, 31.46, 70.62, 84.38, 115.07` (en coordonnées SVG)  
Y = 204.11, taille = 10.58 × 10.32 chacune  
Animation : 2 frames alternées à 100 ms.

### Animation de vibration

```kotlin
bodyBounceOffset = sin(animTimeMs * 0.015f) * 2f
jugY = bodyBounceOffset * 0.5f         // CHASE / RETREAT
jugY = bodyBounceOffset * 1.5f         // ANTICIPATION (plus intense)
```

---

## 4. `xtruck` — Véhicule Joueur (niveau 3 / stage3)

> Le camion est le **véhicule du joueur**, pas un ennemi. Mais sa logique est importante pour le port Godot.

### Position

```kotlin
val truckX = renderWidth * vanXFrac + vanImpactPush
// vanXFrac = 0.15 (copter), 0.15→0.35 (transition), 0.35 (juggernaut)
```

### Parts (SVG coords, en coordonnées finales = SVG * finalScale)

| Partie | Bitmap | X | Y | W | H |
|---|---|---|---|---|---|
| Body (intact) | `xtruck1_00.png` | -1.38 | 231.49 | 64.03 | 12.17 |
| Body (damaged) | `xtruck1_01.png` | — | — | — | — |
| Cabin (intact) | `xtruck1_02.png` | 22.47 | 221.97 | 8.47 | 9.52 |
| Cabin (damaged) | `xtruck1_03.png` | — | — | — | — |
| Bed (intact) | `xtruck1_04.png` | 31.73 | 222.76 | 15.61 | 8.73 |
| Bed (damaged) | `xtruck1_05.png` | — | — | — | — |
| Exhaust | `xtruck1_06.png` | 47.34 | 229.64 | 11.38 | 1.85 |
| Bumper | `xtruck2_04.png` | 53.76 | 229.64 | 7.67 | 1.85 |
| Mirror L | `xtruck2_05.png` | 1.17 | 217.60 | 15.61 | 13.76 |
| Mirror R | `xtruck2_06.png` | 4.87 | 220.51 | 11.91 | 10.85 |

### Roues (2 frames à 100ms)

| Position | Intact | Animé |
|---|---|---|
| Rear | `xtruck2_00.png` | `xtruck2_02.png` |
| Front | `xtruck2_01.png` | `xtruck2_03.png` |

Positions SVG : Rear = (8.94, 238.37), Front = (48.63, 237.84)

### États de la sirène (HP-based)

| HP | Sprite | Comportement |
|---|---|---|
| > 66% | `xtruck2_07.png` | Flash (150ms on/off) |
| 33–66% | `xtruck2_08.png` | Statique endommagée |
| < 33% | `xtruck2_09.png` | Base brisée statique |

### Impact Push (recul du camion)

```kotlin
vanImpactPush = 60f          // Au moment de l'impact
// Décroît de 3 * dt par frame
vanImpactPush = maxOf(0f, vanImpactPush - 3f * dt)
```

---

## 5. Effets Globaux

### Screen Shake

```kotlin
screenShake = 24f             // Valeur max au déclenchement
// Décroît de 1 * dt par frame
screenShake = maxOf(0f, screenShake - dt)
// Application :
val shakeX = (random() - 0.5f) * screenShake * 2f
val shakeY = (random() - 0.5f) * screenShake * 2f
```

### Damage Flash (overlay rouge)

```kotlin
dmgFlash = 12f                // Copter attack
dmgFlash = 20f                // Juggernaut collision / entity collision
// Décroît de 1 * dt par frame
```

### Débris physiques

```kotlin
d.x += d.vx * dt
d.y += d.vy * dt
d.vy += 0.25f * dt            // Gravité
d.rotation += d.vRot * dt
d.life -= 0.015f * dt         // Fade sur ~66 frames (1.1 sec)
```

### Projectiles joueur

- **Bullet :** tir automatique toutes les 6 frames (10 Hz), voyage de `(0.25w, 0.8h)` vers réticule
- **Rocket :** manuel
- **Vitesse projectile :** `t += 0.08 * dt`, arrive à destination quand `t >= 1`

---

## 6. Détection `isLevel3`

```kotlin
val isLevel3 = mapAssetPath.contains("level3", ignoreCase = true) 
            || mapAssetPath.contains("stage3", ignoreCase = true)
```

Quand `isLevel3 = true` :
- Le copter devient **HK-Aerial** (sprites `xbighk_*`)
- Le véhicule joueur devient **camion** (sprites `xtruck*`)
- Les hitboxes et les débris changent
- Sur la mort du Juggernaut, les roues utilisent `bmpTruckWheel` au lieu de `bmpVanWheel`

---

## 7. Caméra / Scroll

```kotlin
val camSpeed = 0.02f          // colonnes par frame
camX += camSpeed * dt         // Scroll continu
```

Le fond défile en boucle (`T2ParallaxMap`). Les entités Tiled (de la couche `Entities`) apparaissent quand leur colonne `startCol <= camX + colsVisible + 2`.
