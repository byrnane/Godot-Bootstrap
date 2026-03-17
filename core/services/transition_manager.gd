extends Node;

signal transition_started(data: Dictionary);
signal transition_finished();

var _is_active: bool = false;

func is_active() -> bool:
	return _is_active;

func begin_loading(data: Dictionary = {}) -> void:
	_is_active = true;
	transition_started.emit(data);
	if UiShell != null:
		await UiShell.show_loading_screen(data);

func update_loading_progress(progress: float, status_text: String = "") -> void:
	if UiShell == null:
		return;
	UiShell.update_loading_progress(progress, status_text);

func finish_loading() -> void:
	if UiShell != null:
		await UiShell.hide_loading_screen();
	_is_active = false;
	transition_finished.emit();

func fail_loading(error_text: String = "") -> void:
	if UiShell != null:
		if not error_text.is_empty():
			UiShell.update_loading_progress(0.0, error_text);
		await UiShell.hide_loading_screen();
	_is_active = false;
	transition_finished.emit();
