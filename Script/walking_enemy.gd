class_name WalkingEnemy
extends ActorBase

@export var temps_entre_tirs: float = 3.0
@export var nombre_de_tirs: int = 8 # Nombre de tirs par rafale
@export var delai_avant_tir: float = 0.5 # Délai d'attente avant le premier tir / pause idle
@export var scene_projectile_lance: PackedScene

# --- SELECTION DE PICKUPS POUR ALLIES (XYJC ET XSARAH) ---
@export_enum(
	"aucun",
	"xpickup_29", "xpickup_17", "xpickup_18", "xpickup_21", 
	"xpickup_12", "xpickup_14", "xpickup_16", "xpickup_07", 
	"xpickup_09", "xpickup_11", "xpickup_01", "xpickup_03", 
	"xpickup_05", "xpickup_24"
) var objet_a_dropper: String = "xpickup_29"

# Champ interne (non-exporté sur la classe mère) alimenté par les sous-classes dérivées
var option_comportement: String = "marche_et_tir_profil"

var a_lance_projectile_ce_cycle: bool = false
var vitesse_initiale: float = 40.0

func _ready() -> void:
	super._ready()
	vitesse_initiale = vitesse_deplacement # Sauvegarde de la vitesse de base d'actor_base
	_initialiser_projectile_par_defaut()
	_ajuster_orientation_john_connor()
	if anim_sprite and not anim_sprite.frame_changed.is_connected(_on_frame_changed):
		anim_sprite.frame_changed.connect(_on_frame_changed)

func _ajuster_orientation_john_connor() -> void:
	var nom_minuscule = name.to_lower()
	if "xojc" in nom_minuscule:
		inverser_visuel = true
	elif "xyjc" in nom_minuscule:
		inverser_visuel = false

func _initialiser_projectile_par_defaut() -> void:
	if scene_projectile_lance == null:
		var nom_minuscule = name.to_lower()
		if "xethrow" in nom_minuscule or "ethrow" in nom_minuscule:
			scene_projectile_lance = load("res://aseprite/xengren.tscn")
		elif "xtech" in nom_minuscule or "tech" in nom_minuscule:
			scene_projectile_lance = load("res://aseprite/xflask.tscn")
		else:
			scene_projectile_lance = null

func _demarrer_deplacement(anim: String) -> void:
	vitesse_deplacement = vitesse_initiale
	jouer_animation(anim)

func _arreter_deplacement() -> void:
	vitesse_deplacement = 0.0

func activer_acteur() -> void:
	super.activer_acteur()
	print("[%s] Acteur activé -> Comportement: '%s', Vitesse: %.1f, Flip: %s" % [name, option_comportement, vitesse_deplacement, inverser_visuel])
	
	var nom_minuscule = name.to_lower()
	var est_arnold = ("xarnb" in nom_minuscule or "xarnm" in nom_minuscule or "xarns" in nom_minuscule)
	var est_swat = ("xswat" in nom_minuscule)
	
	# 1. ARNOLD
	if est_arnold:
		_boucle_arnold_marche_pause_tir8x()
		return

	# 2. XSWAT (Correction du code mort ici)
	if est_swat or "swat" in option_comportement:
		_boucle_xswat_attaques()
		return

	# 3. LANCEURS STATIONNAIRES
	if option_comportement == "stationnaire_lanceur" or (not possede_animation("walk") and not possede_animation("walk") and (possede_animation("throw") or possede_animation("xethrow"))):
		_boucle_tir_stationnaire()
		return

	# 4. ALLIÉS (xyjc / xsarah)
	var nom_minuscule_loc = name.to_lower()
	var est_allie = ("xyjc" in nom_minuscule_loc or "xsarah" in nom_minuscule_loc or option_comportement == "allié_drop_pickup")
	if est_allie:
		_sequence_allie_cinematique()
		return

	# 5. SÉQUENCES ENFWRD (Entrée de profondeur 1x walk_fwrd) vs BIGEND (Profil direct)
	var est_fwrd = (self is EnfwrdEnemy or self is MedfwrdEnemy or "fwrd" in nom_minuscule_loc or "fwrd" in scene_file_path.to_lower())
	if est_fwrd and possede_animation("walk_fwrd"):
		_sequence_fwrd_face()
		return

	if option_comportement in ["marche_stop_idle_shoot", "marche_idle_tir_face"]:
		_sequence_marche_stop_idle_shoot()
		return
	elif option_comportement == "lancer_grenade_1x_puis_marche" or possede_animation("xendrop"):
		_sequence_drop_puis_walk()
	elif possede_animation("jump") or possede_animation("xenjump") or option_comportement == "saut_obstacle":
		_sequence_jump()
	elif possede_animation("walk"):
		var anim_tir = "walk_shoot"
		if possede_animation("walk_shoot_profile"):
			anim_tir = "walk_shoot_profile"
		elif possede_animation("walk_shoot"):
			anim_tir = "walk_shoot"
		elif possede_animation("shoot_profile"):
			anim_tir = "shoot_profile"
		elif possede_animation("shoot"):
			anim_tir = "shoot"
		_demarrer_deplacement("walk")
		_boucle_alternance_tir("walk", anim_tir)

# --- BOUCLE XSWAT ---
func _boucle_xswat_attaques() -> void:
	while est_actif():
		var mode = option_comportement
		if mode == "swat_aleatoire":
			mode = ["swat_debout", "swat_roulade"].pick_random()
			
		if mode == "swat_roulade":
			if possede_animation("roll"):
				_demarrer_deplacement("roll")
			await attendre(temps_entre_tirs)
			if not est_actif(): break
			
			_arreter_deplacement()
			if possede_animation("idle_crouch"):
				jouer_animation("idle_crouch")
				await attendre(0.4)
			if not est_actif(): break
			
			if possede_animation("roll_attack"):
				a_lance_projectile_ce_cycle = false
				jouer_animation("roll_attack")
				_lancer_projectile()
				await _attendre_fin_animation_ou_timer(1.0)
		else:
			if possede_animation("walk"):
				_demarrer_deplacement("walk")
			await attendre(temps_entre_tirs)
			if not est_actif(): break
			
			_arreter_deplacement()
			if possede_animation("idle_stand"):
				jouer_animation("idle_stand")
				await attendre(0.4)
			if not est_actif(): break
			
			if possede_animation("stand_attack"):
				a_lance_projectile_ce_cycle = false
				jouer_animation("stand_attack")
				_lancer_projectile()
				await _attendre_fin_animation_ou_timer(1.0)

# --- BOUCLE ARNOLD ---
func _boucle_arnold_marche_pause_tir8x() -> void:
	var premier_cycle := true
	while est_actif():
		# 1. Marche
		_demarrer_deplacement("walk")
		var duree_marche = delai_avant_tir if premier_cycle else temps_entre_tirs
		premier_cycle = false
		if duree_marche > 0.0:
			await attendre(duree_marche)
		if not est_actif(): break
		
		# 2. Pause Idle
		_arreter_deplacement()
		if possede_animation("idle"):
			jouer_animation("idle")
			if delai_avant_tir > 0.0:
				await attendre(delai_avant_tir)
		if not est_actif(): break
		
		# 3. Salve de tirs (8x)
		var anim_tir = "shoot" if possede_animation("shoot") else ("throw" if possede_animation("throw") else "walk_shoot")
		if possede_animation(anim_tir):
			jouer_animation(anim_tir)
			for i in range(nombre_de_tirs):
				if not est_actif(): break
				_lancer_ou_dropper_objet()
				await attendre(0.18)
		
		if not est_actif(): break

func _sequence_drop_puis_walk() -> void:
	_arreter_deplacement()
	var anim_drop = "drop" if possede_animation("drop") else "xendrop"
	jouer_animation(anim_drop)
	_lancer_ou_dropper_objet()
	await _attendre_fin_animation_ou_timer(1.2)
	
	match option_comportement:
		"marche_stop_idle_shoot", "marche_idle_tir_face":
			if possede_animation("idle"):
				jouer_animation("idle")
			await attendre(1.0)
			var anim_marche = "walk_fwrd" if possede_animation("walk_fwrd") else "walk"
			_boucle_alternance_tir(anim_marche, "shoot")
		_:
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "walk_shoot" if possede_animation("walk_shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "shoot")
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)

func _sequence_allie_cinematique() -> void:
	if possede_animation("walk"):
		_demarrer_deplacement("walk")
		await attendre(temps_entre_tirs)
	if not est_actif(): return

	_arreter_deplacement()
	if possede_animation("scan"):
		jouer_animation("scan")
		await _attendre_fin_animation_ou_timer(0.8)
	if not est_actif(): return

	if possede_animation("take"):
		jouer_animation("take")
		await _attendre_fin_animation_ou_timer(1.0)
	if not est_actif(): return

	if possede_animation("walk"):
		_demarrer_deplacement("walk")
		await attendre(1.5)
	if not est_actif(): return

	_arreter_deplacement()
	if possede_animation("drop") and objet_a_dropper != "aucun":
		jouer_animation("drop")
		_dropper_pickup_allie()
		await _attendre_fin_animation_ou_timer(1.0)

	if possede_animation("walk"):
		_demarrer_deplacement("walk")

func _dropper_pickup_allie() -> void:
	if objet_a_dropper == "aucun":
		return

	var path_pickup = "res://tsj/" + objet_a_dropper + ".png"
	if not ResourceLoader.exists(path_pickup):
		print("[ALLIÉ DROP] Texture introuvable : ", path_pickup)
		return

	var noeud_pickup = Area2D.new()
	noeud_pickup.name = "Pickup_" + objet_a_dropper

	var spr = Sprite2D.new()
	spr.texture = load(path_pickup)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	noeud_pickup.add_child(spr)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	noeud_pickup.add_child(col)

	var notifier_pickup = VisibleOnScreenNotifier2D.new()
	notifier_pickup.screen_exited.connect(func():
		if is_instance_valid(noeud_pickup):
			noeud_pickup.queue_free()
	)
	noeud_pickup.add_child(notifier_pickup)

	noeud_pickup.global_position = global_position + Vector2(0, 20.0)
	get_parent().add_child(noeud_pickup)

func _lancer_ou_dropper_objet() -> void:
	var nom_minuscule = name.to_lower()
	if "xyjc" in nom_minuscule or "xsarah" in nom_minuscule or option_comportement == "allié_drop_pickup":
		_dropper_pickup_allie()
	else:
		_lancer_projectile()

func _sequence_jump() -> void:
	_arreter_deplacement()
	var anim_jump = "jump" if possede_animation("jump") else "xenjump"
	jouer_animation(anim_jump)
	await _attendre_fin_animation_ou_timer(1.2)
	
	match option_comportement:
		"marche_stop_idle_shoot", "marche_idle_tir_face":
			if possede_animation("idle"):
				jouer_animation("idle")
			await attendre(1.0)
			var anim_marche = "walk_fwrd" if possede_animation("walk_fwrd") else "walk"
			_boucle_alternance_tir(anim_marche, "shoot")
		_:
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "walk_shoot" if possede_animation("walk_shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "shoot")
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)

func _sequence_fwrd_face() -> void:
	# 1. Animation de marche de face progressive (exécutée 1 passe complète selon la variante d'acteur)
	_arreter_deplacement()
	var anim_entree = "walk_fwrd" if possede_animation("walk_fwrd") else "walk_front"
	print("[%s] Séquence entrée FWRD -> Animation: '%s'" % [name, anim_entree])
	jouer_animation(anim_entree)
	
	# Attente exacte de la durée complète de la passe (5.0s pour xbigend [40 frames], 4.75s pour xmedend [38 frames])
	await _attendre_fin_passation_animation(anim_entree, 2.0)
	print("[%s] Fin entrée FWRD -> Transition vers comportement: '%s'" % [name, option_comportement])
	
	# 2. Une fois arrivé à destination sur son sol (Sol 1 ou Sol 2), passer à l'action/marche d'option
	match option_comportement:
		"lancer_grenade_1x_puis_marche":
			if possede_animation("throw") or possede_animation("xethrow"):
				a_lance_projectile_ce_cycle = false
				jouer_animation("throw" if possede_animation("throw") else "xethrow")
				_lancer_projectile()
				await _attendre_fin_animation_ou_timer(1.2)
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "walk_shoot" if possede_animation("walk_shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "shoot")
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)
				
		"marche_stop_idle_shoot":
			_sequence_marche_stop_idle_shoot()

		"marche_et_tir_profil":
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "walk_shoot_profile" if possede_animation("walk_shoot_profile") else ("walk_shoot" if possede_animation("walk_shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "shoot"))
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)

		"marche_profil_tir_face":
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "shoot" if possede_animation("shoot") else "walk_shoot"
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)
				
		"marche_et_tir_en_marchant":
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "walk_shoot_profile" if possede_animation("walk_shoot_profile") else ("walk_shoot" if possede_animation("walk_shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "shoot"))
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)

		"stationnaire_lanceur":
			_boucle_tir_stationnaire()

		"marche_tir_face", "marche_idle_tir_face":
			while est_actif():
				var anim_pas_face = "walk_fwrd" if possede_animation("walk_fwrd") else "walk_front"
				jouer_animation(anim_pas_face)
				await _attendre_fin_passation_animation(anim_pas_face, 2.0)
				if not est_actif(): break
				
				_arreter_deplacement()
				if possede_animation("idle"):
					jouer_animation("idle")
					await attendre(0.3)
				if not est_actif(): break
				
				if possede_animation("shoot"):
					jouer_animation("shoot")
					for i in range(nombre_de_tirs):
						if not est_actif(): break
						_lancer_ou_dropper_objet()
						await attendre(0.18)
				if not est_actif(): break
				await attendre(temps_entre_tirs)
				
		"saut_obstacle":
			if possede_animation("jump") or possede_animation("xenjump"):
				jouer_animation("jump" if possede_animation("jump") else "xenjump")
				await _attendre_fin_animation_ou_timer(1.2)
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, "walk_shoot" if possede_animation("walk_shoot") else "shoot_profile")

		_:
			var anim_marche = "walk" if possede_animation("walk") else "walk"
			var anim_tir = "walk_shoot" if possede_animation("walk_shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "shoot")
			_demarrer_deplacement(anim_marche)
			_boucle_alternance_tir(anim_marche, anim_tir)

func _boucle_tir_stationnaire() -> void:
	_arreter_deplacement()
	var anim_tir = "shoot" if possede_animation("shoot") else ("throw" if possede_animation("throw") else "xethrow")
	while est_actif():
		await attendre(temps_entre_tirs)
		if not est_actif(): break
		a_lance_projectile_ce_cycle = false
		jouer_animation(anim_tir)
		await _attendre_fin_animation_ou_timer(1.2)

func _on_frame_changed() -> void:
	if anim_sprite:
		var anim_nom = str(anim_sprite.animation)
		if "shoot" in anim_nom or "attack" in anim_nom or "throw" in anim_nom:
			if anim_sprite.frame == 2 and not a_lance_projectile_ce_cycle:
				a_lance_projectile_ce_cycle = true
				_lancer_ou_dropper_objet()

func _lancer_projectile() -> void:
	if scene_projectile_lance == null:
		_initialiser_projectile_par_defaut()
		
	if scene_projectile_lance:
		var proj = scene_projectile_lance.instantiate()
		get_parent().add_child(proj)
		
		var pos_spawn = global_position
		var dir_proj = Vector2(-0.3, 1.0)
		
		if "direction_tir" in proj and proj.direction_tir != Vector2.ZERO:
			dir_proj = proj.direction_tir
		
		if direction_deplacement == "gauche_vers_droite":
			if dir_proj.x < 0:
				dir_proj.x = -dir_proj.x
		elif direction_deplacement == "droite_vers_gauche":
			if dir_proj.x > 0:
				dir_proj.x = -dir_proj.x
		
		if proj.has_method("initialiser_lancer"):
			var nom_minuscule = name.to_lower()
			if "ethrow" in nom_minuscule or option_comportement == "stationnaire_lanceur":
				var cible_centre_y = Vector2(pos_spawn.x + (dir_proj.x * 120.0), 87.5)
				proj.initialiser_lancer(pos_spawn, cible_centre_y)
			else:
				proj.initialiser_lancer(pos_spawn, dir_proj)
		elif proj.has_method("initialiser_tir"):
			# Distinguo tirs horizontaux droits devant (walk_shoot_profile ou xmedend) vs tirs orientes camera (xbigend walk_shoot)
			var cur_anim = str(anim_sprite.animation) if anim_sprite else ""
			var est_xmedend = ("medend" in name.to_lower() or "medfwrd" in name.to_lower())
			if cur_anim == "walk_shoot_profile" or (est_xmedend and cur_anim == "walk_shoot"):
				var sens_x = 1.0 if direction_deplacement == "gauche_vers_droite" else -1.0
				var cible_devant = pos_spawn + Vector2(sens_x * 300.0, 0.0)
				proj.initialiser_tir(pos_spawn, cible_devant, false)
			else:
				# Pour xbigend (walk_shoot) et tirs standards de profil vers le joueur
				var cible_joueur = pos_spawn + Vector2(dir_proj.x * 200.0, 150.0)
				proj.initialiser_tir(pos_spawn, cible_joueur, false)
		else:
			proj.global_position = pos_spawn

func _boucle_alternance_tir(anim_walk: String, anim_attack: String) -> void:
	var est_tir_continu = (option_comportement == "marche_et_tir_en_marchant")
	var anim_active = anim_attack if (est_tir_continu and possede_animation(anim_attack)) else anim_walk
	print("[%s] Démarrage boucle alternance -> Walk: '%s', Attack: '%s', Continu: %s" % [name, anim_walk, anim_attack, est_tir_continu])
	
	while est_actif():
		_demarrer_deplacement(anim_active)
		print("[%s] Phase MARCHE -> Anim: '%s' (Durée: %.2fs)" % [name, anim_active, temps_entre_tirs])
		await attendre(temps_entre_tirs)
		if not est_actif(): break
		
		if possede_animation(anim_attack):
			var garde_marche = est_tir_continu or ("walk_shoot" in anim_attack) or ("walk_shoot_profile" in anim_attack)
			if not garde_marche:
				_arreter_deplacement()
			
			a_lance_projectile_ce_cycle = false
			print("[%s] Phase TIR -> Anim: '%s' (Salves: %d)" % [name, anim_attack, nombre_de_tirs])
			jouer_animation(anim_attack)
			
			for i in range(nombre_de_tirs):
				if not est_actif(): break
				_lancer_ou_dropper_objet()
				await attendre(0.18)
			
			if not est_actif(): break
			if not garde_marche:
				await _attendre_fin_animation_ou_timer(0.5)
			
			if not est_actif(): break
			_demarrer_deplacement(anim_active)

func _attendre_fin_passation_animation(nom_anim: String, duree_fallback: float = 1.0) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(nom_anim):
		var count = anim_sprite.sprite_frames.get_frame_count(nom_anim)
		var speed = anim_sprite.sprite_frames.get_animation_speed(nom_anim)
		if count > 0 and speed > 0.0:
			var duree_passe = float(count) / speed
			await attendre(duree_passe)
			return
	await attendre(duree_fallback)

func _attendre_fin_animation_ou_timer(duree_fallback: float) -> void:
	if anim_sprite and anim_sprite.sprite_frames:
		var current_anim = anim_sprite.animation
		if anim_sprite.sprite_frames.has_animation(current_anim):
			if not anim_sprite.sprite_frames.get_animation_loop(current_anim):
				await anim_sprite.animation_finished
				return
	await attendre(duree_fallback)

func _sequence_marche_stop_idle_shoot() -> void:
	# 1. Tir initial immédiat lors de l'arrivée sur le sol (Idle -> Tir)
	_arreter_deplacement()
	if possede_animation("idle"):
		jouer_animation("idle")
		await attendre(delai_avant_tir)
	if est_actif():
		var anim_tir_init = "shoot" if possede_animation("shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "walk_shoot")
		if possede_animation(anim_tir_init):
			a_lance_projectile_ce_cycle = false
			jouer_animation(anim_tir_init)
			for i in range(nombre_de_tirs):
				if not est_actif(): break
				_lancer_ou_dropper_objet()
				await attendre(0.18)
			await _attendre_fin_animation_ou_timer(0.4)

	# 2. Boucle continue : Marche -> Stop -> Idle -> Tir
	while est_actif():
		_demarrer_deplacement("walk")
		await attendre(temps_entre_tirs)
		if not est_actif(): break
		
		_arreter_deplacement()
		if possede_animation("idle"):
			jouer_animation("idle")
			await attendre(delai_avant_tir)
		if not est_actif(): break
		
		var anim_tir = "shoot" if possede_animation("shoot") else ("shoot_profile" if possede_animation("shoot_profile") else "walk_shoot")
		if possede_animation(anim_tir):
			a_lance_projectile_ce_cycle = false
			jouer_animation(anim_tir)
			for i in range(nombre_de_tirs):
				if not est_actif(): break
				_lancer_ou_dropper_objet()
				await attendre(0.18)
			await _attendre_fin_animation_ou_timer(0.4)
		
		if not est_actif(): break
		await attendre(0.2)
