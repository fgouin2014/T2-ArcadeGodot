class_name BighkEnemy
extends ActorBase

## Script autonome pour l'hélicoptère HK de profil XBIGHK (survol horizontal / décollage)

@export var nombre_de_passages: int = 1
@export var attaquer_en_passant: bool = true
@export var mode_hk_decolage: bool = false
@export var y_decolage: float = 17.0
@export var vitesse_decolage: float = 60.0
@export var vitesse_vol_horizontal: float = 120.0

var camera_detectee: bool = false

func _ready() -> void:
	super._ready()
	if mode_hk_decolage and not Engine.is_editor_hint():
		_afficher_visuel()
		_appliquer_orientation_visuelle()

func _appliquer_orientation_visuelle() -> void:
	if anim_sprite:
		anim_sprite.flip_h = inverser_visuel

func activer_acteur() -> void:
	super.activer_acteur()
	_appliquer_orientation_visuelle()
	
	if mode_hk_decolage:
		_sequence_decollage()
	else:
		_sequence_hk_profil()

func _sequence_decollage() -> void:
	vitesse_deplacement = 0.0
	
	var tentatives = 0
	while est_actif() and not camera_detectee and tentatives < 500:
		tentatives += 1
		var camera = get_viewport().get_camera_2d()
		if camera:
			var viewport_size = get_viewport_rect().size
			var camera_left = camera.global_position.x - viewport_size.x / 2.0
			var camera_right = camera.global_position.x + viewport_size.x / 2.0
			
			if global_position.x >= camera_left and global_position.x <= camera_right:
				camera_detectee = true
		await attendre(0.1)
	
	if not est_actif(): return
	if not camera_detectee: camera_detectee = true
	
	var position_depart_y = global_position.y
	var position_cible_y = y_decolage
	var distance_parcourir = position_depart_y - position_cible_y
	
	if distance_parcourir > 0:
		var duree_decolage = distance_parcourir / vitesse_decolage
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "global_position:y", position_cible_y, duree_decolage)
		await tween.finished
		if est_actif():
			global_position.y = position_cible_y
	
	vitesse_deplacement = vitesse_vol_horizontal
	_sequence_hk_profil()

func _sequence_hk_profil() -> void:
	vitesse_deplacement = vitesse_vol_horizontal
	if possede_animation("fly"):
		jouer_animation("fly")
