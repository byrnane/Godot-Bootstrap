extends Node2D
class_name ForestGame

signal pause_requested
signal resume_requested
signal back_to_menu_requested
signal save_requested
signal view_changed(view_model: Dictionary)

var mode_id: String = "platformer"
var world: Node2D
var _hud: Control
var _pending_autosave: bool = false
var _won: bool = false

func _ready() -> void:
	var background_layer: CanvasLayer = CanvasLayer.new()
	background_layer.layer = -1
	add_child(background_layer)
	var background: TextureRect = TextureRect.new()
	background.texture = ForestArt.texture("forest_panorama")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(background)
	var particles: CPUParticles2D = ForestArt.fireflies(background_layer, get_viewport_rect().size)
	get_viewport().size_changed.connect(func() -> void:
		particles.position = get_viewport_rect().size / 2
		particles.emission_rect_extents = get_viewport_rect().size / 2
	)
	AppContext.state_changed.connect(_on_state_changed)
	InputManager.device_changed.connect(_refresh_view)
	InputManager.bindings_changed.connect(_on_bindings_changed)

func get_hud_scene() -> PackedScene:
	return load("res://features/gameplay/gameplay_hud.tscn")

func bind_hud(hud: Control) -> void:
	_hud = hud
	view_changed.connect(hud.apply_view_model)
	hud.pause_requested.connect(func() -> void: pause_requested.emit())
	hud.retry_requested.connect(retry_checkpoint)
	hud.primary_requested.connect(_on_result_primary)
	hud.menu_requested.connect(func() -> void: back_to_menu_requested.emit())
	_refresh_view()

func unbind_hud(hud: Control) -> void:
	if view_changed.is_connected(hud.apply_view_model):
		view_changed.disconnect(hud.apply_view_model)
	_hud = null

func on_enter(payload: SceneTransitionPayload = null) -> void:
	SessionContext.game_data = ForestData.profile_from_save(SessionContext.to_save_data()) if not SessionContext.is_new_session else ForestData.normalized(SessionContext.game_data, SessionContext.current_level_id)
	mode_id = str(payload.data.get("mode_id", SessionContext.game_data.mode_id)) if payload != null else str(SessionContext.game_data.mode_id)
	if mode_id not in ForestData.MODES:
		mode_id = "platformer"
	var restart: bool = payload != null and bool(payload.data.get("restart_mode", false))
	if restart:
		SessionContext.game_data.progress[mode_id] = ForestData.normalized({}).progress[mode_id]
	var entry: Dictionary = SessionContext.game_data.progress[mode_id]
	var initial: bool = not entry.started or restart
	entry.started = true
	SessionContext.game_data.mode_id = mode_id
	SessionContext.game_data.progress[mode_id] = entry
	_mount_world()
	if initial:
		_commit_checkpoint(entry)
	else:
		_sync_checkpoint_metrics(entry)
	if entry.completed:
		world.finished = true
		_won = true
		_show_result(true)

func _mount_world() -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
	var entry: Dictionary = SessionContext.game_data.progress[mode_id]
	match mode_id:
		"platformer": world = ForestPlatformer.new()
		"shooter": world = ForestShooter.new()
		"puzzle": world = ForestPuzzle.new()
	world.configure(entry)
	world.checkpoint_reached.connect(_commit_checkpoint)
	world.stage_finished.connect(_on_stage_finished)
	world.defeated.connect(_on_defeated)
	world.changed.connect(_refresh_view)
	add_child(world)
	AudioManager.play_music("res://assets/music/level_a.mp3" if mode_id != "shooter" else "res://assets/music/level_b.mp3")
	if _hud != null:
		_hud.hide_result()
	_refresh_view()

func retry_checkpoint() -> void:
	if SceneRouter.is_loading() or AppContext.state != AppState.Value.IN_GAME or UiShell.has_open_modals():
		return
	_mount_world()

func restart_mode() -> void:
	var entry: Dictionary = ForestData.normalized({}).progress[mode_id]
	entry.started = true
	_commit_checkpoint(entry)
	_mount_world()

func _sync_checkpoint_metrics(entry: Dictionary) -> void:
	SessionContext.current_level_id = Scenes.LEVEL_STUB_B if mode_id == "platformer" and int(entry.stage) == 1 else Scenes.LEVEL_STUB_A
	SessionContext.player_health = 3
	SessionContext.score = int(entry.score)

func _commit_checkpoint(entry: Dictionary) -> void:
	SessionContext.game_data.progress[mode_id] = entry.duplicate(true)
	SessionContext.game_data.mode_id = mode_id
	SessionContext.game_data.revision = int(SessionContext.game_data.get("revision", 0)) + 1
	_sync_checkpoint_metrics(entry)
	_pending_autosave = true
	_try_autosave.call_deferred()
	_refresh_view()

func _try_autosave() -> void:
	if not _pending_autosave or AppContext.state != AppState.Value.IN_GAME or SceneRouter.is_loading():
		return
	_pending_autosave = false
	if not AppContext.settings.autosave_enabled or not AppContext.settings.autosave_on_checkpoint:
		return
	var success: bool = AutosaveManager.emit_checkpoint("forest_" + mode_id, {
		"title": tr(ForestData.TITLES[mode_id]),
		"revision": SessionContext.game_data.revision,
	})
	if not success:
		UiFeedback.toast(tr("UI_SAVE_SLOT_TOAST_SAVE_FAILED"), {"variant": "error"})

func _on_state_changed(state: AppState.Value) -> void:
	if state == AppState.Value.IN_GAME:
		_try_autosave.call_deferred()

func _on_bindings_changed(_action_name: StringName) -> void:
	_refresh_view()

func _on_stage_finished() -> void:
	var entry: Dictionary = SessionContext.game_data.progress[mode_id].duplicate(true)
	entry.score = world.score
	entry.checkpoint = 0
	entry.collected = []
	if int(entry.stage) == 2:
		entry.completed = true
	else:
		entry.stage = int(entry.stage) + 1
	_commit_checkpoint(entry)
	_won = true
	AudioManager.play_sfx(preload("res://assets/sfx/heal.ogg"))
	_show_result(true)

func _on_defeated() -> void:
	_won = false
	_show_result(false)

func _show_result(victory: bool) -> void:
	if _hud != null:
		_hud.show_result(victory, bool(SessionContext.game_data.progress[mode_id].completed), world.score)

func _on_result_primary() -> void:
	if _won and bool(SessionContext.game_data.progress[mode_id].completed):
		UiFeedback.confirm(tr("UI_FOREST_CONFIRM_RESTART") % tr(ForestData.TITLES[mode_id]), restart_mode, Callable(), {"title": tr("UI_FOREST_RESTART_MODE"), "confirm_text": tr("UI_FOREST_RESTART_MODE")})
	else:
		retry_checkpoint()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause") or event.is_action_pressed("ui_cancel"):
		if AppContext.state == AppState.Value.PAUSED:
			resume_requested.emit()
		elif AppContext.state == AppState.Value.IN_GAME:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("keeper_retry") and ForestData.input_available():
		retry_checkpoint()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_view()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and AppContext.state == AppState.Value.IN_GAME:
		pause_requested.emit()

func _refresh_view() -> void:
	if world == null or not is_instance_valid(world):
		return
	var metric: String
	match mode_id:
		"platformer": metric = tr("UI_FOREST_SPARKS") % [world.collected.size(), 3]
		"shooter": metric = tr("UI_FOREST_ENEMIES") % world.enemies.size()
		"puzzle": metric = tr("UI_FOREST_PLATES") % [world.occupied_plates(), world.plates.size(), world.moves]
	view_changed.emit({
		"mode_id": mode_id, "stage": world.stage + 1, "health": 0 if mode_id == "puzzle" else world.health,
		"score": world.score, "metric": metric,
		"checkpoint": int(SessionContext.game_data.progress[mode_id].checkpoint),
	})
