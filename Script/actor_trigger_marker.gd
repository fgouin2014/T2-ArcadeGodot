class_name ActorTriggerMarker
extends Marker2D

## Marker2D permettant de commander un acteur (ex: s'arrêter, jouer Idle, faire pause, quitter le level).
## Peut être déclenché soit par proximité physique de l'acteur (au passage),
## soit en liaison avec un StopMarker de caméra.

@export_group("Acteur Cible")
## Sélection directe du nœud acteur dans l'arbre de scène.
@export var acteur_cible: NodePath
## Nom de l'acteur cible si NodePath n'est pas utilisé (ex: "xyjc", "xt100").
@export var nom_acteur_cible: String = ""

@export_group("Action")
## Action à appliquer à l'acteur lors du déclenchement.
@export_enum(
	"aucun",
	"quitter_et_liberer",
	"arret_idle",
	"pause_nette",
	"reprendre_marche",
	"jouer_animation",
	"subir_elimination"
) var action: String = "quitter_et_liberer"

## Nom de l'animation à jouer si l'action 'jouer_animation' est choisie.
@export var nom_animation: String = "idle"
## Délai en secondes avant d'appliquer l'action après déclenchement.
@export var delai_action_sec: float = 0.0
## Si coché, le marqueur ne s'active qu'une seule fois.
@export var declencher_une_seule_fois: bool = true

@export_group("Déclenchement")
## Mode de déclenchement :
## - "proximite_acteur" : se déclenche quand l'acteur passe à proximité horizontale (rayon_declenchement_px).
## - "sur_stop_camera" : se déclenche quand le StopMarker associé est atteint.
## - "les_deux" : se déclenche au premier événement qui survient.
@export_enum("proximite_acteur", "sur_stop_camera", "les_deux") var mode_declenchement: String = "proximite_acteur"
## Distance en X à laquelle l'acteur déclenche le marqueur en marchant (en pixels).
@export var rayon_declenchement_px: float = 16.0
## Référence optionnelle à un StopMarker si mode "sur_stop_camera" ou "les_deux".
@export var stop_associe: NodePath

var _deja_declenche: bool = false
var _acteur_cache: ActorBase = null
var _derniere_pos_x_acteur: float = -999999.0

func _ready() -> void:
	print("[ActorTriggerMarker] %s : _ready() appelé" % name)
	call_deferred("_resoudre_references")

func _resoudre_references() -> void:
	print("[ActorTriggerMarker] %s : _resoudre_references() appelé" % name)
	_resoudre_acteur()
	_connecter_stop()

func _resoudre_acteur() -> ActorBase:
	if is_instance_valid(_acteur_cache):
		return _acteur_cache

	# 1. Par NodePath direct
	if acteur_cible != null and not acteur_cible.is_empty():
		var node = get_node_or_null(acteur_cible)
		print("[ActorTriggerMarker] %s : Tentative résolution par NodePath '%s' -> %s" % [name, acteur_cible, node])
		if node is ActorBase:
			_acteur_cache = node as ActorBase
			print("[ActorTriggerMarker] %s : Acteur trouvé par NodePath : %s" % [name, _acteur_cache.name])
			return _acteur_cache
		elif node != null:
			print("[ActorTriggerMarker] %s : Node trouvé mais n'est pas ActorBase (type: %s)" % [name, node.get_class()])

	# 2. Par nom dans la scène
	var nom_recherche = nom_acteur_cible
	if nom_recherche.is_empty() and acteur_cible != null and not acteur_cible.is_empty():
		nom_recherche = acteur_cible.get_concatenated_names().split("/")[-1]

	if not nom_recherche.is_empty():
		var scene = get_tree().current_scene if get_tree() else null
		if scene:
			var node = scene.find_child(nom_recherche, true, false)
			print("[ActorTriggerMarker] %s : Tentative résolution par nom '%s' -> %s" % [name, nom_recherche, node])
			if node is ActorBase:
				_acteur_cache = node as ActorBase
				print("[ActorTriggerMarker] %s : Acteur trouvé par nom : %s" % [name, _acteur_cache.name])
				return _acteur_cache

	print("[ActorTriggerMarker] %s : ÉCHEC résolution acteur cible" % name)
	return null

func _connecter_stop() -> void:
	if mode_declenchement == "proximite_acteur":
		return

	var stop_node: Node = null
	if stop_associe != null and not stop_associe.is_empty():
		stop_node = get_node_or_null(stop_associe)
		print("[ActorTriggerMarker] %s : stop_associe='%s' -> stop_node=%s" % [name, stop_associe, stop_node])
	elif get_parent() is StopMarker:
		stop_node = get_parent()
		print("[ActorTriggerMarker] %s : stop_node = parent (StopMarker)" % name)

	if stop_node and stop_node.has_signal("stop_enclenche"):
		if not stop_node.stop_enclenche.is_connected(_on_stop_enclenche):
			stop_node.stop_enclenche.connect(_on_stop_enclenche)
			print("[ActorTriggerMarker] %s : Connecté au signal stop_enclenche de %s" % [name, stop_node.name])
		else:
			print("[ActorTriggerMarker] %s : Déjà connecté au signal stop_enclenche de %s" % [name, stop_node.name])
	else:
		print("[ActorTriggerMarker] %s : stop_node invalide ou pas de signal stop_enclenche" % name)

	# Écoute de secours sur la caméra si le stop_associe est atteint
	var cam := get_viewport().get_camera_2d() if get_viewport() else null
	if cam and cam.has_signal("camera_stop_atteint"):
		if not cam.camera_stop_atteint.is_connected(_on_camera_stop_atteint):
			cam.camera_stop_atteint.connect(_on_camera_stop_atteint)
			print("[ActorTriggerMarker] %s : Connecté au signal camera_stop_atteint" % name)

func _on_camera_stop_atteint(node_stop: Node2D, nom_stop: String) -> void:
	if _deja_declenche and declencher_une_seule_fois:
		return
	if stop_associe != null and not stop_associe.is_empty():
		var target = get_node_or_null(stop_associe)
		if target == node_stop or (target and target.name == nom_stop):
			declencher_action()
	elif get_parent() == node_stop or (get_parent() and get_parent().name == nom_stop):
		declencher_action()

func _physics_process(_delta: float) -> void:
	if _deja_declenche and declencher_une_seule_fois:
		return

	if mode_declenchement == "sur_stop_camera":
		return

	var acteur := _resoudre_acteur()
	if not is_instance_valid(acteur) or acteur.est_elimine or not acteur.is_inside_tree():
		return

	var current_x = acteur.global_position.x
	var target_x = global_position.x
	var rayon = max(rayon_declenchement_px, 16.0)

	# 1. Détection dans le rayon
	if abs(current_x - target_x) <= rayon:
		declencher_action()
		return

	# 2. Détection de franchissement (si l'acteur a sauté la coordonnée entre deux frames)
	if _derniere_pos_x_acteur > -900000.0:
		if (_derniere_pos_x_acteur < target_x and current_x >= target_x) or (_derniere_pos_x_acteur > target_x and current_x <= target_x):
			declencher_action()
			return

	_derniere_pos_x_acteur = current_x

func _on_stop_enclenche() -> void:
	print("[ActorTriggerMarker] %s : _on_stop_enclenche appelé (deja_declenche=%s, declencher_une_seule_fois=%s)" % [name, _deja_declenche, declencher_une_seule_fois])
	if _deja_declenche and declencher_une_seule_fois:
		return
	declencher_action()

## Déclenche l'action sur l'acteur cible
func declencher_action() -> void:
	if _deja_declenche and declencher_une_seule_fois:
		return

	var acteur := _resoudre_acteur()
	if not is_instance_valid(acteur):
		push_warning("[ActorTriggerMarker] %s : Impossible de trouver l'acteur cible." % name)
		return

	if declencher_une_seule_fois:
		_deja_declenche = true

	if delai_action_sec > 0.0:
		get_tree().create_timer(delai_action_sec, false).timeout.connect(func():
			if is_instance_valid(acteur):
				_appliquer_action(acteur)
		)
	else:
		_appliquer_action(acteur)

func _appliquer_action(acteur: ActorBase) -> void:
	print("[ActorTriggerMarker] %s exécute '%s' sur %s" % [name, action, acteur.name])
	match action:
		"quitter_et_liberer":
			if acteur.has_method("quitter_et_liberer"):
				acteur.quitter_et_liberer()
			else:
				acteur.set_physics_process(false)
				acteur.collision_layer = 0
				acteur.collision_mask = 0
				acteur.hide()
				acteur.queue_free()

		"arret_idle":
			if acteur.has_method("arret_idle"):
				acteur.arret_idle()
			else:
				acteur.vitesse_deplacement = 0.0
				if acteur.possede_animation("idle"):
					acteur.jouer_animation("idle")

		"pause_nette":
			if acteur.has_method("pause_nette"):
				acteur.pause_nette()
			else:
				acteur.vitesse_deplacement = 0.0
				if acteur.anim_sprite:
					acteur.anim_sprite.pause()
				if acteur.anim_player and acteur.anim_player.is_playing():
					acteur.anim_player.pause()

		"reprendre_marche":
			if acteur.has_method("reprendre_marche"):
				acteur.reprendre_marche()
			else:
				acteur.vitesse_deplacement = 40.0
				if acteur.possede_animation("walk"):
					acteur.jouer_animation("walk")

		"jouer_animation":
			if not nom_animation.is_empty() and acteur.possede_animation(nom_animation):
				acteur.jouer_animation(nom_animation)

		"subir_elimination":
			acteur.subir_elimination()

		_:
			pass
