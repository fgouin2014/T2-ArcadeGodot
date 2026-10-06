class_name GoActionPropertySetter extends GoAction
## When triggered, sets the value of a given property on a node.
##
## 

## Node object that owns the property.
@export var target_node:Node
## Name path of the property to set.
@export var property_name:StringName
## Value to set for given property.
@export var value:Variant

func _trigger()->void:
	if target_node:
		target_node.set(property_name,value)
