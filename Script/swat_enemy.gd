class_name SwatEnemy
extends WalkingEnemy

## Script spécialisé pour l'ennemi XSWAT avec options d'inspecteur exclusives.

@export_enum(
	"swat_debout",
	"swat_roulade",
	"swat_aleatoire"
) var comportement_swat: String = "swat_debout"

func activer_acteur() -> void:
	option_comportement = comportement_swat
	super.activer_acteur()
