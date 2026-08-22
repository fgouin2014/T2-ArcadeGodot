@tool
class_name Spawner2D
extends Node2D

# --- PROPRIÉTÉ EXPORTÉE AVEC MENU DÉROULANT COMPLET ---
@export_enum("xgigend", "xbigend", "xbigend2", "xbigend3", "xmedend", "xmedend2", "xmedend3", "xswat", "xt100", "xtech", "xarnb", "xarng", "xarnm", "xarns", "xbighk", "xendrop", "xendrop2", "xendrop3", "xenfwrd", "xenfwrd2", "xenfwrd3", "xenjump", "xenjump2", "xenjump3", "xethrow", "xfrdfhk", "xmedfwrd", "xmedfwrd2", "xmedfwrd3", "xt100big", "xsarah", "xojc", "xyjc") var type_ennemi: String = "xgigend":
	set(valeur):
		type_ennemi = valeur
		if Engine.is_editor_hint():
			mettre_a_jour_apercu_visuel()

@export var delai_spawn: float = 2.0
@export var actif_au_demarrage: bool = true

# --- OPTIONS DE SENS, ORIENTATION ET VITESSE DE DÉPLACEMENT ---
@export_enum("droite_vers_gauche", "gauche_vers_droite", "immobile") var direction_deplacement: String = "droite_vers_gauche":
	set(valeur):
		direction_deplacement = valeur
		if Engine.is_editor_hint():
			mettre_a_jour_apercu_visuel()
@export var inverser_visuel: bool = false:
	set(valeur):
		inverser_visuel = valeur
		if Engine.is_editor_hint():
			mettre_a_jour_apercu_visuel()
@export var vitesse_deplacement: float = 40.0

# --- OPTIONS DE VAGUES ET RÉPÉTITION ---
@export var repeter_spawn: bool = false
@export var intervalle_repetition: float = 3.0
@export var nombre_max_spawns: int = 0 # 0 = infini / illimité

var apercu_sprite: Sprite2D = null
var compte_spawns: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		mettre_a_jour_apercu_visuel()
	else:
		# En jeu : suppression de l'aperçu d'éditeur et lancement du chrono
		var node_apercu = get_node_or_null("ApercuEditeur")
		if node_apercu:
			node_apercu.queue_free()
		
		if actif_au_demarrage:
			_demarrer_spawn_chrono()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		mettre_a_jour_apercu_visuel()

func _demarrer_spawn_chrono() -> void:
	if not is_inside_tree(): return
	if delai_spawn > 0.0:
		var tree = get_tree()
		if tree:
			await tree.create_timer(delai_spawn, false).timeout
	generer_ennemi()

# --- APERÇU VISUEL DANS L'ÉDITEUR GODOT ---
func mettre_a_jour_apercu_visuel() -> void:
	if not Engine.is_editor_hint(): return
	apercu_sprite = get_node_or_null("ApercuEditeur") as Sprite2D
	if apercu_sprite == null:
		apercu_sprite = Sprite2D.new()
		apercu_sprite.name = "ApercuEditeur"
		apercu_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		apercu_sprite.modulate = Color(1.0, 1.0, 1.0, 0.65) # Semi-transparent dans l'éditeur
		add_child(apercu_sprite)
		
	var type_scene = "xbigend" if type_ennemi in ["xbigend2", "xbigend3"] else ("xenfwrd" if type_ennemi in ["xenfwrd2", "xenfwrd3"] else ("xmedfwrd" if type_ennemi in ["xmedfwrd2", "xmedfwrd3"] else ("xmedend" if type_ennemi in ["xmedend2", "xmedend3"] else ("xendrop" if type_ennemi in ["xendrop2", "xendrop3"] else ("xenjump" if type_ennemi in ["xenjump2", "xenjump3"] else type_ennemi)))))
	var chemin_scene = "res://aseprite/" + type_scene + ".tscn"
	if ResourceLoader.exists(chemin_scene):
		var scene = load(chemin_scene) as PackedScene
		if scene:
			var inst = scene.instantiate()
			var anim = inst.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if anim and anim.sprite_frames:
				var est_ennemi_profil = not (type_ennemi in ["xenfwrd", "xenfwrd2", "xenfwrd3", "xgigend", "xt100big", "xarng", "xbighk", "xfrdfhk", "xendrop", "xenjump", "xethrow"])
				var anim_nom = "idle"

				if est_ennemi_profil and anim.sprite_frames.has_animation("walk"):
					anim_nom = "walk"
				elif est_ennemi_profil and anim.sprite_frames.has_animation("walk_shoot"):
					anim_nom = "walk_shoot"
				elif anim.sprite_frames.has_animation("idle"):
					anim_nom = "idle"
				elif anim.sprite_frames.has_animation("walk_fwrd"):
					anim_nom = "walk_fwrd"
				else:
					var list_anims = anim.sprite_frames.get_animation_names()
					anim_nom = list_anims[0] if list_anims.size() > 0 else ""

				if anim_nom != "" and anim.sprite_frames.get_frame_count(anim_nom) > 0:
					var frame_tex = anim.sprite_frames.get_frame_texture(anim_nom, 0)
					apercu_sprite.texture = frame_tex
					if direction_deplacement == "droite_vers_gauche":
						apercu_sprite.flip_h = inverser_visuel
					else:
						apercu_sprite.flip_h = not inverser_visuel
					apercu_sprite.visible = true
			inst.free()

# --- GÉNÉRATION DE L'ENNEMI EN JEU ---
func generer_ennemi() -> void:
	if not is_inside_tree(): return
	var type_scene = "xbigend" if type_ennemi in ["xbigend2", "xbigend3"] else ("xenfwrd" if type_ennemi in ["xenfwrd2", "xenfwrd3"] else ("xmedfwrd" if type_ennemi in ["xmedfwrd2", "xmedfwrd3"] else ("xmedend" if type_ennemi in ["xmedend2", "xmedend3"] else ("xendrop" if type_ennemi in ["xendrop2", "xendrop3"] else ("xenjump" if type_ennemi in ["xenjump2", "xenjump3"] else type_ennemi)))))
	var chemin_scene = "res://aseprite/" + type_scene + ".tscn"
	if ResourceLoader.exists(chemin_scene):
		var scene = load(chemin_scene) as PackedScene
		if scene:
			var ennemi = scene.instantiate() as Node2D
			ennemi.global_position = global_position
			
			# Configuration de xbigend (le seul qui s'arrête pour tirer : walk -> stop -> idle -> shoot -> walk)
			if type_ennemi == "xbigend":
				if "comportement_bigend" in ennemi:
					ennemi.comportement_bigend = "marche_stop_idle_shoot"
				if "option_comportement" in ennemi:
					ennemi.option_comportement = "marche_stop_idle_shoot"
			elif type_ennemi == "xbigend2":
				# xbigend2 (Attaque 2) : Tir Continu en Marchant avec walk_shoot
				if "comportement_bigend" in ennemi:
					ennemi.comportement_bigend = "marche_et_tir_profil"
				if "option_comportement" in ennemi:
					ennemi.option_comportement = "marche_et_tir_profil"
			elif type_ennemi == "xbigend3":
				# xbigend3 (Attaque 3) : Tir Continu en Marchant avec walk_shoot_profile
				if "comportement_bigend" in ennemi:
					ennemi.comportement_bigend = "marche_et_tir_en_marchant"
				if "option_comportement" in ennemi:
					ennemi.option_comportement = "marche_et_tir_en_marchant"
			elif type_ennemi == "xenfwrd":
				# xenfwrd (Entrée du fond 1x walk_fwrd -> marche_stop_idle_shoot)
				if "comportement_enfwrd" in ennemi:
					ennemi.comportement_enfwrd = "marche_stop_idle_shoot"
				if "option_comportement" in ennemi:
					ennemi.option_comportement = "marche_stop_idle_shoot"
			elif type_ennemi == "xenfwrd2":
				# xenfwrd2 (Entrée du fond 1x walk_fwrd -> marche_et_tir_profil avec walk_shoot)
				if "comportement_enfwrd" in ennemi:
					ennemi.comportement_enfwrd = "marche_et_tir_profil"
				if "option_comportement" in ennemi:
					ennemi.option_comportement = "marche_et_tir_profil"
			elif type_ennemi == "xenfwrd3":
				# xenfwrd3 (Entrée du fond 1x walk_fwrd -> marche_et_tir_en_marchant avec walk_shoot_profile)
				if "comportement_enfwrd" in ennemi:
					ennemi.comportement_enfwrd = "marche_et_tir_en_marchant"
				if "option_comportement" in ennemi:
					ennemi.option_comportement = "marche_et_tir_en_marchant"
			
			# Transmission des options de déplacement et d'orientation
			if "direction_deplacement" in ennemi:
				ennemi.direction_deplacement = direction_deplacement
			if "inverser_visuel" in ennemi:
				ennemi.inverser_visuel = inverser_visuel
			if "vitesse_deplacement" in ennemi:
				ennemi.vitesse_deplacement = vitesse_deplacement
				
			get_parent().add_child(ennemi)
			compte_spawns += 1
			print("[SPAWNER] Ennemi généré (#", compte_spawns, ") : ", type_ennemi, " (Dir: ", direction_deplacement, ", Flip: ", inverser_visuel, ", Vitesse: ", vitesse_deplacement, ") à : ", global_position)
	
	# Gestion de la répétition / vagues d'ennemis
	if repeter_spawn and (nombre_max_spawns <= 0 or compte_spawns < nombre_max_spawns):
		if intervalle_repetition > 0.0:
			var tree = get_tree()
			if tree:
				await tree.create_timer(intervalle_repetition, false).timeout
				if is_inside_tree():
					generer_ennemi()
		else:
			generer_ennemi()
	else:
		queue_free()
