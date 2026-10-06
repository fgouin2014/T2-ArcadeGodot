class_name VehicleActorBase
extends ActorBase

## Classe de base pour les véhicules T2 (xjug, xsvan, xtruck, xcopter)
## Hérite de ActorBase pour le support complet de :
## - activation au démarrage / à l'entrée caméra
## - activation sur StopMarker (declencheur_stop / nom_stop_declencheur)
## - déverrouillage de stop à la mort (deverrouiller_stop_a_la_mort)
## - comportement dynamique sous déplacement vs arrêt

@export_group("Suivi Caméra & Patrouille")
@export var suivre_camera_automatiquement: bool = true ## Si false, le véhicule ne suit pas la caméra automatiquement (pour véhicules cinématiques)
@export var offset_lucarne_ratio_x: float = 0.35 ## Position cible relative dans la lucarne (0.35 = 35% de la largeur)
@export var patrouille_a_l_arret: bool = false   ## Si true (ex: xl1ghk), patrouille en va-et-vient quand la caméra s'arrête. Default = false pour véhicules terrestres.
@export var vitesse_patrouille: float = 40.0      ## Vitesse du va-et-vient quand la patrouille à l'arrêt est activée (px/s)
@export var distance_va_et_vient_px: float = 120.0 ## Amplitude du va-et-vient autour du centre (px)

var _pos_origine_x: float = 0.0
var _sens_marche: float = -1.0
var _derniere_camera_x: float = 0.0
var _camera_initialisee: bool = false

func _ready() -> void:
	super._ready()
	vitesse_deplacement = 0.0

func activer_acteur() -> void:
	super.activer_acteur()
	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera:
		_derniere_camera_x = camera.get_screen_center_position().x
		_pos_origine_x = _derniere_camera_x
		_camera_initialisee = true
	else:
		_pos_origine_x = global_position.x

func _physics_process(delta: float) -> void:
	if not est_actif():
		return

	# Si le suivi automatique est désactivé, ne pas ajuster la position
	if not suivre_camera_automatiquement:
		return

	var camera = get_viewport().get_camera_2d() if get_viewport() else null
	if camera == null:
		return

	var centre_cam_x = camera.get_screen_center_position().x
	var delta_cam_x = centre_cam_x - _derniere_camera_x
	_derniere_camera_x = centre_cam_x

	if not _camera_initialisee:
		_pos_origine_x = centre_cam_x
		_camera_initialisee = true

	# 1. CAMÉRA EN DÉPLACEMENT : Le véhicule ajuste sa vitesse pour suivre et se caler dans la lucarne
	if abs(delta_cam_x) > 0.05:
		var viewport_w = get_viewport_rect().size.x
		var target_x = centre_cam_x - (viewport_w * 0.5) + (viewport_w * offset_lucarne_ratio_x)
		global_position.x = move_toward(global_position.x, target_x, 300.0 * delta)
		_pos_origine_x = centre_cam_x
	else:
		# 2. CAMÉRA À L'ARRÊT : Patrouille UNIQUEMENT si l'option est cochée (default = false pour véhicules terrestres)
		if patrouille_a_l_arret and distance_va_et_vient_px > 0.0:
			global_position.x += _sens_marche * vitesse_patrouille * delta
			if global_position.x <= (_pos_origine_x - distance_va_et_vient_px):
				global_position.x = _pos_origine_x - distance_va_et_vient_px
				_sens_marche = 1.0
			elif global_position.x >= (_pos_origine_x + distance_va_et_vient_px):
				global_position.x = _pos_origine_x + distance_va_et_vient_px
				_sens_marche = -1.0

func subir_degats(degats_subis: int = 1) -> void:
	if not est_actif():
		return
	pv_actuels = max(0, pv_actuels - degats_subis)
	if pv_actuels <= 0:
		subir_elimination()

func subir_degats_partie(_partie: String, degats_subis: int = 1, _pos_impact: Vector2 = Vector2.INF, _est_missile: bool = false) -> void:
	subir_degats(degats_subis)
