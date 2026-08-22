class_name TechEnemy
extends WalkingEnemy

## Script spécialisé pour l'ennemi XTECH (Technicien Cyberdyne).

@export_enum(
	"lancer_grenade_1x_puis_marche",
	"stationnaire_lanceur",
	"marche_et_tir_profil"
) var comportement_tech: String = "lancer_grenade_1x_puis_marche"

func activer_acteur() -> void:
	option_comportement = comportement_tech
	super.activer_acteur()

func _sequence_drop_puis_walk() -> void:
	_arreter_deplacement()
	
	# 1. Tag 'throw' (lance le flask à la frame 2)
	a_lance_projectile_ce_cycle = false
	if possede_animation("throw"):
		jouer_animation("throw")
		await _attendre_fin_animation_ou_timer(0.8)
	
	if est_elimine or not deja_active: return

	# 2. Tag 'recovery' (phase de récupération après le lancer)
	var anim_recov = "recovery" if possede_animation("recovery") else "xtechdrop"
	if possede_animation(anim_recov):
		jouer_animation(anim_recov)
		await _attendre_fin_animation_ou_timer(0.8)

	if est_elimine or not deja_active: return

	# 3. Enchaîne avec 'walk' et continue la marche
	var anim_marche = "walk" if possede_animation("walk") else "walk"
	_demarrer_deplacement(anim_marche)
	_boucle_alternance_tir(anim_marche, "throw" if possede_animation("throw") else "shoot")
