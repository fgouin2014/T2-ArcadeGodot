@tool
extends EditorScript

func _run() -> void:
	print("--- DEBUT : OPTIMISATION CHIRURGICALE DES POLYGONES ---")
	
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		print("❌ Erreur : Aucune scène n'est ouverte dans l'éditeur !")
		return
		
	var sprite = scene_root.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
	var notifier = scene_root.find_child("VisibleOnScreenNotifier2D", true, false) as VisibleOnScreenNotifier2D
	
	if not sprite:
		print("❌ Erreur : 'AnimatedSprite2D' introuvable dans la scène courante.")
		return

	# Trouver ou créer automatiquement le nœud polygone
	var polygon_node = scene_root.find_child("CollisionPolygon2D", true, false) as CollisionPolygon2D
	if not polygon_node:
		polygon_node = CollisionPolygon2D.new()
		polygon_node.name = "CollisionPolygon2D"
		scene_root.add_child(polygon_node)
		polygon_node.owner = scene_root
		
		# Si un ancien CollisionShape2D basique existe, on le désactive pour éviter les conflits
		var old_collision = scene_root.find_child("CollisionShape2D", true, false) as CollisionShape2D
		if old_collision:
			old_collision.disabled = true
			print("ℹ️ Ancien CollisionShape2D désactivé au profit du polygone.")

	# Traiter l'automatisation des pistes
	generer_pistes_polygone_et_notifier(scene_root, sprite, polygon_node, notifier)
	
	print("✅ Scène mise à jour ! (Faites Ctrl+S dans l'éditeur)")
	print("⚠️ ÉTAPE SUIVANTE : Utilisez l'outil en haut de l'écran 2D pour générer les points du polygone automatiquement sur la Frame 0.")
	print("--- FIN ---")

func generer_pistes_polygone_et_notifier(root: Node, sprite: AnimatedSprite2D, polygon: CollisionPolygon2D, notifier: VisibleOnScreenNotifier2D) -> void:
	var anim_player = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		root.add_child(anim_player)
		anim_player.owner = root

	var lib_name = ""
	if not anim_player.has_animation_library(lib_name):
		anim_player.add_animation_library(lib_name, AnimationLibrary.new())
	var library = anim_player.get_animation_library(lib_name)

	var sprite_frames = sprite.sprite_frames
	if not sprite_frames: return

	# Définir une zone de Notifier par défaut (sera ajustable par frame)
	var rect_notifier_defaut = Rect2(-32, -32, 64, 64)

	for anim_name in sprite_frames.get_animation_names():
		var full_anim_name = anim_name + "_anim"
		var anim : Animation
		
		if library.has_animation(full_anim_name):
			anim = library.get_animation(full_anim_name)
			while anim.get_track_count() > 0:
				anim.remove_track(0)
		else:
			anim = Animation.new()
			library.add_animation(full_anim_name, anim)

		var frame_count = sprite_frames.get_frame_count(anim_name)
		var speed = sprite_frames.get_animation_speed(anim_name)
		var frame_duration = 1.0 / speed
		
		anim.length = frame_count * frame_duration
		anim.step = frame_duration

		# PISTE 1 : Sprite Frame
		var track_sprite = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_sprite, "AnimatedSprite2D:frame")
		anim.value_track_set_update_mode(track_sprite, Animation.UPDATE_DISCRETE)

		# PISTE 2 : Position du Polygone (pour le déplacer si le sprite bouge)
		var track_poly_pos = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_poly_pos, "CollisionPolygon2D:position")
		anim.value_track_set_update_mode(track_poly_pos, Animation.UPDATE_DISCRETE)

		# PISTE 3 & 4 : Notifier (Si présent)
		var track_notif_pos = -1
		var track_notif_rect = -1
		if notifier:
			track_notif_pos = anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track_notif_pos, "VisibleOnScreenNotifier2D:position")
			anim.value_track_set_update_mode(track_notif_pos, Animation.UPDATE_DISCRETE)
			
			track_notif_rect = anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(track_notif_rect, "VisibleOnScreenNotifier2D:rect")
			anim.value_track_set_update_mode(track_notif_rect, Animation.UPDATE_DISCRETE)

		# Génération des clés de base discrètes
		for i in range(frame_count):
			var time_stamp = i * frame_duration
			
			anim.track_insert_key(track_sprite, time_stamp, i)
			anim.track_insert_key(track_poly_pos, time_stamp, Vector2(0, 0))
			
			if notifier:
				anim.track_insert_key(track_notif_pos, time_stamp, Vector2(0, 0))
				anim.track_insert_key(track_notif_rect, time_stamp, rect_notifier_defaut)

		if sprite_frames.get_animation_loop(anim_name):
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE
