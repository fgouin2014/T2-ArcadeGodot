class_name EnfwrdEnemy
extends WalkingEnemy

## Script spécialisé pour l'endosquelette XENFWRD (Sol 1).
## Gère une hitbox dynamique qui s'adapte à l'animation courante :
##   - vue de dos (walk_fwrd)       → hitbox étroite  34×82
##   - vue de face (idle, shoot)    → hitbox moyenne  36×88
##   - profil/marche (walk, etc.)   → hitbox large    76×88

@export_enum(
	"marche_stop_idle_shoot",
	"marche_et_tir_profil",
	"marche_et_tir_en_marchant",
	"marche_tir_face"
) var comportement_enfwrd: String = "marche_stop_idle_shoot"

# Dimensions de hitbox par groupe d'animation (mesurées depuis le spritesheet)
const HITBOX_DOS     := Vector2(34, 82)   # walk_fwrd — vue de dos, personnage sortant du fond
const HITBOX_FACE    := Vector2(36, 88)   # idle, shoot — vue de face pleine hauteur
const HITBOX_PROFIL  := Vector2(76, 88)   # walk, walk_shoot, walk_shoot_profile — déplacement latéral

# Décalage vertical léger pour la vue de dos (contenu commence à Y=6 dans le frame)
const OFFSET_DOS := Vector2(0, 3)
const OFFSET_STD := Vector2(0, 0)

var _collision_shape: CollisionShape2D
var _sprite: AnimatedSprite2D

func _ready() -> void:
	super._ready()
	_collision_shape = $CollisionShape2D
	_sprite = $AnimatedSprite2D
	if is_instance_valid(_sprite):
		_sprite.animation_changed.connect(_on_animation_changed)
	_mettre_a_jour_hitbox()

func _on_animation_changed() -> void:
	_mettre_a_jour_hitbox()

## Met à jour la taille de la CollisionShape2D selon l'animation active.
func _mettre_a_jour_hitbox() -> void:
	if not is_instance_valid(_collision_shape):
		return
	var shape: Shape2D = _collision_shape.shape
	if not shape is RectangleShape2D:
		return

	var anim: String = str(_sprite.animation) if is_instance_valid(_sprite) else ""

	match anim:
		"walk_fwrd":
			shape.size = HITBOX_DOS
			_collision_shape.position = OFFSET_DOS
		"idle", "shoot":
			shape.size = HITBOX_FACE
			_collision_shape.position = OFFSET_STD
		"walk", "walk_shoot", "walk_shoot_profile":
			shape.size = HITBOX_PROFIL
			_collision_shape.position = OFFSET_STD
		_:
			# die et toute autre animation → taille de face par défaut
			shape.size = HITBOX_FACE
			_collision_shape.position = OFFSET_STD

func activer_acteur() -> void:
	var nom_node = name.to_lower()
	if "xenfwrd3" in nom_node:
		option_comportement = "marche_et_tir_en_marchant"
	elif "xenfwrd2" in nom_node:
		option_comportement = "marche_et_tir_profil"
	elif "xenfwrd" in nom_node and not ("xenfwrd2" in nom_node or "xenfwrd3" in nom_node):
		option_comportement = "marche_stop_idle_shoot"
	elif option_comportement == "" or option_comportement == null:
		option_comportement = comportement_enfwrd

	super.activer_acteur()
