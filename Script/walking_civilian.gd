class_name WalkingCivilian
extends ActorBase

## Script complet pour civils et alliés (Young John Connor & Sarah Connor).

signal destination_atteinte(pos: Vector2)

@export_enum("marche_et_take_au_marqueur", "marche_libre", "scan_cinematique") var comportement_civil: String = "marche_et_take_au_marqueur"

@export_enum(
	"aucun",
	"xpickup_29", "xpickup_17", "xpickup_18", "xpickup_21",
	"xpickup_12", "xpickup_14", "xpickup_16", "xpickup_07",
	"xpickup_09", "xpickup_11", "xpickup_01", "xpickup_03",
	"xpickup_05", "xpickup_24"
) var objet_a_dropper: String = "xpickup_29"

@export var drop_aleatoire: bool = false       # true = xyjc (drop aléatoire en marchant), false = xsarah (drop au Marker2D Take)
@export var probabilite_drop: float = 0.25    # Probabilité par cycle de marche (ex: 25%)
@export var temps_entre_cycles: float = 5.0   # Secondes entre chaque vérification de drop aléatoire

@export_group("Déplacement Manuel (Alternative AnimationPlayer)")
## Si true, active le déplacement manuel via Tween au lieu d'AnimationPlayer (utile pour Android)
@export var deplacement_manuel_actif: bool = false
## StopMarker qui déclenche le déplacement manuel
@export var stop_declencheur_deplacement: NodePath = NodePath("")
## Destination du déplacement (position X et Y)
@export var destination_deplacement: Vector2 = Vector2(2725, 103)
## Durée du déplacement en secondes
@export var duree_deplacement_sec: float = 5.0
## Délai avant le début du déplacement après le signal stop (en secondes)
@export var delai_deplacement_sec: float = 0.2
## Si true, inverse le sprite horizontalement pendant le déplacement
@export var inverser_pendant_deplacement: bool = true
## Moment de l'inversion du sprite en secondes (0.0 = début, 5.0 = fin pour durée 5s)
@export var moment_inversion_sec: float = 4.5

# --- ÉTAT INTERNE ---
var _marqueur_take: Marker2D = null
var _a_fait_take: bool = false
var _en_sequence_action: bool = false
var _est_en_arret_force: bool = false
var _vitesse_sauvegardee: float = 40.0
var _deplacement_en_cours: bool = false
var _stop_declencheur_connecte: bool = false
var _inversion_manuelle_active: bool = false  # Pour forcer flip_h pendant le déplacement manuel sans toucher inverser_visuel

func _ready() -> void:
	super._ready()
	if vitesse_deplacement <= 0.0:
		vitesse_deplacement = 40.0
	_vitesse_sauvegardee = vitesse_deplacement
	
	# Connecter au StopMarker pour le déplacement manuel
	if deplacement_manuel_actif and not Engine.is_editor_hint():
		call_deferred("_connecter_stop_deplacement")

func activer_acteur() -> void:
	super.activer_acteur()
	_vitesse_sauvegardee = vitesse_deplacement if vitesse_deplacement > 0.0 else 40.0
	
	call_deferred("_rechercher_marqueur_take")
	
	match comportement_civil:
		"scan_cinematique":
			_arreter_marche()
			if possede_animation("scan"):
				jouer_animation("scan")
			elif possede_animation("idle"):
				jouer_animation("idle")
		_:
			_demarrer_marche()
			_boucle_comportement_civil()

func _rechercher_marqueur_take() -> void:
	var root = get_parent()
	if root == null:
		return
	var marqueurs = root.find_children("*Take*", "Marker2D", true, false)
	if marqueurs.size() > 0:
		_marqueur_take = marqueurs[0] as Marker2D
		print("[CIVIL] Marker2D 'Take' détecté à X=", _marqueur_take.global_position.x)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Appliquer l'inversion manuelle pendant le déplacement manuel
	if _deplacement_en_cours and _inversion_manuelle_active and anim_sprite:
		anim_sprite.flip_h = false  # xyjc regarde vers la gauche quand flip_h = false
	
	# Détection dynamique du Marker2D "Take" pendant la marche
	if deja_active and not est_elimine and not _en_sequence_action and _marqueur_take and not _a_fait_take:
		if abs(global_position.x - _marqueur_take.global_position.x) < 16.0:
			_jouer_sequence_take()

func _boucle_comportement_civil() -> void:
	while deja_active and not est_elimine:
		await attendre(temps_entre_cycles)
		if not est_actif() or _en_sequence_action:
			continue

		# Drop aléatoire pendant la marche (Young John Connor)
		if drop_aleatoire and objet_a_dropper != "aucun":
			if randf() < probabilite_drop:
				await _jouer_sequence_drop_aleatoire()

func _jouer_sequence_take() -> void:
	_a_fait_take = true
	_en_sequence_action = true
	_arreter_marche()

	if possede_animation("take"):
		jouer_animation("take")
		await _attendre_fin_animation(1.2)
	elif possede_animation("crouch"):
		jouer_animation("crouch")
		await attendre(1.0)

	# Déposer l'objet au pied du civil si configuré
	if objet_a_dropper != "aucun":
		if possede_animation("drop"):
			jouer_animation("drop")
			await _attendre_fin_animation(0.8)
		_dropper_pickup()

	_en_sequence_action = false
	_demarrer_marche()

func _jouer_sequence_drop_aleatoire() -> void:
	_en_sequence_action = true
	_arreter_marche()

	if possede_animation("drop"):
		jouer_animation("drop")
		await _attendre_fin_animation(0.8)
	
	_dropper_pickup()
	
	_en_sequence_action = false
	_demarrer_marche()

func _demarrer_marche() -> void:
	vitesse_deplacement = _vitesse_sauvegardee if _vitesse_sauvegardee > 0.0 else 40.0
	if possede_animation("walk"):
		jouer_animation("walk")

func _arreter_marche() -> void:
	vitesse_deplacement = 0.0

func arret_idle() -> void:
	_est_en_arret_force = true
	_en_sequence_action = true
	_arreter_marche()
	velocity = Vector2.ZERO
	if possede_animation("idle"):
		jouer_animation("idle")
	elif possede_animation("idle_stand"):
		jouer_animation("idle_stand")

func pause_nette() -> void:
	_est_en_arret_force = true
	_en_sequence_action = true
	_arreter_marche()
	velocity = Vector2.ZERO
	if anim_sprite:
		anim_sprite.pause()
	if anim_player and anim_player.is_playing():
		anim_player.pause()

func reprendre_marche() -> void:
	_est_en_arret_force = false
	_en_sequence_action = false
	if anim_sprite and not anim_sprite.is_playing():
		anim_sprite.play()
	if anim_player and anim_player.is_playing() == false and anim_player.current_animation != "":
		anim_player.play()
	_demarrer_marche()


func _dropper_pickup() -> void:
	if objet_a_dropper == "aucun":
		return
	var path_pickup = "res://images/items/" + objet_a_dropper + ".png"
	if not ResourceLoader.exists(path_pickup):
		path_pickup = "res://tsj/" + objet_a_dropper + ".png"
		if not ResourceLoader.exists(path_pickup):
			print("[CIVIL DROP] Texture introuvable : ", path_pickup)
			return

	var noeud_pickup = Node2D.new()
	noeud_pickup.name = "Pickup_" + objet_a_dropper

	var spr = Sprite2D.new()
	spr.texture = load(path_pickup)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	noeud_pickup.add_child(spr)

	var area = Area2D.new()
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	col.shape = shape
	area.add_child(col)
	noeud_pickup.add_child(area)

	var script_pickup = GDScript.new()
	script_pickup.source_code = """extends Node2D
var nom_pickup: String = \"%s\"
func subir_degats(_d: int = 1) -> void:
	if nom_pickup == \"xpickup_14\":
		GlobalSettings.ajouter_missiles(1)
	print(\"[PICKUP] Ramassé : \", nom_pickup)
	queue_free()
""" % objet_a_dropper
	noeud_pickup.set_script(script_pickup)

	noeud_pickup.global_position = global_position + Vector2(0, 20.0)
	get_parent().add_child(noeud_pickup)
	print("[CIVIL DROP] ", name, " a déposé : ", objet_a_dropper)

func _attendre_fin_animation(duree_fallback: float) -> void:
	if anim_sprite and anim_sprite.sprite_frames:
		var current_anim = anim_sprite.animation
		if anim_sprite.sprite_frames.has_animation(current_anim):
			if not anim_sprite.sprite_frames.get_animation_loop(current_anim):
				await anim_sprite.animation_finished
				return
	await attendre(duree_fallback)

func _connecter_stop_deplacement() -> void:
	if _stop_declencheur_connecte:
		return
	
	if stop_declencheur_deplacement == null or stop_declencheur_deplacement.is_empty():
		push_warning("[CIVIL] %s: stop_declencheur_deplacement est vide, impossible de connecter le déplacement manuel." % name)
		return
	
	var stop_node = get_node_or_null(stop_declencheur_deplacement)
	if stop_node == null:
		push_warning("[CIVIL] %s: StopMarker introuvable via le chemin '%s'." % [name, stop_declencheur_deplacement])
		return
	
	if stop_node.has_signal("stop_enclenche"):
		stop_node.stop_enclenche.connect(_on_stop_deplacement_declenche)
		_stop_declencheur_connecte = true
		print("[CIVIL] %s: Connecté au StopMarker '%s' pour le déplacement manuel." % [name, stop_node.name])
	else:
		push_warning("[CIVIL] %s: Le nœud '%s' n'a pas le signal stop_enclenche." % [name, stop_node.name])

func _on_stop_deplacement_declenche() -> void:
	if not deplacement_manuel_actif:
		return
	
	print("[CIVIL] %s: Stop déclenché, début du déplacement manuel dans %.2fs" % [name, delai_deplacement_sec])
	
	if delai_deplacement_sec > 0.0:
		await attendre(delai_deplacement_sec)
	
	# Attendre que l'acteur soit activé avant de commencer le déplacement
	while not deja_active:
		await attendre(0.1)
	
	print("[CIVIL] %s: Acteur activé, début du déplacement manuel" % name)
	_deplacer_manuellement()

func _deplacer_manuellement() -> void:
	if _deplacement_en_cours:
		return
	
	_deplacement_en_cours = true
	_en_sequence_action = true
	_arreter_marche()
	velocity = Vector2.ZERO
	
	var position_depart = global_position
	var position_finale = destination_deplacement
	# Si la destination_deplacement est locale au parent (ex: sous-scène instanciée), la convertir en global
	if get_parent() and (destination_deplacement.x < (global_position.x - 500.0) or destination_deplacement.x < 1000.0):
		position_finale = get_parent().to_global(destination_deplacement)
	
	print("[CIVIL] %s: Déplacement manuel de %s vers %s (%.2fs)" % [name, position_depart, position_finale, duree_deplacement_sec])
	
	# Animation de déplacement (walk ou idle)
	if possede_animation("walk"):
		jouer_animation("walk")
	elif possede_animation("idle"):
		jouer_animation("idle")
	
	# Inversion du sprite au moment spécifié - timer commence MAINTENANT
	if inverser_pendant_deplacement and moment_inversion_sec > 0.0:
		var timer = get_tree().create_timer(moment_inversion_sec, false)
		timer.timeout.connect(func():
			print("[CIVIL] %s: Timer d'inversion déclenché après %.2fs (deplacement_en_cours=%s)" % [name, moment_inversion_sec, _deplacement_en_cours])
			if _deplacement_en_cours:
				_inverser_sprite()
			else:
				print("[CIVIL] %s: Timer déclenché mais déplacement déjà terminé" % name)
		)
		print("[CIVIL] %s: Timer d'inversion programmé pour %.2fs" % [name, moment_inversion_sec])
	
	# Tween pour le déplacement
	var tw := create_tween()
	tw.set_parallel(false)  # Séquentiel pour s'assurer que tout s'arrête ensemble
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	
	# Déplacement X et Y en parallèle
	var tw_pos := create_tween()
	tw_pos.set_parallel(true)
	tw_pos.tween_property(self, "global_position:x", position_finale.x, duree_deplacement_sec)
	tw_pos.tween_property(self, "global_position:y", position_finale.y, duree_deplacement_sec)
	
	# Attendre la fin du déplacement
	await tw_pos.finished
	
	# Arrêt complet
	_deplacement_en_cours = false
	_inversion_manuelle_active = false  # Désactiver l'inversion manuelle
	_en_sequence_action = false
	velocity = Vector2.ZERO
	vitesse_deplacement = 0.0
	
	# Forcer la position exacte
	global_position = position_finale
	
	print("[CIVIL] %s: Déplacement manuel terminé à %s" % [name, global_position])
	destination_atteinte.emit(global_position)
	
	# Jouer l'animation idle à la fin
	if possede_animation("idle"):
		jouer_animation("idle")

func _inverser_sprite() -> void:
	# Activer l'inversion manuelle pour faire regarder xyjc vers la gauche
	_inversion_manuelle_active = true
	print("[CIVIL] %s: Inversion manuelle activée (xyjc regarde vers gauche)" % name)
	
	# Forcer immédiatement
	if anim_sprite:
		anim_sprite.flip_h = false  # xyjc regarde vers la gauche quand flip_h = false
		print("[CIVIL] %s: anim_sprite.flip_h forcé à false" % name)
