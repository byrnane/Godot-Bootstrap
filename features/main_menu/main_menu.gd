extends Control;
class_name MainMenu;

const SCENE_TRANSITION_PAYLOAD_TYPE = preload("res://core/types/scene_transition_payload.gd");

signal new_game_requested;
signal continue_requested;
signal settings_requested;
signal quit_requested;


@onready var continue_button: Button = %ContinueButton;
@onready var new_game_button: Button = %NewGameButton;
@onready var settings_button: Button = %SettingsButton;
@onready var quit_button: Button = %QuitButton;


func _ready() -> void:
	AudioManager.bind_ui_sounds(self);
	continue_button.pressed.connect(_on_continue_button_pressed);
	new_game_button.pressed.connect(_on_new_game_button_pressed);
	settings_button.pressed.connect(_on_settings_button_pressed);
	quit_button.pressed.connect(_on_quit_button_pressed);
	_refresh_continue_state();


func on_enter(_payload: SCENE_TRANSITION_PAYLOAD_TYPE = null) -> void:
	_refresh_continue_state();
	new_game_button.grab_focus();


func _refresh_continue_state() -> void:
	continue_button.disabled = not SaveManager.has_save();
	_apply_button_focus_cycle(_collect_focusable_buttons());


func _collect_focusable_buttons() -> Array[Button]:
	var buttons: Array[Button] = [new_game_button];
	if not continue_button.disabled:
		buttons.append(continue_button);
	buttons.append(settings_button);
	buttons.append(quit_button);
	return buttons;


func _apply_button_focus_cycle(buttons: Array[Button]) -> void:
	if buttons.size() <= 1:
		return;
	for button_index: int in range(buttons.size()):
		var current_button: Button = buttons[button_index];
		var previous_button: Button = buttons[(button_index - 1 + buttons.size()) % buttons.size()];
		var next_button: Button = buttons[(button_index + 1) % buttons.size()];
		current_button.focus_neighbor_top = current_button.get_path_to(previous_button);
		current_button.focus_neighbor_bottom = current_button.get_path_to(next_button);


func _on_continue_button_pressed() -> void:
	continue_requested.emit();


func _on_new_game_button_pressed() -> void:
	new_game_requested.emit();


func _on_settings_button_pressed() -> void:
	settings_requested.emit();


func _on_quit_button_pressed() -> void:
	quit_requested.emit();
