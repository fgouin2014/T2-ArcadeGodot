class_name FlyingOrb
extends ActorBase

signal orb_detruite(orb_node: FlyingOrb)

@export_group("Déplacement & Wooble")
@export var vitesse_strafe: float = 35.0
@export var amplitude_wooble: float = 6.0
@export var frequence_wooble: float = 3.5

@export_group("Attaque & Tirs")
@export var nombre_de_tirs: int = 3 ## Nombre de coups tirés par phase d'attaque
@export var cadence_rafale_sec: float = 0.2 ## Intervalle entre chaque tir d'une même salve
@export var temps_entre_attaques_min: float = 2.5
@export var temps_entre_attaques_max: float = 4.5
@export var tirer_missile: bool = false ## true = tire des projectiles xmissile, false = tirs standards instantanés ennemi (GlobalSettings.infliger_degats_joueur)
@export var scene_missile: PackedScene = preload("res://aseprite/xmissile.tscn")
@export var scene_explosion: PackedScene = preload("res://aseprite/effect/xexpl2.tscn")

@export_group("Émergence")
## Mode d'apparition quand posé directement dans une scène (sans porte parente pods) :
## EMERGE_25D = émerge du fond vers le premier plan au démarrage.
## HATCH = démarre comme œuf fermé, éclore (open) à l'activation, puis prend son envol.
## VOL_DIRECT = commence directement en vol stationnaire.
enum ModeEmergence { EMERGE_25D, HATCH, VOL_DIRECT }
@export var mode_emergence: ModeEmergence = ModeEmergence.EMERGE_25D

enum EtatOrb { EMERGENCE, VOL_LIBRE, RECUL, TIR, MORT }
var etat_orb: EtatOrb = EtatOrb.EMERGENCE

var temps_vol: float = 0.0
var direction_strafe: float = 1.0
var cible_y_vol: float = 0.0
var timer_prochaine_attaque: float = 3.0
var porte_parente: Node2D = null

func _ready() -> void:
	pv_actuels = pv_max
	_resoudre_priorite_popup()
	_est_prioritaire_popup = true
	z_index = 250
	
	if anim_sprite:
		anim_sprite.animation_finished.connect(_sur_animation_terminee)
		if mode_emergence == ModeEmergence.HATCH and porte_parente == null:
			anim_sprite.play("closed")
	
	# Si issu d'une porte (pods), ActorBase ne doit pas masquer le visuel
	if porte_parente != null:
		deja_active = true
		_afficher_visuel()
	else:
		super._ready()

func activer_acteur() -> void:
	super.activer_acteur()
	cible_y_vol = global_position.y
	
	if porte_parente == null:
		match mode_emergence:
			ModeEmergence.HATCH:
				_demarrer_hatch()
			ModeEmergence.EMERGE_25D:
				_demarrer_avancement_25d()
			ModeEmergence.VOL_DIRECT:
				_demarrer_vol_libre()
	else:
		_demarrer_avancement_25d()

## Initialisation depuis une porte de pods
func initialiser_depuis_porte(porte: Node2D) -> void:
	porte_parente = porte
	global_position = porte.global_position
	cible_y_vol = porte.global_position.y + 25.0
	deja_active = true
	_afficher_visuel()
	# call_deferred : le nœud sera ajouté à l'arbre par PodHatch APRÈS cet appel.
	# On attend le prochain frame pour que _ready() soit exécuté et que anim_sprite soit prêt.
	call_deferred("_demarrer_avancement_25d")


## Éclosion Hatch : joue 'open' une fois puis vole
func _demarrer_hatch() -> void:
	deja_active = true
	_afficher_visuel()
	etat_orb = EtatOrb.EMERGENCE
	if anim_sprite:
		anim_sprite.show()
		anim_sprite.play("open")

## Avancement vers l'écran en 2.5D (utilise emerge_25d)
func _demarrer_avancement_25d() -> void:
	deja_active = true
	_afficher_visuel()
	etat_orb = EtatOrb.EMERGENCE
	if cible_y_vol == 0.0:
		cible_y_vol = global_position.y + (25.0 if porte_parente != null else 0.0)
		
	if anim_sprite:
		anim_sprite.show()
		anim_sprite.play("emerge_25d")
		
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position:y", cible_y_vol, 0.7)

## Recul vers le fond en 2.5D (utilise retract_25d)
func _demarrer_recul_25d() -> void:
	if est_elimine or etat_orb == EtatOrb.MORT:
		return
	etat_orb = EtatOrb.RECUL
	if anim_sprite:
		anim_sprite.play("retract_25d")


func _demarrer_vol_libre() -> void:
	if est_elimine: return
	etat_orb = EtatOrb.VOL_LIBRE
	if anim_sprite:
		anim_sprite.play("fly")
	timer_prochaine_attaque = randf_range(temps_entre_attaques_min, temps_entre_attaques_max)
	_init_direction_strafe()

## Initialise la direction de strafe selon direction_deplacement ou aléatoirement.
func _init_direction_strafe() -> void:
	if direction_deplacement == "droite_vers_gauche":
		direction_strafe = -1.0
	elif direction_deplacement == "gauche_vers_droite":
		direction_strafe = 1.0
	else:
		direction_strafe = -1.0 if randf() < 0.5 else 1.0


func _physics_process(delta: float) -> void:
	# Tant que l'acteur n'est pas activé à l'écran/stop, AUCUN déplacement ne doit s'exécuter
	if not deja_active or est_elimine or not is_inside_tree():
		return

	# Priorité visuelle au-dessus du décor
	z_index = 250
		
	temps_vol += delta
	
	if etat_orb == EtatOrb.VOL_LIBRE or etat_orb == EtatOrb.TIR or etat_orb == EtatOrb.RECUL or etat_orb == EtatOrb.EMERGENCE:
		# 1. Wooble sinusoïdal vertical et horizontal
		var decalage_wooble_y = sin(temps_vol * frequence_wooble) * amplitude_wooble
		var decalage_wooble_x = cos(temps_vol * (frequence_wooble * 0.7)) * (amplitude_wooble * 0.5)
		
		# 2. Strafe latéral continu
		if etat_orb != EtatOrb.TIR:
			velocity.x = (direction_strafe * vitesse_strafe) + decalage_wooble_x
			# Limites d'écran relatives à la caméra
			var camera = get_viewport().get_camera_2d()
			if camera:
				var cam_x = camera.global_position.x
				var min_x = cam_x - 110.0
				var max_x = cam_x + 110.0
				if global_position.x < min_x:
					global_position.x = min_x
					direction_strafe = 1.0
				elif global_position.x > max_x:
					global_position.x = max_x
					direction_strafe = -1.0
			else:
				if randf() < 0.01:
					direction_strafe *= -1.0
		else:
			velocity.x = 0.0
			
		velocity.y = (cible_y_vol + decalage_wooble_y - global_position.y) * 4.0
		move_and_slide()
		
		# 3. Timer en vol libre : Attaque
		if etat_orb == EtatOrb.VOL_LIBRE:
			timer_prochaine_attaque -= delta
			if timer_prochaine_attaque <= 0.0:
				_sequence_attaque()


func _sequence_attaque() -> void:
	if est_elimine or etat_orb == EtatOrb.MORT: return
	etat_orb = EtatOrb.TIR
	if anim_sprite:
		anim_sprite.play("shoot")
		
	var nb_coups = max(1, nombre_de_tirs)
	for i in range(nb_coups):
		if est_elimine or etat_orb == EtatOrb.MORT or not is_inside_tree():
			break
		_tirer_un_coup()
		if i < nb_coups - 1:
			await get_tree().create_timer(cadence_rafale_sec, false).timeout
			
	# Fin de salve → recul 2.5D vers le fond pour boucler le cycle
	if not est_elimine and etat_orb == EtatOrb.TIR:
		await get_tree().create_timer(0.3, false).timeout
		_demarrer_recul_25d()


func _tirer_un_coup() -> void:
	if tirer_missile and scene_missile and is_inside_tree():
		var mis = scene_missile.instantiate() as Node2D
		if mis:
			var parent_scene = get_parent() if get_parent() else self
			parent_scene.add_child(mis)
			var pos_depart = global_position + Vector2(0, 12)
			if mis.has_method("initialiser_tir"):
				var cible_joueur = pos_depart + Vector2(randf_range(-40.0, 40.0), 160.0)
				mis.initialiser_tir(pos_depart, cible_joueur, false)
			elif mis.has_method("initialiser_lancer"):
				var dir_tir = Vector2(randf_range(-0.3, 0.3), 1.0).normalized()
				mis.initialiser_lancer(pos_depart, dir_tir)
			else:
				mis.global_position = pos_depart
			print("[XORB] Missile tiré vers le joueur !")
	else:
		# Tir instantané standard ennemi (sans projectile)
		if notifier == null or notifier.is_on_screen():
			GlobalSettings.infliger_degats_joueur(1)
			print("[XORB] Tir standard infligeant 1 dégât au joueur !")

func _sur_animation_terminee() -> void:
	if est_elimine or not anim_sprite:
		return
		
	match anim_sprite.animation:
		"open":
			# Fin de l'éclosion -> prend son envol (mode HATCH uniquement)
			_demarrer_vol_libre()
		"emerge_25d":
			# Fin du zoom vers l'avant → attaque immédiate
			_init_direction_strafe()
			_sequence_attaque()
		"retract_25d":
			# Fin du recul vers le fond → temporisation puis ré-avance
			get_tree().create_timer(randf_range(1.0, 2.5), false).timeout.connect(func():
				if not est_elimine and is_inside_tree() and etat_orb != EtatOrb.MORT:
					_demarrer_avancement_25d()
			)
		"die":
			queue_free()


func subir_degats(quantite: int = 1) -> void:
	if est_elimine: return
	pv_actuels -= quantite
	_flash_blanc()
	if pv_actuels <= 0:
		_eliminer_orb()

func _flash_blanc() -> void:
	if anim_sprite == null: return
	anim_sprite.modulate = Color(3.5, 3.5, 3.5, 1.0)
	var tw = create_tween()
	tw.tween_property(anim_sprite, "modulate", Color.WHITE, 0.08)

func _eliminer_orb() -> void:
	if est_elimine: return
	est_elimine = true
	etat_orb = EtatOrb.MORT
	GlobalSettings.ajouter_score(points_score)
	orb_detruite.emit(self)
	
	# Notifie la porte parente
	if is_instance_valid(porte_parente) and porte_parente.has_method("notifier_ennemi_detruit"):
		porte_parente.notifier_ennemi_detruit()
		
	# Explosion xexpl2
	if scene_explosion and is_inside_tree():
		var exp_node = scene_explosion.instantiate() as Node2D
		if exp_node:
			exp_node.global_position = global_position
			exp_node.z_index = 2000
			var parent_scene = get_parent() if get_parent() else self
			parent_scene.add_child(exp_node)
			var a = exp_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if a:
				var anim_n = "explose" if a.sprite_frames.has_animation("explose") else "default"
				a.play(anim_n)
				a.animation_finished.connect(func(_x=null): if is_instance_valid(exp_node): exp_node.queue_free())
			else:
				get_tree().create_timer(0.8, false).timeout.connect(func(): if is_instance_valid(exp_node): exp_node.queue_free())

	hide()
	queue_free()
