extends Node2D

@export var est_missile_alternatif: bool = false
@export var est_tir_special: bool = false
@export var degats: int = 1
@export var vitesse_lerp: float = 9.0 # ~0.11 seconde de vol (6-7 frames)

var start_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var t: float = 0.0
var sprite_projectile: Sprite2D = null

# --- PRÉCHARGEMENT DES TEXTURES XWEPGRA ---
var textures_tir_principal: Array[Texture2D] = [
	preload("res://tsj/xwepgra_16.png"),
	preload("res://tsj/xwepgra_17.png"),
	preload("res://tsj/xwepgra_18.png"),
	preload("res://tsj/xwepgra_19.png"),
	preload("res://tsj/xwepgra_20.png"),
	preload("res://tsj/xwepgra_21.png")
]

var textures_missile: Array[Texture2D] = [
	preload("res://tsj/xwepgra_01.png"),
	preload("res://tsj/xwepgra_02.png"),
	preload("res://tsj/xwepgra_03.png"),
	preload("res://tsj/xwepgra_04.png"),
	preload("res://tsj/xwepgra_05.png"),
	preload("res://tsj/xwepgra_06.png")
]

var textures_fumee_missile: Array[Texture2D] = [
	preload("res://tsj/xwepgra_15.png"),
	preload("res://tsj/xwepgra_14.png"),
	preload("res://tsj/xwepgra_13.png"),
	preload("res://tsj/xwepgra_12.png"),
	preload("res://tsj/xwepgra_11.png"),
	preload("res://tsj/xwepgra_10.png")
]

var textures_impact: Array[Texture2D] = [
	preload("res://tsj/xwepgra_07.png"),
	preload("res://tsj/xwepgra_08.png"),
	preload("res://tsj/xwepgra_09.png")
]

func _ready() -> void:
	sprite_projectile = Sprite2D.new()
	sprite_projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite_projectile)

func initialiser_tir(depart: Vector2, cible: Vector2, mode_missile: bool = false, quantite_degats: int = 1, special: bool = false) -> void:
	start_pos = depart
	target_pos = cible
	position = start_pos
	t = 0.0
	est_missile_alternatif = mode_missile
	est_tir_special = special
	degats = maxi(1, quantite_degats)

func _physics_process(delta: float) -> void:
	if t >= 1.0:
		return

	t += delta * vitesse_lerp
	var t_clamped = clamp(t, 0.0, 1.0)
	
	# Interpolation 2.5D du bas vers la cible en profondeur
	position = start_pos.lerp(target_pos, t_clamped)
	
	# Orientation du sprite selon la trajectoire
	var direction = (target_pos - start_pos).normalized()
	rotation = direction.angle() + (PI / 2.0)
	
	# Choix de la texture selon l'avancement du vol (du plus gros au plus petit)
	var liste_tex = textures_missile if est_missile_alternatif else textures_tir_principal
	var index_tex = int(t_clamped * (liste_tex.size() - 1))
	if sprite_projectile and index_tex < liste_tex.size():
		sprite_projectile.texture = liste_tex[index_tex]
		
	# Émission de cercles de fumée le long de la trajectoire pour le missile
	if est_missile_alternatif and randf() < 0.4:
		_emettre_cercle_fumee(position, direction, t_clamped)

	if t >= 1.0:
		_verifier_impact_cible()
		queue_free()

func _emettre_cercle_fumee(pos_fumee: Vector2, dir_vol: Vector2, ratio_vol: float) -> void:
	var spr_fumee = Sprite2D.new()
	spr_fumee.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var index_fumee = int(ratio_vol * (textures_fumee_missile.size() - 1))
	if index_fumee < textures_fumee_missile.size():
		spr_fumee.texture = textures_fumee_missile[index_fumee]
	
	# Positionnée légèrement derrière le missile
	spr_fumee.global_position = pos_fumee - (dir_vol * 6.0)
	spr_fumee.rotation = dir_vol.angle() + (PI / 2.0)
	get_parent().add_child(spr_fumee)
	
	# Animation de disparition rapide de la fumée (0.2s)
	var tween = spr_fumee.create_tween()
	tween.tween_property(spr_fumee, "modulate:a", 0.0, 0.20)
	tween.tween_callback(spr_fumee.queue_free)

var scene_explosion_missile: PackedScene = preload("res://aseprite/effect/xexpl4.tscn")

func _creer_impact_explosion(pos_impact: Vector2) -> void:
	var parent_node = get_parent()
	if parent_node == null or not is_inside_tree():
		return
		
	var spr_impact = Sprite2D.new()
	spr_impact.name = "ImpactExplosion"
	spr_impact.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr_impact.global_position = pos_impact
	spr_impact.texture = textures_impact[0]
	spr_impact.z_index = 2000
	parent_node.add_child(spr_impact)
	
	# Sequencage de frames d'explosion securise via SceneTreeTimer
	var tree = get_tree()
	if tree:
		tree.create_timer(0.04, false).timeout.connect(func():
			if is_instance_valid(spr_impact):
				spr_impact.texture = textures_impact[1]
		)
		tree.create_timer(0.08, false).timeout.connect(func():
			if is_instance_valid(spr_impact):
				spr_impact.texture = textures_impact[2]
		)
		tree.create_timer(0.12, false).timeout.connect(func():
			if is_instance_valid(spr_impact):
				spr_impact.queue_free()
		)

func _creer_impact_explosion_missile(pos_impact: Vector2) -> void:
	var parent_node = get_parent()
	if parent_node == null or not is_inside_tree() or scene_explosion_missile == null:
		return
	var expl = scene_explosion_missile.instantiate() as AnimatedSprite2D
	if expl:
		expl.name = "MissileExplosionXExpl4"
		expl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		expl.global_position = pos_impact
		expl.z_index = 2000
		
		# Assurer que l'animation ne boucle pas et se détruit à la fin
		if expl.sprite_frames:
			var anim_name = "explode" if expl.sprite_frames.has_animation("explode") else "default"
			expl.sprite_frames.set_animation_loop(anim_name, false)
			expl.animation = anim_name
			expl.play(anim_name)
			expl.animation_finished.connect(func():
				if is_instance_valid(expl):
					expl.queue_free()
			)
		else:
			get_tree().create_timer(0.5, false).timeout.connect(func():
				if is_instance_valid(expl):
					expl.queue_free()
			)
		parent_node.add_child(expl)

func _verifier_impact_cible() -> void:
	# Toujours générer l'effet d'impact à la position ciblée
	_creer_impact_explosion(target_pos)

	var vp := get_viewport()
	# Position écran exacte correspondant au tir
	var pos_ecran_cible := vp.get_mouse_position() if vp else target_pos
	
	# En mode joystick, utiliser la position du réticule de la caméra au lieu de la souris
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera and "mode_joystick_actif" in camera and camera.mode_joystick_actif:
		if "position_visee_monde" in camera:
			# Convertir la position monde du réticule en position écran
			var centre_ecran = Vector2(vp.size) / 2.0 if vp else Vector2.ZERO
			var position_monde_reticule = camera.position_visee_monde
			var position_ecran_relative = position_monde_reticule - camera.get_screen_center_position()
			pos_ecran_cible = centre_ecran + position_ecran_relative

	# 1. PASSE PRIORITAIRE : Détection Visuelle Canvas pour éléments sous ParallaxLayer / Décors décalés
	var parent_scene := get_parent()
	if parent_scene and vp:
		var candidats_canvas := []
		_rechercher_cibles_canvas(parent_scene, pos_ecran_cible, candidats_canvas)
		if candidats_canvas.size() > 0:
			candidats_canvas.sort_custom(Callable(self, "_comparer_distance"))
			var meilleur = candidats_canvas[0]
			var target_actor = meilleur["actor"]
			var child_hit = meilleur["child"]
			var nom_partie: String = meilleur.get("nom_partie", "")

			# Si tir alternatif / missile sur un acteur piéton, ennemi ou civil (hors véhicule), instancier xexpl4
			if est_missile_alternatif:
				var est_vehicule = target_actor is VehicleActorBase or child_hit is VehicleActorBase or target_actor is L1GhkEnemy
				var est_acteur_eligible = target_actor is ActorBase or target_actor is WalkingEnemy or target_actor is WalkingCivilian or target_actor is PopupEnemy or child_hit is ActorBase
				if est_acteur_eligible and not est_vehicule:
					_creer_impact_explosion_missile(target_pos)

			if target_actor.has_method("subir_degats_partie") and nom_partie != "":
				_appeler_subir_degats_partie(target_actor, nom_partie, degats, target_pos, est_missile_alternatif, est_tir_special)
				print("[T2 ARCADE] Impact Canvas Hitspot Réussi sur : ", nom_partie, " de ", target_actor.name)
				return
			elif est_missile_alternatif and target_actor.has_method("subir_degats_missile"):
				_appeler_subir_degats_missile(target_actor, degats, target_pos, est_tir_special)
				print("[T2 ARCADE] Impact Missile Alternatif sur : ", target_actor.name)
				return
			elif target_actor.has_method("subir_degats_sur_enfant") and child_hit:
				target_actor.subir_degats_sur_enfant(child_hit, degats)
				print("[T2 ARCADE] Impact Canvas vers parent centralisateur : ", target_actor.name, " pour : ", child_hit.name)
				return
			elif target_actor.has_method("subir_degats"):
				target_actor.subir_degats(degats)
				print("[T2 ARCADE] Impact Canvas Réussi sur : ", target_actor.name)
				return

	# 2. Vérification par Physique 2D (Masque 0xFFFFFFFF couvrant les 32 calques de collision)
	var space_state = get_world_2d().direct_space_state
	if space_state:
		var query = PhysicsShapeQueryParameters2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 4.0 # Précision pixel-perfect (au lieu de 18.0) pour éviter tout débordement
		query.shape = circle
		query.transform = Transform2D(0.0, target_pos)
		query.collision_mask = 0xFFFFFFFF # Intercepte tous les calques
		query.collide_with_bodies = true
		query.collide_with_areas = true
		
		var results = space_state.intersect_shape(query)
		
		# PASSE 2 : Détection Physique Unifiée (Area2D Hitspots + CharacterBody2D / StaticBody2D)
		# Triée par priorité visuelle absolue (z_index / Y-sort) pour que l'acteur au premier plan prenne le coup
		var candidats_physiques = []
		for res in results:
			var collider = res.collider
			if collider == null:
				continue
			if _est_dans_parallax(collider):
				continue
				
			# Cas 1 : Pickups (ramassage ou destruction directe)
			if collider is Area2D:
				if collider.has_method("ramasser"):
					collider.ramasser()
					print("[T2 ARCADE] Pickup ramasse (Physique) : ", collider.name)
					return
				if collider.has_method("subir_degats") and not collider.has_method("subir_degats_sur_enfant") and (collider.name.to_lower().contains("pickup") or collider is PickupItem or collider is MissilePickup):
					collider.subir_degats(degats)
					print("[T2 ARCADE] Impact direct sur Pickup (Physique) : ", collider.name)
					return

				# Cas 2 : Area2D de boss ou décor (ex: HitArea de hittank, breakable_prop, etc.)
				var parent_actor: Node = collider.get_parent()
				while parent_actor and not parent_actor.has_method("subir_degats_partie") and not parent_actor.has_method("subir_degats_sur_enfant") and not parent_actor.has_method("subir_degats") and not parent_actor.has_method("subir_degats_missile"):
					parent_actor = parent_actor.get_parent()
				if parent_actor == null and (collider.has_method("subir_degats") or collider.has_method("subir_degats_missile")):
					parent_actor = collider
					
				if parent_actor and not parent_actor.get("est_elimine"):
					var nom_partie = collider.name.to_lower().replace("hitspot_", "").replace("hitspot", "").replace("base", "chassis")
					if nom_partie == "hitarea" and collider.get_parent():
						nom_partie = collider.get_parent().name.to_lower()
					var z_idx = _calculer_z_index_effectif(collider if collider is CanvasItem else parent_actor)
					var p_y = (collider as CanvasItem).global_position.y if collider is CanvasItem else parent_actor.global_position.y
					var dist = target_pos.distance_to((collider as CanvasItem).global_position if collider is CanvasItem else parent_actor.global_position)
					candidats_physiques.append({
						"type": "area",
						"collider": collider,
						"actor": parent_actor,
						"nom_partie": nom_partie,
						"dist": dist,
						"z_index": z_idx,
						"pos_y": p_y
					})
			else:
				# Cas 3 : Corps physiques standards (CharacterBody2D, StaticBody2D, etc. pour ennemis simples)
				# Les véhicules (XSVan, XJug, XCopter) ont des HitAreas dédiées et ne doivent pas prendre de dégâts via leur boîte cinématique globale
				if collider is VehicleActorBase or (collider.get_parent() and collider.get_parent() is VehicleActorBase):
					continue
					
				var p_node = collider.get_parent()
				var target_actor = collider if (collider.has_method("subir_degats") or collider.has_method("subir_degats_missile")) else (p_node if p_node and (p_node.has_method("subir_degats") or p_node.has_method("subir_degats_sur_enfant") or p_node.has_method("subir_degats_missile")) else null)
				
				if target_actor and not target_actor.get("est_elimine"):
					var z_idx = _calculer_z_index_effectif(collider if collider is CanvasItem else target_actor)
					var p_y = (collider as CanvasItem).global_position.y if collider is CanvasItem else target_actor.global_position.y
					var dist = target_pos.distance_to((collider as CanvasItem).global_position if collider is CanvasItem else target_actor.global_position)
					candidats_physiques.append({
						"type": "body",
						"collider": collider,
						"actor": target_actor,
						"nom_partie": "",
						"dist": dist,
						"z_index": z_idx,
						"pos_y": p_y
					})
		
		# TRI UNIFIÉ : Area2D prioritaire sur Body, puis premier plan visuel (z_index / Y-sort) puis proximité
		candidats_physiques.sort_custom(Callable(self, "_comparer_priorite_cible"))
		
		for item in candidats_physiques:
			var target_actor = item["actor"]
			var target_collider = item["collider"]
			if target_actor.get("est_elimine"):
				continue
				
			# Si tir alternatif / missile sur un acteur piéton, ennemi ou civil (hors véhicule), instancier xexpl4
			if est_missile_alternatif:
				var est_vehicule = target_actor is VehicleActorBase or target_collider is VehicleActorBase or target_actor is L1GhkEnemy
				var est_acteur_eligible = target_actor is ActorBase or target_actor is WalkingEnemy or target_actor is WalkingCivilian or target_actor is PopupEnemy or target_collider is ActorBase
				if est_acteur_eligible and not est_vehicule:
					_creer_impact_explosion_missile(target_pos)

			if item["type"] == "area":
				if target_actor.has_method("subir_degats_partie") and item["nom_partie"] != "":
					_appeler_subir_degats_partie(target_actor, item["nom_partie"], degats, target_pos, est_missile_alternatif, est_tir_special)
					print("[T2 ARCADE] Impact Hitspot Réussi sur : ", target_collider.name, " (", item["nom_partie"], ") de ", target_actor.name)
					return
				elif est_missile_alternatif and target_actor.has_method("subir_degats_missile"):
					_appeler_subir_degats_missile(target_actor, degats, target_pos, est_tir_special)
					print("[T2 ARCADE] Impact Physique Missile Alternatif sur : ", target_actor.name)
					return
				elif target_actor.has_method("subir_degats_sur_enfant"):
					var piece_cible = target_collider.get_parent() if target_collider.name == "HitArea" else target_collider
					target_actor.subir_degats_sur_enfant(piece_cible, degats)
					print("[T2 ARCADE] Redirection Area2D vers le parent centralisateur : ", target_actor.name, " pour : ", piece_cible.name)
					return
				elif target_collider.has_method("subir_degats"):
					target_collider.subir_degats(degats)
					print("[T2 ARCADE] Impact direct sur Area2D : ", target_collider.name)
					return
				elif target_actor.has_method("subir_degats"):
					target_actor.subir_degats(degats)
					print("[T2 ARCADE] Impact direct sur parent de Area2D : ", target_actor.name)
					return
			else:
				if est_missile_alternatif and target_actor.has_method("subir_degats_missile"):
					_appeler_subir_degats_missile(target_actor, degats, target_pos, est_tir_special)
					print("[T2 ARCADE] Impact Physique Missile Alternatif sur : ", target_actor.name)
					return
				elif target_actor.has_method("subir_degats_sur_enfant"):
					target_actor.subir_degats_sur_enfant(target_collider, degats)
					print("[T2 ARCADE] Redirection Physique vers le parent centralisateur : ", target_actor.name, " pour l'enfant : ", target_collider.name)
					return
				elif target_actor.has_method("subir_degats"):
					target_actor.subir_degats(degats)
					print("[T2 ARCADE] Impact réussi (Physique Trié) sur : ", target_actor.name, " (dist: ", str(round(item["dist"])), "px)")
					return

func _est_dans_parallax(node: Node) -> bool:
	var p = node
	while p:
		if p is ParallaxLayer or p is ParallaxBackground:
			return true
		p = p.get_parent()
	return false

func _rechercher_cibles_canvas(noeud_racine: Node, point_ecran: Vector2, out_candidats: Array) -> void:
	if not is_instance_valid(noeud_racine):
		return

	# Recherche restreinte aux décors ParallaxBackground / ParallaxLayer
	var est_dans_parallax = false
	var p = noeud_racine
	while p:
		if p is ParallaxLayer or p is ParallaxBackground:
			est_dans_parallax = true
			break
		p = p.get_parent()

	if not est_dans_parallax:
		for child in noeud_racine.get_children():
			_rechercher_cibles_canvas(child, point_ecran, out_candidats)
		return

	var canvas_item := noeud_racine as CanvasItem
	if canvas_item and canvas_item.is_visible_in_tree():
		# Vérification uniquement sur les Area2D actives (HitArea ou hitspot)
		if canvas_item is Area2D:
			var area = canvas_item as Area2D
			if area.monitorable and _point_touche_area_ecran(area, point_ecran):
				var centre_ecran = area.get_global_transform_with_canvas().origin

				# Cas prioritaire : le pickup est lui-meme l'acteur (ex: xpickup_XX embarque).
				# On s'arrete ici sans remonter aux parents pour ne pas declencher le BreakableProp.
				if canvas_item.has_method("subir_degats"):
					out_candidats.append({
						"actor": canvas_item,
						"child": canvas_item,
						"nom_partie": "",
						"dist": point_ecran.distance_to(centre_ecran)
					})
					return

				# Cas standard : remonter pour trouver l'acteur parent (HitArea, hitspot, etc.)
				var parent_actor: Node = canvas_item.get_parent()
				while parent_actor and not parent_actor.has_method("subir_degats_partie") and not parent_actor.has_method("subir_degats_sur_enfant") and not parent_actor.has_method("subir_degats"):
					parent_actor = parent_actor.get_parent()
				
				if parent_actor:
					var nom_p: String = ""
					if parent_actor.has_method("subir_degats_partie"):
						nom_p = canvas_item.name.to_lower().replace("hitspot_", "").replace("hitspot", "").replace("base", "chassis")
						if nom_p == "hitarea" and canvas_item.get_parent():
							nom_p = canvas_item.get_parent().name.to_lower()
					
					out_candidats.append({
						"actor": parent_actor,
						"child": canvas_item.get_parent() if canvas_item.name == "HitArea" else canvas_item,
						"nom_partie": nom_p,
						"dist": point_ecran.distance_to(centre_ecran)
					})
				return

	for child in noeud_racine.get_children():
		_rechercher_cibles_canvas(child, point_ecran, out_candidats)

func _point_touche_area_ecran(area: Area2D, point_ecran: Vector2) -> bool:
	var trans_ecran := area.get_global_transform_with_canvas()
	# Projeter le point écran dans le repère local de l'Area2D
	var point_local = trans_ecran.affine_inverse() * point_ecran

	for child in area.get_children():
		if child is CollisionShape2D:
			var col = child as CollisionShape2D
			if col.disabled or col.shape == null:
				continue
			var pt_shape = col.transform.affine_inverse() * point_local
			if col.shape is RectangleShape2D:
				var half_size: Vector2 = (col.shape as RectangleShape2D).size * 0.5
				var rect_local = Rect2(-half_size, (col.shape as RectangleShape2D).size)
				if rect_local.has_point(pt_shape):
					return true
			elif col.shape is CircleShape2D:
				var rad: float = (col.shape as CircleShape2D).radius
				if pt_shape.length_squared() <= (rad * rad):
					return true
		elif child is CollisionPolygon2D:
			var poly = child as CollisionPolygon2D
			if poly.disabled:
				continue
			var pt_poly = poly.transform.affine_inverse() * point_local
			if Geometry2D.is_point_in_polygon(pt_poly, poly.polygon):
				return true

	return false

func _comparer_distance(a: Dictionary, b: Dictionary) -> bool:
	return float(a["dist"]) < float(b["dist"])

func _comparer_priorite_cible(a: Dictionary, b: Dictionary) -> bool:
	# 1. Les Area2D spécifiques (HitAreas) ont la priorité absolue sur les corps génériques
	var a_is_area = (a.get("type") == "area")
	var b_is_area = (b.get("type") == "area")
	if a_is_area != b_is_area:
		return a_is_area
		
	# 2. Z-index effectif
	var z_a = int(a.get("z_index", 0))
	var z_b = int(b.get("z_index", 0))
	if z_a != z_b:
		return z_a > z_b # Plus grand z_index en premier (au premier plan visuel)
		
	# 3. Y-sort
	var y_a = float(a.get("pos_y", 0.0))
	var y_b = float(b.get("pos_y", 0.0))
	if abs(y_a - y_b) > 4.0:
		return y_a > y_b # Plus bas sur l'écran = au premier plan (Y-sort)
		
	# 4. Proximité au centre de l'impact
	return float(a["dist"]) < float(b["dist"])

func _calculer_z_index_effectif(noeud: Node) -> int:
	var total_z: int = 0
	var n: Node = noeud
	while n:
		if n is CanvasItem:
			total_z += (n as CanvasItem).z_index
			if not (n as CanvasItem).z_as_relative:
				break
		n = n.get_parent()
	return total_z

func _appeler_subir_degats_partie(cible: Object, nom_partie: String, montant_degats: int, pos: Vector2, est_missile: bool, est_special: bool) -> void:
	if not is_instance_valid(cible) or not cible.has_method("subir_degats_partie"):
		return
	var nb_args := 0
	for m in cible.get_method_list():
		if m.name == "subir_degats_partie":
			nb_args = m.get("args", []).size()
			break
	if nb_args >= 5:
		cible.call("subir_degats_partie", nom_partie, montant_degats, pos, est_missile, est_special)
	elif nb_args == 4:
		cible.call("subir_degats_partie", nom_partie, montant_degats, pos, est_missile)
	elif nb_args == 3:
		cible.call("subir_degats_partie", nom_partie, montant_degats, pos)
	elif nb_args == 2:
		cible.call("subir_degats_partie", nom_partie, montant_degats)
	else:
		cible.call("subir_degats_partie", nom_partie, montant_degats, pos, est_missile)

func _appeler_subir_degats_missile(cible: Object, montant_degats: int, pos: Vector2, est_special: bool) -> void:
	if not is_instance_valid(cible) or not cible.has_method("subir_degats_missile"):
		return
	var nb_args := 0
	for m in cible.get_method_list():
		if m.name == "subir_degats_missile":
			nb_args = m.get("args", []).size()
			break
	if nb_args >= 3:
		cible.call("subir_degats_missile", montant_degats, pos, est_special)
	elif nb_args == 2:
		cible.call("subir_degats_missile", montant_degats, pos)
	elif nb_args == 1:
		cible.call("subir_degats_missile", montant_degats)
	else:
		cible.call("subir_degats_missile", montant_degats, pos)
