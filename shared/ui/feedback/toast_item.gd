extends PanelContainer;
class_name ToastItem;

signal expired(item: ToastItem);


const FADE_DURATION: float = 0.18;
const DEFAULT_DURATION: float = 2.4;


@onready var message_label: Label = %MessageLabel;


func show_toast(payload: Dictionary) -> void:
	message_label.text = String(payload.get("message", ""));
	modulate = Color(1.0, 1.0, 1.0, 0.0);

	var fade_in: Tween = create_tween();
	fade_in.tween_property(self, "modulate:a", 1.0, FADE_DURATION);
	await fade_in.finished;

	var duration: float = maxf(float(payload.get("duration", DEFAULT_DURATION)), 0.5);
	await get_tree().create_timer(duration).timeout;

	var fade_out: Tween = create_tween();
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_DURATION);
	await fade_out.finished;
	expired.emit(self);
