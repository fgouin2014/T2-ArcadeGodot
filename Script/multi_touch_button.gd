extends Button
class_name MultiTouchButton

## Bouton tactile avec gestion native du Multi-Touch (Android / Mobile).
## Permet des appuis simultanés avec le Joystick virtuel et d'autres boutons.

signal touched_down()
signal touched_up()
signal touched_pressed()

@export var action_name: StringName = ""
@export var haptic_feedback: bool = true
@export var haptic_duration_ms: int = 25
@export var pressed_modulate: Color = Color(0.75, 0.75, 0.75, 1.0)

var _touch_index: int = -1
var _is_down: bool = false
var _default_modulate: Color = Color.WHITE

func _ready() -> void:
	_default_modulate = self_modulate
	# Désactiver le focus pour éviter le vol de focus clavier/UI
	focus_mode = Control.FOCUS_NONE

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if _is_down:
			_release_button(false)
		return

	# --- 1. GESTION DES TOUCHES TACTILES MOBILES (MULTI-TOUCH) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			# Si aucun doigt n'est sur ce bouton et que le point est dans notre rectangle
			if _touch_index == -1 and get_global_rect().has_point(event.position):
				_press_button(event.index)
		elif event.index == _touch_index:
			var inside = get_global_rect().has_point(event.position)
			_release_button(inside)

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			# On peut ajuster le feedback si le doigt glisse hors du bouton
			pass

	# --- 2. GESTION DE LA SOURIS (TEST SUR PC / DESKTOP) ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _touch_index == -1 and get_global_rect().has_point(event.position):
					_press_button(-2) # -2 = identifiant pour la souris
			elif _touch_index == -2:
				var inside = get_global_rect().has_point(event.position)
				_release_button(inside)

func _press_button(touch_idx: int) -> void:
	_touch_index = touch_idx
	_is_down = true
	self_modulate = pressed_modulate
	
	if haptic_feedback:
		Input.vibrate_handheld(haptic_duration_ms)
		
	if action_name != "":
		Input.action_press(action_name)
		
	touched_down.emit()

func _release_button(was_inside: bool) -> void:
	_touch_index = -1
	_is_down = false
	self_modulate = _default_modulate
	
	if action_name != "":
		Input.action_release(action_name)
		
	touched_up.emit()
	if was_inside:
		touched_pressed.emit()

func _exit_tree() -> void:
	if _is_down:
		_release_button(false)
