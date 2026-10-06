class_name FlyingHK
extends ActorBase

# Script spécifique pour les véhicules Hunter-Killer (HK) aériens
# - xbighk: Vol horizontal continu de gauche à droite avec tirs standards
# - xfrdfhk: Vue de face, avance au centre (fly) -> cabrage (pitchup) -> montée (climb) bord haut collé (y=0) + salves de xmissile

@export var mode_hk_front: bool = false # Activer pour xfrdfhk (vue de face)
@export var nombre_de_passages: int = 1 # Nombre de survols avant disparition
@export var attaquer_en_passant: bool = true # Activer ou désactiver les tirs pendant le passage
@export var mode_hk_decolage: bool = false # Activer ou désactiver les decollage pour xbighk
@export var y_decolage: float = 17.0 # Position Y cible pour le décollage (en pixels)
@export var vitesse_decolage: float = 60.0 # Vitesse de montée lors du décollage
@export var vitesse_vol_horizontal: float = 120.0
@export var missile_scene: PackedScene = preload("res://aseprite/xmissile.tscn")

# Variables internes pour le décollage
var camera_detectee: bool = false

func _ready() -> void:
	if mode_hk_front:
		vitesse_deplacement = 0.0
	super._ready()
	# En mode décollage, rendre le HK visible immédiatement (au sol)
	# MAIS laisser ActorBase gérer l'activation normalement (avec délai et stop)
	if mode_hk_decolage and not Engine.is_editor_hint():
		_afficher_visuel()
		# Appliquer l'inversion visuelle dès l'entrée dans le level
		_appliquer_orientation_visuelle()
		print("[FlyingHK] Mode décollage activé - HK visible au sol, position initiale: ", global_position, " | inverser_visuel: ", inverser_visuel)

func _appliquer_orientation_visuelle() -> void:
	if anim_sprite:
		anim_sprite.flip_h = inverser_visuel
		print("[FlyingHK] Orientation visuelle appliquée - flip_h: ", anim_sprite.flip_h)

func activer_acteur() -> void:
	super.activer_acteur()
	print("[FlyingHK] activer_acteur appelé - mode_hk_decolage: ", mode_hk_decolage, ", deja_active: ", deja_active)
	
	# Appliquer l'orientation visuelle dès l'activation (pour les modes non-décollage)
	if not mode_hk_decolage:
		_appliquer_orientation_visuelle()
	
	if mode_hk_front or possede_animation("pitchup") or possede_animation("climb"):
		_sequence_hk_front()
	elif mode_hk_decolage:
		# En mode décollage, attendre la caméra puis décoller
		_sequence_decollage()
	else:
		# En mode normal, commencer immédiatement
		_sequence_hk_profil()

func _sequence_decollage() -> void:
	print("[FlyingHK] _sequence_decollage démarrée")
	# Désactiver le déplacement horizontal pendant le décollage
	vitesse_deplacement = 0.0
	
	# Attendre que la caméra détecte le HK
	var tentatives = 0
	while est_actif() and not camera_detectee and tentatives < 500: # Limite de sécurité
		tentatives += 1
		var camera = get_viewport().get_camera_2d()
		if camera:
			var viewport_size = get_viewport_rect().size
			var camera_left = camera.global_position.x - viewport_size.x / 2.0
			var camera_right = camera.global_position.x + viewport_size.x / 2.0
			
			print("[FlyingHK] Détection caméra - HK X: ", global_position.x, " | Caméra left: ", camera_left, " | Caméra right: ", camera_right)
			
			if global_position.x >= camera_left and global_position.x <= camera_right:
				camera_detectee = true
				print("[FlyingHK] Caméra détectée - début du décollage vers Y=", y_decolage)
		
		await attendre(0.1) # Vérification périodique
	
	if not est_actif():
		print("[FlyingHK] Annulation - acteur n'est plus actif")
		return
	
	if not camera_detectee:
		print("[FlyingHK] Timeout - caméra non détectée après ", tentatives * 0.1, " secondes")
		# Force le décollage même sans détection de caméra
		camera_detectee = true
	
	# Décollage physique vers y_decolage avec tween fluide
	var position_depart_y = global_position.y
	var position_cible_y = y_decolage
	var distance_parcourir = position_depart_y - position_cible_y
	
	print("[FlyingHK] Décollage - Y départ: ", position_depart_y, " | Y cible: ", position_cible_y, " | Distance: ", distance_parcourir)
	
	if distance_parcourir > 0:
		var duree_decolage = distance_parcourir / vitesse_decolage
		
		# Créer un tween pour une transition fluide avec easing
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT) # Ralentit à la fin pour une transition fluide
		tween.set_trans(Tween.TRANS_SINE) # Courbe sinusoïdale pour un effet naturel
		
		# Animer la position Y avec le tween
		tween.tween_property(self, "global_position:y", position_cible_y, duree_decolage)
		
		# Attendre la fin du tween
		await tween.finished
		
		if est_actif():
			global_position.y = position_cible_y
			print("[FlyingHK] Décollage terminé - début du comportement normal")
	
	# Restaurer la vitesse de déplacement et commencer le comportement normal
	vitesse_deplacement = vitesse_vol_horizontal
	_sequence_hk_profil()

func _sequence_hk_profil() -> void:
	# Configurer la vitesse de vol horizontal
	vitesse_deplacement = vitesse_vol_horizontal
	
	if possede_animation("fly"):
		jouer_animation("fly")

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
				
	# Suppression à la fin des passages
	queue_free()

func _tirer_salve_missiles() -> void:
	if missile_scene and is_inside_tree():
		print("[XFRDFHK] Tir d'une salve de xmissiles vers le joueur !")
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
