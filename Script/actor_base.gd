class_name ActorBase
extends CharacterBody2D

@export var pv_max: int = 5 # Santé par défaut (minimum 5 impacts)
@export var activer_uniquement_sur_ecran: bool = true # Attend la caméra pour se déclencher
@export var delai_activation_sec: float = 0.0 # Délai optionnel (secondes) après détection écran
@export_enum("droite_vers_gauche", "gauche_vers_droite", "immobile") var direction_deplacement: String = "droite_vers_gauche"
@export var vitesse_deplacement: float = 40.0
@export var inverser_visuel: bool = false # Case à cocher simple (Flip H) pour inverser le regard du personnage si nécessaire
@export var points_score: int = 100 # Score accordé au joueur lors de l'élimination
@export var degats_au_clic: bool = false # Debug uniquement : un clic direct blesse l'acteur (sinon seuls les projectiles comptent)

@export_group("Spawn")
@export var delai_spawn: float = 0.0          # Délai avant le premier clone (0.0 = utilise intervalle_repetition)
@export var repeter_spawn: bool = false       # Active la génération de clones répétés
@export var intervalle_repetition: float = 3.0 # Intervalle entre les spawns répétés (en secondes)
@export var nombre_max_spawns: int = 0        # Nombre maximum de spawns (0 = illimité, 1 = initial uniquement, 2 = initial + 1 clone)

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D

var deja_active: bool = false
var est_elimine: bool = false
var pv_actuels: int = 5
var position_spawn_initiale: Vector2 = Vector2.ZERO
var compte_spawns_acteur: int = 1

# Catégorie de tri visuel résolue une seule fois (évite des comparaisons de chaînes à chaque frame)
var _est_prioritaire_popup: bool = false

func _ready() -> void:
	pv_actuels = pv_max
	input_pickable = true
	position_spawn_initiale = global_position
	_est_prioritaire_popup = _resoudre_priorite_popup()
	
	# ANNULATION ABSOLUE DES COLLISIONS PHYSIQUES ENTRE ENNEMIS
	collision_layer = 2 # Calque dédié aux ennemis
	collision_mask = 0  # Ne bloque physiquement contre AUCUN autre acteur (passe à travers à 100%)
	
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	if not Engine.is_editor_hint():
		if activer_uniquement_sur_ecran:
			_masquer_visuel()
			if notifier:
				if not notifier.screen_entered.is_connected(_on_ecran_entre):
					notifier.screen_entered.connect(_on_ecran_entre)
				call_deferred("_verifier_ecran_initial")
			else:
				activer_acteur()
		else:
			activer_acteur()
	else:
		_afficher_visuel()

func _resoudre_priorite_popup() -> bool:
	if self is PopupEnemy:
		return true
	var nom_min = name.to_lower()
	return "popup" in nom_min or "gigend" in nom_min or "t100big" in nom_min or "arng" in nom_min

## Attente respectant la pause du jeu (get_tree().create_timer() ignore la pause par défaut).
func attendre(secondes: float) -> void:
	if secondes <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(secondes, false).timeout

## Vrai tant que l'acteur peut poursuivre sa séquence de comportement.
func est_actif() -> bool:
	return is_inside_tree() and deja_active and not est_elimine

func _verifier_ecran_initial() -> void:
	if notifier and notifier.is_on_screen():
		_on_ecran_entre()

func _masquer_visuel() -> void:
	if anim_sprite:
		anim_sprite.hide()
	visible = true

func _afficher_visuel() -> void:
	if anim_sprite:
		anim_sprite.show()
	visible = true

func _on_ecran_entre() -> void:
	if not deja_active:
		if delai_activation_sec > 0.0:
			await attendre(delai_activation_sec)
		if not deja_active:
			activer_acteur()

func activer_acteur() -> void:
	if deja_active:
		return
	deja_active = true
	_afficher_visuel()
	if repeter_spawn and not Engine.is_editor_hint():
		_demarrer_boucle_spawn()

func _demarrer_boucle_spawn() -> void:
	if not is_inside_tree():
		return
	
	# Attente initiale avant le premier clone (Actor #2)
	var attente_initiale = delai_spawn if delai_spawn > 0.0 else intervalle_repetition
	if attente_initiale > 0.0:
		await attendre(attente_initiale)
		if not is_inside_tree() or not repeter_spawn:
			return
	
	while repeter_spawn and is_inside_tree() and (nombre_max_spawns <= 0 or compte_spawns_acteur < nombre_max_spawns):
		_generer_clone_acteur()
		
		if nombre_max_spawns > 0 and compte_spawns_acteur >= nombre_max_spawns:
			break
			
		if intervalle_repetition > 0.0:
			await attendre(intervalle_repetition)
			if not is_inside_tree() or not repeter_spawn:
				break
		else:
			break

func _generer_clone_acteur() -> void:
	if not is_inside_tree():
		return
		
	var scene_path = scene_file_path
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
		
	var scene = load(scene_path) as PackedScene
	if not scene:
		return
		
	var clone = scene.instantiate() as ActorBase
	if not clone:
		return
		
	# Désactiver le spawner sur le clone pour éviter une boucle infinie
	clone.repeter_spawn = false
	clone.activer_uniquement_sur_ecran = false
	
	# Transmettre la configuration de l'acteur courant
	clone.vitesse_deplacement = vitesse_deplacement
	clone.direction_deplacement = direction_deplacement
	clone.inverser_visuel = inverser_visuel
	clone.delai_activation_sec = 0.0
	
	for prop in ["comportement_bigend", "comportement_enfwrd", "option_comportement"]:
		if prop in self and prop in clone:
			clone.set(prop, self.get(prop))
			
	clone.global_position = position_spawn_initiale
	var parent = get_parent()
	if parent == null:
		clone.free()
		return
	parent.add_child(clone)
	compte_spawns_acteur += 1
	clone.activer_acteur()

func _physics_process(_delta: float) -> void:
	# Tri visuel dynamique en profondeur (Y-Sorting) : Aucun acteur ne passe devant un PopUp !
	if not est_elimine:
		# Priorité PopUp z=100 (au-dessus des piétons, sous les projectiles z=500 et la vitre z=900)
		z_index = 100 if _est_prioritaire_popup else int(clamp(global_position.y, 1.0, 90.0))
		
	if deja_active and not est_elimine and vitesse_deplacement > 0.0:
		match direction_deplacement:
			"droite_vers_gauche":
				velocity.x = -vitesse_deplacement
				if anim_sprite and anim_sprite.flip_h != inverser_visuel:
					anim_sprite.flip_h = inverser_visuel
				move_and_slide()
			"gauche_vers_droite":
				velocity.x = vitesse_deplacement
				if anim_sprite and anim_sprite.flip_h == inverser_visuel:
					anim_sprite.flip_h = not inverser_visuel
				move_and_slide()
			"immobile":
				velocity.x = 0

func possede_animation(nom_anim: String) -> bool:
	if anim_player:
		return anim_player.has_animation(nom_anim)
	elif anim_sprite and anim_sprite.sprite_frames:
		return anim_sprite.sprite_frames.has_animation(nom_anim)
	return false

func jouer_animation(nom_anim: String) -> void:
	if anim_player and anim_player.has_animation(nom_anim):
		anim_player.play(nom_anim)
	elif anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(nom_anim):
		anim_sprite.play(nom_anim)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Les dégâts proviennent normalement des projectiles du joueur (cadence de tir et
	# GunPower appliqués) : le clic direct reste une option de debug.
	if not degats_au_clic:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		subir_degats(1)

func subir_degats(quantite: int) -> void:
	if est_elimine:
		return
	pv_actuels -= quantite
	
	# --- RÉACTION AUX COUPS PAR POSTURE / IMPACT ---
	if possede_animation("hit"):
		var anim_idle_retour = "idle"
		if anim_sprite:
			var anim_actuelle = anim_sprite.animation
			if anim_actuelle in ["shoot", "idle"]:
				anim_idle_retour = anim_actuelle
			elif "crouch" in anim_actuelle and possede_animation("idle_crouch"):
				anim_idle_retour = "idle_crouch"
			elif possede_animation("idle_stand"):
				anim_idle_retour = "idle_stand"
				
		jouer_animation("hit")
		
		# Minuteur léger pour réenclencher l'animation active après l'impact (0.2s)
		var timer = get_tree().create_timer(0.2, false)
		timer.timeout.connect(func():
			if not est_elimine and anim_sprite and anim_sprite.animation == &"hit":
				if possede_animation(anim_idle_retour):
					jouer_animation(anim_idle_retour)
		)

	if pv_actuels <= 0:
		subir_elimination()

func subir_elimination() -> void:
	if est_elimine:
		return
	est_elimine = true
	GlobalSettings.ajouter_score(points_score)
	
	var nom_minuscule = name.to_lower()
	# --- FRAGMENTATION MÉTALLIQUE SANS FEU POUR XGIGEND ---
	if "gigend" in nom_minuscule:
		_creer_effet_fragmentation_metallique()
		hide()
		await attendre(0.8)
		queue_free()
		return
		
	if possede_animation("die"):
		jouer_animation("die")
		if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("die"):
			if not anim_sprite.sprite_frames.get_animation_loop("die"):
				await anim_sprite.animation_finished
			else:
				await attendre(0.8)
	queue_free()

func _creer_effet_fragmentation_metallique() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 40
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300)
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 280.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 8.0
	particles.color = Color(0.7, 0.75, 0.8, 1.0) # Gris acier / métal d'arcade sans feu
	parent.add_child(particles)
	particles.emitting = true
