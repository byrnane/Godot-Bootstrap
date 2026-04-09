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
@export var toast_stack_path: NodePath;
@export var modal_backdrop_path: NodePath;
@export var pause_modal_scene: PackedScene;
@export var settings_modal_scene: PackedScene;
@export var feedback_modal_scene: PackedScene;
@export var loading_screen_scene: PackedScene;
@export var debug_overlay_scene: PackedScene;
@export var toast_item_scene: PackedScene;


var _hud_layer: Control = null;
var _modal_layer: Control = null;
var _loading_layer: Control = null;
var _debug_layer: Control = null;
var _toast_stack: VBoxContainer = null;
var _modal_backdrop: Control = null;
var _current_hud: Control = null;
var _pause_modal: PauseModal = null;
var _settings_modal: SettingsModal = null;
var _feedback_modal: FeedbackModal = null;
var _loading_screen: LoadingScreen = null;
var _debug_overlay: Control = null;
var _modal_stack: Array[Control] = [];
var _feedback_queue: Array[Dictionary] = [];
var _queued_feedback_request_ids: Dictionary = {};
var _active_feedback_kind: StringName = &"";
var _active_feedback_request_id: int = -1;
var _debug_refresh_elapsed: float = 0.0;
var _reported_setup_issues: Dictionary = {};
var _loading_visible: bool = false;
var _loading_transition_active: bool = false;
var _loading_request_token: int = 0;


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	_hud_layer = get_node_or_null(hud_layer_path) as Control;
	_modal_layer = get_node_or_null(modal_layer_path) as Control;
	_loading_layer = get_node_or_null(loading_layer_path) as Control;
	_debug_layer = get_node_or_null(debug_layer_path) as Control;
	_toast_stack = get_node_or_null(toast_stack_path) as VBoxContainer;
	if _debug_layer != null:
		_debug_layer.z_as_relative = false;
		_debug_layer.z_index = DEBUG_LAYER_Z_INDEX;
	_modal_backdrop = get_node_or_null(modal_backdrop_path) as Control;
	_validate_shell_setup();
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
	_compact_modal_stack();
	for modal: Control in _modal_stack:
		if modal != null and modal.has_method("close_modal"):
			modal.call("close_modal");
	_modal_stack.clear();
	_cancel_active_feedback_request();
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
	_loading_request_token += 1;
	var request_token: int = _loading_request_token;
	if _loading_visible and not _loading_transition_active:
		_refresh_debug_overlay();
		return;
	if _loading_transition_active:
		await _wait_for_loading_transition();
	if request_token != _loading_request_token:
		return;
	if _loading_visible:
		_refresh_debug_overlay();
		return;
	_loading_transition_active = true;
	await _loading_screen.show_screen(data);
	_loading_transition_active = false;
	_loading_visible = true;
	_refresh_debug_overlay();


func update_loading_progress(progress: float, status_text: String = "") -> void:
	if _loading_screen == null:
		return;
	if not _loading_visible and not _loading_transition_active:
		return;
	_loading_screen.update_progress(progress, status_text);


func hide_loading_screen() -> void:
	if _loading_screen == null:
		return;
	_loading_request_token += 1;
	var request_token: int = _loading_request_token;
	if not _loading_visible and not _loading_transition_active:
		_refresh_debug_overlay();
		return;
	if _loading_transition_active:
		await _wait_for_loading_transition();
	if request_token != _loading_request_token:
		return;
	if not _loading_visible:
		_refresh_debug_overlay();
		return;
	_loading_transition_active = true;
	await _loading_screen.hide_screen();
	_loading_transition_active = false;
	_loading_visible = false;
	_refresh_debug_overlay();


func _ensure_modals() -> void:
	if _modal_layer == null:
		_warn_setup_issue("modal_layer_missing", "modal_layer_path is not configured or points to a missing node");
		return;
	if pause_modal_scene != null and _pause_modal == null:
		_pause_modal = pause_modal_scene.instantiate() as PauseModal;
		if _pause_modal != null:
			_modal_layer.add_child(_pause_modal);
			_pause_modal.process_mode = Node.PROCESS_MODE_ALWAYS;
			_bind_modal_lifecycle(_pause_modal);
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
			_bind_modal_lifecycle(_settings_modal);
			_settings_modal.close_requested.connect(close_settings);
	if feedback_modal_scene != null and _feedback_modal == null:
		_feedback_modal = feedback_modal_scene.instantiate() as FeedbackModal;
		if _feedback_modal != null:
			_modal_layer.add_child(_feedback_modal);
			_feedback_modal.process_mode = Node.PROCESS_MODE_ALWAYS;
			_bind_modal_lifecycle(_feedback_modal);
			_feedback_modal.confirmed.connect(_on_feedback_confirmed);
			_feedback_modal.canceled.connect(_on_feedback_canceled);
	if pause_modal_scene == null:
		_warn_setup_issue("pause_modal_scene_missing", "pause_modal_scene is not assigned");
	if settings_modal_scene == null:
		_warn_setup_issue("settings_modal_scene_missing", "settings_modal_scene is not assigned");
	if feedback_modal_scene == null:
		_warn_setup_issue("feedback_modal_scene_missing", "feedback_modal_scene is not assigned");


func _ensure_loading_screen() -> void:
	if _loading_layer == null:
		_warn_setup_issue("loading_layer_missing", "loading_layer_path is not configured or points to a missing node");
		return;
	if loading_screen_scene == null:
		_warn_setup_issue("loading_screen_scene_missing", "loading_screen_scene is not assigned");
		return;
	if _loading_screen != null:
		return;
	_loading_screen = loading_screen_scene.instantiate() as LoadingScreen;
	if _loading_screen == null:
		return;
	_loading_layer.add_child(_loading_screen);
	_loading_screen.process_mode = Node.PROCESS_MODE_ALWAYS;


func _ensure_debug_overlay() -> void:
	if _debug_layer == null:
		_warn_setup_issue("debug_layer_missing", "debug_layer_path is not configured or points to a missing node");
		return;
	if debug_overlay_scene == null:
		_warn_setup_issue("debug_overlay_scene_missing", "debug_overlay_scene is not assigned");
		return;
	if _debug_overlay != null:
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
	_compact_modal_stack();
	if _modal_stack.has(modal):
		_modal_stack.erase(modal);
	# Re-appending keeps stacking deterministic when one modal opens another.
	_modal_stack.append(modal);
	_refresh_modal_visibility();
	_refresh_debug_overlay();
	if modal.has_method("open_modal"):
		modal.call_deferred("open_modal");


func _pop_modal(modal: Control) -> void:
	if modal == null:
		return;
	_compact_modal_stack();
	if _modal_stack.has(modal):
		_modal_stack.erase(modal);
	if modal.has_method("close_modal"):
		modal.call("close_modal");
	_refresh_modal_visibility();
	_refresh_debug_overlay();


func _refresh_modal_visibility() -> void:
	_compact_modal_stack();
	var top_modal: Control = _modal_stack.back() if not _modal_stack.is_empty() else null;
	var has_visible_modals: bool = false;
	for modal: Control in _get_managed_modals():
		if modal == null:
			continue;
		var is_stacked: bool = _modal_stack.has(modal);
		var is_top_modal: bool = modal == top_modal;
		if modal.visible or is_stacked:
			has_visible_modals = true;
		modal.mouse_filter = Control.MOUSE_FILTER_STOP if is_top_modal else Control.MOUSE_FILTER_IGNORE;
		modal.set_process_unhandled_input(is_top_modal);
		modal.z_index = _modal_stack.find(modal) + 1 if is_stacked else 0;

	if _modal_backdrop != null:
		_modal_backdrop.visible = has_visible_modals;
		_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if has_visible_modals else Control.MOUSE_FILTER_IGNORE;


func _focus_top_modal() -> void:
	_compact_modal_stack();
	if _modal_stack.is_empty():
		return;
	var top_modal: Control = _modal_stack.back();
	if top_modal == null:
		return;
	if top_modal.has_method("focus_default_control"):
		top_modal.call_deferred("focus_default_control");


func _request_close_top_modal_from_backdrop() -> void:
	_compact_modal_stack();
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
	if UiFeedback != null:
		if not UiFeedback.confirm_requested.is_connected(_on_confirm_requested):
			UiFeedback.confirm_requested.connect(_on_confirm_requested);
		if not UiFeedback.alert_requested.is_connected(_on_alert_requested):
			UiFeedback.alert_requested.connect(_on_alert_requested);
		if not UiFeedback.toast_requested.is_connected(_on_toast_requested):
			UiFeedback.toast_requested.connect(_on_toast_requested);


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
	_compact_modal_stack();
	var hud_name: String = "-";
	if _current_hud != null:
		hud_name = _current_hud.name;
	var modal_names: Array[String] = [];
	for modal: Control in _modal_stack:
		if modal == null:
			continue;
		if not is_instance_valid(modal):
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


func _get_managed_modals() -> Array[Control]:
	var modals: Array[Control] = [];
	for modal: Control in [_pause_modal, _settings_modal, _feedback_modal]:
		if modal != null:
			modals.append(modal);
	return modals;


func _on_confirm_requested(request_id: int, payload: Dictionary) -> void:
	_enqueue_feedback_request(&"confirm", request_id, payload);
	_try_show_next_feedback();


func _on_alert_requested(request_id: int, payload: Dictionary) -> void:
	_enqueue_feedback_request(&"alert", request_id, payload);
	_try_show_next_feedback();


func _on_toast_requested(payload: Dictionary) -> void:
	if _toast_stack == null or toast_item_scene == null:
		return;

	var toast_item: Control = toast_item_scene.instantiate() as Control;
	if toast_item == null:
		return;

	_toast_stack.add_child(toast_item);
	toast_item.connect("expired", _on_toast_expired);
	toast_item.show_toast(payload);


func _try_show_next_feedback() -> void:
	if _feedback_modal == null:
		return;
	if _active_feedback_request_id >= 0:
		return;
	while not _feedback_queue.is_empty():
		var request: Dictionary = _feedback_queue.pop_front();
		var request_id: int = int(request.get("request_id", -1));
		_queued_feedback_request_ids.erase(request_id);
		var kind: StringName = request.get("kind", &"");
		if request_id < 0:
			continue;
		if kind != &"confirm" and kind != &"alert":
			continue;

		_active_feedback_kind = kind;
		_active_feedback_request_id = request_id;
		var payload: Dictionary = request.get("payload", {});
		if _active_feedback_kind == &"alert":
			_feedback_modal.configure_alert(_active_feedback_request_id, payload);
		else:
			_feedback_modal.configure_confirm(_active_feedback_request_id, payload);
		_push_modal(_feedback_modal);
		return;


func _on_feedback_confirmed(request_id: int) -> void:
	if request_id != _active_feedback_request_id:
		return;

	var resolved_kind: StringName = _active_feedback_kind;
	_clear_active_feedback_request();
	await _close_feedback_modal();
	if resolved_kind == &"alert":
		UiFeedback.resolve_alert(request_id);
	else:
		UiFeedback.resolve_confirm(request_id, true);
	call_deferred("_try_show_next_feedback");


func _on_feedback_canceled(request_id: int) -> void:
	if request_id != _active_feedback_request_id:
		return;

	_clear_active_feedback_request();
	await _close_feedback_modal();
	UiFeedback.resolve_confirm(request_id, false);
	call_deferred("_try_show_next_feedback");


func _cancel_active_feedback_request() -> void:
	_feedback_queue.clear();
	_queued_feedback_request_ids.clear();
	if _active_feedback_request_id < 0:
		return;
	if _active_feedback_kind == &"alert":
		UiFeedback.resolve_alert(_active_feedback_request_id);
	else:
		UiFeedback.resolve_confirm(_active_feedback_request_id, false);
	_clear_active_feedback_request();


func _clear_active_feedback_request() -> void:
	_active_feedback_kind = &"";
	_active_feedback_request_id = -1;


func _on_toast_expired(item: Control) -> void:
	if item == null:
		return;
	if item.get_parent() != null:
		item.get_parent().remove_child(item);
	item.queue_free();


func _bind_modal_lifecycle(modal: BaseModal) -> void:
	if modal == null:
		return;
	if not modal.opened.is_connected(_on_modal_visibility_changed):
		modal.opened.connect(_on_modal_visibility_changed);
	if not modal.closed.is_connected(_on_modal_visibility_changed):
		modal.closed.connect(_on_modal_visibility_changed);


func _close_feedback_modal() -> void:
	if _feedback_modal == null:
		return;
	_pop_modal(_feedback_modal);
	await _feedback_modal.closed;


func _on_modal_visibility_changed() -> void:
	_refresh_modal_visibility();
	_refresh_debug_overlay();
	if not _modal_stack.is_empty():
		call_deferred("_focus_top_modal");


func _validate_shell_setup() -> void:
	if _hud_layer == null:
		_warn_setup_issue("hud_layer_missing", "hud_layer_path is not configured or points to a missing node");
	if _modal_layer == null:
		_warn_setup_issue("modal_layer_missing", "modal_layer_path is not configured or points to a missing node");
	if _loading_layer == null:
		_warn_setup_issue("loading_layer_missing", "loading_layer_path is not configured or points to a missing node");
	if _debug_layer == null:
		_warn_setup_issue("debug_layer_missing", "debug_layer_path is not configured or points to a missing node");
	if _toast_stack == null:
		_warn_setup_issue("toast_stack_missing", "toast_stack_path is not configured or points to a missing node");
	if _modal_backdrop == null:
		_warn_setup_issue("modal_backdrop_missing", "modal_backdrop_path is not configured or points to a missing node");
	if toast_item_scene == null:
		_warn_setup_issue("toast_item_scene_missing", "toast_item_scene is not assigned");


func _warn_setup_issue(issue_key: String, message: String) -> void:
	if _reported_setup_issues.has(issue_key):
		return;
	_reported_setup_issues[issue_key] = true;
	push_warning("UiShell: %s." % [message]);


func _compact_modal_stack() -> void:
	var compacted_stack: Array[Control] = [];
	for modal: Control in _modal_stack:
		if modal == null:
			continue;
		if not is_instance_valid(modal):
			continue;
		if compacted_stack.has(modal):
			continue;
		compacted_stack.append(modal);
	_modal_stack = compacted_stack;


func _wait_for_loading_transition() -> void:
	while _loading_transition_active:
		await get_tree().process_frame;


func _enqueue_feedback_request(kind: StringName, request_id: int, payload: Dictionary) -> void:
	if request_id < 0:
		return;
	if request_id == _active_feedback_request_id:
		return;
	if _queued_feedback_request_ids.has(request_id):
		for request_index: int in range(_feedback_queue.size()):
			var queued_request: Dictionary = _feedback_queue[request_index];
			if int(queued_request.get("request_id", -1)) != request_id:
				continue;
			_feedback_queue[request_index] = {
				"kind": kind,
				"request_id": request_id,
				"payload": payload,
			};
			return;
	_feedback_queue.append({
		"kind": kind,
		"request_id": request_id,
		"payload": payload,
	});
	_queued_feedback_request_ids[request_id] = true;
