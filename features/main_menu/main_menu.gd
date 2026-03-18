extends Control;
class_name MainMenu;

signal new_game_requested;
signal continue_requested;
signal settings_requested;
signal quit_requested;


@onready var continue_button: Button = %ContinueButton;
@onready var new_game_button: Button = %NewGameButton;
@onready var settings_button: Button = %SettingsButton;
@onready var quit_button: Button = %QuitButton;


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_button_pressed);
	new_game_button.pressed.connect(_on_new_game_button_pressed);
	settings_button.pressed.connect(_on_settings_button_pressed);
	quit_button.pressed.connect(_on_quit_button_pressed);
	_refresh_continue_state();


func on_enter(_payload: Variant = null) -> void:
	_refresh_continue_state();
	new_game_button.grab_focus();


func _refresh_continue_state() -> void:
	continue_button.disabled = not SaveManager.has_save();


func _on_continue_button_pressed() -> void:
	continue_requested.emit();


func _on_new_game_button_pressed() -> void:
	new_game_requested.emit();


func _on_settings_button_pressed() -> void:
	settings_requested.emit();


func _on_quit_button_pressed() -> void:
	quit_requested.emit();
