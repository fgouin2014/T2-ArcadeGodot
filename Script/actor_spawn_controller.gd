class_name ActorSpawnController
extends Node

var scene_path: String = ""
var position_reference: Vector2 = Vector2.ZERO
var max_spawns: int = 0
var stop_at_original_death: bool = true
var original_id: int = 0
var initial_delay: float = 0.0
var repeat_interval: float = 0.1
var step_spawn: int = 3
var distance_step_px: float = 10.0
var parent_container: Node = null
var speed_original: float = 40.0
var direction_original: String = "droite_vers_gauche"
var flip_original: bool = false
var special_properties: Dictionary = {}
var count_spawns: int = 1
var active_actors: Array[ActorBase] = []
var timer_initial: Timer
var timer_repeat: Timer

func configurer(source: ActorBase) -> void:
	scene_path = source.scene_file_path
	position_reference = source.position_spawn_initiale
	max_spawns = source.nombre_max_spawns
	stop_at_original_death = source.stopper_spawn_a_la_mort
	original_id = source.get_instance_id()
	initial_delay = source.delai_spawn
	repeat_interval = max(source.intervalle_repetition, 0.1)
	step_spawn = source.step_decalage_spawn
	distance_step_px = source.distance_step_spawn_px
	parent_container = source.get_parent()
	speed_original = source.vitesse_deplacement
	direction_original = source.direction_deplacement
	flip_original = source.inverser_visuel
	active_actors = [source]
	for property_name in [
		"comportement_bigend", "comportement_enfwrd", "option_comportement", "comportement_medend",
		"nombre_de_passages", "attaquer_en_passant", "mode_hk_decolage",
		"y_decolage", "vitesse_decolage", "vitesse_vol_horizontal", "missile_scene"
	]:
		if property_name in source:
			special_properties[property_name] = source.get(property_name)

func demarrer() -> void:
	if parent_container == null or scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		queue_free()
		return
	if max_spawns > 0 and count_spawns >= max_spawns:
		queue_free()
		return

	timer_repeat = Timer.new()
	timer_repeat.wait_time = repeat_interval
	timer_repeat.one_shot = false
	add_child(timer_repeat)
	timer_repeat.timeout.connect(_on_timer_repeat)

	timer_initial = Timer.new()
	timer_initial.wait_time = max(initial_delay if initial_delay > 0.0 else repeat_interval, 0.1)
	timer_initial.one_shot = true
	add_child(timer_initial)
	timer_initial.timeout.connect(_on_timer_initial)
	timer_initial.start()

func _on_timer_initial() -> void:
	if _generer_clone():
		timer_repeat.start()
	else:
		queue_free()

func _on_timer_repeat() -> void:
	if not _generer_clone():
		queue_free()

func _generer_clone() -> bool:
	if stop_at_original_death:
		var original = instance_from_id(original_id) as ActorBase
		if is_instance_valid(original) and original.est_elimine:
			return false


	if max_spawns > 0 and count_spawns >= max_spawns:
		return false
	var scene = load(scene_path) as PackedScene
	if scene == null or parent_container == null or not is_instance_valid(parent_container):
		return false
	var clone = scene.instantiate() as ActorBase
	if clone == null:
		return false

	clone.est_un_clone = true
	clone.repeter_spawn = false
	clone.nombre_max_spawns = 0
	clone.actif_au_demarrage = false
	clone.activer_uniquement_sur_ecran = false
	clone.vitesse_deplacement = speed_original
	clone.direction_deplacement = direction_original
	clone.inverser_visuel = flip_original
	for property_name in special_properties:
		if property_name in clone:
			clone.set(property_name, special_properties[property_name])

	parent_container.add_child(clone)
	clone.position = ActorBase._choisir_position_spawn(position_reference, step_spawn, distance_step_px, active_actors)
	active_actors.append(clone)
	count_spawns += 1
	clone.activer_acteur()
	return max_spawns <= 0 or count_spawns < max_spawns
