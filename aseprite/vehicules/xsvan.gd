class_name XSVanPlayerV2
extends VehicleActorBase

## XSVan Player Vehicle Controller pour Godot 4.7
## Dérive de VehicleActorBase pour le support complet d'ActorBase, StopMarkers et suivi caméra.

signal player_died()

@export_group("Positionnement Caméra-Relatif")
@export var position_x_ratio: float = 0.0
@export var position_x_adjustment: float = 0.0
@export var position_y_ratio: float = 0.0
@export var position_y_adjustment: float = 10.0

@export_group("Animation d'Entrée")
@export var enable_entry_animation: bool = true
@export var entry_duration: float = 2.0
@export var entry_easing: String = "SINE_OUT"

@export_group("Réactions au Jug")
@export var jug_reaction_enabled: bool = true
@export var recoil_recovery_speed: float = 120.0
@export var recoil_push_px: float = 60.0          ## Distance de projection du van lors de l'impact (pixels)
@export var recoil_push_sec: float = 0.2          ## Temps de poussée vers l'avant (secondes)
@export var recoil_hold_sec: float = 0.8          ## Temps de maintien sous l'impact (secondes)
@export var recoil_return_sec: float = 0.6        ## Temps de retour à la position normale (secondes)

var current_van_state: VanState = VanState.STATIONNAIRE
var _camera_positionning_enabled: bool = false
var _entry_animation: bool = false
var _entry_progress: float = 0.0
var _entry_duration: float = 2.0
var _entry_easing: String = "SINE_OUT"

enum VanState { STATIONNAIRE, ENTREE, RECOIL }

var body_damage_step: int = 0 ## 0 = Intact body, 1 = dm0, 2 = dm1
var anim_time_ms: float = 0.0
var van_impact_push: float = 0.0

var light_left_broken: bool = false
var light_right_broken: bool = false

## Pilotage code-pur du recul X (comme XJug, évite la mutation de ressource Android)
var _recoil_timer: float = 0.0


@onready var body_node: Node2D = get_node_or_null("BodyNode") as Node2D
@onready var body_damageable: AnimatedSprite2D = get_node_or_null("BodyNode/DomageablePart") as AnimatedSprite2D
@onready var body_sprite: Sprite2D = get_node_or_null("BodyNode/Body") as Sprite2D
@onready var lights_node: Node2D = get_node_or_null("BodyNode/Lights") as Node2D

@onready var debug_marker: ColorRect = null
@onready var van_anim_player: AnimationPlayer = get_node_or_null("VanAnimationPlayer") as AnimationPlayer

# --- DEBUG HUD ---
var debug_hud: CanvasLayer = null
var _entry_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	suivre_camera_automatiquement = false
	super._ready()
	add_to_group("player_vehicle")
	_update_visuals()
	_create_debug_marker()
	
	if van_anim_player:
		if not van_anim_player.animation_finished.is_connected(_on_animation_finished):
			van_anim_player.animation_finished.connect(_on_animation_finished)
	
	_initialiser_debug_hud()

func _get_logical_viewport_size(camera: Camera2D) -> Vector2:
	if camera and "largeur_lucarne" in camera and "hauteur_lucarne" in camera:
		return Vector2(float(camera.largeur_lucarne), float(camera.hauteur_lucarne))
	return Vector2(288.0, 176.0)

func _play_anim(anim_name: StringName) -> void:
	if not van_anim_player:
		return
	if van_anim_player.has_animation(anim_name):
		if not van_anim_player.is_playing() or van_anim_player.current_animation != anim_name:
			van_anim_player.play(anim_name)

func get_hit_roof_global_position() -> Vector2:
	var marker = get_node_or_null("BodyNode/HitRoof") as Node2D
	if marker:
		return marker.global_position
	return global_position + Vector2(6.5, 25.0)

func get_hit_roof_rest_position() -> Vector2:
	var marker = get_node_or_null("BodyNode/HitRoof") as Node2D
	if marker:
		if body_node:
			return marker.global_position - Vector2(body_node.position.x, 0.0)
		return marker.global_position
	return global_position + Vector2(6.5, 25.0)

func get_hit_rear_global_position() -> Vector2:
	var marker = get_node_or_null("BodyNode/HitRear") as Node2D
	if marker:
		return marker.global_position
	return global_position + Vector2(5.3, 73.4)

func get_hit_rear_rest_position() -> Vector2:
	var marker = get_node_or_null("BodyNode/HitRear") as Node2D
	if marker:
		if body_node:
			return marker.global_position - Vector2(body_node.position.x, 0.0)
		return marker.global_position
	return global_position + Vector2(5.3, 73.4)

func _sync_from_controller() -> void:
	var controller = get_node_or_null("../VehicleChaseController")
	if controller == null:
		controller = get_node_or_null("../../VehicleChaseController")
	if controller:
		if "van_position_x_ratio" in controller:
			position_x_ratio = controller.van_position_x_ratio
		if "van_position_x_adjustment" in controller:
			position_x_adjustment = controller.van_position_x_adjustment
		if "van_position_y_ratio" in controller:
			position_y_ratio = controller.van_position_y_ratio
		if "van_position_y_adjustment" in controller:
			position_y_adjustment = controller.van_position_y_adjustment
		if "van_recoil_push_px" in controller:
			recoil_push_px = controller.van_recoil_push_px
		if "van_recoil_push_sec" in controller:
			recoil_push_sec = controller.van_recoil_push_sec
		if "van_recoil_hold_sec" in controller:
			recoil_hold_sec = controller.van_recoil_hold_sec
		if "van_recoil_return_sec" in controller:
			recoil_return_sec = controller.van_recoil_return_sec
		if "van_invincible" in controller:
			invincible = controller.van_invincible
		if "van_entree_easing" in controller:
			var easing_enum = controller.van_entree_easing
			_entry_easing = _get_easing_string_from_enum(easing_enum)

func _physics_process(delta: float) -> void:
	if not est_actif():
		return

	_sync_from_controller()

	# Gérer les animations selon l'état du van
	match current_van_state:
		VanState.STATIONNAIRE:
			_play_anim(&"stationnaire")
		VanState.ENTREE:
			_play_anim(&"entree")
		VanState.RECOIL:
			_play_anim(&"recul")

	_update_debug_log()

	# ================================================================
	# Pilotage de BodyNode.position.x en code pur (indépendant de l'animation)
	# 3 phases précises :
	# 1. Poussée (0.0 -> recoil_push_sec) : Projection vers l'avant (0 -> recoil_push_px)
	# 2. Maintien (recoil_push_sec -> recoil_push_sec + recoil_hold_sec) : Pression du bélier (recoil_push_px)
	# 3. Retour (jusqu'à total_recoil) : Retour fluide à 0 (recoil_push_px -> 0.0)
	# ================================================================
	if body_node:
		if current_van_state == VanState.RECOIL:
			var total_recoil = max(recoil_push_sec + recoil_hold_sec + recoil_return_sec, 0.01)
			_recoil_timer += delta
			var bx: float
			if _recoil_timer < recoil_push_sec:
				var p_push = clamp(_recoil_timer / max(recoil_push_sec, 0.001), 0.0, 1.0)
				bx = lerp(0.0, recoil_push_px, sin(p_push * PI * 0.5))
			elif _recoil_timer < (recoil_push_sec + recoil_hold_sec):
				bx = recoil_push_px
			elif _recoil_timer < total_recoil:
				var p_ret = clamp((_recoil_timer - (recoil_push_sec + recoil_hold_sec)) / max(recoil_return_sec, 0.001), 0.0, 1.0)
				bx = lerp(recoil_push_px, 0.0, p_ret)
			else:
				bx = 0.0
				current_van_state = VanState.STATIONNAIRE
				_recoil_timer = 0.0
				_play_anim(&"stationnaire")
				print("[XSVan] Fin du recul (temps de retour terminé) - retour à STATIONNAIRE")
			body_node.position.x = bx
		else:
			# Si hors recul, s'assurer que le body_node est calé à 0
			body_node.position.x = move_toward(body_node.position.x, 0.0, 200.0 * delta)

	# Système de positionnement caméra-relatif
	if _camera_positionning_enabled:
		var camera = get_viewport().get_camera_2d() if get_viewport() else null
		if camera:
			var centre_cam = camera.get_screen_center_position()
			var viewport_size = _get_logical_viewport_size(camera)
			
			var target_x = centre_cam.x - (viewport_size.x * 0.5) + (viewport_size.x * position_x_ratio) + position_x_adjustment
			var target_y = centre_cam.y - (viewport_size.y * position_y_ratio) + position_y_adjustment
			
			# Animation d'entrée intégrée (relative à la caméra en mouvement)
			if _entry_animation:
				_entry_progress += delta / max(_entry_duration, 0.01)
				if _entry_progress >= 1.0:
					_entry_progress = 1.0
					_entry_animation = false
					current_van_state = VanState.STATIONNAIRE
					print("[XSVan] Animation d'entrée terminée - passage à STATIONNAIRE")
					_play_anim(&"stationnaire")
				else:
					_play_anim(&"entree")
				
				var ease_value = _get_easing_value(clamp(_entry_progress, 0.0, 1.0), _entry_easing)
				if _entry_from_right:
					var entry_offset_x = (viewport_size.x * (1.0 - position_x_ratio)) + 140.0
					global_position.x = target_x + (1.0 - ease_value) * entry_offset_x
				else:
					var entry_offset_x = (viewport_size.x * position_x_ratio) + position_x_adjustment + 120.0
					global_position.x = target_x - (1.0 - ease_value) * entry_offset_x
				global_position.y = target_y
			else:
				# Positionnement normal
				global_position.x = target_x
				global_position.y = target_y
			
			# Debug marker pour visualiser la position cible
			if debug_marker:
				debug_marker.global_position = Vector2(target_x, target_y)
			
			if Engine.get_physics_frames() % 60 == 0:
				print("[XSVan DEBUG] Position: ", global_position.x, " | Target: ", target_x, " | State: ", current_van_state, " | RecoilTimer: ", _recoil_timer)
	else:
		# Si le positionnement caméra n'est pas activé, utiliser VehicleActorBase
		super._physics_process(delta)
		
		# Système de recul legacy compatible
		if van_impact_push > 0.0:
			van_impact_push = max(0.0, van_impact_push - 180.0 * delta)
			global_position.x -= van_impact_push

var _entry_from_right: bool = false

func enable_camera_positionning(x_ratio: float, x_adjustment: float, y_ratio: float, y_adjustment: float, entry: bool = true, duration: float = 2.0, easing: String = "SINE_OUT", from_right: bool = false) -> void:
	position_x_ratio = x_ratio
	position_x_adjustment = x_adjustment
	position_y_ratio = y_ratio
	position_y_adjustment = y_adjustment
	_entry_duration = duration
	_entry_easing = easing
	_entry_from_right = from_right
	_camera_positionning_enabled = true
	
	if entry:
		_entry_animation = true
		_entry_progress = 0.0
		var camera = get_viewport().get_camera_2d() if get_viewport() else null
		var viewport_size = _get_logical_viewport_size(camera)
		var centre_cam = camera.get_screen_center_position() if camera else Vector2.ZERO
		var start_x = centre_cam.x + (viewport_size.x * 0.5) + 120.0 if from_right else centre_cam.x - (viewport_size.x * 0.5) - 100.0
		_entry_start_pos = Vector2(start_x, centre_cam.y - (viewport_size.y * position_y_ratio) + position_y_adjustment)
		global_position = _entry_start_pos
		current_van_state = VanState.ENTREE
		print("[XSVan] Mode caméra-relatif activé avec animation d'entrée (depuis la %s)" % ("droite" if from_right else "gauche"))
	else:
		current_van_state = VanState.STATIONNAIRE
		print("[XSVan] Mode caméra-relatif activé sans animation d'entrée")

func disable_camera_positionning() -> void:
	_camera_positionning_enabled = false
	current_van_state = VanState.STATIONNAIRE
	print("[XSVan] Mode caméra-relatif désactivé")

func take_jug_attack() -> void:
	if jug_reaction_enabled:
		print("[XSVan] Jug attack / ram reçu - application des dégâts et déclenchement du recul")
		subir_degats(5)
		_declencher_recul()

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

func _update_visuals() -> void:
	if body_damageable:
		var frames = body_damageable.sprite_frames
		if frames:
			if body_damage_step == 0:
				body_damageable.animation = "defaullt"
			elif body_damage_step == 1:
				body_damageable.animation = "damaged"
			elif body_damage_step >= 2:
				body_damageable.animation = "destroyed"

func subir_elimination() -> void:
	player_died.emit()
	super.subir_elimination()

func subir_degats(amount: int = 10) -> void:
	if invincible or est_elimine:
		return
	super.subir_degats(amount)
	
	# Mettre à jour le niveau de dégâts du corps
	if pv_actuels <= pv_max * 0.3:
		body_damage_step = 2
	elif pv_actuels <= pv_max * 0.6:
		body_damage_step = 1
	else:
		body_damage_step = 0
	
	_update_visuals()

func _declencher_recul() -> void:
	current_van_state = VanState.RECOIL
	_recoil_timer = 0.0
	if body_node:
		body_node.position.x = 0.0
	_play_anim(&"recul")
	print("[XSVan] Recoil / dégâts reçus - animation recul déclenchée")

func _on_animation_finished(anim_name: StringName) -> void:
	pass

func _create_debug_marker() -> void:
	if debug_marker == null:
		debug_marker = ColorRect.new()
		debug_marker.size = Vector2(4, 4)
		debug_marker.color = Color.RED
		debug_marker.z_index = 1000
		add_child(debug_marker)

# Méthodes de réaction aux signaux du Jug
func on_jug_state_changed(new_state: int) -> void:
	if not jug_reaction_enabled:
		return
	
	print("[XSVan] Jug state changed to: ", new_state)
	if current_van_state == VanState.RECOIL:
		return
	
	match new_state:
		0: # CHASE
			_play_anim(&"stationnaire")
		1: # ANTICIPATION
			_play_anim(&"stationnaire")
		2: # LUNGE
			_play_anim(&"stationnaire")
		3: # RETREAT
			_play_anim(&"stationnaire")

func on_jug_attack_started() -> void:
	if not jug_reaction_enabled:
		return
	print("[XSVan] Jug attack started")
	if current_van_state != VanState.RECOIL:
		_play_anim(&"stationnaire")

func on_jug_impact_occurred() -> void:
	if not jug_reaction_enabled:
		return
	if current_van_state != VanState.RECOIL:
		print("[XSVan] Jug impact occurred - déclenchement du recul")
		_declencher_recul()

# --- DEBUG HUD ---
func _initialiser_debug_hud() -> void:
	debug_hud = get_node_or_null("/root/Main/DebugHUD")

func _update_debug_log() -> void:
	if not debug_hud:
		_initialiser_debug_hud()
	if not debug_hud:
		return

	var state_text = "UNKNOWN"
	match current_van_state:
		VanState.STATIONNAIRE: state_text = "STATIONNAIRE"
		VanState.ENTREE: state_text = "ENTREE"
		VanState.RECOIL: state_text = "RECOIL"

	var mode_text = "CAMERA-RELATIF" if _camera_positionning_enabled else "VEHICLEBASE"
	var log_text = "Mode: %s\nÉtat: %s\nPos: (%.1f, %.1f)\nPV: %d/%d\nDamage: %d" % [mode_text, state_text, global_position.x, global_position.y, pv_actuels, pv_max, body_damage_step]
	if debug_hud and debug_hud.has_method("set_van_log"):
		debug_hud.set_van_log(log_text)

func replay_entry_animation() -> void:
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	var viewport_size = _get_logical_viewport_size(camera)
	var centre_cam = camera.get_screen_center_position() if camera else Vector2.ZERO
	_entry_start_pos = Vector2(centre_cam.x - (viewport_size.x * 0.5) - 100.0, centre_cam.y - (viewport_size.y * position_y_ratio) + position_y_adjustment)
	global_position = _entry_start_pos
	_entry_animation = true
	_entry_progress = 0.0
	current_van_state = VanState.ENTREE
	_play_anim(&"entree")
