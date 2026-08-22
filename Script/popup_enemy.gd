class_name PopupEnemy
extends ActorBase

@export var nombre_de_tirs: int = 8 # Nombre de tirs par rafale (remplace la duree fixe)
@export var duree_attaque_secondes: float = 9.0
@export var delai_avant_tir: float = 0.5 # Délai d'attente avant le premier tir / pause idle
@export var boucler_apparition_test: bool = false
@export var delai_reapparition_secondes: float = 5.0

var en_cours_dattaque: bool = false

func _ready() -> void:
	super._ready()
	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation("popup"):
			anim_sprite.sprite_frames.set_animation_loop("popup", false)
		if anim_sprite.sprite_frames.has_animation("retract"):
			anim_sprite.sprite_frames.set_animation_loop("retract", false)
		if anim_sprite.sprite_frames.has_animation("hit"):
			anim_sprite.sprite_frames.set_animation_loop("hit", false)
		if anim_sprite.sprite_frames.has_animation("hithead"):
			anim_sprite.sprite_frames.set_animation_loop("hithead", false)

		if not anim_sprite.animation_finished.is_connected(_on_animated_sprite_finished):
			anim_sprite.animation_finished.connect(_on_animated_sprite_finished)

func activer_acteur() -> void:
	super.activer_acteur()
	demarrer_sequence_popup()

func demarrer_sequence_popup() -> void:
	if possede_animation("popup"):
		jouer_animation("popup")
	else:
		demarrer_phase_attaque()

func subir_degats(quantite: int) -> void:
	if est_elimine: return
	pv_actuels -= quantite
	
	if en_cours_dattaque:
		if possede_animation("hit"):
			jouer_animation("hit")
	
	if pv_actuels <= 0:
		subir_elimination()

func _on_animated_sprite_finished() -> void:
	if anim_sprite and anim_sprite.animation in [&"hit", &"hithead"]:
		if en_cours_dattaque and not est_elimine:
			if possede_animation("shoot"):
				jouer_animation("shoot")
			elif possede_animation("idle"):
				jouer_animation("idle")
	elif anim_sprite and anim_sprite.animation == &"popup":
		if delai_avant_tir > 0.0:
			await attendre(delai_avant_tir)
		demarrer_phase_attaque()
	elif anim_sprite and anim_sprite.animation == &"retract":
		if boucler_apparition_test:
			_masquer_visuel()
			await attendre(delai_reapparition_secondes)
			deja_active = false
			activer_acteur()
		else:
			queue_free()

func demarrer_phase_attaque() -> void:
	en_cours_dattaque = true
	if possede_animation("shoot"):
		jouer_animation("shoot")
	elif possede_animation("idle"):
		jouer_animation("idle")
	
	await attendre(duree_attaque_secondes)
	if not est_elimine and en_cours_dattaque:
		en_cours_dattaque = false
		if possede_animation("retract"):
			jouer_animation("retract")
		else:
			queue_free()
