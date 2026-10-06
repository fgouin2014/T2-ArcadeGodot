class_name BreakableWindow
extends Node2D

@export var scene_glass_shard_a: PackedScene
@export var scene_glass_shard_b: PackedScene

## Points de score accordés au joueur lors de la casse de chaque vitre
@export var points_score: int = 150

var _damaged_textures: Dictionary = {}

func _ready() -> void:
	if scene_glass_shard_a == null:
		scene_glass_shard_a = load("res://aseprite/effect/glass_shard_a.tscn")
	if scene_glass_shard_b == null:
		scene_glass_shard_b = load("res://aseprite/effect/glass_shard_b.tscn")

	for child in get_children():
		if child is Sprite2D:
			_damaged_textures[child] = child.get_meta("damaged_texture", null)
			var area = child.get_node_or_null("HitArea") as Area2D
			if area:
				area.monitorable = true
				if not area.area_entered.is_connected(_on_pane_hit):
					area.area_entered.connect(_on_pane_hit.bind(child))

func _on_pane_hit(_bullet: Area2D, pane: Sprite2D) -> void:
	casse_vitre(pane)

func subir_degats_sur_enfant(enfant: Node, _quantite: int = 1) -> void:
	# Appelé par projectile.gd avec la vitre touchée exacte
	var pane = enfant as Sprite2D
	if pane == null and enfant is Area2D:
		pane = enfant.get_parent() as Sprite2D
	if pane and is_instance_valid(pane):
		casse_vitre(pane)

func subir_degats(_quantite: int = 1) -> void:
	# Fallback si appelé sans vitre spécifique
	for child in get_children():
		if child is Sprite2D and not child.get_meta("destroyed", false):
			casse_vitre(child)
			break

func casse_vitre(pane: Sprite2D) -> void:
	if pane.get_meta("destroyed", false):
		return
	
	pane.set_meta("destroyed", true)
	if _damaged_textures.has(pane) and _damaged_textures[pane] != null:
		pane.texture = _damaged_textures[pane]
		
	var hit_area = pane.get_node_or_null("HitArea") as Area2D
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
	
	# Ajouter les points pour la casse de la vitre
	GlobalSettings.ajouter_score(points_score)
	
	_spawn_gibs(pane)

func _spawn_gibs(pane: Sprite2D) -> void:
	if pane == null:
		return
	var count_a: int = randi_range(3, 4)
	var count_b: int = randi_range(3, 4)
	var total_count: int = count_a + count_b
	
	var shard_list: Array = []
	for i in count_a:
		shard_list.append(scene_glass_shard_a)
	for i in count_b:
		shard_list.append(scene_glass_shard_b)
	shard_list.shuffle()
	
	for idx in range(total_count):
		var scene: PackedScene = shard_list[idx]
		if not scene:
			continue
		var g = scene.instantiate() as Node2D
		if not g:
			continue
		g.position = pane.position
		
		var denom: float = max(float(total_count - 1), 1.0)
		var angle_deg: float = lerp(-150.0, -30.0, float(idx) / denom)
		angle_deg += randf_range(-15.0, 15.0)
		var angle_rad: float = deg_to_rad(angle_deg)
		var speed: float = randf_range(60.0, 140.0)
		g.velocite = Vector2(cos(angle_rad), sin(angle_rad)) * speed
		g.z_index = 100
		
		add_child(g)
