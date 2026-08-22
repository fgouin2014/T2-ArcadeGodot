extends Camera2D

# --- Paramètres modifiables dans l'Inspecteur ---
@export var vitesse_auto : float = 50.0   
@export var delai_intro_secondes : float = 3.0 # Délai au démarrage du niveau avant d'activer le défilement
@export var temps_pause_stop_secondes : float = 4.0 # Durée d'arrêt sur chaque Marker2D 'Stop'
@export_enum("Bord_Gauche", "Centre_Viseur", "Bord_Droit") var alignement_stop : String = "Bord_Gauche"
@export var verrouillee : bool = true # Inactif pendant l intro
@export var mode_perpetuel : bool = false # Si true (ex: stage3/xroad), boucle le parallax à l'infini
@export var largeur_boucle_parallax : float = 0.0
@export var cadencement_tir_cooldown : float = 0.10
@export var echelle_viseur : Vector2 = Vector2(1.0, 1.0)
@export var mode_joystick_actif : bool = false # Si true, visée via Joystick DX / Gamepad

# --- CHARGEMENT DU NOUVEAU VISEUR BLEU (.tscn) ---
@export var scene_viseur_bleu : PackedScene = preload("res://maps/Reticule.tscn") # <-- Remplace par le vrai chemin de ta scène .tscn !
var instance_viseur_bleu : Node2D = null

# --- Variables internes ---
var tir_maintenu : bool = false
var cooldown_tir_restant : float = 0.0
var position_visee_monde : Vector2 = Vector2.ZERO
var position_visee_ecran : Vector2 = Vector2.ZERO # Coordonnées Écran relatives centrées
var temps_ecoule : float = 0.0 
var largeur_lucarne : float = 288.0 
var hauteur_lucarne : float = 176.0
var boss_vaincu : bool = false
var en_pause_sur_stop : bool = false

# Liste des positions et paramètres des Marker2D nommés "Stop"
var liste_stops_data : Array = []
var canvas_viseur_jeu: CanvasLayer = null

# Référence cachée au noeud VirtualJoystickDX (cherché une seule fois)
var _vjoy: Node = null

var scene_projectile : PackedScene = preload("res://projectile.tscn")


func _ready() -> void:
	if not is_inside_tree(): return
	position_smoothing_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	var demi_ecran = largeur_lucarne / 2.0
	position.x = limit_left + demi_ecran
	temps_ecoule = 0.0
	verrouillee = true

	# Instanciation de la scène du nouveau viseur bleu
	_creer_nouveau_viseur()
	position_visee_monde = get_global_mouse_position()
	tir_maintenu = false
	
	call_deferred("_rechercher_marqueurs_stop")

	if mode_perpetuel and largeur_boucle_parallax > 0.0:
		configurer_parallax_looping()

	if delai_intro_secondes > 0.0:
		get_tree().create_timer(delai_intro_secondes).timeout.connect(func():
			if not boss_vaincu and not en_pause_sur_stop:
				verrouillee = false
				print("[CAMÉRA] Intro terminée ! Début du scroll auto.")
		)
	else:
		verrouillee = false

	# Cache la référence au joystick virtuel (une seule fois, pas à chaque frame)
	call_deferred("_chercher_vjoy")


func _chercher_vjoy() -> void:
	_vjoy = get_tree().root.find_child("VirtualJoystickDX", true, false)
	if _vjoy == null:
		# Fallback: chercher n'importe quel Control avec get_value()
		for child in get_tree().root.find_children("Virtual*", "Control", true, false):
			if child.has_method("get_value"):
				_vjoy = child
				break
	if _vjoy:
		print("[CAMÉRA] VirtualJoystickDX trouvé : ", _vjoy.name)
	else:
		print("[CAMÉRA] AVERTISSEMENT : VirtualJoystickDX introuvable!")


func _creer_nouveau_viseur() -> void:
	if scene_viseur_bleu == null:
		scene_viseur_bleu = preload("res://maps/Reticule.tscn")
	if scene_viseur_bleu:
		canvas_viseur_jeu = CanvasLayer.new()
		canvas_viseur_jeu.name = "CanvasViseurJeu"
		canvas_viseur_jeu.layer = 120
		add_child(canvas_viseur_jeu)
		
		instance_viseur_bleu = scene_viseur_bleu.instantiate() as Node2D
		if instance_viseur_bleu:
			canvas_viseur_jeu.add_child(instance_viseur_bleu)
			_actualiser_position_viseur()



func _actualiser_position_viseur() -> void:
	if instance_viseur_bleu == null:
		return

	if get_tree().paused:
		instance_viseur_bleu.hide()
		return
	else:
		instance_viseur_bleu.show()

	# --- 1. MODE JOYSTICK / GAMEPAD ---
	var vp = get_viewport()
	if mode_joystick_actif:
		var centre_hud = Vector2.ZERO
		if vp:
			centre_hud = Vector2(vp.size) / 2.0
		instance_viseur_bleu.position = centre_hud + position_visee_ecran

		# Position Monde pour les projectiles
		position_visee_monde = get_screen_center_position() + position_visee_ecran
		return
		
	# --- 2. MODE SOURIS / TACTILE DIRECT ---
	if vp:
		# 1. Cible dans le Monde 2D pour les projectiles
		position_visee_monde = get_global_mouse_position()
		
		# 2. Position Écran exacte sur le CanvasLayer (fixe, 0 drift)
		instance_viseur_bleu.position = vp.get_mouse_position()
	else:
		position_visee_monde = get_global_mouse_position()
		instance_viseur_bleu.global_position = position_visee_monde


func _rechercher_marqueurs_stop() -> void:
	liste_stops_data.clear()
	var root_target = get_parent()
	if root_target == null: return
	
	var pos_min_autorisee = position.x + 10.0
	
	var marqueurs = root_target.find_children("*Stop*", "Marker2D", true, false)
	for m in marqueurs:
		if m is Marker2D:
			var px = m.global_position.x
			if px > pos_min_autorisee:
				var align_val = alignement_stop
				if "alignement" in m and str(m.alignement) != "Utiliser_Defaut_Camera":
					align_val = str(m.alignement)
				elif m.has_meta("alignement") and str(m.get_meta("alignement")) != "Utiliser_Defaut_Camera":
					align_val = str(m.get_meta("alignement"))
				
				var pause_val = temps_pause_stop_secondes
				if "temps_pause" in m and float(m.temps_pause) >= 0.0:
					pause_val = float(m.temps_pause)
				elif m.has_meta("temps_pause") and float(m.get_meta("temps_pause")) >= 0.0:
					pause_val = float(m.get_meta("temps_pause"))
				
				liste_stops_data.append({
					"x": px,
					"node": m,
					"alignement": align_val,
					"temps_pause": pause_val
				})
			
	liste_stops_data.sort_custom(func(a, b): return a["x"] < b["x"])
	print("[CAMÉRA] Marqueurs Stop détectés : ", liste_stops_data)


func configurer_parallax_looping() -> void:
	if largeur_boucle_parallax <= 0.0:
		return
	var root_target = get_parent()
	if root_target:
		_appliquer_motion_mirroring(root_target)


func _appliquer_motion_mirroring(node: Node) -> void:
	for child in node.get_children():
		if child is ParallaxLayer:
			(child as ParallaxLayer).motion_mirroring = Vector2(largeur_boucle_parallax, 0)
		_appliquer_motion_mirroring(child)


func bloquer_camera() -> void: verrouillee = true
func debloquer_camera() -> void: verrouillee = false
func stopper_scroll_boss_defait() -> void:
	boss_vaincu = true
	verrouillee = true


func tirer_projectile(cible_monde: Vector2, mode_missile: bool = false) -> void:
	if scene_projectile == null or cooldown_tir_restant > 0.0:
		return
		
	cooldown_tir_restant = cadencement_tir_cooldown
	var centre_ecran = get_screen_center_position()
	var depart_canon_bas_gauche = centre_ecran + Vector2(-largeur_lucarne / 2.0, hauteur_lucarne / 2.0)
	
	var proj = scene_projectile.instantiate()
	get_parent().add_child(proj)
	
	if proj.has_method("initialiser_tir"):
		proj.initialiser_tir(depart_canon_bas_gauche, cible_monde, mode_missile)
	else:
		proj.position = depart_canon_bas_gauche


func _unhandled_input(event: InputEvent) -> void:
	# NOTE : la position du réticule est mise à jour chaque frame dans _physics_process.
	# Ici on gère uniquement les événements de TIR.

	if event is InputEventMouseButton:
		if not mode_joystick_actif:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					tir_maintenu = true
					tirer_projectile(position_visee_monde, false)
				else:
					tir_maintenu = false
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				tirer_projectile(position_visee_monde, true)

	elif event is InputEventScreenTouch:
		if mode_joystick_actif:
			# En mode joystick, le touch contrôle le joystick virtuel (pas le réticule)
			get_viewport().set_input_as_handled()
			return
		if event.pressed:
			tir_maintenu = true
			tirer_projectile(position_visee_monde)
		else:
			tir_maintenu = false

	elif event is InputEventScreenDrag:
		if mode_joystick_actif:
			get_viewport().set_input_as_handled()
			return


@export var gun_power_max: float = 100.0
@export var gun_power_actuel: float = 100.0
@export var vitesse_drain_gunpower: float = 5.0 
@export var vitesse_recharge_gunpower: float = 15.0 


func _physics_process(delta: float) -> void:
	if not is_inside_tree(): return
	
	temps_ecoule += delta
	if cooldown_tir_restant > 0.0:
		cooldown_tir_restant -= delta

	# --- GESTION DE LA SURCHAUFFE DU CANON (GUNPOWER) ---
	if tir_maintenu:
		gun_power_actuel = max(0.0, gun_power_actuel - vitesse_drain_gunpower * delta)
	else:
		gun_power_actuel = min(gun_power_max, gun_power_actuel + vitesse_recharge_gunpower * delta)

	var ratio_power = clamp(gun_power_actuel / gun_power_max, 0.0, 1.0)
	var ratio_lisse = pow(ratio_power, 0.5)
	cadencement_tir_cooldown = lerp(1.0, 0.10, ratio_lisse)

	# --- SCROLL AUTOMATIQUE DE LA CAMÉRA ---
	if not verrouillee and not boss_vaincu and not en_pause_sur_stop:
		position.x += vitesse_auto * delta
		
		# Détection des Marker2D "Stop"
		if liste_stops_data.size() > 0:
			var stop_info = liste_stops_data[0]
			var prochain_stop_x = float(stop_info["x"])
			var align_mode = str(stop_info["alignement"])
			var pause_duree = float(stop_info["temps_pause"])
			var demi_lucarne = largeur_lucarne / 2.0
			
			var position_stop_camera = prochain_stop_x
			match align_mode:
				"Bord_Gauche":
					position_stop_camera = prochain_stop_x + demi_lucarne
				"Bord_Droit":
					position_stop_camera = prochain_stop_x - demi_lucarne
				_:
					position_stop_camera = prochain_stop_x

			if position.x >= position_stop_camera:
				position.x = position_stop_camera
				en_pause_sur_stop = true
				liste_stops_data.pop_front()
				print("[CAMÉRA] Pause Stop (", align_mode, ") à X = ", prochain_stop_x, " (pos cam = ", position_stop_camera, ", durée ", pause_duree, "s)")
				get_tree().create_timer(pause_duree).timeout.connect(func():
					en_pause_sur_stop = false
					print("[CAMÉRA] Fin de la pause Stop ! Reprise du scroll.")
				)

	position.x = round(position.x)

	# --- LECTURE DU JOYSTICK VIRTUEL ET GAMEPAD ---
	var dir_stick := Vector2.ZERO
	var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(joy_x) > 0.15 or abs(joy_y) > 0.15:
		dir_stick = Vector2(joy_x, joy_y)
	else:
		dir_stick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Joystick virtuel (référence cachée au _ready, pas de find_child chaque frame)
	if _vjoy and _vjoy.has_method("get_value"):
		var vjoy_val : Vector2 = _vjoy.get_value()
		if vjoy_val != Vector2.ZERO:
			dir_stick = vjoy_val

	# --- DÉPLACEMENT DU VISEUR (clamped dans la lucarne) ---
	if mode_joystick_actif and dir_stick != Vector2.ZERO:
		position_visee_ecran += dir_stick * (150.0 * delta)
		var demi_w = largeur_lucarne / 2.0
		var demi_h = hauteur_lucarne / 2.0
		position_visee_ecran.x = clamp(position_visee_ecran.x, -demi_w, demi_w)
		position_visee_ecran.y = clamp(position_visee_ecran.y, -demi_h, demi_h)

	# Mise à jour du réticule à chaque frame (mode souris OU joystick)
	_actualiser_position_viseur()
		
	# --- GESTION DES TIRS DU GAMEPAD / JOYSTICK ---
	var tir_gamepad = Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3
	var missile_gamepad = Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.3
	
	if tir_gamepad:
		tir_maintenu = true
	elif missile_gamepad and cooldown_tir_restant <= 0.0:
		tirer_projectile(position_visee_monde, true)

	if tir_maintenu and cooldown_tir_restant <= 0.0:
		tirer_projectile(position_visee_monde)
	
	# --- LIMITES GLOBALE DE LA CARTE ---
	var demi_ecran = largeur_lucarne / 2.0
	if position.x < limit_left + demi_ecran:
		position.x = limit_left + demi_ecran
	elif not mode_perpetuel and position.x >= limit_right - demi_ecran:
		position.x = limit_right - demi_ecran
		verrouillee = true
