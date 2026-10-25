extends CharacterBody3D
class_name RetroZombie
const SavedState = preload("res://features/prototype/saved_state.gd")

signal defeated(zombie: Node)
@export var stable_id: String = "zombie"
var health: int = 100
var enabled: bool = true
var alerted: bool = false
var attack_left: float = 0.0
var impact_pending: bool = false
var hit_left: float = 0.0
var player: CharacterBody3D
var animation: AnimationPlayer
var navigation: NavigationAgent3D
var target_left: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 7
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.65
	shape_node.shape = shape
	shape_node.position.y = 0.825
	add_child(shape_node)
	var model: Node3D = preload("res://assets/models/retro_prototype/zombie.glb").instantiate()
	add_child(model)
	model.rotation.y = PI
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	navigation = NavigationAgent3D.new()
	navigation.path_desired_distance = 0.35
	navigation.target_desired_distance = 0.9
	navigation.radius = 0.32
	# This level's 0.25m voxel bake places walkable surfaces 0.5m above feet.
	navigation.path_height_offset = 0.5
	add_child(navigation)
	RetroPlayer.play_clip(animation, "Idle")

func sees_player() -> bool:
	if not is_instance_valid(player):
		return false
	var start: Vector3 = global_position + Vector3.UP * 1.3
	var target: Vector3 = player.global_position + Vector3.UP * 1.1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, target, 3, [get_rid()])
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == player

func _physics_process(delta: float) -> void:
	if health <= 0 or not enabled or not is_instance_valid(player):
		return
	hit_left = maxf(hit_left - delta, 0.0)
	var distance: float = global_position.distance_to(player.global_position)
	if distance < 10.0 and sees_player():
		alerted = true
	if attack_left > 0.0:
		attack_left -= delta
		if impact_pending and attack_left < 0.65:
			impact_pending = false
			if distance < 1.55 and sees_player():
				player.take_damage(20)
		velocity.x = 0.0
		velocity.z = 0.0
	elif alerted and hit_left <= 0.0:
		if distance < 1.3 and sees_player():
			attack_left = 1.2
			impact_pending = true
			RetroPlayer.play_clip(animation, "Attack", true)
		else:
			target_left -= delta
			if target_left <= 0.0:
				navigation.target_position = player.global_position
				target_left = 0.25
			var next: Vector3 = navigation.get_next_path_position()
			var direction: Vector3 = (next - global_position)
			direction.y = 0.0
			if direction.length() > 0.05 and not navigation.is_navigation_finished():
				direction = direction.normalized()
				velocity.x = direction.x * 1.15
				velocity.z = direction.z * 1.15
				rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 5.0)
				RetroPlayer.play_clip(animation, "Walk")
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				RetroPlayer.play_clip(animation, "Idle")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= delta * 18.0
	move_and_slide()

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	alerted = true
	impact_pending = false
	attack_left = 0.0
	velocity = Vector3.ZERO
	if health == 0:
		collision_layer = 0
		collision_mask = 0
		RetroPlayer.play_clip(animation, "Death", true)
		defeated.emit(self)
	else:
		hit_left = 0.28
		RetroPlayer.play_clip(animation, "Hit", true)

func snapshot() -> Dictionary:
	return {"health": health, "position": [position.x, position.y, position.z], "yaw": rotation.y, "alerted": alerted}

func restore(data: Dictionary) -> void:
	health = clampi(int(SavedState.number(data.get("health"), 100)), 0, 100)
	position = SavedState.point(data.get("position"), position)
	rotation.y = SavedState.number(data.get("yaw"), 0.0)
	alerted = bool(data.get("alerted", false))
	if health == 0:
		collision_layer = 0
		collision_mask = 0
		RetroPlayer.play_clip(animation, "Death", true)
		if animation != null:
			animation.seek(animation.current_animation_length, true)
			animation.pause()
