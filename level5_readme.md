# Level 5 - Documentation de Parallax et Vitesse

## Configuration Actuelle

- **Level width:** 3987px
- **Temps de parcours souhaité:** 5:44 (344 secondes)
- **Dernier frontdesk position:** 5313.19px

## Motion Scale Parallax

- **Background (PL):** motion_scale = 1.0
- **Floorground (PL):** motion_scale = 1.0  
- **Foreground (PL):** motion_scale = 2.1

## Calculs de Vitesse Nécessaire

### Pour le Foreground (PL)
```
Vitesse = Distance / Temps
Vitesse = 5313.19px / 344sec = 15.45 px/sec
```

### Pour la Caméra
```
Vitesse caméra = Vitesse foreground / motion_scale
Vitesse caméra = 15.45 / 2.1 = 7.36 px/sec
```

### Pour le Background (PL)
```
Vitesse background = Vitesse caméra / motion_scale
Vitesse background = 7.36 / 1.0 = 7.36 px/sec
```

## Paramètres Recommandés

- **vitesse_auto (camera):** 7.36 px/sec
- **Background (PL) motion_scale:** 1.0 (déjà configuré)
- **Foreground (PL) motion_scale:** 2.1 (déjà configuré)

## Problème de Séparation

Avec motion_scale = 2.1 dans le foreground:
- Chaque pixel d'espace dans le foreground = 2.1 pixels à l'écran
- Pour 7 secondes de séparation à 15.45 px/sec = 108px requis
- À l'écran: 108px × 2.1 = 227px

**Résultat:** Maximum 1 seconde de séparation possible avec la configuration actuelle.

## Solutions Possibles

1. **Réduire motion_scale foreground:** Passer de 2.1 à ~1.0-1.2
2. **Augmenter level width:** Ajouter ~227px pour accommoder la séparation
3. **Réduire temps de parcours:** Ajuster le temps total de 5:44
4. **Accepter 1 seconde de séparation:** Garder la configuration actuelle

## Configuration Caméra Auto

Dans `camera_auto_scroll.gd`:
```gdscript
@export var vitesse_auto : float = 7.36   # Au lieu de 50.0
```

## Date de Documentation

11 septembre 2026
