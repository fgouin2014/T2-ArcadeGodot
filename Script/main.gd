extends Control

# --- RÉFÉRENCES UI / SCÈNE ---
@onready var ecran_jeu: Control = $EcranJeu
@onready var vue_jeu: SubViewport = $EcranJeu/VueJeu
@onready var menu_pause_overlay: Control = $MenuPauseOverlay
@onready var bouton_pause: Button = $BoutonPause
@onready var btn_reprendre: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonReprendre
@onready var btn_recommencer: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonRecommencer
@onready var btn_menu_principal: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonLevelSelect
@onready var btn_quitter: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonQuitter
@onready var btn_level_select_pause: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonLevelSelect
@onready var btn_debug: Button = $MenuPauseOverlay/CentreContainer/BoiteV/BoutonDebug
@onready var debug_options_container: Control = $MenuPauseOverlay/CentreContainer/BoiteV/DebugOptionsContainer
@onready var check_jug: CheckBox = $MenuPauseOverlay/CentreContainer/BoiteV/DebugOptionsContainer/CheckJug
@onready var check_copter: CheckBox = $MenuPauseOverlay/CentreContainer/BoiteV/DebugOptionsContainer/CheckCopter
@onready var check_van: CheckBox = $MenuPauseOverlay/CentreContainer/BoiteV/DebugOptionsContainer/CheckVan
@onready var check_health: CheckBox = $MenuPauseOverlay/CentreContainer/BoiteV/DebugOptionsContainer/CheckHealth

# --- RÉFÉRENCES MENU PRINCIPAL ---
@onready var main_menu: Control = $MainMenu
@onready var btn_level_select_main: Button = $MainMenu/ConteneurPrincipal/BoutonLevelSelect
@onready var btn_reprendre_main: Button = $MainMenu/ConteneurPrincipal/BoutonReprendre
@onready var btn_quitter_main: Button = $MainMenu/ConteneurPrincipal/BoutonQuitter
@onready var menu_select_overlay: Control = $MenuSelectLevelOverlay
@onready var btn_retour_select: Button = $MenuSelectLevelOverlay/ConteneurPrincipal/BoutonRetour

# --- DEBUG HUD ---
var debug_hud: CanvasLayer = null

# --- RÉFÉRENCES DES GAUGES DE LA BORNE D'ARCADE ---
@onready var gauge_vie_p1: ColorRect = get_node_or_null("GaugeVieP1") as ColorRect
@onready var gauge_vie_p2: ColorRect = get_node_or_null("GaugeVieP2") as ColorRect
@onready var gauge_gunpower_1: ColorRect = get_node_or_null("GaugeGunPower1") as ColorRect
@onready var gauge_gunpower_2: ColorRect = get_node_or_null("GaugeGunPower2") as ColorRect
@onready var label_score: BitmapText = get_node_or_null("ScoreBitmap") as BitmapText
@onready var label_credits: BitmapText = get_node_or_null("CreditsBitmap") as BitmapText
@onready var label_missiles: BitmapText = get_node_or_null("MissilesBitmap") as BitmapText

# --- CONSTANTES VISUELLES ET HUD ---
const LARGEUR_MAX_GUNPOWER: float = 190.0
const X_ZERO_GP1: float = 245.0
const X_ZERO_GP2: float = 719.0

const COULEUR_VERT: Color = Color(0.0, 0.9, 0.2, 1.0)
const COULEUR_JAUNE: Color = Color(1.0, 0.85, 0.0, 1.0)
const COULEUR_ROUGE: Color = Color(0.95, 0.1, 0.1, 1.0)

const INTERVALLE_VAGUE_SEC: float = 2.0 # Cadence de déclenchement des spawners de la carte

# --- DOCKING D'ENNEMIS ---
const CHEMINS_ENNEMIS: Dictionary = {
	"xgigend": "res://aseprite/xgigend.tscn",
	"xbigend": "res://aseprite/xbigend.tscn",
	"xbigend2": "res://aseprite/xbigend.tscn",
	"xbigend3": "res://aseprite/xbigend.tscn",
	"xmedend": "res://aseprite/xmedend.tscn",
	"xmedend2": "res://aseprite/xmedend.tscn",
	"xmedend3": "res://aseprite/xmedend.tscn",
	"xswat": "res://aseprite/xswat.tscn",
	"xt100": "res://aseprite/xt100.tscn",
	"xtech": "res://aseprite/xtech.tscn",
	"xarnb": "res://aseprite/xarnb.tscn",
	"xarng": "res://aseprite/xarng.tscn",
	"xarnm": "res://aseprite/xarnm.tscn",
	"xarns": "res://aseprite/xarns.tscn",
	"xbighk": "res://aseprite/xbighk.tscn",
	"xendrop": "res://aseprite/xendrop.tscn",
	"xendrop2": "res://aseprite/xendrop.tscn",
	"xendrop3": "res://aseprite/xendrop.tscn",
	"xenfwrd": "res://aseprite/xenfwrd.tscn",
	"xenfwrd2": "res://aseprite/xenfwrd.tscn",
	"xenfwrd3": "res://aseprite/xenfwrd.tscn",
	"xenjump": "res://aseprite/xenjump.tscn",
	"xenjump2": "res://aseprite/xenjump.tscn",
	"xenjump3": "res://aseprite/xenjump.tscn",
	"xethrow": "res://aseprite/xethrow.tscn",
	"xfrdfhk": "res://aseprite/xfrdfhk.tscn",
	"xmedfwrd": "res://aseprite/xmedfwrd.tscn",
	"xmedfwrd2": "res://aseprite/xmedfwrd.tscn",
	"xmedfwrd3": "res://aseprite/xmedfwrd.tscn",
	"xt100big": "res://aseprite/xt100big.tscn",
	"xsarah": "res://aseprite/xsarah.tscn",
	"xojc": "res://aseprite/xojc.tscn",
	"xyjc": "res://aseprite/xyjc.tscn"
}

# --- VARIABLES D'ÉTAT ---
var canvas_viseur_pause: CanvasLayer = null
var sprite_viseur_pause: Sprite2D = null
var timer_spawn: Timer = null
var carte_actuelle: Node = null

var btn_toggle_mode_controle: Button = null
var ui_joystick_container: Control = null
var mode_joystick_actif: bool = false

var overlay_game_over: Control = null
var camera_jeu: Camera2D = null
var _en_transition_niveau: bool = false
var _overlay_fondu: ColorRect = null

# Géométrie des jauges de vie verticales (lues sur la scène au démarrage)
var _geometrie_gauges_vie: Dictionary = {}

# Échelles de base initiales des labels HUD (pour éviter le cumul/glitch de scale lors des pulses)
var _echelles_base_hud: Dictionary = {}
var _tweens_pulse_hud: Dictionary = {}


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
	
	GlobalSettings.reinitialiser_partie()

	_initialiser_fondu_transition()
	_initialiser_viseur_pause_ui()
	_initialiser_hud_partie()
	_connecter_signaux_ui()
	_initialiser_bouton_mode_controle()
	_creer_ui_joystick_et_boutons()
	_initialiser_debug_hud()

	if not GlobalSettings.demande_changement_niveau.is_connected(_on_demande_changement_niveau):
		GlobalSettings.demande_changement_niveau.connect(_on_demande_changement_niveau)

	# Connecter les signaux du menu de sélection de niveau
	if menu_select_overlay and menu_select_overlay.has_signal("niveau_selectionne"):
		if not menu_select_overlay.niveau_selectionne.is_connected(_on_niveau_selectionne):
			menu_select_overlay.niveau_selectionne.connect(_on_niveau_selectionne)
	if menu_select_overlay and menu_select_overlay.has_signal("retour_menu_principal"):
		if not menu_select_overlay.retour_menu_principal.is_connected(retourner_main_menu):
			menu_select_overlay.retour_menu_principal.connect(retourner_main_menu)

	# Configuration initiale des menus
	if main_menu:
		main_menu.visible = true
	if menu_select_overlay:
		menu_select_overlay.visible = false
	if menu_pause_overlay:
		menu_pause_overlay.visible = false
	
	# Mettre le jeu en pause au démarrage jusqu'à ce qu'une partie commence
	get_tree().paused = true
	
	# NE PAS charger la carte automatiquement au démarrage
	# La carte sera chargée uniquement quand l'utilisateur sélectionne un niveau


func _initialiser_fondu_transition() -> void:
	var canvas_fondu = CanvasLayer.new()
	canvas_fondu.name = "CanvasFonduTransition"
	canvas_fondu.layer = 150
	canvas_fondu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_fondu)
	
	_overlay_fondu = ColorRect.new()
	_overlay_fondu.name = "OverlayNoirFondu"
	_overlay_fondu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_fondu.color = Color(0, 0, 0, 0)
	_overlay_fondu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_fondu.add_child(_overlay_fondu)


func _on_demande_changement_niveau(prochain_niveau: String) -> void:
	if _en_transition_niveau:
		return
	_charger_prochain_tableau(prochain_niveau)


func _charger_prochain_tableau(prochain_niveau: String) -> void:
	_en_transition_niveau = true
	print("[Main] Transition de niveau enclenchée vers : ", prochain_niveau)
	
	# Arrêter les tirs en cours
	if camera_jeu:
		camera_jeu.tir_maintenu = false
	
	# Arrêter le timer de spawn actuel
	if timer_spawn and is_instance_valid(timer_spawn):
		timer_spawn.stop()
	
	# Fondu au noir (0.4s)
	if _overlay_fondu:
		var tw_out = create_tween()
		tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_out.tween_property(_overlay_fondu, "color:a", 1.0, 0.4)
		await tw_out.finished
	
	# Si c'est le menu ou une scène globale hors vue jeu
	if "menu" in prochain_niveau.to_lower():
		revenir_au_menu()
		_en_transition_niveau = false
		return
	
	# Réinitialiser la partie pour un nouveau niveau
	GlobalSettings.reinitialiser_partie()
	
	# Déchargement propre de l'ancienne carte
	if carte_actuelle and is_instance_valid(carte_actuelle):
		carte_actuelle.queue_free()
		carte_actuelle = null
		camera_jeu = null
	
	# Laisser le temps à Godot de libérer l'arbre
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Chargement et instanciation du nouveau niveau
	GlobalSettings.carte_selectionnee = prochain_niveau
	var scene_carte = load(prochain_niveau) as PackedScene
	if scene_carte:
		carte_actuelle = scene_carte.instantiate()
		vue_jeu.add_child(carte_actuelle)
		camera_jeu = carte_actuelle.get_node_or_null("Camera2D") as Camera2D
		configurer_le_spawn_automatique()
		_connecter_boss_places_dans_la_carte()
		print("[Main] Niveau '", prochain_niveau, "' instancié et démarré avec succès !")
	else:
		push_error("[Main] Impossible de charger la scène du niveau : " + str(prochain_niveau))
	
	# Fondu d'ouverture (0.4s)
	if _overlay_fondu:
		var tw_in = create_tween()
		tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_in.tween_property(_overlay_fondu, "color:a", 0.0, 0.4)
		await tw_in.finished
	
	# Reprendre le jeu après le chargement du niveau
	definir_pause(false)
	_en_transition_niveau = false



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


func _initialiser_debug_hud() -> void:
	var debug_scene = load("res://Script/debug_hud.tscn")
	if debug_scene:
		debug_hud = debug_scene.instantiate()
		debug_hud.name = "DebugHUD"
		debug_hud.layer = 200  # Au-dessus de tout
		add_child(debug_hud)
		print("[Main] DebugHUD créé avec succès")


func _initialiser_hud_partie() -> void:
	for gauge in [gauge_vie_p1, gauge_vie_p2]:
		if gauge:
			_geometrie_gauges_vie[gauge] = {"haut": gauge.offset_top, "bas": gauge.offset_bottom}

	# Mémoriser les échelles de base originales des textes HUD
	for lbl in [label_score, label_credits, label_missiles]:
		if lbl:
			_echelles_base_hud[lbl] = lbl.scale

	if not GlobalSettings.score_modifie.is_connected(_on_score_modifie):
		GlobalSettings.score_modifie.connect(_on_score_modifie)
	if not GlobalSettings.vie_modifiee.is_connected(_on_vie_modifiee):
		GlobalSettings.vie_modifiee.connect(_on_vie_modifiee)
	if not GlobalSettings.credits_modifies.is_connected(_on_credits_modifies):
		GlobalSettings.credits_modifies.connect(_on_credits_modifies)
	if not GlobalSettings.missiles_modifies.is_connected(_on_missiles_modifies):
		GlobalSettings.missiles_modifies.connect(_on_missiles_modifies)
	if not GlobalSettings.partie_terminee.is_connected(_on_partie_terminee):
		GlobalSettings.partie_terminee.connect(_on_partie_terminee)
	if not GlobalSettings.pickup_collecte_anime.is_connected(_on_pickup_collecte_anime):
		GlobalSettings.pickup_collecte_anime.connect(_on_pickup_collecte_anime)

	_on_score_modifie(GlobalSettings.score)
	_on_credits_modifies(GlobalSettings.credits_restants)
	_on_missiles_modifies(GlobalSettings.missiles_restants)
	_on_vie_modifiee(GlobalSettings.vie_actuelle, GlobalSettings.vie_max)


func _animer_pulse_hud(cible_hud: Control) -> void:
	if cible_hud == null or not is_instance_valid(cible_hud):
		return
	var scale_base: Vector2 = _echelles_base_hud.get(cible_hud, cible_hud.scale)
	
	# Si un tween tournait déjà sur cet élément, le stopper proprement
	if _tweens_pulse_hud.has(cible_hud):
		var ancien_tw: Tween = _tweens_pulse_hud[cible_hud]
		if is_instance_valid(ancien_tw) and ancien_tw.is_running():
			ancien_tw.kill()

	# Réinitialiser immédiatement à l'échelle de base avant le pulse
	cible_hud.scale = scale_base

	var tw_pulse = create_tween()
	tw_pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tweens_pulse_hud[cible_hud] = tw_pulse
	tw_pulse.tween_property(cible_hud, "scale", scale_base * 1.3, 0.08)
	tw_pulse.tween_property(cible_hud, "scale", scale_base, 0.12)


func _on_pickup_collecte_anime(texture_pickup: Texture2D, pos_ecran_depart: Vector2, type_pickup: String) -> void:
	# Déterminer la cible HUD selon le type de pickup :
	# - Missiles -> haut-gauche (MissilesBitmap)
	# - Crédits -> haut-centre (CreditsBitmap)
	# - Reste (Score, etc.) -> entre les missiles et les crédits (ScoreBitmap)
	var cible_hud: Control = label_score
	var nom_type = type_pickup.to_lower()
	if "missile" in nom_type or "14" in nom_type:
		cible_hud = label_missiles if label_missiles else label_score
	elif "credit" in nom_type or "21" in nom_type:
		cible_hud = label_credits if label_credits else label_score
	else:
		cible_hud = label_score

	if cible_hud == null:
		return

	# Si texture_pickup est null, c'est le signal d'impact/arrivée à destination pour faire pulser le texte HUD
	if texture_pickup == null:
		_animer_pulse_hud(cible_hud)
		return

	# Fallback si une texture est fournie depuis un autre composant
	var sprite_volant := Sprite2D.new()
	sprite_volant.texture = texture_pickup
	sprite_volant.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_volant.scale = Vector2(3.0, 3.0)
	sprite_volant.z_index = 0
	sprite_volant.global_position = pos_ecran_depart
	
	if has_node("ImageHUD"):
		add_child(sprite_volant)
		move_child(sprite_volant, get_node("ImageHUD").get_index())
	else:
		add_child(sprite_volant)

	var scale_courante = _echelles_base_hud.get(cible_hud, cible_hud.scale)
	var pos_cible = cible_hud.global_position + (cible_hud.size * scale_courante * 0.5)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sprite_volant, "global_position", pos_cible, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite_volant, "scale", Vector2(1.2, 1.2), 0.4)
	tw.chain().tween_property(sprite_volant, "modulate:a", 0.0, 0.1)

	tw.finished.connect(func():
		if is_instance_valid(sprite_volant):
			sprite_volant.queue_free()
		if is_instance_valid(cible_hud):
			_animer_pulse_hud(cible_hud)
	)


func _on_score_modifie(score: int) -> void:
	if label_score:
		label_score.set_text("%08d" % score)


func _on_credits_modifies(credits_restants: int) -> void:
	if label_credits:
		label_credits.set_text("%02d" % credits_restants)

func _on_missiles_modifies(missiles_restants: int) -> void:
	if label_missiles:
		label_missiles.set_text("%04d" % missiles_restants)


func _on_vie_modifiee(vie_actuelle: int, vie_max: int) -> void:
	var ratio = clamp(float(vie_actuelle) / float(max(vie_max, 1)), 0.0, 1.0)
	for gauge in [gauge_vie_p1, gauge_vie_p2]:
		if gauge == null or not _geometrie_gauges_vie.has(gauge):
			continue
		var geo = _geometrie_gauges_vie[gauge]
		var hauteur_totale = float(geo["bas"]) - float(geo["haut"])
		# Jauge verticale : elle se vide par le haut
		gauge.offset_top = float(geo["bas"]) - (hauteur_totale * ratio)
		gauge.offset_bottom = float(geo["bas"])


func _on_partie_terminee(score_final: int) -> void:
	_afficher_game_over(score_final)


func _afficher_game_over(score_final: int) -> void:
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.show()
		return

	overlay_game_over = Control.new()
	overlay_game_over.name = "OverlayGameOver"
	overlay_game_over.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_game_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay_game_over)

	var fond = ColorRect.new()
	fond.color = Color(0.0, 0.0, 0.0, 0.72)
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_game_over.add_child(fond)

	var centre = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_game_over.add_child(centre)

	var boite = VBoxContainer.new()
	boite.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(boite)

	var titre = Label.new()
	titre.text = "GAME OVER"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(titre)

	var label_final = Label.new()
	label_final.text = "SCORE FINAL : %08d" % score_final
	label_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boite.add_child(label_final)

	var btn_rejouer = Button.new()
	btn_rejouer.text = "REJOUER"
	btn_rejouer.custom_minimum_size = Vector2(220, 40)
	if not btn_rejouer.pressed.is_connected(recommencer_niveau): btn_rejouer.pressed.connect(recommencer_niveau)
	boite.add_child(btn_rejouer)

	var btn_menu = Button.new()
	btn_menu.text = "MENU PRINCIPAL"
	btn_menu.custom_minimum_size = Vector2(220, 40)
	if not btn_menu.pressed.is_connected(revenir_au_menu): btn_menu.pressed.connect(revenir_au_menu)
	boite.add_child(btn_menu)

	definir_pause(true)
	if menu_pause_overlay:
		menu_pause_overlay.hide()
	overlay_game_over.move_to_front()


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
	if btn_debug and not btn_debug.pressed.is_connected(_basculer_debug_menu):
		btn_debug.pressed.connect(_basculer_debug_menu)
	if check_jug and not check_jug.toggled.is_connected(_on_check_jug_toggled):
		check_jug.toggled.connect(_on_check_jug_toggled)
	if check_copter and not check_copter.toggled.is_connected(_on_check_copter_toggled):
		check_copter.toggled.connect(_on_check_copter_toggled)
	if check_van and not check_van.toggled.is_connected(_on_check_van_toggled):
		check_van.toggled.connect(_on_check_van_toggled)
	if check_health and not check_health.toggled.is_connected(_on_check_health_toggled):
		check_health.toggled.connect(_on_check_health_toggled)
	
	# Signaux du menu principal
	if btn_level_select_main and not btn_level_select_main.pressed.is_connected(afficher_menu_selection):
		btn_level_select_main.pressed.connect(afficher_menu_selection)
	if btn_reprendre_main and not btn_reprendre_main.pressed.is_connected(reprendre_jeu_depuis_menu):
		btn_reprendre_main.pressed.connect(reprendre_jeu_depuis_menu)
	if btn_quitter_main and not btn_quitter_main.pressed.is_connected(quitter_jeu):
		btn_quitter_main.pressed.connect(quitter_jeu)
	if btn_retour_select and not btn_retour_select.pressed.is_connected(retourner_main_menu):
		btn_retour_select.pressed.connect(retourner_main_menu)
	
	# Signaux du menu pause
	if btn_level_select_pause and not btn_level_select_pause.pressed.is_connected(afficher_menu_selection):
		btn_level_select_pause.pressed.connect(afficher_menu_selection)


# ==============================================================================
# BOUCLE DE RENDU ET MISE À JOUR (PROCESS)
# ==============================================================================
func _process(_delta: float) -> void:
	_mettre_a_jour_viseur_ui()
	_mettre_a_jour_jauges_gunpower()
	_update_health_debug_log()


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
		
	var camera = camera_jeu if (camera_jeu and is_instance_valid(camera_jeu)) else vue_jeu.get_camera_2d()
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
		
	if conteneur_spawners.get_child_count() == 0:
		return

	timer_spawn = Timer.new()
	timer_spawn.wait_time = INTERVALLE_VAGUE_SEC
	if not timer_spawn.timeout.is_connected(spawn_ennemi_specifique): timer_spawn.timeout.connect(spawn_ennemi_specifique)
	add_child(timer_spawn)
	timer_spawn.start()


## Relie les boss déjà placés dans la carte à l'arrêt du défilement de la caméra.
func _connecter_boss_places_dans_la_carte() -> void:
	if carte_actuelle == null or camera_jeu == null:
		return
	if not camera_jeu.has_method("stopper_scroll_boss_defait"):
		return

	for noeud in carte_actuelle.find_children("*", "Node2D", true, false):
		if noeud.has_signal("boss_defeated") and not noeud.boss_defeated.is_connected(camera_jeu.stopper_scroll_boss_defait):
			noeud.boss_defeated.connect(camera_jeu.stopper_scroll_boss_defait)


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
		# Tous les points de spawn de la carte ont été consommés : plus rien à cadencer
		if timer_spawn and is_instance_valid(timer_spawn):
			timer_spawn.stop()
		return
		
	var spawner_choisi = spawners_disponibles.pick_random()
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
		var camera = camera_jeu if (camera_jeu and is_instance_valid(camera_jeu)) else carte_actuelle.get_node_or_null("Camera2D")
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
			btn_toggle_mode_controle.text = "🕹️ MODE CONTRÔLE : MANETTE"
			btn_toggle_mode_controle.custom_minimum_size = Vector2(250, 40)
			if not btn_toggle_mode_controle.pressed.is_connected(_basculer_mode_controle): btn_toggle_mode_controle.pressed.connect(_basculer_mode_controle)
			boite_v.add_child(btn_toggle_mode_controle)


func _basculer_mode_controle() -> void:
	mode_joystick_actif = not mode_joystick_actif
	if btn_toggle_mode_controle:
		btn_toggle_mode_controle.text = "🕹️ MODE CONTRÔLE : MANETTE" if mode_joystick_actif else "🎯 MODE CONTRÔLE : SOURIS / TACTILE"
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
		
		var btn_tir = ui_joystick_container.get_node_or_null("BoutonTirPrincipalUI")
		if btn_tir:
			if btn_tir.has_signal("touched_down"):
				if not btn_tir.touched_down.is_connected(_on_btn_tir_down):
					btn_tir.touched_down.connect(_on_btn_tir_down)
					btn_tir.touched_up.connect(_on_btn_tir_up)
			elif btn_tir is Button:
				if not btn_tir.button_down.is_connected(_on_btn_tir_down):
					btn_tir.button_down.connect(_on_btn_tir_down)
					btn_tir.button_up.connect(_on_btn_tir_up)
				
		var btn_missile = ui_joystick_container.get_node_or_null("BoutonTirMissileUI")
		if btn_missile:
			if btn_missile.has_signal("touched_down"):
				if not btn_missile.touched_down.is_connected(_on_btn_missile_pressed):
					btn_missile.touched_down.connect(_on_btn_missile_pressed)
			elif btn_missile is Button:
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
# DEBUG HUD
# ==============================================================================
func _basculer_debug_menu() -> void:
	if debug_options_container:
		debug_options_container.visible = not debug_options_container.visible
	if debug_hud:
		debug_hud.toggle_debug_hud(debug_options_container.visible)

func _on_check_jug_toggled(pressed: bool) -> void:
	if debug_hud:
		debug_hud.toggle_jug_log(pressed)

func _on_check_copter_toggled(pressed: bool) -> void:
	if debug_hud:
		debug_hud.toggle_copter_log(pressed)

func _on_check_van_toggled(pressed: bool) -> void:
	if debug_hud:
		debug_hud.toggle_van_log(pressed)

func _on_check_health_toggled(pressed: bool) -> void:
	if debug_hud:
		debug_hud.toggle_health_log(pressed)

func _update_health_debug_log() -> void:
	if not debug_hud:
		return

	if not carte_actuelle:
		return

	var health_text = ""
	var actor_count = 0

	# Scanner tous les acteurs avec des PV
	for actor in carte_actuelle.find_children("*", "Node2D", true, false):
		if actor.has_method("get_pv_actuels") and actor.has_method("get_pv_max"):
			var pv_actuels = actor.get_pv_actuels() if actor.has_method("get_pv_actuels") else 0
			var pv_max = actor.get_pv_max() if actor.has_method("get_pv_max") else 1
			var ratio = float(pv_actuels) / float(max(pv_max, 1)) * 100.0

			var actor_name = actor.name
			if "jug" in actor_name.to_lower():
				actor_name = "JUG"
			elif "copter" in actor_name.to_lower():
				actor_name = "COPTER"
			elif "van" in actor_name.to_lower():
				actor_name = "VAN"

			health_text += "%s: %d/%d (%.0f%%)\n" % [actor_name, pv_actuels, pv_max, ratio]
			actor_count += 1

	if actor_count == 0:
		health_text = "Aucun acteur détecté"

	if debug_hud and debug_hud.has_method("set_health_log"):
		debug_hud.set_health_log(health_text)


# ==============================================================================
# MENU PAUSE & NAVIGATION
# ==============================================================================
func basculer_pause() -> void:
	if GlobalSettings.partie_perdue:
		return
	
	# Si un menu est affiché, ne pas afficher le menu pause
	var menu_actif = (main_menu and main_menu.visible) or (menu_select_overlay and menu_select_overlay.visible)
	
	if menu_actif:
		definir_pause(true)  # Garder la pause mais ne pas afficher le menu pause
	else:
		definir_pause(not get_tree().paused)


func definir_pause(etat_pause: bool) -> void:
	get_tree().paused = etat_pause
	
	# N'afficher le menu pause que si on n'est pas dans les menus principaux
	var menu_actif = (main_menu and main_menu.visible) or (menu_select_overlay and menu_select_overlay.visible)
	
	if menu_pause_overlay:
		if menu_actif:
			# Si un menu principal est actif, cacher le menu pause
			menu_pause_overlay.visible = false
		else:
			# Sinon, afficher le menu pause normalement
			menu_pause_overlay.visible = etat_pause
			if etat_pause:
				menu_pause_overlay.move_to_front()
	
	# Arrêter/reprendre la caméra quand le menu pause est affiché/caché
	if camera_jeu and is_instance_valid(camera_jeu):
		if menu_pause_overlay and menu_pause_overlay.visible:
			# Arrêter la caméra quand le menu pause est visible
			if camera_jeu.has_method("arreter_camera"):
				camera_jeu.arreter_camera()
		else:
			# Reprendre la caméra quand le menu pause est caché
			if camera_jeu.has_method("reprendre_camera"):
				camera_jeu.reprendre_camera()
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if etat_pause else Input.MOUSE_MODE_HIDDEN



func reprendre_jeu() -> void:
	definir_pause(false)

func recommencer_niveau() -> void:
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.hide()
	definir_pause(false)
	GlobalSettings.reinitialiser_partie()
	
	# Recharger uniquement le niveau actuel sans recharger toute l'interface
	if carte_actuelle and is_instance_valid(carte_actuelle):
		var chemin_carte_actuelle = GlobalSettings.carte_selectionnee
		if chemin_carte_actuelle.is_empty():
			chemin_carte_actuelle = "res://level2.tscn"
		
		# Décharger l'ancienne carte
		carte_actuelle.queue_free()
		carte_actuelle = null
		camera_jeu = null
		
		# Attendre que Godot libère la mémoire
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Recharger la même carte
		var scene_carte = load(chemin_carte_actuelle) as PackedScene
		if scene_carte:
			carte_actuelle = scene_carte.instantiate()
			vue_jeu.add_child(carte_actuelle)
			camera_jeu = carte_actuelle.get_node_or_null("Camera2D") as Camera2D
			configurer_le_spawn_automatique()
			_connecter_boss_places_dans_la_carte()
			print("[Main] Niveau réinitialisé : ", chemin_carte_actuelle)
		else:
			push_error("[Main] Impossible de recharger le niveau : " + str(chemin_carte_actuelle))
	else:
		# Fallback : recharger toute la scène si aucune carte n'est chargée
		get_tree().reload_current_scene()

func quitter_jeu() -> void:
	definir_pause(false)
	get_tree().quit()

func revenir_au_menu() -> void:
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.hide()
	definir_pause(false)
	GlobalSettings.reinitialiser_partie()
	if timer_spawn and is_instance_valid(timer_spawn):
		timer_spawn.stop()
		timer_spawn.queue_free()
		timer_spawn = null
		
	if vue_jeu:
		for enfant in vue_jeu.get_children():
			enfant.queue_free()
	carte_actuelle = null
	camera_jeu = null
	
	# Afficher le menu principal au lieu de changer de scène
	afficher_main_menu()

func afficher_main_menu() -> void:
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.hide()
	if main_menu:
		main_menu.visible = true
		main_menu.move_to_front()
	if menu_select_overlay:
		menu_select_overlay.visible = false
	if menu_pause_overlay:
		menu_pause_overlay.visible = false
	definir_pause(true)

func afficher_menu_selection() -> void:
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.hide()
	if main_menu:
		main_menu.visible = false
	if menu_select_overlay:
		menu_select_overlay.visible = true
		menu_select_overlay.move_to_front()
	if menu_pause_overlay:
		menu_pause_overlay.visible = false
	definir_pause(true)

func reprendre_jeu_depuis_menu() -> void:
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.hide()
	if main_menu:
		main_menu.visible = false
	if menu_select_overlay:
		menu_select_overlay.visible = false
	if menu_pause_overlay:
		menu_pause_overlay.visible = false
	definir_pause(false)

func retourner_main_menu() -> void:
	if menu_select_overlay:
		menu_select_overlay.visible = false
	if main_menu:
		main_menu.visible = true
		main_menu.move_to_front()
	if menu_pause_overlay:
		menu_pause_overlay.visible = false
	definir_pause(true)

func _on_niveau_selectionne(chemin_niveau: String) -> void:
	GlobalSettings.carte_selectionnee = chemin_niveau
	print("[Main] Niveau sélectionné : ", chemin_niveau)
	
	# Cacher tous les menus et l'overlay game over
	if overlay_game_over and is_instance_valid(overlay_game_over):
		overlay_game_over.hide()
	if main_menu:
		main_menu.visible = false
	if menu_select_overlay:
		menu_select_overlay.visible = false
	if menu_pause_overlay:
		menu_pause_overlay.visible = false
	
	# Recharger la scène avec le nouveau niveau
	_charger_prochain_tableau(chemin_niveau)

# ==============================================================================
# GESTION DES ENTRÉES (SOURIS, CLAVIER, BOUTON RETOUR ANDROID)
# ==============================================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not GlobalSettings.partie_perdue:
		basculer_pause()

func _input(event: InputEvent) -> void:
	# Aucune mise en pause manuelle lorsque la partie est terminée (overlay Game Over actif)
	if GlobalSettings.partie_perdue:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_BACK, KEY_ESCAPE, KEY_P]:
			basculer_pause()
