class_name Xl4DoorBoss
extends Node2D

## Machine à États pour le Boss Skynet Door (t2_xl4door.tscn)
## Gère l'activation (automatique à l'écran, au tir, ou en test F6),
## les 3 phases de combat, les salves de missiles, les tirs des shooters, et l'ouverture progressive des portes.
##
## SOURCES DE VÉRITÉ :
##   - PV de chaque composant   → metadata/hp        sur le Sprite2D dans la scène
##   - Distance de slide portes → metadata/slide_distance sur le Sprite2D des portes
##   - Activation différée      → metadata/enabled = false masque les nœuds de phase 2/3
##   - Salves shooters          → metadata/salvo_count + metadata/fire_rate_frames

enum PhaseBoss {
	PHASE1_GENERATORS,
	TRANSITION_DOORS1_OPENING,
	PHASE2_ARMORS_AND_SHOOTERS,
	TRANSITION_DOORS2_OPENING,
	PHASE3_TIME_MACHINE_ACTIVE,
	COMPLETED
}

var phase_actuelle: PhaseBoss = PhaseBoss.PHASE1_GENERATORS
var deja_active: bool = false

# --- NŒUDS DE DÉCOR ET PORTES ---
@onready var door1_left: Sprite2D  = _trouver_noeud("xskynt1_doors") as Sprite2D
@onready var door1_right: Sprite2D = _trouver_noeud("xskynt1_doors2") as Sprite2D
@onready var door2_left: Sprite2D  = _trouver_noeud("xskynt2_doors2") as Sprite2D
@onready var door2_right: Sprite2D = _trouver_noeud("xskynt2_doors") as Sprite2D
@onready var time_machine_sprite: Sprite2D = _trouver_noeud("the_timemachine") as Sprite2D

# --- MARQUEURS DE SPAWN ---
@onready var spawn_gen_top_left:    Marker2D = _trouver_noeud("SpawnGeneratorTopLeft") as Marker2D
@onready var spawn_gen_bottom_left: Marker2D = _trouver_noeud("SpawnGeneratorBottomLeft") as Marker2D
@onready var spawn_gen_top_right:   Marker2D = _trouver_noeud("SpawnGeneratorTopRight") as Marker2D
@onready var spawn_gen_bottom_right:Marker2D = _trouver_noeud("SpawnGeneratorBottomRight") as Marker2D
@onready var spawn_shooter_left:    Marker2D = _trouver_noeud("SpawnShooterLeft") as Marker2D
@onready var spawn_shooter_right:   Marker2D = _trouver_noeud("SpawnShooterRight") as Marker2D
@onready var spawn_timemachine:     Marker2D = _trouver_noeud("SpawnTimeMachine") as Marker2D

# --- PV PAR COMPOSANT (initialisés depuis metadata/hp — source unique de vérité) ---
var pv_generateurs: Dictionary = {}
var pv_armures: Dictionary = {}

# --- ORDRE DÉTERMINISTE (évite l'itération aléatoire sur Dictionary) ---
const ORDRE_GENERATEURS: Array[String] = [
	"generator_top_left",
	"generator_bottom_left",
	"generator_top_right",
	"generator_bottom_right",
]
const ORDRE_ARMURES: Array[String] = [
	"xskynt2_armor_02", "xskynt2_armor_03", "xskynt2_armor_04", "xskynt2_armor_06",
	"xskynt2_armor_07", "xskynt2_armor_08", "xskynt2_armor_09", "xskynt2_armor_10",
	"xskynt2_armor_11", "xskynt2_armor_12", "xskynt2_armor_14", "xskynt2_armor_15",
	"xskynt2_armor_16", "xskynt2_armor_17",
	"xskynt2_armor_shooter_left", "xskynt2_armor_shooter_right",
]

# --- SCÈNES D'EFFETS (chargées dynamiquement) ---
var missile_scene: PackedScene = null
var expl2_scene: PackedScene   = null
var expl3_scene: PackedScene   = null
var elec_scene: PackedScene    = null

@export var cadence_missiles_generateurs: float = 2.5
@export var cadence_tirs_shooters: float        = 2.0
@export var cadence_elec_timemachine: float     = 1.8

var _chrono_gen_missiles: float = 2.0 # Tir quasi-immédiat dès activation
var _chrono_shooters: float     = 1.5
var _chrono_timemachine: float  = 1.0


# ============================================================
#  UTILITAIRES
# ============================================================

func _trouver_noeud(nom: String) -> Node:
	var n = get_node_or_null("lobby/" + nom)
	if n == null:
		n = get_node_or_null(nom)
	return n


# ============================================================
#  INITIALISATION
# ============================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Le décor de base est toujours visible
	visible = true
	var lobby_n = get_node_or_null("lobby")
	if lobby_n:
		lobby_n.visible = true

	# Respecte metadata/enabled = false : cache les nœuds de phase 2/3 dès le départ
	_appliquer_visibilite_initiale()

	# Chargement sécurisé des scènes d'effets
	if ResourceLoader.exists("res://aseprite/xmissile.tscn"):
		missile_scene = load("res://aseprite/xmissile.tscn")
	if ResourceLoader.exists("res://aseprite/effect/xexpl2.tscn"):
		expl2_scene = load("res://aseprite/effect/xexpl2.tscn")
	if ResourceLoader.exists("res://aseprite/effect/xexpl3.tscn"):
		expl3_scene = load("res://aseprite/effect/xexpl3.tscn")
	if ResourceLoader.exists("res://aseprite/effect/xelec.tscn"):
		elec_scene = load("res://aseprite/effect/xelec.tscn")

	# Initialisation PV depuis metadata/hp de la scène (source unique de vérité)
	for nom in ORDRE_GENERATEURS:
		var node = _trouver_noeud(nom)
		pv_generateurs[nom] = int(node.get_meta("hp", 3)) if node else 3

	for nom in ORDRE_ARMURES:
		var node = _trouver_noeud(nom)
		pv_armures[nom] = int(node.get_meta("hp", 3)) if node else 3

	phase_actuelle = PhaseBoss.PHASE1_GENERATORS
	_configurer_hitspots()
	_configurer_detecteur_ecran()

	# Auto-activation si déjà sur l'écran ou en mode test F6
	get_tree().create_timer(0.1).timeout.connect(_verifier_auto_activation)


func _appliquer_visibilite_initiale() -> void:
	## Tous les éléments sont physiquement présents et visibles dès le départ,
	## étagés selon leur z_index (Machine: 0, Portes 2: 1, Armures: 2, Portes 1: 3, Mur: 4, Générateurs: 5).
	## En Phase 1, seuls les HitAreas des générateurs sont interactifs.
	var lobby_n = get_node_or_null("lobby")
	if not lobby_n:
		return
	for child in lobby_n.get_children():
		if child is Sprite2D:
			child.visible = true
			var hit := child.get_node_or_null("HitArea") as Area2D
			if hit:
				var is_gen := "generator" in child.name.to_lower()
				hit.monitoring     = is_gen
				hit.input_pickable = is_gen

	# Forcer explicitement la visibilité de toutes les portes et de la machine
	door1_left  = _trouver_noeud("xskynt1_doors")  as Sprite2D
	door1_right = _trouver_noeud("xskynt1_doors2") as Sprite2D
	door2_left  = _trouver_noeud("xskynt2_doors2") as Sprite2D
	door2_right = _trouver_noeud("xskynt2_doors")  as Sprite2D
	if door1_left:  door1_left.visible  = true
	if door1_right: door1_right.visible = true
	if door2_left:  door2_left.visible  = true
	if door2_right: door2_right.visible = true
	if time_machine_sprite: time_machine_sprite.visible = true


func _configurer_detecteur_ecran() -> void:
	var notifier := get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
	if not notifier:
		# Position et rect identiques à ceux définis dans la scène
		notifier = VisibleOnScreenNotifier2D.new()
		notifier.name     = "VisibleOnScreenNotifier2D"
		notifier.position = Vector2(158, 44)
		notifier.rect     = Rect2(-160, -45, 320, 108)
		add_child(notifier)

	if not notifier.screen_entered.is_connected(activer_boss):
		notifier.screen_entered.connect(activer_boss)


func _verifier_auto_activation() -> void:
	if deja_active:
		return
	var cur_scene = get_tree().current_scene
	var p = get_parent()
	# Activation en scène isolée (F6) ou dans testchamber
	if (cur_scene == self
			or p == get_tree().root
			or (cur_scene and cur_scene.name == "testchamber")
			or (p and p.name == "testchamber")):
		print("[XL4DOOR] Mode Test détecté — Activation immédiate !")
		activer_boss()
		return

	var notifier := get_node_or_null("VisibleOnScreenNotifier2D") as VisibleOnScreenNotifier2D
	if notifier and notifier.is_on_screen():
		print("[XL4DOOR] Notifier sur écran — Activation immédiate !")
		activer_boss()


func activer_boss() -> void:
	if deja_active:
		return
	deja_active = true
	_chrono_gen_missiles = cadence_missiles_generateurs - 0.3
	print("[XL4DOOR] === BOSS ACTIVÉ — Phase 1 (Générateurs) en cours ! ===")


# ============================================================
#  CONFIGURATION DES HITSPOTS (souris + projectiles)
# ============================================================

func _configurer_hitspots() -> void:
	var lobby_n = get_node_or_null("lobby")
	if not lobby_n:
		return
	for sprite_child in lobby_n.get_children():
		if not (sprite_child is Sprite2D):
			continue
		var nom_partie: String = sprite_child.name
		var hit_area := sprite_child.get_node_or_null("HitArea") as Area2D
		if not hit_area:
			continue

		hit_area.collision_layer = 4
		hit_area.collision_mask  = 2

		# Mode souris (debug / test F6)
		hit_area.input_pickable = true
		if not hit_area.input_event.is_connected(_on_hitarea_input.bind(nom_partie)):
			hit_area.input_event.connect(_on_hitarea_input.bind(nom_partie))

		# Mode projectiles en jeu (area_entered)
		hit_area.monitoring = true
		if not hit_area.area_entered.is_connected(_on_hitarea_projectile.bind(nom_partie)):
			hit_area.area_entered.connect(_on_hitarea_projectile.bind(nom_partie))


func _on_hitarea_input(_viewport: Node, event: InputEvent, _shape_idx: int, partie: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		subir_degats_partie(partie, 1, get_global_mouse_position())


func _on_hitarea_projectile(area: Area2D, partie: String) -> void:
	## Reçoit les projectiles (xmissile, etc.) qui entrent dans la HitArea.
	## Lit metadata/degats sur l'Area2D si disponible, sinon 1 dégât.
	var degats: int = int(area.get_meta("degats", 1)) if area.has_meta("degats") else 1
	subir_degats_partie(partie, degats, area.global_position)


# ============================================================
#  BOUCLE DE JEU
# ============================================================

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not deja_active:
		return

	match phase_actuelle:
		PhaseBoss.PHASE1_GENERATORS:
			_chrono_gen_missiles += delta
			if _chrono_gen_missiles >= cadence_missiles_generateurs:
				_chrono_gen_missiles = 0.0
				_tirer_salves_generateurs()

		PhaseBoss.PHASE2_ARMORS_AND_SHOOTERS:
			_chrono_shooters += delta
			if _chrono_shooters >= cadence_tirs_shooters:
				_chrono_shooters = 0.0
				_tirer_attaques_shooters()

		PhaseBoss.PHASE3_TIME_MACHINE_ACTIVE:
			_chrono_timemachine += delta
			if _chrono_timemachine >= cadence_elec_timemachine:
				_chrono_timemachine = 0.0
				_tirer_electricite_timemachine()


# ============================================================
#  LOGIQUE DE TIR
# ============================================================

func _tirer_salves_generateurs() -> void:
	if missile_scene == null:
		return
	var gens := [
		{"name": "generator_top_left",     "marker": spawn_gen_top_left,     "fb": Vector2(334, 225)},
		{"name": "generator_bottom_left",  "marker": spawn_gen_bottom_left,  "fb": Vector2(334, 289)},
		{"name": "generator_top_right",    "marker": spawn_gen_top_right,    "fb": Vector2(590, 225)},
		{"name": "generator_bottom_right", "marker": spawn_gen_bottom_right, "fb": Vector2(590, 289)},
	]
	var cible := _get_cible()
	for g in gens:
		if pv_generateurs.get(g["name"], 0) > 0:
			_spawner_missile(g["marker"], g["fb"], cible)


func _tirer_attaques_shooters() -> void:
	if missile_scene == null:
		return
	var shooters := [
		{"name": "xskynt2_armor_shooter_left",  "marker": spawn_shooter_left,  "fb": Vector2(422, 262)},
		{"name": "xskynt2_armor_shooter_right", "marker": spawn_shooter_right, "fb": Vector2(502, 262)},
	]
	var cible := _get_cible()
	for s in shooters:
		if pv_armures.get(s["name"], 0) <= 0:
			continue
		var node = _trouver_noeud(s["name"])
		# Lit salvo_count et fire_rate_frames depuis les métadonnées de la scène
		var salvo: int           = int(node.get_meta("salvo_count",      1))  if node and node.has_meta("salvo_count")      else 1
		var rate_frames: int     = int(node.get_meta("fire_rate_frames", 30)) if node and node.has_meta("fire_rate_frames") else 30
		var delai_entre: float   = rate_frames / 60.0
		_tirer_salve(s["marker"], s["fb"], cible, salvo, delai_entre)


func _tirer_salve(marker: Marker2D, fallback: Vector2, cible: Vector2, salvo: int, delai: float) -> void:
	## Tire [salvo] missiles avec [delai] secondes entre chaque tir.
	for i in salvo:
		if i == 0:
			_spawner_missile(marker, fallback, cible)
		else:
			get_tree().create_timer(delai * i, false).timeout.connect(
				func(): _spawner_missile(marker, fallback, cible)
			)


func _spawner_missile(marker: Marker2D, fallback: Vector2, cible: Vector2) -> void:
	if missile_scene == null:
		return
	var pos: Vector2 = marker.global_position if marker else (global_position + fallback)
	var m = missile_scene.instantiate()
	var parent_cible := get_parent() if get_parent() else self
	parent_cible.add_child(m)
	var dir := (cible - pos).normalized()
	if m.has_method("initialiser_lancer"):
		m.initialiser_lancer(pos, dir)
	else:
		m.global_position = pos


func _tirer_electricite_timemachine() -> void:
	if elec_scene == null:
		return
	var pos: Vector2 = (spawn_timemachine.global_position
			if spawn_timemachine
			else global_position + Vector2(462, 258))
	var cible := _get_cible()
	var elec  = elec_scene.instantiate()

	# Phase 3 : la machine temporelle blesse le joueur
	if "degats"        in elec: elec.degats        = 1
	if "blesser_joueur" in elec: elec.blesser_joueur = true

	# Nombre et intervalle de décharges lus depuis la machine (metadata de la scène)
	var tm_node = _trouver_noeud("the_timemachine")
	if tm_node and tm_node.has_meta("xelec_count"):
		if "xelec_count" in elec: elec.xelec_count = tm_node.get_meta("xelec_count")
	if tm_node and tm_node.has_meta("xelec_interval_frames"):
		if "xelec_interval_frames" in elec: elec.xelec_interval_frames = tm_node.get_meta("xelec_interval_frames")

	var parent_cible := get_parent() if get_parent() else self
	parent_cible.add_child(elec)
	var dir := (cible - pos).normalized()
	if elec.has_method("initialiser_lancer"):
		elec.initialiser_lancer(pos, dir)
	else:
		elec.global_position = pos


func _get_cible() -> Vector2:
	var vp = get_viewport()
	if vp and vp.get_camera_2d():
		return vp.get_camera_2d().get_screen_center_position() + Vector2(0, -45)
	return global_position + Vector2(460, 250)


# ============================================================
#  GESTION DES DÉGÂTS
# ============================================================

func subir_degats(degats: int = 1) -> void:
	## Point d'entrée générique (tir non ciblé).
	## Utilise ORDRE_GENERATEURS / ORDRE_ARMURES pour un comportement déterministe.
	activer_boss()
	if phase_actuelle == PhaseBoss.PHASE1_GENERATORS:
		for k in ORDRE_GENERATEURS:
			if pv_generateurs.get(k, 0) > 0:
				subir_degats_partie(k, degats, global_position)
				return
	elif phase_actuelle == PhaseBoss.PHASE2_ARMORS_AND_SHOOTERS:
		for k in ORDRE_ARMURES:
			if pv_armures.get(k, 0) > 0:
				subir_degats_partie(k, degats, global_position)
				return


func subir_degats_partie(partie: String, degats: int = 1, pos_impact: Vector2 = Vector2.INF) -> void:
	activer_boss()
	var nom := partie.to_lower()
	print("[XL4DOOR] Impact reçu sur : '", nom, "' | Phase actuelle : ", phase_actuelle)

	if "generator" in nom:
		if phase_actuelle != PhaseBoss.PHASE1_GENERATORS:
			return
		var key := _clef_depuis_nom(nom, ORDRE_GENERATEURS)
		if key and pv_generateurs.get(key, 0) > 0:
			pv_generateurs[key] -= degats
			var node := _trouver_noeud(key) as CanvasItem
			_flash(node)
			var pt: Vector2 = pos_impact if pos_impact != Vector2.INF else (node.global_position if node is Node2D else global_position)
			_spawn_expl(expl2_scene, pt, 0.6)
			var hp_max: int = int(_trouver_noeud(key).get_meta("hp", 3)) if _trouver_noeud(key) else 3
			print("[XL4DOOR] ", key, " PV: ", max(0, pv_generateurs[key]), "/", hp_max)
			if pv_generateurs[key] <= 0:
				_detruire_generateur(key, node)
		return

	if "armor" in nom or "shooter" in nom:
		if phase_actuelle != PhaseBoss.PHASE2_ARMORS_AND_SHOOTERS:
			return
		var key := _clef_depuis_nom(nom, ORDRE_ARMURES)
		if key and pv_armures.get(key, 0) > 0:
			pv_armures[key] -= degats
			var node := _trouver_noeud(key) as CanvasItem
			_flash(node)
			var pt: Vector2 = pos_impact if pos_impact != Vector2.INF else (node.global_position if node is Node2D else global_position)
			_spawn_expl(expl2_scene, pt, 0.6)
			print("[XL4DOOR] Armure ", key, " PV: ", max(0, pv_armures[key]))
			if pv_armures[key] <= 0:
				_detruire_armure(key, node)
		return


func _clef_depuis_nom(nom: String, ordre: Array) -> String:
	## Retourne la clé de l'ordre qui correspond au nom reçu (sous-chaîne bidirectionnelle).
	for k in ordre:
		if k in nom or nom in k:
			return k
	return ""


# ============================================================
#  DESTRUCTION ET TRANSITIONS DE PHASE
# ============================================================

func _desactiver(nom_sprite: String) -> void:
	var sprite := _trouver_noeud(nom_sprite) as CanvasItem
	if sprite:
		sprite.visible = false
	var hit := (sprite.get_node_or_null("HitArea") as Area2D) if sprite else null
	if hit:
		hit.monitoring      = false
		hit.input_pickable  = false
		var col := hit.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col:
			col.set_deferred("disabled", true)


func _detruire_generateur(key: String, node: Node2D) -> void:
	_spawn_expl(expl3_scene, node.global_position if node else global_position, 0.7)
	_desactiver(key)
	print("[XL4DOOR] Générateur ", key, " DÉTRUIT !")
	for v in pv_generateurs.values():
		if v > 0:
			return
	_ouvrir_portes_phase1()


func _ouvrir_portes_phase1() -> void:
	phase_actuelle = PhaseBoss.TRANSITION_DOORS1_OPENING
	print("[XL4DOOR] Tous les générateurs détruits -> Ouverture des portes extérieures (Phase 1 -> 2) !")
	door1_left  = _trouver_noeud("xskynt1_doors")  as Sprite2D
	door1_right = _trouver_noeud("xskynt1_doors2") as Sprite2D
	if door1_left and door1_right:
		# Distances lues depuis metadata/slide_distance (source unique de vérité)
		var slide_l: float = door1_left.get_meta("slide_distance",  93.0)
		var slide_r: float = door1_right.get_meta("slide_distance", 93.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(door1_left,  "position:x", door1_left.position.x  - slide_l, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(door1_right, "position:x", door1_right.position.x + slide_r, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	# Révéler et activer uniquement les nœuds de phase 2 (armures avec metadata/trigger_target)
	_activer_noeuds_phase2()
	phase_actuelle = PhaseBoss.PHASE2_ARMORS_AND_SHOOTERS
	print("[XL4DOOR] Portes 1 ouvertes ! Phase 2 — Armures et Shooters actifs.")


func _activer_noeuds_phase2() -> void:
	## Rend visible et active les armures de phase 2 et les portes intérieures fermées.
	door2_left  = _trouver_noeud("xskynt2_doors2") as Sprite2D
	door2_right = _trouver_noeud("xskynt2_doors")  as Sprite2D
	if door2_left:
		door2_left.visible = true
	if door2_right:
		door2_right.visible = true

	var lobby_n = get_node_or_null("lobby")
	if not lobby_n:
		return
	for child in lobby_n.get_children():
		if not (child is Sprite2D):
			continue
		if "xskynt2_armor" in child.name.to_lower():
			child.visible = true
			var hit := child.get_node_or_null("HitArea") as Area2D
			if hit:
				hit.monitoring     = true
				hit.input_pickable = true


func _detruire_armure(key: String, node: Node2D) -> void:
	_spawn_expl(expl3_scene, node.global_position if node else global_position, 0.7)
	_desactiver(key)
	print("[XL4DOOR] Armure ", key, " DÉTRUITE !")
	for v in pv_armures.values():
		if v > 0:
			return
	_ouvrir_portes_phase2()


func _ouvrir_portes_phase2() -> void:
	phase_actuelle = PhaseBoss.TRANSITION_DOORS2_OPENING
	print("[XL4DOOR] Toutes les armures détruites -> Ouverture des portes intérieures (Phase 2 -> 3) !")
	door2_left  = _trouver_noeud("xskynt2_doors2") as Sprite2D
	door2_right = _trouver_noeud("xskynt2_doors")  as Sprite2D
	if door2_left:  door2_left.visible  = true
	if door2_right: door2_right.visible = true
	if door2_left and door2_right:
		# Distances lues depuis metadata/slide_distance (source unique de vérité)
		var slide_l: float = door2_left.get_meta("slide_distance",  88.0)
		var slide_r: float = door2_right.get_meta("slide_distance", 88.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(door2_left,  "position:x", door2_left.position.x  - slide_l, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(door2_right, "position:x", door2_right.position.x + slide_r, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		# Verrouiller les portes 2 escamotées dans les murs pour qu'elles ne réapparaissent jamais
		door2_left.visible = false
		door2_right.visible = false

	# Révéler la machine temporelle au centre
	if time_machine_sprite:
		time_machine_sprite.visible = true
	phase_actuelle = PhaseBoss.PHASE3_TIME_MACHINE_ACTIVE
	print("[XL4DOOR] Portes 2 ouvertes et escamotées ! Phase 3 — Machine Temporelle active.")


# ============================================================
#  EFFETS VISUELS
# ============================================================

func _flash(sprite: CanvasItem) -> void:
	if sprite == null:
		return
	sprite.modulate = Color(3.5, 3.5, 3.5, 1.0)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)


func _spawn_expl(scene: PackedScene, pos: Vector2, fallback_timer: float) -> void:
	## Fonction unifiée pour xexpl2 (hit léger) et xexpl3 (destruction).
	## [fallback_timer] : durée avant queue_free si pas d'AnimatedSprite2D.
	if scene == null or not is_inside_tree():
		return
	var e = scene.instantiate()
	e.global_position = pos
	e.z_index = 2000
	var parent_cible := get_parent() if get_parent() else self
	parent_cible.add_child(e)
	var a := e.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if a:
		var anim_name := "explose" if a.sprite_frames.has_animation("explose") else "default"
		a.play(anim_name)
		a.animation_finished.connect(e.queue_free)
	else:
		get_tree().create_timer(fallback_timer).timeout.connect(e.queue_free)
