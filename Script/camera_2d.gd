extends Camera2D

# Vitesse de défilement en pixels par seconde
@export var vitesse : float = 60.0

func _process(delta: float) -> void:
	# On fait avancer la position X de la caméra vers la droite
	position.x += vitesse * delta
	
	# Si la caméra atteint la limite droite de la carte, elle s'arrête
	if position.x >= limit_right - (get_viewport_rect().size.x / 2):
		position.x = limit_right - (get_viewport_rect().size.x / 2)
