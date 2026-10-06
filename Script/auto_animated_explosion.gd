class_name AutoAnimatedExplosion
extends Node2D

func _ready() -> void:
	var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		anim.animation_finished.connect(queue_free)
		# Essayer les animations courantes
		if anim.sprite_frames.has_animation("explose"):
			anim.play("explose")
		elif anim.sprite_frames.has_animation("explode"):
			anim.play("explode")
		elif anim.sprite_frames.has_animation("default"):
			anim.play("default")
		else:
			anim.play()
	else:
		queue_free()
