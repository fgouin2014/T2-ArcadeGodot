# civilian_ally.gd — DÉPRÉCIÉ
# Ce script est remplacé par :
#   - res://Script/walking_civilian.gd  (xyjc, xsarah)
#   - res://Script/civilian_decoratif.gd (xojc)
# Conservé uniquement pour compatibilité avec les scènes non encore migrées.

class_name CivilianAlly
extends ActorBase

func activer_acteur() -> void:
	super.activer_acteur()
	if possede_animation("walk"):
		jouer_animation("walk")
