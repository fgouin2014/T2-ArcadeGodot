class_name PodsManager
extends Node2D

signal toutes_les_portes_detruites()

## Nom du StopMarker à déverrouiller lorsque toutes les portes sont détruites
@export var nom_stop_camera: String = "StopMarker1"

## Délai entre deux tentatives d'ouverture par étage
@export var intervalle_tentative_ouverture_sec: float = 3.0

var portes_haut: Array[PodHatch] = []
var portes_bas: Array[PodHatch] = []
var total_portes_initiales: int = 10
var total_portes_restantes: int = 10
var tout_detruit: bool = false
var actif: bool = false

# Verrous d'exclusivité par étage : 1 seule porte ouverte à la fois par étage
var porte_ouverte_haut: PodHatch = null
var porte_ouverte_bas: PodHatch = null

func _ready() -> void:
	call_deferred("_initialiser_portes")
	call_deferred("_connecter_stop_camera")

func _initialiser_portes() -> void:
	portes_haut.clear()
	portes_bas.clear()
	
	var liste = find_children("*", "PodHatch", true, false)
	for item in liste:
		if item is PodHatch:
			item.gestionnaire_pods = self
			if item.type_porte == PodHatch.TypePorte.HAUT_A:
				portes_haut.append(item)
			else:
				portes_bas.append(item)
				
			if not item.porte_detruite.is_connected(_sur_porte_detruite):
				item.porte_detruite.connect(_sur_porte_detruite)
			if not item.porte_fermee.is_connected(_sur_porte_fermee):
				item.porte_fermee.connect(_sur_porte_fermee)
				
	total_portes_initiales = portes_haut.size() + portes_bas.size()
	total_portes_restantes = total_portes_initiales
	print("[PODS MANAGER] %d portes détectées (%d haut, %d bas). En attente du Stop caméra..." % [total_portes_initiales, portes_haut.size(), portes_bas.size()])

func _connecter_stop_camera() -> void:
	# 1. Écoute directe du StopMarker ciblé s'il existe dans la scène
	var root_target = get_tree().current_scene if get_tree().current_scene else get_parent()
	if root_target:
		var marqueurs = root_target.find_children("*Stop*", "Marker2D", true, false)
		for m in marqueurs:
			if m is Marker2D and (nom_stop_camera == "" or m.name == nom_stop_camera):
				if m.has_signal("stop_enclenche"):
					if not m.stop_enclenche.is_connected(activer_pods):
						m.stop_enclenche.connect(activer_pods)
						print("[PODS MANAGER] Connecté directement au StopMarker : ", m.name)

	# 2. Écoute de la caméra via le signal universel camera_stop_atteint
	var camera = get_tree().root.find_child("Camera2D", true, false)
	if camera and camera.has_signal("camera_stop_atteint"):
		if not camera.camera_stop_atteint.is_connected(_on_camera_stop_atteint):
			camera.camera_stop_atteint.connect(_on_camera_stop_atteint)

func _on_camera_stop_atteint(node_stop: Node2D, nom_stop: String) -> void:
	if actif:
		return
	if nom_stop_camera == "" or nom_stop == nom_stop_camera or (node_stop and node_stop.name == nom_stop_camera):
		print("[PODS MANAGER] Stop caméra atteint ('%s') -> DÉMARRAGE DU CYCLE DES PODS !" % nom_stop)
		activer_pods()

func activer_pods() -> void:
	if actif or tout_detruit:
		return
	actif = true
	_boucle_scheduler_haut()
	_boucle_scheduler_bas()

func _boucle_scheduler_haut() -> void:
	if not actif or tout_detruit:
		return
		
	# Vérifie si aucune porte haute n'est déjà ouverte
	if porte_ouverte_haut == null or not is_instance_valid(porte_ouverte_haut) or porte_ouverte_haut.etat_actuel == PodHatch.EtatPorte.FERME:
		porte_ouverte_haut = null
		# Filtrer les portes hautes éligibles (vivantes, fermées, sans ennemi vivant)
		var candidates: Array[PodHatch] = []
		for p in portes_haut:
			if is_instance_valid(p) and p.peut_s_ouvrir():
				candidates.append(p)
				
		if candidates.size() > 0:
			candidates.shuffle()
			var porte_choisie = candidates[0]
			if porte_choisie.tenter_ouverture():
				porte_ouverte_haut = porte_choisie
				print("[PODS MANAGER] Étage HAUT -> Ouverture exclusive de : ", porte_choisie.name)
				
	var prochain_delai = randf_range(intervalle_tentative_ouverture_sec, intervalle_tentative_ouverture_sec + 2.0)
	get_tree().create_timer(prochain_delai, false).timeout.connect(_boucle_scheduler_haut)

func _boucle_scheduler_bas() -> void:
	if not actif or tout_detruit:
		return
		
	# Vérifie si aucune porte basse n'est déjà ouverte
	if porte_ouverte_bas == null or not is_instance_valid(porte_ouverte_bas) or porte_ouverte_bas.etat_actuel == PodHatch.EtatPorte.FERME:
		porte_ouverte_bas = null
		# Filtrer les portes basses éligibles
		var candidates: Array[PodHatch] = []
		for p in portes_bas:
			if is_instance_valid(p) and p.peut_s_ouvrir():
				candidates.append(p)
				
		if candidates.size() > 0:
			candidates.shuffle()
			var porte_choisie = candidates[0]
			if porte_choisie.tenter_ouverture():
				porte_ouverte_bas = porte_choisie
				print("[PODS MANAGER] Étage BAS -> Ouverture exclusive de : ", porte_choisie.name)
				
	var prochain_delai = randf_range(intervalle_tentative_ouverture_sec, intervalle_tentative_ouverture_sec + 2.0)
	get_tree().create_timer(prochain_delai, false).timeout.connect(_boucle_scheduler_bas)

func _sur_porte_fermee(porte: PodHatch) -> void:
	if porte == porte_ouverte_haut:
		porte_ouverte_haut = null
	elif porte == porte_ouverte_bas:
		porte_ouverte_bas = null

var ennemis_vivants: Array[Node2D] = []

func enregistrer_ennemi_spawn(ennemi: Node2D) -> void:
	if ennemi and not ennemis_vivants.has(ennemi):
		ennemis_vivants.append(ennemi)
		if ennemi.has_signal("tree_exited"):
			ennemi.tree_exited.connect(func(): _sur_ennemi_elimine(ennemi))

func _sur_ennemi_elimine(ennemi: Node2D) -> void:
	ennemis_vivants.erase(ennemi)
	_verifier_deverrouillage_total()

func _sur_porte_detruite(porte: PodHatch) -> void:
	if tout_detruit:
		return
		
	if porte == porte_ouverte_haut:
		porte_ouverte_haut = null
	elif porte == porte_ouverte_bas:
		porte_ouverte_bas = null
		
	total_portes_restantes = max(0, total_portes_restantes - 1)
	print("[PODS MANAGER] Porte détruite (%s). Restantes : %d/%d" % [porte.name, total_portes_restantes, total_portes_initiales])
	
	if total_portes_restantes == 0:
		actif = false
		_verifier_deverrouillage_total()

func _verifier_deverrouillage_total() -> void:
	if total_portes_restantes == 0 and not tout_detruit:
		# Nettoyer les références d'ennemis invalides
		ennemis_vivants = ennemis_vivants.filter(func(e): return is_instance_valid(e) and ("est_elimine" not in e or not e.est_elimine))
		if ennemis_vivants.is_empty():
			tout_detruit = true
			toutes_les_portes_detruites.emit()
			_deverrouiller_camera()
		else:
			print("[PODS MANAGER] Portes détruites mais il reste %d ennemis à éliminer avant de déverrouiller !" % ennemis_vivants.size())

func _deverrouiller_camera() -> void:
	print("[PODS MANAGER] TOUTES LES PORTES ET ACTEURS SONT ÉLIMINÉS ! Déverrouillage de la caméra.")
	var camera: Camera2D = null
	for cam in get_tree().get_nodes_in_group("cameras"):
		if cam is Camera2D and (cam.has_method("deverrouiller_stop") or cam.has_method("reprendre_scroll_force")):
			camera = cam
			break
	if camera == null:
		var found = get_tree().root.find_child("Camera2D", true, false)
		if found is Camera2D:
			camera = found

	if camera:
		if camera.has_method("deverrouiller_stop"):
			camera.deverrouiller_stop(nom_stop_camera)
			print("[PODS MANAGER] Caméra : deverrouiller_stop('%s') appelé." % nom_stop_camera)
		elif camera.has_method("reprendre_scroll_force"):
			camera.reprendre_scroll_force()
			print("[PODS MANAGER] Caméra : reprendre_scroll_force() appelé.")
