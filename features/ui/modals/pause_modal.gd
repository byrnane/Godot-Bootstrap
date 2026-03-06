extends BaseModal;
class_name PauseModal;

signal resume_requested;
signal save_requested;
signal settings_requested;
signal back_to_menu_requested;

func _ready() -> void:
	super._ready();
	if not close_requested.is_connected(_on_close_requested):
		close_requested.connect(_on_close_requested);

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