class_name GaugeLifeT100
extends Node2D

@onready var gauge_rect: ColorRect = $Sprite2D2/GaugeLifeT100

# Variables exportables pour l'inspecteur
@export_group("Configuration Drainage")
## Vitesse de drainage (en % par seconde) quand xt100 est en contact
@export var vitesse_drainage: float = 4.0
## Vitesse de recharge (en % par seconde) quand xt100 n'est pas en contact
@export var vitesse_recharge: float = 1.5
## % de gauge perdu par tir principal (équivalent de degats_tir_principal)
@export var degats_gauge_par_tir_principale: float = 2.5
## % de gauge perdu par tir alternatif (équivalent de degats_tir_alternatif)
@export var degats_gauge_par_tir_secondaire: float = 12.0

@export_group("Gestion Contact Multi-Flaques")
## Si coché, multiplie les dégâts de drainage et de tirs par le nombre de flaques touchées en même temps
@export var multiplier_par_nombre_pools: bool = true
## Multiplicateur d'impact par flaque supplémentaire (1.0 = multiplication directe par le compte, 0.5 = 50% de bonus par flaque supplémentaire)
@export var facteur_par_flaque_supplementaire: float = 1.0
## Nombre maximum de flaques prises en compte simultanément (0 = sans limite)
@export var max_pools_simultanees: int = 0

@export_group("Déclencheur sur Arrêt Caméra")
## Sélecteur visuel de StopMarker dans l'Inspecteur Godot
@export var declencheur_stop: NodePath
## Nom ou identifiant optionnel du StopMarker (ex: "Stop1stFight")
@export var nom_stop_declencheur: String = ""
## Mode d'activation: activer_quand_atteint = dès l'arrêt, activer_a_la_reprise = à la reprise
@export_enum("activer_quand_atteint", "activer_a_la_reprise") var mode_activation_stop: String = "activer_quand_atteint"

# Variables internes
var valeur_actuelle: float = 100.0  # De 100% (pleine) à 0% (vide)
var est_en_contact: bool = false
var fluid_pool_running: bool = false
var xt100_ref: Node2D = null
var stop_marker_ref: StopMarker = null
var visible_par_stop: bool = false
var est_active: bool = false

# Signaux
signal gauge_vide()
signal valeur_changee(nouvelle_valeur: float)

func _ready() -> void:
	# Rendre la gauge invisible et inactive au démarrage
	visible = false
	visible_par_stop = false
	est_active = false
	
	# Initialiser la valeur à 100% (pleine)
	valeur_actuelle = 100.0
	
	# Connecter au StopMarker si configuré
	var a_declencheur = (declencheur_stop != null and not declencheur_stop.is_empty()) or nom_stop_declencheur != ""
	if a_declencheur:
		call_deferred("_connecter_declencheur_stop")

func _connecter_declencheur_stop() -> void:
	stop_marker_ref = get_node_or_null(declencheur_stop) as StopMarker
	if stop_marker_ref == null and get_parent():
		stop_marker_ref = get_parent().get_node_or_null(declencheur_stop) as StopMarker
	if stop_marker_ref == null and not nom_stop_declencheur.is_empty():
		var scene = get_tree().current_scene
		if scene:
			stop_marker_ref = scene.find_child(nom_stop_declencheur, true, false) as StopMarker
	if stop_marker_ref == null:
		# Fallback : chercher dans la scène racine ou le boss
		var root = get_tree().current_scene if get_tree() else null
		if root:
			stop_marker_ref = root.find_child("Stop1stFight", true, false) as StopMarker

	if stop_marker_ref:
		if mode_activation_stop == "activer_quand_atteint":
			if not stop_marker_ref.stop_enclenche.is_connected(_on_stop_atteint):
				stop_marker_ref.stop_enclenche.connect(_on_stop_atteint)
		print("[GAUGE] Connectée au StopMarker: ", stop_marker_ref.name)
	else:
		push_warning("[GAUGE] StopMarker introuvable: ", declencheur_stop, " ou nom: ", nom_stop_declencheur)

func _on_stop_atteint() -> void:
	visible = true
	visible_par_stop = true
	est_active = true
	valeur_actuelle = 100.0  # Remettre à 100% (pleine)
	mettre_a_jour_affichage()
	print("[GAUGE] Gauge active et visible sur arrêt caméra: ", stop_marker_ref.name if stop_marker_ref else "inconnu")

func desactiver_et_cacher() -> void:
	est_active = false
	visible = false
	visible_par_stop = false
	print("[GAUGE] Gauge désactivée et cachée")

var nombre_pools_contact: int = 0

func _calculer_multiplicateur_pools() -> float:
	if not multiplier_par_nombre_pools or nombre_pools_contact <= 1:
		return 1.0
	var count = nombre_pools_contact
	if max_pools_simultanees > 0:
		count = mini(count, max_pools_simultanees)
	# 1 pool = 1.0, chaque pool supplémentaire ajoute facteur_par_flaque_supplementaire
	return 1.0 + float(count - 1) * facteur_par_flaque_supplementaire

func _process(delta: float) -> void:
	# Ne traiter que si la gauge est active et visible
	if not est_active or not visible or not visible_par_stop:
		return
	
	# Le drainage continu s'opère tant que xt100 est en contact avec au moins une flaque au sol
	# Les dommages de base sont multipliés selon la configuration multi-pools
	if est_en_contact and nombre_pools_contact > 0:
		var mult := _calculer_multiplicateur_pools()
		var changement = vitesse_drainage * mult * delta
		valeur_actuelle = max(0.0, valeur_actuelle - changement)
	else:
		# Recharge: de 0% vers 100%
		var changement = vitesse_recharge * delta
		valeur_actuelle = min(100.0, valeur_actuelle + changement)
	
	mettre_a_jour_affichage()
	
	# Vérifier si la gauge est vide (0%)
	if valeur_actuelle <= 0.0:
		est_active = false  # Désactiver le drainage
		gauge_vide.emit()

func _on_contact_change(en_contact: bool, nb_pools: int = 1) -> void:
	est_en_contact = en_contact
	nombre_pools_contact = nb_pools if en_contact else 0
	print("[GAUGE] Contact xt100 avec flaque: ", en_contact, " (nombre pools = ", nombre_pools_contact, ", mult = ", _calculer_multiplicateur_pools(), ")")

func _on_fluid_pool_running_change(est_running: bool) -> void:
	fluid_pool_running = est_running
	if not est_running:
		est_en_contact = false
		nombre_pools_contact = 0
	print("[GAUGE] Flaque running: ", est_running)

func _on_degats_recus(degats: int, est_missile: bool, _est_special: bool = false) -> void:
	# Appliquer les dégâts supplémentaires à la gauge UNIQUEMENT quand la flaque est active ET que xt100 est dedans
	if not est_en_contact or not fluid_pool_running or nombre_pools_contact <= 0:
		return
	
	# Utiliser directement l'équivalent en % selon le type de tir, multiplié selon la config multi-pools
	var multiplicateur := _calculer_multiplicateur_pools()
	var perte_base = degats_gauge_par_tir_secondaire if est_missile else degats_gauge_par_tir_principale
	var perte_gauge = perte_base * multiplicateur
	
	# Appliquer à la gauge
	valeur_actuelle = max(0.0, valeur_actuelle - perte_gauge)
	mettre_a_jour_affichage()
	
	print("[GAUGE] Dégâts reçus: ", degats, " missile:", est_missile, " pools:", nombre_pools_contact, " (mult:", multiplicateur, ") perte gauge: ", perte_gauge, "%")
	
	if valeur_actuelle <= 0.0 and est_active:
		est_active = false
		gauge_vide.emit()

func mettre_a_jour_affichage() -> void:
	if not gauge_rect:
		return
	
	# Calculer le ratio (100% = 1.0, 0% = 0.0)
	var ratio = valeur_actuelle / 100.0
	ratio = clamp(ratio, 0.0, 1.0)
	
	# Mettre à jour la largeur du ColorRect
	var largeur_max = 128.0  # Largeur originale du ColorRect
	gauge_rect.size.x = largeur_max * ratio
	
	# Garder la couleur originale (pas de changement dynamique)
	# La couleur reste celle configurée dans le .tscn

func set_valeur(valeur: float) -> void:
	valeur_actuelle = clamp(valeur, 0.0, 100.0)
	mettre_a_jour_affichage()
	valeur_changee.emit(valeur_actuelle)

func get_valeur() -> float:
	return valeur_actuelle
