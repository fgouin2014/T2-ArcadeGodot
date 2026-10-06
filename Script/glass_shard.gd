class_name GlassShard
extends Node2D

var velocite: Vector2 = Vector2.ZERO
var gravite: float = 400.0

func _ready() -> void:
	z_index = 100
	get_tree().create_timer(0.5, false).timeout.connect(_fade_out)

func _physics_process(delta: float) -> void:
	velocite.y += gravite * delta
	position += velocite * delta

func _fade_out() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
