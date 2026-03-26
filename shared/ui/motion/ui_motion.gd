extends RefCounted
class_name UiMotion


const SHORT_DURATION: float = 0.16;
const MEDIUM_DURATION: float = 0.24;
const MODAL_INITIAL_SCALE: Vector2 = Vector2(0.98, 0.98);
const TOAST_OFFSET_Y: float = 14.0;


static func play_modal_open(host: CanvasItem, content: Control) -> Tween:
	host.modulate.a = 0.0;
	content.modulate.a = 0.0;
	content.scale = MODAL_INITIAL_SCALE;

	var tween: Tween = host.create_tween();
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);
	tween.set_trans(Tween.TRANS_SINE);
	tween.set_ease(Tween.EASE_OUT);
	tween.tween_property(host, "modulate:a", 1.0, SHORT_DURATION);
	tween.parallel().tween_property(content, "modulate:a", 1.0, SHORT_DURATION);
	tween.parallel().tween_property(content, "scale", Vector2.ONE, MEDIUM_DURATION);
	return tween;


static func play_modal_close(host: CanvasItem, content: Control) -> Tween:
	var tween: Tween = host.create_tween();
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);
	tween.set_trans(Tween.TRANS_SINE);
	tween.set_ease(Tween.EASE_IN);
	tween.tween_property(host, "modulate:a", 0.0, SHORT_DURATION);
	tween.parallel().tween_property(content, "modulate:a", 0.0, SHORT_DURATION);
	tween.parallel().tween_property(content, "scale", MODAL_INITIAL_SCALE, SHORT_DURATION);
	return tween;


static func play_toast_enter(item: Control) -> Tween:
	var start_position: Vector2 = item.position + Vector2(0.0, TOAST_OFFSET_Y);
	item.position = start_position;
	item.modulate.a = 0.0;

	var tween: Tween = item.create_tween();
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);
	tween.set_trans(Tween.TRANS_SINE);
	tween.set_ease(Tween.EASE_OUT);
	tween.tween_property(item, "modulate:a", 1.0, SHORT_DURATION);
	tween.parallel().tween_property(item, "position:y", start_position.y - TOAST_OFFSET_Y, MEDIUM_DURATION);
	return tween;


static func play_toast_exit(item: Control) -> Tween:
	var tween: Tween = item.create_tween();
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);
	tween.set_trans(Tween.TRANS_SINE);
	tween.set_ease(Tween.EASE_IN);
	tween.tween_property(item, "modulate:a", 0.0, SHORT_DURATION);
	tween.parallel().tween_property(item, "position:y", item.position.y + TOAST_OFFSET_Y, SHORT_DURATION);
	return tween;


static func play_loading_fade(screen: CanvasItem, card: CanvasItem, target_alpha: float, duration: float) -> Tween:
	var card_target_scale: Vector2 = Vector2.ONE if target_alpha >= 1.0 else MODAL_INITIAL_SCALE;
	var tween: Tween = screen.create_tween();
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);
	tween.set_trans(Tween.TRANS_SINE);
	tween.set_ease(Tween.EASE_OUT if target_alpha >= 1.0 else Tween.EASE_IN);
	tween.tween_property(screen, "modulate:a", target_alpha, duration);
	tween.parallel().tween_property(card, "modulate:a", target_alpha, duration);
	tween.parallel().tween_property(card, "scale", card_target_scale, duration);
	return tween;
