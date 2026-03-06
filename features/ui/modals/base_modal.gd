extends PanelContainer;
class_name BaseModal;

signal close_requested;
signal opened;
signal closed;

@export var close_action_name: StringName = &"ui_cancel";
@export var close_on_cancel: bool = true;
@export var close_on_backdrop: bool = true;
@export var default_focus_path: NodePath;

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS;
	visible = false;

func open_modal() -> void:
	visible = true;
	_sync_ui_state();
	focus_default_control();
	opened.emit();

func close_modal() -> void:
	visible = false;
	closed.emit();

func request_close() -> void:
	close_requested.emit();

func can_close_from_backdrop() -> bool:
	return close_on_backdrop;

func can_close_from_cancel() -> bool:
	return close_on_cancel;

func focus_default_control() -> void:
	var default_control: Control = get_node_or_null(default_focus_path) as Control;
	if default_control != null:
		default_control.grab_focus();

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return;
	if not close_on_cancel:
		return;
	if event.is_action_pressed(close_action_name):
		request_close();
		get_viewport().set_input_as_handled();

func _sync_ui_state() -> void:
	pass;
