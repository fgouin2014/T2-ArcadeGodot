class_name XCopterBoss
extends VehicleActorBase

## XCopter Boss Controller pour Godot 4.7
## Machine d'états: ENTREE -> VOL_STATIONNAIRE (attaque) -> ESQUIVE (retrait quand touché) -> ENTREE

signal exploded()

enum CopterState { ENTREE, VOL_STATIONNAIRE, ESQUIVE, PAUSE_HORS_ECRAN, RECOIL }

# Paramètres de hovering léger (géré par animation)
@export var hover_speed: float = 3.0

# Paramètres d'attaque
@export var attack_interval: float = 1.2
@export var attack_damage: int = 1

@export_group("Positionnement Relatif au Van (HitRoof)")
@export var offset_relatif_hit_roof: Vector2 = Vector2(-70.0, -45.0) ## Décalage (X, Y) par rapport au marqueur HitRoof du Van
@export var position_x_ratio: float = 0.20 ## Fallback si pas de van
@export var position_x_adjustment: float = 0.0
@export var position_y_ratio: float = 0.25 ## Fallback Y si pas de van
@export var position_y_adjustment: float = 0.0

@export_group("Animation d'Entrée")
@export var enable_entry_animation: bool = true
@export var entry_duration: float = 1.5
@export var entry_easing: String = "SINE_OUT"

@export_group("Animation d'Esquive")
@export var esquive_duration: float = 1.0
@export var esquive_distance_px: float = 100.0 ## Distance de retrait en esquive (pixels)
@export var esquive_pause_sec: float = 1.5     ## Temps de pause hors écran avant la ré-entrée (secondes)

@export_group("Animation de Recul (Hit)")
@export var recoil_distance_px: float = 20.0   ## Distance de sursaut arrière lors d'un dégât (pixels)
@export var recoil_duration_sec: float = 0.5   ## Durée du sursaut arrière lors d'un dégât (secondes)

# Variables d'état
var current_state: CopterState = CopterState.ENTREE
var anim_time: float = 0.0
var attack_timer: float = 0.0
var _camera_positionning_enabled: bool = false
var _entry_progress: float = 0.0
var _entry_start_pos: Vector2 = Vector2.ZERO
var _entry_duration: float = 1.5
var _entry_easing: String = "SINE_OUT"
var _esquive_progress: float = 0.0
var _esquive_start_pos: Vector2 = Vector2.ZERO
var _esquive_duration: float = 1.0
var _esquive_pause_timer: float = 0.0
var recoil_timer: float = 0.0

# --- DEBUG HUD ---
var debug_hud: CanvasLayer = null

@onready var animated_rotor: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var sprite_corps: AnimatedSprite2D = get_node_or_null("SpriteCorps") as AnimatedSprite2D
@onready var copter_anim_player: AnimationPlayer = get_node_or_null("CopterAnimationPlayer") as AnimationPlayer

func _ready() -> void:
	suivre_camera_automatiquement = false
	super._ready()
	print("[XCopter] _ready appelé - position initiale: ", global_position)
	if animated_rotor:
		animated_rotor.play("default")
	
	if copter_anim_player:
		if not copter_anim_player.animation_finished.is_connected(_on_animation_finished):
			copter_anim_player.animation_finished.connect(_on_animation_finished)
	
	_initialiser_debug_hud()

func _get_logical_viewport_size(camera: Camera2D) -> Vector2:
	if camera and "largeur_lucarne" in camera and "hauteur_lucarne" in camera:
		return Vector2(float(camera.largeur_lucarne), float(camera.hauteur_lucarne))
	return Vector2(288.0, 176.0)

func _play_anim(anim_name: StringName) -> void:
	if not copter_anim_player:
		return
	if copter_anim_player.has_animation(anim_name):
		if not copter_anim_player.is_playing() or copter_anim_player.current_animation != anim_name:
			copter_anim_player.play(anim_name)
	elif anim_name == &"vol_stationnaire" and copter_anim_player.has_animation(&"stationnaire"):
		if not copter_anim_player.is_playing() or copter_anim_player.current_animation != &"stationnaire":
			copter_anim_player.play(&"stationnaire")
	elif anim_name == &"stationnaire" and copter_anim_player.has_animation(&"vol_stationnaire"):
		if not copter_anim_player.is_playing() or copter_anim_player.current_animation != &"vol_stationnaire":
			copter_anim_player.play(&"vol_stationnaire")

func _sync_from_controller() -> void:
	var controller = get_node_or_null("../VehicleChaseController")
	if controller == null:
		controller = get_node_or_null("../../VehicleChaseController")
	if controller:
		if "copter_offset_hit_roof" in controller:
			offset_relatif_hit_roof = controller.copter_offset_hit_roof
		if "copter_position_x_adjustment" in controller:
			position_x_adjustment = controller.copter_position_x_adjustment
		if "copter_position_y_adjustment" in controller:
			position_y_adjustment = controller.copter_position_y_adjustment
		if "copter_attack_damage" in controller:
			attack_damage = controller.copter_attack_damage
		if "copter_attack_interval" in controller:
			attack_interval = controller.copter_attack_interval
		if "copter_hover_speed" in controller:
			hover_speed = controller.copter_hover_speed
		if "copter_recoil_distance_px" in controller:
			recoil_distance_px = controller.copter_recoil_distance_px
		if "copter_recoil_duration_sec" in controller:
			recoil_duration_sec = controller.copter_recoil_duration_sec
		if "copter_esquive_distance_px" in controller:
			esquive_distance_px = controller.copter_esquive_distance_px
		if "copter_esquive_duration_sec" in controller:
			esquive_duration = controller.copter_esquive_duration_sec
			_esquive_duration = controller.copter_esquive_duration_sec
		if "copter_esquive_pause_sec" in controller:
			esquive_pause_sec = controller.copter_esquive_pause_sec
		if "copter_entree_duree_secondes" in controller:
			entry_duration = controller.copter_entree_duree_secondes
			_entry_duration = controller.copter_entree_duree_secondes
		if "copter_entree_easing" in controller:
			var easing_enum = controller.copter_entree_easing
			_entry_easing = _get_easing_string_from_enum(easing_enum)
			entry_easing = _entry_easing
		if "copter_invincible" in controller:
			invincible = controller.copter_invincible

func _get_target_position() -> Vector2:
	var player_van = get_tree().get_first_node_in_group("player_vehicle")
	if player_van and is_instance_valid(player_van):
		var roof_pos = player_van.get_hit_roof_rest_position() if player_van.has_method("get_hit_roof_rest_position") else (player_van.get_hit_roof_global_position() if player_van.has_method("get_hit_roof_global_position") else player_van.global_position)
		return roof_pos + offset_relatif_hit_roof + Vector2(position_x_adjustment, position_y_adjustment)
	
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera:
		var centre_cam = camera.get_screen_center_position()
		var viewport_size = _get_logical_viewport_size(camera)
		var tx = centre_cam.x - (viewport_size.x * 0.5) + (viewport_size.x * position_x_ratio) + position_x_adjustment
		var ty = centre_cam.y - (viewport_size.y * 0.5) + (viewport_size.y * position_y_ratio) + position_y_adjustment
		return Vector2(tx, ty)
	return global_position

func _physics_process(delta: float) -> void:
	if not est_actif() or est_elimine:
		return

	_sync_from_controller()
	anim_time += delta * hover_speed
	_update_debug_log()

	if _camera_positionning_enabled:
		var target_pos = _get_target_position()
		
		match current_state:
			CopterState.ENTREE:
				_entry_progress += delta / max(_entry_duration, 0.01)
				if _entry_progress >= 1.0:
					_entry_progress = 1.0
					current_state = CopterState.VOL_STATIONNAIRE
					attack_timer = 0.0
					print("[XCopter] Animation d'entrée terminée - passage à VOL_STATIONNAIRE")
					_play_anim(&"stationnaire")
				else:
					_play_anim(&"entree")

				var ease_value = _get_easing_value(clamp(_entry_progress, 0.0, 1.0), _entry_easing)
				var entry_offset_x = max(esquive_distance_px, 200.0)
				global_position.x = target_pos.x - (1.0 - ease_value) * entry_offset_x
				global_position.y = target_pos.y

			CopterState.VOL_STATIONNAIRE:
				global_position = target_pos
				_play_anim(&"stationnaire")
				_update_vol_stationnaire(delta)

			CopterState.ESQUIVE:
				_esquive_progress += delta / max(_esquive_duration, 0.01)
				var ease_val = _get_easing_value(clamp(_esquive_progress, 0.0, 1.0), "QUAD_OUT")
				var retrait_total = max(esquive_distance_px, 200.0)
				global_position.x = target_pos.x - ease_val * retrait_total
				global_position.y = target_pos.y
				if _esquive_progress >= 1.0:
					current_state = CopterState.PAUSE_HORS_ECRAN
					_esquive_pause_timer = 0.0
					print("[XCopter] Esquive complétée -> Pause hors écran (", esquive_pause_sec, "s)")

			CopterState.PAUSE_HORS_ECRAN:
				var retrait_total = max(esquive_distance_px, 200.0)
				global_position.x = target_pos.x - retrait_total
				global_position.y = target_pos.y
				_esquive_pause_timer += delta
				if _esquive_pause_timer >= esquive_pause_sec:
					_demarrer_nouvelle_entree()

			CopterState.RECOIL:
				_play_anim(&"recul")
				_update_recoil(delta)
	else:
		super._physics_process(delta)

	# ================================================================
	# Pilotage de SpriteCorps.position.x en code pur (indépendant de l'animation)
	# Seul le recul (impact) anime le sprite en local ; l'esquive déplace global_position
	# ================================================================
	if sprite_corps:
		var sx: float = 1.0
		match current_state:
			CopterState.RECOIL:
				var push_t = max(recoil_duration_sec * 0.2, 0.01)
				var ret_t = max(recoil_duration_sec * 0.8, 0.01)
				var rt = clamp(recoil_timer, 0.0, recoil_duration_sec)
				if rt < push_t:
					sx = lerp(1.0, 1.0 - recoil_distance_px, rt / push_t)
				else:
					sx = lerp(1.0 - recoil_distance_px, 1.0, (rt - push_t) / ret_t)
			_:
				sx = 1.0
		sprite_corps.position.x = sx

func _update_vol_stationnaire(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_interval:
		_tirer_sur_joueur()
		attack_timer = 0.0

func _update_recoil(delta: float) -> void:
	recoil_timer += delta
	if recoil_timer >= recoil_duration_sec:
		recoil_timer = 0.0
		current_state = CopterState.VOL_STATIONNAIRE
		print("[XCopter] Retour au vol stationnaire après RECOIL")

func enable_camera_positionning(x_ratio: float, x_adjustment: float, y_ratio: float, y_adjustment: float, entry: bool = true, duration: float = 1.5, easing: String = "SINE_OUT") -> void:
	position_x_ratio = x_ratio
	position_x_adjustment = x_adjustment
	position_y_ratio = y_ratio
	position_y_adjustment = y_adjustment
	_entry_duration = duration
	_entry_easing = easing
	_camera_positionning_enabled = true
	
	print("[XCopter] enable_camera_positionning appelé - x_ratio: ", x_ratio, " x_adj: ", x_adjustment, " y_ratio: ", y_ratio, " y_adj: ", y_adjustment)
	
	if entry:
		current_state = CopterState.ENTREE
		_entry_progress = 0.0
		var target_pos = _get_target_position()
		var entry_offset_x = max(esquive_distance_px, 200.0)
		_entry_start_pos = Vector2(target_pos.x - entry_offset_x, target_pos.y)
		global_position = _entry_start_pos
		print("[XCopter] Position départ hors écran: ", global_position)
		_play_anim(&"entree")
		print("[XCopter] Mode caméra-relatif activé avec animation d'entrée")
	else:
		current_state = CopterState.VOL_STATIONNAIRE
		_play_anim(&"stationnaire")
		print("[XCopter] Mode caméra-relatif activé sans animation d'entrée")

func disable_camera_positionning() -> void:
	_camera_positionning_enabled = false
	current_state = CopterState.VOL_STATIONNAIRE
	print("[XCopter] Mode caméra-relatif désactivé")

func _get_easing_value(progress: float, easing: String) -> float:
	match easing:
		"LINEAR":
			return progress
		"SINE_IN":
			return 1.0 - cos(progress * PI * 0.5)
		"SINE_OUT":
			return sin(progress * PI * 0.5)
		"SINE_IN_OUT":
			return (1.0 - cos(progress * PI)) * 0.5
		"QUAD_IN":
			return progress * progress
		"QUAD_OUT":
			return 1.0 - (1.0 - progress) * (1.0 - progress)
		"QUAD_IN_OUT":
			if progress < 0.5:
				return 2.0 * progress * progress
			else:
				return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
		"CUBIC_IN":
			return progress * progress * progress
		"CUBIC_OUT":
			return 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
		"CUBIC_IN_OUT":
			if progress < 0.5:
				return 4.0 * progress * progress * progress
			else:
				return 1.0 - 4.0 * (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
		_:
			return progress

func _get_easing_string_from_enum(easing_enum: int) -> String:
	match easing_enum:
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

func hit(amount: int = 10) -> void:
	subir_degats(amount)

func hit_at_position(_hit_pos: Vector2, amount: int = 10) -> void:
	subir_degats(amount)

func subir_degats_partie(_partie: String, degats_subis: int = 1, _pos_impact: Vector2 = Vector2.INF, _est_missile: bool = false) -> void:
	subir_degats(degats_subis)

func subir_degats(amount: int = 10) -> void:
	if not est_actif() or est_elimine:
		return
	
	pv_actuels = max(0, pv_actuels - amount)
	print("[XCopter] Dégâts reçus: ", amount, " | PV: ", pv_actuels, "/", pv_max)
	
	if pv_actuels <= 0:
		subir_elimination()
		return
	
	# Si pas déjà en train d'esquiver, déclencher l'esquive
	if current_state != CopterState.ESQUIVE:
		_declencher_esquive()

func _declencher_esquive() -> void:
	current_state = CopterState.ESQUIVE
	_esquive_progress = 0.0
	_esquive_start_pos = global_position
	_play_anim(&"esquive")
	print("[XCopter] Esquive déclenchée - retrait vers la gauche (", esquive_distance_px, " px)")

func _on_animation_finished(_anim_name: StringName) -> void:
	# Machine d'état pilotée par les timers de _physics_process
	pass

func _demarrer_nouvelle_entree() -> void:
	current_state = CopterState.ENTREE
	_entry_progress = 0.0
	var target_pos = _get_target_position()
	var entry_offset_x = max(esquive_distance_px, 200.0)
	global_position.x = target_pos.x - entry_offset_x
	global_position.y = target_pos.y
	_play_anim(&"entree")
	print("[XCopter] Début ré-entrée depuis hors écran: ", global_position)

func subir_elimination() -> void:
	est_elimine = true
	exploded.emit()
	super.subir_elimination()

func respawn_copter() -> void:
	print("[XCopter] Respawn du copter")
	est_elimine = false
	pv_actuels = pv_max
	current_state = CopterState.ENTREE
	recoil_timer = 0.0
	
	if not est_actif():
		activer_acteur()
	
	_demarrer_nouvelle_entree()
	print("[XCopter] Copter respawn complété")

func _tirer_sur_joueur() -> void:
	var player_vehicle = get_tree().get_first_node_in_group("player_vehicle")
	if player_vehicle and is_instance_valid(player_vehicle):
		if player_vehicle.has_method("subir_degats"):
			player_vehicle.subir_degats(attack_damage)
		elif player_vehicle.has_method("take_damage"):
			player_vehicle.take_damage(attack_damage)
		print("[XCopter] Tir sur le van - dégâts: ", attack_damage)

# --- DEBUG HUD ---
func _initialiser_debug_hud() -> void:
	debug_hud = get_node_or_null("/root/Main/DebugHUD")

func _update_debug_log() -> void:
	if not debug_hud:
		_initialiser_debug_hud()
	if not debug_hud:
		return

	var state_text = "UNKNOWN"
	match current_state:
		CopterState.ENTREE: state_text = "ENTREE"
		CopterState.VOL_STATIONNAIRE: state_text = "STATIONNAIRE"
		CopterState.ESQUIVE: state_text = "ESQUIVE"
		CopterState.PAUSE_HORS_ECRAN: state_text = "PAUSE_HORS_ECRAN"
		CopterState.RECOIL: state_text = "RECOIL"

	var mode_text = "CAMERA-RELATIF" if _camera_positionning_enabled else "VEHICLEBASE"
	var entry_text = "ENTRÉE (%.0f%%)" % (_entry_progress * 100.0) if current_state == CopterState.ENTREE else ("ESQUIVE (%.0f%%)" % (_esquive_progress * 100.0) if current_state == CopterState.ESQUIVE else "POSITIONNÉ")
	var log_text = "Mode: %s\nÉtat: %s\nPhase: %s\nAnim: %.2f\nAttack: %.2f\nPos: (%.1f, %.1f)\nPV: %d/%d" % [mode_text, state_text, entry_text, anim_time, attack_timer, global_position.x, global_position.y, pv_actuels, pv_max]
	if debug_hud and debug_hud.has_method("set_copter_log"):
		debug_hud.set_copter_log(log_text)
