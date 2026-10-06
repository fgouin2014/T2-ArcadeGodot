# Pickups

Catalogue des objets representes dans `images/items/`.

| Asset | Nom | Scene | Effet / description |
| --- | --- | --- | --- |
| `xpickup_01.png` | Chargeurs | `xpickup_01_chargeur.tscn` | Recharge instantanement et completement la jauge d'energie de la mitrailleuse. |
| `xpickup_03.png` | Coolant | `xpickup_03_coolant.tscn` | Empeche temporairement l'arme de surchauffer pendant 20 secondes. |
| `xpickup_05.png` | Shield temporaire | `xpickup_05_shield.tscn` | Protege des tirs ennemis pendant 20 secondes. |
| `xpickup_07.png` | Nuke | `xpickup_07_nuke.tscn` | Tirer dessus declenche une explosion massive qui elimine instantanement tous les ennemis visibles a l'ecran et accorde un bonus de points consequent. |
| `xpickup_09.png` | Gatling gun | `xpickup_09_gatling.tscn` | TODO: arme principale temporaire. |
| `xpickup_11.png` | Inconnue | `xpickup_11_unknown.tscn` | TODO: effet a definir. |
| `xpickup_12.png` | Shotgun Shell | `xpickup_12_shotgun_shell.tscn` | Munitions d'arme alternative (ajoute au stock d'alt-fire / missiles). |
| `xpickup_14.png` | Missiles | `xpickup_14_missile.tscn` | Ajoute des missiles au stock independant de la jauge GunPower. |
| `xpickup_16.png` + `xpickup_17.png` | CPU | `xpickup_16_cpu.tscn` | Animation en alternance entre les deux images. TODO: effet a definir. |
| `xpickup_18.png` | Plasma | `xpickup_18_plasma.tscn` | TODO: augmente temporairement la puissance brute des balles. |
| `xpickup_21.png` | Credit | `xpickup_21_credit.tscn` | Ajoute un credit. |
| `xpickup_24.png` | Bombe dangereuse | `xpickup_24_bombe.tscn` | TODO: une bombe qui blesse le joueur si le joueur tire dessus. |
| `xpickup_25.png` | Inconnue B | `xpickup_25_unknown.tscn` | TODO: asset non identifie, effet a definir. |
| `xpickup_26.png` | Inconnue C | `xpickup_26_unknown.tscn` | TODO: asset non identifie, effet a definir. |
| `xpickup_29.png` | Shotgun | `xpickup_29_shotgun.tscn` | Arme speciale Shotgun (Level 8) : donne 3 tirs de substitution temporaires. Dès que le stock tombe à 0, le stock régulier précédent est restauré. |

## Etat d'integration

Toutes les scenes sont dans `aseprite/` et utilisent `res://Script/pickup_item.gd`.

| Status | Pickups |
| --- | --- |
| Integre et fonctionnel | `01` `03` `05` `07` `12` `14` `21` `29` |
| Scene creee, effet TODO | `09` `11` `16` `18` `24` `25` `26` |

### Notes
- `xpickup_16_cpu.tscn` utilise un `AnimatedSprite2D` qui alterne entre `xpickup_16.png` et `xpickup_17.png` a 2 FPS.
- `xpickup_16.png` et `xpickup_17.png` sont traites comme **une seule animation CPU**, pas comme deux objets distincts.
- `xpickup_12` recharge le stock d'arme alternative (comme `xpickup_14`).
- `xpickup_29` remplace temporairement le stock de missiles par 3 munitions spéciales de Shotgun (Level 8), puis restaure le stock précédent une fois épuisé.
