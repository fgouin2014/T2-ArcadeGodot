class_name MedendEnemy
extends WalkingEnemy

## Script spécialisé pour l'endosquelette XMEDEND avec options d'inspecteur exclusives.

@export_enum(
	"marche_stop_idle_shoot",
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant",
	"marche_tir_face",
	"saut_obstacle",
	"lancer_grenade_1x_puis_marche",
	"stationnaire_lanceur"
) var comportement_medend: String = "marche_stop_idle_shoot"

func activer_acteur() -> void:
	# Priorité 1 : La valeur choisie explicitement dans l'Inspecteur Godot
	if comportement_medend != "" and comportement_medend != null:
		option_comportement = comportement_medend
	else:
		# Priorité 2 (Fallback) : Déduction automatique par le nom du nœud
		var nom_node = name.to_lower()
		if "xmedend3" in nom_node:
			option_comportement = "marche_et_tir_en_marchant"
		elif "xmedend2" in nom_node:
			option_comportement = "marche_et_tir_profil"
		else:
			option_comportement = "marche_stop_idle_shoot"
		
	super.activer_acteur()
