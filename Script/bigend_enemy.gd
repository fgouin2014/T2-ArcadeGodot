class_name BigendEnemy
extends WalkingEnemy

## Script spécialisé pour l'endosquelette XBIGEND avec options d'inspecteur exclusives.

@export_enum(
	"marche_stop_idle_shoot",
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant"
) var comportement_bigend: String = "marche_stop_idle_shoot"

func activer_acteur() -> void:
	var nom_node = name.to_lower()
	if "xbigend3" in nom_node:
		option_comportement = "marche_et_tir_en_marchant"
	elif "xbigend2" in nom_node:
		option_comportement = "marche_et_tir_profil"
	elif "xbigend" in nom_node and not ("xbigend2" in nom_node or "xbigend3" in nom_node):
		option_comportement = "marche_stop_idle_shoot"
	elif option_comportement == "" or option_comportement == null:
		option_comportement = comportement_bigend
		
	super.activer_acteur()
