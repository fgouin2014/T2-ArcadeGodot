extends Node

## État global de la session de jeu (autoload "GlobalSettings").
## Contient la carte sélectionnée ainsi que l'état du joueur (vie, crédits, score).

signal vie_modifiee(vie_actuelle: int, vie_max: int)
signal score_modifie(score: int)
signal credits_modifies(credits_restants: int)
signal missiles_modifies(missiles_restants: int)
signal joueur_touche(degats: int)
signal partie_terminee(score_final: int)
signal demande_changement_niveau(prochain_niveau: String)
signal pickup_collecte_anime(texture_pickup: Texture2D, pos_ecran_depart: Vector2, type_pickup: String)

const DICO_NIVEAUX: Array[Dictionary] = [
	{
		"fichier": "level1.tscn",
		"code": "MISSION 01",
		"titre": "LA GUERRE DU FUTUR (2029)",
		"desc": "Combattez les Endosquelettes et Hunter-Killers dans les ruines de L.A.",
		"actif": true,
		"nextmap": "level2.tscn"
	},
	{
		"fichier": "level2.tscn",
		"code": "MISSION 02",
		"titre": "LA PLANQUE",
		"desc": "Protégez John et Sarah Connor contre les assauts ennemis.",
		"actif": true,
		"nextmap": "level3.tscn"
	},
	{
		"fichier": "level3.tscn",
		"code": "MISSION 03",
		"titre": "LA POURSUITE",
		"desc": "Escortez le véhicule des civils en fuite.",
		"actif": true,
		"nextmap": "level4.tscn"
	},
	{
		"fichier": "level4.tscn",
		"code": "MISSION 04",
		"titre": "LE CŒUR DE SKYNET",
		"desc": "Affrontez les défenses automatisées du noyau Skynet.",
		"actif": true,
		"nextmap": "level5.tscn"
	},
	{
		"fichier": "level5.tscn",
		"code": "MISSION 05",
		"titre": "CYBERDYNE OFFICE",
		"desc": "Infiltration du complexe Cyberdyne protèger Young John Connor.",
		"actif": true,
		"nextmap": "level6.tscn"
	},
	{
		"fichier": "level6.tscn",
		"code": "MISSION 06",
		"titre": "LE COFFRE CYBERDYNE",
		"desc": "Infiltration du complexe Cyberdyne recuperer les objets du future.",
		"actif": true,
		"nextmap": "level6.tscn"
	},
	{
		"fichier": "level7.tscn",
		"code": "MISSION 07",
		"titre": "POURSUITE DE L'AUTOROUTE",
		"desc": "Course poursuite à grande vitesse en camion-citerne.",
		"actif": true,
		"nextmap": "level8.tscn"
	},
	{
		"fichier": "level8.tscn",
		"code": "MISSION 08",
		"titre": "LA FONDERIE D'ACIER",
		"desc": "Le duel final contre le T-1000 dans le métal en fusion.",
		"actif": true,
		"nextmap": "maps/menu_selection.tscn"
	}
]

const VIE_MAX_DEFAUT: int = 100
const CREDITS_DEFAUT: int = 3
const MISSILES_DEFAUT: int = 999
const DUREE_INVULNERABILITE_SEC: float = 1.0

@export_group("Arme joueur (global)")
## Dégâts infligés aux cibles par le tir principal (projectile joueur).
@export var degats_tir_principal: int = 1
## Dégâts infligés par l'alt-fire / missile visuel (clic droit, B).
@export var degats_tir_alternatif: int = 5

var carte_selectionnee: String = ""

var vie_max: int = VIE_MAX_DEFAUT
var vie_actuelle: int = VIE_MAX_DEFAUT
var credits_restants: int = CREDITS_DEFAUT
var missiles_restants: int = MISSILES_DEFAUT
var score: int = 0
var partie_perdue: bool = false

# --- Gestion Arme Spéciale Shotgun (Level 8) ---
var munitions_shotgun_special: int = 0
var _stock_missiles_sauvegarde: int = -1
var dernier_tir_etait_special: bool = false

var _invulnerable_jusqua_msec: int = 0

func reinitialiser_partie() -> void:
	vie_max = VIE_MAX_DEFAUT
	vie_actuelle = VIE_MAX_DEFAUT
	credits_restants = CREDITS_DEFAUT
	missiles_restants = MISSILES_DEFAUT
	munitions_shotgun_special = 0
	_stock_missiles_sauvegarde = -1
	dernier_tir_etait_special = false
	score = 0
	partie_perdue = false
	_invulnerable_jusqua_msec = 0
	vie_modifiee.emit(vie_actuelle, vie_max)
	credits_modifies.emit(credits_restants)
	missiles_modifies.emit(missiles_restants)
	score_modifie.emit(score)

func est_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_jusqua_msec

func infliger_degats_joueur(degats: int) -> void:
	if partie_perdue or degats <= 0 or est_invulnerable():
		return

	_invulnerable_jusqua_msec = Time.get_ticks_msec() + int(DUREE_INVULNERABILITE_SEC * 1000.0)
	vie_actuelle = max(0, vie_actuelle - degats)
	joueur_touche.emit(degats)
	vie_modifiee.emit(vie_actuelle, vie_max)

	if vie_actuelle == 0:
		_consommer_credit()

func soigner_joueur(points: int) -> void:
	if partie_perdue or points <= 0:
		return
	vie_actuelle = min(vie_max, vie_actuelle + points)
	vie_modifiee.emit(vie_actuelle, vie_max)

func ajouter_score(points: int) -> void:
	if points <= 0:
		return
	score += points
	score_modifie.emit(score)

func obtenir_degats_tir_joueur(mode_missile: bool = false) -> int:
	var montant := degats_tir_alternatif if mode_missile else degats_tir_principal
	return maxi(1, montant)

func peut_tirer_missile() -> bool:
	if partie_perdue:
		return false
	if munitions_shotgun_special > 0:
		return true
	return missiles_restants > 0

func consommer_missile() -> bool:
	if not peut_tirer_missile():
		return false
	
	if munitions_shotgun_special > 0:
		dernier_tir_etait_special = true
		munitions_shotgun_special -= 1
		if munitions_shotgun_special <= 0:
			# Rétablissement du stock régulier de missiles précédent
			munitions_shotgun_special = 0
			if _stock_missiles_sauvegarde >= 0:
				missiles_restants = _stock_missiles_sauvegarde
				_stock_missiles_sauvegarde = -1
			print("[GLOBAL] Shotgun spécial épuisé -> Rétablissement des missiles normaux (", missiles_restants, ")")
			missiles_modifies.emit(missiles_restants)
		else:
			missiles_modifies.emit(munitions_shotgun_special)
		return true

	dernier_tir_etait_special = false
	missiles_restants -= 1
	missiles_modifies.emit(missiles_restants)
	return true

func ajouter_missiles(quantite: int) -> void:
	if quantite <= 0:
		return
	if munitions_shotgun_special > 0:
		# Shotgun spécial actif : accumuler dans le stock normal sauvegardé.
		# Ces shells seront restaurés dans missiles_restants quand le spécial s'épuise.
		_stock_missiles_sauvegarde += quantite
		print("[GLOBAL] xpickup_12 ramassé pendant shotgun spécial → stock normal sauvegardé : ", _stock_missiles_sauvegarde)
	else:
		missiles_restants += quantite
		missiles_modifies.emit(missiles_restants)

## Active l'arme spéciale Shotgun (ex: Level 8) : remplace temporairement le stock de missiles
func activer_shotgun_special(quantite: int = 3) -> void:
	if quantite <= 0:
		return
	if munitions_shotgun_special <= 0:
		# Sauvegarder le stock actuel de missiles pour le restaurer à 0
		_stock_missiles_sauvegarde = missiles_restants
		munitions_shotgun_special = quantite
	else:
		# Cumuler si le joueur en ramasse d'autres
		munitions_shotgun_special += quantite
	print("[GLOBAL] Shotgun spécial activé ! Munitions : ", munitions_shotgun_special, " (stock précédent sauvegardé : ", _stock_missiles_sauvegarde, ")")
	missiles_modifies.emit(munitions_shotgun_special)

func ajouter_credits(quantite: int = 1) -> void:
	if quantite <= 0:
		return
	credits_restants += quantite
	credits_modifies.emit(credits_restants)

## Active un bouclier temporaire qui protège des dégâts pendant duree_sec
func activer_bouclier(duree_sec: float = 20.0) -> void:
	_invulnerable_jusqua_msec = max(_invulnerable_jusqua_msec, Time.get_ticks_msec() + int(duree_sec * 1000.0))
	print("[GLOBAL] Bouclier activé pour ", duree_sec, " secondes !")

## Recharger complètement la jauge GunPower de l'arme
func recharger_gunpower_complet() -> void:
	var camera = get_tree().root.find_child("Camera2D", true, false)
	if camera and "gun_power_actuel" in camera and "gun_power_max" in camera:
		camera.gun_power_actuel = camera.gun_power_max
		if "en_surchauffe" in camera:
			camera.en_surchauffe = false
		print("[GLOBAL] GunPower rechargé au maximum !")

## Active le coolant (anti-surchauffe) sur la caméra pendant duree_sec
func activer_coolant(duree_sec: float = 20.0) -> void:
	var camera = get_tree().root.find_child("Camera2D", true, false)
	if camera and camera.has_method("activer_coolant"):
		camera.activer_coolant(duree_sec)
	elif camera and "en_surchauffe" in camera:
		camera.gun_power_actuel = camera.gun_power_max
		camera.en_surchauffe = false
		print("[GLOBAL] Coolant activé pour ", duree_sec, " secondes !")

## Déclenche une nuke : élimine tous les ennemis visibles à l'écran et ajoute un gros score
func declencher_nuke(score_bonus: int = 5000) -> void:
	ajouter_score(score_bonus)
	# Élimination de tous les ennemis ActorBase présents dans le tree
	var ennemis = get_tree().get_nodes_in_group("ennemis")
	if ennemis.is_empty():
		for node in get_tree().root.find_children("*", "CharacterBody2D", true, false):
			if node is ActorBase or node.has_method("subir_degats"):
				ennemis.append(node)
	
	for ennemi in ennemis:
		if is_instance_valid(ennemi):
			if "est_elimine" in ennemi and not ennemi.est_elimine:
				if ennemi.has_method("subir_degats"):
					ennemi.subir_degats(9999)
				elif ennemi.has_method("queue_free"):
					ennemi.queue_free()
	print("[GLOBAL] NUKE DÉCLENCHÉE ! Tous les ennemis éliminés (+", score_bonus, " pts)")

func _consommer_credit() -> void:
	credits_restants -= 1
	credits_modifies.emit(credits_restants)

	if credits_restants <= 0:
		credits_restants = 0
		partie_perdue = true
		partie_terminee.emit(score)
	else:
		# Réapparition immédiate avec une courte invulnérabilité de reprise
		vie_actuelle = vie_max
		_invulnerable_jusqua_msec = Time.get_ticks_msec() + int(DUREE_INVULNERABILITE_SEC * 2000.0)
		vie_modifiee.emit(vie_actuelle, vie_max)

## Déclenche le signal de changement de niveau pour Main.gd
func declencher_changement_niveau(override_prochain: String = "") -> void:
	var prochain = override_prochain
	if prochain.is_empty():
		prochain = obtenir_prochain_niveau(carte_selectionnee)
	if not prochain.is_empty():
		print("[GLOBAL] Demande de changement de niveau vers : ", prochain)
		demande_changement_niveau.emit(prochain)
	else:
		push_warning("[GLOBAL] Aucun niveau suivant trouvé pour : " + str(carte_selectionnee))

## Nettoie les préfixes de chemin pour la comparaison
func normaliser_chemin_niveau(chemin: String) -> String:
	if chemin.begins_with("res://"):
		return chemin.trim_prefix("res://")
	return chemin

## Résout le prochain niveau à charger depuis DICO_NIVEAUX
func obtenir_prochain_niveau(fichier_actuel: String) -> String:
	var clean_actuel = normaliser_chemin_niveau(fichier_actuel)
	for i in range(DICO_NIVEAUX.size()):
		var entree = DICO_NIVEAUX[i]
		var fichier_entree = normaliser_chemin_niveau(entree.get("fichier", ""))
		if fichier_entree == clean_actuel or clean_actuel.ends_with(fichier_entree) or fichier_entree.ends_with(clean_actuel):
			# 1. Vérifier d'abord si "nextmap" est spécifié
			if entree.has("nextmap") and str(entree["nextmap"]) != "":
				var nm = str(entree["nextmap"])
				return nm if nm.begins_with("res://") else "res://" + nm
			# 2. Sinon, prendre le prochain niveau actif dans la séquence
			for j in range(i + 1, DICO_NIVEAUX.size()):
				if DICO_NIVEAUX[j].get("actif", false):
					var nm = str(DICO_NIVEAUX[j]["fichier"])
					return nm if nm.begins_with("res://") else "res://" + nm
			# 3. Fin de la liste de jeu : retour au menu
			return "res://maps/menu_selection.tscn"
	
	# Si la carte actuelle n'a pas été trouvée, renvoyer la première active ou le menu
	for entree in DICO_NIVEAUX:
		if entree.get("actif", false):
			var nm = str(entree["fichier"])
			return nm if nm.begins_with("res://") else "res://" + nm
	return "res://maps/menu_selection.tscn"
