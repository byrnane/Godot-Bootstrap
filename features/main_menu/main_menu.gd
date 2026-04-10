extends Control;
class_name MainMenu;

const SCENE_TRANSITION_PAYLOAD_TYPE = preload("res://core/types/scene_transition_payload.gd");
const UI_FOCUS = preload("res://shared/ui/navigation/ui_focus.gd");

signal new_game_requested;
signal continue_requested;
signal settings_requested;
signal save_slots_requested;
signal quit_requested;


@onready var continue_button: Button = %ContinueButton;
@onready var new_game_button: Button = %NewGameButton;
@onready var settings_button: Button = %SettingsButton;
@onready var save_slots_button: Button = %SaveSlotsButton;
@onready var quit_button: Button = %QuitButton;


func _ready() -> void:
	AudioManager.bind_ui_sounds(self);
	continue_button.pressed.connect(_on_continue_button_pressed);
	new_game_button.pressed.connect(_on_new_game_button_pressed);
	settings_button.pressed.connect(_on_settings_button_pressed);
	save_slots_button.pressed.connect(_on_save_slots_button_pressed);
	quit_button.pressed.connect(_on_quit_button_pressed);
	_refresh_continue_state();


func on_enter(_payload: SCENE_TRANSITION_PAYLOAD_TYPE = null) -> void:
	_refresh_continue_state();
	new_game_button.grab_focus();


func _refresh_continue_state() -> void:
	continue_button.disabled = not SaveManager.has_continue_save();
	UI_FOCUS.apply_vertical_focus_cycle(_collect_focusable_buttons());


func _collect_focusable_buttons() -> Array[Button]:
	var buttons: Array[Button] = [new_game_button];
	if not continue_button.disabled:
		buttons.append(continue_button);
	buttons.append(save_slots_button);
	buttons.append(settings_button);
	buttons.append(quit_button);
	return buttons;


func _on_continue_button_pressed() -> void:
	continue_requested.emit();


func _on_new_game_button_pressed() -> void:
	new_game_requested.emit();


func _on_settings_button_pressed() -> void:
	settings_requested.emit();


func _on_save_slots_button_pressed() -> void:
	save_slots_requested.emit();


func _on_quit_button_pressed() -> void:
	quit_requested.emit();
