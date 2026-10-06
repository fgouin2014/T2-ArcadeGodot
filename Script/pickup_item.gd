class_name PickupItem
extends Area2D

## Type d'effet du pickup selon le catalogue PICKUPS.md
@export_enum(
		"Chargeurs (xpickup_01)",
		"Coolant (xpickup_03)",
		"Shield (xpickup_05)",
		"Nuke (xpickup_07)",
		"Gatling (xpickup_09)",
		"Inconnu (xpickup_11)",
		"Shotgun Shell (xpickup_12)",
		"Missiles (xpickup_14)",
		"CPU (xpickup_16)",
		"Plasma (xpickup_18)",
		"Credit (xpickup_21)",
		"Bombe (xpickup_24)",
		"Inconnu B (xpickup_25)",
		"Inconnu C (xpickup_26)",
		"Shotgun (xpickup_29)"
	) var type_pickup: String = "Missiles (xpickup_14)"

## Quantite associee (pour missiles ou credits ou points nuke)
@export var quantite: int = 1

## Points de score accordés au joueur lors de la collecte
@export var points_score: int = 150

## Duree en secondes pour les effets temporaires (Coolant 20s, Shield 20s)
@export var duree_effet_sec: float = 20.0

@export_group("Animation de Collecte")
## Durée en secondes du vol du pickup vers le HUD (plus grand = plus lent)
@export var duree_envol_sec: float = 1.25

@export_group("Activation")
## Si false, le pickup reste invisible et non collectable jusqu'à activation (stop ou code externe).
@export var actif_au_demarrage: bool = true

@export_group("Effet d'Apparition")
## Comportement physique / trajectoire du pickup lors de son apparition.
@export_enum("fixe", "tombe_au_sol", "tombe_hors_ecran", "bond_au_sol", "bond_hors_ecran") var effet_apparition: String = "fixe"

@export_group("Paramètres Balistiques")
## Ligne Y absolue où l'item doit se poser au sol (-1.0 = position éditeur / défaut 138px).
@export var hauteur_sol_y: float = 138.0
## Gravité / accélération de chute vers le bas (en px/s²).
@export var gravite: float = 500.0
## Vitesse initiale de chute (en px/s vers le bas). 0 = départ statique, >0 = déjà en mouvement à l'apparition.
@export var vitesse_chute_initiale_y: float = 0.0
## Impulsion verticale vers le haut pour les modes "bond_*" (en px/s).
@export var impulsion_bond_y: float = 140.0
## Écartement / impulsion horizontale aléatoire gauche/droite (en px/s).
@export var dispersion_x: float = 35.0
## Si coché, l'item effectue un petit rebond élastique quand il touche le sol.
@export var rebond_au_sol: bool = false
## Coefficient d'élasticité du rebond (0.35 = petit rebond amorti).
@export_range(0.0, 0.8) var elasticite_rebond: float = 0.35

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

# ─── DÉCLENCHEUR SUR ARRÊT CAMÉRA ────────────────────────────────────────────
@export_group("Déclencheur sur Arrêt Caméra")
## Sélecteur visuel de StopMarker dans l'Inspecteur Godot
@export var declencheur_stop: NodePath
## Nom ou identifiant optionnel du StopMarker (ex: "Stop1")
@export var nom_stop_declencheur: String = ""
## activer_quand_atteint = activation dès que le stop est atteint (défaut). activer_a_la_reprise = activation quand la caméra repart après le stop.
@export_enum("activer_quand_atteint", "activer_a_la_reprise") var mode_activation_stop: String = "activer_quand_atteint"
## Délai (sec) entre le déclenchement du stop et l'activation du pickup
@export var delai_activation_sec: float = 0.0

var _vitesse: Vector2 = Vector2.ZERO
var _en_mouvement: bool = false
var _mode_chute_active: String = "fixe"
var _nombre_rebonds: int = 0
var _pickup_active: bool = false
var _en_attente_activation: bool = false
var _camera_stop_declencheur: CameraStopDeclencheur = null
var _y_origine_sol: float = -1.0

# --- Motion Scale (configuré par BallisticTriggerMarker) ---
## Facteur de suivi caméra en X : 1.0 = fixe à l'écran, < 1.0 = dérive vers la gauche.
var _motion_scale: float = 1.0
var _camera_x_prev: float = 0.0
var _camera_motion_ref: Camera2D = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	_y_origine_sol = global_position.y

	var a_declencheur = CameraStopDeclencheur.est_configure(declencheur_stop, nom_stop_declencheur)
	if a_declencheur or not actif_au_demarrage:
		_desactiver_pickup()
		if a_declencheur:
			call_deferred("_connecter_declencheur_stop")
	else:
		_activer_pickup()

func _desactiver_pickup() -> void:
	_pickup_active = false
	_en_mouvement = false
	_vitesse = Vector2.ZERO
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _activer_pickup() -> void:
	if _pickup_active:
		return
	_pickup_active = true
	visible = true
	monitoring = true
	monitorable = true
	jouer_effet_apparition()

func _stop_declencheur_ignore_camera() -> bool:
	return _pickup_active or _en_attente_activation

func _connecter_declencheur_stop() -> void:
	if _camera_stop_declencheur == null:
		_camera_stop_declencheur = CameraStopDeclencheur.new()
		_camera_stop_declencheur.configure(
			self,
			declencheur_stop,
			nom_stop_declencheur,
			mode_activation_stop,
			_on_stop_declenche,
			_stop_declencheur_ignore_camera
		)
	_camera_stop_declencheur.connect_signals()

func _exit_tree() -> void:
	if _camera_stop_declencheur:
		_camera_stop_declencheur.deconnecter()
		_camera_stop_declencheur = null

func _on_stop_declenche() -> void:
	if _pickup_active or _en_attente_activation:
		return
	_en_attente_activation = true
	CameraStopDeclencheur.executer_avec_delai(self, delai_activation_sec, func():
		_en_attente_activation = false
		if not _pickup_active and is_inside_tree():
			_activer_pickup()
	)

func jouer_effet_apparition(type_effet: String = "") -> void:
	var effet = type_effet if type_effet != "" else effet_apparition
	_mode_chute_active = effet
	_nombre_rebonds = 0
	
	match effet:
		"fixe":
			_en_mouvement = false
			_vitesse = Vector2.ZERO
			
		"tombe_au_sol":
			_vitesse = Vector2(0.0, vitesse_chute_initiale_y)
			_en_mouvement = true
			
		"tombe_hors_ecran":
			_vitesse = Vector2(0.0, vitesse_chute_initiale_y)
			_en_mouvement = true
			
		"bond_au_sol":
			var dir_x = randf_range(-dispersion_x, dispersion_x)
			_vitesse = Vector2(dir_x, -impulsion_bond_y)
			_en_mouvement = true
			
		"bond_hors_ecran":
			var dir_x = randf_range(-dispersion_x * 1.2, dispersion_x * 1.2)
			_vitesse = Vector2(dir_x, -impulsion_bond_y * 1.1)
			_en_mouvement = true

func _physics_process(delta: float) -> void:
	if not _en_mouvement:
		return
	
	# Application de la gravité
	_vitesse.y += gravite * delta
	position += _vitesse * delta
	
	var est_enfant_camera = get_parent() is Camera2D
	
	# Gestion selon le mode
	match _mode_chute_active:
		"tombe_au_sol", "bond_au_sol":
			var y_sol_cible = hauteur_sol_y if hauteur_sol_y > 0.0 else 138.0
			var pos_y_actuelle = position.y if est_enfant_camera else global_position.y
			
			if pos_y_actuelle >= y_sol_cible:
				position.y -= (pos_y_actuelle - y_sol_cible)
				if rebond_au_sol and _nombre_rebonds < 2 and abs(_vitesse.y) > 20.0:
					_vitesse.y = -abs(_vitesse.y) * maxf(elasticite_rebond, 0.25)
					_vitesse.x *= 0.6
					_nombre_rebonds += 1
				else:
					_vitesse = Vector2.ZERO
					_en_mouvement = false
					
		"bond_hors_ecran":
			var y_sol_cible = hauteur_sol_y if hauteur_sol_y > 0.0 else 138.0
			var pos_y_actuelle = position.y if est_enfant_camera else global_position.y
			
			# 1 rebond au sol au point de chute avant de poursuivre la sortie hors écran
			if _nombre_rebonds == 0 and pos_y_actuelle >= y_sol_cible:
				position.y -= (pos_y_actuelle - y_sol_cible)
				var dir_x = randf_range(-dispersion_x * 1.2, dispersion_x * 1.2)
				_vitesse = Vector2(dir_x, -abs(_vitesse.y) * maxf(elasticite_rebond, 0.4))
				_nombre_rebonds += 1
			elif _nombre_rebonds > 0 and pos_y_actuelle >= 200.0:
				_en_mouvement = false
				queue_free()
				return

			# Sortie bord gauche : opportunité manquée (seulement si motion_scale < 1.0)
			if _motion_scale < 1.0 and position.x < -160.0:
				_en_mouvement = false
				queue_free()

		"tombe_hors_ecran":
			var pos_y_actuelle = position.y if est_enfant_camera else global_position.y
			# Seuil de sortie hors écran : au-delà du bas de l'écran (> 200px pour un écran de 176px)
			if pos_y_actuelle >= 200.0:
				_en_mouvement = false
				queue_free()
				return

			# Sortie bord gauche : opportunité manquée (seulement si motion_scale < 1.0)
			if _motion_scale < 1.0 and position.x < -160.0:
				_en_mouvement = false
				queue_free()

func _process(_delta: float) -> void:
	# Drift en X selon motion_scale — uniquement si < 1.0 et item actif en mouvement
	if _motion_scale >= 1.0 or not _pickup_active or not _en_mouvement:
		return
	if _camera_motion_ref == null:
		var vp := get_viewport()
		if vp:
			_camera_motion_ref = vp.get_camera_2d()
		if _camera_motion_ref == null:
			return
		_camera_x_prev = _camera_motion_ref.global_position.x
		return
	var cam_dx := _camera_motion_ref.global_position.x - _camera_x_prev
	_camera_x_prev = _camera_motion_ref.global_position.x
	if cam_dx != 0.0:
		position.x -= cam_dx * (1.0 - _motion_scale)

func subir_degats(_degats: int = 1) -> void:
	if not _pickup_active:
		return
	ramasser()

var _est_ramasse: bool = false

func ramasser() -> void:
	if not _pickup_active or _est_ramasse:
		return
	_est_ramasse = true
	
	# Arrêter toute physique de chute / rebond
	_en_mouvement = false
	_vitesse = Vector2.ZERO
	
	# Désactiver les collisions physiques pour ne plus le retoucher
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Déterminer la cible X en haut de l'écran selon le type de pickup :
	# Dans l'espace de la vue de jeu (288x176) :
	# - Missiles (haut-gauche) -> X ~ 20, Y ~ -25
	# - Crédits (haut-centre) -> X ~ 144, Y ~ -25
	# - Autres / Score (entre les deux) -> X ~ 75, Y ~ -25
	var nom_type = type_pickup.to_lower()
	var cible_local_x: float = 75.0
	
	if "missile" in nom_type or "14" in nom_type:
		cible_local_x = 20.0
	elif "credit" in nom_type or "21" in nom_type:
		cible_local_x = 144.0
	
	# Trouver la position caméra actuelle pour calculer la cible monde X / Y
	var cam_x: float = global_position.x
	var cam_y: float = 0.0
	var viewport = get_viewport()
	if viewport:
		var cam = viewport.get_camera_2d()
		if cam:
			cam_x = cam.global_position.x - 144.0 + cible_local_x
			cam_y = cam.global_position.y - 88.0 - 25.0
		else:
			cam_x = cible_local_x
			cam_y = -25.0
	else:
		cam_y = -25.0

	var pos_arrivee = Vector2(cam_x, cam_y)

	# Animation d'envol du pickup vers le haut (passage sous la lucarne / le panneau)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "global_position", pos_arrivee, duree_envol_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.5, 0.5), duree_envol_sec)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.1)

	# À l'arrivée en haut sous le HUD : déclencher l'effet flash/pulsation du HUD et libérer
	tw.finished.connect(func():
		GlobalSettings.pickup_collecte_anime.emit(null, Vector2.ZERO, type_pickup)
		queue_free()
	)

	# Ajouter les points au score
	GlobalSettings.ajouter_score(points_score)
	
	match type_pickup:
		"Chargeurs (xpickup_01)":
			# Recharge instantanement et completement la jauge d'energie de l'arme
			GlobalSettings.recharger_gunpower_complet()
			
		"Coolant (xpickup_03)":
			# Empeche temporairement l'arme de surchauffer pendant duree_effet_sec secondes
			GlobalSettings.activer_coolant(duree_effet_sec)
			
		"Shield (xpickup_05)":
			# Protege des tirs ennemis pendant duree_effet_sec secondes
			GlobalSettings.activer_bouclier(duree_effet_sec)
			
		"Nuke (xpickup_07)":
			# Explosion massive qui elimine tous les ennemis visibles a l'ecran + bonus points
			var bonus_points = 5000 if quantite <= 1 else quantite
			GlobalSettings.declencher_nuke(bonus_points)
			
		"Gatling (xpickup_09)":
			# TODO: activer arme temporaire Gatling
			pass
			
		"Inconnu (xpickup_11)":
			# TODO: effet a definir
			pass
			
		"Shotgun Shell (xpickup_12)":
			# Ajoute des munitions d'arme alternative
			GlobalSettings.ajouter_missiles(quantite)
			
		"Missiles (xpickup_14)":
			# Ajoute des missiles au stock
			GlobalSettings.ajouter_missiles(quantite)
			
		"CPU (xpickup_16)":
			# TODO: effet CPU a definir
			pass
			
		"Plasma (xpickup_18)":
			# TODO: activer boost de puissance Plasma (duree: duree_effet_sec)
			pass
			
		"Credit (xpickup_21)":
			# Ajoute un ou plusieurs credits
			GlobalSettings.ajouter_credits(quantite)
			
		"Bombe (xpickup_24)":
			# TODO: bombe dangereuse - blesse le joueur si tiree par le joueur
			pass
			
		"Inconnu B (xpickup_25)":
			# TODO: effet a definir
			pass
			
		"Inconnu C (xpickup_26)":
			# TODO: effet a definir
			pass
			
		"Shotgun (xpickup_29)":
			# Active l'arme spéciale Shotgun (Level 8) avec 3 tirs de substitution
			var qte_shotgun := quantite if quantite > 0 else 3
			GlobalSettings.activer_shotgun_special(qte_shotgun)
			
		_:
			# Detection automatique par nom si le dropdown n'est pas standard
			var n = name.to_lower()
			if "01" in n:
				GlobalSettings.recharger_gunpower_complet()
			elif "03" in n:
				GlobalSettings.activer_coolant(duree_effet_sec)
			elif "05" in n:
				GlobalSettings.activer_bouclier(duree_effet_sec)
			elif "07" in n:
				GlobalSettings.declencher_nuke(5000)
			elif "21" in n:
				GlobalSettings.ajouter_credits(quantite)
			elif "12" in n or "14" in n:
				GlobalSettings.ajouter_missiles(quantite)
			elif "29" in n:
				var qte_shotgun := quantite if quantite > 0 else 3
				GlobalSettings.activer_shotgun_special(qte_shotgun)

	print("[PICKUP] Ramasse : ", type_pickup, " (x", quantite, ")")
