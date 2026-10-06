class_name BallisticTriggerMarker
extends Marker2D

## Marqueur de pluie balistique continue d'items (cartouches, munitions, etc.).
## Les items sont instanciés comme enfants de Camera2D → ils suivent la lucarne automatiquement.
## Le BTM est PASSIF : il ne démarre jamais seul. Seul un StopMarker ou appel externe
## déclenche demarrer_pluie() / arreter_pluie() / modifier_cadence().

@export_group("Configuration Items & Quantité")
## Liste de scènes PickupItem pouvant tomber (une ou plusieurs).
@export var scenes_items: Array[PackedScene] = []
## Poids relatifs pour chaque scène (même taille que scenes_items).
## Ex: [0.7, 0.2, 0.1] → 70% premier item, 20% deuxième, 10% troisième.
## Si vide ou taille différente, distribution uniforme.
@export var poids_items: Array[float] = []
## Quantité d'items / munitions contenue dans chaque drop (ex: 3 shotgun shells, 5 missiles, etc.).
@export var quantite_item: int = 1
## Z-Index des items pour l'affichage au premier plan.
@export var z_index_item: int = 500

@export_group("Animation de Collecte")
## Durée en secondes du vol du pickup vers le HUD lors de la collecte.
@export var duree_envol_sec: float = 1.25

@export_group("Effet d'Apparition")
## Comportement physique / trajectoire du pickup lors de son apparition.
@export_enum("fixe", "tombe_au_sol", "tombe_hors_ecran", "bond_au_sol", "bond_hors_ecran") var effet_apparition: String = "tombe_hors_ecran"

@export_group("Paramètres Balistiques")
## Ligne Y absolue où l'item doit se poser au sol (si mode au sol).
@export var hauteur_sol_y: float = 150.0
## Gravité / accélération de chute vers le bas (en px/s²). Contrôle la vitesse de chute.
@export var gravite: float = 200.0
## Vitesse initiale de chute (en px/s vers le bas). 0 = départ statique, >0 = déjà en vitesse à l'apparition.
@export var vitesse_chute_initiale_y: float = 0.0
## Impulsion verticale vers le haut pour les modes "bond_*" (en px/s).
@export var impulsion_bond_y: float = 140.0
## Écartement / impulsion horizontale aléatoire gauche/droite pour les bonds (en px/s).
@export var dispersion_x: float = 35.0
## Si coché, l'item effectue un petit rebond élastique quand il touche le sol.
@export var rebond_au_sol: bool = false
## Coefficient d'élasticité du rebond (0.35 = petit rebond amorti).
@export_range(0.0, 0.8) var elasticite_rebond: float = 0.35

@export_group("Motion Scale & Profondeur")
## Facteur de suivi caméra en X.
## 1.0 = item 100% fixé à la lucarne (ne dérive pas).
## 0.85 = item dérive légèrement → le joueur peut manquer son opportunité.
## 0.0 = item complètement en espace monde (dérive à la vitesse caméra).
@export_range(0.0, 1.0, 0.05) var motion_scale: float = 1.0

@export_group("Points de Chute & Ordre")
## Offsets X (en pixels) par rapport au centre de la lucarne.
## Ex: [-100, -35, 35, 100] = 4 colonnes de chute.
@export var points_spawn_x: Array[float] = [-100.0, -35.0, 35.0, 100.0]
## Premier point de départ lors du démarrage.
@export_enum("Gauche (0)", "Centre_Gauche (1)", "Centre_Droit (2)", "Droite (3)", "Aleatoire") var premier_point_depart: String = "Centre_Gauche (1)"
## Hauteur Y de spawn en espace local caméra.
## -88 = haut exact de l'écran, -100 = légèrement au-dessus (recommandé).
@export var hauteur_spawn_y: float = -100.0
## Dispersion aléatoire en X autour du point (en pixels).
@export var dispersion_x_px: float = 8.0

@export_group("Spécifique Phase IV (Shotgun Spécial)")
## Si coché, active l'injection de xpickup_29 en pluie conditionnelle.
## Piloté automatiquement via GaugeLife2ndT100 (signaux phase_4_demarree/terminee).
## Peut aussi être activé manuellement pour les tests.
@export var activer_drop_special_phase4: bool = false
## Scène du pickup spécial (ex: xpickup_29_shotgun.tscn).
@export var scene_pickup_special: PackedScene = preload("res://aseprite/xpickup_29_shotgun.tscn")
## Index de la colonne réservée pour le drop spécial (0 à 3, ex: 3 = Droite).
@export_range(0, 3) var index_colonne_speciale: int = 3
## Probabilité de spawn sur cette colonne (ex: 0.333 = 1 chance sur 3).
@export_range(0.0, 1.0, 0.05) var probabilite_drop_special: float = 0.333
## StopMarker du début du 2nd combat boss (ex: Stop2ndFightStart).
## À son déclenchement, le BTM auto-découvre GaugeLife2ndT100 et se connecte
## à ses signaux phase_4_demarree / phase_4_terminee pour piloter le drop spécial.
@export var declencheur_stop_phase4: NodePath
@export var nom_stop_phase4: String = "Stop2ndFightStart"


@export_group("Cadence & Timing")
## Délai en secondes entre deux chutes d'items consécutives.
@export var delai_entre_chutes_sec: float = 2.0

# --- État interne ---
var _pluie_active: bool = false
var _boucle_en_cours: bool = false
var _index_point_courant: int = 0
var _token_session: int = 0
var _premiere_drop_speciale_faite: bool = false
var _stop_phase4_ref: StopMarker = null
var _gauge_life_2nd_ref: GaugeLife2ndT100 = null

func _ready() -> void:
	_initialiser_index_depart()
	# BTM est passif — aucun auto-démarrage.
	# Un StopMarker doit appeler demarrer_pluie() pour lancer la pluie.
	call_deferred("_connecter_stop_phase4")

# ─── API PUBLIQUE (appelée par StopMarker) ───────────────────────────────────

func demarrer_pluie() -> void:
	_pluie_active = true
	if _boucle_en_cours:
		return
	print("[BallisticTriggerMarker] %s : Démarrage de la pluie balistique" % name)
	_boucle_balistique()

func arreter_pluie() -> void:
	_pluie_active = false
	_token_session += 1
	_boucle_en_cours = false
	_premiere_drop_speciale_faite = false
	print("[BallisticTriggerMarker] %s : Pluie arrêtée" % name)

# ─── Connexion Phase IV (auto-découverte GaugeLife2ndT100) ───────────────────

func _connecter_stop_phase4() -> void:
	# Cherche le StopMarker Phase IV par NodePath ou par nom
	if declencheur_stop_phase4 and not declencheur_stop_phase4.is_empty():
		var n = get_node_or_null(declencheur_stop_phase4)
		if n == null and get_parent():
			n = get_parent().get_node_or_null(declencheur_stop_phase4)
		if n is StopMarker:
			_stop_phase4_ref = n
	if _stop_phase4_ref == null and not nom_stop_phase4.is_empty():
		var scene = get_tree().current_scene if get_tree() else null
		if scene:
			var n = scene.find_child(nom_stop_phase4, true, false)
			if n is StopMarker:
				_stop_phase4_ref = n
	if _stop_phase4_ref:
		if not _stop_phase4_ref.stop_enclenche.is_connected(_on_stop_phase4_declenche):
			_stop_phase4_ref.stop_enclenche.connect(_on_stop_phase4_declenche)
		print("[BTM] %s : StopMarker Phase IV connecté → %s" % [name, _stop_phase4_ref.name])
	else:
		print("[BTM] %s : Pas de StopMarker Phase IV (pilotage drop spécial manuel)" % name)

func _on_stop_phase4_declenche() -> void:
	if _gauge_life_2nd_ref != null:
		return  # déjà connecté
	var scene = get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	var gauge := _trouver_gauge_life_2nd(scene)
	if gauge == null:
		push_warning("[BTM] %s : GaugeLife2ndT100 introuvable dans la scène !" % name)
		return
	_gauge_life_2nd_ref = gauge
	if not _gauge_life_2nd_ref.phase_4_demarree.is_connected(demarrer_drop_special):
		_gauge_life_2nd_ref.phase_4_demarree.connect(demarrer_drop_special)
	if not _gauge_life_2nd_ref.phase_4_terminee.is_connected(arreter_drop_special):
		_gauge_life_2nd_ref.phase_4_terminee.connect(arreter_drop_special)
	print("[BTM] %s : Connecté à GaugeLife2ndT100 → %s" % [name, _gauge_life_2nd_ref.name])

func _trouver_gauge_life_2nd(root: Node) -> GaugeLife2ndT100:
	for child in root.get_children():
		if child is GaugeLife2ndT100:
			return child
		var found := _trouver_gauge_life_2nd(child)
		if found:
			return found
	return null

## Active le drop spécial (xpickup_29). Appelé via signal phase_4_demarree ou manuellement.
func demarrer_drop_special() -> void:
	activer_drop_special_phase4 = true
	_premiere_drop_speciale_faite = false
	print("[BTM] %s : Drop spécial Phase IV ACTIVÉ" % name)

## Désactive le drop spécial. Appelé via signal phase_4_terminee ou manuellement.
func arreter_drop_special() -> void:
	activer_drop_special_phase4 = false
	print("[BTM] %s : Drop spécial Phase IV DÉSACTIVÉ" % name)

func _exit_tree() -> void:
	if _gauge_life_2nd_ref:
		if _gauge_life_2nd_ref.phase_4_demarree.is_connected(demarrer_drop_special):
			_gauge_life_2nd_ref.phase_4_demarree.disconnect(demarrer_drop_special)
		if _gauge_life_2nd_ref.phase_4_terminee.is_connected(arreter_drop_special):
			_gauge_life_2nd_ref.phase_4_terminee.disconnect(arreter_drop_special)
		_gauge_life_2nd_ref = null

func modifier_cadence(nouvelle_cadence: float) -> void:
	delai_entre_chutes_sec = maxf(0.05, nouvelle_cadence)
	print("[BallisticTriggerMarker] %s : Nouvelle cadence = %.2fs" % [name, delai_entre_chutes_sec])


# ─── Boucle principale ───────────────────────────────────────────────────────

func _boucle_balistique() -> void:
	if _boucle_en_cours:
		return
	_boucle_en_cours = true
	_token_session += 1
	var token := _token_session

	while _pluie_active and _token_session == token:
		_lancer_un_item_sequentiel()
		await get_tree().create_timer(maxf(delai_entre_chutes_sec, 0.05), false).timeout

	_boucle_en_cours = false
	print("[BallisticTriggerMarker] %s : Boucle balistique terminée" % name)

# ─── Spawn d'un item ─────────────────────────────────────────────────────────

func _lancer_un_item_sequentiel() -> void:
	if scenes_items.is_empty():
		push_warning("[BallisticTriggerMarker] %s : scenes_items est vide !" % name)
		return

	var cam := get_viewport().get_camera_2d() as Camera2D
	if cam == null:
		push_warning("[BallisticTriggerMarker] %s : Camera2D introuvable, skip spawn." % name)
		return

	var col_actuelle := _index_point_courant % points_spawn_x.size()
	var scene_choisie: PackedScene = null

	if activer_drop_special_phase4:
		if not _premiere_drop_speciale_faite and col_actuelle == index_colonne_speciale:
			# 1ère drop : obligatoirement sur la colonne réservée
			scene_choisie = scene_pickup_special if scene_pickup_special else _choisir_scene()
			_premiere_drop_speciale_faite = true
			print("[BallisticTriggerMarker] Spawn SPÉCIAL (1ère fois, colonne imposée %d)" % col_actuelle)
		elif _premiere_drop_speciale_faite and randf() <= probabilite_drop_special:
			# Drops suivantes : n'importe quelle colonne, selon probabilité
			scene_choisie = scene_pickup_special if scene_pickup_special else _choisir_scene()
			print("[BallisticTriggerMarker] Spawn SPÉCIAL aléatoire (colonne %d)" % col_actuelle)
		else:
			scene_choisie = _choisir_scene()
	else:
		scene_choisie = _choisir_scene()

	if scene_choisie == null:
		return

	var instance := scene_choisie.instantiate() as Node2D
	if instance == null:
		push_warning("[BallisticTriggerMarker] %s : Impossible d'instancier la scène." % name)
		return

	instance.z_index = z_index_item

	if instance is PickupItem:
		var pickup := instance as PickupItem
		pickup.quantite = quantite_item
		pickup.duree_envol_sec = duree_envol_sec
		pickup.effet_apparition = effet_apparition
		pickup.hauteur_sol_y = hauteur_sol_y
		pickup.gravite = gravite
		pickup.vitesse_chute_initiale_y = vitesse_chute_initiale_y
		pickup.impulsion_bond_y = impulsion_bond_y
		pickup.dispersion_x = dispersion_x
		pickup.rebond_au_sol = rebond_au_sol
		pickup.elasticite_rebond = elasticite_rebond
		pickup.actif_au_demarrage = true
		pickup._motion_scale = motion_scale

	# Enfant de Camera2D → suit la lucarne automatiquement
	cam.add_child(instance)

	# Position en espace local caméra :
	# x = colonne de spawn (offset depuis le centre), y = au-dessus du haut écran
	var offset_x := points_spawn_x[_index_point_courant % points_spawn_x.size()]
	var jitter_x := randf_range(-dispersion_x_px, dispersion_x_px)
	instance.position = Vector2(offset_x + jitter_x, hauteur_spawn_y)

	_index_point_courant = (_index_point_courant + 1) % points_spawn_x.size()

# ─── Sélection pondérée d'item ───────────────────────────────────────────────

func _choisir_scene() -> PackedScene:
	if scenes_items.size() == 1:
		return scenes_items[0]
	if poids_items.size() != scenes_items.size() or poids_items.is_empty():
		# Distribution uniforme si pas de poids ou taille incohérente
		return scenes_items[randi() % scenes_items.size()]
	# Tirage pondéré
	var total := 0.0
	for p in poids_items:
		total += maxf(0.0, p)
	if total <= 0.0:
		return scenes_items[randi() % scenes_items.size()]
	var r := randf() * total
	var cumul := 0.0
	for i in scenes_items.size():
		cumul += maxf(0.0, poids_items[i])
		if r <= cumul:
			return scenes_items[i]
	return scenes_items[-1]

# ─── Initialisation index de départ ─────────────────────────────────────────

func _initialiser_index_depart() -> void:
	match premier_point_depart:
		"Gauche (0)":
			_index_point_courant = 0
		"Centre_Gauche (1)":
			_index_point_courant = 1
		"Centre_Droit (2)":
			_index_point_courant = 2
		"Droite (3)":
			_index_point_courant = 3
		"Aleatoire":
			_index_point_courant = randi() % maxi(1, points_spawn_x.size())
		_:
			_index_point_courant = 1
