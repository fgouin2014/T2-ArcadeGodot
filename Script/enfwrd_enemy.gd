class_name EnfwrdEnemy
extends WalkingEnemy

## Script spécialisé pour l'endosquelette XENFWRD (Sol 1) avec options d'inspecteur exclusives.

@export_enum(
	"marche_stop_idle_shoot",
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant",
	"marche_tir_face"
) var comportement_enfwrd: String = "marche_stop_idle_shoot"

func _ready() -> void:
	super._ready()

func activer_acteur() -> void:
	var nom_node = name.to_lower()
	if "xenfwrd3" in nom_node:
		option_comportement = "marche_et_tir_en_marchant"
	elif "xenfwrd2" in nom_node:
		option_comportement = "marche_et_tir_profil"
	elif "xenfwrd" in nom_node and not ("xenfwrd2" in nom_node or "xenfwrd3" in nom_node):
		option_comportement = "marche_stop_idle_shoot"
	elif option_comportement == "" or option_comportement == null:
		option_comportement = comportement_enfwrd
		
	super.activer_acteur()
