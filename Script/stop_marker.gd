class_name StopMarker
extends Marker2D

signal stop_enclenche()

var _animation_deja_jouee : bool = false
var _deplacement_simple_en_cours : bool = false

## Mode d'alignement de la caméra lors de l'arrêt sur ce marqueur.
## 'Utiliser_Defaut_Camera' : utilise le choix configuré dans Camera2D.
@export_enum("Utiliser_Defaut_Camera", "Bord_Gauche", "Centre_Viseur", "Bord_Droit") var alignement : String = "Utiliser_Defaut_Camera"

## Durée de pause sur ce marqueur en secondes.
## Mettre une valeur négative (ex: -1.0) pour utiliser la durée par défaut configurée dans Camera2D.
@export var temps_pause : float = -1.0

## Si true, la caméra s'arrête indéfiniment jusqu'à un déverrouillage externe (ex: porte détruite).
## Le temps_pause ci-dessus sera alors décompté après le déverrouillage.
@export var locked : bool = false

## Si true, le marqueur ne s'activera qu'une seule fois : après son passage, il est définitivement ignoré (utile pour les boucles perpétuelles).
@export var stop_once : bool = true

## Si true, la caméra NE s'arrête PAS sur ce marqueur : elle continue de défiler sans pause.
## Les effets du stop (signal, motion_scale) sont quand même déclenchés au passage.
@export var continuer_sans_arret : bool = false

@export_group("Modification Motion Scale Sol")
## Si true, modifie la vitesse motion_scale d'un ParallaxLayer au passage de ce stop.
## La nouvelle vitesse est permanente — elle persiste après la reprise du défilement.
@export var modifier_motion_scale : bool = false
## Nom exact du nœud ParallaxLayer à modifier (ex: "Sol", "Sol_Fond").
@export var nom_parallax_layer : String = ""
## Nouvelle valeur de motion_scale appliquée au ParallaxLayer ciblé.
## Ex: Vector2(0.0, 1.0) pour immobiliser le sol, Vector2(0.5, 1.0) pour le ralentir.
@export var nouveau_motion_scale : Vector2 = Vector2(1.0, 1.0)
## Durée de la transition Tween vers la nouvelle vitesse (en secondes).
@export var duree_transition_sec : float = 0.5

@export_group("Modification Vitesse Camera")
## Si true, modifie la vitesse de scroll auto (vitesse_auto) de la caméra au passage de ce stop.
## La nouvelle vitesse est permanente.
@export var modifier_vitesse_camera : bool = false
## Nouvelle vitesse de défilement horizontal de la caméra (en pixels/sec). Ex: 75.0 ou 100.0.
@export var nouvelle_vitesse_camera : float = 50.0
## Durée de transition Tween vers la nouvelle vitesse de caméra (0.0 = instantané).
@export var duree_transition_camera_sec : float = 0.5

@export_group("Transition de Niveau")
## Si coché, atteindre ce marqueur Stop déclenche la fin du tableau et le passage au prochain niveau configuré dans DICO_NIVEAUX.
@export var changer_niveau : bool = false
## Délai d'attente avant d'enclencher la transition vers le niveau suivant (en secondes).
@export var delai_transition_sec : float = 0.5

@export_group("AnimationPlayer")
## Si true, déclenche une animation sur un AnimationPlayer quand le stop est enclenché.
@export var declencher_animation : bool = false
## Chemin vers le nœud AnimationPlayer dans la scène (ex: %BridgeAnimationPlayer).
@export var animation_player_path : NodePath = NodePath("")
## Nom de l'animation à jouer (ex: "bridge_open").
@export var nom_animation : String = ""
## Délai en secondes avant de lancer l'animation après l'arrêt (0.0 = immédiat).
@export var delai_animation_sec : float = 0.0

@export_group("Déplacement Simple (Alternative AnimationPlayer)")
## Si true, déplace un nœud statique (Sprite2D, Node2D, etc.) quand le stop est enclenché.
@export var deplacer_noeud_simple : bool = false
## Chemin vers le nœud à déplacer dans la scène (ex: "../../t2_xfback2/floor (PL)/floor/xfback_04").
@export var noeud_a_deplacer_path : NodePath = NodePath("")
## Décalage de position X en pixels (0.0 = pas de changement).
@export var decalage_x : float = 0.0
## Décalage de position Y en pixels (ex: 24.0 pour descendre de 24 pixels).
@export var decalage_y : float = 0.0
## Durée du déplacement en secondes.
@export var duree_deplacement_simple_sec : float = 3.0
## Délai avant le début du déplacement après le signal stop (en secondes).
@export var delai_deplacement_simple_sec : float = 0.0
## Type de transition (SINE, LINEAR, QUAD, CUBIC).
@export_enum("SINE", "LINEAR", "QUAD", "CUBIC") var type_transition : String = "SINE"

@export_group("Pluie Balistique (Ballistic Trigger)")
## Si true, pilote un BallisticTriggerMarker lors du déclenchement de ce stop.
@export var controler_pluie_balistique : bool = false
## Chemin vers le nœud BallisticTriggerMarker dans la scène.
@export var ballistic_marker_path : NodePath = NodePath("")
## Action balistique à effectuer au passage de ce stop.
@export_enum("demarrer", "arreter", "modifier_cadence", "demarrer_drop_special", "arreter_drop_special") var action_balistique : String = "demarrer"
## Nouvelle cadence entre les tirs en secondes si l'action 'modifier_cadence' est choisie.
@export var cadence_balistique_sec : float = 0.5

## Appelé lorsque la caméra atteint ce marqueur.
func enclencher_stop() -> void:
	print("[STOP MARKER] Arrêt caméra activé sur marqueur : ", name)
	stop_enclenche.emit()
	# Différer d'1 frame : le parallax est mis à jour APRÈS que la caméra soit figée,
	# ce qui évite un saut visuel brutal au moment exact de l'arrêt.
	call_deferred("_appliquer_motion_scale")
	call_deferred("_appliquer_vitesse_camera")
	if changer_niveau:
		_declencher_transition_niveau()
	if declencher_animation:
		call_deferred("_declencher_animation")
	if deplacer_noeud_simple:
		call_deferred("_deplacer_noeud_simple")
	if controler_pluie_balistique:
		call_deferred("_appliquer_action_balistique")

func _declencher_transition_niveau() -> void:
	if delai_transition_sec <= 0.0:
		GlobalSettings.declencher_changement_niveau()
	else:
		get_tree().create_timer(delai_transition_sec, false).timeout.connect(func():
			GlobalSettings.declencher_changement_niveau()
		)

func _declencher_animation() -> void:
	if not declencher_animation:
		return
	
	# Respecter stop_once : ne jouer l'animation qu'une seule fois
	if stop_once and _animation_deja_jouee:
		return
	
	if nom_animation.is_empty():
		push_warning("[STOP MARKER] %s : nom_animation est vide, impossible de déclencher l'animation." % name)
		return
	
	var player := get_node_or_null(animation_player_path) as AnimationPlayer
	if not is_instance_valid(player):
		push_warning("[STOP MARKER] %s : AnimationPlayer introuvable via le chemin '%s'." % [name, animation_player_path])
		return
	
	if not player.has_animation(nom_animation):
		push_warning("[STOP MARKER] %s : L'animation '%s' n'existe pas dans %s." % [name, nom_animation, player.name])
		return
	
	if stop_once:
		_animation_deja_jouee = true
	
	if delai_animation_sec > 0.0:
		get_tree().create_timer(delai_animation_sec, false).timeout.connect(func():
			_jouer_animation(player)
		)
	else:
		_jouer_animation(player)

func _jouer_animation(player: AnimationPlayer) -> void:
	print("[STOP MARKER] %s lance l'animation '%s' sur %s" % [name, nom_animation, player.name])
	player.play(nom_animation)

## Modifie la vitesse de scroll auto de la caméra avec ou sans transition Tween.
func _appliquer_vitesse_camera() -> void:
	if not modifier_vitesse_camera:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		var scene := get_tree().current_scene
		if scene:
			cam = scene.find_child("*Camera*", true, false) as Camera2D
	if cam:
		if cam.has_method("changer_vitesse_auto"):
			cam.changer_vitesse_auto(nouvelle_vitesse_camera, duree_transition_camera_sec)
		elif "vitesse_auto" in cam:
			cam.vitesse_auto = nouvelle_vitesse_camera
			print("[STOP MARKER] vitesse_auto de la caméra changée directement à : ", nouvelle_vitesse_camera)
	else:
		push_warning("[STOP MARKER] Caméra introuvable pour modifier la vitesse_auto.")


## Modifie en douceur le motion_scale du ParallaxLayer ciblé via un Tween.
## Compense motion_offset pour éviter tout saut visuel : le décor reste en place
## et commence à défiler à la nouvelle vitesse à partir de sa position actuelle.
func _appliquer_motion_scale() -> void:
	if not modifier_motion_scale or nom_parallax_layer.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var calque := scene.find_child(nom_parallax_layer, true, false)
	if calque == null:
		push_warning("[STOP MARKER] ParallaxLayer '%s' introuvable dans la scène." % nom_parallax_layer)
		return
	if not (calque is ParallaxLayer):
		push_warning("[STOP MARKER] Le nœud '%s' n'est pas un ParallaxLayer." % nom_parallax_layer)
		return
	var layer := calque as ParallaxLayer
	var ancienne_scale := layer.motion_scale

	# Compensation d'offset : évite le saut visuel lors du changement de motion_scale.
	# Formule : new_offset = old_offset + scroll * (old_scale - new_scale)
	# Le décor reste au même endroit mais défile désormais à la nouvelle vitesse.
	var scroll := Vector2.ZERO
	var parallax_bg := layer.get_parent() as ParallaxBackground
	if parallax_bg:
		scroll = parallax_bg.scroll_offset
	else:
		var cam := get_viewport().get_camera_2d()
		if cam:
			scroll = cam.global_position
	var offset_compense := layer.motion_offset + scroll * (ancienne_scale - nouveau_motion_scale)

	print("[STOP MARKER] Transition motion_scale '%s' : %s → %s (%.2fs)" % [nom_parallax_layer, ancienne_scale, nouveau_motion_scale, duree_transition_sec])
	if duree_transition_sec > 0.0:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.set_parallel(true)
		tw.tween_property(layer, "motion_scale", nouveau_motion_scale, duree_transition_sec)
		tw.tween_property(layer, "motion_offset", offset_compense, duree_transition_sec)
	else:
		layer.motion_scale = nouveau_motion_scale
		layer.motion_offset = offset_compense

func _deplacer_noeud_simple() -> void:
	if not deplacer_noeud_simple:
		return
	
	# Respecter stop_once : ne déplacer qu'une seule fois
	if stop_once and _deplacement_simple_en_cours:
		return
	
	if noeud_a_deplacer_path == null or noeud_a_deplacer_path.is_empty():
		push_warning("[STOP MARKER] %s : noeud_a_deplacer_path est vide, impossible de déplacer le nœud." % name)
		return
	
	var noeud := get_node_or_null(noeud_a_deplacer_path)
	if not is_instance_valid(noeud):
		push_warning("[STOP MARKER] %s : Nœud introuvable via le chemin '%s'." % [name, noeud_a_deplacer_path])
		return
	
	if stop_once:
		_deplacement_simple_en_cours = true
	
	if delai_deplacement_simple_sec > 0.0:
		get_tree().create_timer(delai_deplacement_simple_sec, false).timeout.connect(func():
			_executer_deplacement_simple(noeud)
		)
	else:
		_executer_deplacement_simple(noeud)

func _executer_deplacement_simple(noeud: Node) -> void:
	var position_depart = noeud.position
	var position_finale = Vector2(position_depart.x + decalage_x, position_depart.y + decalage_y)
	
	print("[STOP MARKER] %s déplace %s de %s vers %s (%.2fs)" % [name, noeud.name, position_depart, position_finale, duree_deplacement_simple_sec])
	
	# Déterminer le type de transition
	var trans_type = Tween.TRANS_SINE
	match type_transition:
		"LINEAR":
			trans_type = Tween.TRANS_LINEAR
		"QUAD":
			trans_type = Tween.TRANS_QUAD
		"CUBIC":
			trans_type = Tween.TRANS_CUBIC
	
	if duree_deplacement_simple_sec > 0.0:
		var tw := create_tween()
		tw.set_trans(trans_type)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.set_parallel(true)
		tw.tween_property(noeud, "position:x", position_finale.x, duree_deplacement_simple_sec)
		tw.tween_property(noeud, "position:y", position_finale.y, duree_deplacement_simple_sec)
	else:
		noeud.position = position_finale

func _appliquer_action_balistique() -> void:
	if not controler_pluie_balistique:
		return
	
	var ballistic_node: Node = null
	if ballistic_marker_path != null and not ballistic_marker_path.is_empty():
		ballistic_node = get_node_or_null(ballistic_marker_path)
	
	if ballistic_node == null:
		var scene = get_tree().current_scene if get_tree() else null
		if scene:
			ballistic_node = scene.find_child("BallisticTriggerMarker*", true, false)
	
	if ballistic_node == null:
		push_warning("[STOP MARKER] %s : BallisticTriggerMarker introuvable pour action '%s'." % [name, action_balistique])
		return
	
	print("[STOP MARKER] %s applique l'action balistique '%s' sur %s" % [name, action_balistique, ballistic_node.name])
	match action_balistique:
		"demarrer":
			if ballistic_node.has_method("demarrer_pluie"):
				ballistic_node.demarrer_pluie()
		"arreter":
			if ballistic_node.has_method("arreter_pluie"):
				ballistic_node.arreter_pluie()
		"modifier_cadence":
			if ballistic_node.has_method("modifier_cadence"):
				ballistic_node.modifier_cadence(cadence_balistique_sec)
		"demarrer_drop_special":
			if ballistic_node.has_method("demarrer_drop_special"):
				ballistic_node.demarrer_drop_special()
		"arreter_drop_special":
			if ballistic_node.has_method("arreter_drop_special"):
				ballistic_node.arreter_drop_special()
