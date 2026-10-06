class_name BreakableDoor
extends SceneryActorBase

## Porte / Clôture destructible (breakable_xl4fen2) héritant de SceneryActorBase / ActorBase.
## Déverrouille automatiquement le StopMarker désigné lors de sa destruction complète.

enum ExplosionType { NONE, PETITE, MOYENNE, GRANDE, PERSONNALISEE }
enum ExplosionPattern { SIMPLE, DOUBLE, CASCADE }
@export var explosion_type: ExplosionType = ExplosionType.GRANDE
@export var custom_explosion_scene: PackedScene = null
@export var explosion_pattern: ExplosionPattern = ExplosionPattern.DOUBLE

func _get_explosion_scene() -> PackedScene:
	match explosion_type:
		ExplosionType.PETITE:
			return load("res://aseprite/effect/xexpl1.tscn")
		ExplosionType.MOYENNE:
			return load("res://aseprite/effect/xexpl2.tscn")
		ExplosionType.GRANDE:
			return load("res://aseprite/effect/xexpl3.tscn")
		ExplosionType.PERSONNALISEE:
			return custom_explosion_scene
		ExplosionType.NONE:
			return null
		_:
			return load("res://aseprite/effect/xexpl3.tscn")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func _ready() -> void:
	if has_meta("shots"):
		pv_max = int(get_meta("shots"))
	if has_meta("stop"):
		nom_stop_declencheur = str(get_meta("stop"))
	elif has_meta("Stop"):
		nom_stop_declencheur = str(get_meta("Stop"))
		
	super._ready()

func subir_degats_sur_enfant(_enfant: Node, quantite: int) -> void:
	subir_degats(quantite)

func subir_degats(quantite: int = 1) -> void:
	if est_elimine:
		return
		
	pv_actuels -= quantite
	set_meta("shots", pv_actuels)
	
	if pv_actuels <= 0:
		_executer_sequence_destruction()
	else:
		_flash_cloture()

func _flash_cloture() -> void:
	var target_sprite: CanvasItem = sprite
	if target_sprite == null:
		target_sprite = anim_sprite
	if target_sprite == null:
		return
	target_sprite.modulate = Color(3.5, 3.5, 3.5, 1.0)
	var tw := target_sprite.create_tween()
	tw.tween_property(target_sprite, "modulate", Color.WHITE, 0.08)

func _executer_sequence_destruction() -> void:
	if est_elimine:
		return
	est_elimine = true
	
	visible = false
	var hit_area = get_node_or_null("HitArea")
	if hit_area:
		hit_area.queue_free()

	var origine = global_position
	var pos_haute = origine + Vector2(14.5, -115.0)
	var pos_basse = origine + Vector2(14.5, -38.0)
	var pos_milieu = origine + Vector2(14.5, -76.5)
	
	var scene_explosion = _get_explosion_scene()
	if scene_explosion:
		match explosion_pattern:
			ExplosionPattern.SIMPLE:
				_spawn_expl(scene_explosion, pos_milieu, 1.0)
			ExplosionPattern.DOUBLE:
				_spawn_expl(scene_explosion, pos_haute, 1.0)
				await get_tree().create_timer(0.06, false).timeout
				_spawn_expl(scene_explosion, pos_basse, 1.0)
			ExplosionPattern.CASCADE:
				_spawn_expl(scene_explosion, pos_haute, 1.0)
				await get_tree().create_timer(0.06, false).timeout
				_spawn_expl(scene_explosion, pos_milieu, 1.0)
				await get_tree().create_timer(0.06, false).timeout
				_spawn_expl(scene_explosion, pos_basse, 1.0)
	
	# Déverrouillage du StopMarker cible
	var nom_stop_cible: String = nom_stop_declencheur
	var camera: Camera2D = null
	for cam in get_tree().get_nodes_in_group("cameras"):
		if cam is Camera2D and (cam.has_method("deverrouiller_stop") or cam.has_method("reprendre_scroll_force")):
			camera = cam
			break
	if camera == null:
		var found = get_tree().root.find_child("Camera2D", true, false)
		if found is Camera2D:
			camera = found

	if camera:
		if camera.has_method("deverrouiller_stop"):
			camera.deverrouiller_stop(nom_stop_cible)
			print("[BreakableDoor] deverrouiller_stop('", nom_stop_cible, "') déclenché.")
		elif camera.has_method("reprendre_scroll_force"):
			camera.reprendre_scroll_force()
			print("[BreakableDoor] reprendre_scroll_force() (fallback) déclenché.")

	queue_free()

func _spawn_expl(scene: PackedScene, pos: Vector2, fallback_timer: float) -> void:
	if scene == null:
		return
	var e = scene.instantiate()
	e.z_index = 50  # Même z_index que breakable_prop.gd
	
	# Utiliser le mode de positionnement configuré
	var parent_cible := get_parent() if get_parent() else self
	if mode_positionnement_apparitions == "global_world_space":
		e.global_position = pos
	else:
		e.position = parent_cible.to_local(pos)
	parent_cible.add_child(e)
	print("[BreakableDoor] Explosion spawnée à locale: ", e.position, " parent: ", parent_cible.name, " z_index: ", e.z_index)
	
	var a := e.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if a:
		var anim_name := "explose" if a.sprite_frames.has_animation("explose") else "default"
		a.play(anim_name)
		a.animation_finished.connect(_on_expl_anim_finished.bind(e))
	else:
		get_tree().create_timer(fallback_timer, false).timeout.connect(_on_expl_timeout.bind(e))

func _trouver_parallax_layer_parent(node: Node) -> ParallaxLayer:
	var p = node
	while p:
		if p is ParallaxLayer:
			return p
		p = p.get_parent()
	return null

func _on_expl_anim_finished(node: Node) -> void:
	if is_instance_valid(node):
		var anim = node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim:
			anim.hide()
		node.queue_free()

func _on_expl_timeout(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
