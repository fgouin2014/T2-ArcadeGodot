extends Control

## Script refactorisé pour le Menu Principal Arcade (Terminator 2).

signal niveau_selectionne(chemin_niveau: String)
signal retour_menu_principal()

# Référence centralisée vers la liste des niveaux
var DICO_NIVEAUX: Array[Dictionary]:
	get: return GlobalSettings.DICO_NIVEAUX

@onready var liste_niveaux: VBoxContainer = find_child("ListeNiveaux", true, false) as VBoxContainer
var canvas_viseur: CanvasLayer = null
var sprite_viseur_rouge: Sprite2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_initialiser_viseur_rouge()
	_construire_menu_principal()
	_connecter_bouton_retour()

func _connecter_bouton_retour() -> void:
	var btn_retour = find_child("BoutonRetour", true, false)
	if btn_retour and not btn_retour.pressed.is_connected(_on_bouton_retour_pressed):
		btn_retour.pressed.connect(_on_bouton_retour_pressed)

func _on_bouton_retour_pressed() -> void:
	if retour_menu_principal.get_connections().size() > 0:
		emit_signal("retour_menu_principal")
	else:
		get_tree().change_scene_to_file("res://maps/Main.tscn")

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
	var chemin_complet = "res://" + nom_fichier
	GlobalSettings.carte_selectionnee = chemin_complet
	print("[MENU PRINCIPAL] Lancement de la mission : ", chemin_complet)
	
	if niveau_selectionne.get_connections().size() > 0:
		emit_signal("niveau_selectionne", chemin_complet)
	else:
		get_tree().change_scene_to_file("res://maps/Main.tscn")
