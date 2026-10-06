class_name SceneryActorBase
extends Node2D

## Classe de base légère pour les éléments de décor destructibles immobiles (réservoirs, portes, murs).
## Dérive directement de Node2D pour être assignée sur n'importe quel décor sans conflit de type CharacterBody2D.

@export var pv_max: int = 5
@export var actif_au_demarrage: bool = true
@export var delai_activation_sec: float = 0.0
@export var nom_stop_declencheur: String = ""
@export var deverrouiller_stop_a_la_mort: bool = true ## Si true, déverrouille le stop caméra lié lors de la destruction de cet élément
@export var scene_explosion_piece: PackedScene = preload("res://aseprite/effect/xexpl3.tscn")

## Points de score accordés au joueur lors de la destruction
@export var points_score: int = 150

@export_group("Positionnement Apparitions")
## Mode de positionnement pour les explosions et pickups spawnés par cet élément.
## local_parallax_compatible = suit le parallax naturellement (recommandé pour décors dans ParallaxLayer)
## global_world_space = position fixe dans l'espace monde (utile pour éléments mobiles)
@export_enum("local_parallax_compatible", "global_world_space") var mode_positionnement_apparitions: String = "local_parallax_compatible"

var pv_actuels: int = 5
var deja_active: bool = false
var est_elimine: bool = false
var _en_attente_activation: bool = false

@onready var notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _ready() -> void:
	pv_actuels = pv_max
	_masquer_visuel()
	
	if notifier:
		if not notifier.screen_entered.is_connected(_on_ecran_entre):
			notifier.screen_entered.connect(_on_ecran_entre)
	
	_verifier_ecran_initial()

func _est_dans_ou_derriere_vue_camera() -> bool:
	var vp = get_viewport()
	if vp and vp.get_camera_2d():
		var camera = vp.get_camera_2d()
		var centre_x = camera.get_screen_center_position().x
		var demi_l = 160.0
		if "largeur_lucarne" in camera:
			demi_l = float(camera.largeur_lucarne) / 2.0
		if global_position.x <= (centre_x + demi_l + 30.0):
			return true
	return false

func _verifier_ecran_initial() -> void:
	if not deja_active and actif_au_demarrage:
		if _est_dans_ou_derriere_vue_camera():
			_on_ecran_entre()

func _masquer_visuel() -> void:
	var s = get_node_or_null("Sprite2D") as Sprite2D
	if s:
		s.hide()
	if anim_sprite:
		anim_sprite.hide()

func _afficher_visuel() -> void:
	var s = get_node_or_null("Sprite2D") as Sprite2D
	if s:
		s.show()
	if anim_sprite:
		anim_sprite.show()

func _on_ecran_entre() -> void:
	if not deja_active and not _en_attente_activation and actif_au_demarrage:
		_en_attente_activation = true
		if delai_activation_sec > 0.0:
			await get_tree().create_timer(delai_activation_sec, false).timeout
		_en_attente_activation = false
		if not deja_active and is_inside_tree() and not est_elimine:
			activer_acteur()

func activer_acteur() -> void:
	deja_active = true
	_afficher_visuel()

func subir_degats(quantite: int = 1) -> void:
	if est_elimine:
		return
	pv_actuels -= quantite
	if pv_actuels <= 0:
		subir_elimination()

func subir_elimination() -> void:
	if est_elimine:
		return
	est_elimine = true
	
	# Ajouter les points pour la destruction
	GlobalSettings.ajouter_score(points_score)
	
	if deverrouiller_stop_a_la_mort:
		_deverrouiller_stop_lie()
	queue_free()

func _deverrouiller_stop_lie() -> void:
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera and camera.has_method("deverrouiller_stop"):
		camera.deverrouiller_stop(nom_stop_declencheur)