extends PanelContainer;
class_name ToastItem;

signal expired(item: ToastItem);


const DEFAULT_DURATION: float = 2.4;
const UI_MOTION_UTIL = preload("res://shared/ui/motion/ui_motion.gd");


@onready var title_label: Label = %TitleLabel;
@onready var message_label: Label = %MessageLabel;
var _dismissed: bool = false;
var _lifetime: Timer;


func _ready() -> void:
	%DismissButton.pressed.connect(_expire);
	_lifetime = Timer.new();
	_lifetime.one_shot = true;
	add_child(_lifetime);
	_lifetime.timeout.connect(_start_exit);


func show_toast(payload: Dictionary) -> void:
	var tone: String = String(payload.get("variant", "info"));
	if tone not in ["info", "success", "warning", "error"]:
		tone = "info";
	theme_type_variation = StringName("UiToast" + tone.capitalize());
	%Icon.texture = get_theme_icon(StringName(tone), &"UiStatusIcons");
	title_label.text = String(payload.get("title", ""));
	title_label.visible = not title_label.text.is_empty();
	message_label.text = String(payload.get("message", ""));

	var enter_tween: Tween = UI_MOTION_UTIL.play_toast_enter(self);
	var duration: float = maxf(float(payload.get("duration", DEFAULT_DURATION)), 0.5);
	enter_tween.finished.connect(_start_lifetime.bind(duration), CONNECT_ONE_SHOT);


func _start_lifetime(duration: float) -> void:
	if not _dismissed:
		_lifetime.start(duration);


func _start_exit() -> void:
	var exit_tween: Tween = UI_MOTION_UTIL.play_toast_exit(self);
	exit_tween.finished.connect(_expire, CONNECT_ONE_SHOT);


func _expire() -> void:
	if not _dismissed:
		_dismissed = true;
		_lifetime.stop();
		expired.emit(self);
