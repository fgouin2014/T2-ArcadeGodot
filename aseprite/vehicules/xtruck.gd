class_name XTruckPlayer
extends VehicleActorBase

## XTruck Player Vehicle Controller pour Godot 4.7
## Dérive de VehicleActorBase pour le support complet d'ActorBase, StopMarkers et suivi caméra.
##
## Règles de Dégâts des Tranches (Slices) :
## - Attaque Ennemie : La 1ère tranche endommagée est OBLIGATOIREMENT Slice0 (arrière).
##   Les tranches suivantes sont prélevées une-à-une ALEATOIREMENT parmi les tranches intactes.
## - Tir du Joueur : Endommage directement et individuellement la tranche ciblée par le point d'impact.

signal player_died()

var van_impact_push: float = 0.0
var anim_time_ms: float = 0.0

@onready var sprite_body_main: Sprite2D = get_node_or_null("BodyNode/SpriteBodyMain") as Sprite2D
@onready var sprite_cabin_intact: Sprite2D = get_node_or_null("BodyNode/SpriteCabinTopIntact") as Sprite2D
@onready var sprite_cabin_damaged: Sprite2D = get_node_or_null("BodyNode/SpriteCabinTopDamaged") as Sprite2D
@onready var sprite_bed_intact: Sprite2D = get_node_or_null("BodyNode/SpriteBedIntact") as Sprite2D
@onready var sprite_bed_damaged: Sprite2D = get_node_or_null("BodyNode/SpriteBedDamaged") as Sprite2D

@onready var damage_slices: Array[Sprite2D] = [
	get_node_or_null("BodyNode/DamageParts/DamageSlice0") as Sprite2D,
	get_node_or_null("BodyNode/DamageParts/DamageSlice1") as Sprite2D,
	get_node_or_null("BodyNode/DamageParts/DamageSlice2") as Sprite2D,
	get_node_or_null("BodyNode/DamageParts/DamageSlice3") as Sprite2D,
	get_node_or_null("BodyNode/DamageParts/DamageSlice4") as Sprite2D,
	get_node_or_null("BodyNode/DamageParts/DamageSlice5") as Sprite2D,
	get_node_or_null("BodyNode/DamageParts/DamageSlice6") as Sprite2D
]

@onready var body_node: Node2D = get_node_or_null("BodyNode") as Node2D
@onready var wheels_node: Node2D = get_node_or_null("WheelsNode") as Node2D

func _ready() -> void:
	# Utiliser les valeurs @export de ActorBase au lieu de hardcoder
	# pv_max et pv_actuels sont gérés par ActorBase
	offset_lucarne_ratio_x = 0.15
	super._ready()
	add_to_group("player_vehicle")
	_update_visual_damage_states()

func _physics_process(delta: float) -> void:
	if not est_actif():
		return

	# Atténuation du recul
	van_impact_push = max(0.0, van_impact_push - 180.0 * delta)

	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	var camera_en_mouvement = false
	if camera:
		var delta_cam_x = camera.get_screen_center_position().x - _derniere_camera_x
		camera_en_mouvement = abs(delta_cam_x) > 0.05

	# Quand le xtruck est à l'arrêt (caméra immobile), les roues ne tournent pas et la carrosserie ne rebondit pas
	if camera_en_mouvement:
		anim_time_ms += delta * 1000.0
		if body_node:
			body_node.position.y = sin(anim_time_ms * 0.015) * 2.0
		_gerer_animation_roues(true)
	else:
		if body_node:
			body_node.position.y = 0.0
		_gerer_animation_roues(false)

	super._physics_process(delta)
	global_position.x += van_impact_push

func _gerer_animation_roues(en_roulement: bool) -> void:
	if wheels_node:
		for child in wheels_node.get_children():
			if child is AnimatedSprite2D:
				if en_roulement:
					if not child.is_playing(): child.play("roll")
				else:
					child.stop()
					child.frame = 0


# --- API DE DÉGÂTS & TRANCHES ---

## Degâts infligés par un ENNEMI (global)
func subir_degats(amount: int = 10) -> void:
	super.subir_degats(amount)  # Utiliser le système ActorBase
	_endommager_slice_ennemie()
	_update_visual_damage_states()

func subir_elimination() -> void:
	est_elimine = true
	player_died.emit()
	super.subir_elimination()

## Reçoit une attaque de choc (ex: XJug)
func take_jug_attack() -> void:
	subir_degats(35)
	apply_impact_push(60.0)

## Endommagement spécifique ENNEMI : Slice 0 en premier, puis une-à-une ALÉATOIREMENT
func _endommager_slice_ennemie() -> void:
	# 1. Si la Slice 0 n'est pas encore endommagée, c'est OBLIGATOIREMENT la première !
	if damage_slices.size() > 0 and damage_slices[0] and not damage_slices[0].visible:
		damage_slices[0].visible = true
		return

	# 2. Sinon, trouver toutes les tranches encore intactes
	var indices_intacts: Array[int] = []
	for i in range(1, damage_slices.size()):
		if damage_slices[i] and not damage_slices[i].visible:
			indices_intacts.append(i)

	# 3. Choisir une tranche intacte aléatoirement
	if indices_intacts.size() > 0:
		var idx_choisi = indices_intacts[randi() % indices_intacts.size()]
		damage_slices[idx_choisi].visible = true

## Degâts infligés par le JOUER via point d'impact direct
func hit_at_position(hit_global_pos: Vector2, amount: int = 10) -> void:
	super.subir_degats(amount)  # Utiliser le système ActorBase
	
	# Coordonnée X locale (0 à 242px)
	var local_x: float = to_local(hit_global_pos).x
	
	# Endommager individuellement la tranche ciblée par le tir joueur
	var slice_idx: int = int(clamp(local_x / 34.5, 0, 6))
	damage_slice(slice_idx)
	
	if local_x >= 90.0 and local_x <= 130.0:
		damage_cabin()
	elif local_x > 130.0 and local_x <= 190.0:
		damage_bed()

	_update_visual_damage_states()

func subir_degats_partie(_partie: String, amount: int = 10, pos_impact: Vector2 = Vector2.INF, _est_missile: bool = false) -> void:
	if pos_impact != Vector2.INF:
		hit_at_position(pos_impact, amount)
	else:
		subir_degats(amount)

func damage_slice(slice_index: int) -> void:
	if slice_index >= 0 and slice_index < damage_slices.size():
		var spr = damage_slices[slice_index]
		if spr: spr.visible = true

func damage_cabin() -> void:
	if sprite_cabin_intact: sprite_cabin_intact.visible = false
	if sprite_cabin_damaged: sprite_cabin_damaged.visible = true

func damage_bed() -> void:
	if sprite_bed_intact: sprite_bed_intact.visible = false
	if sprite_bed_damaged: sprite_bed_damaged.visible = true

func apply_impact_push(force: float) -> void:
	van_impact_push = force

func _update_visual_damage_states() -> void:
	var hp_pct: float = float(pv_actuels) / float(pv_max)
	if hp_pct <= 0.50:
		damage_bed()
		damage_cabin()


