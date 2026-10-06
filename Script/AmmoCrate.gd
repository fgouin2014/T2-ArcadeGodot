class_name AmmoCrate
extends Node2D

## Ammo Crate interactif — le joueur tire dessus pour ouvrir et obtenir un pickup.
##
## Options :
## - usage_unique : ouvre, donne le pickup, et le crate disparaît ensuite (pas de refermeture)
## - vitesse_ouverture : contrôle la vitesse de l'animation "open" (FPS)
## - chute_du_ciel : si coché, le crate tombe de y_depart_chute jusqu'à sa position initiale au sol
## - Déclencheur sur Arrêt Caméra : comme les acteurs, peut s'activer sur un StopMarker caméra

# ─── TYPE DE PICKUP ──────────────────────────────────────────────────────────
@export_enum(
	"Missile_x4 (xpickup_14)",
	"Chargeurs (xpickup_01)",
	"Coolant (xpickup_03)",
	"Shield (xpickup_05)",
	"Nuke (xpickup_07)",
	"Gatling (xpickup_09)",
	"Inconnu (xpickup_11)",
	"Shotgun Shell (xpickup_12)",
	"CPU (xpickup_16)",
	"Plasma (xpickup_18)",
	"Credit (xpickup_21)",
	"Bombe (xpickup_24)",
	"Inconnu B (xpickup_25)",
	"Inconnu C (xpickup_26)",
	"Shotgun (xpickup_29)",
	"Custom_Scene"
) var type_pickup: String = "Missile_x4 (xpickup_14)"
@export var scene_pickup_custom: PackedScene = null

# ─── SCÈNES CATALOGUE ────────────────────────────────────────────────────────
@export var scene_missile_pickup: PackedScene = preload("res://aseprite/xpickup_14_missile.tscn")
@export var scene_chargeur_pickup: PackedScene = preload("res://aseprite/xpickup_01_chargeur.tscn")
@export var scene_coolant_pickup: PackedScene = preload("res://aseprite/xpickup_03_coolant.tscn")
@export var scene_shield_pickup: PackedScene = preload("res://aseprite/xpickup_05_shield.tscn")
@export var scene_nuke_pickup: PackedScene = preload("res://aseprite/xpickup_07_nuke.tscn")
@export var scene_credit_pickup: PackedScene = preload("res://aseprite/xpickup_21_credit.tscn")
@export var scene_gatling_pickup: PackedScene = preload("res://aseprite/xpickup_09_gatling.tscn")
@export var scene_inconnu11_pickup: PackedScene = preload("res://aseprite/xpickup_11_unknown.tscn")
@export var scene_shotgun_shell_pickup: PackedScene = preload("res://aseprite/xpickup_12_shotgun_shell.tscn")
@export var scene_cpu_pickup: PackedScene = preload("res://aseprite/xpickup_16_cpu.tscn")
@export var scene_plasma_pickup: PackedScene = preload("res://aseprite/xpickup_18_plasma.tscn")
@export var scene_bombe_pickup: PackedScene = preload("res://aseprite/xpickup_24_bombe.tscn")
@export var scene_inconnu25_pickup: PackedScene = preload("res://aseprite/xpickup_25_unknown.tscn")
@export var scene_inconnu26_pickup: PackedScene = preload("res://aseprite/xpickup_26_unknown.tscn")
@export var scene_shotgun_pickup: PackedScene = preload("res://aseprite/xpickup_29_shotgun.tscn")
@export var quantite_missiles_par_item: int = 5
@export var offset_apparition: Vector2 = Vector2(0, 14)

# ─── COMPORTEMENT ────────────────────────────────────────────────────────────
@export_group("Comportement Crate")
## Si false, le crate est invisible et inactif jusqu'à activation par StopMarker ou code externe
@export var actif_au_demarrage: bool = true
## Usage unique : le crate disparaît après avoir donné l'item (pas de refermeture cyclique)
@export var usage_unique: bool = false
## Durée d'ouverture avant refermeture (ignoré si usage_unique = true)
@export var temps_ouverture_secondes: float = 2.0
## Vitesse de l'animation d'ouverture en FPS (default = 12, plus bas = plus lent)
@export var vitesse_ouverture: float = 12.0

@export_group("Positionnement Apparitions")
## Mode de positionnement pour les pickups spawnés.
## local_parallax_compatible = suit le parallax naturellement (recommandé pour décors dans ParallaxLayer)
## global_world_space = position fixe dans l'espace monde
@export_enum("local_parallax_compatible", "global_world_space") var mode_positionnement_apparitions: String = "local_parallax_compatible"

# ─── CHUTE DU CIEL ───────────────────────────────────────────────────────────
@export_group("Chute du Ciel")
## Si coché, le crate tombe de y_depart_chute jusqu'à sa position au sol
@export var chute_du_ciel: bool = false
## Position Y de départ de la chute (en coordonnées locales relatives au parent)
@export var y_depart_chute: float = 17.0
## Vitesse de chute en pixels/seconde
@export var vitesse_chute: float = 120.0

# ─── DÉCLENCHEUR SUR ARRÊT CAMÉRA ────────────────────────────────────────────
@export_group("Déclencheur sur Arrêt Caméra")
## Sélecteur visuel de StopMarker dans l'Inspecteur Godot
@export var declencheur_stop: NodePath
## Nom ou identifiant optionnel du StopMarker (ex: "Stop1")
@export var nom_stop_declencheur: String = ""
## activer_quand_atteint = activation dès que le stop est atteint (défaut). activer_a_la_reprise = activation quand la caméra repart après le stop.
@export_enum("activer_quand_atteint", "activer_a_la_reprise") var mode_activation_stop: String = "activer_quand_atteint"
## Délai (sec) entre le déclenchement du stop et l'activation du crate
@export var delai_activation_sec: float = 0.0

# ─── NŒUDS ───────────────────────────────────────────────────────────────────
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: Area2D = $HitArea

# ─── ÉTAT ─────────────────────────────────────────────────────────────────────
enum EtatCrate { INACTIF, CHUTE, FLASH, OPENING, OPENED, CLOSING }
var etat_actuel: EtatCrate = EtatCrate.FLASH
var pickup_deja_donne: bool = false
var _y_sol: float = 0.0
var _en_chute: bool = false
var _deja_active: bool = false
var _en_attente_activation: bool = false
var _camera_stop_declencheur: CameraStopDeclencheur = null

func _ready() -> void:
	_y_sol = position.y

	if anim_sprite:
		anim_sprite.animation_finished.connect(_sur_animation_terminee)

	var a_declencheur = CameraStopDeclencheur.est_configure(declencheur_stop, nom_stop_declencheur)

	if a_declencheur or not actif_au_demarrage:
		# Masqué et inactif jusqu'à l'activation par stop ou code externe
		_masquer()
		etat_actuel = EtatCrate.INACTIF
		if a_declencheur:
			call_deferred("_connecter_declencheur_stop")
	else:
		_activer_crate()

func _masquer() -> void:
	visible = false
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)

func _activer_crate() -> void:
	if _deja_active:
		return
	_deja_active = true
	visible = true
	if chute_du_ciel:
		position.y = y_depart_chute
		_en_chute = true
		etat_actuel = EtatCrate.CHUTE
		if hit_area:
			hit_area.set_deferred("monitoring", false)
			hit_area.set_deferred("monitorable", false)
		if anim_sprite:
			anim_sprite.play("flash")
	else:
		_passer_a_l_etat(EtatCrate.FLASH)

func _stop_declencheur_ignore_camera() -> bool:
	return _deja_active or _en_attente_activation

func _connecter_declencheur_stop() -> void:
	if _camera_stop_declencheur == null:
		_camera_stop_declencheur = CameraStopDeclencheur.new()
		_camera_stop_declencheur.configure(
			self,
			declencheur_stop,
			nom_stop_declencheur,
			mode_activation_stop,
			_on_stop_declenche,
			_stop_declencheur_ignore_camera
		)
	_camera_stop_declencheur.connect_signals()

func _exit_tree() -> void:
	if _camera_stop_declencheur:
		_camera_stop_declencheur.deconnecter()
		_camera_stop_declencheur = null

func _on_stop_declenche() -> void:
	if _deja_active or _en_attente_activation:
		return
	_en_attente_activation = true
	CameraStopDeclencheur.executer_avec_delai(self, delai_activation_sec, func():
		_en_attente_activation = false
		if not _deja_active and is_inside_tree():
			_activer_crate()
	)

func _physics_process(delta: float) -> void:
	if not _en_chute:
		return
	position.y = move_toward(position.y, _y_sol, vitesse_chute * delta)
	if position.y >= _y_sol:
		position.y = _y_sol
		_en_chute = false
		_passer_a_l_etat(EtatCrate.FLASH)

# ─── API DE DÉGÂTS ────────────────────────────────────────────────────────────
func subir_degats_sur_enfant(_enfant: Node, _quantite: int) -> void:
	subir_degats(_quantite)

func subir_degats(_quantite: int = 1) -> void:
	if etat_actuel == EtatCrate.FLASH:
		_ouvrir_caisse()

func _ouvrir_caisse() -> void:
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", false)
	_passer_a_l_etat(EtatCrate.OPENING)

# ─── MACHINE À ÉTATS ──────────────────────────────────────────────────────────
func _passer_a_l_etat(nouvel_etat: EtatCrate) -> void:
	etat_actuel = nouvel_etat
	if anim_sprite == null:
		return

	match etat_actuel:
		EtatCrate.FLASH:
			if hit_area:
				hit_area.set_deferred("monitoring", false)
				hit_area.set_deferred("monitorable", true)
			anim_sprite.play("flash")

		EtatCrate.OPENING:
			# Applique la vitesse d'ouverture configurable
			anim_sprite.sprite_frames.set_animation_speed("open", vitesse_ouverture)
			anim_sprite.play("open")

		EtatCrate.OPENED:
			anim_sprite.play("opened")
			if not pickup_deja_donne:
				pickup_deja_donne = true
				_faire_apparaitre_pickups()

			if usage_unique:
				# Disparaît après un court délai
				get_tree().create_timer(0.5, false).timeout.connect(func():
					if is_instance_valid(self):
						queue_free()
				)
			else:
				# Refermeture cyclique après temps_ouverture_secondes
				get_tree().create_timer(temps_ouverture_secondes, false).timeout.connect(func():
					if is_instance_valid(self) and etat_actuel == EtatCrate.OPENED:
						_passer_a_l_etat(EtatCrate.CLOSING)
				)

		EtatCrate.CLOSING:
			anim_sprite.play("close")

func _sur_animation_terminee() -> void:
	if anim_sprite == null:
		return
	var anim_jouee = anim_sprite.animation
	match anim_jouee:
		"open":
			_passer_a_l_etat(EtatCrate.OPENED)
		"close":
			# Réinitialisation pour usage répété
			pickup_deja_donne = false
			_passer_a_l_etat(EtatCrate.FLASH)

# ─── SPAWN PICKUP ─────────────────────────────────────────────────────────────
func _faire_apparaitre_pickups() -> void:
	var conteneur_parent = get_parent() if get_parent() else self
	var centre_base = global_position + offset_apparition

	if "Missile_x4" in type_pickup:
		var offsets_de_4 = [
			Vector2(-4.5, -4.5),
			Vector2(4.5, -4.5),
			Vector2(-4.5, 4.5),
			Vector2(4.5, 4.5)
		]
		for offset_p in offsets_de_4:
			var scene_a_instancier = scene_missile_pickup
			if scene_a_instancier:
				var item = scene_a_instancier.instantiate() as Node2D
				if item:
					if mode_positionnement_apparitions == "global_world_space":
						item.global_position = centre_base + offset_p
					else:
						item.position = conteneur_parent.to_local(centre_base + offset_p)
					item.z_index = z_index + 10
					if "quantite" in item:
						item.quantite = quantite_missiles_par_item
					conteneur_parent.add_child(item)
					print("[AMMO CRATE] Pickup missile spawned à : ", item.global_position)
	else:
		var scene_a_instancier: PackedScene = scene_pickup_custom
		if "01" in type_pickup:
			scene_a_instancier = scene_chargeur_pickup
		elif "03" in type_pickup:
			scene_a_instancier = scene_coolant_pickup
		elif "05" in type_pickup:
			scene_a_instancier = scene_shield_pickup
		elif "07" in type_pickup:
			scene_a_instancier = scene_nuke_pickup
		elif "09" in type_pickup:
			scene_a_instancier = scene_gatling_pickup
		elif "11" in type_pickup:
			scene_a_instancier = scene_inconnu11_pickup
		elif "12" in type_pickup:
			scene_a_instancier = scene_shotgun_shell_pickup
		elif "16" in type_pickup:
			scene_a_instancier = scene_cpu_pickup
		elif "18" in type_pickup:
			scene_a_instancier = scene_plasma_pickup
		elif "21" in type_pickup:
			scene_a_instancier = scene_credit_pickup
		elif "24" in type_pickup:
			scene_a_instancier = scene_bombe_pickup
		elif "25" in type_pickup:
			scene_a_instancier = scene_inconnu25_pickup
		elif "26" in type_pickup:
			scene_a_instancier = scene_inconnu26_pickup
		elif "29" in type_pickup:
			scene_a_instancier = scene_shotgun_pickup

		if scene_a_instancier:
			var item = scene_a_instancier.instantiate() as Node2D
			if item:
				if mode_positionnement_apparitions == "global_world_space":
					item.global_position = centre_base
				else:
					item.position = conteneur_parent.to_local(centre_base)
				item.z_index = z_index + 10
				conteneur_parent.add_child(item)
				print("[AMMO CRATE] Pickup ", type_pickup, " spawned à : ", item.global_position)
