class_name CameraStopDeclencheur
extends RefCounted

## Utilitaire partagé : connexion StopMarker / signaux caméra et filtrage du stop cible.
## Utilisé par ActorBase, AmmoCrate, PickupItem, Spawner2D, etc.

var _host: Node
var _declencheur_stop: NodePath
var _nom_stop_declencheur: String
var _mode_activation_stop: String
var _on_trigger: Callable
var _should_ignore_camera: Callable

var _marker_node: Node = null
var _camera: Camera2D = null


static func est_configure(declencheur_stop: NodePath, nom_stop_declencheur: String = "") -> bool:
	return (declencheur_stop != null and not declencheur_stop.is_empty()) or nom_stop_declencheur != ""


static func stop_correspond(
	host: Node,
	declencheur_stop: NodePath,
	nom_stop_declencheur: String,
	node_stop: Node2D,
	nom_stop: String
) -> bool:
	if nom_stop_declencheur != "" and (nom_stop == nom_stop_declencheur or (node_stop and node_stop.name == nom_stop_declencheur)):
		return true
	if declencheur_stop != null and not declencheur_stop.is_empty() and is_instance_valid(host):
		var target = host.get_node_or_null(declencheur_stop)
		if target == node_stop:
			return true
	if nom_stop_declencheur == "" and (declencheur_stop == null or declencheur_stop.is_empty()):
		return true
	return false


static func executer_avec_delai(host: Node, delai_sec: float, callback: Callable) -> void:
	if not is_instance_valid(host):
		return
	if delai_sec > 0.0:
		host.get_tree().create_timer(delai_sec, false).timeout.connect(func():
			if is_instance_valid(host) and callback.is_valid():
				callback.call()
		)
	elif callback.is_valid():
		callback.call()


func configure(
	host: Node,
	declencheur_stop: NodePath,
	nom_stop_declencheur: String,
	mode_activation_stop: String,
	on_trigger: Callable,
	should_ignore_camera: Callable = Callable()
) -> CameraStopDeclencheur:
	_host = host
	_declencheur_stop = declencheur_stop
	_nom_stop_declencheur = nom_stop_declencheur
	_mode_activation_stop = mode_activation_stop
	_on_trigger = on_trigger
	_should_ignore_camera = should_ignore_camera
	return self


func connect_signals() -> void:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	deconnecter()

	if _declencheur_stop != null and not _declencheur_stop.is_empty():
		_marker_node = _host.get_node_or_null(_declencheur_stop)
		if _marker_node and _marker_node.has_signal("stop_enclenche"):
			if not _marker_node.stop_enclenche.is_connected(_on_marker_stop_enclenche):
				_marker_node.stop_enclenche.connect(_on_marker_stop_enclenche)
			return

	var viewport = _host.get_viewport()
	if viewport == null:
		return
	_camera = viewport.get_camera_2d()
	if _camera == null:
		return

	if _mode_activation_stop == "activer_a_la_reprise":
		if _camera.has_signal("camera_stop_repris") and not _camera.camera_stop_repris.is_connected(_on_camera_stop_event):
			_camera.camera_stop_repris.connect(_on_camera_stop_event)
	else:
		if _camera.has_signal("camera_stop_atteint") and not _camera.camera_stop_atteint.is_connected(_on_camera_stop_event):
			_camera.camera_stop_atteint.connect(_on_camera_stop_event)


func deconnecter() -> void:
	if is_instance_valid(_marker_node) and _marker_node.has_signal("stop_enclenche"):
		if _marker_node.stop_enclenche.is_connected(_on_marker_stop_enclenche):
			_marker_node.stop_enclenche.disconnect(_on_marker_stop_enclenche)
	_marker_node = null

	if is_instance_valid(_camera):
		if _camera.has_signal("camera_stop_repris") and _camera.camera_stop_repris.is_connected(_on_camera_stop_event):
			_camera.camera_stop_repris.disconnect(_on_camera_stop_event)
		if _camera.has_signal("camera_stop_atteint") and _camera.camera_stop_atteint.is_connected(_on_camera_stop_event):
			_camera.camera_stop_atteint.disconnect(_on_camera_stop_event)
	_camera = null


func _on_marker_stop_enclenche() -> void:
	_fire_trigger()


func _on_camera_stop_event(node_stop: Node2D, nom_stop: String) -> void:
	if _should_ignore_camera.is_valid() and _should_ignore_camera.call():
		return
	if stop_correspond(_host, _declencheur_stop, _nom_stop_declencheur, node_stop, nom_stop):
		_fire_trigger()


func _fire_trigger() -> void:
	if _on_trigger.is_valid():
		_on_trigger.call()
