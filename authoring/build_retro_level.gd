extends SceneTree

const MODEL_ROOT: String = "res://assets/models/retro_prototype/"
var world: Node3D
var geometry: Node3D
var authoring: Node3D
var index: int = 0
var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	configure_inputs()
	world = Node3D.new()
	world.name = "ServiceBlock"
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	authoring = Node3D.new()
	authoring.name = "RetroCyclopsBlockout"
	var navigation: NavigationRegion3D = NavigationRegion3D.new()
	navigation.name = "Navigation"
	world.add_child(navigation)
	geometry = Node3D.new()
	geometry.name = "Geometry"
	navigation.add_child(geometry)
	wall_material = _material(Color(0.33, 0.35, 0.28), "plaster")
	floor_material = _material(Color(0.24, 0.26, 0.22), "floor")
	# Three rooms, a continuous floor, and two broad open doorways.
	block(Vector3(0, -0.15, -12.5), Vector3(10, 0.3, 34), floor_material)
	block(Vector3(-5.1, 1.6, -12.5), Vector3(0.2, 3.2, 34), wall_material)
	block(Vector3(5.1, 1.6, -12.5), Vector3(0.2, 3.2, 34), wall_material)
	block(Vector3(0, 1.6, 4.5), Vector3(10, 3.2, 0.2), wall_material)
	block(Vector3(0, 1.6, -29.5), Vector3(10, 3.2, 0.2), wall_material)
	for z: float in [-5.0, -16.0]:
		block(Vector3(-3.25, 1.6, z), Vector3(3.5, 3.2, 0.3), wall_material)
		block(Vector3(3.25, 1.6, z), Vector3(3.5, 3.2, 0.3), wall_material)
		block(Vector3(0, 2.85, z), Vector3(3.0, 0.7, 0.3), wall_material)
		var frame: Node3D = model("doorframe", geometry, Vector3(0, 0, z))
		frame.scale.x = 2.5
	# The bounded navigation bake excludes this overhead collider.
	var ceiling: MeshInstance3D = MeshInstance3D.new()
	var ceiling_mesh: BoxMesh = BoxMesh.new()
	ceiling_mesh.size = Vector3(10, 0.15, 34)
	ceiling.mesh = ceiling_mesh
	ceiling.material_override = wall_material
	ceiling.position = Vector3(0, 3.3, -12.5)
	geometry.add_child(ceiling)
	var ceiling_body: StaticBody3D = StaticBody3D.new()
	ceiling.add_child(ceiling_body)
	var ceiling_collision: CollisionShape3D = CollisionShape3D.new()
	var ceiling_shape: BoxShape3D = BoxShape3D.new()
	ceiling_shape.size = ceiling_mesh.size
	ceiling_collision.shape = ceiling_shape
	ceiling_body.add_child(ceiling_collision)
	prop("locker", Vector3(-4.3, 0, 1.5), Vector3(0.65, 1.8, 0.45))
	prop("crate", Vector3(3.3, 0, -2.2), Vector3(0.8, 0.8, 0.8))
	prop("crate", Vector3(-2.3, 0, -10.3), Vector3(0.8, 0.8, 0.8))
	prop("crate", Vector3(-2.3, 0.8, -10.3), Vector3(0.8, 0.8, 0.8))
	prop("crate", Vector3(2.5, 0, -13.5), Vector3(0.8, 0.8, 0.8))
	prop("locker", Vector3(-4.4, 0, -22.0), Vector3(0.65, 1.8, 0.45))
	prop("locker", Vector3(-3.65, 0, -22.0), Vector3(0.65, 1.8, 0.45))
	prop("crate", Vector3(2.7, 0, -24.0), Vector3(0.8, 0.8, 0.8))
	for z: float in [-1.0, -8.0, -12.0, -19.0, -25.0]:
		var pipe: Node3D = model("pipe", geometry, Vector3(4.75, 1.2, z))
		pipe.rotation_degrees.z = 90
		light(Vector3(0, 2.8, z), Color(0.72, 0.84, 0.62) if z > -16.0 else Color(0.95, 0.57, 0.29))
	sign_text("POST 01 / SECURITY", Vector3(0, 2.3, -4.78))
	sign_text("02 / STORAGE", Vector3(0, 2.7, -15.78))
	sign_text("03 / POWER", Vector3(-3.0, 2.45, -29.28))
	sign_text("EXIT", Vector3(0, 2.2, -29.25))
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.055, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.64, 0.5)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.11, 0.14, 0.1)
	environment.fog_density = 0.012
	environment_node.environment = environment
	world.add_child(environment_node)
	var player: Node3D = preload("res://features/prototype/player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector3(0, 0.05, 2.5)
	world.add_child(player)
	var zombie_script: Script = load("res://features/prototype/zombie.gd")
	var locations: Array[Vector3] = [Vector3(-2.0, 0.05, -8.5), Vector3(2.5, 0.05, -12.0), Vector3(-2.5, 0.05, -19.5), Vector3(1, 0.05, -23.5), Vector3(3, 0.05, -26)]
	for i: int in range(locations.size()):
		var zombie: CharacterBody3D = CharacterBody3D.new()
		zombie.set_script(zombie_script)
		zombie.name = "Zombie%d" % (i + 1)
		zombie.stable_id = "zombie_%d" % (i + 1)
		zombie.position = locations[i]
		world.add_child(zombie)
	pickup("ammo_1", "ammo", Vector3(-3.4, 0.65, -6.8))
	pickup("medkit_1", "medkit", Vector3(3.4, 0.65, -7.0))
	pickup("ammo_2", "ammo", Vector3(-3.4, 0.65, -17.8))
	pickup("medkit_2", "medkit", Vector3(3.4, 0.65, -17.8))
	pickup("exit", "exit", Vector3(0, 0, -28.9))
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.filter_baking_aabb = AABB(Vector3(-5.5, -0.5, -30), Vector3(11, 2.8, 35))
	navigation.navigation_mesh = mesh
	await process_frame
	navigation.bake_navigation_mesh(false)
	await process_frame
	print("NAV_POLYGONS ", mesh.get_polygon_count())
	# Runtime-generated children of actors belong to their scripts, not the scene.
	for actor: Node in world.get_children():
		if actor is CharacterBody3D:
			strip_runtime(actor)
	set_owners(world, world)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(world) == OK)
	assert(ResourceSaver.save(packed, "res://features/levels/level_a.tscn") == OK)
	var alias: FileAccess = FileAccess.open("res://features/levels/level_b.tscn", FileAccess.WRITE)
	alias.store_string('[gd_scene load_steps=2 format=3]\n[ext_resource type="PackedScene" path="res://features/levels/level_a.tscn" id="1"]\n[node name="ServiceBlock" instance=ExtResource("1")]\n')
	alias.close()
	set_owners(authoring, authoring)
	var source: PackedScene = PackedScene.new()
	assert(source.pack(authoring) == OK)
	assert(ResourceSaver.save(source, "res://authoring/retro_cyclops_blockout.tscn") == OK)
	print("RETRO_LEVEL_BUILT")
	for source_block: CyclopsBlock in authoring.get_children():
		release_volume(source_block.control_mesh)
		source_block.control_mesh = null
	world.queue_free()
	authoring.free()
	await process_frame
	quit()

func _material(color: Color, texture_name: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var path: String = "res://assets/textures/retro_prototype/%s.png" % texture_name
	if ResourceLoader.exists(path):
		material.albedo_texture = load(path)
		material.albedo_color = Color.WHITE
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
		material.uv1_triplanar = true
	return material

func block(center: Vector3, dimensions: Vector3, material: Material) -> void:
	index += 1
	var volume: ConvexVolume = ConvexVolume.new()
	volume.init_block(AABB(center - dimensions * 0.5, dimensions), Transform2D.IDENTITY, 0)
	var source: CyclopsBlock = CyclopsBlock.new()
	source.name = "Block%d" % index
	source.mesh_vector_data = volume.to_mesh_vector_data()
	source.materials = [material]
	authoring.add_child(source)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Block%d" % index
	body.collision_layer = 1
	body.collision_mask = 7
	geometry.add_child(body)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = volume.create_mesh([material], material)
	body.add_child(visual)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = volume.get_points()
	collision.shape = shape
	body.add_child(collision)
	# Cyclops volume elements hold strong back-references to their container.
	# This one-shot exporter owns that temporary graph and releases it here.
	release_volume(volume)

func release_volume(volume: ConvexVolume) -> void:
	if volume == null:
		return
	for item: Variant in volume.vertices + volume.edges + volume.faces + volume.face_vertices:
		item.mesh = null
	volume.vertices.clear()
	volume.edges.clear()
	volume.faces.clear()
	volume.face_vertices.clear()

func model(asset: String, parent_node: Node, point: Vector3) -> Node3D:
	var result: Node3D = (load(MODEL_ROOT + asset + ".glb") as PackedScene).instantiate()
	parent_node.add_child(result)
	result.position = point
	return result

func prop(asset: String, point: Vector3, dimensions: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = point
	body.collision_layer = 1
	body.collision_mask = 7
	geometry.add_child(body)
	model(asset, body, Vector3.ZERO)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position.y = dimensions.y * 0.5
	body.add_child(collision)

func pickup(id: String, kind: String, point: Vector3) -> void:
	var object: StaticBody3D = StaticBody3D.new()
	object.set_script(load("res://features/prototype/pickup.gd"))
	object.name = id
	object.stable_id = id
	object.kind = kind
	object.position = point
	world.add_child(object)
	var visual: Node3D = model("locker" if kind == "exit" else kind, object, Vector3.ZERO)
	visual.rotation.y = PI
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.55, 0.5, 0.35) if kind != "exit" else Vector3(0.8, 1.8, 0.5)
	collision.position.y = 0.2 if kind != "exit" else 0.8
	collision.shape = shape
	object.add_child(collision)
	if kind != "exit":
		block(point - Vector3(0, 0.35, 0), Vector3(1.0, 0.6, 0.65), wall_material)

func sign_text(value: String, point: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = value
	label.font_size = 64
	label.pixel_size = 0.005
	label.modulate = Color(0.85, 0.83, 0.57)
	label.no_depth_test = false
	label.position = point
	geometry.add_child(label)

func light(point: Vector3, color: Color) -> void:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = point
	lamp.light_color = color
	lamp.light_energy = 1.6
	lamp.omni_range = 8.0
	lamp.shadow_enabled = true
	geometry.add_child(lamp)
	var fixture: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.2, 0.06, 0.24)
	fixture.mesh = mesh
	fixture.position = point + Vector3(0, 0.15, 0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	fixture.material_override = material
	geometry.add_child(fixture)

func set_owners(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		if child.scene_file_path.is_empty():
			set_owners(child, owner_node)

func strip_runtime(node: Node) -> void:
	for child: Node in node.get_children():
		if child.owner == null:
			node.remove_child(child)
			child.queue_free()
		else:
			strip_runtime(child)

func configure_inputs() -> void:
	var actions: Dictionary = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "reload": KEY_R, "interact": KEY_E, "view": KEY_V, "fire": 0}
	var config: GameConfigData = GameConfigData.new()
	for action: String in actions:
		var event: InputEvent
		if action == "fire":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			event = mouse
		else:
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = actions[action]
			event = key
		var name: String = "proto_" + action
		event.device = -1
		ProjectSettings.set_setting("input/" + name, {"deadzone": 0.2, "events": [event]})
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		InputMap.action_add_event(name, event)
		config.input_actions[StringName(name)] = {"label_key": "P3_ACTION_" + action.to_upper(), "group_key": "P3_INPUT_GROUP", "conflict_group": "prototype_" + action}
	ResourceSaver.save(config, "res://core/config/game_config_override.tres")
	ProjectSettings.save()
