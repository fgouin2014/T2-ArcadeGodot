class_name CivilianDecoratif
extends ActorBase

## Script purement décoratif pour les civils sans interaction de gameplay.
## Utilisé par xojc (Old John Connor) en Level 3 (cinématique) et Level 4 (statique décor).

# --- EXPORTS ---
@export var duree_idle_initial: float = 2.0
## Liste ordonnée des animations à enchaîner avant walk (ex: ["idle", "idle_walk"])
@export var tags_sequence: Array[String] = []
@export var duree_par_tag: float = 2.0  # Secondes par tag de la séquence

func activer_acteur() -> void:
	super.activer_acteur()
	_jouer_sequence_decorative()

func _jouer_sequence_decorative() -> void:
	## Joue l'idle initial, puis la séquence de tags, puis walk perpétuel.
	
	# Idle initial
	if possede_animation("idle") and duree_idle_initial > 0.0:
		jouer_animation("idle")
		await get_tree().create_timer(duree_idle_initial).timeout
	if est_elimine or not deja_active:
		return

	# Séquence de tags
	for tag in tags_sequence:
		if est_elimine or not deja_active:
			return
		if possede_animation(tag):
			jouer_animation(tag)
			# Si l'animation est non-bouclée, attendre sa fin ; sinon durée fixe
			if anim_sprite and anim_sprite.sprite_frames:
				if anim_sprite.sprite_frames.has_animation(tag) and not anim_sprite.sprite_frames.get_animation_loop(tag):
					await anim_sprite.animation_finished
				else:
					await get_tree().create_timer(duree_par_tag).timeout
			else:
				await get_tree().create_timer(duree_par_tag).timeout

	# Walk perpétuel jusqu'à sortie du cadre
	if possede_animation("walk") and not est_elimine:
		jouer_animation("walk")
