class_name EthrowEnemy
extends WalkingEnemy

## Script spécialisé pour l'endosquelette XETHROW avec options d'inspecteur identiques à XMEDEND.

@export_enum(
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant",
	"marche_stop_idle_shoot",
	"saut_obstacle",
	"lancer_grenade_1x_puis_marche",
	"stationnaire_lanceur"
) var comportement_xethrow: String = "lancer_grenade_1x_puis_marche"

func activer_acteur() -> void:
	option_comportement = comportement_xethrow
	super.activer_acteur()
