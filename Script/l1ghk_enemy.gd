class_name L1GhkEnemy
extends ActorBase

## Script modulaire multi-hitspots pour le Boss Terrestre XL1GHK sur chenilles.
## Upper Body complet = Torse, Tête, BrasGauche, BrasDroit
##
## Comportements :
## - Déplacement : Suit et se centre automatiquement sur la caméra en défilement,
##   effectue un va-et-vient dynamique à vitesse normale quand la caméra s'arrête.
## - Bras : Pas de projectiles tirés.
## - Tête : Tire l'attaque électrique 'xelec' vers la caméra UNIQUEMENT quand les 2 bras sont à 0% PV.
##   Dès 0% PV : arrêt IMMÉDIAT des tirs, bascule en 'damaged', et reste visible jusqu'à destruction de l'Upper Body.
## - Trappe Base : Tirs de salves de roquettes propulsées vers la caméra.
## - Règle Trappe & Dégâts :
##   • Les dégâts de la base sont TOUS RESTREINTS STRICTEMENT au Hitspot de la TRAPPE (HitspotBaseTrappe) et non à l'ensemble du châssis.
##   • Trappe FERMÉE : Aucun dégât ni explosion xexpl2 enregistré.
##   • Trappe OUVERTE (pendant les tirs de missiles ou de manière permanente quand Upper Body détruit) : Dégâts et xexpl2 actifs sur la trappe !

# --- SANTÉ MULTI-HITSPOTS ---
@export var pv_bras_gauche_max: int = 15
@export var pv_bras_droit_max: int = 15
@export var pv_tete_max: int = 15
@export var pv_torse_max: int = 20
@export var pv_chassis_max: int = 30

var pv_bras_gauche: int = 15
var pv_bras_droit: int = 15
var pv_tete: int = 15
var pv_torse: int = 20

var bras_gauche_hs: bool = false # À 0% PV : bras endommagé
var bras_droit_hs: bool = false  # À 0% PV : bras endommagé
var tete_detruite: bool = false  # À 0% PV : tête détruite (ne tire plus)
var torse_detruit: bool = false  # À 0% PV : torse détruit

var upper_body_detruit: bool = false # Vrai quand Torse+Tête+2 Bras sont détruits
var trappe_ouverte: bool = false     # Vrai pendant l'ouverture/tir de missiles ou après destruction upper body

# --- COMPOSANTS NŒUDS ---
@onready var sprite_bras_gauche: AnimatedSprite2D = get_node_or_null("BrasGauche") as AnimatedSprite2D
@onready var sprite_bras_droit: AnimatedSprite2D = get_node_or_null("BrasDroit") as AnimatedSprite2D
@onready var sprite_tete: AnimatedSprite2D = get_node_or_null("Tete") as AnimatedSprite2D
@onready var sprite_torse: Sprite2D = get_node_or_null("Torse") as Sprite2D

# --- MARQUEURS DE SPAWN PROJECTILES (Marker2D) ---
@onready var marker_tete: Marker2D = get_node_or_null("SpawnTete") as Marker2D
@onready var marker_missile: Marker2D = get_node_or_null("SpawnMissile") as Marker2D
@onready var marker_bras_gauche: Marker2D = get_node_or_null("SpawnBrasGauche") as Marker2D
@onready var marker_bras_droit: Marker2D = get_node_or_null("SpawnBrasDroit") as Marker2D

# --- PARAMÈTRES DE DÉPLACEMENT & CENTRAGE CAMÉRA ---
@export var vitesse_patrouille: float = 40.0 # Vitesse normale du va-et-vient (px/s)
@export var vitesse_centrage_camera: float = 60.0 # Vitesse d'alignement au centre de la caméra
@export var distance_va_et_vient_px: float = 120.0 # Amplitude du va-et-vient en pixels

# --- SCÈNES D'ATTAQUES & EXPLOSIONS ARCADE T2 ---
@export var cadence_missiles_sec: float = 3.5
@export var nombre_missiles_par_salve: int = 4
@export var missile_scene: PackedScene = preload("res://aseprite/xmissile.tscn")

@export var cadence_tir_tete_sec: float = 2.0
@export var elec_scene: PackedScene = preload("res://aseprite/effect/xelec.tscn")

@export var expl2_scene: PackedScene = preload("res://aseprite/effect/xexpl2.tscn") # Impact balle
@export var expl3_scene: PackedScene = preload("res://aseprite/effect/xexpl3.tscn") # Destruction pièce

# Rehaussement de la cible vers le haut de la vue (niveau des yeux / vitre au lieu du pied de la caméra)
@export var decalage_vertical_visee_y: float = -45.0 

var _chrono_missile: float = 0.0
var _chrono_tir_tete: float = 0.0
var _pos_origine_x: float = 0.0
var _sens_marche: float = -1.0 # -1.0 = Vers la gauche, 1.0 = Vers la droite
var _derniere_camera_x: float = 0.0
var _camera_initialisee: bool = false

func _ready() -> void:
	super._ready()
	vitesse_deplacement = 0.0
	velocity = Vector2.ZERO
	
	pv_max = pv_chassis_max
	pv_actuels = pv_max
	pv_bras_gauche = pv_bras_gauche_max
	pv_bras_droit = pv_bras_droit_max
	pv_tete = pv_tete_max
	pv_torse = pv_torse_max
	trappe_ouverte = false
	
	_configurer_hitspots_interactifs()

func _configurer_hitspots_interactifs() -> void:
	var table_hitspots = {
		"HitspotBrasGauche": "bras_gauche",
		"HitspotBrasDroit": "bras_droit",
		"HitspotTete": "tete",
		"HitspotTorse": "torse",
		"HitspotBaseTrappe": "trappe"
	}
	
	for nom_noeud in table_hitspots.keys():
		var hitspot = get_node_or_null(nom_noeud) as Area2D
		if hitspot:
			hitspot.input_pickable = true
			var partie = table_hitspots[nom_noeud]
			if not hitspot.input_event.is_connected(_on_hitspot_input.bind(partie)):
				hitspot.input_event.connect(_on_hitspot_input.bind(partie))

func _on_hitspot_input(_viewport: Node, event: InputEvent, _shape_idx: int, partie: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		subir_degats_partie(partie, 1, get_global_mouse_position())

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos_clic = get_global_mouse_position()
		var hitspot_proche: String = "trappe"
		var dist_min: float = 999999.0
		
		var hitspots_map = {
			"bras_gauche": get_node_or_null("HitspotBrasGauche"),
			"bras_droit": get_node_or_null("HitspotBrasDroit"),
			"tete": get_node_or_null("HitspotTete"),
			"torse": get_node_or_null("HitspotTorse"),
			"trappe": get_node_or_null("HitspotBaseTrappe")
		}
		
		for partie in hitspots_map.keys():
			var node_h = hitspots_map[partie]
			if node_h and node_h is Area2D and node_h.monitoring:
				var col = node_h.get_node_or_null("CollisionShape2D") as CollisionShape2D
				if col and not col.disabled:
					var d = pos_clic.distance_to(node_h.global_position)
					if d < dist_min:
						dist_min = d
						hitspot_proche = partie
						
		subir_degats_partie(hitspot_proche, 1, pos_clic)

func activer_acteur() -> void:
	super.activer_acteur()
	_pos_origine_x = global_position.x
	_sens_marche = -1.0
	_jouer_anim_base("base_idle")
	_mettre_a_jour_visuels_bras()

func _physics_process(delta: float) -> void:
	if not deja_active or est_elimine: return
	
	z_index = int(clamp(global_position.y, 1.0, 90.0))
	
	# --- 1. DÉTECTION, SUIVI ET CENTRAGE AUTOMATIQUE SUR LA CAMÉRA ---
	var camera = null
	var vp = get_viewport()
	if vp and vp.get_camera_2d():
		camera = vp.get_camera_2d()
		
	var delta_camera_x: float = 0.0
	var centre_cam_x: float = global_position.x
	if camera:
		centre_cam_x = camera.get_screen_center_position().x
		if not _camera_initialisee:
			_derniere_camera_x = camera.global_position.x
			_camera_initialisee = true
		else:
			delta_camera_x = camera.global_position.x - _derniere_camera_x
			_derniere_camera_x = camera.global_position.x

	var camera_en_mouvement = abs(delta_camera_x) > 0.05

	if camera_en_mouvement:
		global_position.x += delta_camera_x
		global_position.x = move_toward(global_position.x, centre_cam_x, vitesse_centrage_camera * delta)
		_pos_origine_x = global_position.x
	else:
		global_position.x += _sens_marche * vitesse_patrouille * delta
		
		if _sens_marche < 0.0 and global_position.x <= (_pos_origine_x - distance_va_et_vient_px):
			_sens_marche = 1.0
		elif _sens_marche > 0.0 and global_position.x >= _pos_origine_x:
			_sens_marche = -1.0

	# --- 2. ATTAQUE MISSILES DEPUIS LA TRAPPE ---
	var cadence_effective = (cadence_missiles_sec * 0.5) if upper_body_detruit else cadence_missiles_sec
	_chrono_missile += delta
	if _chrono_missile >= cadence_effective:
		_lancer_attaque_missiles()

	# --- 3. ATTAQUE ÉLECTRIQUE 'XELEC' DE LA TÊTE (VERROUILLAGE ABSOLU : UNIQUEMENT SI 2 BRAS HS ET TÊTE VIVANTE) ---
	var tete_active = (bras_gauche_hs and bras_droit_hs) and (not tete_detruite) and (pv_tete > 0) and (not upper_body_detruit)
	if tete_active:
		_chrono_tir_tete += delta
		if _chrono_tir_tete >= cadence_tir_tete_sec:
			_tirer_electricite_tete()
	else:
		_chrono_tir_tete = 0.0

# --- GESTION DES TIRS DE LA TÊTE (XELEC) ---
func _tirer_electricite_tete() -> void:
	_chrono_tir_tete = 0.0
	if est_elimine or not is_inside_tree() or elec_scene == null or tete_detruite or pv_tete <= 0 or upper_body_detruit:
		return
	
	var spawn_head = marker_tete.global_position if marker_tete else (global_position + Vector2(-24, -80))
	var centre_camera = spawn_head + Vector2(-150, decalage_vertical_visee_y)
	var vp = get_viewport()
	if vp and vp.get_camera_2d():
		centre_camera = vp.get_camera_2d().get_screen_center_position() + Vector2(0.0, decalage_vertical_visee_y)
		
	var dispersion_y = randf_range(-12.0, 12.0)
	var dir_vers_camera = ((centre_camera + Vector2(0.0, dispersion_y)) - spawn_head).normalized()
	
	var elec = elec_scene.instantiate()
	get_parent().add_child(elec)
	if elec.has_method("initialiser_lancer"):
		elec.initialiser_lancer(spawn_head, dir_vers_camera)
	else:
		elec.global_position = spawn_head
	print("[XL1GHK TÊTE] Arc électrique XELEC tiré vers le haut de la caméra !")

# --- GESTION HIERARCHIQUE DES HITSPOTS ET IMMUNITES ---
func subir_degats_partie(partie: String, degats: int = 1, pos_impact: Vector2 = Vector2.INF) -> void:
	if est_elimine: return
	
	var nom = partie.to_lower()
	
	# 1. BRAS GAUCHE
	if "bras" in nom and ("gauche" in nom or "left" in nom or "g" in nom):
		if bras_gauche_hs or upper_body_detruit: return
		pv_bras_gauche -= degats
		_faire_reagir_piece(sprite_bras_gauche)
		var pt_expl = pos_impact if pos_impact != Vector2.INF else (global_position + Vector2(-64, -53))
		_jouer_impact_balle_xexpl2(pt_expl)
		print("[XL1GHK] Impact Bras Gauche (PV : ", max(0, pv_bras_gauche), "/", pv_bras_gauche_max, ")")
		if pv_bras_gauche <= 0:
			_neutraliser_bras_gauche()
			
	# 2. BRAS DROIT
	elif "bras" in nom and ("droit" in nom or "right" in nom or "d" in nom):
		if bras_droit_hs or upper_body_detruit: return
		pv_bras_droit -= degats
		_faire_reagir_piece(sprite_bras_droit)
		var pt_expl = pos_impact if pos_impact != Vector2.INF else (global_position + Vector2(64, -53))
		_jouer_impact_balle_xexpl2(pt_expl)
		print("[XL1GHK] Impact Bras Droit (PV : ", max(0, pv_bras_droit), "/", pv_bras_droit_max, ")")
		if pv_bras_droit <= 0:
			_neutraliser_bras_droit()
			
	# 3. TÊTE
	elif "tete" in nom or "head" in nom:
		if upper_body_detruit or tete_detruite or pv_tete <= 0: return
		var pt_expl = pos_impact if pos_impact != Vector2.INF else (global_position + Vector2(-24, -80))
		
		# REGLE 1 : La tête ne peut être touchée tant qu'au moins UN bras est fonctionnel !
		if not (bras_gauche_hs and bras_droit_hs):
			print("[XL1GHK] TÊTE IMMUNISÉE ! Neutralisez les 2 bras en premier.")
			return
			
		pv_tete -= degats
		_faire_reagir_piece(sprite_tete)
		_jouer_impact_balle_xexpl2(pt_expl)
		print("[XL1GHK] Impact Tête (PV : ", max(0, pv_tete), "/", pv_tete_max, ")")
		if pv_tete <= (pv_tete_max / 2) and sprite_tete:
			if sprite_tete.sprite_frames.has_animation("damaged"):
				sprite_tete.play("damaged")
		if pv_tete <= 0:
			_detruire_tete()
			
	# 4. TORSE
	elif "torse" in nom or "torso" in nom or "corps" in nom:
		if upper_body_detruit or torse_detruit: return
		var pt_expl = pos_impact if pos_impact != Vector2.INF else (global_position + Vector2(-24, -51))
		
		# REGLE 2 : Le torse ne peut être détruit que lorsque Tête + 2 Bras sont à zéro !
		if not (bras_gauche_hs and bras_droit_hs and tete_detruite):
			print("[XL1GHK] TORSE IMMUNISÉ ! Neutralisez la Tête et les 2 Bras en premier.")
			return
			
		pv_torse -= degats
		_faire_reagir_piece(sprite_torse)
		_jouer_impact_balle_xexpl2(pt_expl)
		print("[XL1GHK] Impact Torse (PV : ", max(0, pv_torse), "/", pv_torse_max, ")")
		if pv_torse <= 0:
			_detruire_torse()
			
	# 5. TRAPPE SEULEMENT (et non l'ensemble du châssis / chenilles)
	elif "trappe" in nom or "hatch" in nom:
		var pt_expl = pos_impact if pos_impact != Vector2.INF else (global_position + Vector2(0, -25))
		
		# RÈGLE : La trappe ne prend des dégâts ET ne déclenche xexpl2 QUE si elle est OUVERTE !
		var trappe_vulnerable = trappe_ouverte or upper_body_detruit
		if not trappe_vulnerable:
			print("[XL1GHK] TRAPPE FERMÉE IMMUNISÉE ! Aucun dégât ni explosion enregistré.")
			return
			
		_faire_reagir_piece(anim_sprite)
		_jouer_impact_balle_xexpl2(pt_expl)
		subir_degats(degats)

func _faire_reagir_piece(sprite: CanvasItem) -> void:
	if sprite == null: return
	var tween = sprite.create_tween()
	sprite.modulate = Color(3.5, 3.5, 3.5, 1.0) # Flash blanc dégât
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

func _neutraliser_bras_gauche() -> void:
	bras_gauche_hs = true
	if sprite_bras_gauche:
		if sprite_bras_gauche.sprite_frames.has_animation("damaged"):
			sprite_bras_gauche.play("damaged")
	_jouer_explosion_destruction_xexpl3(global_position + Vector2(-64, -53))
	_desactiver_collision_hitspot("HitspotBrasGauche")
	print("[XL1GHK] Bras Gauche HS (0% PV) -> Explosion XEXPL3 & Neutralisé !")
	_verifier_activation_tete()

func _neutraliser_bras_droit() -> void:
	bras_droit_hs = true
	if sprite_bras_droit:
		if sprite_bras_droit.sprite_frames.has_animation("damaged"):
			sprite_bras_droit.play("damaged")
	_jouer_explosion_destruction_xexpl3(global_position + Vector2(64, -53))
	_desactiver_collision_hitspot("HitspotBrasDroit")
	print("[XL1GHK] Bras Droit HS (0% PV) -> Explosion XEXPL3 & Neutralisé !")
	_verifier_activation_tete()

func _verifier_activation_tete() -> void:
	if bras_gauche_hs and bras_droit_hs and not tete_detruite:
		print("[XL1GHK] Les 2 bras sont neutralisés ! La tête commence à tirer XELEC et devient vulnérable !")

func _detruire_tete() -> void:
	tete_detruite = true
	pv_tete = 0
	_chrono_tir_tete = 0.0
	_desactiver_collision_hitspot("HitspotTete")
	
	if sprite_tete and sprite_tete.sprite_frames.has_animation("damaged"):
		sprite_tete.play("damaged")
		
	_jouer_explosion_destruction_xexpl3(global_position + Vector2(-24, -80))
	print("[XL1GHK] Tête neutralisée (0% PV) -> Explosion XEXPL3, damaged & ARRÊT DÉFINITIF XELEC !")

func _detruire_torse() -> void:
	torse_detruit = true
	upper_body_detruit = true
	trappe_ouverte = true # La trappe reste ouverte en permanence !
	
	if sprite_torse: sprite_torse.visible = false
	if sprite_tete: sprite_tete.visible = false
	if sprite_bras_gauche: sprite_bras_gauche.visible = false
	if sprite_bras_droit: sprite_bras_droit.visible = false
	
	for nom_h in ["HitspotTorse", "HitspotTete", "HitspotBrasGauche", "HitspotBrasDroit"]:
		_desactiver_collision_hitspot(nom_h)
		
	_jouer_explosion_destruction_xexpl3(global_position + Vector2(-24, -51))
	print("[XL1GHK] UPPER BODY DÉTRUIT -> Explosion XEXPL3 ! La trappe reste ouverte et la base est vulnérable !")
	_jouer_anim_base("missile_salvo")

func _desactiver_collision_hitspot(nom_noeud: String) -> void:
	var h = get_node_or_null(nom_noeud) as Area2D
	if h:
		h.input_pickable = false
		var col = h.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col: col.set_deferred("disabled", true)

func _lancer_attaque_missiles() -> void:
	_chrono_missile = 0.0
	if est_elimine or not is_inside_tree(): return

	if not upper_body_detruit:
		_jouer_anim_base("missile_open")
		await attendre(0.2)
		trappe_ouverte = true # Trappe ouverte pendant les tirs !
		await attendre(0.2)
		if est_elimine or not is_inside_tree(): return

	trappe_ouverte = true
	_jouer_anim_base("missile_salvo")

	var centre_camera = global_position + Vector2(-150, decalage_vertical_visee_y)
	var vp = get_viewport()
	if vp and vp.get_camera_2d():
		centre_camera = vp.get_camera_2d().get_screen_center_position() + Vector2(0.0, decalage_vertical_visee_y)

	var spawn_pos = marker_missile.global_position if marker_missile else (global_position + Vector2(-24, -55))
	for i in range(nombre_missiles_par_salve):
		if est_elimine or not is_inside_tree(): break
		if missile_scene:
			var m = missile_scene.instantiate()
			get_parent().add_child(m)
			
			var dispersion = Vector2(randf_range(-25.0, 25.0), randf_range(-15.0, 15.0))
			var cible_missile = centre_camera + dispersion
			var dir_vers_camera = (cible_missile - spawn_pos).normalized()
			var offset_spawn = Vector2((i - (nombre_missiles_par_salve - 1) * 0.5) * 10.0, 0.0)
			
			if m.has_method("initialiser_lancer"):
				m.initialiser_lancer(spawn_pos + offset_spawn, dir_vers_camera)
			else:
				m.global_position = spawn_pos + offset_spawn
		await attendre(0.25)

	if est_elimine or not is_inside_tree(): return

	if not upper_body_detruit:
		_jouer_anim_base("missile_close")
		await attendre(0.4)
		trappe_ouverte = false # Refermeture de la trappe
		if not est_elimine:
			_jouer_anim_base("base_idle")

func _jouer_anim_base(nom_anim: String) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(nom_anim):
		anim_sprite.play(nom_anim)

func _mettre_a_jour_visuels_bras() -> void:
	if sprite_bras_gauche:
		if sprite_bras_gauche.sprite_frames.has_animation("damaged" if bras_gauche_hs else "idle"):
			sprite_bras_gauche.play("damaged" if bras_gauche_hs else "idle")
	if sprite_bras_droit:
		if sprite_bras_droit.sprite_frames.has_animation("damaged" if bras_droit_hs else "idle"):
			sprite_bras_droit.play("damaged" if bras_droit_hs else "idle")
	if sprite_tete:
		if sprite_tete.sprite_frames.has_animation("damaged" if tete_detruite else "idle"):
			sprite_tete.play("damaged" if tete_detruite else "idle")

# --- IMPACT DE BALLE ANIMÉ ARCADE (XEXPL2) AU POINT D'IMPACT EXACT ---
func _jouer_impact_balle_xexpl2(pos: Vector2) -> void:
	if not is_inside_tree() or expl2_scene == null: return
	var exp2 = expl2_scene.instantiate()
	exp2.global_position = pos
	exp2.z_index = 2000
	get_parent().add_child(exp2)
	var anim = exp2.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		var anim_name = "explose" if anim.sprite_frames.has_animation("explose") else "default"
		anim.play(anim_name)
		anim.animation_finished.connect(func(_a=null): if is_instance_valid(exp2): exp2.queue_free())
	else:
		get_tree().create_timer(0.6, false).timeout.connect(exp2.queue_free)

# --- EXPLOSION DE DESTRUCTION PIÈCE ANIMÉE ARCADE (XEXPL3) ---
func _jouer_explosion_destruction_xexpl3(pos: Vector2) -> void:
	if not is_inside_tree() or expl3_scene == null: return
	var exp3 = expl3_scene.instantiate()
	exp3.global_position = pos
	exp3.z_index = 2000
	get_parent().add_child(exp3)
	var anim = exp3.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim:
		var anim_name = "explose" if anim.sprite_frames.has_animation("explose") else "default"
		anim.play(anim_name)
		anim.animation_finished.connect(func(_a=null): if is_instance_valid(exp3): exp3.queue_free())
	else:
		get_tree().create_timer(0.7, false).timeout.connect(exp3.queue_free)

func subir_degats(quantite: int) -> void:
	var trappe_vulnerable = trappe_ouverte or upper_body_detruit
	if not trappe_vulnerable:
		print("[XL1GHK] Trappe fermée immunisée !")
		return
		
	pv_actuels -= quantite
	print("[XL1GHK TRAPPE] Dégâts subis : ", quantite, " (PV restants : ", max(0, pv_actuels), "/", pv_max, ")")
	if pv_actuels <= 0:
		subir_elimination()

func subir_elimination() -> void:
	if est_elimine: return
	est_elimine = true
	print("[XL1GHK] DESTRUCTION TOTALE DU BOSS !")
	_jouer_anim_base("base_destroy")
	
	for i in range(5):
		var offset = Vector2(randf_range(-60, 60), randf_range(-40, 20))
		_jouer_explosion_destruction_xexpl3(global_position + offset)
		await attendre(0.15)
		
	super.subir_elimination()
