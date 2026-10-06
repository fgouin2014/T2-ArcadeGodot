class_name GaugeLife2ndT100
extends Node2D

## State manager pour la 2e bataille boss XT100 (foundry_fight).
## Jauge unidirectionnelle (100% à 0%), sans régénération.
## Décrémentée par palier (défaut 5%) à chaque fin de cycle "blown" du boss XT100.
## Déclenche jouer_crack_defeat() sur le boss à 0%.

@onready var gauge_rect: ColorRect = $SpriteGauge/GaugeLife2ndT100

@export_group("Configuration")
## % de gauge perdu par cycle de déstabilisation (blown)
@export var perte_par_cycle_pct: float = 5.0
## Seuil de jauge pour déclencher l'apparition de xt100big Round 1 (ex: 75%)
@export var seuil_phase_big_pct: float = 75.0
## Seuil de jauge pour déclencher l'apparition de xt100big Round 2 (ex: 25%)
@export var seuil_phase_big2_pct: float = 25.0

@export_group("Déclencheur sur Arrêt Caméra")
@export var declencheur_stop: NodePath
@export var nom_stop_declencheur: String = "Stop2ndFightStart"

@export_group("Cible Boss XT100")
@export var xt100_cible: NodePath
@export var xt100big_cible: NodePath

# --- État interne ---
var valeur_actuelle: float = 100.0
var est_active: bool = false
var phase_actuelle_boss: int = 1
var _xt100_ref: Node = null
var _xt100big_ref: Node = null
var _stop_ref: StopMarker = null
var _largeur_max: float = 128.0
var _phase_big_declenchee: bool = false
var _phase_big2_declenchee: bool = false

signal gauge_vide()
signal valeur_changee(nouvelle_valeur: float)
signal phase_4_demarree()
signal phase_4_terminee()

func _ready() -> void:
	visible = false
	est_active = false
	valeur_actuelle = 100.0
	phase_actuelle_boss = 1
	_phase_big_declenchee = false
	_phase_big2_declenchee = false
	call_deferred("_connecter_stop_et_xt100")

func _connecter_stop_et_xt100() -> void:
	# 1. Connexion au StopMarker
	_stop_ref = _chercher_stop()
	if _stop_ref:
		if _stop_ref.has_signal("stop_enclenche"):
			if not _stop_ref.stop_enclenche.is_connected(_on_stop_atteint):
				_stop_ref.stop_enclenche.connect(_on_stop_atteint)
		print("[GAUGE2ND] Connectée au StopMarker: ", _stop_ref.name)
	else:
		push_warning("[GAUGE2ND] StopMarker introuvable: %s" % nom_stop_declencheur)

	# 2. Recherche et connexion au boss XT100
	_xt100_ref = _chercher_xt100()
	if _xt100_ref:
		if _xt100_ref.has_signal("cycle_blown_termine"):
			if not _xt100_ref.cycle_blown_termine.is_connected(_on_cycle_blown_termine):
				_xt100_ref.cycle_blown_termine.connect(_on_cycle_blown_termine)
		if _xt100_ref.has_signal("degats_recus"):
			if not _xt100_ref.degats_recus.is_connected(_on_xt100_degats_recus):
				_xt100_ref.degats_recus.connect(_on_xt100_degats_recus)
		print("[GAUGE2ND] Connectée au boss: ", _xt100_ref.name)
	else:
		push_warning("[GAUGE2ND] xt100 introuvable")

	# 3. Recherche et connexion à xt100big
	_xt100big_ref = _chercher_xt100big()
	if _xt100big_ref:
		if _xt100big_ref.has_signal("retract_termine"):
			if not _xt100big_ref.retract_termine.is_connected(_on_xt100big_retract_termine):
				_xt100big_ref.retract_termine.connect(_on_xt100big_retract_termine)
		print("[GAUGE2ND] Connectée à xt100big: ", _xt100big_ref.name)

func _chercher_stop() -> StopMarker:
	if declencheur_stop != null and not declencheur_stop.is_empty():
		var node = get_node_or_null(declencheur_stop)
		if node is StopMarker:
			return node
		var node_parent = get_parent().get_node_or_null(declencheur_stop) if get_parent() else null
		if node_parent is StopMarker:
			return node_parent

	if not nom_stop_declencheur.is_empty():
		var scene = get_tree().current_scene if get_tree() else null
		if scene:
			var node = scene.find_child(nom_stop_declencheur, true, false)
			if node is StopMarker:
				return node
		if get_parent():
			var node_p = get_parent().find_child(nom_stop_declencheur, true, false)
			if node_p is StopMarker:
				return node_p

	return null

func _chercher_xt100() -> Node:
	if xt100_cible != null and not xt100_cible.is_empty():
		var n = get_node_or_null(xt100_cible)
		if n:
			return n
		if get_parent():
			var np = get_parent().get_node_or_null(xt100_cible)
			if np:
				return np

	if get_parent():
		var n_2nd = get_parent().get_node_or_null("xt1002nd")
		if n_2nd:
			return n_2nd
		var n_xt = get_parent().find_child("xt100*", true, false)
		if n_xt:
			return n_xt

	var scene = get_tree().current_scene if get_tree() else null
	if scene:
		return scene.find_child("xt1002nd", true, false)

	return null

func _chercher_xt100big() -> Node:
	if xt100big_cible != null and not xt100big_cible.is_empty():
		var n = get_node_or_null(xt100big_cible)
		if n:
			return n
		if get_parent():
			var np = get_parent().get_node_or_null(xt100big_cible)
			if np:
				return np

	if get_parent():
		var n_big = get_parent().get_node_or_null("xt100big")
		if n_big:
			return n_big

	var scene = get_tree().current_scene if get_tree() else null
	if scene:
		return scene.find_child("xt100big", true, false)

	return null

func _on_stop_atteint() -> void:
	visible = true
	est_active = true
	valeur_actuelle = 100.0
	phase_actuelle_boss = 1
	_phase_big_declenchee = false
	_phase_big2_declenchee = false
	_mettre_a_jour_affichage()
	print("[GAUGE2ND] Activée et visible (100%) sur arrêt caméra")

func _on_xt100_degats_recus(degats: int, est_missile: bool, est_special: bool = false) -> void:
	if not est_active:
		return
	
	# En Phase 2 (75% -> 50%), chaque hit décrémente la jauge en temps réel
	if phase_actuelle_boss == 2:
		valeur_actuelle = maxf(50.0, valeur_actuelle - float(degats))
		_mettre_a_jour_affichage()
		valeur_changee.emit(valeur_actuelle)
		print("[GAUGE2ND Phase 2] Dégâts reçus: -%d PV -> Jauge: %.1f %%" % [degats, valeur_actuelle])
		
		# Seuil 50% atteint -> Conclusion Phase 2 et démarrage Phase 3
		if valeur_actuelle <= 50.0:
			phase_actuelle_boss = 3
			_transition_phase_2_vers_3()
	
	# En Phase 4 (25% -> 0%), SEULES les munitions spéciales Shotgun font baisser la jauge
	elif phase_actuelle_boss == 4:
		if est_missile and est_special:
			valeur_actuelle = maxf(0.0, valeur_actuelle - float(degats))
			_mettre_a_jour_affichage()
			valeur_changee.emit(valeur_actuelle)
			print("[GAUGE2ND Phase 4] Dégâts Shotgun SPÉCIAL reçus: -%d PV -> Jauge: %.1f %%" % [degats, valeur_actuelle])
			
			# Seuil 0% atteint uniquement avec tir spécial -> Transition vers la séquence finale boiler
			if valeur_actuelle <= 0.0:
				phase_actuelle_boss = 5
				_transition_phase_4_vers_finale()
		else:
			print("[GAUGE2ND Phase 4] Tir standard/missile normal reçu : Le T-1000 réagit et recule, mais la jauge reste fixe (%.1f %%)" % valeur_actuelle)

func _on_cycle_blown_termine(montant_perte: float = -1.0) -> void:
	if not est_active and montant_perte >= 0.0:
		return

	if montant_perte < 0.0 and montant_perte != -1.0:
		# Cas de restauration explicite (ex: -25.0)
		restaurer_gauge(absf(montant_perte))
		return

	var perte := perte_par_cycle_pct if montant_perte <= 0.0 else montant_perte
	valeur_actuelle = maxf(0.0, valeur_actuelle - perte)
	_mettre_a_jour_affichage()
	valeur_changee.emit(valeur_actuelle)
	print("[GAUGE2ND] Cycle blown terminé -> Jauge: %.1f %% (-%.1f %%)" % [valeur_actuelle, perte])

	# Déclenchement de l'interlude xt100big Round 1 à 75% (fin Phase 1)
	if valeur_actuelle <= seuil_phase_big_pct and not _phase_big_declenchee and phase_actuelle_boss == 1:
		_phase_big_declenchee = true
		_declencher_interlude_xt100big_round1()
		return

	# Déclenchement de l'interlude xt100big Round 2 à 25% (fin Phase 3)
	if valeur_actuelle <= seuil_phase_big2_pct and not _phase_big2_declenchee and phase_actuelle_boss == 3:
		_phase_big2_declenchee = true
		_declencher_interlude_xt100big_round2()
		return

func _declencher_interlude_xt100big_round1() -> void:
	print("[GAUGE2ND] Seuil %.1f %% atteint -> Pause XT100 et activation XT100Big (Round 1)" % seuil_phase_big_pct)
	
	if _xt100_ref and _xt100_ref.has_method("mettre_en_pause_phase"):
		_xt100_ref.mettre_en_pause_phase()
	
	if _xt100big_ref:
		if _xt100big_ref.has_method("activer_acteur"):
			_xt100big_ref.activer_acteur()
	else:
		push_warning("[GAUGE2ND] xt100big_ref introuvable pour l'interlude Round 1 !")

func _declencher_interlude_xt100big_round2() -> void:
	print("[GAUGE2ND] Seuil %.1f %% atteint -> Pause XT100 et activation XT100Big (Round 2)" % seuil_phase_big2_pct)
	
	if _xt100_ref and _xt100_ref.has_method("mettre_en_pause_phase"):
		_xt100_ref.mettre_en_pause_phase()
	
	if _xt100big_ref:
		if _xt100big_ref.has_method("reinitialiser_pour_prochain_round"):
			_xt100big_ref.reinitialiser_pour_prochain_round(20)
		if _xt100big_ref.has_method("activer_acteur"):
			_xt100big_ref.activer_acteur()
	else:
		push_warning("[GAUGE2ND] xt100big_ref introuvable pour l'interlude Round 2 !")

func _on_xt100big_retract_termine() -> void:
	if phase_actuelle_boss == 1:
		print("[GAUGE2ND] XT100Big Round 1 terminé -> Démarrage Phase 2 du XT100")
		phase_actuelle_boss = 2
		if _xt100_ref:
			if _xt100_ref.has_method("demarrer_phase_2"):
				_xt100_ref.demarrer_phase_2()
			elif _xt100_ref.has_method("reprendre_seconde_phase"):
				_xt100_ref.reprendre_seconde_phase()
	elif phase_actuelle_boss == 3:
		print("[GAUGE2ND] XT100Big Round 2 terminé -> Démarrage Phase 4 du XT100")
		phase_actuelle_boss = 4
		phase_4_demarree.emit()
		if _xt100_ref and _xt100_ref.has_method("demarrer_phase_4"):
			_xt100_ref.demarrer_phase_4()

func _transition_phase_2_vers_3() -> void:
	print("[GAUGE2ND] Seuil 50% atteint -> Conclusion Phase 2 et démarrage Phase 3")
	if _xt100_ref:
		if _xt100_ref.has_method("conclure_phase_2"):
			await _xt100_ref.conclure_phase_2()
		if _xt100_ref.has_method("demarrer_phase_3"):
			_xt100_ref.demarrer_phase_3()

func _transition_phase_4_vers_finale() -> void:
	print("[GAUGE2ND] Jauge à 0% ! Démarrage de la séquence finale boiler (Phase 5)")
	phase_actuelle_boss = 5
	if _xt100_ref and _xt100_ref.has_method("declencher_sequence_finale_boiler"):
		_xt100_ref.declencher_sequence_finale_boiler()

func _mettre_a_jour_affichage() -> void:
	if not gauge_rect:
		return
	var ratio := clampf(valeur_actuelle / 100.0, 0.0, 1.0)
	gauge_rect.size.x = _largeur_max * ratio

func desactiver_et_cacher() -> void:
	est_active = false
	visible = false

func set_valeur(v: float) -> void:
	valeur_actuelle = clampf(v, 0.0, 100.0)
	_mettre_a_jour_affichage()
	valeur_changee.emit(valeur_actuelle)

func restaurer_gauge(montant_pct: float = 25.0) -> void:
	valeur_actuelle = clampf(valeur_actuelle + montant_pct, 0.0, 100.0)
	phase_actuelle_boss = 4
	est_active = true
	visible = true
	phase_4_demarree.emit()
	_mettre_a_jour_affichage()
	valeur_changee.emit(valeur_actuelle)
	print("[GAUGE2ND] Restauration jauge de +%.1f %% -> Jauge: %.1f %% (Phase 4 réactivée)" % [montant_pct, valeur_actuelle])

func get_valeur() -> float:
	return valeur_actuelle
