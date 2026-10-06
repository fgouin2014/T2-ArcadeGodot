class_name HitTankEffect
extends Node2D

signal fluid_pool_running_change(est_running: bool)

@onready var hole: Sprite2D = $hole
@onready var fluid: AnimatedSprite2D = $fluid
@onready var pool: AnimatedSprite2D = $pool
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var fluid_area: Area2D = $fluid/Area2D
@onready var pool_area: Area2D = $pool/Area2D

## Niveau Y absolu du sol dans le repère local du boss hittank
@export var sol_y_local: float = 152.0

## Bornes de hauteur pour interpoler la dérive X de la flaque
@export var y_impact_min: float = 48.0
@export var y_impact_max: float = 110.0

@export var offset_x_pool_haut: float = 9.0
@export var offset_x_pool_bas: float = 3.0

## Offset pour que le trou noir du sprite (situé vers le haut de xjug4_05 de 115px) soit centré sur le réticule
## Décalé en X positif (+3.5px) pour aligner le centre du trou sur le réticule
@export var offset_centrage_trou: Vector2 = Vector2(3.5, 48.0)

func _ready() -> void:
	if fluid:
		fluid.z_index = 1
	if pool:
		pool.z_index = 3
	if hole:
		hole.z_index = 1

	if anim_player and anim_player.has_animation("flow_and_fade"):
		anim_player.play("flow_and_fade")
		_activer_collisions()
		_notifier_etat_animations()
		# Garantir l'extinction nette et l'émission du signal à 5.0 secondes
		var tw = create_tween()
		tw.tween_interval(5.0)
		tw.tween_callback(func():
			_desactiver_collisions()
			if is_instance_valid(fluid):
				fluid.visible = false
				fluid.stop()
			if is_instance_valid(pool):
				pool.visible = false
				pool.stop()
			fluid_pool_running_change.emit(false)
			print("[HIT TANK] Extinction garantie des flaques/fluides à 5.0s")
		)
	else:
		_demarrer_sequence_par_code()

## Configure l'impact au point exact où le réticule a touché
func configurer_impact(pos_locale_impact: Vector2) -> void:
	# Caler le trou noir exactement sous le centre de la croix du réticule
	position = pos_locale_impact + offset_centrage_trou

	if hole:
		hole.position = Vector2.ZERO

	if fluid:
		fluid.position = Vector2.ZERO

	# Calcul de la dérive horizontale X de la flaque selon la hauteur de tir
	var ratio_y = clamp((pos_locale_impact.y - y_impact_min) / max(y_impact_max - y_impact_min, 1.0), 0.0, 1.0)
	var decalage_x = lerp(offset_x_pool_haut, offset_x_pool_bas, ratio_y)
	
	# La flaque 'pool' se pose au sol au Y fixe (sol_y_local - position.y)
	var distance_au_sol_y = sol_y_local - position.y
	if pool:
		pool.position = Vector2(decalage_x, distance_au_sol_y)

func _demarrer_sequence_par_code() -> void:
	if fluid:
		fluid.visible = true
		fluid.play("running")
	if pool:
		pool.visible = true
		pool.play("running")
	if hole:
		hole.visible = true
		hole.modulate.a = 1.0
	
	# Activer les collisions quand fluid et pool sont visibles
	_activer_collisions()
	
	# Notifier l'état des animations
	_notifier_etat_animations()

	# 1. 5 secondes : arrêt et masquage net du fluide et de la flaque
	var tw = create_tween()
	tw.tween_interval(5.0)
	tw.tween_callback(func():
		if is_instance_valid(fluid):
			fluid.stop()
			fluid.visible = false
		if is_instance_valid(pool):
			pool.stop()
			pool.visible = false
		# Désactiver les collisions quand fluid.stop() et pool.stop()
		_desactiver_collisions()
		# Notifier que les animations ne sont plus running
		_notifier_etat_animations()
	)

	# 2. Le trou 'hole' reste 4 secondes supplémentaires (total 9s), puis fondu de fermeture
	tw.tween_interval(4.0)
	tw.tween_callback(func():
		if is_instance_valid(hole):
			var tw_fade = create_tween()
			tw_fade.tween_property(hole, "modulate:a", 0.0, 0.6)
			tw_fade.tween_callback(queue_free)
		else:
			queue_free()
	)

func _activer_collisions() -> void:
	if is_instance_valid(fluid_area):
		fluid_area.monitoring = true
		fluid_area.monitorable = true
	if is_instance_valid(pool_area):
		pool_area.monitoring = true
		pool_area.monitorable = true

func _desactiver_collisions() -> void:
	if is_instance_valid(fluid_area):
		fluid_area.monitoring = false
		fluid_area.monitorable = false
		for col in fluid_area.find_children("*", "CollisionShape2D"):
			if col is CollisionShape2D:
				(col as CollisionShape2D).set_deferred("disabled", true)
	if is_instance_valid(pool_area):
		pool_area.monitoring = false
		pool_area.monitorable = false
		for col in pool_area.find_children("*", "CollisionShape2D"):
			if col is CollisionShape2D:
				(col as CollisionShape2D).set_deferred("disabled", true)

func _notifier_etat_animations() -> void:
	var est_running = false
	if fluid and fluid.animation == "running" and fluid.is_playing():
		est_running = true
	if pool and pool.animation == "running" and pool.is_playing():
		est_running = true
	
	print("[HIT TANK] État animations: fluid=", fluid.animation if fluid else "null", " pool=", pool.animation if pool else "null", " running=", est_running)
	fluid_pool_running_change.emit(est_running)
