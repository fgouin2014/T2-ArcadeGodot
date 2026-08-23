extends Node

## État global de la session de jeu (autoload "GlobalSettings").
## Contient la carte sélectionnée ainsi que l'état du joueur (vie, crédits, score).

signal vie_modifiee(vie_actuelle: int, vie_max: int)
signal score_modifie(score: int)
signal credits_modifies(credits_restants: int)
signal joueur_touche(degats: int)
signal partie_terminee(score_final: int)

const VIE_MAX_DEFAUT: int = 100
const CREDITS_DEFAUT: int = 3
const DUREE_INVULNERABILITE_SEC: float = 1.0

var carte_selectionnee: String = ""

var vie_max: int = VIE_MAX_DEFAUT
var vie_actuelle: int = VIE_MAX_DEFAUT
var credits_restants: int = CREDITS_DEFAUT
var score: int = 0
var partie_perdue: bool = false

var _invulnerable_jusqua_msec: int = 0

func reinitialiser_partie() -> void:
	vie_max = VIE_MAX_DEFAUT
	vie_actuelle = VIE_MAX_DEFAUT
	credits_restants = CREDITS_DEFAUT
	score = 0
	partie_perdue = false
	_invulnerable_jusqua_msec = 0
	vie_modifiee.emit(vie_actuelle, vie_max)
	credits_modifies.emit(credits_restants)
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
