class_name XJugBossV2
extends VehicleActorBase

## XJug Juggernaut Boss Vehicle Controller pour Godot 4.7
## Dérive de VehicleActorBase pour le support complet d'ActorBase, StopMarkers et suivi caméra.

signal boss_defeated()
signal jug_state_changed(new_state: State) ## Signal pour les changements d'état du Jug
signal jug_attack_started() ## Signal quand le Jug commence une attaque
signal jug_impact_occurred() ## Signal quand le Jug impacte le van

enum State { CHASE, ANTICIPATION, LUNGE, HOLD, RETREAT }

@export var enable_suspension_bounce: bool = true

@export_group("Positionnement Relatif au Van (HitRear)")
@export var position_x_adjustment: float = 0.0 ## Ajustement fin X en pixels par rapport à HitRear
@export var position_y_adjustment: float = 10.0 ## Ajustement fin Y en pixels par rapport à HitRear
@export var front_bumper_offset_px: float = 586.0 ## Distance X entre la racine XJug et le pare-choc avant
@export var position_x_ratio: float = 0.35 ## Fallback caméra si pas de van
@export var position_y_ratio: float = 0.32 ## Fallback caméra si pas de van

@export_group("Vitesses & Distances Paramétrables")
@export var distance_chase_px: float = 40.0 ## Point d'origine / distance de garde derrière le van en phase CHASE (pixels)
@export var ram_push_px: float = 80.0 ## Distance de course du bélier vers l'avant lors du RAM (pixels)
@export var temps_chase_sec: float = 3.5 ## Durée de l'état CHASE entre les attaques (secondes)
@export var temps_anticipation_sec: float = 1.0 ## Durée d'avertissement / anticipation avant la charge (secondes)
@export var ram_push_sec: float = 0.6 ## Durée de la charge vers l'avant jusqu'au contact (secondes)
@export var ram_hold_sec: float = 0.8 ## Durée de maintien sous l'impact collé au van (secondes)
@export var ram_return_sec: float = 1.5 ## Durée du retrait vers la position stationnaire de garde (secondes)

var current_state: State = State.CHASE
var state_timer: float = 0.0
var _camera_positionning_enabled: bool = false
var _entry_animation: bool = false
var _entry_progress: float = 0.0
var _entry_duration: float = 2.0
var _entry_easing: String = "SINE_OUT"
var _entry_start_pos: Vector2 = Vector2.ZERO

## Déplacement X local du BodyNode piloté par code (ANTICIPATION / LUNGE / RETREAT)
## Remplace les pistes BodyNode:position:x des animations (évite la mutation de ressource partagée sur Android)
var _body_x_offset: float = 0.0

@export_group("Santé des Morceaux (25 PV chacun)")
@export var door_pv_max: int = 25 ## PV Max de la porte (DoorDmg)
@export var engine_pv_max: int = 25 ## PV Max du moteur (EngineDmg)

@export_group("Effets Visuels d'Impact")
@export var enable_hit_flash: bool = true
@export var flash_intensity: float = 3.5
@export var flash_duration_sec: float = 0.08

var door_pv: int = 25
var engine_pv: int = 25

var door_damage_level: int = 0
var engine_damage_level: int = 0

# --- DEBUG HUD ---
var debug_hud: CanvasLayer = null

var anim_time_ms: float = 0.0
var body_bounce_y: float = 0.0

@onready var body_node: Node2D = get_node_or_null("BodyNode") as Node2D
@onready var door_dmg_sprite: AnimatedSprite2D = get_node_or_null("BodyNode/Cabine/DoorDmg") as AnimatedSprite2D
@onready var engine_dmg_sprite: AnimatedSprite2D = get_node_or_null("BodyNode/Cabine/EngineDmg") as AnimatedSprite2D
@onready var jug_anim_player: AnimationPlayer = get_node_or_null("JugAnimationPlayer") as AnimationPlayer

func _ready() -> void:
	door_pv = door_pv_max
	engine_pv = engine_pv_max
	pv_max = door_pv_max + engine_pv_max
	pv_actuels = pv_max
	offset_lucarne_ratio_x = 0.85
	super._ready()
	current_state = State.CHASE
	state_timer = 0.0
	_update_damage_visuals()
	
	if jug_anim_player:
		if not jug_anim_player.animation_finished.is_connected(_on_animation_finished):
			jug_anim_player.animation_finished.connect(_on_animation_finished)
	
	_initialiser_debug_hud()

func _get_logical_viewport_size(camera: Camera2D) -> Vector2:
	if camera and "largeur_lucarne" in camera and "hauteur_lucarne" in camera:
		return Vector2(float(camera.largeur_lucarne), float(camera.hauteur_lucarne))
	return Vector2(288.0, 176.0)

func _get_target_position() -> Vector2:
	var player_van = get_tree().get_first_node_in_group("player_vehicle")
	if player_van and is_instance_valid(player_van):
		var rear_pos = player_van.get_hit_rear_rest_position() if player_van.has_method("get_hit_rear_rest_position") else (player_van.get_hit_rear_global_position() if player_van.has_method("get_hit_rear_global_position") else player_van.global_position)
		var base_y = rear_pos.y - 73.4 + position_y_adjustment
		var bumper_base_x = rear_pos.x - distance_chase_px + position_x_adjustment
		var chase_x = bumper_base_x - front_bumper_offset_px
		return Vector2(chase_x, base_y)
	
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera:
		var centre_cam = camera.get_screen_center_position()
		var viewport_size = _get_logical_viewport_size(camera)
		var target_bumper_x = centre_cam.x - (viewport_size.x * 0.5) + (viewport_size.x * position_x_ratio) + position_x_adjustment
		var chase_target_x = target_bumper_x - front_bumper_offset_px
		var target_y = centre_cam.y - (viewport_size.y * position_y_ratio) + position_y_adjustment
		return Vector2(chase_target_x, target_y)
	return global_position

func enable_camera_positionning(x_ratio: float, x_adjustment: float, y_ratio: float, y_adjustment: float, entry: bool = true, duration: float = 2.0, easing: String = "SINE_OUT") -> void:
	position_x_ratio = x_ratio
	position_x_adjustment = x_adjustment
	position_y_ratio = y_ratio
	position_y_adjustment = y_adjustment
	_entry_duration = duration
	_entry_easing = easing
	_camera_positionning_enabled = true
	
	if entry:
		_entry_animation = true
		_entry_progress = 0.0
		var camera = get_viewport().get_camera_2d() if get_viewport() else null
		var viewport_size = _get_logical_viewport_size(camera)
		var centre_cam = camera.get_screen_center_position() if camera else Vector2.ZERO
		var target_pos = _get_target_position()
		_entry_start_pos = Vector2(centre_cam.x - (viewport_size.x * 0.5) - front_bumper_offset_px - 50.0, target_pos.y)
		global_position = _entry_start_pos
		current_state = State.CHASE
		print("[XJug] Mode caméra-relatif activé avec animation d'entrée")
	else:
		current_state = State.CHASE
		print("[XJug] Mode caméra-relatif activé sans animation d'entrée")

func disable_camera_positionning() -> void:
	_camera_positionning_enabled = false
	print("[XJug] Mode caméra-relatif désactivé")

func battre_en_retraite_temporaire() -> void:
	current_state = State.CHASE
	state_timer = 0.0
	_play_anim(&"chase")
	if body_node:
		body_node.position.x = 0.0
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	var viewport_size = _get_logical_viewport_size(camera)
	var centre_cam = camera.get_screen_center_position() if camera else Vector2.ZERO
	var retrait_x = centre_cam.x - (viewport_size.x * 0.5) - front_bumper_offset_px - 80.0
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "global_position:x", retrait_x, 1.2)
	print("[XJug] Retraite temporaire hors écran à gauche à l'état CHASE")

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
		_:
			return progress

func _play_anim(anim_name: StringName, custom_speed: float = 1.0) -> void:
	if not jug_anim_player:
		return
	if jug_anim_player.has_animation(anim_name):
		if not jug_anim_player.is_playing() or jug_anim_player.current_animation != anim_name:
			jug_anim_player.play(anim_name, -1, custom_speed)
	elif anim_name == &"stationnaire" and jug_anim_player.has_animation(&"chase"):
		if not jug_anim_player.is_playing() or jug_anim_player.current_animation != &"chase":
			jug_anim_player.play(&"chase", -1, custom_speed)

func _sync_from_controller() -> void:
	var controller = get_node_or_null("../VehicleChaseController")
	if controller == null:
		controller = get_node_or_null("../../VehicleChaseController")
	if controller:
		if "jug_position_x_adjustment" in controller:
			position_x_adjustment = controller.jug_position_x_adjustment
		if "jug_position_y_adjustment" in controller:
			position_y_adjustment = controller.jug_position_y_adjustment
		if "jug_distance_chase_px" in controller:
			distance_chase_px = controller.jug_distance_chase_px
		if "jug_ram_push_px" in controller:
			ram_push_px = controller.jug_ram_push_px
		if "jug_temps_chase_sec" in controller:
			temps_chase_sec = controller.jug_temps_chase_sec
		if "jug_temps_anticipation_sec" in controller:
			temps_anticipation_sec = controller.jug_temps_anticipation_sec
		if "jug_ram_push_sec" in controller:
			ram_push_sec = controller.jug_ram_push_sec
		if "jug_ram_hold_sec" in controller:
			ram_hold_sec = controller.jug_ram_hold_sec
		if "jug_ram_return_sec" in controller:
			ram_return_sec = controller.jug_ram_return_sec
		if "jug_invincible" in controller:
			invincible = controller.jug_invincible
		if "enable_hit_flash" in controller:
			enable_hit_flash = controller.enable_hit_flash
		if "hit_flash_intensity" in controller:
			flash_intensity = controller.hit_flash_intensity
		if "hit_flash_duration_sec" in controller:
			flash_duration_sec = controller.hit_flash_duration_sec

func _physics_process(delta: float) -> void:
	if not est_actif() or est_elimine:
		return

	_sync_from_controller()

	if _camera_positionning_enabled:
		var target_pos = _get_target_position()
		
		if _entry_animation:
			_entry_progress += delta / max(_entry_duration, 0.01)
			if _entry_progress >= 1.0:
				_entry_progress = 1.0
				_entry_animation = false
				current_state = State.CHASE
				state_timer = 0.0
				print("[XJug] Animation d'entrée terminée - passage à CHASE")
			
			var ease_val = _get_easing_value(clamp(_entry_progress, 0.0, 1.0), _entry_easing)
			var entry_offset_x = 250.0
			global_position.x = target_pos.x - (1.0 - ease_val) * entry_offset_x
			global_position.y = target_pos.y
		else:
			global_position.x = target_pos.x
			global_position.y = target_pos.y

		if Engine.get_physics_frames() % 60 == 0:
			print("[XJug DEBUG] Pos: %.1f | Target: %.1f | State: %s | PV: %d/%d (Porte: %d/%d, Moteur: %d/%d)" % [
				global_position.x, target_pos.x, State.keys()[current_state], pv_actuels, pv_max, door_pv, door_pv_max, engine_pv, engine_pv_max
			])
	else:
		super._physics_process(delta)

	state_timer += delta
	_update_debug_log()

	# ================================================================
	# Pilotage de BodyNode.position.x — 3 phases simples (comme le Van)
	# LUNGE  : 0 → ram_push_px  (SINE_OUT)  en ram_push_sec
	# HOLD   : maintien à ram_push_px
	# RETREAT: ram_push_px → 0  (SINE_IN)   en ram_return_sec
	# ================================================================
	if body_node:
		var target_body_x: float = 0.0
		match current_state:
			State.CHASE, State.ANTICIPATION:
				target_body_x = 0.0
			State.LUNGE:
				var p = clamp(state_timer / max(ram_push_sec, 0.001), 0.0, 1.0)
				target_body_x = lerp(0.0, ram_push_px, sin(p * PI * 0.5))
			State.HOLD:
				target_body_x = ram_push_px
			State.RETREAT:
				var p_ret = clamp(state_timer / max(ram_return_sec, 0.001), 0.0, 1.0)
				target_body_x = lerp(ram_push_px, 0.0, (1.0 - cos(p_ret * PI)) * 0.5)
			_:
				target_body_x = 0.0
		body_node.position.x = target_body_x

	match current_state:
		State.CHASE:
			_play_anim(&"chase")
			if state_timer >= temps_chase_sec:
				_passer_a_l_etat(State.ANTICIPATION)

		State.ANTICIPATION:
			_play_anim(&"anticipation")
			if state_timer >= temps_anticipation_sec:
				_passer_a_l_etat(State.LUNGE)

		State.LUNGE:
			var scale_lunge = 0.6 / max(ram_push_sec, 0.1)
			_play_anim(&"lunge", scale_lunge)
			
			if state_timer >= ram_push_sec:
				# Impact exact au bout de ram_push_sec
				var player_van = get_tree().get_first_node_in_group("player_vehicle")
				if player_van and is_instance_valid(player_van):
					if player_van.has_method("take_jug_attack"):
						player_van.take_jug_attack()
					else:
						jug_impact_occurred.emit()
				else:
					jug_impact_occurred.emit()
				_passer_a_l_etat(State.HOLD)

		State.HOLD:
			_play_anim(&"lunge", 0.1)
			if state_timer >= ram_hold_sec:
				_passer_a_l_etat(State.RETREAT)

		State.RETREAT:
			var scale_retreat = 1.2 / max(ram_return_sec, 0.1)
			_play_anim(&"retreat", scale_retreat)
			if state_timer >= ram_return_sec:
				_passer_a_l_etat(State.CHASE)

func _passer_a_l_etat(nouvel_etat: State) -> void:
	current_state = nouvel_etat
	state_timer = 0.0
	jug_state_changed.emit(nouvel_etat)
	
	if nouvel_etat == State.CHASE and body_node:
		body_node.position.x = 0.0
	
	match nouvel_etat:
		State.CHASE:
			_play_anim(&"chase")
		State.ANTICIPATION:
			_play_anim(&"anticipation")
		State.LUNGE:
			var scale_lunge = 0.6 / max(ram_push_sec, 0.1)
			_play_anim(&"lunge", scale_lunge)
			jug_attack_started.emit()
		State.HOLD:
			pass
		State.RETREAT:
			var scale_retreat = 1.2 / max(ram_return_sec, 0.1)
			_play_anim(&"retreat", scale_retreat)

func _on_animation_finished(anim_name: StringName) -> void:
	# La machine d'état principale est désormais pilotée avec précision par les timers d'interpolation (_physics_process)
	pass

var _en_sequence_defaite: bool = false

func subir_elimination() -> void:
	if _en_sequence_defaite:
		return
	_en_sequence_defaite = true
	invincible = true  # Plus de dégâts pendant la retraite
	effet_mort = MortEffet.OFF  # Aucune explosion lors de la défaite
	print("[XJug] VAINCUS → Séquence de défaite : RETREAT puis CHASE puis Phase 4")
	
	# S'assurer qu'on part bien d'une position valide (forcer RETREAT si besoin)
	if current_state != State.RETREAT:
		_passer_a_l_etat(State.RETREAT)
	
	# Attendre la fin du retrait (ram_return_sec)
	await get_tree().create_timer(ram_return_sec, false).timeout
	
	# Bref CHASE de sortie (1 seconde) pour que le Juggernaut reprenne sa position normale
	_passer_a_l_etat(State.CHASE)
	await get_tree().create_timer(1.0, false).timeout
	
	# Marquer éliminé et signaler la victoire au contrôleur
	est_elimine = true
	boss_defeated.emit()
	print("[XJug] Séquence de défaite terminée → boss_defeated émis")
	super.subir_elimination()

func is_door_disabled() -> bool:
	return door_pv <= 0

func is_engine_disabled() -> bool:
	return engine_pv <= 0

func subir_degats_partie(partie: String, amount: int = 1, pos_impact: Vector2 = Vector2.INF, _est_missile: bool = false) -> void:
	if est_elimine or invincible or _en_sequence_defaite:
		return

	var p = partie.to_lower()
	var is_door = ("door" in p or "porte" in p)
	var is_engine = ("engine" in p or "moteur" in p or "hood" in p)

	if is_door:
		if door_pv > 0:
			var prev_pv = door_pv
			door_pv = max(0, door_pv - amount)
			_update_damage_visuals()
			_flash_blanc(door_dmg_sprite)
			if door_pv == 0 and prev_pv > 0:
				_spawn_part_explosion(door_dmg_sprite)
				print("[XJug] Porte DÉTRUITE (disabled) ! PV: 0/", door_pv_max)
			else:
				print("[XJug] Dégâts Porte : ", door_pv, "/", door_pv_max)
		else:
			print("[XJug] Porte déjà détruite (disabled) - aucun dégât supplémentaire")
			return
	elif is_engine:
		if engine_pv > 0:
			var prev_pv = engine_pv
			engine_pv = max(0, engine_pv - amount)
			_update_damage_visuals()
			_flash_blanc(engine_dmg_sprite)
			if engine_pv == 0 and prev_pv > 0:
				_spawn_part_explosion(engine_dmg_sprite)
				print("[XJug] Moteur DÉTRUIT (disabled) ! PV: 0/", engine_pv_max)
			else:
				print("[XJug] Dégâts Moteur : ", engine_pv, "/", engine_pv_max)
		else:
			print("[XJug] Moteur déjà détruit (disabled) - aucun dégât supplémentaire")
			return
	else:
		print("[XJug] Tir sur zone blindée/non-vulnérable ignoré : ", partie)
		return

	# Mise à jour des PV globaux pour HUD et ActorBase
	pv_actuels = door_pv + engine_pv

	# Condition de victoire : LES 2 MORCEAUX DOIVENT ÊTRE 'disabled' (PV <= 0)
	if is_door_disabled() and is_engine_disabled():
		print("[XJug] Porte ET Moteur détruits (disabled) -> XJug VAINCUS !")
		subir_elimination()

func subir_degats(_amount: int = 1) -> void:
	# XJug ne prend pas de dégâts directs génériques sur son grand collider body.
	# Les dégâts doivent obligatoirement cibler les HitArea de DoorDmg ou EngineDmg.
	pass

func subir_degats_missile(amount: int, pos_impact: Vector2 = Vector2.INF) -> void:
	# Un tir missile inflige des dégâts aux deux morceaux
	subir_degats_partie("doordmg", amount, pos_impact)
	subir_degats_partie("enginedmg", amount, pos_impact)

## Dégâts directs porte (ex: debug ou interactions spécifiques)
func damage_door(amount: int = 1) -> void:
	subir_degats_partie("doordmg", amount)

## Dégâts directs moteur (ex: debug ou interactions spécifiques)
func damage_engine(amount: int = 1) -> void:
	subir_degats_partie("enginedmg", amount)

func _spawn_part_explosion(sprite_node: Node2D) -> void:
	if sprite_node == null:
		return
	var expl_scene = preload("res://aseprite/effect/xexpl2.tscn")
	if expl_scene:
		var expl = expl_scene.instantiate()
		var parent = get_parent()
		if parent:
			parent.add_child(expl)
			expl.global_position = sprite_node.global_position

func _flash_blanc(target_sprite: CanvasItem) -> void:
	if not enable_hit_flash or target_sprite == null:
		return
	target_sprite.modulate = Color(flash_intensity, flash_intensity, flash_intensity, 1.0)
	var tw := target_sprite.create_tween()
	tw.tween_property(target_sprite, "modulate", Color.WHITE, flash_duration_sec)

func _update_damage_visuals() -> void:
	if door_dmg_sprite and door_dmg_sprite.sprite_frames:
		if door_pv <= 0:
			door_dmg_sprite.animation = &"disabled"
			door_damage_level = 2
		elif door_pv <= int(door_pv_max * 0.5):
			door_dmg_sprite.animation = &"damaged"
			door_damage_level = 1
		else:
			door_dmg_sprite.animation = &"default"
			door_damage_level = 0
		
	if engine_dmg_sprite and engine_dmg_sprite.sprite_frames:
		if engine_pv <= 0:
			engine_dmg_sprite.animation = &"disabled"
			engine_damage_level = 2
		elif engine_pv <= int(engine_pv_max * 0.5):
			engine_dmg_sprite.animation = &"damaged"
			engine_damage_level = 1
		else:
			engine_dmg_sprite.animation = &"default"
			engine_damage_level = 0

func faire_ram_attack() -> void:
	# DÉSACTIVÉ TEMPORAIREMENT
	return

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
		State.CHASE: state_text = "CHASE"
		State.ANTICIPATION: state_text = "ANTICIPATION"
		State.LUNGE: state_text = "LUNGE"
		State.HOLD: state_text = "HOLD"
		State.RETREAT: state_text = "RETREAT"

	var porte_status = "DISABLED" if door_pv <= 0 else ("DMG" if door_pv <= int(door_pv_max * 0.5) else "OK")
	var moteur_status = "DISABLED" if engine_pv <= 0 else ("DMG" if engine_pv <= int(engine_pv_max * 0.5) else "OK")

	var log_text = "État: %s\nTimer: %.2f\nPos X: %.1f\nPV: %d/%d\nPorte: %d/%d (%s)\nMoteur: %d/%d (%s)" % [
		state_text, state_timer, global_position.x, pv_actuels, pv_max,
		door_pv, door_pv_max, porte_status,
		engine_pv, engine_pv_max, moteur_status
	]
	if debug_hud and debug_hud.has_method("set_jug_log"):
		debug_hud.set_jug_log(log_text)
