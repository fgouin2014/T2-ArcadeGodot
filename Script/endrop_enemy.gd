class_name EndropEnemy
extends WalkingEnemy

## Script spécialisé pour XENDROP avec comportement de drop initial, salve de tir face, et marche/tir alterné.

@export_enum(
	"drop_tir_face_puis_marche_stop_shoot",
	"marche_stop_idle_shoot",
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant"
) var comportement_xendrop: String = "drop_tir_face_puis_marche_stop_shoot"

func activer_acteur() -> void:
	option_comportement = comportement_xendrop
	super.activer_acteur()
