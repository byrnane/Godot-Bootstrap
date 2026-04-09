extends BaseModal;
class_name PauseModal;

signal resume_requested;
signal save_requested;
signal settings_requested;
signal back_to_menu_requested;


@onready var resume_button: Button = %ResumeButton;
@onready var save_button: Button = %SaveButton;
@onready var settings_button: Button = %SettingsButton;
@onready var back_button: Button = %BackButton;


func _ready() -> void:
	super._ready();
	if not close_requested.is_connected(_on_close_requested):
		close_requested.connect(_on_close_requested);
	_apply_button_focus_cycle([resume_button, save_button, settings_button, back_button]);


func _apply_button_focus_cycle(buttons: Array[Button]) -> void:
	if buttons.size() <= 1:
		return;
	for button_index: int in range(buttons.size()):
		var current_button: Button = buttons[button_index];
		var previous_button: Button = buttons[(button_index - 1 + buttons.size()) % buttons.size()];
		var next_button: Button = buttons[(button_index + 1) % buttons.size()];
		current_button.focus_neighbor_top = current_button.get_path_to(previous_button);
		current_button.focus_neighbor_bottom = current_button.get_path_to(next_button);


func _on_resume_button_pressed() -> void:
	resume_requested.emit();


func _on_save_button_pressed() -> void:
	save_requested.emit();


func _on_settings_button_pressed() -> void:
	settings_requested.emit();


func _on_back_button_pressed() -> void:
	back_to_menu_requested.emit();


func _on_close_requested() -> void:
	resume_requested.emit();
