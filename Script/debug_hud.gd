extends CanvasLayer

## Système de Debug HUD pour afficher les logs en jeu
## Labels positionnés:
## - Haut-gauche: xjug
## - Haut-droit: xcopter
## - Bas-droit: xsvan
## - Bas-gauche: gauge de vie

signal debug_setting_changed(log_type: String, enabled: bool)

# Références aux labels
@onready var label_jug: Label = $LabelJug
@onready var label_copter: Label = $LabelCopter
@onready var label_van: Label = $LabelVan
@onready var label_health: Label = $LabelHealth

# État des logs
var jug_log_enabled: bool = true
var copter_log_enabled: bool = true
var van_log_enabled: bool = true
var health_log_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	configurer_labels()

func configurer_labels() -> void:
	if label_jug:
		label_jug.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label_jug.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label_jug.modulate = Color.CYAN
		label_jug.visible = jug_log_enabled
		
	if label_copter:
		label_copter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_copter.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label_copter.modulate = Color.YELLOW
		label_copter.visible = copter_log_enabled
		
	if label_van:
		label_van.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label_van.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label_van.modulate = Color.LIME
		label_van.visible = van_log_enabled

	if label_health:
		label_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label_health.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label_health.modulate = Color.RED
		label_health.visible = health_log_enabled

func set_jug_log(text: String) -> void:
	if label_jug and jug_log_enabled:
		label_jug.text = "[JUG] " + text
		if visible:
			print("[DebugHUD] Jug log: ", text)

func set_copter_log(text: String) -> void:
	if label_copter and copter_log_enabled:
		label_copter.text = "[COPTER] " + text
		if visible:
			print("[DebugHUD] Copter log: ", text)

func set_van_log(text: String) -> void:
	if label_van and van_log_enabled:
		label_van.text = "[VAN] " + text
		if visible:
			print("[DebugHUD] Van log: ", text)

func set_health_log(text: String) -> void:
	if label_health and health_log_enabled:
		label_health.text = "[HEALTH] " + text
		if visible:
			print("[DebugHUD] Health log: ", text)

func toggle_jug_log(enabled: bool) -> void:
	jug_log_enabled = enabled
	if label_jug:
		label_jug.visible = enabled
	debug_setting_changed.emit("jug", enabled)

func toggle_copter_log(enabled: bool) -> void:
	copter_log_enabled = enabled
	if label_copter:
		label_copter.visible = enabled
	debug_setting_changed.emit("copter", enabled)

func toggle_van_log(enabled: bool) -> void:
	van_log_enabled = enabled
	if label_van:
		label_van.visible = enabled
	debug_setting_changed.emit("van", enabled)

func toggle_health_log(enabled: bool) -> void:
	health_log_enabled = enabled
	if label_health:
		label_health.visible = enabled
	debug_setting_changed.emit("health", enabled)

func toggle_debug_hud(enabled: bool) -> void:
	visible = enabled
