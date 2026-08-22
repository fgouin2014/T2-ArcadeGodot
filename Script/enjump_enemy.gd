class_name EnjumpEnemy
extends WalkingEnemy

## Script spécialisé pour XENJUMP avec les mêmes options d'inspecteur que XBIGEND.

@export_enum(
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant",
	"marche_stop_idle_shoot"
) var comportement_xenjump: String = "marche_et_tir_profil"

func activer_acteur() -> void:
	option_comportement = comportement_xenjump
	super.activer_acteur()
