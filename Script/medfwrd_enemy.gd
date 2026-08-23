class_name MedfwrdEnemy
extends MedendEnemy

## Script spécialisé pour l'endosquelette XMEDFWRD (Sol 2).

func activer_acteur() -> void:
	var nom_node = name.to_lower()
	if "xmedfwrd3" in nom_node:
		option_comportement = "marche_et_tir_en_marchant"
	elif "xmedfwrd2" in nom_node:
		option_comportement = "marche_et_tir_profil"
	elif "xmedfwrd" in nom_node and not ("xmedfwrd2" in nom_node or "xmedfwrd3" in nom_node):
		option_comportement = "marche_stop_idle_shoot"
	elif option_comportement == "" or option_comportement == null or option_comportement == "marche_et_tir_profil":
		option_comportement = comportement_medend
		
	super.activer_acteur()
