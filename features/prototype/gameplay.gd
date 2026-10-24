extends Node3D
const SavedState = preload("res://features/prototype/saved_state.gd")

signal pause_requested
signal resume_requested
signal back_to_menu_requested
signal save_requested
signal view_changed(view_model: Dictionary)

@export var level_scene_root_path: NodePath = NodePath("LevelRoot")
@onready var level_root: Node3D = get_node(level_scene_root_path)
var player: RetroPlayer
var enemies: Array[RetroZombie] = []
var pickups: Array[RetroPickup] = []
var outcome: String = ""
var focus_available: bool = true
var wants_capture: bool = true
var interaction: RetroPickup
var room_checkpoint: int = 0
var refresh_left: float = 0.0
var impact: MeshInstance3D
var impact_left: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func get_hud_scene() -> PackedScene:
	return preload("res://features/prototype/hud.tscn")

func bind_hud(hud: Control) -> void:
	view_changed.connect(hud.apply_view_model)
	hud.pause_requested.connect(_pause)
	hud.restart_requested.connect(_restart)
	hud.menu_requested.connect(func() -> void: back_to_menu_requested.emit())
	hud.apply_view_model(_view())

func unbind_hud(hud: Control) -> void:
	if view_changed.is_connected(hud.apply_view_model):
		view_changed.disconnect(hud.apply_view_model)

func on_enter(_payload: SceneTransitionPayload = null) -> void:
	var path: String = Scenes.get_scene_path(SessionContext.current_level_id)
	if path.is_empty():
		path = Scenes.get_scene_path(Scenes.LEVEL_STUB_A)
	var level: Node3D = (load(path) as PackedScene).instantiate()
	level_root.add_child(level)
	AudioManager.play_music(preload("res://assets/music/level_a.mp3"))
	player = level.get_node("Player") as RetroPlayer
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	for node: Node in level.find_children("*", "CharacterBody3D", true, false):
		if node is RetroZombie:
			enemies.append(node)
			node.player = player
			node.defeated.connect(_on_enemy_defeated)
	for node: Node in level.find_children("*", "StaticBody3D", true, false):
		if node is RetroPickup:
			pickups.append(node)
	var data: Dictionary = SessionContext.game_data
	if int(SavedState.number(data.get("prototype_version"), 0)) == 1:
		player.restore(data.get("player", {}) if data.get("player") is Dictionary else {})
		player.health = clampi(SessionContext.player_health, 0, 100)
		var saved_enemies: Dictionary = data.get("enemies", {}) if data.get("enemies") is Dictionary else {}
		for enemy: RetroZombie in enemies:
			if saved_enemies.get(enemy.stable_id) is Dictionary:
				enemy.restore(saved_enemies[enemy.stable_id])
		var consumed: Array = data.get("consumed", []) if data.get("consumed") is Array else []
		for pickup: RetroPickup in pickups:
			if pickup.stable_id in consumed:
				pickup.consume()
		outcome = str(data.get("outcome", ""))
		if outcome not in ["", "dead", "won"]:
			outcome = ""
		room_checkpoint = clampi(int(SavedState.number(data.get("checkpoint"), 0)), 0, 2)
	else:
		player.health = 100
	player.changed.connect(_sync_state)
	player.fired.connect(_on_shot)
	player.died.connect(_on_player_died)
	if player.health == 0:
		outcome = "dead"
	impact = MeshInstance3D.new()
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.045
	ball.height = 0.09
	impact.mesh = ball
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.65, 0.25)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact.material_override = material
	impact.visible = false
	add_child(impact)
	_sync_state(true)
	view_changed.emit(_view())

func on_exit() -> void:
	# AppFlow may already have installed a new/loaded session before this hook.
	# State is synchronized during play and on mutations, never over that handoff.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_available = false
		wants_capture = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focus_available = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	if event.is_action_pressed("ui_pause"):
		_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not wants_capture and _can_play():
		wants_capture = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("proto_interact") and player.enabled:
		interact()

func _can_play() -> bool:
	return outcome.is_empty() and focus_available and AppContext.state == AppState.Value.IN_GAME and not UiShell.has_open_modals() and not SceneRouter.is_loading() and not TransitionManager.is_active()

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var allowed: bool = _can_play()
	player.enabled = allowed and wants_capture
	for enemy: RetroZombie in enemies:
		enemy.enabled = allowed
	var mode: int = Input.MOUSE_MODE_CAPTURED if allowed and wants_capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode and not DisplayServer.get_name() == "headless":
		Input.mouse_mode = mode
	if allowed and not get_tree().paused:
		_sync_state()
		var next_checkpoint: int = 2 if player.position.z < -19.0 else (1 if player.position.z < -9.0 else 0)
		if next_checkpoint > room_checkpoint:
			room_checkpoint = next_checkpoint
			_sync_state()
			AutosaveManager.emit_checkpoint("prototype_room_%d" % next_checkpoint, {})
	interaction = find_interaction() if allowed else null
	impact_left -= delta
	if impact != null:
		impact.visible = impact_left > 0.0
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = 0.1
		view_changed.emit(_view())

func find_interaction() -> RetroPickup:
	var camera: Camera3D = player.active_camera()
	var start: Vector3 = camera.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * 6.0, 9, [player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is RetroPickup:
		return null
	var pickup: RetroPickup = hit.collider as RetroPickup
	if pickup.consumed or player.global_position.distance_to(pickup.global_position) > 2.0:
		return null
	# The third-person camera can see around cover; the player's reach cannot.
	var occlusion: Dictionary = player.ray(player.global_position + Vector3.UP, pickup.global_position + Vector3.UP * 0.15, 1)
	return pickup if occlusion.is_empty() else null

func interact() -> bool:
	var target: RetroPickup = find_interaction()
	if target == null:
		return false
	if target.kind == "exit":
		if living_enemies() > 0:
			return false
		outcome = "won"
		_sync_state()
		AutosaveManager.emit_checkpoint("prototype_complete", {})
		view_changed.emit(_view())
		return true
	var success: bool = target.interact(player)
	if success:
		AudioManager.play_sfx(preload("res://assets/sfx/heal.ogg"))
		_sync_state()
	return success

func living_enemies() -> int:
	var count: int = 0
	for enemy: RetroZombie in enemies:
		if enemy.health > 0:
			count += 1
	return count

func _sync_state(initial_entry: bool = false) -> void:
	if not is_instance_valid(player):
		return
	if not initial_entry and (SceneRouter.current_scene_root != self or SceneRouter.is_loading() or TransitionManager.is_active()):
		return
	var saved_enemies: Dictionary = {}
	for enemy: RetroZombie in enemies:
		saved_enemies[enemy.stable_id] = enemy.snapshot()
	var consumed: Array[String] = []
	for pickup: RetroPickup in pickups:
		if pickup.consumed:
			consumed.append(pickup.stable_id)
	SessionContext.player_health = player.health
	SessionContext.score = (5 - living_enemies()) * 100
	SessionContext.game_data = {"prototype_version": 1, "player": player.snapshot(), "enemies": saved_enemies,
		"consumed": consumed, "outcome": outcome, "checkpoint": room_checkpoint}

func _view() -> Dictionary:
	var result: Dictionary = {"health": 100, "magazine": 8, "reserve": 24, "remaining": 5, "outcome": outcome, "interaction": "", "reloading": false, "captured": wants_capture}
	if is_instance_valid(player):
		result.health = player.health
		result.magazine = player.magazine
		result.reserve = player.reserve
		result.remaining = living_enemies()
		result.reloading = player.reloading
		result.third_person = player.third_person
	if is_instance_valid(interaction):
		result.interaction = interaction.label_key()
		if interaction.kind == "exit" and living_enemies() > 0:
			result.interaction = "P3_EXIT_LOCKED"
	return result

func _pause() -> void:
	if AppContext.state == AppState.Value.PAUSED:
		resume_requested.emit()
	else:
		_sync_state()
		pause_requested.emit()

func _restart() -> void:
	AppFlow.restart_session()

func _on_enemy_defeated(_enemy: Node) -> void:
	_sync_state()
	AudioManager.play_sfx(preload("res://assets/sfx/score.ogg"))

func _on_player_died() -> void:
	outcome = "dead"
	_sync_state()
	view_changed.emit(_view())

func _on_shot(hit: Dictionary) -> void:
	if ResourceLoader.exists("res://assets/sfx/retro_shot.wav"):
		AudioManager.play_sfx(load("res://assets/sfx/retro_shot.wav"))
	if not hit.is_empty():
		impact.position = hit.position
		impact_left = 0.07
