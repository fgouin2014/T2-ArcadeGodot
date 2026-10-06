class_name ActorBase
extends CharacterBody2D

@export var pv_max: int = 5 # Santé par défaut (minimum 5 impacts)
@export var invincible: bool = false # Si true, l'acteur ne subit aucun dégât (invulnérable)
@export var actif_au_demarrage: bool = true:
	set(valeur):
		actif_au_demarrage = valeur
		activer_uniquement_sur_ecran = valeur

var activer_uniquement_sur_ecran: bool = true

@export var delai_activation_sec: float = 0.0 # Délai (sec) entre la détection écran/stop caméra et l'activation de l'acteur ORIGINAL (ne s'applique pas aux clones)
@export_enum("droite_vers_gauche", "gauche_vers_droite", "immobile") var direction_deplacement: String = "droite_vers_gauche"
@export var vitesse_deplacement: float = 40.0
@export var inverser_visuel: bool = false # Case à cocher simple (Flip H) pour inverser le regard du personnage si nécessaire
@export var points_score: int = 100 # Score accordé au joueur lors de l'élimination
@export var degats_au_clic: bool = false # Debug uniquement : un clic direct blesse l'acteur (sinon seuls les projectiles comptent)

@export_group("Bouclage Caméra")
@export var boucle_avec_camera: bool = false # Si true, l'acteur boucle avec la caméra en mode perpétuel (utile pour véhicules et décors destructibles)

@export_group("Déclencheur sur Arrêt Caméra")
@export var declencheur_stop: NodePath ## Sélecteur visuel de StopMarker dans l'Inspecteur Godot
@export var nom_stop_declencheur: String = "" ## Nom ou identifiant optionnel du StopMarker (ex: "Stop1")
@export_enum("activer_quand_atteint", "activer_a_la_reprise") var mode_activation_stop: String = "activer_quand_atteint" ## activer_quand_atteint = activation dès que le stop est atteint (défaut). activer_a_la_reprise = activation quand la caméra repart après le stop.
@export var deverrouiller_stop_a_la_mort: bool = true ## Si true, déverrouille le stop caméra lié lors de la mort de cet acteur

@export_group("Transition de Niveau")
## Si coché, éliminer cet acteur déclenche le passage automatique au prochain niveau configuré dans DICO_NIVEAUX.
@export var changer_niveau_a_la_mort: bool = false
## Délai d'attente avant la transition après la mort (ex: 1.0s pour laisser jouer l'animation de destruction).
@export var delai_transition_mort_sec: float = 1.0

@export_group("Spawn")
@export var delai_spawn: float = 0.0          # Attente avant le 1er clone après activation de l'original (0.0 = utilise intervalle_repetition comme 1ère attente)
@export var repeter_spawn: bool = false       # Active la génération de clones répétés
@export var intervalle_repetition: float = 3.0 # Intervalle entre chaque clone (sert aussi de 1ère attente si delai_spawn = 0.0)
@export var nombre_max_spawns: int = 0        # Nombre maximum de clones générés (0 = illimité, 1 = 1 clone, 2 = 2 clones, etc.)
@export var stopper_spawn_a_la_mort: bool = true # true = mort de l'original stoppe les spawns | false = un Timer sur le parent prend le relais
@export_range(1, 8, 1) var step_decalage_spawn: int = 3 # Nombre de positions candidates de chaque côté pour éviter le chevauchement
@export var distance_step_spawn_px: float = 10.0 # Distance fixe entre les positions candidates de spawn

@export_group("Effets de Mort")
enum MortEffet { OFF, EXPLOSION, PARTICULES, PERSONNALISE }
@export var effet_mort: MortEffet = MortEffet.OFF
enum ExplosionPattern { SIMPLE, DOUBLE, CASCADE }
@export var explosion_pattern: ExplosionPattern = ExplosionPattern.SIMPLE
@export var scene_explosion_personnalisee: PackedScene = null
@export_range(0.0, 2.0) var delai_avant_explosion: float = 0.0

@export_group("Message de Mort (BitmapText)")
## Si non vide, affiche ce message à l'écran centré lors de la mort de l'acteur.
@export_multiline var message_a_la_mort: String = ""
## Durée d'affichage du message en secondes.
@export var duree_message_mort_sec: float = 2.5
## Police pour le message de mort.
@export_enum("xfonts_blue", "xfonts_red", "xfonts_white", "xfonts_trueblue", "xfonts2_white") var police_message_mort: String = "xfonts_red"

@export_group("Positionnement Apparitions")
## Mode de positionnement pour les explosions et pickups spawnés par cet acteur.
## local_parallax_compatible = suit le parallax naturellement (recommandé pour décors dans ParallaxLayer)
## global_world_space = position fixe dans l'espace monde (utile pour acteurs mobiles)
@export_enum("local_parallax_compatible", "global_world_space") var mode_positionnement_apparitions: String = "local_parallax_compatible"

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D

var deja_active: bool = false
var _en_attente_activation: bool = false
var est_elimine: bool = false
var pv_actuels: int = 5
var position_spawn_initiale: Vector2 = Vector2.ZERO
var compte_spawns_acteur: int = 0

# Catégorie de tri visuel résolue une seule fois (évite des comparaisons de chaînes à chaque frame)
var _est_prioritaire_popup: bool = false
var _camera_stop_declencheur: CameraStopDeclencheur = null

func _ready() -> void:
	pv_actuels = pv_max
	input_pickable = true
	position_spawn_initiale = position
	_est_prioritaire_popup = _resoudre_priorite_popup()
	
	# ANNULATION ABSOLUE DES COLLISIONS PHYSIQUES ENTRE ENNEMIS
	collision_layer = 2 # Calque dédié aux ennemis
	collision_mask = 0  # Ne bloque physiquement contre AUCUN autre acteur (passe à travers à 100%)
	
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	_initialiser_hitbox_dynamique()

	if not Engine.is_editor_hint():
		_masquer_visuel()
		var a_declencheur = CameraStopDeclencheur.est_configure(declencheur_stop, nom_stop_declencheur)
		if a_declencheur:
			# Le StopMarker prime toujours : l'acteur attend le Stop caméra avant de s'activer
			call_deferred("_connecter_declencheur_stop")
		elif actif_au_demarrage:
			# Pas de StopMarker : activation automatique à l'entrée à l'écran
			if notifier:
				if not notifier.screen_entered.is_connected(_on_ecran_entre):
					notifier.screen_entered.connect(_on_ecran_entre)
			call_deferred("_verifier_ecran_initial")
		
		# Connecter au signal de bouclage de caméra si boucle_avec_camera est activé
		if boucle_avec_camera:
			call_deferred("_connecter_bouclage_camera")
	else:
		_afficher_visuel()

func _resoudre_priorite_popup() -> bool:
	if self is PopupEnemy:
		return true
	var nom_min = name.to_lower()
	return "popup" in nom_min or "gigend" in nom_min or "t100big" in nom_min or "arng" in nom_min

## Attente respectant la pause du jeu (get_tree().create_timer() ignore la pause par défaut).
func attendre(secondes: float) -> void:
	if not is_inside_tree():
		return
	if secondes <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(secondes, false).timeout

## Vrai tant que l'acteur peut poursuivre sa séquence de comportement.
func est_actif() -> bool:
	return is_inside_tree() and deja_active and not est_elimine

func _est_dans_ou_derriere_vue_camera() -> bool:
	if notifier and notifier.is_on_screen():
		return true
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera:
		var centre_x = camera.get_screen_center_position().x
		var demi_l = 160.0
		if "largeur_lucarne" in camera:
			demi_l = float(camera.largeur_lucarne) / 2.0
		# Si la position de l'acteur est déjà atteinte/dépassée par le bord droit de la caméra (+ marge)
		if global_position.x <= (centre_x + demi_l + 30.0):
			return true
	return false

func _verifier_ecran_initial() -> void:
	if not deja_active and actif_au_demarrage:
		if _est_dans_ou_derriere_vue_camera():
			print("[%s] Déjà visible au démarrage -> _on_ecran_entre()" % name)
			_on_ecran_entre()
		else:
			print("[%s] Hors écran au démarrage, attend screen_entered" % name)

func _connecter_bouclage_camera() -> void:
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera and camera.has_signal("camera_looped"):
		if not camera.camera_looped.is_connected(_on_camera_looped):
			camera.camera_looped.connect(_on_camera_looped)
			print("[%s] Connecté au signal de bouclage de caméra" % name)

func _on_camera_looped(position_avant: float, position_apres: float) -> void:
	# Quand la caméra boucle, ajuster la position de l'acteur par le même décalage
	var decalage = position_apres - position_avant
	global_position.x += decalage
	print("[%s] Bouclage avec caméra - décalage X: %f" % [name, decalage])

func _masquer_visuel() -> void:
	if anim_sprite:
		anim_sprite.hide()
	visible = true

func _afficher_visuel() -> void:
	if anim_sprite:
		anim_sprite.show()
	visible = true

func _on_ecran_entre() -> void:
	if not deja_active and not _en_attente_activation and actif_au_demarrage:
		_en_attente_activation = true
		print("[%s] Entré à l'écran - delai_activation_sec=%.2f" % [name, delai_activation_sec])
		await attendre(delai_activation_sec)
		_en_attente_activation = false
		if not deja_active and is_inside_tree() and not est_elimine:
			print("[%s] Délai terminé -> activer_acteur()" % name)
			activer_acteur()

func _stop_declencheur_ignore_camera() -> bool:
	return deja_active or _en_attente_activation

func _connecter_declencheur_stop() -> void:
	if _camera_stop_declencheur == null:
		_camera_stop_declencheur = CameraStopDeclencheur.new()
		_camera_stop_declencheur.configure(
			self,
			declencheur_stop,
			nom_stop_declencheur,
			mode_activation_stop,
			_on_stop_declenche,
			_stop_declencheur_ignore_camera
		)
	_camera_stop_declencheur.connect_signals()

func _exit_tree() -> void:
	if _camera_stop_declencheur:
		_camera_stop_declencheur.deconnecter()
		_camera_stop_declencheur = null

func _on_stop_declenche() -> void:
	if not deja_active and not _en_attente_activation:
		_en_attente_activation = true
		print("[%s] Stop déclenché - delai_activation_sec=%.2f" % [name, delai_activation_sec])
		await attendre(delai_activation_sec)
		_en_attente_activation = false
		if not deja_active and is_inside_tree() and not est_elimine:
			print("[%s] Délai stop terminé -> activer_acteur()" % name)
			activer_acteur()

var est_un_clone: bool = false

func activer_acteur() -> void:
	if deja_active:
		return
	deja_active = true
	_afficher_visuel()
	
	# Si c'est un clone, ON EMPÊCHE STRICTEMENT qu'il soit un spawner
	if est_un_clone:
		repeter_spawn = false
		return

	# Seul l'acteur d'origine placé dans la scène peut lancer la boucle de spawn
	if repeter_spawn and not Engine.is_editor_hint():
		repeter_spawn = false
		_demarrer_spawner()

func _demarrer_spawner() -> void:
	var parent = get_parent()
	if parent == null or scene_file_path == "" or not ResourceLoader.exists(scene_file_path):
		return
	var spawner := ActorSpawnController.new()
	spawner.name = "Spawner_" + name
	parent.add_child(spawner)
	spawner.configurer(self)
	spawner.demarrer()

static func _choisir_position_spawn(position_reference: Vector2, step_spawn: int, distance_step_px: float, acteurs_du_groupe: Array[ActorBase]) -> Vector2:
	var candidats: Array[Vector2] = []
	var nombre_pas = max(1, step_spawn)

	for pas in range(1, nombre_pas + 1):
		var distance = max(1.0, distance_step_px) * pas
		candidats.append(position_reference + Vector2(-distance, 0.0))
		candidats.append(position_reference + Vector2(distance, 0.0))
	candidats.shuffle()

	for candidat in candidats:
		if _position_spawn_libre(candidat.x, distance_step_px, acteurs_du_groupe):
			return candidat

	# Si les six positions sont prises, choisir la position la plus éloignée du groupe.
	var meilleur_candidat = candidats[0]
	var meilleure_distance = -1.0
	for candidat in candidats:
		var distance_groupe = _distance_minimale_groupe(candidat.x, acteurs_du_groupe)
		if distance_groupe > meilleure_distance:
			meilleure_distance = distance_groupe
			meilleur_candidat = candidat
	return meilleur_candidat

static func _position_spawn_libre(position_x: float, distance_step_px: float, acteurs_du_groupe: Array[ActorBase]) -> bool:
	for acteur in acteurs_du_groupe:
		if not is_instance_valid(acteur) or acteur.est_elimine:
			continue
		if abs(position_x - acteur.position.x) < max(1.0, distance_step_px):
			return false
	return true

static func _distance_minimale_groupe(position_x: float, acteurs_du_groupe: Array[ActorBase]) -> float:
	var distance_minimale = INF
	for acteur in acteurs_du_groupe:
		if is_instance_valid(acteur) and not acteur.est_elimine:
			distance_minimale = min(distance_minimale, abs(position_x - acteur.position.x))
	return distance_minimale

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
	if anim_player and anim_player.has_animation(nom_anim):
		return true
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(nom_anim):
		return true
	return false

func jouer_animation(nom_anim: String) -> void:
	if anim_player and anim_player.has_animation(nom_anim):
		anim_player.play(nom_anim)
	elif anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(nom_anim):
		# Si un AnimationPlayer est en train de tourner sur une autre animation, on l'arrête pour libérer le sprite
		if anim_player and anim_player.is_playing() and anim_player.current_animation != nom_anim:
			anim_player.stop()
		anim_sprite.play(nom_anim)

func _attendre_fin_animation_ou_timer(duree_fallback: float) -> void:
	if anim_sprite and anim_sprite.sprite_frames:
		var current_anim = anim_sprite.animation
		if anim_sprite.sprite_frames.has_animation(current_anim):
			if not anim_sprite.sprite_frames.get_animation_loop(current_anim):
				await anim_sprite.animation_finished
				return
	await attendre(duree_fallback)

func quitter_et_liberer() -> void:
	est_elimine = true
	deja_active = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	input_pickable = false
	var col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col:
		col.set_deferred("disabled", true)
	hide()
	queue_free()

func arret_idle() -> void:
	vitesse_deplacement = 0.0
	velocity = Vector2.ZERO
	if possede_animation("idle"):
		jouer_animation("idle")
	elif possede_animation("idle_stand"):
		jouer_animation("idle_stand")

func pause_nette() -> void:
	vitesse_deplacement = 0.0
	velocity = Vector2.ZERO
	if anim_sprite:
		anim_sprite.pause()
	if anim_player and anim_player.is_playing():
		anim_player.pause()

func reprendre_marche() -> void:
	vitesse_deplacement = 40.0
	if anim_sprite and not anim_sprite.is_playing():
		anim_sprite.play()
	if anim_player and anim_player.is_playing() == false and anim_player.current_animation != "":
		anim_player.play()
	if possede_animation("walk"):
		jouer_animation("walk")

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# Les dégâts proviennent normalement des projectiles du joueur (cadence de tir et
	# GunPower appliqués) : le clic direct reste une option de debug.
	if not degats_au_clic:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		subir_degats(1)

func subir_degats_missile(degats_recus: int, _pos_impact: Vector2 = Vector2.ZERO) -> void:
	subir_degats(degats_recus)

func subir_degats(quantite: int) -> void:
	if est_elimine or invincible:
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
	
	# Désactivation immédiate des collisions pour ne pas bloquer les tirs vers les ennemis vivants
	collision_layer = 0
	collision_mask = 0
	input_pickable = false
	var col_mort = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_mort:
		col_mort.set_deferred("disabled", true)
		
	GlobalSettings.ajouter_score(points_score)
	
	if deverrouiller_stop_a_la_mort:
		_deverrouiller_stop_lie()

	if not message_a_la_mort.is_empty():
		_afficher_message_mort_hud()
	
	if changer_niveau_a_la_mort:
		if delai_transition_mort_sec <= 0.0:
			GlobalSettings.declencher_changement_niveau()
		else:
			get_tree().create_timer(delai_transition_mort_sec, false).timeout.connect(func():
				GlobalSettings.declencher_changement_niveau()
			)
	
	# --- NOUVEAU: Effets d'explosion ---
	if effet_mort != MortEffet.OFF:
		if delai_avant_explosion > 0.0:
			await attendre(delai_avant_explosion)
		
		match effet_mort:
			MortEffet.EXPLOSION, MortEffet.PERSONNALISE:
				var scene_explosion = _get_explosion_scene_mort()
				if scene_explosion:
					_spawn_explosion_actor(scene_explosion, global_position)
					await attendre(1.0)  # Attendre que l'explosion se joue
			MortEffet.PARTICULES:
				_creer_effet_particules_generique()
				await attendre(0.8)
	
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

func _afficher_message_mort_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasMortMessage_" + name
	canvas.layer = 110

	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg)

	var label := BitmapText.new()
	label.font_folder = "res://images/fonts/" + police_message_mort
	label.alignement = "centre"
	label.pixel_scale = 1.0
	label.set_text(message_a_la_mort)
	container.add_child(label)

	var txt_size = label.size
	var pad = Vector2(16.0, 8.0)
	bg.size = txt_size + (pad * 2.0)
	bg.position = -bg.size / 2.0
	label.position = bg.position + pad

	var vp_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(320, 240)
	container.position = vp_size / 2.0

	canvas.add_child(container)
	var scene = get_tree().current_scene if get_tree() else null
	if scene:
		scene.add_child(canvas)
	else:
		get_tree().root.add_child(canvas)

	get_tree().create_timer(duree_message_mort_sec, false).timeout.connect(func():
		if is_instance_valid(canvas):
			canvas.queue_free()
	)

func _deverrouiller_stop_lie() -> void:
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera and camera.has_method("deverrouiller_stop"):
		var nom_target = nom_stop_declencheur
		if nom_target == "" and declencheur_stop != null and not declencheur_stop.is_empty():
			var node = get_node_or_null(declencheur_stop)
			if node:
				nom_target = node.name
		camera.deverrouiller_stop(nom_target)

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

## Adaptation dynamique universelle des hitboxes RectangleShape2D selon l'orientation de l'animation.
func _initialiser_hitbox_dynamique() -> void:
	if is_instance_valid(anim_sprite):
		if not anim_sprite.animation_changed.is_connected(_on_animation_changed_base):
			anim_sprite.animation_changed.connect(_on_animation_changed_base)
		_on_animation_changed_base()

func _on_animation_changed_base() -> void:
	if not is_instance_valid(anim_sprite):
		return
	var col = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not col or not col.shape is RectangleShape2D:
		return
		
	var shape = col.shape as RectangleShape2D
	var anim_name = anim_sprite.animation.to_lower()
	
	# Ne pas écraser les hitboxes spécifiques ni les véhicules / boss à structures personnalisées
	if self is VehicleActorBase or self.has_method("_mettre_a_jour_hitbox_specifique") or self.has_method("_mettre_a_jour_hitbox"):
		return
		
	# Catégorie 1 : Vue de dos (walk_fwrd, dos) -> Hitbox étroite (32px-34px)
	if "fwrd" in anim_name or "dos" in anim_name:
		shape.size.x = 34.0
		col.position.x = 0.0
	# Catégorie 2 : Vue de profil / marche latérale (walk, walk_shoot, walk_profile) -> Hitbox ajustée et orientée vers l'avant
	elif "walk" in anim_name or "profile" in anim_name or "side" in anim_name:
		shape.size.x = 42.0
		var sens_regard = 1.0 if direction_deplacement == "gauche_vers_droite" else -1.0
		if inverser_visuel:
			sens_regard = -sens_regard
		col.position.x = sens_regard * 6.0
	# Catégorie 3 : Vue de face (idle, shoot, popup, hit, die, stand) -> RESSERRÉE OBLIGATOIREMENT (32px-36px)
	else:
		shape.size.x = 36.0
		col.position.x = 0.0

## --- Effets d'explosion pour ActorBase ---

func _get_explosion_scene_mort() -> PackedScene:
	match effet_mort:
		MortEffet.EXPLOSION:
			return load("res://aseprite/effect/xexpl2.tscn")  # Moyenne par défaut
		MortEffet.PERSONNALISE:
			return scene_explosion_personnalisee
		MortEffet.OFF, MortEffet.PARTICULES:
			return null
		_:
			return null

func _spawn_explosion_actor(scene: PackedScene, centre: Vector2) -> void:
	if not scene:
		return
	
	var parent_cible := get_parent() if get_parent() else self
	var pos_haut = centre + Vector2(0, -20)
	var pos_bas = centre + Vector2(0, 20)
	
	match explosion_pattern:
		ExplosionPattern.SIMPLE:
			_spawn_expl_at(scene, centre, parent_cible)
		ExplosionPattern.DOUBLE:
			_spawn_expl_at(scene, pos_haut, parent_cible)
			await attendre(0.06)
			_spawn_expl_at(scene, pos_bas, parent_cible)
		ExplosionPattern.CASCADE:
			_spawn_expl_at(scene, pos_haut, parent_cible)
			await attendre(0.06)
			_spawn_expl_at(scene, centre, parent_cible)
			await attendre(0.06)
			_spawn_expl_at(scene, pos_bas, parent_cible)

func _spawn_expl_at(scene: PackedScene, pos: Vector2, parent: Node) -> void:
	var e = scene.instantiate() as Node2D
	if e:
		e.z_index = 50
		if mode_positionnement_apparitions == "global_world_space":
			e.global_position = pos
		else:
			e.position = parent.to_local(pos)
		parent.add_child(e)
		
		var anim := e.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim:
			var anim_nom = "explose" if anim.sprite_frames.has_animation("explose") else "default"
			anim.play(anim_nom)
			anim.animation_finished.connect(func():
				if is_instance_valid(e):
					e.queue_free()
			)
		else:
			get_tree().create_timer(0.8, false).timeout.connect(func():
				if is_instance_valid(e):
					e.queue_free()
			)

func _creer_effet_particules_generique() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var particles = CPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = 30
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(1.0, 0.6, 0.2, 1.0) # Orange feu
	parent.add_child(particles)
	particles.emitting = true
