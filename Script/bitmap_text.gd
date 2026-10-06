@tool
class_name BitmapText
extends Control

@export_dir var font_folder: String = "res://images/fonts/xfonts_blue"
@export var glyph_modulate: Color = Color.WHITE:
	set(value):
		glyph_modulate = value
		if is_inside_tree():
			_rebuild()
@export var pixel_scale: float = 1.0:
	set(value):
		pixel_scale = max(value, 0.1)
		if is_inside_tree():
			_rebuild()

@export_enum("gauche", "centre", "droite") var alignement: String = "centre":
	set(value):
		alignement = value
		if is_inside_tree():
			_rebuild()
@export var espacement_lignes_px: float = 2.0:
	set(value):
		espacement_lignes_px = value
		if is_inside_tree():
			_rebuild()

var _text_value: String = ""

func set_text(value: String) -> void:
	# Remplacer les séquences littérales \n ou \r\n par de vrais sauts de ligne
	_text_value = value.replace("\\n", "\n").replace("\r", "")
	_rebuild()

func _ready() -> void:
	_text_value = _text_value.replace("\\n", "\n").replace("\r", "")
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	if _text_value.is_empty():
		size = Vector2.ZERO
		return

	# Découpage du texte en lignes (support \n et paragraphes \n\n)
	var texte_propre = _text_value.replace("\\n", "\n").replace("\r", "")
	var lignes_raw = texte_propre.split("\n")
	var donnees_lignes: Array[Dictionary] = []
	var largeur_max_totale := 0.0
	var hauteur_ligne_defaut := 12.0 * pixel_scale

	# 1. Calcul préliminaire de chaque ligne
	for ligne in lignes_raw:
		var items_ligne: Array[Dictionary] = []
		var larg_ligne := 0.0
		var haut_ligne := hauteur_ligne_defaut

		for character in ligne:
			if character == "\r" or character == "\n" or character == "\t":
				continue
			var texture = _load_character_texture(character)
			if texture == null:
				if character == " ":
					var espace_larg = 4.0 * pixel_scale
					items_ligne.append({"texture": null, "size": Vector2(espace_larg, haut_ligne)})
					larg_ligne += espace_larg
				continue

			var glyph_sz = texture.get_size() * pixel_scale
			items_ligne.append({"texture": texture, "size": glyph_sz})
			larg_ligne += glyph_sz.x
			haut_ligne = max(haut_ligne, glyph_sz.y)

		donnees_lignes.append({
			"items": items_ligne,
			"largeur": larg_ligne,
			"hauteur": haut_ligne
		})
		largeur_max_totale = max(largeur_max_totale, larg_ligne)

	# 2. Positionnement des glyphes avec gestion de l'alignement
	var curseur_y := 0.0
	for d in donnees_lignes:
		var items: Array[Dictionary] = d["items"]
		var larg: float = d["largeur"]
		var haut: float = d["hauteur"]

		var decalage_x := 0.0
		match alignement:
			"centre":
				decalage_x = (largeur_max_totale - larg) / 2.0
			"droite":
				decalage_x = largeur_max_totale - larg
			_:
				decalage_x = 0.0

		var curseur_x = decalage_x
		for item in items:
			var tex: Texture2D = item["texture"]
			var sz: Vector2 = item["size"]
			if tex != null:
				var glyph := TextureRect.new()
				glyph.texture = tex
				glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				glyph.modulate = glyph_modulate
				glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				glyph.stretch_mode = TextureRect.STRETCH_SCALE
				glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
				glyph.position = Vector2(curseur_x, curseur_y)
				glyph.size = sz
				add_child(glyph)
			curseur_x += sz.x

		curseur_y += haut + (espacement_lignes_px * pixel_scale)

	size = Vector2(largeur_max_totale, max(0.0, curseur_y - (espacement_lignes_px * pixel_scale)))

func _load_character_texture(character: String) -> Texture2D:
	if ResourceLoader.exists(font_folder.path_join("xfonts2_33.png")):
		return _load_indexed_texture_xfonts2(character)

	var file_name := ""
	if character == " ":
		file_name = "space.png"
	elif character in [":", ",", "-", ".", "'"]:
		file_name = {
			":": "colon.png",
			",": "comma.png",
			"-": "dash.png",
			".": "period.png",
			"'": "apostrophe.png"
		}[character]
	else:
		file_name = character.to_upper() + ".png"

	var path := font_folder.path_join(file_name)
	if not ResourceLoader.exists(path):
		path = font_folder.path_join("blank.png")
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _load_indexed_texture_xfonts2(character: String) -> Texture2D:
	var index := -1
	if character == "'":
		index = 7
	elif character == ",":
		index = 12
	elif character == "-":
		index = 13
	elif character == ".":
		index = 14
	elif character >= "0" and character <= "9":
		index = 16 + int(character)
	elif character == ":":
		index = 26
	elif character == "_":
		index = 29
	elif "ABCDEFGHIJKLMNOPQRSTUVWXYZ".find(character.to_upper()) >= 0:
		index = 33 + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".find(character.to_upper())
	else:
		var blank_path := font_folder.path_join("blank.png")
		return load(blank_path) as Texture2D if ResourceLoader.exists(blank_path) else null

	var path := font_folder.path_join("xfonts2_%02d.png" % index)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
