class_name FrdfhkEnemy
extends ActorBase

## Script autonome pour l'hélicoptère HK de face XFRDFHK (survol frontal, cabrage, montée & missiles)

@export var nombre_de_passages: int = 1
@export var attaquer_en_passant: bool = true
@export var missile_scene: PackedScene = preload("res://aseprite/xmissile.tscn")

func _ready() -> void:
	vitesse_deplacement = 0.0
	super._ready()

func _appliquer_orientation_visuelle() -> void:
	if anim_sprite:
		anim_sprite.flip_h = inverser_visuel

func activer_acteur() -> void:
	super.activer_acteur()
	_appliquer_orientation_visuelle()
	_sequence_hk_front()

func _sequence_hk_front() -> void:
	vitesse_deplacement = 0.0
	for passage in range(nombre_de_passages):
		if est_elimine or not is_inside_tree(): break
		
		# Phase 1: 'fly' - Survol frontal vers le joueur
		if possede_animation("fly"):
			jouer_animation("fly")
			if attaquer_en_passant:
				_tirer_salve_missiles()
			if anim_sprite:
				await anim_sprite.animation_finished
			if est_elimine or not is_inside_tree(): break

		# Phase 2: 'pitchup' - Le HK se cabre vers le haut
		if possede_animation("pitchup"):
			jouer_animation("pitchup")
			if anim_sprite:
				await anim_sprite.animation_finished

		# Phase 3: 'climb' - Remontée vers le ciel (y = 0)
		if possede_animation("climb"):
			jouer_animation("climb")
			var viewport_top = get_viewport_rect().position.y
			global_position.y = viewport_top + (anim_sprite.sprite_frames.get_frame_texture("climb", 0).get_height() / 2.0 if anim_sprite and anim_sprite.sprite_frames else 30.0)
			if anim_sprite:
				await anim_sprite.animation_finished
				
	queue_free()

func _tirer_salve_missiles() -> void:
	if missile_scene and is_inside_tree():
		for i in range(2):
			if est_elimine or not is_inside_tree(): break
			var m = missile_scene.instantiate()
			get_parent().add_child(m)
			var offset_x = -15.0 if i == 0 else 15.0
			if m.has_method("initialiser_lancer"):
				m.initialiser_lancer(global_position + Vector2(offset_x, 10.0), Vector2(0.0, 1.0))
			else:
				m.global_position = global_position + Vector2(offset_x, 10.0)
			await attendre(0.3)
