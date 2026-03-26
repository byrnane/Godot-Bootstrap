extends PanelContainer;
class_name BaseModal;


const UiFocus = preload("res://shared/ui/navigation/ui_focus.gd");
const UiMotion = preload("res://shared/ui/motion/ui_motion.gd");


signal close_requested;
signal opened;
signal closed;


@export var close_action_name: StringName = &"ui_cancel";
@export var close_on_cancel: bool = true;
@export var close_on_backdrop: bool = true;
@export var default_focus_path: NodePath;
@export var fullscreen_mode: bool = false;
@export var motion_target_path: NodePath = NodePath("MarginContainer");

@onready var motion_target: Control = get_node_or_null(motion_target_path) as Control;
@onready var body_scroll: ScrollContainer = %BodyScroll;


var _previous_focus_owner: Control = null;
var _motion_tween: Tween = null;
var _is_closing: bool = false;


func _ready() -> void:
	_apply_layout_mode();
	process_mode = Node.PROCESS_MODE_ALWAYS;
	set_process_unhandled_input(false);
	visible = false;
	AudioManager.bind_ui_sounds(self);


func open_modal() -> void:
	_is_closing = false;
	_stop_motion_tween();
	_remember_focus_owner();
	visible = true;
	# Derived modals can re-sync controls here every time they are reopened
	# without duplicating focus and open-state behavior.
	_sync_ui_state();
	focus_default_control();
	call_deferred("_reset_scroll_position");
	if motion_target != null:
		_motion_tween = UiMotion.play_modal_open(self, motion_target);
	opened.emit();


func close_modal() -> void:
	if _is_closing:
		return;

	_is_closing = true;
	_stop_motion_tween();
	if motion_target != null:
		_motion_tween = UiMotion.play_modal_close(self, motion_target);
		await _motion_tween.finished;

	visible = false;
	modulate = Color(1.0, 1.0, 1.0, 1.0);
	if motion_target != null:
		motion_target.modulate = Color(1.0, 1.0, 1.0, 1.0);
		motion_target.scale = Vector2.ONE;

	_is_closing = false;
	call_deferred("_restore_previous_focus");
	closed.emit();


func request_close() -> void:
	close_requested.emit();


func can_close_from_backdrop() -> bool:
	return close_on_backdrop;


func can_close_from_cancel() -> bool:
	return close_on_cancel;


func focus_default_control() -> void:
	if UiFocus.grab_path(self, default_focus_path):
		return;

	var fallback_control: Control = UiFocus.find_first_focusable(self);
	if fallback_control != null:
		fallback_control.grab_focus();


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not close_on_cancel:
		return;
	if event.is_action_pressed(close_action_name):
		request_close();
		get_viewport().set_input_as_handled();


func _sync_ui_state() -> void:
	pass;


func _reset_scroll_position() -> void:
	if body_scroll == null:
		return;
	body_scroll.scroll_vertical = 0;


func _apply_layout_mode() -> void:
	if not fullscreen_mode:
		return;
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);


func _remember_focus_owner() -> void:
	_previous_focus_owner = UiFocus.capture(get_viewport());


func _restore_previous_focus() -> void:
	if UiFocus.restore(_previous_focus_owner):
		_previous_focus_owner = null;
		return;

	_previous_focus_owner = null;


func _stop_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill();
	_motion_tween = null;
