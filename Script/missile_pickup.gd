class_name MissilePickup
extends PickupItem

## Alias de compatibilité pour l'ancien script dédié aux missiles
func _ready() -> void:
	type_pickup = "Missiles (xpickup_14)"
	super._ready()
