extends CanvasLayer;

signal pause_requested;
signal resume_requested;
signal settings_requested;
signal back_to_menu_requested;
signal save_requested;


const DEBUG_LAYER_Z_INDEX: int = 1000;
const DEBUG_OVERLAY_Z_INDEX: int = 1000;


@export var hud_layer_path: NodePath;
@export var modal_layer_path: NodePath;
@export var loading_layer_path: NodePath;
@export var debug_layer_path: NodePath;
@export var modal_backdrop_path: NodePath;
@export var pause_modal_scene: PackedScene;
@export var settings_modal_scene: PackedScene;
@export var loading_screen_scene: PackedScene;
@export var debug_overlay_scene: PackedScene;


var _hud_layer: Control = null;
var _modal_layer: Control = null;
var _loading_layer: Control = null;
var _debug_layer: Control = null;
var _modal_backdrop: Control = null;
var _current_hud: Control = null;
var _pause_modal: PauseModal = null;
var _settings_modal: SettingsModal = null;
var _loading_screen: LoadingScreen = null;
var _debug_overlay: Control = null;
var _modal_stack: Array[Control] = [];
var _debug_refresh_elapsed: float = 0.0;


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	_hud_layer = get_node_or_null(hud_layer_path) as Control;
	_modal_layer = get_node_or_null(modal_layer_path) as Control;
	_loading_layer = get_node_or_null(loading_layer_path) as Control;
	_debug_layer = get_node_or_null(debug_layer_path) as Control;
	if _debug_layer != null:
		_debug_layer.z_as_relative = false;
		_debug_layer.z_index = DEBUG_LAYER_Z_INDEX;
	_modal_backdrop = get_node_or_null(modal_backdrop_path) as Control;
	if _modal_backdrop != null and not _modal_backdrop.gui_input.is_connected(_on_modal_backdrop_gui_input):
		_modal_backdrop.gui_input.connect(_on_modal_backdrop_gui_input);
	_ensure_loading_screen();
	_ensure_debug_overlay();
	_ensure_modals();
	_connect_runtime_signals();
	_sync_debug_overlay_visibility();
	_refresh_debug_overlay();
	_refresh_modal_visibility();


func _process(delta: float) -> void:
	if not AppContext.debug_enabled:
		return;
	_debug_refresh_elapsed += delta;
	if _debug_refresh_elapsed < 0.2:
		return;
	_debug_refresh_elapsed = 0.0;
	_refresh_debug_overlay();


func _input(event: InputEvent) -> void:
	if InputManager != null and InputManager.is_rebinding():
		return;
	if event.is_action_pressed(&"ui_debug_overlay"):
		AppContext.toggle_debug_enabled();
		get_viewport().set_input_as_handled();


func open_settings() -> void:
	_push_modal(_settings_modal);


func close_settings() -> void:
	_pop_modal(_settings_modal);


func open_pause() -> void:
	_push_modal(_pause_modal);


func close_pause() -> void:
	_pop_modal(_pause_modal);


func close_all_modals() -> void:
	for modal: Control in _modal_stack:
		if modal != null and modal.has_method("close_modal"):
			modal.call("close_modal");
	_modal_stack.clear();
	_refresh_modal_visibility();
	_refresh_debug_overlay();


func request_pause() -> void:
	pause_requested.emit();


func request_resume() -> void:
	resume_requested.emit();


func request_settings() -> void:
	settings_requested.emit();


func request_back_to_menu() -> void:
	back_to_menu_requested.emit();


func request_save() -> void:
	save_requested.emit();


func set_hud_scene(hud_scene: PackedScene) -> Control:
	clear_hud();
	if _hud_layer == null or hud_scene == null:
		return null;
	_current_hud = hud_scene.instantiate() as Control;
	if _current_hud == null:
		return null;
	_hud_layer.add_child(_current_hud);
	_current_hud.process_mode = Node.PROCESS_MODE_ALWAYS;
	_refresh_debug_overlay();
	return _current_hud;


func clear_hud() -> void:
	if _current_hud == null:
		return;
	if is_instance_valid(_current_hud):
		_hud_layer.remove_child(_current_hud);
		_current_hud.queue_free();
	_current_hud = null;
	_refresh_debug_overlay();


func get_current_hud() -> Control:
	return _current_hud;


func show_loading_screen(data: Dictionary = {}) -> void:
	_ensure_loading_screen();
	if _loading_screen == null:
		return;
	await _loading_screen.show_screen(data);
	_refresh_debug_overlay();


func update_loading_progress(progress: float, status_text: String = "") -> void:
	if _loading_screen == null:
		return;
	_loading_screen.update_progress(progress, status_text);


func hide_loading_screen() -> void:
	if _loading_screen == null:
		return;
	await _loading_screen.hide_screen();
	_refresh_debug_overlay();


func _ensure_modals() -> void:
	if _modal_layer == null:
		return;
	if pause_modal_scene != null and _pause_modal == null:
		_pause_modal = pause_modal_scene.instantiate() as PauseModal;
		if _pause_modal != null:
			_modal_layer.add_child(_pause_modal);
			_pause_modal.process_mode = Node.PROCESS_MODE_ALWAYS;
			# UiShell forwards modal intent upward and stays ignorant of pause logic.
			_pause_modal.resume_requested.connect(request_resume);
			_pause_modal.save_requested.connect(request_save);
			_pause_modal.settings_requested.connect(open_settings);
			_pause_modal.back_to_menu_requested.connect(request_back_to_menu);
	if settings_modal_scene != null and _settings_modal == null:
		_settings_modal = settings_modal_scene.instantiate() as SettingsModal;
		if _settings_modal != null:
			_modal_layer.add_child(_settings_modal);
			_settings_modal.process_mode = Node.PROCESS_MODE_ALWAYS;
			_settings_modal.close_requested.connect(close_settings);


func _ensure_loading_screen() -> void:
	if _loading_layer == null or loading_screen_scene == null or _loading_screen != null:
		return;
	_loading_screen = loading_screen_scene.instantiate() as LoadingScreen;
	if _loading_screen == null:
		return;
	_loading_layer.add_child(_loading_screen);
	_loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS;


func _ensure_debug_overlay() -> void:
	if _debug_layer == null or debug_overlay_scene == null or _debug_overlay != null:
		return;
	_debug_overlay = debug_overlay_scene.instantiate() as Control;
	if _debug_overlay == null:
		return;
	_debug_layer.add_child(_debug_overlay);
	_debug_overlay.process_mode = Node.PROCESS_MODE_ALWAYS;
	_debug_overlay.z_as_relative = false;
	_debug_overlay.z_index = DEBUG_OVERLAY_Z_INDEX;


func _push_modal(modal: Control) -> void:
	if modal == null:
		return;
	if _modal_stack.has(modal):
		_modal_stack.erase(modal);
	# Re-appending keeps stacking deterministic when one modal opens another.
	_modal_stack.append(modal);
	_refresh_modal_visibility();
	_refresh_debug_overlay();
	_focus_top_modal();
	if modal.has_method("open_modal"):
		modal.call_deferred("open_modal");


func _pop_modal(modal: Control) -> void:
	if modal == null:
		return;
	if _modal_stack.has(modal):
		_modal_stack.erase(modal);
	if modal.has_method("close_modal"):
		modal.call("close_modal");
	_refresh_modal_visibility();
	_refresh_debug_overlay();
	_focus_top_modal();


func _refresh_modal_visibility() -> void:
	var has_modals: bool = not _modal_stack.is_empty();
	if _modal_backdrop != null:
		_modal_backdrop.visible = has_modals;
		_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if has_modals else Control.MOUSE_FILTER_IGNORE;
	for modal: Control in [_pause_modal, _settings_modal]:
		if modal == null:
			continue;
		var modal_is_visible: bool = _modal_stack.has(modal);
		modal.visible = modal_is_visible;
		if modal_is_visible:
			modal.z_index = _modal_stack.find(modal) + 1;


func _focus_top_modal() -> void:
	if _modal_stack.is_empty():
		return;
	var top_modal: Control = _modal_stack.back();
	if top_modal == null:
		return;
	if top_modal.has_method("focus_default_control"):
		top_modal.call_deferred("focus_default_control");


func _request_close_top_modal_from_backdrop() -> void:
	if _modal_stack.is_empty():
		return;
	var top_modal: Control = _modal_stack.back();
	if top_modal == null:
		return;
	if top_modal.has_method("can_close_from_backdrop") and not bool(top_modal.call("can_close_from_backdrop")):
		return;
	if top_modal.has_method("request_close"):
		top_modal.call("request_close");


func _on_modal_backdrop_gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton;
	if mouse_event == null:
		return;
	if not mouse_event.pressed:
		return;
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return;
	_request_close_top_modal_from_backdrop();


func _connect_runtime_signals() -> void:
	if not AppContext.state_changed.is_connected(_on_app_state_changed):
		AppContext.state_changed.connect(_on_app_state_changed);
	if not AppContext.debug_enabled_changed.is_connected(_on_debug_enabled_changed):
		AppContext.debug_enabled_changed.connect(_on_debug_enabled_changed);
	if not SceneRouter.scene_changed.is_connected(_on_scene_changed):
		SceneRouter.scene_changed.connect(_on_scene_changed);
	if not SceneRouter.scene_load_started.is_connected(_on_scene_load_started):
		SceneRouter.scene_load_started.connect(_on_scene_load_started);
	if not SceneRouter.scene_load_failed.is_connected(_on_scene_load_failed):
		SceneRouter.scene_load_failed.connect(_on_scene_load_failed);


func _sync_debug_overlay_visibility() -> void:
	if _debug_overlay == null:
		return;
	if AppContext.debug_enabled:
		_debug_overlay.show_overlay();
	else:
		_debug_overlay.hide_overlay();


func _refresh_debug_overlay() -> void:
	if _debug_overlay == null:
		return;
	var hud_name: String = "-";
	if _current_hud != null:
		hud_name = _current_hud.name;
	var modal_names: Array[String] = [];
	for modal: Control in _modal_stack:
		if modal == null:
			continue;
		modal_names.append(modal.name);
	_debug_overlay.apply_snapshot({
		"app_state": AppContext.state,
		"scene_id": String(SceneRouter.current_scene_id),
		"tree_paused": get_tree().paused,
		"is_loading": SceneRouter.is_loading(),
		"hud_name": hud_name,
		"modal_names": ", ".join(modal_names) if not modal_names.is_empty() else "-",
		"debug_enabled": AppContext.debug_enabled,
	});


func _on_app_state_changed(_new_state: AppState.Value) -> void:
	_refresh_debug_overlay();


func _on_debug_enabled_changed(_is_enabled: bool) -> void:
	_debug_refresh_elapsed = 0.0;
	_sync_debug_overlay_visibility();
	_refresh_debug_overlay();


func _on_scene_changed(_scene_id: StringName, _scene_root: Node) -> void:
	_refresh_debug_overlay();


func _on_scene_load_started(_scene_id: StringName) -> void:
	_refresh_debug_overlay();


func _on_scene_load_failed(_scene_id: StringName, _error_text: String) -> void:
	_refresh_debug_overlay();
