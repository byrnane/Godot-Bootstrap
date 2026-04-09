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


func update_loading_progress(progress: float, status_text: String = "", status_state: StringName = StringName()) -> void:
	if UiShell == null:
		return;
	UiShell.update_loading_progress(progress, status_text, status_state);


func finish_loading() -> void:
	await _finish_transition("");


func fail_loading(error_text: String = "") -> void:
	await _finish_transition(error_text);


func _finish_transition(error_text: String) -> void:
	if UiShell != null:
		if not error_text.is_empty():
			UiShell.update_loading_progress(0.0, error_text, &"error");
		await UiShell.hide_loading_screen();
	_is_active = false;
	transition_finished.emit();
