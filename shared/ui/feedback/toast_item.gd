extends PanelContainer;
class_name ToastItem;

signal expired(item: ToastItem);


const DEFAULT_DURATION: float = 2.4;
const UI_MOTION_UTIL = preload("res://shared/ui/motion/ui_motion.gd");


@onready var status_badge = %StatusBadge;
@onready var title_label: Label = %TitleLabel;
@onready var message_label: Label = %MessageLabel;


func show_toast(payload: Dictionary) -> void:
	status_badge.variant = StringName(payload.get("variant", "info"));
	title_label.text = String(payload.get("title", ""));
	title_label.visible = not title_label.text.is_empty();
	message_label.text = String(payload.get("message", ""));

	var enter_tween: Tween = UI_MOTION_UTIL.play_toast_enter(self);
	await enter_tween.finished;

	var duration: float = maxf(float(payload.get("duration", DEFAULT_DURATION)), 0.5);
	await get_tree().create_timer(duration).timeout;

	var exit_tween: Tween = UI_MOTION_UTIL.play_toast_exit(self);
	await exit_tween.finished;
	expired.emit(self);
