extends Control;
class_name DebugOverlay;

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

var _snapshot: Dictionary = {};
var _time_since_refresh: float = 0.0;

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	mouse_filter = Control.MOUSE_FILTER_IGNORE;
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

func _get_state_label(state_value: AppState.Value) -> String:
	match state_value:
		AppState.Value.BOOT:
			return tr("UI_STATE_BOOT");
		AppState.Value.MAIN_MENU:
			return tr("UI_STATE_MAIN_MENU");
		AppState.Value.LOADING:
			return tr("UI_STATE_LOADING");
		AppState.Value.IN_GAME:
			return tr("UI_STATE_IN_GAME");
		AppState.Value.PAUSED:
			return tr("UI_STATE_PAUSED");
		_:
			return str(state_value);

func _format_bool(value: Variant) -> String:
	return "ON" if bool(value) else "OFF";
