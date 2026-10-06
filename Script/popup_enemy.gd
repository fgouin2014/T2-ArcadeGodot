class_name PopupEnemy
extends ActorBase

## Ennemi de type PopUp :
## - Type 1: T-800 Endosquelette (xgigend)
## - Type 2: Arnold Peau Synthétique (xarng)
## - Type 3: T-1000 Géant (xt100big)
##
## Comportements :
## - Apparition 'popup', salves 'shoot' (nombre_de_tirs), et disparition 'retract'
## - Déplacement X : "Immobile_X" ou "Patrouille_X" (défaut Patrouille pour xt100big, Immobile pour types 1 & 2)
## - Déplacement Y : support du déplacement vertical d'émergence/immersion
## - Impacts localisés : réservés exclusivement aux tirs alternatifs (HitArea: hit1, HitArea2: hit2, HitArea3: aim frame 0)

signal retract_termine()

@export_group("Attaque & Salves")
@export var nombre_de_tirs: int = 8 # Nombre de tirs par rafale
@export var intervalle_entre_tirs_sec: float = 0.18 # Intervalle entre chaque tir d'une rafale
@export var temps_entre_salves_sec: float = 1.2 # Temps de repos/marche entre deux salves
@export var duree_attaque_secondes: float = 9.0
@export var delai_avant_tir: float = 0.5 # Délai d'attente avant le premier tir / pause idle
@export var boucler_apparition_test: bool = false
@export var delai_reapparition_secondes: float = 5.0
@export var liberer_a_la_fin: bool = true

@export_group("Déplacement Axe X")
@export_enum("Immobile_X", "Patrouille_X") var mode_deplacement_x: String = "Immobile_X"
@export var deplacement_x_actif: bool = false # Si true ou si mode_deplacement_x == "Patrouille_X", active la patrouille
@export var limite_x_min: float = 60.0
@export var limite_x_max: float = 260.0

var en_cours_dattaque: bool = false
var _en_interruption_hit: bool = false
var _token_salve: int = 0
var _sens_x: int = -1

func _ready() -> void:
	super._ready()
	
	# Configuration automatique par défaut selon le type de scène
	if "xt100big" in name.to_lower():
		if mode_deplacement_x == "Immobile_X" and not deplacement_x_actif:
			mode_deplacement_x = "Patrouille_X"
			deplacement_x_actif = true

	if anim_sprite and anim_sprite.sprite_frames:
		if anim_sprite.sprite_frames.has_animation("popup"):
			anim_sprite.sprite_frames.set_animation_loop("popup", false)
		if anim_sprite.sprite_frames.has_animation("retract"):
			anim_sprite.sprite_frames.set_animation_loop("retract", false)
		if anim_sprite.sprite_frames.has_animation("hit"):
			anim_sprite.sprite_frames.set_animation_loop("hit", false)
		if anim_sprite.sprite_frames.has_animation("hit1"):
			anim_sprite.sprite_frames.set_animation_loop("hit1", false)
		if anim_sprite.sprite_frames.has_animation("hit2"):
			anim_sprite.sprite_frames.set_animation_loop("hit2", false)
		if anim_sprite.sprite_frames.has_animation("hithead"):
			anim_sprite.sprite_frames.set_animation_loop("hithead", false)

		if not anim_sprite.animation_finished.is_connected(_on_animated_sprite_finished):
			anim_sprite.animation_finished.connect(_on_animated_sprite_finished)

func activer_acteur() -> void:
	super.activer_acteur()
	_en_interruption_hit = false
	demarrer_sequence_popup()

func demarrer_sequence_popup() -> void:
	if possede_animation("popup"):
		jouer_animation("popup")
	else:
		demarrer_phase_attaque()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if not deja_active or est_elimine or not en_cours_dattaque:
		return
	
	# Déplacement sur l'axe X uniquement (Patrouille horizontale optionnelle)
	var patrouille_x := (mode_deplacement_x == "Patrouille_X" or deplacement_x_actif)
	if patrouille_x and not _en_interruption_hit and vitesse_deplacement > 0.0:
		velocity.x = float(_sens_x) * vitesse_deplacement
		global_position.x += velocity.x * delta
		
		if global_position.x <= limite_x_min:
			global_position.x = limite_x_min
			_sens_x = 1
		elif global_position.x >= limite_x_max:
			global_position.x = limite_x_max
			_sens_x = -1
	else:
		velocity.x = 0.0

## Dégâts par partie (nom_partie, degats, pos, est_missile)
func subir_degats_partie(nom_partie: String, degats: int, pos: Vector2, est_missile: bool = false) -> void:
	if est_elimine:
		return
	
	pv_actuels -= degats
	print("[POPUP] %s: subir_degats_partie '%s' (-%d PV, reste %d, missile=%s)" % [name, nom_partie, degats, pv_actuels, est_missile])
	
	if pv_actuels <= 0:
		subir_elimination()
		return
	
	# Les réactions spécifiques (hit1, hit2, aim0) sont RÉSERVÉES aux tirs alternatifs (missiles)
	if est_missile:
		var nom_p = nom_partie.to_lower()
		if "hitarea2" in nom_p:
			_declencher_hit_reaction("hit2")
		elif "hitarea3" in nom_p:
			_declencher_interruption_aim0()
		elif "hitarea" in nom_p or "hit" in nom_p:
			_declencher_hit_reaction("hit1")
		else:
			if possede_animation("hit"):
				_declencher_hit_reaction("hit")
	else:
		# Pour les tirs normaux sur Type 1 et Type 2 (xgigend / xarng) : léger hit visuel si pas en train de tirer
		if not ("xt100big" in name.to_lower()) and possede_animation("hit") and not en_cours_dattaque:
			jouer_animation("hit")

## Dégâts par missile direct (tir alternatif)
func subir_degats_missile(degats: int, pos_impact: Vector2 = Vector2.ZERO) -> void:
	if est_elimine:
		return
	
	var ecart_local = to_local(pos_impact)
	if ecart_local.y > 0.0:
		subir_degats_partie("HitArea3", degats, pos_impact, true)
	elif ecart_local.x < 0.0:
		subir_degats_partie("HitArea", degats, pos_impact, true)
	else:
		subir_degats_partie("HitArea2", degats, pos_impact, true)

## Dégâts primaires standards (tir normal)
func subir_degats(quantite: int) -> void:
	if est_elimine:
		return
	pv_actuels -= quantite
	
	if pv_actuels <= 0:
		subir_elimination()

## Réaction aux tirs alternatifs sur les bras/tête (hit1 ou hit2)
func _declencher_hit_reaction(anim_hit: String) -> void:
	if est_elimine:
		return
	_token_salve += 1 # Interrompt la salve de tir en cours
	_en_interruption_hit = true
	
	if possede_animation(anim_hit):
		jouer_animation(anim_hit)
	elif possede_animation("hit"):
		jouer_animation("hit")

## Réaction au tir alternatif sur le bas du corps (HitArea3) : fige sur aim frame 0
func _declencher_interruption_aim0() -> void:
	if est_elimine:
		return
	_token_salve += 1 # Interrompt la salve de tir en cours
	_en_interruption_hit = true
	
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("aim"):
		anim_sprite.animation = &"aim"
		anim_sprite.frame = 0 # Frame 0 (AtlasTexture_7)
		anim_sprite.pause()
	
	var token = _token_salve
	get_tree().create_timer(0.35, false).timeout.connect(func():
		if _token_salve == token and not est_elimine and is_inside_tree():
			_en_interruption_hit = false
			if en_cours_dattaque and possede_animation("shoot"):
				jouer_animation("shoot")
	)

func _on_animated_sprite_finished() -> void:
	if anim_sprite and anim_sprite.animation in [&"hit", &"hit1", &"hit2", &"hithead"]:
		_en_interruption_hit = false
		if en_cours_dattaque and not est_elimine:
			if possede_animation("shoot"):
				jouer_animation("shoot")
			elif possede_animation("idle"):
				jouer_animation("idle")
	elif anim_sprite and anim_sprite.animation == &"popup":
		if delai_avant_tir > 0.0:
			await attendre(delai_avant_tir)
		if not is_inside_tree() or est_elimine:
			return
		demarrer_phase_attaque()
	elif anim_sprite and anim_sprite.animation == &"retract":
		retract_termine.emit()
		if boucler_apparition_test:
			_masquer_visuel()
			await attendre(delai_reapparition_secondes)
			if not is_inside_tree() or est_elimine:
				return
			deja_active = false
			activer_acteur()
		elif not liberer_a_la_fin:
			hide()
			en_cours_dattaque = false
			_en_interruption_hit = false
		else:
			hide()
			queue_free()

func reinitialiser_pour_prochain_round(pv_round: int = 20) -> void:
	est_elimine = false
	deja_active = false
	_en_attente_activation = false
	_en_interruption_hit = false
	en_cours_dattaque = false
	_token_salve += 1
	pv_actuels = pv_round
	pv_max = pv_round
	collision_layer = 2
	collision_mask = 0
	input_pickable = true
	var col_corps = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_corps:
		col_corps.set_deferred("disabled", false)
	hide()
	print("[%s] Réinitialisé pour le prochain round (PV = %d)" % [name, pv_actuels])

func demarrer_phase_attaque() -> void:
	en_cours_dattaque = true
	_boucle_salves_popup()

func _boucle_salves_popup() -> void:
	while est_actif() and en_cours_dattaque and not est_elimine:
		var token = _token_salve
		
		# Phase de tir : Salve de 'nombre_de_tirs'
		if possede_animation("shoot") and not _en_interruption_hit:
			jouer_animation("shoot")
			
			for i in range(nombre_de_tirs):
				if not est_actif() or not en_cours_dattaque or _token_salve != token or _en_interruption_hit:
					break
				# Infliger 1 dégât joueur s'il est visible à l'écran
				if notifier == null or notifier.is_on_screen():
					GlobalSettings.infliger_degats_joueur(1)
				await attendre(intervalle_entre_tirs_sec)
		
		if not est_actif() or not en_cours_dattaque:
			break
		
		# Pause entre les salves
		if possede_animation("idle") and not _en_interruption_hit:
			jouer_animation("idle")
		await attendre(temps_entre_salves_sec)

## Élimination avec animation 'retract'
func subir_elimination() -> void:
	if est_elimine:
		return
	
	est_elimine = true
	en_cours_dattaque = false
	_en_interruption_hit = false
	_token_salve += 1
	
	# Désactiver les collisions physiques et de hit
	collision_layer = 0
	collision_mask = 0
	input_pickable = false
	var col_corps = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col_corps:
		col_corps.set_deferred("disabled", true)
	
	GlobalSettings.ajouter_score(points_score)
	
	if deverrouiller_stop_a_la_mort:
		_deverrouiller_stop_lie()
	
	# Jouer l'animation retract
	if possede_animation("retract"):
		jouer_animation("retract")
	else:
		retract_termine.emit()
		hide()
		if liberer_a_la_fin:
			queue_free()
