class_name StopMarker
extends Marker2D

## Mode d'alignement de la caméra lors de l'arrêt sur ce marqueur.
## 'Utiliser_Defaut_Camera' : utilise le choix configuré dans Camera2D.
@export_enum("Utiliser_Defaut_Camera", "Bord_Gauche", "Centre_Viseur", "Bord_Droit") var alignement : String = "Utiliser_Defaut_Camera"

## Durée de pause sur ce marqueur en secondes.
## Mettre une valeur négative (ex: -1.0) pour utiliser la durée par défaut configurée dans Camera2D.
@export var temps_pause : float = -1.0
