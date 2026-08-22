extends Control

# --- RÉFÉRENCES UI / SCÈNE ---
@onready var ecran_jeu: Control = $EcranJeu
@onready var vue_jeu: SubViewport = $EcranJeu/VueJeu
@onready var menu_pause_overlay: Control = $MenuPauseOverlay
@onready var bouton_pause: Button = $BoutonPause
@onready var btn_reprendre: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonReprendre
@onready var btn_recommencer: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonRecommencer
@onready var btn_menu_principal: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonMenuPrincipal
@onready var btn_quitter: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonQuitter

# --- RÉFÉRENCES DES GAUGES DE LA BORNE D'ARCADE ---
@onready var gauge_vie_p1: ColorRect = get_node_or_null("GaugeVieP1") as ColorRect
@onready var gauge_vie_p2: ColorRect = get_node_or_null("GaugeVieP2") as ColorRect
@onready var gauge_gunpower_1: ColorRect = get_node_or_null("GaugeGunPower1") as ColorRect
@onready var gauge_gunpower_2: ColorRect = get_node_or_null("GaugeGunPower2") as ColorRect

# --- CONSTANTES VISUELLES ET HUD ---
const LARGEUR_MAX_GUNPOWER: float = 190.0
const X_ZERO_GP1: float = 245.0
const X_ZERO_GP2: float = 719.0

const COULEUR_VERT: Color = Color(0.0, 0.9, 0.2, 1.0)
const COULEUR_JAUNE: Color = Color(1.0, 0.85, 0.0, 1.0)
const COULEUR_ROUGE: Color = Color(0.95, 0.1, 0.1, 1.0)

# --- DOCKING D'ENNEMIS ---
const CHEMINS_ENNEMIS: Dictionary = {
	"xgigend": "res://aseprite/xgigend.tscn",
	"xbigend": "res://aseprite/xbigend.tscn",
	"xmedend": "res://aseprite/xmedend.tscn",
	"xswat": "res://aseprite/xswat.tscn",
	"xt100": "res://aseprite/xt100.tscn",
	"xtech": "res://aseprite/xtech.tscn",
	"xarng": "res://aseprite/xarng.tscn",
	"xt100big": "res://aseprite/xt100big.tscn",
	"xsarah": "res://aseprite/xsarah.tscn"
}

# --- VARIABLES D'ÉTAT ---
var canvas_viseur_pause: CanvasLayer = null
var sprite_viseur_pause: Sprite2D = null
var timer_spawn: Timer = null
var carte_actuelle: Node = null

var btn_toggle_mode_controle: Button = null
var ui_joystick_container: Control = null
var mode_joystick_actif: bool = false


# ==============================================================================
# INITIALISATION
# ==============================================================================
func _ready() -> void:
	# Exécution continue même en PAUSE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if menu_pause_overlay:
		menu_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if bouton_pause:
		bouton_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Interactions physiques avec la souris
	if vue_jeu:
		vue_jeu.physics_object_picking = true
		
	# Curseur personnalisé du système
	var tex_viseur_rouge = load("res://tsj/xmisc_02.png")
	if tex_viseur_rouge:
		for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM, Input.CURSOR_CROSS, Input.CURSOR_CAN_DROP]:
			Input.set_custom_mouse_cursor(tex_viseur_rouge, shape, Vector2(8, 8))

	RenderingServer.set_default_clear_color(Color.BLACK)
	get_tree().set_quit_on_go_back(false)
	
	_initialiser_viseur_pause_ui()
	_connecter_signaux_ui()
	_initialiser_bouton_mode_controle()
	_creer_ui_joystick_et_boutons()

	definir_pause(false)
	
	# Chargement de la carte de jeu
	var chemin_carte = GlobalSettings.carte_selectionnee
	if chemin_carte.is_empty():
		chemin_carte = "res://level2.tscn"
		
	var scene_carte = load(chemin_carte) as PackedScene
	if scene_carte:
		carte_actuelle = scene_carte.instantiate()
		vue_jeu.add_child(carte_actuelle)
		configurer_le_spawn_automatique()


func _initialiser_viseur_pause_ui() -> void:
	canvas_viseur_pause = CanvasLayer.new()
	canvas_viseur_pause.name = "CanvasViseurPause"
	canvas_viseur_pause.layer = 128
	canvas_viseur_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_viseur_pause)
	
	sprite_viseur_pause = Sprite2D.new()
	sprite_viseur_pause.name = "ViseurRougePauseSprite"
	sprite_viseur_pause.texture = load("res://tsj/xmisc_02.png")
	sprite_viseur_pause.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_viseur_pause.centered = true
	canvas_viseur_pause.add_child(sprite_viseur_pause)


func _connecter_signaux_ui() -> void:
	if bouton_pause:
		bouton_pause.mouse_default_cursor_shape = Control.CURSOR_ARROW
		if not bouton_pause.pressed.is_connected(basculer_pause):
			bouton_pause.pressed.connect(basculer_pause)
			
	if btn_reprendre and not btn_reprendre.pressed.is_connected(reprendre_jeu):
		btn_reprendre.pressed.connect(reprendre_jeu)
	if btn_recommencer and not btn_recommencer.pressed.is_connected(recommencer_niveau):
		btn_recommencer.pressed.connect(recommencer_niveau)
	if btn_menu_principal and not btn_menu_principal.pressed.is_connected(revenir_au_menu):
		btn_menu_principal.pressed.connect(revenir_au_menu)
	if btn_quitter and not btn_quitter.pressed.is_connected(quitter_jeu):
		btn_quitter.pressed.connect(quitter_jeu)


# ==============================================================================
# BOUCLE DE RENDU ET MISE À JOUR (PROCESS)
# ==============================================================================
func _process(_delta: float) -> void:
	_mettre_a_jour_viseur_ui()
	_mettre_a_jour_jauges_gunpower()


func _mettre_a_jour_viseur_ui() -> void:
	var pos_souris = get_viewport().get_mouse_position()
	var sur_ecran_jeu = false
	
	if ecran_jeu:
		sur_ecran_jeu = ecran_jeu.get_global_rect().has_point(pos_souris)
		
	var en_pause = get_tree().paused or (menu_pause_overlay and menu_pause_overlay.visible)

	if en_pause or not sur_ecran_jeu:
		if sprite_viseur_pause:
			sprite_viseur_pause.show()
			sprite_viseur_pause.global_position = pos_souris
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		if sprite_viseur_pause:
			sprite_viseur_pause.hide()


func _mettre_a_jour_jauges_gunpower() -> void:
	if not (vue_jeu and carte_actuelle):
		return
		
	var camera = vue_jeu.get_camera_2d()
	if camera and "gun_power_actuel" in camera and "gun_power_max" in camera:
		var max_p = camera.gun_power_max if camera.gun_power_max > 0 else 100.0
		var ratio = clamp(camera.gun_power_actuel / max_p, 0.0, 1.0)
		
		var couleur_dynamique: Color
		if ratio > 0.5:
			var t = (ratio - 0.5) * 2.0
			couleur_dynamique = COULEUR_JAUNE.lerp(COULEUR_VERT, t)
		else:
			var t = ratio * 2.0
			couleur_dynamique = COULEUR_ROUGE.lerp(COULEUR_JAUNE, t)
		
		if gauge_gunpower_1:
			gauge_gunpower_1.offset_left = X_ZERO_GP1
			gauge_gunpower_1.offset_right = X_ZERO_GP1 + (LARGEUR_MAX_GUNPOWER * ratio)
			gauge_gunpower_1.color = couleur_dynamique
			
		if gauge_gunpower_2:
			gauge_gunpower_2.offset_left = X_ZERO_GP2
			gauge_gunpower_2.offset_right = X_ZERO_GP2 + (LARGEUR_MAX_GUNPOWER * ratio)
			gauge_gunpower_2.color = couleur_dynamique


# ==============================================================================
# SPAWN & SPATIALISATION DES ENNEMIS
# ==============================================================================
func configurer_le_spawn_automatique() -> void:
	var conteneur_spawners = carte_actuelle.get_node_or_null("Spawners")
	if conteneur_spawners == null:
		return
		
	timer_spawn = Timer.new()
	timer_spawn.wait_time = 2.0
	timer_spawn.autostart = false
	timer_spawn.timeout.connect(spawn_ennemi_specifique)
	add_child(timer_spawn)


func obtenir_scene_ennemi(type_key: String) -> PackedScene:
	if CHEMINS_ENNEMIS.has(type_key):
		var chemin = str(CHEMINS_ENNEMIS[type_key])
		if ResourceLoader.exists(chemin):
			return load(chemin) as PackedScene
			
	if ResourceLoader.exists("res://aseprite/xgigend.tscn"):
		return load("res://aseprite/xgigend.tscn") as PackedScene
		
	return null


func obtenir_type_ennemi_du_spawner(spawner: Node) -> String:
	if "type_ennemi" in spawner:
		return str(spawner.type_ennemi)
	if spawner.has_meta("type_ennemi"):
		return str(spawner.get_meta("type_ennemi"))
	
	var nom_spawner_minuscule = spawner.name.to_lower()
	for type_cle in CHEMINS_ENNEMIS.keys():
		if type_cle in nom_spawner_minuscule:
			return type_cle
			
	return "xgigend"


func spawn_ennemi_specifique() -> void:
	if carte_actuelle == null:
		return
		
	var conteneur_spawners = carte_actuelle.get_node_or_null("Spawners")
	if conteneur_spawners == null:
		return
		
	var liste_spawners = conteneur_spawners.get_children()
	if liste_spawners.is_empty():
		return
		
	var spawners_disponibles = liste_spawners.filter(func(sp): return not sp.has_meta("deja_spawne"))
	if spawners_disponibles.is_empty():
		return
		
	var spawner_choisi = spawners_disponibles[randi() % spawners_disponibles.size()]
	spawner_choisi.set_meta("deja_spawne", true)
	
	var type_ennemi = obtenir_type_ennemi_du_spawner(spawner_choisi)
	var scene_ennemi = obtenir_scene_ennemi(type_ennemi)
	if scene_ennemi == null:
		push_error("Impossible de charger la scène d'ennemi pour : " + type_ennemi)
		return
	
	var position_reelle: Vector2 = Vector2.ZERO
	if carte_actuelle is Node2D:
		position_reelle = (carte_actuelle as Node2D).to_local(spawner_choisi.global_position)
	elif spawner_choisi is Node2D:
		position_reelle = spawner_choisi.global_position
	
	var nouvel_ennemi = scene_ennemi.instantiate()
	nouvel_ennemi.position = position_reelle
	carte_actuelle.add_child(nouvel_ennemi)
	
	if nouvel_ennemi.has_signal("boss_defeated"):
		var camera = carte_actuelle.get_node_or_null("Camera2D")
		if camera and camera.has_method("stopper_scroll_boss_defait"):
			if not nouvel_ennemi.boss_defeated.is_connected(camera.stopper_scroll_boss_defait):
				nouvel_ennemi.boss_defeated.connect(camera.stopper_scroll_boss_defait)

	if not nouvel_ennemi.has_method("demarrer_sequence"):
		var anim_sprite = nouvel_ennemi.get_node_or_null("AnimatedSprite2D")
		if anim_sprite and anim_sprite.sprite_frames:
			if anim_sprite.sprite_frames.has_animation("popup"):
				anim_sprite.play("popup")
			elif anim_sprite.sprite_frames.has_animation("idle"):
				anim_sprite.play("idle")


# ==============================================================================
# MODES DE CONTRÔLE (TACTILE / SOURIS / JOYSTICK)
# ==============================================================================
func _initialiser_bouton_mode_controle() -> void:
	if menu_pause_overlay:
		var boite_v = menu_pause_overlay.get_node_or_null("CentreContainer/BoiteV")
		if boite_v and btn_toggle_mode_controle == null:
			btn_toggle_mode_controle = Button.new()
			btn_toggle_mode_controle.name = "BoutonToggleModeControle"
			btn_toggle_mode_controle.text = "🕹️ MODE CONTRÔLE : SOURIS / TACTILE DIRECT"
			btn_toggle_mode_controle.custom_minimum_size = Vector2(250, 40)
			btn_toggle_mode_controle.pressed.connect(_basculer_mode_controle)
			boite_v.add_child(btn_toggle_mode_controle)


func _basculer_mode_controle() -> void:
	mode_joystick_actif = not mode_joystick_actif
	if btn_toggle_mode_controle:
		btn_toggle_mode_controle.text = "🕹️ MODE CONTRÔLE : JOYSTICK VIRTUEL & GAMEPAD" if mode_joystick_actif else "🎯 MODE CONTRÔLE : SOURIS / TACTILE DIRECT"
	if ui_joystick_container:
		ui_joystick_container.visible = mode_joystick_actif
		
	if carte_actuelle:
		var camera = carte_actuelle.get_node_or_null("Camera2D")
		if camera and "mode_joystick_actif" in camera:
			camera.mode_joystick_actif = mode_joystick_actif


func _creer_ui_joystick_et_boutons() -> void:
	ui_joystick_container = get_node_or_null("VirtualJoystickUI") as Control
	if ui_joystick_container:
		ui_joystick_container.visible = mode_joystick_actif
		
		var btn_tir = ui_joystick_container.get_node_or_null("BoutonTirPrincipalUI") as Button
		if btn_tir:
			if not btn_tir.button_down.is_connected(_on_btn_tir_down):
				btn_tir.button_down.connect(_on_btn_tir_down)
				btn_tir.button_up.connect(_on_btn_tir_up)
				
		var btn_missile = ui_joystick_container.get_node_or_null("BoutonTirMissileUI") as Button
		if btn_missile:
			if not btn_missile.pressed.is_connected(_on_btn_missile_pressed):
				btn_missile.pressed.connect(_on_btn_missile_pressed)


func _on_btn_tir_down() -> void:
	_actionner_tir_ui(true, false)

func _on_btn_tir_up() -> void:
	_actionner_tir_ui(false, false)

func _on_btn_missile_pressed() -> void:
	_actionner_tir_ui(true, true)

func _actionner_tir_ui(est_presse: bool, est_missile: bool) -> void:
	if carte_actuelle:
		var camera = carte_actuelle.get_node_or_null("Camera2D")
		if camera:
			if est_missile:
				if camera.has_method("tirer_projectile"):
					camera.tirer_projectile(camera.position_visee_monde, true)
			else:
				camera.tir_maintenu = est_presse


# ==============================================================================
# MENU PAUSE & NAVIGATION
# ==============================================================================
func basculer_pause() -> void:
	definir_pause(not get_tree().paused)


func definir_pause(etat_pause: bool) -> void:
	get_tree().paused = etat_pause
	if menu_pause_overlay:
		menu_pause_overlay.visible = etat_pause
		if etat_pause:
			menu_pause_overlay.move_to_front()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if etat_pause else Input.MOUSE_MODE_HIDDEN



func reprendre_jeu() -> void:
	definir_pause(false)

func recommencer_niveau() -> void:
	definir_pause(false)
	get_tree().reload_current_scene()

func quitter_jeu() -> void:
	definir_pause(false)
	get_tree().quit()

func revenir_au_menu() -> void:
	definir_pause(false)
	if timer_spawn and is_instance_valid(timer_spawn):
		timer_spawn.stop()
		timer_spawn.queue_free()
		
	if vue_jeu:
		for enfant in vue_jeu.get_children():
			enfant.queue_free()
			
	get_tree().change_scene_to_file("res://maps/menu_selection.tscn")

# ==============================================================================
# GESTION DES ENTRÉES (SOURIS, CLAVIER, BOUTON RETOUR ANDROID)
# ==============================================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		basculer_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_BACK, KEY_ESCAPE, KEY_P]:
			basculer_pause()
