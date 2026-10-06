class_name VehicleChaseController
extends Node2D

## Contrôleur de séquence de véhicules T2 (Level 6 xroad)
## Séquence: Intro → Van entre/positionne → Copter attaque → Juggernaut RAM → Van sort → Juggernaut repasse → Fin

signal chase_completed()
signal game_over()
signal van_respawn()

@export var is_level3: bool = false

@export_group("Van (Configuration & Position)")
@export var van_pv_max: int = 20                     ## PV Max du Van (ActorBase)
@export var van_invincible: bool = false             ## Invulnérabilité du Van (ActorBase)
@export var van_recoil_push_px: float = 60.0         ## Distance de projection du van lors de l'impact bélier (pixels)
@export var van_recoil_push_sec: float = 0.2         ## Temps de poussée vers l'avant lors du choc (secondes)
@export var van_recoil_hold_sec: float = 0.8         ## Temps de maintien sous l'impact (secondes)
@export var van_recoil_return_sec: float = 0.6       ## Temps du retour du coil à la position stationnaire (secondes)
@export var van_position_x_ratio: float = 0.45       ## Position X du van (ratio dans la lucarne)
@export var van_position_x_adjustment: float = 0.0   ## Ajustement fin X en pixels
@export var van_position_y_ratio: float = 0.32        ## Position Y du van (ratio par rapport à la lucarne)
@export var van_position_y_adjustment: float = 10.0  ## Ajustement fin Y en pixels

@export_group("Copter (Configuration & Position HitRoof)")
@export var copter_pv_max: int = 30                  ## PV Max du Copter (ActorBase)
@export var copter_invincible: bool = false          ## Invulnérabilité du Copter (ActorBase)
@export var copter_attack_damage: int = 1            ## Dégâts infligés par tir
@export var copter_attack_interval: float = 1.2      ## Intervalle entre chaque tir (secondes)
@export var copter_hover_speed: float = 3.0          ## Vitesse d'oscillation en vol
@export var copter_recoil_distance_px: float = 20.0  ## Distance de sursaut arrière lors d'un dégât (pixels)
@export var copter_recoil_duration_sec: float = 0.5  ## Durée totale du sursaut arrière lors d'un dégât (secondes)
@export var copter_esquive_distance_px: float = 100.0 ## Distance de retrait en esquive (pixels)
@export var copter_esquive_duration_sec: float = 1.0 ## Durée du retrait en esquive (secondes)
@export var copter_esquive_pause_sec: float = 1.5   ## Temps de pause hors écran avant la ré-entrée (secondes)
@export var copter_offset_hit_roof: Vector2 = Vector2(-70.0, -45.0)  ## Offset XY du copter par rapport à HitRoof du van
@export var copter_position_x_adjustment: float = 0.0  ## Ajustement fin X supplémentaire en pixels
@export var copter_position_y_adjustment: float = 0.0  ## Ajustement fin Y supplémentaire en pixels

@export_group("Juggernaut (Configuration & Position HitRear)")
@export var jug_pv_max: int = 50                     ## PV Max du Juggernaut (ActorBase)
@export var jug_invincible: bool = false             ## Invulnérabilité du Juggernaut (ActorBase)
@export var jug_distance_chase_px: float = 40.0      ## Point d'origine / distance de garde derrière le van en phase CHASE (pixels)
@export var jug_ram_push_px: float = 80.0            ## Distance de course du bélier vers l'avant lors du RAM (pixels)
@export var jug_temps_chase_sec: float = 3.5         ## Durée de l'état CHASE entre les attaques (secondes)
@export var jug_temps_anticipation_sec: float = 1.0  ## Durée d'avertissement / anticipation avant la charge (secondes)
@export var jug_ram_push_sec: float = 0.6            ## Durée de la charge vers l'avant jusqu'au contact (secondes)
@export var jug_ram_hold_sec: float = 0.8            ## Durée de maintien sous l'impact collé au van (secondes)
@export var jug_ram_return_sec: float = 1.5          ## Durée du retrait vers la position stationnaire de garde (secondes)
@export var jug_position_x_adjustment: float = 0.0   ## Ajustement fin X en pixels (relatif à HitRear - front_bumper_offset)
@export var jug_position_y_adjustment: float = 0.0   ## Ajustement fin Y en pixels (relatif à HitRear)

@export_group("Animations")
@export var van_entree_duree_secondes: float = 2.0 ## Durée de l'animation d'entrée du van (secondes)
@export_enum("LINEAR", "SINE_IN", "SINE_OUT", "SINE_IN_OUT", "QUAD_IN", "QUAD_OUT", "QUAD_IN_OUT", "CUBIC_IN", "CUBIC_OUT", "CUBIC_IN_OUT")
var van_entree_easing: int = 2 ## Type d'easing pour l'entrée du van (dropdown)
@export var delai_apres_van_secondes: float = 1.5 ## Délai après le van avant le copter (secondes)
@export var copter_entree_duree_secondes: float = 1.5 ## Durée de l'animation d'entrée du copter (secondes)
@export_enum("LINEAR", "SINE_IN", "SINE_OUT", "SINE_IN_OUT", "QUAD_IN", "QUAD_OUT", "QUAD_IN_OUT", "CUBIC_IN", "CUBIC_OUT", "CUBIC_IN_OUT")
var copter_entree_easing: int = 2 ## Type d'easing pour l'entrée du copter (dropdown)
@export var jug_entree_duree_secondes: float = 2.0 ## Durée de l'animation d'entrée du Jug (secondes)
@export_enum("LINEAR", "SINE_IN", "SINE_OUT", "SINE_IN_OUT", "QUAD_IN", "QUAD_OUT", "QUAD_IN_OUT", "CUBIC_IN", "CUBIC_OUT", "CUBIC_IN_OUT")
var jug_entree_easing: int = 2 ## Type d'easing pour l'entrée du Jug (dropdown)
@export var van_sortie_duree_secondes: float = 2.5 ## Durée de l'animation de sortie du van (secondes)
@export var jug_passage_duree_secondes: float = 4.0 ## Durée du passage final du Jug (secondes)

@export_group("Effets Visuels d'Impact")
@export var enable_hit_flash: bool = true             ## Activer l'effet de flash blanc à l'impact sur les morceaux destructibles
@export var hit_flash_intensity: float = 3.5          ## Intensité du flash blanc
@export var hit_flash_duration_sec: float = 0.08      ## Durée du flash blanc en secondes

@export_group("Interactions")
@export var enable_jug_van_interaction: bool = true ## Activer les réactions du van aux attaques du Jug

var camera: Camera2D = null
var vehicule_joueur: Node2D = null
var boss_copter: Node2D = null
var boss_jug: Node2D = null
var _respawn_en_cours: bool = false

# Scènes chargées dynamiquement
var scene_copter: PackedScene = preload("res://aseprite/vehicules/xcopter.tscn")
var scene_jug: PackedScene = preload("res://aseprite/vehicules/xjug.tscn")
var scene_van: PackedScene = preload("res://aseprite/vehicules/xsvan.tscn")

func _ready() -> void:
	call_deferred("_initialiser")
	
	# Configurer l'entrée pour relancer l'animation de van (touche R pour test)
	if not Engine.is_editor_hint():
		set_process_input(true)

func _initialiser() -> void:
	camera = get_viewport().get_camera_2d() if get_viewport() else null
	
	if is_level3:
		print("[VEHICLE CHASE] Level 3 : aucun boss forcé.")
	else:
		print("[VEHICLE CHASE] Level 6 : Démarrage après intro")
		_demarrer_sequence_apres_intro()

func _demarrer_sequence_apres_intro() -> void:
	if camera and "delai_intro_secondes" in camera:
		var delai_intro = camera.delai_intro_secondes
		print("[VEHICLE CHASE] Attente intro: ", delai_intro, " secondes")
		await get_tree().create_timer(delai_intro, false).timeout
	
	_demarrer_phase_van_entree()

func _get_logical_viewport_size() -> Vector2:
	if camera and "largeur_lucarne" in camera and "hauteur_lucarne" in camera:
		return Vector2(float(camera.largeur_lucarne), float(camera.hauteur_lucarne))
	return Vector2(288.0, 176.0)

func _demarrer_phase_van_entree() -> void:
	print("[VEHICLE CHASE] Phase 1: Van entre par la gauche")
	
	var conteneur = get_node_or_null("../EnnemisPlaces")
	if conteneur == null:
		conteneur = get_parent()

	vehicule_joueur = scene_van.instantiate()
	conteneur.add_child(vehicule_joueur)
	
	# Activer le bouclage avec la caméra pour que le van boucle quand la caméra boucle
	if "boucle_avec_camera" in vehicule_joueur:
		vehicule_joueur.set("boucle_avec_camera", true)
	
	# ==========================================
	# POSITIONNEMENT VAN - ENTRÉE
	# ==========================================
	var camera_x = camera.get_screen_center_position().x if camera else 0.0
	var vp_size = _get_logical_viewport_size()
	var viewport_w = vp_size.x
	# AJUSTEMENT ICI: Position de départ à gauche hors écran
	# - viewport_w = bord gauche de l'écran
	# - 100.0 = marge supplémentaire pour être sûr hors écran
	vehicule_joueur.global_position.x = camera_x - (viewport_w * 0.5) - 100.0
	# AJUSTEMENT ICI: Position Y du van (ratio du bas, 0.0 = au sol)
	var camera_y = camera.get_screen_center_position().y if camera else -10.0
	var viewport_h = vp_size.y
	vehicule_joueur.global_position.y = camera_y - (viewport_h * van_position_y_ratio)
	
	# Appliquer les propriétés ActorBase configurées
	if "pv_max" in vehicule_joueur:
		vehicule_joueur.pv_max = van_pv_max
		vehicule_joueur.pv_actuels = van_pv_max
	if "invincible" in vehicule_joueur:
		vehicule_joueur.invincible = van_invincible
	if "recoil_push_px" in vehicule_joueur:
		vehicule_joueur.recoil_push_px = van_recoil_push_px
	if "recoil_push_sec" in vehicule_joueur:
		vehicule_joueur.recoil_push_sec = van_recoil_push_sec
	if "recoil_hold_sec" in vehicule_joueur:
		vehicule_joueur.recoil_hold_sec = van_recoil_hold_sec
	if "recoil_return_sec" in vehicule_joueur:
		vehicule_joueur.recoil_return_sec = van_recoil_return_sec

	# Activer le van
	if vehicule_joueur.has_method("activer_acteur"):
		vehicule_joueur.activer_acteur()
	
	# Connecter mort du joueur
	if vehicule_joueur.has_signal("player_died"):
		vehicule_joueur.player_died.connect(_on_player_died)
	
	# ==========================================
	# ACTIVER LE POSITIONNEMENT CAMÉRA-RELATIF AVEC ANIMATION INTÉGRÉE
	# ==========================================
	# Activer le système de positionnement caméra-relatif (comme le Jug)
	# L'animation d'entrée est maintenant gérée par le van lui-même
	if vehicule_joueur.has_method("enable_camera_positionning"):
		var easing_string = _get_easing_string_from_enum(van_entree_easing)
		vehicule_joueur.enable_camera_positionning(van_position_x_ratio, van_position_x_adjustment, van_position_y_ratio, van_position_y_adjustment, true, van_entree_duree_secondes, easing_string)
	# Configuration initiale - le van utilisera ses propres @export après ça
	if "position_x_ratio" in vehicule_joueur:
		vehicule_joueur.set("position_x_ratio", van_position_x_ratio)
	if "position_x_adjustment" in vehicule_joueur:
		vehicule_joueur.set("position_x_adjustment", van_position_x_adjustment)
	if "position_y_ratio" in vehicule_joueur:
		vehicule_joueur.set("position_y_ratio", van_position_y_ratio)
	if "position_y_adjustment" in vehicule_joueur:
		vehicule_joueur.set("position_y_adjustment", van_position_y_adjustment)
	
	print("[VEHICLE CHASE] Van positionnement caméra activé avec animation intégrée")
	# Attendre que l'animation d'entrée du van soit finie + délai configuré
	await get_tree().create_timer(van_entree_duree_secondes + delai_apres_van_secondes, false).timeout
	
	_demarrer_phase_copter_entree()

func _demarrer_phase_copter_entree() -> void:
	print("[VEHICLE CHASE] Phase 2: Copter entre dans le coin")
	
	var conteneur = get_node_or_null("../EnnemisPlaces")
	if conteneur == null:
		conteneur = get_parent()

	boss_copter = scene_copter.instantiate()
	boss_copter.global_position = Vector2(-2000.0, -2000.0)
	conteneur.add_child(boss_copter)
	
	# Activer le bouclage avec la caméra pour que le copter boucle quand la caméra boucle
	if "boucle_avec_camera" in boss_copter:
		boss_copter.set("boucle_avec_camera", true)
	
	# Appliquer les propriétés ActorBase et combat configurées
	if "pv_max" in boss_copter:
		boss_copter.pv_max = copter_pv_max
		boss_copter.pv_actuels = copter_pv_max
	if "invincible" in boss_copter:
		boss_copter.invincible = copter_invincible
	if "attack_damage" in boss_copter:
		boss_copter.attack_damage = copter_attack_damage
	if "attack_interval" in boss_copter:
		boss_copter.attack_interval = copter_attack_interval
	if "hover_speed" in boss_copter:
		boss_copter.hover_speed = copter_hover_speed
	if "recoil_distance_px" in boss_copter:
		boss_copter.recoil_distance_px = copter_recoil_distance_px
	if "recoil_duration_sec" in boss_copter:
		boss_copter.recoil_duration_sec = copter_recoil_duration_sec
	if "esquive_distance_px" in boss_copter:
		boss_copter.esquive_distance_px = copter_esquive_distance_px
	if "esquive_duration" in boss_copter:
		boss_copter.esquive_duration = copter_esquive_duration_sec
	if "esquive_pause_sec" in boss_copter:
		boss_copter.esquive_pause_sec = copter_esquive_pause_sec

	# Connecter mort du copter
	if boss_copter.has_signal("exploded"):
		boss_copter.exploded.connect(on_copter_detruit)
	elif boss_copter.has_signal("tree_exited"):
		boss_copter.tree_exited.connect(on_copter_detruit)
	
	# ==========================================
	# POSITIONNEMENT COPTER RELATIF À HITROOF DU VAN
	# ==========================================
	# Passer l'offset HitRoof depuis le contrôleur vers le copter
	if "offset_relatif_hit_roof" in boss_copter:
		boss_copter.set("offset_relatif_hit_roof", copter_offset_hit_roof)
	if "position_x_adjustment" in boss_copter:
		boss_copter.set("position_x_adjustment", copter_position_x_adjustment)
	if "position_y_adjustment" in boss_copter:
		boss_copter.set("position_y_adjustment", copter_position_y_adjustment)
	
	# Activer le positionnement avec animation d'entrée
	if boss_copter.has_method("enable_camera_positionning"):
		var easing_string = _get_easing_string_from_enum(copter_entree_easing)
		boss_copter.enable_camera_positionning(0.20, copter_position_x_adjustment, 0.25, copter_position_y_adjustment, true, copter_entree_duree_secondes, easing_string)
	
	# Activer le copter APRÈS avoir configuré son entrée hors écran
	if boss_copter.has_method("activer_acteur"):
		boss_copter.activer_acteur()
		print("[VEHICLE CHASE] Copter activé")
	
	print("[VEHICLE CHASE] Copter positionnement HitRoof activé avec animation intégrée")


func on_copter_detruit() -> void:
	print("[VEHICLE CHASE] Copter détruit - sortie de l'écran")
	
	if boss_copter and is_instance_valid(boss_copter):
		# Désactiver le positionnement relatif pour laisser le tween déplacer le copter librement
		if boss_copter.has_method("disable_camera_positionning"):
			boss_copter.disable_camera_positionning()

		# Faire sortir le copter vers la gauche hors écran
		var copter_camera = get_viewport().get_camera_2d() if get_viewport() else null
		if copter_camera:
			var camera_x = copter_camera.get_screen_center_position().x
			var vp_size = _get_logical_viewport_size()
			var viewport_w = vp_size.x
			var position_sortie = camera_x - (viewport_w * 0.5) - 100.0
			
			var tween = create_tween()
			tween.set_ease(Tween.EASE_IN)
			tween.set_trans(Tween.TRANS_QUAD)
			tween.tween_property(boss_copter, "global_position:x", position_sortie, 1.0)
			await tween.finished
		
		# Détruire le copter après sortie
		boss_copter.queue_free()
		boss_copter = null
	
	# Continuer avec le Juggernaut
	await get_tree().create_timer(1.5, false).timeout
	_demarrer_phase_jug_entree()

func _demarrer_phase_jug_entree() -> void:
	print("[VEHICLE CHASE] Phase 3: Juggernaut entre par la gauche")
	
	var conteneur = get_node_or_null("../EnnemisPlaces")
	if conteneur == null:
		conteneur = get_parent()

	boss_jug = scene_jug.instantiate()
	conteneur.add_child(boss_jug)
	
	# Activer le bouclage avec la caméra pour que le jug boucle quand la caméra boucle
	if "boucle_avec_camera" in boss_jug:
		boss_jug.set("boucle_avec_camera", true)
	
	# Appliquer les propriétés ActorBase et combat configurées
	if "pv_max" in boss_jug:
		boss_jug.pv_max = jug_pv_max
		boss_jug.pv_actuels = jug_pv_max
	if "invincible" in boss_jug:
		boss_jug.invincible = jug_invincible
	if "distance_chase_px" in boss_jug:
		boss_jug.distance_chase_px = jug_distance_chase_px
	if "ram_push_px" in boss_jug:
		boss_jug.ram_push_px = jug_ram_push_px
	if "temps_chase_sec" in boss_jug:
		boss_jug.temps_chase_sec = jug_temps_chase_sec
	if "temps_anticipation_sec" in boss_jug:
		boss_jug.temps_anticipation_sec = jug_temps_anticipation_sec
	if "ram_push_sec" in boss_jug:
		boss_jug.ram_push_sec = jug_ram_push_sec
	if "ram_hold_sec" in boss_jug:
		boss_jug.ram_hold_sec = jug_ram_hold_sec
	if "ram_return_sec" in boss_jug:
		boss_jug.ram_return_sec = jug_ram_return_sec
	if "enable_hit_flash" in boss_jug:
		boss_jug.enable_hit_flash = enable_hit_flash
	if "flash_intensity" in boss_jug:
		boss_jug.flash_intensity = hit_flash_intensity
	if "flash_duration_sec" in boss_jug:
		boss_jug.flash_duration_sec = hit_flash_duration_sec

	# Activer le Juggernaut
	if boss_jug.has_method("activer_acteur"):
		boss_jug.activer_acteur()
	
	# Connecter mort du Juggernaut
	if boss_jug.has_signal("boss_defeated"):
		boss_jug.boss_defeated.connect(on_jug_detruit)
	elif boss_jug.has_signal("tree_exited"):
		boss_jug.tree_exited.connect(on_jug_detruit)
	
	# Connecter les signaux d'état du Jug au van (seulement si le van existe et interaction activée)
	if vehicule_joueur and boss_jug and enable_jug_van_interaction:
		if boss_jug.has_signal("jug_state_changed"):
			boss_jug.jug_state_changed.connect(_on_jug_state_changed)
		if boss_jug.has_signal("jug_attack_started"):
			boss_jug.jug_attack_started.connect(_on_jug_attack_started)
		if boss_jug.has_signal("jug_impact_occurred"):
			boss_jug.jug_impact_occurred.connect(_on_jug_impact_occurred)
	
	# Activer le positionnement HitRear avec animation d'entrée intégrée
	# (ratios passés = fallback si le van n'est pas trouvé, non utilisés en gameplay normal)
	if boss_jug.has_method("enable_camera_positionning"):
		var easing_string = _get_easing_string_from_enum(jug_entree_easing)
		boss_jug.enable_camera_positionning(0.35, jug_position_x_adjustment, 0.32, jug_position_y_adjustment, true, jug_entree_duree_secondes, easing_string)
	
	# Passer les ajustements fins depuis le contrôleur vers le jug
	if "position_x_adjustment" in boss_jug:
		boss_jug.set("position_x_adjustment", jug_position_x_adjustment)
	if "position_y_adjustment" in boss_jug:
		boss_jug.set("position_y_adjustment", jug_position_y_adjustment)
	
	print("[VEHICLE CHASE] Juggernaut positionnement HitRear activé avec animation intégrée")


func on_jug_detruit() -> void:
	print("[VEHICLE CHASE] Juggernaut détruit par le joueur")
	
	# Déconnecter les signaux du Jug du van
	_disconnect_jug_signals()
	
	if boss_jug:
		boss_jug.queue_free()
		boss_jug = null
	
	await get_tree().create_timer(1.0, false).timeout
	_demarrer_phase_van_sortie()

func _demarrer_phase_van_sortie() -> void:
	print("[VEHICLE CHASE] Phase 4: Van sort par l'avant (vers la droite)")
	
	if vehicule_joueur and is_instance_valid(vehicule_joueur):
		# Animer position_x_ratio au-delà du bord droit de l'écran (1.5)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(vehicule_joueur, "position_x_ratio", 1.5, van_sortie_duree_secondes)
		await tween.finished
		
		# Déconnecter les signaux du Jug avant de détruire le van
		_disconnect_jug_signals()
		
		if vehicule_joueur and is_instance_valid(vehicule_joueur):
			vehicule_joueur.queue_free()
			vehicule_joueur = null
	
	await get_tree().create_timer(1.0, false).timeout
	_demarrer_phase_jug_fin()

func _demarrer_phase_jug_fin() -> void:
	print("[VEHICLE CHASE] Phase 5: Juggernaut repasse de gauche à droite")
	
	var conteneur = get_node_or_null("../EnnemisPlaces")
	if conteneur == null:
		conteneur = get_parent()

	boss_jug = scene_jug.instantiate()
	conteneur.add_child(boss_jug)
	
	# Activer le bouclage avec la caméra pour que le jug boucle quand la caméra boucle
	if "boucle_avec_camera" in boss_jug:
		boss_jug.set("boucle_avec_camera", true)
	
	var vp_size = _get_logical_viewport_size()
	var viewport_w = vp_size.x
	var viewport_h = vp_size.y
	var camera_x = camera.get_screen_center_position().x if camera else 0.0
	var camera_y = camera.get_screen_center_position().y if camera else 0.0
	var jug_y_ratio = van_position_y_ratio
	
	# Désactiver le mode caméra-relatif pour permettre le passage cinématique libre
	if boss_jug.has_method("disable_camera_positionning"):
		boss_jug.disable_camera_positionning()
	
	# ==========================================
	# POSITIONNEMENT JUGGERNAUT - PASSAGE FINAL
	# ==========================================
	boss_jug.global_position.x = camera_x - (viewport_w * 0.5) - 650.0
	boss_jug.global_position.y = camera_y - (viewport_h * jug_y_ratio) + 10.0 + jug_position_y_adjustment
	
	# Activer le Juggernaut
	if boss_jug.has_method("activer_acteur"):
		boss_jug.activer_acteur()
	
	# ==========================================
	# TWEEN JUGGERNAUT - PASSAGE GAUCHE → DROITE
	# ==========================================
	var tween = create_tween()
	var jug_passage_ease = _get_tween_ease_from_enum(jug_entree_easing)
	tween.set_ease(jug_passage_ease)
	tween.set_trans(Tween.TRANS_LINEAR)
	var position_finale = camera_x + (viewport_w * 0.5) + 650.0
	tween.tween_property(boss_jug, "global_position:x", position_finale, jug_passage_duree_secondes)
	await tween.finished
	
	boss_jug.queue_free()
	boss_jug = null
	
	_terminer_sequence()

func _terminer_sequence() -> void:
	print("[VEHICLE CHASE] Fin de la séquence véhicule -> transition au niveau suivant")
	chase_completed.emit()
	var global_settings = get_node_or_null("/root/GlobalSettings")
	if global_settings and global_settings.has_method("declencher_changement_niveau"):
		global_settings.declencher_changement_niveau()

func _on_player_died() -> void:
	print("[VEHICLE CHASE] Van détruit - vérification des crédits")
	
	# Empêcher les respawn multiples
	if _respawn_en_cours:
		print("[VEHICLE CHASE] Respawn déjà en cours, ignoré")
		return
	
	_respawn_en_cours = true
	# Vérifier s'il reste des crédits
	var global_settings = get_node_or_null("/root/GlobalSettings")
	if global_settings:
		if global_settings.credits_restants > 0:
			print("[VEHICLE CHASE] Crédits restants: ", global_settings.credits_restants, " - consommation d'un crédit")
			global_settings.credits_restants -= 1
			global_settings.credits_modifies.emit(global_settings.credits_restants)
			
			if global_settings.credits_restants <= 0:
				print("[VEHICLE CHASE] Plus de crédits après consommation - Game Over")
				global_settings.credits_restants = 0
				global_settings.partie_perdue = true
				game_over.emit()
				# Laisser l'explosion du van se terminer avant d'afficher le Game Over
				await get_tree().create_timer(1.2, false).timeout
				global_settings.partie_terminee.emit(global_settings.score)
			else:
				# Faire sortir l'ennemi actif hors de l'écran pendant la destruction du van
				if boss_copter and is_instance_valid(boss_copter) and not boss_copter.est_elimine:
					if boss_copter.has_method("_declencher_esquive"):
						boss_copter._declencher_esquive()
				if boss_jug and is_instance_valid(boss_jug) and not boss_jug.est_elimine:
					if boss_jug.has_method("battre_en_retraite_temporaire"):
						boss_jug.battre_en_retraite_temporaire()
				
				_respawn_van()
		else:
			print("[VEHICLE CHASE] Plus de crédits - Game Over")
			global_settings.credits_restants = 0
			global_settings.partie_perdue = true
			game_over.emit()
			await get_tree().create_timer(1.2, false).timeout
			global_settings.partie_terminee.emit(global_settings.score)

func _respawn_van() -> void:
	print("[VEHICLE CHASE] Début du respawn du van (les boss conservent leurs PV et état)")
	_disconnect_jug_signals()
	vehicule_joueur = null
	
	# Attendre la fin de l'explosion du van précédent
	await get_tree().create_timer(1.2, false).timeout
	
	# Réinitialiser la vie du joueur via GlobalSettings si applicable
	var global_settings = get_node_or_null("/root/GlobalSettings")
	if global_settings:
		global_settings.vie_actuelle = global_settings.vie_max
		print("[VEHICLE CHASE] Vie réinitialisée: ", global_settings.vie_actuelle, "/", global_settings.vie_max)
	
	var conteneur = get_node_or_null("../EnnemisPlaces")
	if conteneur == null:
		conteneur = get_parent()

	vehicule_joueur = scene_van.instantiate()
	conteneur.add_child(vehicule_joueur)
	
	if "boucle_avec_camera" in vehicule_joueur:
		vehicule_joueur.set("boucle_avec_camera", true)
	
	if "pv_max" in vehicule_joueur:
		vehicule_joueur.pv_max = van_pv_max
		vehicule_joueur.pv_actuels = van_pv_max
	if "invincible" in vehicule_joueur:
		vehicule_joueur.invincible = van_invincible
	if "recoil_push_px" in vehicule_joueur:
		vehicule_joueur.recoil_push_px = van_recoil_push_px
	if "recoil_push_sec" in vehicule_joueur:
		vehicule_joueur.recoil_push_sec = van_recoil_push_sec
	if "recoil_hold_sec" in vehicule_joueur:
		vehicule_joueur.recoil_hold_sec = van_recoil_hold_sec
	if "recoil_return_sec" in vehicule_joueur:
		vehicule_joueur.recoil_return_sec = van_recoil_return_sec

	if vehicule_joueur.has_method("activer_acteur"):
		vehicule_joueur.activer_acteur()
	
	if vehicule_joueur.has_signal("player_died"):
		vehicule_joueur.player_died.connect(_on_player_died)
	
	# Entrée de reculon par la droite (from_right = true)
	if vehicule_joueur.has_method("enable_camera_positionning"):
		var easing_string = _get_easing_string_from_enum(van_entree_easing)
		vehicule_joueur.enable_camera_positionning(van_position_x_ratio, van_position_x_adjustment, van_position_y_ratio, van_position_y_adjustment, true, van_entree_duree_secondes, easing_string, true)
	
	if "position_x_ratio" in vehicule_joueur:
		vehicule_joueur.set("position_x_ratio", van_position_x_ratio)
	if "position_x_adjustment" in vehicule_joueur:
		vehicule_joueur.set("position_x_adjustment", van_position_x_adjustment)
	if "position_y_ratio" in vehicule_joueur:
		vehicule_joueur.set("position_y_ratio", van_position_y_ratio)
	if "position_y_adjustment" in vehicule_joueur:
		vehicule_joueur.set("position_y_adjustment", van_position_y_adjustment)
	
	print("[VEHICLE CHASE] Van en cours d'entrée de reculon par la droite...")
	# Attendre que le van arrive à son emplacement STATIONNAIRE avant que l'ennemi ré-attaque
	await get_tree().create_timer(van_entree_duree_secondes + 0.5, false).timeout
	
	# Reconnecter les signaux du Jug vers le nouveau van si le Jug est en vie
	if boss_jug and is_instance_valid(boss_jug) and not boss_jug.est_elimine and enable_jug_van_interaction:
		if boss_jug.has_signal("jug_state_changed"):
			boss_jug.jug_state_changed.connect(_on_jug_state_changed)
		if boss_jug.has_signal("jug_attack_started"):
			boss_jug.jug_attack_started.connect(_on_jug_attack_started)
		if boss_jug.has_signal("jug_impact_occurred"):
			boss_jug.jug_impact_occurred.connect(_on_jug_impact_occurred)
		# Le Juggernaut refait son entrée par la gauche pour ré-attaquer
		if boss_jug.has_method("enable_camera_positionning"):
			var jug_easing_string = _get_easing_string_from_enum(jug_entree_easing)
			boss_jug.enable_camera_positionning(0.35, jug_position_x_adjustment, 0.32, jug_position_y_adjustment, true, jug_entree_duree_secondes, jug_easing_string)
			print("[VEHICLE CHASE] Juggernaut relance son entrée pour ré-attaquer")
	
	# Si c'est le Copter qui est actif : il refait son entrée par la gauche
	if boss_copter and is_instance_valid(boss_copter) and not boss_copter.est_elimine:
		if boss_copter.has_method("_demarrer_nouvelle_entree"):
			boss_copter._demarrer_nouvelle_entree()
			print("[VEHICLE CHASE] Copter relance son entrée pour ré-attaquer")

	van_respawn.emit()
	_respawn_en_cours = false
	print("[VEHICLE CHASE] Van respawn complété et positionné à STATIONNAIRE")

func _on_jug_state_changed(new_state: int) -> void:
	if vehicule_joueur and is_instance_valid(vehicule_joueur) and vehicule_joueur.has_method("on_jug_state_changed"):
		vehicule_joueur.on_jug_state_changed(new_state)

func _on_jug_attack_started() -> void:
	if vehicule_joueur and is_instance_valid(vehicule_joueur) and vehicule_joueur.has_method("on_jug_attack_started"):
		vehicule_joueur.on_jug_attack_started()

func _on_jug_impact_occurred() -> void:
	if vehicule_joueur and is_instance_valid(vehicule_joueur) and vehicule_joueur.has_method("on_jug_impact_occurred"):
		vehicule_joueur.on_jug_impact_occurred()

func _disconnect_jug_signals() -> void:
	if boss_jug and is_instance_valid(boss_jug):
		if boss_jug.is_connected("jug_state_changed", _on_jug_state_changed):
			boss_jug.jug_state_changed.disconnect(_on_jug_state_changed)
		if boss_jug.is_connected("jug_attack_started", _on_jug_attack_started):
			boss_jug.jug_attack_started.disconnect(_on_jug_attack_started)
		if boss_jug.is_connected("jug_impact_occurred", _on_jug_impact_occurred):
			boss_jug.jug_impact_occurred.disconnect(_on_jug_impact_occurred)

func replay_van_entry() -> void:
	if vehicule_joueur and vehicule_joueur.has_method("replay_entry_animation"):
		vehicule_joueur.replay_entry_animation()
		print("[VEHICLE CHASE] Animation d'entrée du van relancée")

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("ui_text_newline"): # Touche Entrée par défaut (Debug)
		replay_van_entry()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R: # Touche R pour replay (Debug)
		replay_van_entry()

func _get_easing_string_from_enum(enum_value: int) -> String:
	match enum_value:
		0: return "LINEAR"
		1: return "SINE_IN"
		2: return "SINE_OUT"
		3: return "SINE_IN_OUT"
		4: return "QUAD_IN"
		5: return "QUAD_OUT"
		6: return "QUAD_IN_OUT"
		7: return "CUBIC_IN"
		8: return "CUBIC_OUT"
		9: return "CUBIC_IN_OUT"
		_: return "SINE_OUT"

func _get_tween_ease_from_enum(enum_value: int) -> Tween.EaseType:
	match enum_value:
		0: return Tween.EASE_IN_OUT # LINEAR approximé par IN_OUT
		1: return Tween.EASE_IN
		2: return Tween.EASE_OUT
		3: return Tween.EASE_IN_OUT
		4: return Tween.EASE_IN
		5: return Tween.EASE_OUT
		6: return Tween.EASE_IN_OUT
		7: return Tween.EASE_IN
		8: return Tween.EASE_OUT
		9: return Tween.EASE_IN_OUT
		_: return Tween.EASE_OUT
