extends CanvasLayer;

signal pause_requested;
signal resume_requested;
signal settings_requested;
signal back_to_menu_requested;
signal save_requested;

@export var hud_layer_path: NodePath;
@export var modal_layer_path: NodePath;
@export var loading_layer_path: NodePath;
@export var modal_backdrop_path: NodePath;
@export var pause_modal_scene: PackedScene;
@export var settings_modal_scene: PackedScene;
@export var loading_screen_scene: PackedScene;

var _hud_layer: Control = null;
var _modal_layer: Control = null;
var _loading_layer: Control = null;
var _modal_backdrop: Control = null;
var _current_hud: Control = null;
var _pause_modal: PauseModal = null;
var _settings_modal: SettingsModal = null;
var _loading_screen: LoadingScreen = null;
var _modal_stack: Array[Control] = [];

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	_hud_layer = get_node_or_null(hud_layer_path) as Control;
	_modal_layer = get_node_or_null(modal_layer_path) as Control;
	_loading_layer = get_node_or_null(loading_layer_path) as Control;
	_modal_backdrop = get_node_or_null(modal_backdrop_path) as Control;
	if _modal_backdrop != null and not _modal_backdrop.gui_input.is_connected(_on_modal_backdrop_gui_input):
		_modal_backdrop.gui_input.connect(_on_modal_backdrop_gui_input);
	_ensure_loading_screen();
	_ensure_modals();
	_refresh_modal_visibility();

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
	return _current_hud;

func clear_hud() -> void:
	if _current_hud == null:
		return;
	if is_instance_valid(_current_hud):
		_hud_layer.remove_child(_current_hud);
		_current_hud.queue_free();
	_current_hud = null;

func get_current_hud() -> Control:
	return _current_hud;

func show_loading_screen(data: Dictionary = {}) -> void:
	_ensure_loading_screen();
	if _loading_screen == null:
		return;
	await _loading_screen.show_screen(data);

func update_loading_progress(progress: float, status_text: String = "") -> void:
	if _loading_screen == null:
		return;
	_loading_screen.update_progress(progress, status_text);

func hide_loading_screen() -> void:
	if _loading_screen == null:
		return;
	await _loading_screen.hide_screen();

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

func _push_modal(modal: Control) -> void:
	if modal == null:
		return;
	if _modal_stack.has(modal):
		_modal_stack.erase(modal);
	# Re-appending keeps stacking deterministic when one modal opens another.
	_modal_stack.append(modal);
	_refresh_modal_visibility();
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
	_focus_top_modal();

func _refresh_modal_visibility() -> void:
	var has_modals: bool = not _modal_stack.is_empty();
	if _modal_backdrop != null:
		_modal_backdrop.visible = has_modals;
		_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if has_modals else Control.MOUSE_FILTER_IGNORE;
	for modal: Control in [_pause_modal, _settings_modal]:
		if modal == null:
			continue;
		var is_visible: bool = _modal_stack.has(modal);
		modal.visible = is_visible;
		if is_visible:
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
