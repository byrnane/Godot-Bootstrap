extends CharacterBody3D
class_name RetroPlayer

signal changed
signal fired(hit: Dictionary)
signal died

const MAGAZINE_SIZE: int = 8
const MAX_RESERVE: int = 64
const SavedState = preload("res://features/prototype/saved_state.gd")
var health: int = 100
var magazine: int = 8
var reserve: int = 24
var third_person: bool = false
var enabled: bool = true
var reloading: bool = false
var reload_left: float = 0.0
var shot_left: float = 0.0
var sensitivity: float = 0.0025
var visual: Node3D
var arms: Node3D
var gun: Node3D
var world_gun: Node3D
var body_animation: AnimationPlayer
var arms_animation: AnimationPlayer
var gun_animation: AnimationPlayer
var muzzle_light: OmniLight3D
@onready var pivot: Node3D = $CameraPivot
@onready var first_camera: Camera3D = $CameraPivot/FirstCamera
@onready var third_camera: Camera3D = $CameraPivot/SpringArm/ThirdCamera

func _ready() -> void:
	visual = _model("player", self)
	if visual != null:
		body_animation = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		world_gun = _model("pistol", visual)
		var skeleton: Skeleton3D = visual.find_child("*", true, false) as Skeleton3D
		for node: Node in visual.find_children("*", "Skeleton3D", true, false):
			skeleton = node as Skeleton3D
		if skeleton != null and world_gun != null:
			var socket: BoneAttachment3D = BoneAttachment3D.new()
			skeleton.add_child(socket)
			for bone_name: String in ["weapon_socket", "hand.R", "Hand.R", "hand_r"]:
				if skeleton.find_bone(bone_name) >= 0:
					socket.bone_name = bone_name
					break
			world_gun.reparent(socket, false)
			# Bone local +Y follows the grip; the exported pistol points along -Z.
			world_gun.rotation.x = PI * 0.5
	arms = _model("arms", first_camera)
	gun = _model("pistol", first_camera)
	if gun != null:
		gun.position = Vector3(0.09, -0.18, -0.46)
		gun_animation = gun.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if arms != null:
		arms_animation = arms.find_child("AnimationPlayer", true, false) as AnimationPlayer
	muzzle_light = OmniLight3D.new()
	first_camera.add_child(muzzle_light)
	muzzle_light.position = Vector3(0.18, -0.15, -0.75)
	muzzle_light.light_color = Color(1.0, 0.68, 0.28)
	muzzle_light.omni_range = 4.0
	muzzle_light.light_energy = 0.0
	$CameraPivot/SpringArm.add_excluded_object(get_rid())
	set_camera_mode(false)

func _model(asset_name: String, parent_node: Node) -> Node3D:
	var path: String = "res://assets/models/retro_prototype/%s.glb" % asset_name
	if not ResourceLoader.exists(path):
		return null
	var result: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	parent_node.add_child(result)
	return result

func active_camera() -> Camera3D:
	return third_camera if third_person else first_camera

func set_camera_mode(value: bool) -> void:
	third_person = value
	first_camera.current = not value
	third_camera.current = value
	if visual != null:
		visual.visible = value
	if arms != null:
		arms.visible = not value
	if gun != null:
		gun.visible = not value
	changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		pivot.rotation.x = clampf(pivot.rotation.x - event.relative.y * sensitivity, -1.2, 1.2)
	elif event.is_action_pressed("proto_view"):
		set_camera_mode(not third_person)
	elif event.is_action_pressed("proto_fire"):
		shoot()
	elif event.is_action_pressed("proto_reload"):
		begin_reload()

func _physics_process(delta: float) -> void:
	shot_left = maxf(shot_left - delta, 0.0)
	if muzzle_light != null:
		muzzle_light.light_energy = 2.5 if shot_left > 0.19 else 0.0
	if not enabled or health <= 0:
		velocity = Vector3.ZERO
		return
	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			var amount: int = mini(MAGAZINE_SIZE - magazine, reserve)
			magazine += amount
			reserve -= amount
			reloading = false
			changed.emit()
	var axis: Vector2 = Input.get_vector("proto_left", "proto_right", "proto_forward", "proto_back")
	var direction: Vector3 = global_basis * Vector3(axis.x, 0.0, axis.y)
	var speed: float = 6.2 if Input.is_action_pressed("proto_sprint") else 3.8
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("proto_jump"):
		velocity.y = 5.5
	move_and_slide()
	if global_position.y < -5.0:
		take_damage(100)
	if not reloading and shot_left <= 0.0:
		play_clip(body_animation, "Walk" if axis.length() > 0.1 else "Idle")
	if not reloading and shot_left <= 0.0:
		play_clip(arms_animation, "Idle")

func ray(from: Vector3, to: Vector3, mask: int = 7) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	query.collide_with_areas = false
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func shoot() -> bool:
	if not enabled or health <= 0 or reloading or shot_left > 0.0:
		return false
	if magazine <= 0:
		begin_reload()
		return false
	magazine -= 1
	shot_left = 0.25
	var camera: Camera3D = active_camera()
	var origin: Vector3 = camera.global_position
	var aim: Vector3 = origin - camera.global_basis.z * 60.0
	var sight_hit: Dictionary = ray(origin, aim)
	if not sight_hit.is_empty():
		aim = sight_hit.position
	# Camera aim chooses a target; the muzzle ray still respects nearby cover.
	var muzzle: Vector3 = global_position + Vector3.UP * 1.35 - global_basis.z * 0.32
	var body_origin: Vector3 = global_position + Vector3.UP * 1.35
	var hit: Dictionary = ray(body_origin, muzzle, 1)
	if hit.is_empty():
		# Start at the safe chest position. A barrel inside a touching capsule
		# must not turn the ray backwards toward the camera's entry hit.
		hit = ray(body_origin, body_origin + (aim - body_origin).normalized() * 60.0)
	if not hit.is_empty() and is_instance_valid(hit.collider) and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(34)
	play_clip(body_animation, "Fire", true)
	play_clip(arms_animation, "Fire", true)
	play_clip(gun_animation, "Fire", true)
	fired.emit(hit)
	changed.emit()
	return true

func begin_reload() -> bool:
	if not enabled or health <= 0 or reloading or magazine >= MAGAZINE_SIZE or reserve <= 0:
		return false
	reloading = true
	reload_left = 2.0
	play_clip(body_animation, "Reload", true)
	play_clip(arms_animation, "Reload", true)
	play_clip(gun_animation, "Reload", true)
	changed.emit()
	return true

func take_damage(amount: int) -> void:
	if health <= 0 or not enabled:
		return
	health = maxi(health - amount, 0)
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.play_sfx(preload("res://assets/sfx/damage.ogg"))
	changed.emit()
	if health == 0:
		reloading = false
		set_camera_mode(true)
		play_clip(body_animation, "Death", true)
		died.emit()

func heal(amount: int) -> bool:
	if health <= 0 or health >= 100:
		return false
	health = mini(health + amount, 100)
	changed.emit()
	return true

func add_ammo(amount: int) -> bool:
	if health <= 0 or reserve >= MAX_RESERVE:
		return false
	reserve = mini(reserve + amount, MAX_RESERVE)
	changed.emit()
	return true

static func play_clip(player: AnimationPlayer, suffix: String, restart: bool = false) -> void:
	if player == null:
		return
	for clip: StringName in player.get_animation_list():
		if String(clip).get_slice("/", String(clip).get_slice_count("/") - 1) == suffix or String(clip).ends_with("_" + suffix):
			if suffix in ["Idle", "Walk"]:
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			if restart or player.current_animation != clip:
				player.play(clip, 0.1)
			return

func snapshot() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "yaw": rotation.y, "pitch": pivot.rotation.x,
		"third_person": third_person, "magazine": magazine, "reserve": reserve}

func restore(data: Dictionary) -> void:
	position = SavedState.point(data.get("position"), position)
	rotation.y = SavedState.number(data.get("yaw"), 0.0)
	pivot.rotation.x = clampf(SavedState.number(data.get("pitch"), 0.0), -1.2, 1.2)
	magazine = clampi(int(SavedState.number(data.get("magazine"), 8)), 0, MAGAZINE_SIZE)
	reserve = clampi(int(SavedState.number(data.get("reserve"), 24)), 0, MAX_RESERVE)
	set_camera_mode(bool(data.get("third_person", false)))
