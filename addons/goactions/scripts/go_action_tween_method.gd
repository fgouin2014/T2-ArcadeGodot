@tool
@icon("res://addons/goactions/icons/go_action_tween.svg")
class_name GoActionTweenMethod extends GoAction
## Tweens the method of the [member target_node] when
## [code]trigger()[/code] is called.
##
## If [code]trigger()[/code] is called before the tween operation
## is finished, initial tween operation is cancelled and a new 
## one is started.

## Target node whose property will be tweened. 
@export var target_node:Node:
	set(val):
		if _tween and _tween.is_valid():
			return
		target_node = val
## Path to the property to tween. 
@export var method:String:
	set(val):
		if _tween and _tween.is_valid():
			return
		method = val
## Starting value desired for the tween operation.
@export var from:Variant:
	set(val):
		if _tween and _tween.is_valid():
			return
		from = val
## Final value desired for the tween operation.
@export var to:Variant:
	set(val):
		if _tween and _tween.is_valid():
			return
		to = val
## Duration of the tween operation in seconds.
@export var duration:float = 1.0:
	set(val):
		if _tween and _tween.is_valid():
			return
		duration = val
## [enum Tween.TransType] for the tween operation. 
@export var trans:Tween.TransitionType:
	set(val):
		if _tween and _tween.is_valid():
			return
		trans = val
## [enum Tween.EaseType] for the tween operation. 
@export var ease:Tween.EaseType:
	set(val):
		if _tween and _tween.is_valid():
			return
		ease = val
## If true, the initial value of the target property
## will be restored after the tween operation ends.
@export var restore_initial_value:bool = true:
	set(val):
		if _tween and _tween.is_valid():
			return
		restore_initial_value = val

var _tween:Tween

func _trigger()->void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = get_tree().create_tween()
	_tween.bind_node(target_node)
	_tween.tween_method(Callable(target_node,method),
		from,
		to,
		duration
	).set_trans(trans).set_ease(ease)
	while _tween.is_valid():
		await get_tree().physics_frame
	
