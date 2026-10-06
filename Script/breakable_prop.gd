class_name BreakableProp
extends Node2D

enum ExplosionType { NONE, PETITE, MOYENNE, GRANDE, PERSONNALISEE }
enum ExplosionPattern { SIMPLE, DOUBLE, CASCADE }
@export var explosion_type: ExplosionType = ExplosionType.PETITE
@export var custom_explosion_scene: PackedScene = null
@export var explosion_pattern: ExplosionPattern = ExplosionPattern.SIMPLE

func _get_explosion_scene() -> PackedScene:
	match explosion_type:
		ExplosionType.PETITE:
			return load("res://aseprite/effect/xexpl1.tscn")
		ExplosionType.MOYENNE:
			return load("res://aseprite/effect/xexpl2.tscn")
		ExplosionType.GRANDE:
			return load("res://aseprite/effect/xexpl3.tscn")
		ExplosionType.PERSONNALISEE:
			return custom_explosion_scene
		ExplosionType.NONE:
			return null
		_:
			return load("res://aseprite/effect/xexpl1.tscn")

const CATALOGUE_PICKUP_SCENES: Dictionary = {
	"Missiles (xpickup_14)": "res://aseprite/xpickup_14_missile.tscn",
	"Shotgun Shell (xpickup_12)": "res://aseprite/xpickup_12_shotgun_shell.tscn",
	"Coolant (xpickup_03)": "res://aseprite/xpickup_03_coolant.tscn",
	"Shield (xpickup_05)": "res://aseprite/xpickup_05_shield.tscn",
	"Nuke (xpickup_07)": "res://aseprite/xpickup_07_nuke.tscn",
	"Credit (xpickup_21)": "res://aseprite/xpickup_21_credit.tscn",
	"Chargeurs (xpickup_01)": "res://aseprite/xpickup_01_chargeur.tscn"
}

@export_group("Configuration Pickups par Morceau (Cluster)")

## Liste de pickups INDIVIDUELS par morceau (1 élément = 1 morceau : Elément 0 -> p1, Elément 1 -> p2, etc.).
## Chaque case permet d'assigner un pickup DIFFÉRENT pour chaque porte/morceau (null = pas de pickup sur cette porte).
@export var pickups_par_piece: Array[PackedScene] = []

## Dictionnaire optionnel pour mapper un nom de morceau exact ("p1", "p4", "porte_gauche") vers sa propre scène de pickup.
@export var pickups_par_nom: Dictionary = {}

## (Optionnel) Bitmask si vous souhaitez cocher plusieurs morceaux recevant TOUS le même pickup générique ci-dessous.
@export_flags("p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9", "p10", "p11", "p12", "p13", "p14", "p15", "p16", "p17", "p18", "p19", "p20", "p21", "p22", "p23", "p24", "p25", "p26", "p27", "p28", "p29", "p30", "p31", "p32") var morceaux_portant_pickup: int = 0

## Dropdown du catalogue pour le Bitmask générique ci-dessus.
@export_enum("Aucun", "Missiles (xpickup_14)", "Shotgun Shell (xpickup_12)", "Coolant (xpickup_03)", "Shield (xpickup_05)", "Nuke (xpickup_07)", "Credit (xpickup_21)", "Chargeurs (xpickup_01)") var type_pickup_selectionne: String = "Aucun"

# ── Pickups Mode 1 & 2 (via export) ──────────────────────────────────────────
## Scene de pickup a spawner aleatoirement (null = desactive)
@export var pickup_scene: PackedScene = null

## Probabilite de spawner le pickup PAR PIECE cassee (0.0 = jamais, 1.0 = toujours)
@export_range(0.0, 1.0) var pickup_chance: float = 0.0

## Si true, spawne UN pickup quand TOUS les morceaux sont detruits.
@export var pickup_sur_groupe: bool = false

@export_group("Effet d'Apparition Unique (Cluster)")
## Effet de trajectoire unique applique a tous les pickups generes ou reveles par ce cluster.
@export_enum("heriter_pickup", "fixe", "tombe_au_sol", "tombe_hors_ecran", "bond_au_sol", "bond_hors_ecran") var effet_apparition_pickup: String = "heriter_pickup"

## Points de score accordés au joueur lors de la destruction de chaque morceau
@export var points_score: int = 150
## Ligne Y absolue du sol pour les pickups de ce décor (-1.0 = utilise le réglage du pickup).
@export var hauteur_sol_pickup_y: float = -1.0
## Impulsion verticale vers le haut pour les bonds (px/s, -1.0 = utilise le réglage du pickup).
@export var impulsion_bond_y: float = -1.0
## Dispersion horizontale gauche/droite (px/s, -1.0 = utilise le réglage du pickup).
@export var dispersion_x: float = -1.0

# ── Pickup Mode 3 (embarque dans la scene) ───────────────────────────────────
# Glisser n'importe quel xpickup_XX directement sous une piece (ex: p1).
# Il sera cache au demarrage et revele quand cette piece est cassee,
# exactement comme DamagedSprite. Le joueur doit ensuite tirer dessus
# pour le collecter. Pas de detachement, pas de reparentage.
# ─────────────────────────────────────────────────────────────────────────────

var _pieces: Array[Node] = []
var _damaged_textures: Array = []
var _destroyed_node: Sprite2D
var _pieces_hp: Dictionary = {}

func _ready() -> void:
	_destroyed_node = get_node_or_null("destroyed") as Sprite2D
	if _destroyed_node:
		_destroyed_node.visible = false

	# N'enregistrer que les morceaux destructibles (ceux qui ont un HitArea).
	# Les sprites de fond (bck_X) sont ignores.
	for child in get_children():
		if child.name == "destroyed":
			continue
		var area = child.get_node_or_null("HitArea") as Area2D
		if area:
			_pieces.append(child)
			var max_hp = child.get_meta("hp") if child.has_meta("hp") else 1
			_pieces_hp[child] = max_hp
			var dmg_tex = child.get_meta("damaged_texture") if child.has_meta("damaged_texture") else null
			_damaged_textures.append(dmg_tex)
			area.monitorable = true
			if not area.area_entered.is_connected(_on_piece_hit):
				area.area_entered.connect(_on_piece_hit.bind(child))

		# Mode 3 : cacher tous les pickups embarques dans les pieces.
		# Ils seront reveles lors de la destruction, comme DamagedSprite.
		for sub in child.get_children():
			if sub.has_method("ramasser"):
				if sub is CanvasItem:
					(sub as CanvasItem).visible = false
				# S'assurer que la collision est inactive tant que le pickup est cache
				if sub is Area2D:
					(sub as Area2D).set_deferred("monitorable", false)

	# Cas d'un composant autonome (ex: DomageablePart) qui possède directement un HitArea
	var direct_area = get_node_or_null("HitArea") as Area2D
	if direct_area and _pieces.is_empty():
		_pieces.append(self)
		var max_hp = get_meta("hp") if has_meta("hp") else 1
		_pieces_hp[self] = max_hp
		var dmg_tex = get_meta("damaged_texture") if has_meta("damaged_texture") else null
		_damaged_textures.append(dmg_tex)
		direct_area.monitorable = true
		if not direct_area.area_entered.is_connected(_on_piece_hit):
			direct_area.area_entered.connect(_on_piece_hit.bind(self))

func _on_piece_hit(_bullet: Area2D, piece: Node) -> void:
	casse_morceau(piece)

func subir_degats_sur_enfant(enfant: Node, _quantite: int = 1) -> void:
	# Appele par projectile.gd avec l'enfant touche (HitArea ou piece)
	var piece: Node
	if enfant is Area2D:
		# HitArea -> remonter a la piece parente (p0, p1, etc.)
		piece = enfant.get_parent()
	else:
		piece = enfant
	if piece and is_instance_valid(piece):
		casse_morceau(piece)

func subir_degats(_quantite: int = 1) -> void:
	# Fallback si appele sans piece specifique
	for p in _pieces:
		if not p.get_meta("destroyed", false):
			casse_morceau(p)
			break

func casse_morceau(piece: Node) -> void:
	if piece.get_meta("destroyed", false):
		return

	# Décrémenter les HP du morceau si défini
	var current_hp = _pieces_hp.get(piece, 1) - 1
	_pieces_hp[piece] = current_hp
	
	var idx = _pieces.find(piece)
	
	# Mettre à jour l'animation visuelle
	if piece is AnimatedSprite2D:
		var animated_sprite = piece as AnimatedSprite2D
		if animated_sprite.sprite_frames:
			if current_hp <= 0:
				# Destruction finale : animation destroyed/off
				if animated_sprite.sprite_frames.has_animation("destroyed"):
					animated_sprite.play("destroyed")
				elif animated_sprite.sprite_frames.has_animation("off"):
					animated_sprite.play("off")
				else:
					var animation_found = _trouver_animation_damage(animated_sprite)
					if animation_found:
						animated_sprite.play(animation_found)
			else:
				# Étape intermédiaire : animation damaged
				if animated_sprite.sprite_frames.has_animation("damaged"):
					animated_sprite.play("damaged")
				else:
					var animation_found = _trouver_animation_damage(animated_sprite)
					if animation_found:
						animated_sprite.play(animation_found)
	elif piece is Sprite2D:
		if idx >= 0 and idx < _damaged_textures.size() and _damaged_textures[idx] != null:
			(piece as Sprite2D).texture = _damaged_textures[idx]

	# Petite explosion / spark d'impact
	_spawn_expl(piece)

	# Transmettre les dégâts au parent véhicule (ex: XSVan) s'il existe
	var parent_actor = get_parent()
	while parent_actor and not (parent_actor.has_method("subir_degats") and parent_actor != self):
		parent_actor = parent_actor.get_parent()
	if parent_actor and parent_actor.has_method("subir_degats"):
		parent_actor.subir_degats(1)

	# Si le morceau a encore des HP, ne PAS désactiver son HitArea et interrompre la destruction complète
	if current_hp > 0:
		return

	# --- DESTRUCTION FINALE DU MORCEAU (HP <= 0) ---
	piece.set_meta("destroyed", true)

	# Si la piece a un sprite de debris / dommage dedie -> l'afficher
	var dmg_spr = piece.get_node_or_null("DamagedSprite") as CanvasItem
	if dmg_spr:
		dmg_spr.visible = true
	elif piece is CanvasItem:
		(piece as CanvasItem).visible = true

	# Desactiver le HitArea de la piece (elle est totalement detruite) ou avec l'Options Suivante
	var hit_area = piece.get_node_or_null("HitArea") as Area2D
	if hit_area:
		#hit_area.visible = false
		#hit_area.set_deferred("monitoring", false)
		#hit_area.set_deferred("monitorable", false)
	# Desactiver le HitArea de la piece apres un delais general de 0.5s (pour eviter d'absorber le pickup sous le meme coup de feu) (Option Suivante)
	#if hit_area:
		get_tree().create_timer(0.5, false).timeout.connect(func():
			if is_instance_valid(hit_area):
				hit_area.visible = false
				hit_area.set_deferred("monitoring", false)
				hit_area.set_deferred("monitorable", false)
	)

	# Mode 3 : reveler le pickup embarque (comme DamagedSprite)
	for enfant in piece.get_children():
		if enfant.has_method("ramasser"):
			if enfant is CanvasItem:
				(enfant as CanvasItem).visible = true
			if enfant is Area2D:
				(enfant as Area2D).set_deferred("monitorable", true)
				(enfant as Area2D).set_deferred("monitoring", true)
			_appliquer_parametres_apparition(enfant)
			break  # un seul pickup par piece

	# Ajouter les points pour la destruction du morceau
	GlobalSettings.ajouter_score(points_score)
	
	_spawn_expl(piece)

	# Mode 1 : pickup aleatoire par piece via export var
	if pickup_scene and pickup_chance > 0.0:
		if randf() <= pickup_chance:
			var gpos = (piece as Node2D).global_position if piece is Node2D else global_position
			_spawn_pickup(pickup_scene, gpos, piece)

	# Résolution du pickup spécifique à cette porte / morceau :
	var scene_a_spawner: PackedScene = null
	# 1. Vérification dans la liste Array pickups_par_piece (par index : Elément 0 -> p1, Elément 1 -> p2, etc.)
	if idx >= 0 and idx < pickups_par_piece.size() and pickups_par_piece[idx] != null:
		scene_a_spawner = pickups_par_piece[idx]
	# 2. Vérification dans le dictionnaire pickups_par_nom par nom exact de la pièce (ex: "p1", "porte_gauche")
	elif piece and pickups_par_nom.has(piece.name):
		var val = pickups_par_nom[piece.name]
		if val is PackedScene:
			scene_a_spawner = val as PackedScene
		elif val is String and CATALOGUE_PICKUP_SCENES.has(val):
			scene_a_spawner = load(CATALOGUE_PICKUP_SCENES[val])
	# 3. Mode Bitmask générique (si plusieurs portes partagent le même pickup du dropdown)
	elif idx >= 0 and morceaux_portant_pickup > 0:
		var masque = 1 << idx
		if (morceaux_portant_pickup & masque) != 0:
			scene_a_spawner = pickup_scene
			if scene_a_spawner == null and type_pickup_selectionne != "Aucun":
				if CATALOGUE_PICKUP_SCENES.has(type_pickup_selectionne):
					scene_a_spawner = load(CATALOGUE_PICKUP_SCENES[type_pickup_selectionne])

	if scene_a_spawner:
		var gpos = (piece as Node2D).global_position if piece is Node2D else global_position
		_spawn_pickup(scene_a_spawner, gpos, piece)

	_check_group_destroyed()

func _check_group_destroyed() -> void:
	var all_broken = true
	for p in _pieces:
		if not p.get_meta("destroyed", false):
			all_broken = false
			break

	if all_broken:
		if _destroyed_node:
			for p in _pieces:
				if p is CanvasItem:
					(p as CanvasItem).visible = false
			_destroyed_node.visible = true

		# Mode 2 : pickup de groupe (un seul quand tout est detruit)
		if pickup_sur_groupe and pickup_scene:
			_spawn_pickup(pickup_scene, global_position, self)

func _spawn_expl(piece: Node) -> void:
	var scene_explosion = _get_explosion_scene()
	if not scene_explosion or piece == null:
		return
	var e = scene_explosion.instantiate() as Node2D
	if not e:
		return
	# Position locale -> defile avec le ParallaxLayer sans decalage
	if piece is Node2D:
		e.position = (piece as Node2D).position
	e.z_index = 50
	add_child(e)

func _spawn_pickup(scene: PackedScene, spawn_pos: Vector2, parent_piece: Node = null) -> void:
	if scene == null:
		return
	var p = scene.instantiate() as Node2D
	if not p:
		return
	var parent_cible = get_parent() if get_parent() else self
	parent_cible.add_child(p)
	
	if parent_piece and parent_piece is Node2D and parent_piece.get_parent() == parent_cible:
		p.position = (parent_piece as Node2D).position
	elif parent_piece and parent_piece is Node2D:
		p.global_position = (parent_piece as Node2D).global_position
	else:
		p.global_position = spawn_pos

	p.z_index = 80
	if p is Area2D:
		(p as Area2D).monitorable = true
		(p as Area2D).monitoring = true

	_appliquer_parametres_apparition(p)
	print("[BREAKABLE] Pickup spawne dans le decor '", parent_cible.name, "' a : ", p.global_position)

func _appliquer_parametres_apparition(pickup: Node) -> void:
	if not is_instance_valid(pickup):
		return
	if hauteur_sol_pickup_y > 0.0 and "hauteur_sol_y" in pickup:
		pickup.hauteur_sol_y = hauteur_sol_pickup_y
	if impulsion_bond_y > 0.0 and "impulsion_bond_y" in pickup:
		pickup.impulsion_bond_y = impulsion_bond_y
	if dispersion_x >= 0.0 and "dispersion_x" in pickup:
		pickup.dispersion_x = dispersion_x
	if pickup.has_method("jouer_effet_apparition"):
		if effet_apparition_pickup != "heriter_pickup":
			pickup.jouer_effet_apparition(effet_apparition_pickup)
		else:
			pickup.jouer_effet_apparition()

func _trouver_animation_damage(animated_sprite: AnimatedSprite2D) -> String:
	var sprite_frames = animated_sprite.sprite_frames
	if not sprite_frames:
		return ""
	
	# Essayer les animations courantes pour 'off', 'broken', 'damaged', 'destroyed'
	var animations_a_tester = ["off", "broken", "off_light", "broken_light", "damaged", "destroyed"]
	for anim_name in animations_a_tester:
		if sprite_frames.has_animation(anim_name):
			return anim_name
	
	return ""
