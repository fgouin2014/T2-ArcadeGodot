@tool
class_name TextTriggerMarker
extends Marker2D

## Marker2D permettant d'afficher une séquence de textes Bitmap (diapositives)
## avec gestion de multiligne (\n, paragraphes), choix de polices et alignement.
## Supporte l'intro du niveau, le passage de la caméra ou un StopMarker.
## Réagit en direct (Live Reload) aux changements de propriétés dans l'inspecteur.

signal sequence_terminee()

@export_group("Textes & Séquence")
## Liste des diapositives de texte à afficher successivement.
## Chaque élément peut contenir des retours à la ligne (\n).
@export_multiline var pages_texte: Array[String] = [
	"The T-1000 has you trapped \n in the Steel Mill",
	"Protect John Connor"
]:
	set(valeur):
		pages_texte = valeur
		_actualiser_affichage_live()

## Durée d'affichage de chaque message en secondes (ex: 2.5s).
@export var duree_par_texte_sec: float = 2.5
## Temps de noir/pause entre chaque message (ex: 0.5s).
@export var pause_entre_textes_sec: float = 0.5
## Délai d'attente avant le tout premier texte.
@export var delai_initial_sec: float = 0.0

@export_group("Apparence Bitmap")
## Dossier de la police Bitmap à utiliser.
@export_enum("xfonts_blue", "xfonts_red", "xfonts_white", "xfonts_trueblue", "xfonts2_white") var dossier_police: String = "xfonts_blue":
	set(valeur):
		dossier_police = valeur
		_actualiser_affichage_live()

## Alignement du texte multi-lignes.
@export_enum("centre", "gauche", "droite") var alignement: String = "centre":
	set(valeur):
		alignement = valeur
		_actualiser_affichage_live()

## Teinte modulate appliquée aux glyphes (laisser à Blanc Color.WHITE pour conserver la couleur d'origine des polices pré-rendues, ou teinter xfonts_white).
@export var couleur_texte: Color = Color.WHITE:
	set(valeur):
		couleur_texte = valeur
		_actualiser_affichage_live()

## Échelle des pixels des lettres (1.0 = normal, 2.0 = double).
@export var echelle_pixel: float = 1.0:
	set(valeur):
		echelle_pixel = valeur
		_actualiser_affichage_live()

## Espacement vertical entre les lignes en pixels.
@export var espacement_lignes_px: float = 2.0:
	set(valeur):
		espacement_lignes_px = valeur
		_actualiser_affichage_live()

## Si coché, ajoute un fond noir semi-transparent derrière le texte pour la lisibilité.
@export var afficher_boite_fond: bool = true:
	set(valeur):
		afficher_boite_fond = valeur
		_actualiser_affichage_live()

## Opacité de la boîte de fond (0.0 à 1.0).
@export_range(0.0, 1.0) var opacite_fond: float = 0.65:
	set(valeur):
		opacite_fond = valeur
		_actualiser_affichage_live()

@export_group("Positionnement & Rendu")
## Si true, le texte s'affiche sur le HUD (centré sur l'écran et fixe avec la caméra).
## Si false, le texte s'affiche à la position globale de ce Marker2D dans le monde.
@export var afficher_sur_hud: bool = true:
	set(valeur):
		afficher_sur_hud = valeur
		_actualiser_affichage_live()

## Décalage vertical par rapport au centre de l'écran (ex: -30 pour monter, 40 pour descendre).
@export var decalage_y_hud: float = 0.0:
	set(valeur):
		decalage_y_hud = valeur
		_actualiser_affichage_live()

## Bouton d'action pour tester / rejouer immédiatement la séquence depuis l'inspecteur
@export var rejouer_test_maintenant: bool = false:
	set(valeur):
		if valeur:
			rejouer_sequence_force()

@export_group("Déclencheur")
## Mode d'activation du texte :
## - "au_demarrage_ou_intro" : se déclenche dès l'intro de la map (ou au démarrage).
## - "proximite_camera" : se déclenche quand la caméra atteint ce marqueur en X.
## - "sur_stop_camera" : se déclenche quand un StopMarker caméra est atteint.
## - "proximite_acteur" : se déclenche quand un acteur spécifique passe devant.
@export_enum("au_demarrage_ou_intro", "proximite_camera", "sur_stop_camera", "proximite_acteur") var mode_declenchement: String = "au_demarrage_ou_intro"

## Alignement caméra si mode "proximite_camera" (Centre_Viseur, Bord_Gauche, Bord_Droit).
@export_enum("Centre_Viseur", "Bord_Gauche", "Bord_Droit") var alignement_camera: String = "Centre_Viseur"
## StopMarker cible si mode "sur_stop_camera" (ou parent si sous un StopMarker).
@export var stop_associe: NodePath
## Acteur à surveiller si mode "proximite_acteur".
@export var acteur_surveille: NodePath
## Distance de détection en pixels pour caméra ou acteur.
@export var distance_declenchement_px: float = 16.0
## Si coché, ne se déclenche qu'une seule fois.
@export var declencher_une_seule_fois: bool = true

var _deja_declenche: bool = false
var _layer_hud: CanvasLayer = null
var _container_root: Control = null
var _bg_rect: ColorRect = null
var _bitmap_label: BitmapText = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if mode_declenchement == "au_demarrage_ou_intro":
		call_deferred("declencher_sequence")
	elif mode_declenchement == "sur_stop_camera":
		call_deferred("_connecter_stop")

func _connecter_stop() -> void:
	var stop_node: Node = null
	if stop_associe != null and not stop_associe.is_empty():
		stop_node = get_node_or_null(stop_associe)
	elif get_parent() and get_parent().has_signal("stop_enclenche"):
		stop_node = get_parent()
	if stop_node and stop_node.has_signal("stop_enclenche"):
		stop_node.stop_enclenche.connect(declencher_sequence)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or (_deja_declenche and declencher_une_seule_fois):
		return

	if mode_declenchement == "proximite_camera":
		var cam := get_viewport().get_camera_2d()
		if cam:
			var demi_lucarne = 160.0
			if "largeur_lucarne" in cam:
				demi_lucarne = float(cam.largeur_lucarne) / 2.0
			
			var pos_cible = global_position.x
			match alignement_camera:
				"Bord_Gauche":
					pos_cible = global_position.x + demi_lucarne
				"Bord_Droit":
					pos_cible = global_position.x - demi_lucarne
				_:
					pos_cible = global_position.x
			
			var centre_cam = cam.get_screen_center_position().x
			if centre_cam >= pos_cible - distance_declenchement_px:
				declencher_sequence()

	elif mode_declenchement == "proximite_acteur":
		if acteur_surveille != null and not acteur_surveille.is_empty():
			var act = get_node_or_null(acteur_surveille)
			if act is Node2D and abs(act.global_position.x - global_position.x) <= distance_declenchement_px:
				declencher_sequence()

## Lance la séquence de textes
func declencher_sequence() -> void:
	if _deja_declenche and declencher_une_seule_fois:
		return
	if pages_texte.is_empty():
		return

	if declencher_une_seule_fois:
		_deja_declenche = true

	if delai_initial_sec > 0.0:
		get_tree().create_timer(delai_initial_sec, false).timeout.connect(_lancer_boucle_textes)
	else:
		_lancer_boucle_textes()

func _lancer_boucle_textes() -> void:
	_creer_structure_affichage()
	
	for i in range(pages_texte.size()):
		var texte = pages_texte[i]
		_afficher_texte(texte)
		await get_tree().create_timer(duree_par_texte_sec, false).timeout
		
		# Pause entre textes (sauf après le tout dernier)
		_masquer_texte()
		if i < pages_texte.size() - 1 and pause_entre_textes_sec > 0.0:
			await get_tree().create_timer(pause_entre_textes_sec, false).timeout

	_nettoyer_structure()
	sequence_terminee.emit()

func _creer_structure_affichage() -> void:
	if _container_root != null:
		return

	_container_root = Control.new()
	_container_root.name = "TextTriggerContainer"
	_container_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if afficher_boite_fond:
		_bg_rect = ColorRect.new()
		_bg_rect.name = "BackgroundBox"
		_bg_rect.color = Color(0.0, 0.0, 0.0, opacite_fond)
		_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_container_root.add_child(_bg_rect)

	_bitmap_label = BitmapText.new()
	_bitmap_label.name = "BitmapTextLabel"
	_bitmap_label.font_folder = "res://images/fonts/" + dossier_police
	_bitmap_label.alignement = alignement
	_bitmap_label.glyph_modulate = couleur_texte
	_bitmap_label.pixel_scale = echelle_pixel
	_bitmap_label.espacement_lignes_px = espacement_lignes_px
	_bitmap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container_root.add_child(_bitmap_label)

	if afficher_sur_hud:
		_layer_hud = CanvasLayer.new()
		_layer_hud.name = "CanvasTextTrigger"
		_layer_hud.layer = 110 # Sous le réticule viseur (layer 120) et au-dessus du jeu
		_layer_hud.add_child(_container_root)
		add_child(_layer_hud)
	else:
		_container_root.global_position = global_position
		get_parent().add_child(_container_root)

func _afficher_texte(texte: String) -> void:
	if _bitmap_label == null:
		return
	
	_bitmap_label.set_text(texte)
	_container_root.show()

	# Recalcul de la taille et centrage
	var txt_size = _bitmap_label.size
	var padding = Vector2(16.0, 8.0) * echelle_pixel

	if afficher_boite_fond and _bg_rect:
		_bg_rect.size = txt_size + (padding * 2.0)
		_bg_rect.position = -_bg_rect.size / 2.0
		_bitmap_label.position = _bg_rect.position + padding
	else:
		_bitmap_label.position = -txt_size / 2.0

	if afficher_sur_hud:
		var viewport_sz = get_viewport().get_visible_rect().size
		_container_root.position = (viewport_sz / 2.0) + Vector2(0.0, decalage_y_hud)

func _masquer_texte() -> void:
	if _container_root:
		_container_root.hide()

func _nettoyer_structure() -> void:
	if _layer_hud:
		_layer_hud.queue_free()
		_layer_hud = null
	elif _container_root:
		_container_root.queue_free()
		_container_root = null
	_bitmap_label = null
	_bg_rect = null

## Réactualise en temps réel le texte et le style affiché si le composant est actif
func _actualiser_affichage_live() -> void:
	if not is_inside_tree():
		return

	if is_instance_valid(_bitmap_label):
		_bitmap_label.font_folder = "res://images/fonts/" + dossier_police
		_bitmap_label.alignement = alignement
		_bitmap_label.glyph_modulate = couleur_texte
		_bitmap_label.pixel_scale = echelle_pixel
		_bitmap_label.espacement_lignes_px = espacement_lignes_px
		if not pages_texte.is_empty():
			_bitmap_label.set_text(pages_texte[0])

	if is_instance_valid(_bg_rect):
		_bg_rect.visible = afficher_boite_fond
		_bg_rect.color = Color(0.0, 0.0, 0.0, opacite_fond)

	if is_instance_valid(_bitmap_label) and is_instance_valid(_container_root):
		var txt_size = _bitmap_label.size
		var padding = Vector2(16.0, 8.0) * echelle_pixel
		if afficher_boite_fond and is_instance_valid(_bg_rect):
			_bg_rect.size = txt_size + (padding * 2.0)
			_bg_rect.position = -_bg_rect.size / 2.0
			_bitmap_label.position = _bg_rect.position + padding
		else:
			_bitmap_label.position = -txt_size / 2.0

		if afficher_sur_hud and get_viewport():
			var viewport_sz = get_viewport().get_visible_rect().size
			_container_root.position = (viewport_sz / 2.0) + Vector2(0.0, decalage_y_hud)
		else:
			_container_root.global_position = global_position

## Force le rejeu immédiat de la séquence depuis l'inspecteur
func rejouer_sequence_force() -> void:
	_deja_declenche = false
	_nettoyer_structure()
	declencher_sequence()

