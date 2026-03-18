extends Node;

signal state_changed(new_state: AppState.Value);
signal debug_enabled_changed(is_enabled: bool);

var state: AppState.Value = AppState.Value.BOOT;
var debug_enabled: bool = false;
var settings: UserSettings = null;

func _ready() -> void:
	ensure_defaults();

func ensure_defaults() -> void:
	if settings == null:
		settings = UserSettings.new();

func set_state(new_state: AppState.Value) -> void:
	if state == new_state:
		return;

	state = new_state;
	state_changed.emit(state);

func set_debug_enabled(is_enabled: bool) -> void:
	if debug_enabled == is_enabled:
		return;

	debug_enabled = is_enabled;
	debug_enabled_changed.emit(debug_enabled);

func toggle_debug_enabled() -> void:
	set_debug_enabled(not debug_enabled);
