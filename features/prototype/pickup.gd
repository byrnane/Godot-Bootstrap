extends StaticBody3D
class_name RetroPickup

@export var stable_id: String = "pickup"
@export_enum("medkit", "ammo", "exit") var kind: String = "ammo"
var consumed: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0

func label_key() -> String:
	return "P3_INTERACT_" + kind.to_upper()

func interact(player: RetroPlayer) -> bool:
	if consumed:
		return false
	var success: bool = player.heal(35) if kind == "medkit" else player.add_ammo(16)
	if kind == "exit":
		return false
	if success:
		consume()
	return success

func consume() -> void:
	consumed = true
	visible = false
	collision_layer = 0
