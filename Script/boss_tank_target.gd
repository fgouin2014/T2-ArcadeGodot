class_name BossTankTarget
extends Node2D

@export var scene_effet_hittank: PackedScene = preload("res://aseprite/effect/hittank_effect.tscn")
@export var pv_max: int = 50
var pv_actuels: int = 50

@onready var gauge_ref: Node2D = get_node_or_null("GaugeLifeT1000") as Node2D

func _ready() -> void:
	pv_actuels = pv_max
	
	# Connecter gauge_vide à xt100
	if gauge_ref and gauge_ref.has_signal("gauge_vide"):
		if not gauge_ref.gauge_vide.is_connected(_on_gauge_vide):
			gauge_ref.gauge_vide.connect(_on_gauge_vide)
	
	# Connecter le signal contact_hittank_effect de xt100 à la gauge
	var xt100_node = get_node_or_null("Node2D/xt100")
	if xt100_node and xt100_node.has_signal("contact_hittank_effect"):
		if gauge_ref and gauge_ref.has_method("_on_contact_change"):
			xt100_node.contact_hittank_effect.connect(gauge_ref._on_contact_change)
			print("[BOSS] Signal contact_hittank_effect connecté à la gauge")
	
	# Connecter le signal degats_recus de xt100 à la gauge
	if xt100_node and xt100_node.has_signal("degats_recus"):
		if gauge_ref and gauge_ref.has_method("_on_degats_recus"):
			xt100_node.degats_recus.connect(gauge_ref._on_degats_recus)
			print("[BOSS] Signal degats_recus connecté à la gauge")

func subir_degats(degats: int = 1) -> void:
	pv_actuels = max(0, pv_actuels - degats)
	# Un tir normal ne crée pas de trou

func subir_degats_partie(nom_partie: String, degats: int, pos_impact_monde: Vector2, est_missile: bool = false, est_special: bool = false) -> void:
	if est_missile:
		subir_degats_missile(degats, pos_impact_monde, est_special)
	else:
		pv_actuels = max(0, pv_actuels - degats)
	# Un tir normal ne crée pas de trou

func subir_degats_missile(degats: int, pos_impact_monde: Vector2, _est_special: bool = false) -> void:
	pv_actuels = max(0, pv_actuels - degats)
	# Seul le tir alternatif (missile) perfore et crée les trous/fuites de liquide
	creer_effet_impact(pos_impact_monde)

func creer_effet_impact(pos_monde: Vector2) -> void:
	if scene_effet_hittank == null:
		print("[BOSS] scene_effet_hittank est null!")
		return
	
	print("[BOSS] Création effet hittank à position: ", pos_monde)
	var instance_effet = scene_effet_hittank.instantiate() as HitTankEffect
	if instance_effet:
		# Ajouter l'effet comme enfant direct du boss pour qu'il suive le tank
		add_child(instance_effet)
		var pos_locale = to_local(pos_monde)
		instance_effet.configurer_impact(pos_locale)
		print("[BOSS] Effet hittank créé et configuré")
		
		# Connecter uniquement le signal fluid_pool_running_change à la gauge
		# (le contact est maintenant détecté par xt100 directement)
		if gauge_ref and gauge_ref.has_method("_on_fluid_pool_running_change"):
			instance_effet.fluid_pool_running_change.connect(gauge_ref._on_fluid_pool_running_change)
			print("[BOSS] Signal fluid_pool_running_change connecté à la gauge")
		else:
			print("[BOSS] ERREUR: gauge_ref ou méthode _on_fluid_pool_running_change introuvable")
	else:
		print("[BOSS] ERREUR: instance_effet est null après instantiate")

func get_pv_actuels() -> int:
	return pv_actuels

func get_pv_max() -> int:
	return pv_max

func _on_gauge_vide() -> void:
	# Trouver xt100 et déclencher crack_defeat
	var xt100_node = get_node_or_null("Node2D/xt100")
	if xt100_node and xt100_node.has_method("jouer_crack_defeat"):
		xt100_node.jouer_crack_defeat()
		# Après crack, désactiver et cacher la gauge
		if gauge_ref and gauge_ref.has_method("desactiver_et_cacher"):
			# Attendre un peu que crack se termine avant de cacher
			get_tree().create_timer(1.0).timeout.connect(func():
				if gauge_ref and is_instance_valid(gauge_ref):
					gauge_ref.desactiver_et_cacher()
			)
