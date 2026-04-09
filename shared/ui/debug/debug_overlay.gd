extends Control;
class_name DebugOverlay;

signal clear_save_requested;
signal jump_to_scene_requested(scene_id: StringName);
signal restart_session_requested;

@export var refresh_interval: float = 0.2;

@onready var title_label: Label = %TitleLabel;
@onready var hint_label: Label = %HintLabel;
@onready var fps_label: Label = %FpsLabel;
@onready var state_label: Label = %StateLabel;
@onready var scene_label: Label = %SceneLabel;
@onready var paused_label: Label = %PausedLabel;
@onready var loading_label: Label = %LoadingLabel;
@onready var hud_label: Label = %HudLabel;
@onready var modals_label: Label = %ModalsLabel;
@onready var debug_label: Label = %DebugLabel;
@onready var router_label: Label = %RouterLabel;
@onready var loading_state_label: Label = %LoadingStateLabel;
@onready var modal_state_label: Label = %ModalStateLabel;
@onready var input_state_label: Label = %InputStateLabel;
@onready var actions_label: Label = %ActionsLabel;
@onready var clear_save_button: Button = %ClearSaveButton;
@onready var scene_option_button: OptionButton = %SceneOptionButton;
@onready var jump_scene_button: Button = %JumpSceneButton;
@onready var restart_session_button: Button = %RestartSessionButton;

var _snapshot: Dictionary = {};
var _time_since_refresh: float = 0.0;
var _scene_targets: PackedStringArray = [];

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	mouse_filter = Control.MOUSE_FILTER_PASS;
	clear_save_button.pressed.connect(_on_clear_save_button_pressed);
	jump_scene_button.pressed.connect(_on_jump_scene_button_pressed);
	restart_session_button.pressed.connect(_on_restart_session_button_pressed);
	visible = false;
	_refresh_text();

func _process(delta: float) -> void:
	if not visible:
		return;

	_time_since_refresh += delta;
	if _time_since_refresh < refresh_interval:
		return;

	_time_since_refresh = 0.0;
	_refresh_text();

func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true);
	_refresh_text();

func show_overlay() -> void:
	visible = true;
	_time_since_refresh = refresh_interval;
	_refresh_text();

func hide_overlay() -> void:
	visible = false;

func set_scene_targets(scene_ids: Array[StringName], current_scene_id: StringName) -> void:
	var scene_ids_text: PackedStringArray = [];
	for scene_id: StringName in scene_ids:
		var scene_id_text: String = String(scene_id).strip_edges();
		if scene_id_text.is_empty():
			continue;
		if scene_ids_text.has(scene_id_text):
			continue;
		scene_ids_text.append(scene_id_text);
	scene_ids_text.sort();

	if _scene_targets == scene_ids_text:
		_select_scene_target(current_scene_id);
		return;

	_scene_targets = scene_ids_text;
	scene_option_button.clear();
	for scene_id_text: String in _scene_targets:
		scene_option_button.add_item(scene_id_text);
		var item_index: int = scene_option_button.item_count - 1;
		scene_option_button.set_item_metadata(item_index, scene_id_text);
	_select_scene_target(current_scene_id);
	if scene_option_button.selected < 0 and scene_option_button.item_count > 0:
		scene_option_button.select(0);

func _refresh_text() -> void:
	title_label.text = tr("UI_DEBUG_HEADER");
	hint_label.text = tr("UI_DEBUG_HINT");
	fps_label.text = tr("UI_DEBUG_FPS").format({"value": Engine.get_frames_per_second()});
	state_label.text = tr("UI_DEBUG_APP_STATE").format({"value": _get_state_label(_snapshot.get("app_state", AppContext.state))});
	scene_label.text = tr("UI_DEBUG_SCENE").format({"value": String(_snapshot.get("scene_id", SceneRouter.current_scene_id))});
	paused_label.text = tr("UI_DEBUG_TREE_PAUSED").format({"value": _format_bool(_snapshot.get("tree_paused", get_tree().paused))});
	loading_label.text = tr("UI_DEBUG_LOADING").format({"value": _format_bool(_snapshot.get("is_loading", SceneRouter.is_loading()))});
	hud_label.text = tr("UI_DEBUG_HUD").format({"value": String(_snapshot.get("hud_name", "-"))});
	modals_label.text = tr("UI_DEBUG_MODALS").format({"value": String(_snapshot.get("modal_names", "-"))});
	debug_label.text = tr("UI_DEBUG_ENABLED").format({"value": _format_bool(_snapshot.get("debug_enabled", AppContext.debug_enabled))});

	var router_snapshot: Dictionary = _snapshot.get("router", {});
	var queued_scene_id: String = String(router_snapshot.get("queued_scene_id", "-")).strip_edges();
	if queued_scene_id.is_empty():
		queued_scene_id = "-";
	router_label.text = tr("UI_DEBUG_ROUTER").format({
		"loading": _format_bool(router_snapshot.get("is_loading", SceneRouter.is_loading())),
		"queued": _format_bool(router_snapshot.get("has_queued_transition", false)),
		"target": queued_scene_id,
	});

	var loading_snapshot: Dictionary = _snapshot.get("loading_layer", {});
	loading_state_label.text = tr("UI_DEBUG_LOADING_LAYER").format({
		"visible": _format_bool(loading_snapshot.get("visible", false)),
		"transition": _format_bool(loading_snapshot.get("transition_active", false)),
		"token": int(loading_snapshot.get("request_token", 0)),
	});

	var modal_snapshot: Dictionary = _snapshot.get("modal_layer", {});
	modal_state_label.text = tr("UI_DEBUG_MODAL_LAYER").format({
		"depth": int(modal_snapshot.get("stack_depth", 0)),
		"feedback": int(modal_snapshot.get("feedback_queue_size", 0)),
		"backdrop": _format_bool(modal_snapshot.get("backdrop_visible", false)),
	});

	var input_snapshot: Dictionary = _snapshot.get("input", {});
	var pending_action: String = String(input_snapshot.get("pending_action", "-")).strip_edges();
	if pending_action.is_empty():
		pending_action = "-";
	input_state_label.text = tr("UI_DEBUG_INPUT").format({
		"rebind": _format_bool(input_snapshot.get("is_rebinding", false)),
		"action": pending_action,
		"slot": int(input_snapshot.get("pending_slot", -1)),
	});

	actions_label.text = tr("UI_DEBUG_ACTIONS_HEADER");
	clear_save_button.text = tr("UI_DEBUG_ACTION_CLEAR_SAVE");
	jump_scene_button.text = tr("UI_DEBUG_ACTION_JUMP_SCENE");
	restart_session_button.text = tr("UI_DEBUG_ACTION_RESTART_SESSION");
	scene_option_button.tooltip_text = tr("UI_DEBUG_ACTION_SCENE_TARGET");

func _select_scene_target(scene_id: StringName) -> void:
	var scene_id_text: String = String(scene_id).strip_edges();
	if scene_id_text.is_empty():
		return;
	for item_index: int in range(scene_option_button.item_count):
		if String(scene_option_button.get_item_metadata(item_index)) != scene_id_text:
			continue;
		scene_option_button.select(item_index);
		return;

func _on_clear_save_button_pressed() -> void:
	clear_save_requested.emit();

func _on_jump_scene_button_pressed() -> void:
	var scene_id: StringName = _get_selected_scene_id();
	if scene_id == StringName():
		return;
	jump_to_scene_requested.emit(scene_id);

func _on_restart_session_button_pressed() -> void:
	restart_session_requested.emit();

func _get_selected_scene_id() -> StringName:
	if scene_option_button.selected < 0:
		return StringName();
	var scene_id_text: String = String(scene_option_button.get_item_metadata(scene_option_button.selected)).strip_edges();
	if scene_id_text.is_empty():
		return StringName();
	return StringName(scene_id_text);

func _get_state_label(state_value: AppState.Value) -> String:
	var state_key: String = AppState.to_ui_key(state_value);
	if state_key.is_empty():
		return str(state_value);
	return tr(state_key);

func _format_bool(value: Variant) -> String:
	return "ON" if bool(value) else "OFF";
