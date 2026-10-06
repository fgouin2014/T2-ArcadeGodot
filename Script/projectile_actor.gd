class_name ProjectileActor
extends Node2D

@export_enum("grenade", "missile", "flask") var type_projectile: String = "grenade"
@export var vitesse: float = 80.0 # Vitesse adaptée à l écran 288x175 (px/s)
@export var temps_de_vie: float = 6.0
@export var hauteur_lancer_arc: float = 35.0 # Hauteur maximale de la parabole en pixels (grenade uniquement)
@export var duree_vol_arc: float = 1.2 # Durée de vol avant impact
@export var direction_tir: Vector2 = Vector2(-0.3, 1.0) # Direction par défaut dans l'Inspecteur
@export var inverser_visuel: bool = false # Flip H de la texture du projectile

# --- MODE STICKY GLISSADE SUR VITRE (POUR LA FIOLE XFLASK) ---
@export var est_sticky_glissant: bool = false # Activer l impact collant et la glissade sur l ecran
@export var vitesse_glissade_ecran: float = 35.0 # Vitesse de glissade le long de l ecran (px/s)

# --- DEGATS INFLIGES AU JOUEUR ---
@export var peut_blesser_joueur: bool = true # L'impact retire de la vie au joueur s'il atteint la lucarne
@export var degats_joueur: int = 10
@export var points_score_interception: int = 25 # Score accordé si le joueur détruit le projectile en vol

@onready var anim_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var direction: Vector2 = Vector2.DOWN
var temps_vol: float = 0.0
var position_origine: Vector2 = Vector2.ZERO
var est_initialise: bool = false
var en_glissade: bool = false
var est_neutralise: bool = false # Abattu par le joueur : n'infligera aucun dégât
var degats_deja_infliges: bool = false

func _ready() -> void:
	z_index = 500 # Au-dessus des popups (z=100) et sous la vitre (z=900)
	if anim_sprite:
		anim_sprite.flip_h = inverser_visuel
		if anim_sprite.sprite_frames:
			if anim_sprite.sprite_frames.has_animation("projectile_xengren"):
				anim_sprite.play("projectile_xengren")
			elif anim_sprite.sprite_frames.has_animation("projectile_flask"):
				anim_sprite.play("projectile_flask")
			elif anim_sprite.sprite_frames.has_animation("fly"):
				anim_sprite.play("fly")
			elif anim_sprite.sprite_frames.has_animation("default"):
				anim_sprite.play("default")
	
	_creer_zone_collision_tir()
	get_tree().create_timer(temps_de_vie, false).timeout.connect(queue_free)

func _creer_zone_collision_tir() -> void:
	var area = Area2D.new()
	area.name = "ZoneDegats"
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	area.add_child(col)
	add_child(area)

func subir_degats(_degats: int = 1) -> void:
	if est_neutralise:
		return
	est_neutralise = true
	GlobalSettings.ajouter_score(points_score_interception)
	_declencher_explosion_impact()

func initialiser_lancer(pos_depart: Vector2, dir_forcee: Vector2 = Vector2.ZERO) -> void:
	est_initialise = true
	global_position = pos_depart
	position_origine = pos_depart
	temps_vol = 0.0
	en_glissade = false
	
	if dir_forcee != Vector2.ZERO:
		direction = dir_forcee.normalized()
	else:
		direction = direction_tir.normalized()
		
	# Orientation du missile vers sa direction de vol
	if type_projectile == "missile" or hauteur_lancer_arc <= 0.0:
		rotation = direction.angle() + (PI / 2.0)

func _physics_process(delta: float) -> void:
	if not est_initialise:
		initialiser_lancer(global_position, direction_tir)
		
	temps_vol += delta
	
	# --- 1. MODE MISSILE PROPULSÉ DIRECT (SANS EFFET DE GRENADE) ---
	if type_projectile == "missile" or (hauteur_lancer_arc <= 0.0 and not est_sticky_glissant):
		global_position += direction * vitesse * delta
		rotation = direction.angle() + (PI / 2.0)
		
		# Émission légère de fumée de propulsion réacteur
		if randf() < 0.35 and is_inside_tree():
			_emettre_fumee_propulsion()
			
		if temps_vol >= duree_vol_arc:
			_declencher_explosion_impact()
		return
	
	# --- 2. MODE STICKY GLISSADE SUR VITRE (XFLASK) ---
	if est_sticky_glissant and temps_vol >= duree_vol_arc:
		if not en_glissade:
			en_glissade = true
			_infliger_degats_si_dans_la_lucarne()
			if anim_sprite and anim_sprite.sprite_frames:
				var anim_courante = anim_sprite.animation
				if anim_sprite.sprite_frames.has_animation(anim_courante):
					var total_frames = anim_sprite.sprite_frames.get_frame_count(anim_courante)
					anim_sprite.stop()
					anim_sprite.frame = total_frames - 1
			print("[PROJECTILE STICKY] Fiole collée au CENTRE de la vitre !")
		
		global_position.y += vitesse_glissade_ecran * delta
	elif not est_sticky_glissant and temps_vol >= duree_vol_arc:
		# --- 3. MODE GRENADE BALISTIQUE CHUTE (XENGREN) ---
		_declencher_explosion_impact()
	else:
		# --- PHASE DE VOL PARABOLIQUE (GRENADES) ---
		var t: float = clamp(temps_vol / duree_vol_arc, 0.0, 1.0) if duree_vol_arc > 0.0 else 1.0
		position_origine.x += direction.x * vitesse * delta
		
		if est_sticky_glissant:
			var camera_y_centre: float = 87.5
			var viewport = get_viewport()
			if viewport and viewport.get_camera_2d():
				camera_y_centre = viewport.get_camera_2d().get_screen_center_position().y
			position_origine.y = lerp(position_origine.y, camera_y_centre, t * delta * 4.0)
		else:
			position_origine.y += direction.y * vitesse * delta
		
		var decalage_arc_y: float = 0.0
		if hauteur_lancer_arc > 0.0 and duree_vol_arc > 0.0:
			decalage_arc_y = -4.0 * hauteur_lancer_arc * t * (1.0 - t)
			
		global_position = position_origine + Vector2(0, decalage_arc_y)

func _emettre_fumee_propulsion() -> void:
	var p = CPUParticles2D.new()
	p.global_position = global_position - (direction * 8.0)
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 4
	p.lifetime = 0.3
	p.spread = 45.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 30.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.8, 0.8, 0.8, 0.7)
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.4, false).timeout.connect(p.queue_free)

## Vrai si l'impact se produit dans la lucarne de jeu (donc sur le joueur).
func _impact_atteint_le_joueur() -> bool:
	if est_neutralise or not peut_blesser_joueur or not is_inside_tree():
		return false
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera == null:
		return false
	var taille_lucarne = Vector2(get_viewport().get_visible_rect().size)
	var rect_lucarne = Rect2(camera.get_screen_center_position() - taille_lucarne / 2.0, taille_lucarne)
	return rect_lucarne.has_point(global_position)

func _declencher_explosion_impact() -> void:
	if _impact_atteint_le_joueur():
		GlobalSettings.infliger_degats_joueur(degats_joueur)

	if is_inside_tree():
		var particles = CPUParticles2D.new()
		particles.global_position = global_position
		particles.emitting = false
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = 24
		particles.lifetime = 0.6
		particles.spread = 180.0
		particles.gravity = Vector2(0, 150.0)
		particles.initial_velocity_min = 80.0
		particles.initial_velocity_max = 220.0
		particles.scale_amount_min = 4.0
		particles.scale_amount_max = 10.0
		particles.color = Color(1.0, 0.45, 0.1, 1.0)
		get_parent().add_child(particles)
		particles.emitting = true
		get_tree().create_timer(0.7, false).timeout.connect(particles.queue_free)
	queue_free()

func _infliger_degats_si_dans_la_lucarne() -> void:
	if degats_deja_infliges or est_neutralise or not peut_blesser_joueur or not is_inside_tree():
		return
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera == null:
		return
	var taille_lucarne = Vector2(get_viewport().get_visible_rect().size)
	var rect_lucarne = Rect2(camera.get_screen_center_position() - taille_lucarne / 2.0, taille_lucarne)
	if rect_lucarne.has_point(global_position):
		degats_deja_infliges = true
		GlobalSettings.infliger_degats_joueur(degats_joueur)
