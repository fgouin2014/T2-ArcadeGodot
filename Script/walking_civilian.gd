class_name WalkingCivilian
extends ActorBase

## Script complet pour civils et alliés (Young John Connor & Sarah Connor).

@export_enum("marche_et_take_au_marqueur", "marche_libre", "scan_cinematique") var comportement_civil: String = "marche_et_take_au_marqueur"

@export_enum(
	"aucun",
	"xpickup_29", "xpickup_17", "xpickup_18", "xpickup_21",
	"xpickup_12", "xpickup_14", "xpickup_16", "xpickup_07",
	"xpickup_09", "xpickup_11", "xpickup_01", "xpickup_03",
	"xpickup_05", "xpickup_24"
) var objet_a_dropper: String = "xpickup_29"

@export var drop_aleatoire: bool = false       # true = xyjc (drop aléatoire en marchant), false = xsarah (drop au Marker2D Take)
@export var probabilite_drop: float = 0.25    # Probabilité par cycle de marche (ex: 25%)
@export var temps_entre_cycles: float = 5.0   # Secondes entre chaque vérification de drop aléatoire

# --- ÉTAT INTERNE ---
var _marqueur_take: Marker2D = null
var _a_fait_take: bool = false
var _en_sequence_action: bool = false
var _vitesse_sauvegardee: float = 40.0

func _ready() -> void:
	super._ready()
	if vitesse_deplacement <= 0.0:
		vitesse_deplacement = 40.0
	_vitesse_sauvegardee = vitesse_deplacement

func activer_acteur() -> void:
	super.activer_acteur()
	_vitesse_sauvegardee = vitesse_deplacement if vitesse_deplacement > 0.0 else 40.0
	
	call_deferred("_rechercher_marqueur_take")
	
	match comportement_civil:
		"scan_cinematique":
			_arreter_marche()
			if possede_animation("scan"):
				jouer_animation("scan")
			elif possede_animation("idle"):
				jouer_animation("idle")
		_:
			_demarrer_marche()
			_boucle_comportement_civil()

func _rechercher_marqueur_take() -> void:
	var root = get_parent()
	if root == null:
		return
	var marqueurs = root.find_children("*Take*", "Marker2D", true, false)
	if marqueurs.size() > 0:
		_marqueur_take = marqueurs[0] as Marker2D
		print("[CIVIL] Marker2D 'Take' détecté à X=", _marqueur_take.global_position.x)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Détection dynamique du Marker2D "Take" pendant la marche
	if deja_active and not est_elimine and not _en_sequence_action and _marqueur_take and not _a_fait_take:
		if abs(global_position.x - _marqueur_take.global_position.x) < 16.0:
			_jouer_sequence_take()

func _boucle_comportement_civil() -> void:
	while deja_active and not est_elimine:
		await get_tree().create_timer(temps_entre_cycles).timeout
		if est_elimine or not deja_active or _en_sequence_action:
			continue

		# Drop aléatoire pendant la marche (Young John Connor)
		if drop_aleatoire and objet_a_dropper != "aucun":
			if randf() < probabilite_drop:
				await _jouer_sequence_drop_aleatoire()

func _jouer_sequence_take() -> void:
	_a_fait_take = true
	_en_sequence_action = true
	_arreter_marche()

	if possede_animation("take"):
		jouer_animation("take")
		await _attendre_fin_animation(1.2)
	elif possede_animation("crouch"):
		jouer_animation("crouch")
		await get_tree().create_timer(1.0).timeout

	# Déposer l'objet au pied du civil si configuré
	if objet_a_dropper != "aucun":
		if possede_animation("drop"):
			jouer_animation("drop")
			await _attendre_fin_animation(0.8)
		_dropper_pickup()

	_en_sequence_action = false
	_demarrer_marche()

func _jouer_sequence_drop_aleatoire() -> void:
	_en_sequence_action = true
	_arreter_marche()

	if possede_animation("drop"):
		jouer_animation("drop")
		await _attendre_fin_animation(0.8)
	
	_dropper_pickup()
	
	_en_sequence_action = false
	_demarrer_marche()

func _demarrer_marche() -> void:
	vitesse_deplacement = _vitesse_sauvegardee if _vitesse_sauvegardee > 0.0 else 40.0
	if possede_animation("walk"):
		jouer_animation("walk")

func _arreter_marche() -> void:
	vitesse_deplacement = 0.0

func _dropper_pickup() -> void:
	if objet_a_dropper == "aucun":
		return
	var path_pickup = "res://tsj/" + objet_a_dropper + ".png"
	if not ResourceLoader.exists(path_pickup):
		print("[CIVIL DROP] Texture introuvable : ", path_pickup)
		return

	var noeud_pickup = Node2D.new()
	noeud_pickup.name = "Pickup_" + objet_a_dropper

	var spr = Sprite2D.new()
	spr.texture = load(path_pickup)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	noeud_pickup.add_child(spr)

	var area = Area2D.new()
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	area.add_child(col)
	noeud_pickup.add_child(area)

	var script_pickup = GDScript.new()
	script_pickup.source_code = """extends Node2D
var nom_pickup: String = \"%s\"
func subir_degats(_d: int = 1) -> void:
	print(\"[PICKUP] Ramassé : \", nom_pickup)
	queue_free()
""" % objet_a_dropper
	noeud_pickup.set_script(script_pickup)

	noeud_pickup.global_position = global_position + Vector2(0, 20.0)
	get_parent().add_child(noeud_pickup)
	print("[CIVIL DROP] ", name, " a déposé : ", objet_a_dropper)

func _attendre_fin_animation(duree_fallback: float) -> void:
	if anim_sprite and anim_sprite.sprite_frames:
		var current_anim = anim_sprite.animation
		if anim_sprite.sprite_frames.has_animation(current_anim):
			if not anim_sprite.sprite_frames.get_animation_loop(current_anim):
				await anim_sprite.animation_finished
				return
	await get_tree().create_timer(duree_fallback).timeout
