extends Control

## Script refactorisé pour le Menu Principal Arcade (Terminator 2).

const DICO_NIVEAUX: Array[Dictionary] = [
	{
		"fichier": "level1.tscn",
		"code": "MISSION 01",
		"titre": "LA GUERRE DU FUTUR (2029)",
		"desc": "Combattez les Endosquelettes et Hunter-Killers dans les ruines de L.A.",
		"actif": true
	},
	{
		"fichier": "level2.tscn",
		"code": "MISSION 02",
		"titre": "LA PLANQUE",
		"desc": "Protégez John et Sarah Connor contre les assauts ennemie.",
		"actif": true
	},
	{
		"fichier": "level3.tscn",
		"code": "MISSION 03",
		"titre": "LA POURSUITE",
		"desc": "Escortez le véhicule des civils en fuite.",
		"actif": true
	},
	{
		"fichier": "level4.tscn",
		"code": "MISSION 04",
		"titre": "LE CŒUR DE SKYNET",
		"desc": "Affrontez les défenses automatisées du noyau Skynet.",
		"actif": true
	},
	{
		"fichier": "",
		"code": "MISSION 05",
		"titre": "LE COFFRE CYBERDYNE",
		"desc": "Infiltration du complexe Cyberdyne (N/A pour le moment).",
		"actif": false
	},
	{
		"fichier": "level6.tscn",
		"code": "MISSION 06",
		"titre": "POURSUITE DE L'AUTOROUTE",
		"desc": "Course poursuite à grande vitesse en camion-citerne.",
		"actif": true
	},
	{
		"fichier": "level7.tscn",
		"code": "MISSION 07",
		"titre": "LA FONDERIE D'ACIER",
		"desc": "Le duel final contre le T-1000 dans le métal en fusion.",
		"actif": true
	},
	{
		"fichier": "testchamber.tscn",
		"code": "LABORATOIRE",
		"titre": "CHAMBRE DE TEST & DEBUG",
		"desc": "Zone d'essai pour tous les acteurs, armes et effets.",
		"actif": true
	},
	{
		"fichier": "level1_0.tscn",
		"code": "level1_0",
		"titre": "level1_0",
		"desc": "level1_0.",
		"actif": true
	}
]

@onready var liste_niveaux: VBoxContainer = find_child("ListeNiveaux", true, false) as VBoxContainer
var canvas_viseur: CanvasLayer = null
var sprite_viseur_rouge: Sprite2D = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_initialiser_viseur_rouge()
	_construire_menu_principal()

func _initialiser_viseur_rouge() -> void:
	canvas_viseur = CanvasLayer.new()
	canvas_viseur.layer = 128
	add_child(canvas_viseur)
	
	sprite_viseur_rouge = Sprite2D.new()
	sprite_viseur_rouge.name = "ViseurRougeMenu"
	sprite_viseur_rouge.texture = load("res://tsj/xmisc_02.png")
	sprite_viseur_rouge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_viseur_rouge.centered = true
	canvas_viseur.add_child(sprite_viseur_rouge)
	
	sprite_viseur_rouge.global_position = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenTouch:
		if sprite_viseur_rouge:
			sprite_viseur_rouge.global_position = event.position

func _construire_menu_principal() -> void:
	if liste_niveaux == null:
		return
		
	for enfant in liste_niveaux.get_children():
		enfant.queue_free()
		
	for data in DICO_NIVEAUX:
		_creer_carte_niveau(data)

func _creer_carte_niveau(data: Dictionary) -> void:
	var conteneur_btn = PanelContainer.new()
	conteneur_btn.custom_minimum_size = Vector2(780, 64)
	
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style_panel.border_width_left = 4
	style_panel.border_width_top = 1
	style_panel.border_width_right = 1
	style_panel.border_width_bottom = 1
	style_panel.border_color = Color(0.9, 0.1, 0.1, 1.0)
	style_panel.corner_radius_top_left = 4
	style_panel.corner_radius_top_right = 4
	style_panel.corner_radius_bottom_right = 4
	style_panel.corner_radius_bottom_left = 4
	conteneur_btn.add_theme_stylebox_override("panel", style_panel)
	
	var boite_h = HBoxContainer.new()
	boite_h.add_theme_constant_override("separation", 15)
	
	var lbl_code = Label.new()
	lbl_code.text = " " + data["code"] + " "
	lbl_code.add_theme_font_size_override("font_size", 14)
	lbl_code.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	boite_h.add_child(lbl_code)
	
	var boite_v = VBoxContainer.new()
	boite_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl_titre = Label.new()
	lbl_titre.text = data["titre"]
	lbl_titre.add_theme_font_size_override("font_size", 17)
	lbl_titre.add_theme_color_override("font_color", Color.WHITE)
	boite_v.add_child(lbl_titre)
	
	var lbl_desc = Label.new()
	lbl_desc.text = data["desc"]
	lbl_desc.add_theme_font_size_override("font_size", 12)
	lbl_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	boite_v.add_child(lbl_desc)
	
	boite_h.add_child(boite_v)
	
	var btn_lancer = Button.new()
	var est_actif = data.get("actif", true)
	btn_lancer.text = " JOUER ▶ " if est_actif else " 🔒 N/A "
	btn_lancer.disabled = not est_actif
	btn_lancer.custom_minimum_size = Vector2(110, 42)
	btn_lancer.add_theme_font_size_override("font_size", 14)
	btn_lancer.focus_mode = Control.FOCUS_NONE
	
	if est_actif:
		btn_lancer.pressed.connect(func(): _lancer_mission(data["fichier"]))
	boite_h.add_child(btn_lancer)
	
	conteneur_btn.add_child(boite_h)
	liste_niveaux.add_child(conteneur_btn)

func _lancer_mission(nom_fichier: String) -> void:
	GlobalSettings.carte_selectionnee = "res://" + nom_fichier
	print("[MENU PRINCIPAL] Lancement de la mission : ", GlobalSettings.carte_selectionnee)
	get_tree().call_deferred("change_scene_to_file", "res://maps/Main.tscn")
