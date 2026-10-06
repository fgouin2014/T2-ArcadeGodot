class_name XT100Enemy
extends WalkingEnemy

## Boss T-1000 (Level 7 Foundry) — catalogue AnimatedSprite2D :
## aim, shoot, crack, die, form, foward, getup, hit, idle, roll, smash, split, sweep, walk, downed
##
## downed = une seule anim : chute + au sol + relevé (remplace l'ancien enchaînement die + getup)
## getup / die = morceaux legacy (getup = frames relevé seules ; die ≈ chute seule)

# Signaux pour la gauge
signal contact_hittank_effect(en_contact: bool, nb_pools: int)
signal degats_recus(degats: int, est_missile: bool, est_special: bool)
signal cycle_blown_termine(montant_perte: float)

const MODE_MARCHE_PROFIL := "marche_profil"
const MODE_ROULADE_ECRAN := "roulade_ecran"
const MODE_PROFONDEUR_Y := "profondeur_y"

# --- PV & RÉGÉNÉRATION ---
@export var pv_max_t100: int = 5
@export var temps_downed_fallback_sec: float = 2.0
@export var pv_regeneres: int = 5

@export_group("2nd Boss Fight (Foundry)")
## Si true, utilise l'animation 'blown' à la perte des PV de cycle, notifie la gauge et rechute du ciel
@export var utiliser_anim_blown_a_la_mort: bool = false
## Animation et cinématique de défaite finale à 0% de jauge ('crack' pour 1er boss, 'split' pour 2nd boss)
@export_enum("crack", "split") var animation_defaite: String = "crack"
## Pourcentage déduit de la 2e jauge à chaque cycle 'blown'
@export var perte_gauge_par_blown: float = 5.0
## Nœud Area2D définissant la zone de la passerelle (AreaBoundary)
@export var area_boundary_path: NodePath
## Limite X gauche spécifique (ex: passerelle). Laisser à 0.0 pour calcul auto via AreaBoundary ou caméra
@export var limite_x_min_passerelle: float = 0.0
## Limite X droite spécifique (ex: passerelle). Laisser à 0.0 pour calcul auto via AreaBoundary ou caméra
@export var limite_x_max_passerelle: float = 0.0
## Référence optionnelle vers Young John Connor (WalkingCivilian / xyjc) pour tracking et synchronisation
@export var reference_xyjc: NodePath

@export_group("Déplacement")
## Renommages : Deplacement_1 → marche_profil | Deplacement_2_Roll → roulade_ecran
## marche_profil — marche de profil sur X + attaques (Stop1stFight)
## roulade_ecran — traverse l'écran en roulade, attaque entre chaque passage
## profondeur_y — déplacement avant/arrière sur Y (anim foward, sans scale)
@export_enum("marche_profil", "roulade_ecran", "profondeur_y") var comportement_xt100: String = "marche_profil"
@export var interval_marche_sec: float = 3.0
@export var vitesse_roll_multiplicateur: float = 1.0
@export var marge_bord_ecran_px: float = 50.0
@export var limite_y_min_t100: float = 90.0
@export var limite_y_max_t100: float = 140.0

@export_group("Apparition")
@export var jouer_form_a_l_activation: bool = false
@export var tomber_du_ciel: bool = true           ## Active la chute initiale depuis le ciel à l'activation
@export var y_depart_ciel: float = -63.0          ## Coordonnée Y (locale) de départ de la chute
@export var duree_chute_sec: float = 0.5          ## Durée du tween de chute en secondes
@export var rechute_hors_camera: bool = true      ## Si true, le T-1000 rechute depuis le ciel dès qu'il sort de l'écran pendant le combat

@export_group("Attaques")
@export var interval_attaque: float = 0.5
@export var attaque_gun: bool = true
@export var attaque_smash: bool = true
@export var attaque_sweep: bool = true
@export var attaque_split: bool = false
@export var attaque_crack: bool = false
@export var chance_esquive_roll: float = 0.3
## Durée en secondes de la chute finale lors du split defeat (augmenter pour ralentir).
@export var duree_chute_split_sec: float = 1.2

# --- ÉTAT INTERNE ---
var en_cycle_mort: bool = false
var pv_actuels_t100: int = 5
var direction_mouvement_x: int = 1
var direction_mouvement_y: int = 1
var boucle_t100_active: bool = false
var en_attaque: bool = false
var _boucle_t100_en_cours: bool = false
var _mode_deplacement_resolu: String = MODE_MARCHE_PROFIL
var _deplacement_y_actif: bool = false
var _cible_x_roll: float = NAN
var _en_traversée_roll: bool = false
var _token_attaque: int = 0
var _token_impact: int = 0
var _en_hit: bool = false
var _en_rechute: bool = false         ## true pendant une chute depuis le ciel (initiale ou repositionnement)
var _y_atterrissage: float = 0.0      ## Coordonnée Y locale cible (enregistrée à l'activation)
var _en_attente_coup_de_grace: bool = false ## true quand le boss est à 0% près de la cuve en attente du tir alternatif
var _token_phase5: int = 0

# --- GESTION DES PHASES (2ND FIGHT FOUNDRY) ---
var phase_combat_2nd: int = 1         ## 1 = 100%->75%, 2 = 75%->50% (Charge), 3 = 50%->25% (Post-form), 4 = 25%->0% (Charge), 5 = Finale boiler
var _tween_charge_p2: Tween = null
var _tween_recul_p2: Tween = null
var _en_recul_p2: bool = false
const Y_FOND_PASSERELLE := 95.0
const Y_AVANT_PASSERELLE := 155.0
const X_CENTRE_PASSERELLE := 160.0
@export var vitesse_charge_phase2: float = 35.0 ## Vitesse d'avancée de charge Phase 2 (px/s)

func _ready() -> void:
	super._ready()
	pv_actuels_t100 = pv_max_t100
	_mode_deplacement_resolu = _resoudre_mode_deplacement()
	_configurer_detection_hittank()
	call_deferred("_finaliser_pret_t100")

func _configurer_detection_hittank() -> void:
	# Connecter aux signaux de l'Area2D de xt100 pour détecter les Area2D de hittank
	# Les collisions sont configurées dans xt100.tscn (collision_layer/mask)
	var xt100_area = get_node_or_null("AnimatedSprite2D/Area2D") as Area2D
	if xt100_area:
		if not xt100_area.area_entered.is_connected(_on_hittank_area_entered):
			xt100_area.area_entered.connect(_on_hittank_area_entered)
		if not xt100_area.area_exited.is_connected(_on_hittank_area_exited):
			xt100_area.area_exited.connect(_on_hittank_area_exited)
		print("[T1000] Détection hittank_effect configurée")
	
	# Gestion dynamique de la hitbox selon l'animation (crack, downed, form, roll)
	if anim_sprite:
		if not anim_sprite.animation_changed.is_connected(_mettre_a_jour_hitbox_specifique):
			anim_sprite.animation_changed.connect(_mettre_a_jour_hitbox_specifique)
		_mettre_a_jour_hitbox_specifique()

func _mettre_a_jour_hitbox_specifique() -> void:
	if not anim_sprite:
		return
	var nom_anim := str(anim_sprite.animation).to_lower()
	var col_corps := get_node_or_null("CollisionShape2D") as CollisionShape2D
	var col_area := get_node_or_null("AnimatedSprite2D/Area2D/CollisionShape2D") as CollisionShape2D
	
	# Animations au ras du sol : le dessus de la collision descend de 50% vers le sol (base pieds à Y = 0)
	# Hauteur normale = 88px, centre Y = -44 (pieds à Y = 0)
	# Hauteur réduite = 44px (50% de 88px), centre Y = -22 (pieds restent à Y = 0)
	var est_au_sol := nom_anim in ["crack", "downed", "form", "roll", "die", "getup"]
	var hauteur_cible := 44.0 if est_au_sol else 88.0
	var pos_y_cible := -22.0 if est_au_sol else -44.0
	
	if col_corps and col_corps.shape is RectangleShape2D:
		var shape_corps = col_corps.shape as RectangleShape2D
		shape_corps.size.y = hauteur_cible
		col_corps.position.y = pos_y_cible
	
	if col_area and col_area.shape is RectangleShape2D:
		var shape_area = col_area.shape as RectangleShape2D
		shape_area.size.y = hauteur_cible
		col_area.position.y = pos_y_cible

var _zones_hittank_en_contact: Array[Area2D] = []
var _tween_teinte_flaque: Tween = null
# Teinte bleutée éclatante (style flash/surlignage lumineux sans transparence)
const COULEUR_TEINTE_FLAQUE := Color(1.2, 1.4, 2.8, 1.0)

func _on_hittank_area_entered(area: Area2D) -> void:
	# Ignorer formellement les pickups ou autres éléments
	if area is PickupItem or area.get_parent() is PickupItem:
		return
	# Vérifier si c'est une Area2D de hittank_effect (layer 8)
	if (area.collision_layer & 8) != 0 and not _zones_hittank_en_contact.has(area):
		_zones_hittank_en_contact.append(area)
		var nb_pools := _compter_pools_actifs()
		print("[T1000] Contact hittank détecté ! Pools actifs = ", nb_pools)
		_appliquer_teinte_flaque(true)
		contact_hittank_effect.emit(nb_pools > 0, nb_pools)

func _on_hittank_area_exited(area: Area2D) -> void:
	if area is PickupItem or area.get_parent() is PickupItem:
		return
	# Vérifier si c'est une Area2D de hittank_effect (layer 8)
	if _zones_hittank_en_contact.has(area):
		_zones_hittank_en_contact.erase(area)
	var nb_pools := _compter_pools_actifs()
	print("[T1000] Fin contact hittank. Pools restants = ", nb_pools)
	if nb_pools == 0:
		_appliquer_teinte_flaque(false)
	contact_hittank_effect.emit(nb_pools > 0, nb_pools)

func _appliquer_teinte_flaque(activer: bool) -> void:
	var target_sprite: CanvasItem = anim_sprite if anim_sprite else self
	if _tween_teinte_flaque and _tween_teinte_flaque.is_valid():
		_tween_teinte_flaque.kill()
	
	if activer:
		# Application immédiate de la teinte bleutée pendant le contact
		target_sprite.modulate = COULEUR_TEINTE_FLAQUE
	else:
		# Dès la sortie de la flaque : s'estompe progressivement en 0.5s vers la couleur normale (Color.WHITE)
		_tween_teinte_flaque = target_sprite.create_tween()
		_tween_teinte_flaque.tween_property(target_sprite, "modulate", Color.WHITE, 0.5)

func _compter_pools_actifs() -> int:
	var total := 0
	# Nettoyer les instances détruites ou désactivées
	var valides: Array[Area2D] = []
	for z in _zones_hittank_en_contact:
		if is_instance_valid(z) and z.is_inside_tree() and (z.monitoring or z.monitorable):
			valides.append(z)
			total += 1
	_zones_hittank_en_contact = valides
	return total

func _resoudre_mode_deplacement() -> String:
	match comportement_xt100:
		"marche_profil", "walk_profil", "Deplacement_1":
			return MODE_MARCHE_PROFIL
		"roulade_ecran", "roll_traversée", "Deplacement_2_Roll":
			return MODE_ROULADE_ECRAN
		"profondeur_y", "foward_profondeur", "Deplacement_3_Foward", "foward":
			return MODE_PROFONDEUR_Y
		_:
			push_warning("[T1000] Mode déplacement inconnu '%s' -> marche_profil" % comportement_xt100)
			return MODE_MARCHE_PROFIL

func _finaliser_pret_t100() -> void:
	_assurer_anim_sprite()
	_renforcer_connexion_stop()
	_connecter_synchronisation_xyjc()
	_verifier_stop_deja_franchi()

func _connecter_synchronisation_xyjc() -> void:
	if reference_xyjc == null or str(reference_xyjc) == "":
		return
	var node_xyjc = get_node_or_null(reference_xyjc)
	if node_xyjc == null and get_parent():
		node_xyjc = get_parent().get_node_or_null(reference_xyjc)
	if node_xyjc and node_xyjc.has_signal("destination_atteinte"):
		if not node_xyjc.destination_atteinte.is_connected(_on_xyjc_destination_atteinte):
			node_xyjc.destination_atteinte.connect(_on_xyjc_destination_atteinte)
			print("[T1000] Connecté à destination_atteinte de: %s" % node_xyjc.name)

func _on_xyjc_destination_atteinte(_pos: Vector2) -> void:
	if deja_active or _en_attente_activation or est_elimine:
		return
	print("[T1000] John Connor est arrivé à destination -> Activation T-1000")
	activer_acteur()

func _assurer_anim_sprite() -> AnimatedSprite2D:
	if anim_sprite == null or not is_instance_valid(anim_sprite):
		anim_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if anim_sprite == null:
			anim_sprite = find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	return anim_sprite

func _obtenir_noed_stop_declencheur() -> Node:
	if declencheur_stop == null or str(declencheur_stop) == "":
		return null
	return get_node_or_null(declencheur_stop)

func _renforcer_connexion_stop() -> void:
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera and camera.has_signal("camera_stop_atteint"):
		if not camera.camera_stop_atteint.is_connected(_on_camera_stop_atteint_t100):
			camera.camera_stop_atteint.connect(_on_camera_stop_atteint_t100)

func _on_camera_stop_atteint_t100(node_stop: Node2D, _nom_stop: String) -> void:
	if deja_active or _en_attente_activation or est_elimine:
		return
	var stop_cible = _obtenir_noed_stop_declencheur()
	if stop_cible != null and stop_cible == node_stop:
		_on_stop_declenche()

func _verifier_stop_deja_franchi() -> void:
	if deja_active or _en_attente_activation or est_elimine:
		return
	var stop_cible = _obtenir_noed_stop_declencheur()
	if stop_cible and stop_cible.get_meta("_stop_deja_franchi", false):
		_on_stop_declenche()

func _on_stop_declenche() -> void:
	# Si synchronisé avec John Connor (xyjc), on ignore le stop caméra direct et on attend destination_atteinte
	if reference_xyjc != null and not str(reference_xyjc).is_empty():
		print("[T1000] Stop caméra atteint mais en attente de l'arrivée de John Connor (%s)" % reference_xyjc)
		return
	super._on_stop_declenche()

func _jouer_anim_t100(nom_anim: String) -> void:
	if not possede_animation(nom_anim):
		push_warning("[T1000] Animation introuvable: '%s'" % nom_anim)
		return
	jouer_animation(nom_anim)
	var sprite := _assurer_anim_sprite()
	if sprite and not sprite.is_playing():
		sprite.play(nom_anim)

func _jouer_anim_t100_inversee(nom_anim: String) -> void:
	var sprite := _assurer_anim_sprite()
	if sprite == null or not possede_animation(nom_anim):
		return
	var frames := sprite.sprite_frames.get_frame_count(nom_anim)
	sprite.animation = nom_anim
	sprite.frame = maxi(frames - 1, 0)
	sprite.speed_scale = -1.0
	sprite.play()
	await _attendre_fin_animation_ou_timer(_obtenir_duree_animation(nom_anim, 1.0))
	sprite.speed_scale = 1.0

func _obtenir_areaboundary_node() -> Area2D:
	var area_b: Area2D = null
	if area_boundary_path != null and not area_boundary_path.is_empty():
		area_b = get_node_or_null(area_boundary_path) as Area2D
		if area_b == null and get_parent():
			area_b = get_parent().get_node_or_null(area_boundary_path) as Area2D
	elif get_parent():
		area_b = get_parent().get_node_or_null("AreaBoundary") as Area2D
	return area_b

func _obtenir_collision_polygon_areaboundary() -> CollisionPolygon2D:
	var area_b := _obtenir_areaboundary_node()
	if area_b == null:
		return null
	var col_poly = area_b.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if col_poly == null:
		col_poly = area_b.get_node_or_null("CollisionShape2D") as CollisionPolygon2D
	if col_poly == null:
		col_poly = area_b.find_child("*Polygon*", true, false) as CollisionPolygon2D
	return col_poly

func _obtenir_point_poly_areaboundary(index: int) -> Vector2:
	var col_poly := _obtenir_collision_polygon_areaboundary()
	if col_poly and col_poly.polygon.size() > index and index >= 0:
		var pt = col_poly.polygon[index]
		var pt_monde = col_poly.to_global(pt)
		return get_parent().to_local(pt_monde) if get_parent() else pt_monde
	return Vector2.ZERO

func _obtenir_limites_x_camera() -> Vector2:
	if limite_x_min_passerelle != 0.0 or limite_x_max_passerelle != 0.0:
		var x_min = minf(limite_x_min_passerelle, limite_x_max_passerelle)
		var x_max = maxf(limite_x_min_passerelle, limite_x_max_passerelle)
		return Vector2(x_min, x_max)

	var col_poly := _obtenir_collision_polygon_areaboundary()
	if col_poly and col_poly.polygon.size() > 0:
		var min_x := INF
		var max_x := -INF
		for pt in col_poly.polygon:
			var pt_monde = col_poly.to_global(pt)
			var pt_local = get_parent().to_local(pt_monde).x if get_parent() else pt_monde.x
			min_x = minf(min_x, pt_local)
			max_x = maxf(max_x, pt_local)
		if min_x < max_x:
			return Vector2(min_x + 10.0, max_x - 10.0)

	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera == null:
		return Vector2(global_position.x - 100.0, global_position.x + 100.0)
	var demi := 160.0
	if "largeur_lucarne" in camera:
		demi = float(camera.largeur_lucarne) / 2.0
	var centre := camera.get_screen_center_position().x
	return Vector2(centre - demi + marge_bord_ecran_px, centre + demi - marge_bord_ecran_px)

func activer_acteur() -> void:
	if deja_active and boucle_t100_active:
		return
	deja_active = true
	_afficher_visuel()
	_assurer_anim_sprite()
	pv_actuels_t100 = pv_max_t100
	_mode_deplacement_resolu = _resoudre_mode_deplacement()
	option_comportement = "t100_standard"
	print("[T1000] Activé — mode: %s" % _mode_deplacement_resolu)

	# Sauvegarder le Y d'atterrissage (position locale au moment de l'activation)
	_y_atterrissage = position_spawn_initiale.y

	if tomber_du_ciel:
		await _chute_depuis_ciel(position_spawn_initiale.x)

	# Connecter le signal de sortie d'écran pour le repositionnement hors-caméra
	if rechute_hors_camera and notifier:
		if not notifier.screen_exited.is_connected(_on_ecran_sorti_combat):
			notifier.screen_exited.connect(_on_ecran_sorti_combat)

	_demarrer_combat_t100()

func _demarrer_combat_t100() -> void:
	if jouer_form_a_l_activation and possede_animation("form"):
		_jouer_anim_t100("form")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("form", 1.0))
	if est_actif() and not est_elimine:
		_boucle_t100_standard()

## Chute depuis le ciel vers la position (cible_x, _y_atterrissage) avec un tween EASE_IN.
func _chute_depuis_ciel(cible_x: float) -> void:
	vitesse_deplacement = 0.0
	velocity = Vector2.ZERO
	position = Vector2(cible_x, y_depart_ciel)
	if possede_animation("idle"):
		_jouer_anim_t100("idle")
	var tween := create_tween()
	tween.tween_property(self, "position:y", _y_atterrissage, duree_chute_sec) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	await tween.finished

## Signal screen_exited du VisibleOnScreenNotifier2D — déclenche un repositionnement en plein combat.
func _on_ecran_sorti_combat() -> void:
	if not boucle_t100_active or en_cycle_mort or _en_rechute or est_elimine:
		return
	_rechute_repositionnement()

## Interrompt la boucle de combat, téléporte le T-1000 à un X aléatoire dans l'écran
## en haut (y_depart_ciel), puis le fait retomber sur _y_atterrissage avant de relancer la boucle.
func _rechute_repositionnement() -> void:
	_annuler_attaque_courante()
	_en_rechute = true
	boucle_t100_active = false
	_arreter_deplacement()
	velocity = Vector2.ZERO
	_deplacement_y_actif = false
	_en_traversée_roll = false

	# Choisir un X aléatoire dans les limites visibles de la caméra
	var limites := _obtenir_limites_x_camera()
	var cible_x := randf_range(limites.x, limites.y)
	if phase_combat_2nd != 2:
		_y_atterrissage = position_spawn_initiale.y
	print("[T1000] Rechute repositionnement — X cible: %.1f, Y cible: %.1f" % [cible_x, _y_atterrissage])

	await _chute_depuis_ciel(cible_x)

	if not is_inside_tree() or est_elimine:
		_en_rechute = false
		return

	_en_rechute = false
	# Libérer le verrou de boucle avant de la relancer
	_boucle_t100_en_cours = false
	_boucle_t100_standard()

func _boucle_t100_standard() -> void:
	if _boucle_t100_en_cours or (phase_combat_2nd in [2, 4, 5]):
		return
	_boucle_t100_en_cours = true
	boucle_t100_active = true
	
	while est_actif() and not en_cycle_mort and not _en_rechute and not (phase_combat_2nd in [2, 4, 5]) and boucle_t100_active:
		await _attendre_fin_hit_si_besoin()
		if not est_actif() or en_cycle_mort or _en_rechute or (phase_combat_2nd in [2, 4, 5]) or not boucle_t100_active:
			break
			
		match _mode_deplacement_resolu:
			MODE_ROULADE_ECRAN:
				await _phase_roll_traversée()
			MODE_PROFONDEUR_Y:
				await _phase_foward_profondeur()
			_:
				await _phase_walk_profil()
		
		await _attendre_fin_hit_si_besoin()
		if not est_actif() or en_cycle_mort or _en_rechute or (phase_combat_2nd in [2, 4, 5]) or not boucle_t100_active:
			break
		
		await _phase_attaque()
		await _attendre_fin_hit_si_besoin()
		if not est_actif() or en_cycle_mort or _en_rechute or (phase_combat_2nd in [2, 4, 5]) or not boucle_t100_active:
			break
		
		if _mode_deplacement_resolu == MODE_MARCHE_PROFIL and randf() < chance_esquive_roll:
			await _esquive_t100()
	
	boucle_t100_active = false
	_deplacement_y_actif = false
	_en_traversée_roll = false
	_boucle_t100_en_cours = false

func _phase_walk_profil() -> void:
	_appliquer_direction_x()
	if possede_animation("walk"):
		_jouer_anim_t100("walk")
	elif possede_animation("idle"):
		_jouer_anim_t100("idle")
	vitesse_deplacement = vitesse_initiale
	_deplacement_y_actif = false
	var token := _token_attaque
	await _attendre_avec_annulation_attaque(interval_marche_sec, token)

func _phase_roll_traversée() -> void:
	var limites := _obtenir_limites_x_camera()
	var cible := limites.y if global_position.x < (limites.x + limites.y) * 0.5 else limites.x
	_cible_x_roll = cible
	_en_traversée_roll = true
	if possede_animation("roll"):
		_jouer_anim_t100("roll")
	else:
		_jouer_anim_t100("walk")
	vitesse_deplacement = vitesse_initiale * vitesse_roll_multiplicateur
	direction_deplacement = "gauche_vers_droite" if cible > global_position.x else "droite_vers_gauche"
	_deplacement_y_actif = false
	
	var timeout := 6.0
	var debut := Time.get_ticks_msec()
	var token := _token_attaque
	while est_actif() and not en_cycle_mort and _en_traversée_roll:
		if _attaque_est_annulee(token):
			break
		if abs(global_position.x - cible) <= 8.0:
			break
		if Time.get_ticks_msec() - debut > int(timeout * 1000.0):
			break
		await get_tree().process_frame
	
	_arreter_deplacement()
	velocity.x = 0.0
	_en_traversée_roll = false
	_cible_x_roll = NAN

func _phase_foward_profondeur() -> void:
	direction_mouvement_y *= -1
	_deplacement_y_actif = true
	vitesse_deplacement = vitesse_initiale
	direction_deplacement = "immobile"
	velocity.x = 0.0
	if possede_animation("foward"):
		_jouer_anim_t100("foward")
	elif possede_animation("walk"):
		_jouer_anim_t100("walk")
	var token := _token_attaque
	await _attendre_avec_annulation_attaque(interval_marche_sec, token)
	_deplacement_y_actif = false
	velocity.y = 0.0

func _appliquer_direction_x() -> void:
	direction_mouvement_x *= -1
	if direction_mouvement_x == 1:
		direction_deplacement = "gauche_vers_droite"
	else:
		direction_deplacement = "droite_vers_gauche"

func _annuler_attaque_courante() -> void:
	_token_attaque += 1
	en_attaque = false

func _attaque_est_annulee(token: int) -> bool:
	return _token_attaque != token or not est_actif() or en_cycle_mort or _en_hit

func _attendre_avec_annulation_attaque(duree_sec: float, token: int) -> void:
	var fin := Time.get_ticks_msec() + int(maxf(duree_sec, 0.0) * 1000.0)
	while Time.get_ticks_msec() < fin:
		if _attaque_est_annulee(token):
			return
		await get_tree().process_frame

func _attendre_fin_hit_si_besoin() -> void:
	while _en_hit and est_actif() and not en_cycle_mort:
		await get_tree().process_frame

func _attendre_fin_anim_ou_timer_annulable(duree_fallback: float, token: int) -> void:
	if anim_sprite and anim_sprite.sprite_frames:
		var current_anim := anim_sprite.animation
		if anim_sprite.sprite_frames.has_animation(current_anim):
			if not anim_sprite.sprite_frames.get_animation_loop(current_anim):
				var debut := Time.get_ticks_msec()
				var timeout_ms := int(maxf(duree_fallback, 0.05) * 1000.0)
				while is_inside_tree() and est_actif():
					if _attaque_est_annulee(token):
						return
					if not anim_sprite.is_playing():
						return
					if anim_sprite.animation != current_anim:
						return
					if Time.get_ticks_msec() - debut > timeout_ms:
						return
					await get_tree().process_frame
				return
	await _attendre_avec_annulation_attaque(duree_fallback, token)

func _attendre_frame_specifique_annulable(frame_cible: int, token: int, timeout_sec: float = 1.2) -> void:
	if anim_sprite == null:
		await _attendre_avec_annulation_attaque(0.2, token)
		return
	var debut := Time.get_ticks_msec()
	while is_inside_tree() and est_actif():
		if _attaque_est_annulee(token):
			return
		if anim_sprite.frame >= frame_cible:
			return
		if Time.get_ticks_msec() - debut > int(timeout_sec * 1000.0):
			return
		await get_tree().process_frame

func _reprendre_marche_apres_interruption() -> void:
	if not boucle_t100_active or en_cycle_mort or en_attaque or _en_hit:
		return
	vitesse_deplacement = vitesse_initiale
	match _mode_deplacement_resolu:
		MODE_ROULADE_ECRAN:
			if possede_animation("roll"):
				_jouer_anim_t100("roll")
			elif possede_animation("walk"):
				_jouer_anim_t100("walk")
		MODE_PROFONDEUR_Y:
			_deplacement_y_actif = true
			direction_deplacement = "immobile"
			if possede_animation("foward"):
				_jouer_anim_t100("foward")
			elif possede_animation("walk"):
				_jouer_anim_t100("walk")
		_:
			if possede_animation("walk"):
				_jouer_anim_t100("walk")
			elif possede_animation("idle"):
				_jouer_anim_t100("idle")

func _phase_attaque() -> void:
	_arreter_deplacement()
	velocity = Vector2.ZERO
	await _attaque_t100_aleatoire()

func _physics_process(_delta: float) -> void:
	if not est_elimine:
		z_index = 100 if _est_prioritaire_popup else int(clamp(global_position.y, 1.0, 90.0))
	
	if phase_combat_2nd == 2 or phase_combat_2nd == 4:
		position.x = X_CENTRE_PASSERELLE
		position.y = clampf(position.y, Y_FOND_PASSERELLE, Y_AVANT_PASSERELLE)
		return
	elif phase_combat_2nd == 5:
		return
	
	if not deja_active or est_elimine or en_attaque or not boucle_t100_active or _en_hit:
		return
	
	if _deplacement_y_actif and vitesse_deplacement > 0.0:
		velocity.y = float(direction_mouvement_y) * vitesse_deplacement
		global_position.y = clamp(global_position.y, limite_y_min_t100, limite_y_max_t100)
		if global_position.y <= limite_y_min_t100 or global_position.y >= limite_y_max_t100:
			direction_mouvement_y *= -1
		return
	
	if vitesse_deplacement <= 0.0:
		return
	
	match direction_deplacement:
		"droite_vers_gauche":
			velocity.x = -vitesse_deplacement
			if anim_sprite and anim_sprite.flip_h != inverser_visuel:
				anim_sprite.flip_h = inverser_visuel
			move_and_slide()
		"gauche_vers_droite":
			velocity.x = vitesse_deplacement
			if anim_sprite and anim_sprite.flip_h == inverser_visuel:
				anim_sprite.flip_h = not inverser_visuel
			move_and_slide()
		"immobile":
			velocity.x = 0.0
	
	if _mode_deplacement_resolu == MODE_MARCHE_PROFIL:
		_gerer_limites_camera()
	elif _en_traversée_roll and not is_nan(_cible_x_roll):
		if direction_deplacement == "gauche_vers_droite" and global_position.x >= _cible_x_roll:
			global_position.x = _cible_x_roll
			_en_traversée_roll = false
		elif direction_deplacement == "droite_vers_gauche" and global_position.x <= _cible_x_roll:
			global_position.x = _cible_x_roll
			_en_traversée_roll = false

func _gerer_limites_camera() -> void:
	var limites := _obtenir_limites_x_camera()
	if global_position.x <= limites.x and direction_deplacement == "droite_vers_gauche":
		direction_mouvement_x = 1
		direction_deplacement = "gauche_vers_droite"
	elif global_position.x >= limites.y and direction_deplacement == "gauche_vers_droite":
		direction_mouvement_x = -1
		direction_deplacement = "droite_vers_gauche"

func _construire_pool_attaques() -> Array[String]:
	var pool: Array[String] = []
	if attaque_gun and possede_animation("shoot") and possede_animation("aim"):
		pool.append("gun")
	if attaque_smash and possede_animation("smash"):
		pool.append("smash")
	if attaque_sweep and possede_animation("sweep"):
		pool.append("sweep")
	if attaque_split and possede_animation("split"):
		pool.append("split")
	if attaque_crack and possede_animation("crack"):
		pool.append("crack")
	return pool

func _attaque_t100_aleatoire() -> void:
	var attaques := _construire_pool_attaques()
	if attaques.is_empty():
		if possede_animation("idle"):
			_jouer_anim_t100("idle")
			await attendre(0.4)
		return
	
	var token := _token_attaque
	en_attaque = true
	var choix: String = attaques.pick_random()
	match choix:
		"gun":
			await _attaque_arme_a_feu(token)
		"smash", "sweep":
			await _attaque_coup_porte(choix, token)
		"split":
			await _attaque_split(token)
		"crack":
			await _attaque_crack(token)
	if _attaque_est_annulee(token):
		en_attaque = false
		return
	en_attaque = false
	await _attendre_avec_annulation_attaque(interval_attaque, token)

func _attaque_arme_a_feu(token: int) -> void:
	if possede_animation("idle"):
		_jouer_anim_t100("idle")
		await _attendre_avec_annulation_attaque(0.15, token)
	if _attaque_est_annulee(token):
		return
	if possede_animation("aim"):
		_jouer_anim_t100("aim")
		await _attendre_fin_anim_ou_timer_annulable(_obtenir_duree_animation("aim", 0.25), token)
	if _attaque_est_annulee(token) or not est_actif():
		return
	if possede_animation("shoot"):
		_jouer_anim_t100("shoot")
		await _attendre_frame_specifique_annulable(2, token)
		if not _attaque_est_annulee(token) and est_actif():
			GlobalSettings.infliger_degats_joueur(1)
		var duree_shoot := _obtenir_duree_animation("shoot", 0.35)
		await _attendre_avec_annulation_attaque(duree_shoot, token)

func _attaque_coup_porte(animation_coup: String, token: int) -> void:
	_jouer_anim_t100(animation_coup)
	await _attendre_avec_annulation_attaque(0.2, token)
	if _attaque_est_annulee(token):
		return
	var frame_impact := 2 if animation_coup == "smash" else 3
	await _attendre_frame_specifique_annulable(frame_impact, token)
	if not _attaque_est_annulee(token) and est_actif():
		GlobalSettings.infliger_degats_joueur(1)
		if animation_coup == "smash":
			_spawn_trace_melee_fixe(global_position, animation_coup)
	await _attendre_fin_anim_ou_timer_annulable(_obtenir_duree_animation(animation_coup, 0.8), token)

func _attaque_split(token: int) -> void:
	_jouer_anim_t100("split")
	await _attendre_frame_specifique_annulable(3, token)
	if not _attaque_est_annulee(token) and est_actif():
		GlobalSettings.infliger_degats_joueur(1)
	await _attendre_fin_anim_ou_timer_annulable(_obtenir_duree_animation("split", 1.0), token)

func _attaque_crack(token: int) -> void:
	_jouer_anim_t100("crack")
	await _attendre_frame_specifique_annulable(3, token)
	if not _attaque_est_annulee(token) and est_actif():
		GlobalSettings.infliger_degats_joueur(1)
	await _attendre_fin_anim_ou_timer_annulable(_obtenir_duree_animation("crack", 1.0), token)

func _spawn_trace_melee_fixe(_pos: Vector2, _anim: String) -> void:
	# TODO: trace temporaire fixe à l'écran (voir xflask.tscn — sans glissade)
	pass

func _attendre_frame_specifique(frame_cible: int) -> void:
	if anim_sprite == null:
		await attendre(0.2)
		return
	var timeout := 1.2
	var debut := Time.get_ticks_msec()
	while is_inside_tree() and est_actif():
		if anim_sprite.frame >= frame_cible:
			return
		if Time.get_ticks_msec() - debut > int(timeout * 1000.0):
			return
		await get_tree().process_frame

func _esquive_t100() -> void:
	if not possede_animation("roll"):
		return
	_jouer_anim_t100("roll")
	vitesse_deplacement = vitesse_initiale
	var duree := _obtenir_duree_animation("roll", 0.8)
	var debut := Time.get_ticks_msec()
	while est_actif() and Time.get_ticks_msec() - debut < int(duree * 1000.0):
		move_and_slide()
		await get_tree().process_frame
	_arreter_deplacement()

func subir_degats(quantite: int) -> void:
	_appliquer_degats_t100(quantite, false, false)

func subir_degats_missile(degats: int, _pos_impact: Vector2 = Vector2.ZERO) -> void:
	var est_special := GlobalSettings.dernier_tir_etait_special
	_appliquer_degats_t100(degats, true, est_special)

func _appliquer_degats_t100(quantite: int, est_missile: bool, est_special: bool = false) -> void:
	if est_elimine:
		return
	
	# --- CAS SÉQUENCE FINALE BOILER (Phase 5 : attente du tir alternatif / missile SPÉCIAL) ---
	if _en_attente_coup_de_grace or phase_combat_2nd == 5:
		if est_missile and est_special:
			_token_phase5 += 1 # Annule le timer 10s de timeout
			_en_attente_coup_de_grace = false
			print("[T1000] Coup de grâce réussi avec munition spéciale Shotgun ! Hasta la vista, Baby !")
			jouer_split_defeat()
		else:
			print("[T1000] Tir reçu en Phase V mais NON spécial (ou balle standard) -> Inefficace !")
		return
	
	if invincible or en_cycle_mort:
		return
	
	# --- CAS PHASE 2 OU PHASE 4 (Charge vers le joueur & Recul au tir) ---
	if phase_combat_2nd == 2 or phase_combat_2nd == 4:
		_appliquer_degats_phase_2(quantite, est_missile)
		degats_recus.emit(quantite, est_missile, est_special)
		return
	
	# Émettre signal pour la gauge (Phase 1, 3, etc.)
	degats_recus.emit(quantite, est_missile, est_special)
	if est_elimine or invincible or en_cycle_mort or (phase_combat_2nd in [2, 4, 5]):
		return
	
	# --- CAS STANDARD (Phase 1, 3, etc.) ---
	# Interrompre l'attaque en cours et les mouvements
	_annuler_attaque_courante()
	_token_impact += 1
	var token_impact_courant := _token_impact
	
	pv_actuels_t100 -= quantite
	
	# Si tir alternatif (missile) ou PV à 0, enchaîner immédiatement sur downed ou blown (sans blocage par mitraillage)
	if est_missile or pv_actuels_t100 <= 0:
		pv_actuels_t100 = 0
		_en_hit = false
		await _cycle_mort_regeneration()
		return
	
	if possede_animation("hit"):
		_en_hit = true
		_arreter_deplacement()
		velocity = Vector2.ZERO
		
		var anim_retour := "walk"
		if anim_sprite:
			var cur := str(anim_sprite.animation)
			if cur in ["walk", "foward", "roll"]:
				anim_retour = cur
		
		_jouer_anim_t100("hit")
		var duree_hit := _obtenir_duree_animation("hit", 0.25)
		
		# Attendre la fin du hit de manière sécurisée et annulable par un nouvel impact
		var fin := Time.get_ticks_msec() + int(maxf(duree_hit, 0.1) * 1000.0)
		while Time.get_ticks_msec() < fin:
			if _token_impact != token_impact_courant or est_elimine or en_cycle_mort or not is_inside_tree() or invincible:
				return
			await get_tree().process_frame
		
		if _token_impact != token_impact_courant or est_elimine or en_cycle_mort or not is_inside_tree() or invincible:
			return
		
		_en_hit = false
		
		vitesse_deplacement = vitesse_initiale
		if possede_animation(anim_retour):
			_jouer_anim_t100(anim_retour)
		elif possede_animation("walk"):
			_jouer_anim_t100("walk")
	else:
		if est_missile or pv_actuels_t100 <= 0:
			await _cycle_mort_regeneration()

func _appliquer_degats_phase_2(_quantite: int, est_missile: bool) -> void:
	if en_cycle_mort or (phase_combat_2nd != 2 and phase_combat_2nd != 4) or invincible:
		return
	
	# 1. Tuer le tween de charge immédiatement
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	if _tween_recul_p2 and _tween_recul_p2.is_valid():
		_tween_recul_p2.kill()
	
	_token_impact += 1
	var token_impact_courant := _token_impact
	_en_recul_p2 = true
	_en_hit = true
	velocity = Vector2.ZERO
	
	# 2. Calculer le recul et l'animation :
	# - Tir standard : recul 5px, animation 'hit'
	# - Tir alternatif (missile) : recul 10px, animation 'pushed'
	var distance_recul := 10.0 if est_missile else 5.0
	var anim_reaction := "pushed" if (est_missile and possede_animation("pushed")) else "hit"
	if not possede_animation(anim_reaction) and possede_animation("hit"):
		anim_reaction = "hit"
	
	var y_cible := maxf(Y_FOND_PASSERELLE, position.y - distance_recul)
	
	if possede_animation(anim_reaction):
		_jouer_anim_t100(anim_reaction)
	
	# 3. Tween de recul fluide (0.12s)
	_tween_recul_p2 = create_tween()
	_tween_recul_p2.tween_property(self, "position:y", y_cible, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var duree_anim := _obtenir_duree_animation(anim_reaction, 0.25)
	var duree_totale := maxf(0.15, duree_anim)
	
	var fin := Time.get_ticks_msec() + int(duree_totale * 1000.0)
	while Time.get_ticks_msec() < fin:
		if _token_impact != token_impact_courant or est_elimine or not is_inside_tree() or (phase_combat_2nd != 2 and phase_combat_2nd != 4) or en_cycle_mort or invincible:
			return
		await get_tree().process_frame
	
	if _token_impact != token_impact_courant or est_elimine or not is_inside_tree() or (phase_combat_2nd != 2 and phase_combat_2nd != 4) or en_cycle_mort or invincible:
		return
	
	_en_hit = false
	_en_recul_p2 = false
	
	# 4. Relancer la charge vers l'avant si toujours actif en phase 2 ou 4
	if (phase_combat_2nd == 2 or phase_combat_2nd == 4) and not en_cycle_mort and not invincible and est_actif():
		_lancer_charge_phase_2()

func _lancer_charge_phase_2() -> void:
	if (phase_combat_2nd != 2 and phase_combat_2nd != 4) or not est_actif() or en_cycle_mort or _en_recul_p2 or invincible:
		return
	
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	
	position.x = X_CENTRE_PASSERELLE
	position.y = clampf(position.y, Y_FOND_PASSERELLE, Y_AVANT_PASSERELLE)
	
	var distance_restante := maxf(0.0, Y_AVANT_PASSERELLE - position.y)
	if distance_restante <= 1.0:
		_gerer_arrivee_avant_plan_phase_2()
		return
	
	if possede_animation("foward"):
		_jouer_anim_t100("foward")
	elif possede_animation("walk"):
		_jouer_anim_t100("walk")
	
	# Étape 1 : Déplacement exclusif sur Y (charge vers 155.0 sans bouger en X et SANS attaquer)
	var duree := distance_restante / maxf(1.0, vitesse_charge_phase2)
	_tween_charge_p2 = create_tween()
	_tween_charge_p2.tween_property(self, "position:y", Y_AVANT_PASSERELLE, duree).set_trans(Tween.TRANS_LINEAR)
	_tween_charge_p2.finished.connect(func():
		if (phase_combat_2nd == 2 or phase_combat_2nd == 4) and est_actif() and not en_cycle_mort and not _en_recul_p2 and not invincible:
			position.x = X_CENTRE_PASSERELLE
			position.y = Y_AVANT_PASSERELLE
			_gerer_arrivee_avant_plan_phase_2()
	)

func _gerer_arrivee_avant_plan_phase_2() -> void:
	if (phase_combat_2nd != 2 and phase_combat_2nd != 4) or not est_actif() or en_cycle_mort or _en_recul_p2 or invincible:
		return
	
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	velocity = Vector2.ZERO
	vitesse_deplacement = 0.0
	position.x = X_CENTRE_PASSERELLE
	position.y = Y_AVANT_PASSERELLE
	
	# Étape 1 : Arrêt complet (idle) avant d'attaquer
	if possede_animation("idle"):
		_jouer_anim_t100("idle")
	
	# Pause nette d'arrêt complet (0.3s)
	await attendre(0.3)
	if (phase_combat_2nd != 2 and phase_combat_2nd != 4) or not est_actif() or en_cycle_mort or _en_recul_p2 or invincible:
		return
	
	# Étape 2 : Lancement des attaques aléatoires standards (premier type configuré)
	await _attaque_t100_aleatoire()
	
	if (phase_combat_2nd != 2 and phase_combat_2nd != 4) or not est_actif() or en_cycle_mort or _en_recul_p2 or invincible:
		return
	
	# Étape 3 : Arrêt complet post-attaque
	velocity = Vector2.ZERO
	if possede_animation("idle"):
		_jouer_anim_t100("idle")
	await attendre(0.3)
	
	if (phase_combat_2nd == 2 or phase_combat_2nd == 4) and est_actif() and not en_cycle_mort and not _en_recul_p2 and not invincible:
		_lancer_charge_phase_2()

func _cycle_mort_regeneration() -> void:
	if en_cycle_mort:
		return
	_annuler_attaque_courante()
	en_cycle_mort = true
	boucle_t100_active = false
	_arreter_deplacement()
	velocity = Vector2.ZERO
	
	# 2e bataille : animation 'blown' (chute + disparition) puis déduction jauge et rechute du ciel
	if utiliser_anim_blown_a_la_mort and possede_animation("blown"):
		_jouer_anim_t100("blown")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("blown", 1.2))
		
		# Émettre le signal vers la 2e jauge (déduit 5% par défaut)
		cycle_blown_termine.emit(perte_gauge_par_blown)
		
		# Rechute depuis le ciel à une position X aléatoire sur la passerelle
		await _rechute_repositionnement()
	elif possede_animation("downed"):
		_jouer_anim_t100("downed")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("downed", temps_downed_fallback_sec))
	else:
		# Legacy : die (chute) puis getup (relevé) si downed absent dans SpriteFrames
		if possede_animation("die"):
			_jouer_anim_t100("die")
			await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("die", temps_downed_fallback_sec))
		if possede_animation("getup"):
			_jouer_anim_t100("getup")
			await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("getup", temps_downed_fallback_sec))
	
	if not is_inside_tree():
		en_cycle_mort = false
		return
	
	pv_actuels_t100 = pv_regeneres
	en_cycle_mort = false
	
	if is_inside_tree() and deja_active and not est_elimine and not boucle_t100_active:
		# La boucle précédente peut encore être en await : libérer le verrou avant relance.
		_boucle_t100_en_cours = false
		_boucle_t100_standard()

func subir_elimination() -> void:
	_cycle_mort_regeneration()

func declencher_defaite() -> void:
	if est_elimine:
		return
	if animation_defaite == "split" or (utiliser_anim_blown_a_la_mort and possede_animation("split")):
		await jouer_split_defeat()
	else:
		await jouer_crack_defeat()

func jouer_crack_defeat() -> void:
	if est_elimine:
		return
	_annuler_attaque_courante()
	en_cycle_mort = true
	boucle_t100_active = false
	_arreter_deplacement()
	velocity = Vector2.ZERO
	
	# Jouer crack (1er boss)
	if possede_animation("crack"):
		_jouer_anim_t100("crack")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("crack", 1.0))
	
	# Masquer le T-1000 après destruction
	hide()
	
	# Utiliser le système ActorBase pour déverrouiller le stop
	if deverrouiller_stop_a_la_mort:
		_deverrouiller_stop_lie()
	
	# Fallback direct pour la caméra sur Stop1stFight
	var cam = get_viewport().get_camera_2d() if get_viewport() else null
	if cam and cam.has_method("deverrouiller_stop"):
		cam.deverrouiller_stop("Stop1stFight")
	
	# Devenir inactif et éliminé
	est_elimine = true
	en_cycle_mort = false
	deja_active = false
	collision_layer = 0
	collision_mask = 0

func jouer_split_defeat() -> void:
	if est_elimine:
		return
	_annuler_attaque_courante()
	en_cycle_mort = true
	boucle_t100_active = false
	_arreter_deplacement()
	velocity = Vector2.ZERO
	
	# 1. Jouer split complet
	if possede_animation("split"):
		_jouer_anim_t100("split")
		var duree_split := _obtenir_duree_animation("split", 2.0)
		await _attendre_fin_animation_ou_timer(duree_split)
	
	# 2. Maintenir / delay sur la dernière frame de split
	await attendre(1.0)
	
	# 3. Point de chute : array #3 du CollisionPolygon2D (x=160, y=95)
	var pt_poly_3 := _obtenir_point_poly_areaboundary(3)
	var cible_x := pt_poly_3.x if pt_poly_3 != Vector2.ZERO else 160.0
	var cible_y := global_position.y + 160.0

	# Animations de fond + arrêt pluie au début de la chute
	var scene_split := get_tree().current_scene if get_tree() else null
	# Arrêter toute la pluie balistique
	if scene_split:
		var btm := scene_split.find_child("BallisticTriggerMarker*", true, false)
		if btm and btm.has_method("arreter_pluie"):
			btm.arreter_pluie()
	# FoundryAnimationPlayer (frère dans foundry_fight.tscn)
	var foundry_anim := get_parent().get_node_or_null("FoundryAnimationPlayer") as AnimationPlayer
	if foundry_anim and foundry_anim.has_animation("foundry_move_up"):
		foundry_anim.play("foundry_move_up")
	# BackgroundAnimationPlayer (dans level8.tscn)
	if scene_split:
		var bg_anim := scene_split.find_child("BackgroundAnimationPlayer", true, false) as AnimationPlayer
		if bg_anim and bg_anim.has_animation("xfback_move_up"):
			bg_anim.play("xfback_move_up")

	# Chute vers le bas hors de la passerelle et hors écran
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position:x", cible_x, duree_chute_split_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position:y", cible_y, duree_chute_split_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	
	hide()
	
	# Désactiver et cacher la jauge du boss à sa mort définitive
	var scene = get_tree().current_scene if get_tree() else null
	var gauge_node = null
	if scene:
		gauge_node = scene.find_child("GaugeLife2ndT100*", true, false)
	if gauge_node == null and get_parent():
		gauge_node = get_parent().find_child("GaugeLife2ndT100*", true, false)
	if gauge_node and gauge_node.has_method("desactiver_et_cacher"):
		gauge_node.desactiver_et_cacher()

	# Déverrouiller le stop caméra
	if deverrouiller_stop_a_la_mort:
		_deverrouiller_stop_lie()
	
	var cam = get_viewport().get_camera_2d() if get_viewport() else null
	if cam and cam.has_method("deverrouiller_stop"):
		cam.deverrouiller_stop("Stop2ndFightStart")
	
	est_elimine = true
	en_cycle_mort = false
	deja_active = false
	collision_layer = 0
	collision_mask = 0

func mettre_en_pause_phase() -> void:
	print("[T1000] Mise en pause de la Phase 1 (Interlude XT100Big)")
	_annuler_attaque_courante()
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	if _tween_recul_p2 and _tween_recul_p2.is_valid():
		_tween_recul_p2.kill()
	boucle_t100_active = false
	_boucle_t100_en_cours = false
	_arreter_deplacement()
	velocity = Vector2.ZERO
	_deplacement_y_actif = false
	_en_traversée_roll = false
	hide()
	collision_layer = 0
	collision_mask = 0

func reprendre_seconde_phase() -> void:
	await demarrer_phase_2()

func demarrer_phase_2() -> void:
	print("[T1000] Démarrage de la Phase 2 (75% -> 50%) - Chute du ciel sur la passerelle (160, 33)")
	if est_elimine or not is_inside_tree():
		return
	
	phase_combat_2nd = 2
	collision_layer = 2
	collision_mask = 0
	_afficher_visuel()
	
	# Réinitialiser les états
	en_cycle_mort = false
	_en_rechute = false
	_en_hit = false
	_en_recul_p2 = false
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	if _tween_recul_p2 and _tween_recul_p2.is_valid():
		_tween_recul_p2.kill()
	
	# Chute du ciel vers le fond de la passerelle (160, 95)
	_y_atterrissage = Y_FOND_PASSERELLE
	await _chute_depuis_ciel(X_CENTRE_PASSERELLE)
	
	if is_inside_tree() and not est_elimine and phase_combat_2nd == 2:
		_lancer_charge_phase_2()

func conclure_phase_2() -> void:
	print("[T1000] Conclusion Phase 2 (Seuil 50% atteint) -> Animation 'blown'")
	phase_combat_2nd = 3
	_token_impact += 1
	invincible = true
	collision_layer = 0
	collision_mask = 0
	
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	if _tween_recul_p2 and _tween_recul_p2.is_valid():
		_tween_recul_p2.kill()
	
	_en_recul_p2 = false
	_en_hit = false
	en_cycle_mort = true
	boucle_t100_active = false
	velocity = Vector2.ZERO
	
	if possede_animation("blown"):
		_jouer_anim_t100("blown")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("blown", 1.2))
	elif possede_animation("downed"):
		_jouer_anim_t100("downed")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("downed", 1.5))
	
	en_cycle_mort = false

func demarrer_phase_3() -> void:
	print("[T1000] Démarrage de la Phase 3 (50% -> 25%) -> Reformation 'form'")
	if est_elimine or not is_inside_tree():
		return
	
	phase_combat_2nd = 3
	en_cycle_mort = false
	_en_rechute = false
	_en_hit = false
	_en_recul_p2 = false
	invincible = true
	collision_layer = 0
	collision_mask = 0
	_y_atterrissage = position_spawn_initiale.y
	position.y = _y_atterrissage
	_afficher_visuel()
	
	pv_actuels_t100 = pv_regeneres
	
	# Première apparition de Phase 3 : joue l'animation 'form'
	if possede_animation("form"):
		_jouer_anim_t100("form")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("form", 1.0))
	
	invincible = false
	collision_layer = 2
	
	if is_inside_tree() and not est_elimine:
		_boucle_t100_en_cours = false
		_boucle_t100_standard()

func demarrer_phase_4() -> void:
	print("[T1000] Démarrage de la Phase 4 (25% -> 0%) - Apparition à l'avant-plan avec 'form'")
	if est_elimine or not is_inside_tree():
		return
	
	phase_combat_2nd = 4
	en_cycle_mort = false
	_en_rechute = false
	_en_hit = false
	_en_recul_p2 = false
	_en_attente_coup_de_grace = false
	invincible = true
	collision_layer = 0
	collision_mask = 0
	
	# Placé à l'avant-plan (son point d'origine sur la passerelle)
	_y_atterrissage = position_spawn_initiale.y
	position = Vector2(X_CENTRE_PASSERELLE, _y_atterrissage)
	_afficher_visuel()
	
	pv_actuels_t100 = pv_regeneres
	
	# Première apparition de Phase 4 : joue l'animation 'form'
	if possede_animation("form"):
		_jouer_anim_t100("form")
		await _attendre_fin_animation_ou_timer(_obtenir_duree_animation("form", 1.0))
	
	invincible = false
	collision_layer = 2
	
	if is_inside_tree() and not est_elimine and phase_combat_2nd == 4:
		_lancer_charge_phase_2()

func declencher_sequence_finale_boiler() -> void:
	print("[T1000] Déclenchement de la séquence finale Boiler (0%)")
	if est_elimine:
		return
	
	phase_combat_2nd = 5
	_annuler_attaque_courante()
	if _tween_charge_p2 and _tween_charge_p2.is_valid():
		_tween_charge_p2.kill()
	if _tween_recul_p2 and _tween_recul_p2.is_valid():
		_tween_recul_p2.kill()
	
	_en_recul_p2 = false
	_en_hit = false
	en_cycle_mort = false
	boucle_t100_active = false
	_boucle_t100_en_cours = false
	velocity = Vector2.ZERO
	
	# Garder collision_layer = 2 pour recevoir le tir alternatif missile
	invincible = false
	collision_layer = 2
	collision_mask = 0
	
	# 1. Recul fluide vers l'arrière-scène près du boiler / cuve (160, 95)
	if possede_animation("pushed"):
		_jouer_anim_t100("pushed")
	elif possede_animation("hit"):
		_jouer_anim_t100("hit")
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:x", X_CENTRE_PASSERELLE, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", Y_FOND_PASSERELLE, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	
	velocity = Vector2.ZERO
	if possede_animation("idle"):
		_jouer_anim_t100("idle")
	
	# 2. En attente du coup de grâce (tir alternatif / missile SPÉCIAL) avec timeout de 10s
	_en_attente_coup_de_grace = true
	_token_phase5 += 1
	var token_p5 := _token_phase5
	print("[T1000] Immobilisé près de la cuve (160, 95) en attente du tir alternatif SPÉCIAL ! (Timer 10s lancé)")

	get_tree().create_timer(10.0, false).timeout.connect(func():
		if _token_phase5 == token_p5 and phase_combat_2nd == 5 and _en_attente_coup_de_grace and not est_elimine and is_inside_tree():
			print("[T1000] 10 secondes écoulées sans coup de grâce spécial ! Récupération 25% de jauge et retour en Phase IV !")
			_recuperer_et_retourner_phase_4()
	)

func _recuperer_et_retourner_phase_4() -> void:
	_en_attente_coup_de_grace = false
	# Rechercher la jauge pour restaurer 25%
	var gauge_node: Node = null
	var scene := get_tree().current_scene if get_tree() else null
	if scene:
		gauge_node = scene.find_child("GaugeLife2ndT100*", true, false)
	if gauge_node == null and is_inside_tree():
		gauge_node = get_tree().root.find_child("GaugeLife2ndT100*", true, false)
	if gauge_node == null:
		var p := get_parent()
		while p and gauge_node == null:
			gauge_node = p.find_child("GaugeLife2ndT100*", true, false)
			p = p.get_parent()
	
	if gauge_node and gauge_node.has_method("restaurer_gauge"):
		gauge_node.restaurer_gauge(25.0)
	else:
		# Fallback via signal
		cycle_blown_termine.emit(-25.0)
	
	await demarrer_phase_4()

func get_pv_actuels() -> int:
	return pv_actuels_t100

func get_pv_max() -> int:
	return pv_max_t100
