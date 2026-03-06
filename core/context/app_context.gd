extends Node;

signal state_changed(new_state: AppState.Value);

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
