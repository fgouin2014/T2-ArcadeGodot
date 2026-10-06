class_name PodHatch
extends Node2D

signal porte_detruite(porte_node: PodHatch)
signal porte_ouverte(porte_node: PodHatch)
signal porte_fermee(porte_node: PodHatch)

enum TypePorte { HAUT_A, BAS_B }
@export var type_porte: TypePorte = TypePorte.HAUT_A
@export var pv_max: int = 5
@export var temps_ouvert_sec: float = 8.0
@export var scene_ennemi_orb: PackedScene = preload("res://aseprite/xorb.tscn")
@export var scene_explosion: PackedScene = preload("res://aseprite/effect/xexpl3.tscn")

@export_group("Positionnement Apparitions")
## Mode de positionnement pour les explosions.
## local_parallax_compatible = suit le parallax naturellement (recommandé pour décors dans ParallaxLayer)
## global_world_space = position fixe dans l'espace monde
@export_enum("local_parallax_compatible", "global_world_space") var mode_positionnement_apparitions: String = "local_parallax_compatible"

enum EtatPorte { FERME, OUVERTURE, OUVERT, FERMETURE, DETRUIT }
var etat_actuel: EtatPorte = EtatPorte.FERME
var pv_actuels: int = 5
var en_vie: bool = true

var gestionnaire_pods: Node2D = null
var ennemi_actuel: Node2D = null # Ennemi en cours de vie issu de cette porte

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	pv_actuels = pv_max
	if anim_sprite:
		anim_sprite.animation_finished.connect(_sur_animation_terminee)
		anim_sprite.play("closed")
	
	_activer_hit_area(true)

func peut_s_ouvrir() -> bool:
	# Une porte ne peut s'ouvrir que si elle est fermée, vivante, et n'a pas d'ennemi déjà en vie
	return en_vie and etat_actuel == EtatPorte.FERME and (ennemi_actuel == null or not is_instance_valid(ennemi_actuel))

func tenter_ouverture() -> bool:
	if not peut_s_ouvrir():
		return false
	_ouvrir()
	return true

func subir_degats_sur_enfant(_enfant: Node, quantite: int) -> void:
	subir_degats(quantite)

func subir_degats(quantite: int = 1) -> void:
	if not en_vie or etat_actuel == EtatPorte.DETRUIT:
		return
		
	# RÈGLE : La porte ne prend des dégâts QUE quand elle est fermée, en cours d'ouverture, ou en cours de fermeture.
	# PAS de dégâts quand elle est complètement ouverte (état OUVERT / openned).
	if etat_actuel == EtatPorte.OUVERT:
		return

	pv_actuels -= quantite
	_flash_blanc()
	
	if pv_actuels <= 0:
		_detruire_porte()

func _flash_blanc() -> void:
	if anim_sprite == null:
		return
	anim_sprite.modulate = Color(3.5, 3.5, 3.5, 1.0)
	var tw := create_tween()
	tw.tween_property(anim_sprite, "modulate", Color.WHITE, 0.08)

func _ouvrir() -> void:
	etat_actuel = EtatPorte.OUVERTURE
	_activer_hit_area(true)
	if anim_sprite:
		anim_sprite.play("open")

func _fermer() -> void:
	if not en_vie or etat_actuel != EtatPorte.OUVERT:
		return
	etat_actuel = EtatPorte.FERMETURE
	_activer_hit_area(true)
	if anim_sprite:
		anim_sprite.play("close")

func _sur_animation_terminee() -> void:
	if not en_vie or etat_actuel == EtatPorte.DETRUIT:
		return
		
	match anim_sprite.animation:
		"open":
			etat_actuel = EtatPorte.OUVERT
			# DÉSACTIVATION des dégâts sur la porte pendant qu'elle est ouverte
			_activer_hit_area(false)
			if anim_sprite:
				anim_sprite.play("openned")
			
			# Spawn de l'ennemi associé (si aucun ennemi actif)
			_spawner_ennemi_associe()
			
			porte_ouverte.emit(self)
			
			# Pour les portes du haut (xorb) : se referme 1.0 seconde après l'apparition
			# Pour les portes du bas (silverfish) : conserve le délai complet (8 secondes)
			var delai_fermeture = 1.0 if type_porte == TypePorte.HAUT_A else temps_ouvert_sec
			get_tree().create_timer(delai_fermeture, false).timeout.connect(func():
				if is_instance_valid(self) and en_vie and etat_actuel == EtatPorte.OUVERT:
					_fermer()
			)
			
		"close":
			etat_actuel = EtatPorte.FERME
			_activer_hit_area(true)
			if anim_sprite:
				anim_sprite.play("closed")
			porte_fermee.emit(self)

func _spawner_ennemi_associe() -> void:
	if ennemi_actuel != null and is_instance_valid(ennemi_actuel):
		return
		
	if type_porte == TypePorte.HAUT_A:
		# Spawn de l'ennemi volant xorb
		if scene_ennemi_orb and is_inside_tree():
			var orb = scene_ennemi_orb.instantiate() as Node2D
			if orb:
				# 1. Configurer la position et la référence AVANT d'ajouter à l'arbre
				if orb.has_method("initialiser_depuis_porte"):
					orb.initialiser_depuis_porte(self)
				else:
					orb.global_position = global_position
					
				orb.z_index = 250 # Priorité d'affichage au-dessus des portes et du décor
				
				# 2. Chercher le conteneur EnnemisPlaces ou la racine du niveau
				var conteneur_cible: Node = null
				var scene_courante = get_tree().current_scene
				if scene_courante:
					conteneur_cible = scene_courante.find_child("EnnemisPlaces", true, false)
					if conteneur_cible == null:
						conteneur_cible = scene_courante
				if conteneur_cible == null:
					conteneur_cible = get_parent() if get_parent() else self
					
				conteneur_cible.add_child(orb)
				ennemi_actuel = orb
				if is_instance_valid(gestionnaire_pods) and gestionnaire_pods.has_method("enregistrer_ennemi_spawn"):
					gestionnaire_pods.enregistrer_ennemi_spawn(orb)
				print("[PODHATCH] xorb spawned et ajouté à : ", conteneur_cible.name, " à pos : ", orb.global_position)
	else:
		# Porte Bas B : xfish (sera implémenté plus tard)
		print("[POD HATCH] Porte B ouverte (xfish en attente d'implémentation)")

func notifier_ennemi_detruit() -> void:
	ennemi_actuel = null
	print("[POD HATCH] Ennemi détruit, slot libéré pour : ", name)

func _detruire_porte() -> void:
	if not en_vie:
		return
	en_vie = false
	etat_actuel = EtatPorte.DETRUIT
	_activer_hit_area(false)
	
	if anim_sprite:
		if anim_sprite.sprite_frames.has_animation("destroyed"):
			anim_sprite.play("destroyed")
		elif anim_sprite.sprite_frames.has_animation("detroyed"):
			anim_sprite.play("detroyed")
			
	_spawn_explosion()
	porte_detruite.emit(self)
	print("[POD HATCH] Porte détruite : ", name, " (Type: ", type_porte, ")")

func _spawn_explosion() -> void:
	if scene_explosion == null or not is_inside_tree():
		return
	var exp_node = scene_explosion.instantiate() as Node2D
	if exp_node:
		exp_node.z_index = 50
		var conteneur_parent = get_parent() if get_parent() else self
		if mode_positionnement_apparitions == "global_world_space":
			exp_node.global_position = global_position
		else:
			exp_node.position = conteneur_parent.to_local(global_position)
		conteneur_parent.add_child(exp_node)
		
		var a = exp_node.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if a:
			var anim_n = "explose" if a.sprite_frames.has_animation("explose") else "default"
			a.play(anim_n)
			a.animation_finished.connect(func(_x=null): if is_instance_valid(exp_node): exp_node.queue_free())
		else:
			get_tree().create_timer(0.8, false).timeout.connect(func(): if is_instance_valid(exp_node): exp_node.queue_free())

func _activer_hit_area(actif: bool) -> void:
	if hit_area:
		hit_area.set_deferred("monitoring", false)
		hit_area.set_deferred("monitorable", actif)
