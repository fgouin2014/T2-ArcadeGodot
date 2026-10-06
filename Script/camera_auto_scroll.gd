extends Camera2D

signal camera_stop_atteint(stop_node: Node2D, nom_stop: String)
signal camera_stop_repris(stop_node: Node2D, nom_stop: String)
signal intro_terminee()

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
@export var sensibilite_joystick : float = 220.0 # Vitesse de visée au joystick (px/s)

# --- CHARGEMENT DU NOUVEAU VISEUR BLEU (.tscn) ---
@export var scene_viseur_bleu : PackedScene = preload("res://maps/Reticule.tscn") # <-- Remplace par le vrai chemin de ta scène .tscn !
var instance_viseur_bleu : Node2D = null

# --- Variables internes ---
var tir_maintenu : bool = false
var cooldown_tir_restant : float = 0.0
var cooldown_missile_restant : float = 0.0
var position_visee_monde : Vector2 = Vector2.ZERO
var position_visee_ecran : Vector2 = Vector2.ZERO # Coordonnées Écran relatives centrées
var temps_ecoule : float = 0.0 
var largeur_lucarne : float = 288.0 
var hauteur_lucarne : float = 176.0
var boss_vaincu : bool = false
var en_pause_sur_stop : bool = false
var _stop_node_actif: Node2D = null
var _stop_nom_actif: String = ""
var _position_x_accumulee: float = 0.0

# Liste des positions et paramètres des Marker2D nommés "Stop"
var liste_stops_data : Array = []
# Stops verrouillés en attente de déverrouillage externe : { nom_stop: pause_duree }
var _stops_verrouilles : Dictionary = {}
var canvas_viseur_jeu: CanvasLayer = null

# Signal émis quand la caméra boucle en mode perpétuel
signal camera_looped(position_avant_boucle: float, position_apres_boucle: float)

# Référence cachée au noeud VirtualJoystickDX (cherché une seule fois)
var _vjoy: Node = null

var scene_projectile : PackedScene = preload("res://projectile.tscn")


func _ready() -> void:
	if not is_inside_tree(): return
	position_smoothing_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	var demi_ecran = largeur_lucarne / 2.0
	position.x = limit_left + demi_ecran
	_position_x_accumulee = position.x
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
		get_tree().create_timer(delai_intro_secondes, false).timeout.connect(func():
			if is_instance_valid(self) and not boss_vaincu and not en_pause_sur_stop:
				verrouillee = false
				print("[CAMÉRA] Intro terminée ! Début du scroll auto.")
				intro_terminee.emit()
		)
	else:
		verrouillee = false
		intro_terminee.emit()

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
			var stop_once_val = true
			if "stop_once" in m:
				stop_once_val = bool(m.stop_once)
			elif m.has_meta("stop_once"):
				stop_once_val = bool(m.get_meta("stop_once"))
				
			var dejection_effectuee = m.has_meta("_stop_deja_franchi") and bool(m.get_meta("_stop_deja_franchi"))
			if stop_once_val and dejection_effectuee:
				continue # Ignorer les stops à usage unique déjà franchis

			if px > pos_min_autorisee:
				var align_val = alignement_stop
				if "alignement" in m and str(m.alignement) != "Utiliser_Defaut_Camera":
					align_val = str(m.alignement)
				elif m.has_meta("alignement") and str(m.get_meta("alignement")) != "Utiliser_Defaut_Camera":
					align_val = str(m.get_meta("alignement"))
				
				var pause_val = temps_pause_stop_secondes
				if "temps_pause" in m:
					pause_val = float(m.temps_pause)
				elif m.has_meta("temps_pause"):
					pause_val = float(m.get_meta("temps_pause"))
				
				var locked_val = false
				if "locked" in m:
					locked_val = bool(m.locked)
				elif m.has_meta("locked"):
					locked_val = bool(m.get_meta("locked"))

				var continuer_sans_arret_val = false
				if "continuer_sans_arret" in m:
					continuer_sans_arret_val = bool(m.continuer_sans_arret)
				elif m.has_meta("continuer_sans_arret"):
					continuer_sans_arret_val = bool(m.get_meta("continuer_sans_arret"))
				
				liste_stops_data.append({
					"x": px,
					"node": m,
					"alignement": align_val,
					"temps_pause": pause_val,
					"locked": locked_val,
					"continuer_sans_arret": continuer_sans_arret_val,
					"stop_once": stop_once_val
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
func reprendre_scroll_force() -> void:
	en_pause_sur_stop = false
	verrouillee = false

## Modifie la vitesse de scroll auto de la caméra (vitesse_auto), avec ou sans transition Tween.
func changer_vitesse_auto(nouvelle_vitesse: float, duree_sec: float = 0.0) -> void:
	print("[CAMÉRA] Changement de vitesse demandé : %.1f -> %.1f (durée: %.2fs)" % [vitesse_auto, nouvelle_vitesse, duree_sec])
	if duree_sec > 0.0:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "vitesse_auto", nouvelle_vitesse, duree_sec)
	else:
		vitesse_auto = nouvelle_vitesse


# Déverrouille un stop "locked" : lance le timer temps_pause configuré sur ce stop (ou reprend immédiatement si <= 0)
func deverrouiller_stop(nom_stop: String = "") -> void:
	var duree_a_lancer: float = 0.0
	if nom_stop != "" and _stops_verrouilles.has(nom_stop):
		duree_a_lancer = float(_stops_verrouilles[nom_stop])
		_stops_verrouilles.erase(nom_stop)
	elif _stops_verrouilles.size() > 0:
		# Prendre le premier stop verrouillé si aucun nom spécifique n'est passé
		var premier_cle = _stops_verrouilles.keys()[0]
		duree_a_lancer = float(_stops_verrouilles[premier_cle])
		_stops_verrouilles.erase(premier_cle)
	
	if duree_a_lancer > 0.0:
		print("[CAMÉRA] Stop déverrouillé (", nom_stop if nom_stop != "" else "actif", ") — reprise dans ", duree_a_lancer, "s.")
		get_tree().create_timer(duree_a_lancer, false).timeout.connect(func():
			en_pause_sur_stop = false
			print("[CAMÉRA] Fin du timer post-déverrouillage ! Reprise du scroll.")
			camera_stop_repris.emit(_stop_node_actif, _stop_nom_actif)
		)
	else:
		en_pause_sur_stop = false
		print("[CAMÉRA] Stop déverrouillé — reprise immédiate.")
		camera_stop_repris.emit(_stop_node_actif, _stop_nom_actif)

func stopper_scroll_boss_defait() -> void:
	boss_vaincu = true
	verrouillee = true

## Raccourci Debug 'R' : Téléporte instantanément la caméra sur 'StopMarkerDebug' si présent dans la scène
func _teleporter_debug_stop_marker() -> void:
	var scene = get_tree().current_scene if get_tree() else null
	if scene == null:
		scene = get_parent()
	if scene == null:
		return
	
	var debug_stop = scene.find_child("StopMarkerDebug", true, false) as Marker2D
	if debug_stop == null:
		return
	
	var target_x = debug_stop.global_position.x
	print("[CAMÉRA DEBUG] Touche R pressée -> Téléportation sur StopMarkerDebug (X = %.1f)" % target_x)
	
	# Téléportation immédiate
	position.x = round(target_x)
	_position_x_accumulee = target_x
	en_pause_sur_stop = false
	verrouillee = false
	boss_vaincu = false
	_stops_verrouilles.clear()
	
	# Réinitialiser les stops situés après target_x
	var marqueurs = (get_parent() if get_parent() else scene).find_children("*Stop*", "Marker2D", true, false)
	for m in marqueurs:
		if m is Marker2D and m != debug_stop:
			if m.global_position.x >= target_x - 50.0:
				m.set_meta("_stop_deja_franchi", false)
	
	# Réactualiser la file des stops
	_rechercher_marqueurs_stop()
	
	# Déclencher le stop debug s'il a une action associée
	if debug_stop.has_method("enclencher_stop"):
		debug_stop.enclencher_stop()
	camera_stop_atteint.emit(debug_stop, debug_stop.name)




var en_surchauffe: bool = false
var coolant_temps_restant: float = 0.0

func activer_coolant(duree_sec: float = 20.0) -> void:
	coolant_temps_restant = duree_sec
	gun_power_actuel = gun_power_max
	en_surchauffe = false
	print("[CAMÉRA] Coolant activé pour ", duree_sec, "s (gunpower illimité sans surchauffe).")

func _declencher_vibration_haptique(duree_ms: int = 50, force: float = 0.4) -> void:
	Input.vibrate_handheld(duree_ms)
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, force * 0.5, force, float(duree_ms) / 1000.0)

func peut_tirer(mode_missile: bool = false) -> bool:
	if mode_missile:
		return scene_projectile != null and cooldown_missile_restant <= 0.0 and not GlobalSettings.partie_perdue
	else:
		return scene_projectile != null and cooldown_tir_restant <= 0.0 and not en_surchauffe and not GlobalSettings.partie_perdue

func tirer_projectile(cible_monde: Vector2, mode_missile: bool = false) -> void:
	if not peut_tirer(mode_missile):
		return
	if mode_missile:
		if not GlobalSettings.consommer_missile():
			return
		cooldown_missile_restant = 0.35 # Cooldown indépendant pour les missiles (permets de tirer un missile en plein mitraillage)
		_declencher_vibration_haptique(80, 0.8) # Vibration haptique (Tactile & Gamepad) au lancement du missile
	else:
		cooldown_tir_restant = cadencement_tir_cooldown
		if coolant_temps_restant <= 0.0:
			gun_power_actuel = max(0.0, gun_power_actuel - cout_gunpower_par_tir)
		else:
			gun_power_actuel = gun_power_max
		if gun_power_actuel <= 0.0:
			en_surchauffe = true

	var centre_ecran = get_screen_center_position()
	var depart_canon_bas_gauche = centre_ecran + Vector2(-largeur_lucarne / 2.0, hauteur_lucarne / 2.0)
	
	var proj = scene_projectile.instantiate()
	get_parent().add_child(proj)
	
	var quantite_degats := GlobalSettings.obtenir_degats_tir_joueur(mode_missile)
	var est_tir_special: bool = GlobalSettings.dernier_tir_etait_special if mode_missile else false
	if proj.has_method("initialiser_tir"):
		proj.initialiser_tir(depart_canon_bas_gauche, cible_monde, mode_missile, quantite_degats, est_tir_special)
	elif "degats" in proj:
		proj.degats = quantite_degats
		proj.position = depart_canon_bas_gauche
	else:
		proj.position = depart_canon_bas_gauche


func _unhandled_input(event: InputEvent) -> void:
	# NOTE : la position du réticule est mise à jour chaque frame dans _physics_process.
	# Ici on gère uniquement les événements de TIR.

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and OS.is_debug_build():
			_teleporter_debug_stop_marker()

	if event is InputEventMouseButton:
		if mode_joystick_actif:
			return
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
			# En mode joystick, le multi-touch est géré par VirtualJoystickDX et MultiTouchButton
			return
		
		# --- MODE TACTILE DIRECT MULTI-TOUCH ---
		# Doigt 0 (1er doigt) = Vise et déclenche le tir principal Plasma
		# Doigt > 0 (2e doigt ou tap supplémentaire) = Tir de missile instantané à la position actuelle du viseur !
		if event.index == 0:
			if event.pressed:
				tir_maintenu = true
				tirer_projectile(position_visee_monde, false)
			else:
				tir_maintenu = false
		else:
			if event.pressed:
				tirer_projectile(position_visee_monde, true)

	elif event is InputEventScreenDrag:
		if mode_joystick_actif:
			return


@export var gun_power_max: float = 100.0
@export var gun_power_actuel: float = 100.0
@export var cout_gunpower_par_tir: float = 2.5 # Consommation d'un tir standard (tir principal uniquement)
@export var vitesse_recharge_gunpower: float = 15.0 
@export var seuil_fin_surchauffe: float = 0.35 # Ratio de GunPower requis pour re-tirer après surchauffe

func _physics_process(delta: float) -> void:
	if not is_inside_tree(): return
	
	temps_ecoule += delta
	if cooldown_tir_restant > 0.0:
		cooldown_tir_restant -= delta
	if cooldown_missile_restant > 0.0:
		cooldown_missile_restant -= delta

	if coolant_temps_restant > 0.0:
		coolant_temps_restant -= delta
		gun_power_actuel = gun_power_max
		en_surchauffe = false
	else:
		# --- GESTION DE LA SURCHAUFFE DU CANON (GUNPOWER) ---
		# Le GunPower se consomme à chaque tir (voir tirer_projectile) et se recharge en continu.
		gun_power_actuel = min(gun_power_max, gun_power_actuel + vitesse_recharge_gunpower * delta)

	var ratio_power = clamp(gun_power_actuel / gun_power_max, 0.0, 1.0)
	if en_surchauffe and ratio_power >= seuil_fin_surchauffe:
		en_surchauffe = false
	var ratio_lisse = pow(ratio_power, 0.5)
	cadencement_tir_cooldown = lerp(1.0, 0.10, ratio_lisse)

	# --- SCROLL AUTOMATIQUE DE LA CAMÉRA ---
	if not verrouillee and not boss_vaincu and not en_pause_sur_stop:
		_position_x_accumulee += vitesse_auto * delta
		
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

			if _position_x_accumulee >= position_stop_camera:
					var stop_locked: bool = bool(stop_info.get("locked", false))
					var stop_sans_arret: bool = bool(stop_info.get("continuer_sans_arret", false))
					var stop_node = stop_info.get("node") as Node2D
					liste_stops_data.pop_front()
					
					# Déclencher les effets du stop dans tous les cas (signal, motion_scale)
					if stop_node:
						stop_node.set_meta("_stop_deja_franchi", true)
						if stop_node.has_method("enclencher_stop"):
							stop_node.enclencher_stop()
						camera_stop_atteint.emit(stop_node, stop_node.name)
					
					if stop_sans_arret:
						# Passage transparent : la caméra ne s'arrête PAS, scroll continu
						print("[CAMÉRA] Stop passage transparent ('", stop_node.name if stop_node else "?", "') — scroll continu.")
					else:
						# Arrêt caméra normal
						_position_x_accumulee = position_stop_camera
						position.x = round(_position_x_accumulee)
						en_pause_sur_stop = true
						_stop_node_actif = stop_node
						_stop_nom_actif = stop_node.name if stop_node else ""
						print("[CAMÉRA] Pause Stop (", align_mode, ") à X = ", prochain_stop_x, " | durée=", pause_duree, "s | locked=", stop_locked)
						if stop_locked:
							# Pause indéfinie : le timer ne démarrera qu'au déverrouillage externe (deverrouiller_stop)
							var nom_cle = stop_node.name if stop_node else "stop"
							_stops_verrouilles[nom_cle] = pause_duree
							print("[CAMÉRA] Stop '", nom_cle, "' verrouillé — attente de deverrouiller_stop() (temps_pause = ", pause_duree, "s).")
						elif pause_duree > 0.0:
							get_tree().create_timer(pause_duree, false).timeout.connect(func():
								en_pause_sur_stop = false
								print("[CAMÉRA] Fin de la pause Stop ! Reprise du scroll.")
								camera_stop_repris.emit(_stop_node_actif, _stop_nom_actif)
							)
						else:
							print("[CAMÉRA] Pause indéfinie — attente d'un événement externe.")


	position.x = round(_position_x_accumulee)

	# --- LECTURE DU JOYSTICK VIRTUEL ET GAMEPAD MULTI-MANETTES ---
	var dir_stick := Vector2.ZERO
	var joypads = Input.get_connected_joypads()
	for dev in joypads:
		var jx = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var jy = Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		if abs(jx) > 0.15 or abs(jy) > 0.15:
			dir_stick = Vector2(jx, jy)
			break

	if dir_stick == Vector2.ZERO:
		dir_stick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Joystick virtuel (référence cachée au _ready, pas de find_child chaque frame)
	if _vjoy and _vjoy.has_method("get_value"):
		var vjoy_val : Vector2 = _vjoy.get_value()
		if vjoy_val != Vector2.ZERO:
			dir_stick = vjoy_val

	# --- DÉPLACEMENT DU VISEUR (clamped dans la lucarne) ---
	if mode_joystick_actif and dir_stick != Vector2.ZERO:
		position_visee_ecran += dir_stick * (sensibilite_joystick * delta)
		var demi_w = largeur_lucarne / 2.0
		var demi_h = hauteur_lucarne / 2.0
		position_visee_ecran.x = clamp(position_visee_ecran.x, -demi_w, demi_w)
		position_visee_ecran.y = clamp(position_visee_ecran.y, -demi_h, demi_h)

	# Mise à jour du réticule à chaque frame (mode souris OU joystick)
	_actualiser_position_viseur()
		
	# --- GESTION DES TIRS DU GAMEPAD MULTI-MANETTES / JOYSTICK ---
	var tir_gamepad = Input.is_action_pressed("ui_accept")
	var missile_gamepad = Input.is_action_just_pressed("ui_select")
	for dev in joypads:
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_A) or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.3:
			tir_gamepad = true
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_B) or Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.3:
			missile_gamepad = true

	if tir_gamepad:
		tir_maintenu = true

	if missile_gamepad:
		tirer_projectile(position_visee_monde, true)

	if tir_maintenu:
		tirer_projectile(position_visee_monde, false)

	
	# --- LIMITES GLOBALE DE LA CARTE & BOUCLAGE PERPÉTUEL ---
	var demi_ecran = largeur_lucarne / 2.0
	if _position_x_accumulee < limit_left + demi_ecran:
		_position_x_accumulee = limit_left + demi_ecran
		position.x = round(_position_x_accumulee)
	elif mode_perpetuel and largeur_boucle_parallax > 0.0:
		if _position_x_accumulee >= limit_right - demi_ecran:
			# Ré-enroulement de la caméra au début de la boucle parallax
			var position_avant = _position_x_accumulee
			_position_x_accumulee = limit_left + demi_ecran
			position.x = round(_position_x_accumulee)
			print("[CAMÉRA PERPÉTUELLE] Bouclage effectué ! Position X réinitialisée à ", position.x)
			# Émettre le signal pour que les acteurs avec boucle_avec_camera puissent boucler aussi
			camera_looped.emit(position_avant, position.x)
			# Re-scanner les stops qui ne sont pas "stop_once" pour la boucle suivante
			call_deferred("_rechercher_marqueurs_stop")
	elif not mode_perpetuel and _position_x_accumulee >= limit_right - demi_ecran:
		_position_x_accumulee = limit_right - demi_ecran
		position.x = round(_position_x_accumulee)
		verrouillee = true
