class_name BreakableReservoir
extends SceneryActorBase

## Réservoir destructible de décor héritant de SceneryActorBase / ActorBase.

enum ExplosionType { NONE, PETITE, MOYENNE, GRANDE, PERSONNALISEE }
enum ExplosionPattern { SIMPLE, DOUBLE, CASCADE }
@export var explosion_type: ExplosionType = ExplosionType.GRANDE
@export var custom_explosion_scene: PackedScene = null
@export var explosion_pattern: ExplosionPattern = ExplosionPattern.SIMPLE

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
	# Compatibilité rétroactive si meta hp présente
	if has_meta("hp"):
		pv_max = int(get_meta("hp"))
	super._ready()
	pv_actuels = pv_max

func subir_degats_sur_enfant(_enfant: Node, quantite: int) -> void:
	subir_degats(quantite)

func subir_degats(quantite: int = 1) -> void:
	if est_elimine:
		return
		
	pv_actuels -= quantite
	set_meta("hp", pv_actuels)
	
	if pv_actuels <= 0:
		_exploser_et_detruire()
	else:
		_flash_blanc()

func _flash_blanc() -> void:
	var target_sprite: CanvasItem = sprite
	if target_sprite == null:
		target_sprite = anim_sprite
	if target_sprite:
		target_sprite.modulate = Color(3.5, 3.5, 3.5, 1.0)
		var tw := target_sprite.create_tween()
		tw.tween_property(target_sprite, "modulate", Color.WHITE, 0.08)

func _exploser_et_detruire() -> void:
	if est_elimine:
		return
	est_elimine = true
	
	visible = false
	var hit_area = get_node_or_null("HitArea")
	if hit_area:
		hit_area.queue_free()

	var scene_explosion = _get_explosion_scene()
	if scene_explosion and is_inside_tree():
		var origine = global_position
		var pos_haute = origine + Vector2(0, -20)
		var pos_basse = origine + Vector2(0, 20)
		
		match explosion_pattern:
			ExplosionPattern.SIMPLE:
				_spawn_expl_at(scene_explosion, origine)
			ExplosionPattern.DOUBLE:
				_spawn_expl_at(scene_explosion, pos_haute)
				await get_tree().create_timer(0.06, false).timeout
				_spawn_expl_at(scene_explosion, pos_basse)
			ExplosionPattern.CASCADE:
				_spawn_expl_at(scene_explosion, pos_haute)
				await get_tree().create_timer(0.06, false).timeout
				_spawn_expl_at(scene_explosion, origine)
				await get_tree().create_timer(0.06, false).timeout
				_spawn_expl_at(scene_explosion, pos_basse)

	queue_free()

func _spawn_expl_at(scene: PackedScene, pos: Vector2) -> void:
	var expl = scene.instantiate() as Node2D
	if expl:
		expl.z_index = 50
		var parent_cible := get_parent() if get_parent() else self
		if mode_positionnement_apparitions == "global_world_space":
			expl.global_position = pos
		else:
			expl.position = parent_cible.to_local(pos)
		parent_cible.add_child(expl)
		
		var anim := expl.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim:
			var anim_nom := "explose" if anim.sprite_frames.has_animation("explose") else "default"
			anim.play(anim_nom)
			anim.animation_finished.connect(func(_a=null):
				if is_instance_valid(expl):
					expl.queue_free()
			)
		else:
			get_tree().create_timer(0.8, false).timeout.connect(func():
				if is_instance_valid(expl):
					expl.queue_free()
			)
