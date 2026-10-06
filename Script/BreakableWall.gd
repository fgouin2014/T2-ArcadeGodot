class_name BreakableWall
extends SceneryActorBase

## Mur destructible multi-pièces (BreakableWall) héritant de SceneryActorBase / ActorBase.

@export var hp_piece: int = 3
enum ExplosionType { NONE, PETITE, MOYENNE, GRANDE, PERSONNALISEE }
enum ExplosionPattern { SIMPLE, DOUBLE, CASCADE }
@export var explosion_type: ExplosionType = ExplosionType.MOYENNE
@export var custom_explosion_scene: PackedScene = null
@export var explosion_pattern: ExplosionPattern = ExplosionPattern.CASCADE

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
			return load("res://aseprite/effect/xexpl2.tscn")

@onready var main_wall: StaticBody2D = get_node_or_null("MainWall") as StaticBody2D
@onready var left_piece: StaticBody2D = get_node_or_null("LeftPiece") as StaticBody2D
@onready var right_piece: StaticBody2D = get_node_or_null("RightPiece") as StaticBody2D

func _ready() -> void:
	super._ready()
	if is_instance_valid(main_wall):
		main_wall.collision_layer = 0

func subir_degats_sur_enfant(enfant: Node, quantite: int) -> void:
	if not is_instance_valid(enfant) or est_elimine:
		return
		
	var hp_actuel: int = hp_piece
	if enfant.has_meta("hp"):
		hp_actuel = int(enfant.get_meta("hp"))
	else:
		enfant.set_meta("hp", hp_actuel)
		
	# Protection : MainWall ne prend pas de dégâts tant que LeftPiece ou RightPiece existent
	if enfant == main_wall:
		if is_instance_valid(left_piece) or is_instance_valid(right_piece):
			print("[BreakableWall] MainWall est encore protégé par les morceaux latéraux !")
			return
		
	hp_actuel -= quantite
	enfant.set_meta("hp", hp_actuel)
	print("[BreakableWall] ", enfant.name, " prend des dégâts. HP restants : ", hp_actuel)
	
	_flash_morceau(enfant)
	
	if hp_actuel <= 0:
		print("[BreakableWall] ", enfant.name, " est détruit !")
		
		# Ajouter les points pour la destruction du morceau
		GlobalSettings.ajouter_score(points_score)
		
		var position_explosion = _calculer_centre_morceau(enfant)
		var scene_a_utiliser = _get_explosion_scene()
		var temps_fallback = 1.0 if enfant == main_wall else 0.5
		
		if scene_a_utiliser:
			_declencher_cascade_explosions(scene_a_utiliser, position_explosion, temps_fallback)
		
		enfant.visible = false
		enfant.set_meta("hp", -999)
		
		if enfant == left_piece:
			left_piece = null
		elif enfant == right_piece:
			right_piece = null
			
		enfant.queue_free()
		_verifier_activation_mur()
		
		if enfant == main_wall:
			main_wall = null
			est_elimine = true
			get_tree().create_timer(1.2, false).timeout.connect(_on_cleanup_timer)

func _on_cleanup_timer() -> void:
	if is_instance_valid(self):
		queue_free()

func _flash_morceau(enfant: Node) -> void:
	var s = enfant.get_node_or_null("Sprite2D") as Sprite2D
	if s:
		s.modulate = Color(3.5, 3.5, 3.5, 1.0)
		var tw = s.create_tween()
		tw.tween_property(s, "modulate", Color.WHITE, 0.08)

func _verifier_activation_mur() -> void:
	if not is_instance_valid(main_wall):
		return
		
	var left_valid = is_instance_valid(left_piece) and left_piece.is_inside_tree()
	var right_valid = is_instance_valid(right_piece) and right_piece.is_inside_tree()
	
	if not left_valid and not right_valid:
		main_wall.collision_layer = 8
		print("[BreakableWall] Mur central activé et maintenant vulnérable !")

func subir_degats(quantite: int = 1) -> void:
	if is_instance_valid(left_piece):
		subir_degats_sur_enfant(left_piece, quantite)
	elif is_instance_valid(right_piece):
		subir_degats_sur_enfant(right_piece, quantite)
	elif is_instance_valid(main_wall):
		subir_degats_sur_enfant(main_wall, quantite)

func _declencher_cascade_explosions(scene: PackedScene, centre: Vector2, fallback_timer: float) -> void:
	var pos_haut = centre + Vector2(-15, -20)
	var pos_milieu = centre + Vector2(0, 0)
	var pos_bas = centre + Vector2(0, 20)
	
	match explosion_pattern:
		ExplosionPattern.SIMPLE:
			_spawn_expl(scene, pos_milieu, fallback_timer)
		ExplosionPattern.DOUBLE:
			_spawn_expl(scene, pos_haut, fallback_timer)
			await get_tree().create_timer(0.06, false).timeout
			if not is_inside_tree(): return
			_spawn_expl(scene, pos_bas, fallback_timer)
		ExplosionPattern.CASCADE:
			_spawn_expl(scene, pos_haut, fallback_timer)
			await get_tree().create_timer(0.06, false).timeout
			if not is_inside_tree(): return
			_spawn_expl(scene, pos_milieu, fallback_timer)
			await get_tree().create_timer(0.06, false).timeout
			if not is_inside_tree(): return
			_spawn_expl(scene, pos_bas, fallback_timer)

func _calculer_centre_morceau(node_morceau: Node) -> Vector2:
	var poly_node = node_morceau.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if poly_node and poly_node.polygon.size() > 0:
		var x_min = INF
		var x_max = -INF
		var y_min = INF
		var y_max = -INF
		
		for vertex in poly_node.polygon:
			var global_vertex = poly_node.to_global(vertex)
			if global_vertex.x < x_min: x_min = global_vertex.x
			if global_vertex.x > x_max: x_max = global_vertex.x
			if global_vertex.y < y_min: y_min = global_vertex.y
			if global_vertex.y > y_max: y_max = global_vertex.y
			
		return Vector2((x_min + x_max) / 2.0, (y_min + y_max) / 2.0)
		
	return node_morceau.global_position

func _spawn_expl(scene: PackedScene, pos: Vector2, fallback_timer: float) -> void:
	if scene == null or not is_inside_tree():
		return
	var e = scene.instantiate()
	e.z_index = 50
	var parent_cible := get_parent() if get_parent() else self
	if mode_positionnement_apparitions == "global_world_space":
		e.global_position = pos
	else:
		e.position = parent_cible.to_local(pos)
	parent_cible.add_child(e)
	var a := e.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if a:
		var anim_name := "explose" if a.sprite_frames.has_animation("explose") else "default"
		a.play(anim_name)
		a.animation_finished.connect(_on_expl_anim_finished.bind(e))
	else:
		get_tree().create_timer(fallback_timer, false).timeout.connect(_on_expl_timeout.bind(e))

func _on_expl_anim_finished(node: Node) -> void:
	if is_instance_valid(node):
		var anim = node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim:
			anim.hide()
		node.queue_free()

func _on_expl_timeout(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
