extends Control;
class_name LoadingScreen;

signal intro_finished;
signal outro_finished;


const DEFAULT_PROGRESS: float = -1.0;
const DOT_ANIMATION_STEP: float = 0.35;
const MAX_DOT_COUNT: int = 3;
const UI_MOTION_UTIL = preload("res://shared/ui/motion/ui_motion.gd");
const STATUS_LOADING: StringName = &"loading";
const STATUS_SUCCESS: StringName = &"success";
const STATUS_ERROR: StringName = &"error";
const STATUS_WARNING: StringName = &"warning";
const VALID_STATUS_STATES: Array[StringName] = [
	STATUS_LOADING,
	STATUS_SUCCESS,
	STATUS_ERROR,
	STATUS_WARNING,
];
const STATUS_BADGE_VARIANTS: Dictionary = {
	STATUS_LOADING: "info",
	STATUS_SUCCESS: "success",
	STATUS_ERROR: "error",
	STATUS_WARNING: "warning",
};
const STATUS_BADGE_TEXT_KEYS: Dictionary = {
	STATUS_LOADING: "UI_LOADING_STATE_LOADING",
	STATUS_SUCCESS: "UI_LOADING_STATE_SUCCESS",
	STATUS_ERROR: "UI_LOADING_STATE_ERROR",
	STATUS_WARNING: "UI_LOADING_STATE_WARNING",
};


@export var fade_duration: float = 0.2;
@export var minimum_visible_time: float = 0.0;
@export var tip_cycle_interval: float = 2.5;


@onready var card: Control = %Card;
@onready var status_badge: UiStatusBadge = %StatusBadge;
@onready var title_label: Label = %TitleLabel;
@onready var context_label: Label = %ContextLabel;
@onready var message_label: Label = %MessageLabel;
@onready var progress_bar: ProgressBar = %ProgressBar;
@onready var progress_status_label: Label = %ProgressStatusLabel;
@onready var tip_label: Label = %TipLabel;


var _shown_at_msec: int = 0;
var _base_title_text: String = "";
var _base_message_text: String = "";
var _tip_pool: Array[String] = [];
var _tip_index: int = 0;
var _title_elapsed: float = 0.0;
var _tip_elapsed: float = 0.0;
var _status_state: StringName = STATUS_LOADING;


func _ready() -> void:
	visible = false;
	mouse_filter = Control.MOUSE_FILTER_STOP;
	process_mode = Node.PROCESS_MODE_ALWAYS;
	modulate.a = 0.0;
	card.modulate.a = 0.0;
	card.scale = UI_MOTION_UTIL.MODAL_INITIAL_SCALE;
	progress_bar.visible = false;
	progress_status_label.visible = false;
	context_label.visible = false;


func _process(delta: float) -> void:
	if not visible:
		return;

	_title_elapsed += delta;
	_tip_elapsed += delta;
	_refresh_title_text();
	_cycle_tip_if_needed();


func show_screen(data: Dictionary = {}) -> void:
	_apply_content(data);
	visible = true;
	await _fade_to(1.0);
	_shown_at_msec = Time.get_ticks_msec();
	intro_finished.emit();


func hide_screen() -> void:
	var elapsed_seconds: float = float(Time.get_ticks_msec() - _shown_at_msec) / 1000.0;
	var remaining_seconds: float = maxf(0.0, minimum_visible_time - elapsed_seconds);
	if remaining_seconds > 0.0:
		await get_tree().create_timer(remaining_seconds, false).timeout;
	await _fade_to(0.0);
	visible = false;
	outro_finished.emit();


func update_progress(progress: float, status_text: String = "", status_state: StringName = StringName()) -> void:
	var normalized_progress: float = clampf(progress, 0.0, 1.0);
	var has_progress: bool = progress >= 0.0;
	progress_bar.visible = has_progress;
	progress_bar.value = normalized_progress * 100.0;
	if status_state != StringName():
		_apply_status_state(status_state);
	_update_progress_status(normalized_progress, has_progress, status_text);
	if not status_text.is_empty():
		_base_message_text = status_text;
		message_label.text = _base_message_text;


func _apply_content(data: Dictionary) -> void:
	_base_title_text = _normalize_loading_title(String(data.get("title", tr("UI_LOADING"))));
	_apply_context_text(String(data.get("context", "")));
	_apply_status_state(StringName(data.get("status_state", STATUS_LOADING)));
	_base_message_text = String(data.get("message", tr("UI_LOADING_MESSAGE")));
	message_label.text = _base_message_text;
	_tip_pool = _build_tip_pool(data);
	_tip_index = 0;
	_tip_elapsed = 0.0;
	_title_elapsed = 0.0;
	_refresh_title_text();
	_refresh_tip_text();
	var progress: float = float(data.get("progress", DEFAULT_PROGRESS));
	var has_progress: bool = progress >= 0.0;
	progress_bar.visible = has_progress;
	progress_bar.value = clampf(progress, 0.0, 1.0) * 100.0 if has_progress else 0.0;
	_update_progress_status(clampf(progress, 0.0, 1.0), has_progress, String(data.get("status", "")));


func _fade_to(target_alpha: float) -> void:
	var tween: Tween = UI_MOTION_UTIL.play_loading_fade(self, card, target_alpha, fade_duration);
	await tween.finished;


func _normalize_loading_title(title_text: String) -> String:
	return title_text.rstrip(". ").strip_edges();


func _build_tip_pool(raw_tips: Variant) -> Array[String]:
	var tips: Array[String] = [];
	if raw_tips is Dictionary:
		var data: Dictionary = raw_tips as Dictionary;
		var tips_override: Variant = data.get("tips", []);
		if tips_override is Array:
			tips = _collect_tips_from_array(tips_override as Array);
		if tips.is_empty():
			tips = _collect_tips_from_provider(data.get("tips_provider", null), data);
	elif raw_tips is Array:
		tips = _collect_tips_from_array(raw_tips as Array);
	if not tips.is_empty():
		return tips;
	return [
		tr("UI_LOADING_TIP_1"),
		tr("UI_LOADING_TIP_2"),
		tr("UI_LOADING_TIP_3"),
	];


func _refresh_title_text() -> void:
	var dot_count: int = int(floor(_title_elapsed / DOT_ANIMATION_STEP)) % (MAX_DOT_COUNT + 1);
	title_label.text = "%s%s" % [_base_title_text, ".".repeat(dot_count)];


func _refresh_tip_text() -> void:
	if _tip_pool.is_empty():
		tip_label.text = "";
		return;
	tip_label.text = _tip_pool[_tip_index];


func _cycle_tip_if_needed() -> void:
	if _tip_pool.size() <= 1:
		return;
	if _tip_elapsed < tip_cycle_interval:
		return;
	_tip_elapsed = 0.0;
	_tip_index = (_tip_index + 1) % _tip_pool.size();
	_refresh_tip_text();


func _update_progress_status(progress: float, has_progress: bool, status_text: String) -> void:
	progress_status_label.visible = has_progress;
	if not has_progress:
		progress_status_label.text = "";
		return;
	if not status_text.is_empty():
		progress_status_label.text = status_text;
		return;
	progress_status_label.text = tr("UI_LOADING_PROGRESS").format({
		"percent": int(round(progress * 100.0)),
	});


func _apply_context_text(text: String) -> void:
	var context_text: String = text.strip_edges();
	context_label.visible = not context_text.is_empty();
	context_label.text = context_text;


func _apply_status_state(state: StringName) -> void:
	var normalized_state: StringName = _normalize_status_state(state);
	_status_state = normalized_state;
	if status_badge == null:
		return;
	status_badge.variant = String(STATUS_BADGE_VARIANTS.get(_status_state, "info"));
	status_badge.text_key = String(STATUS_BADGE_TEXT_KEYS.get(_status_state, "UI_LOADING_STATE_LOADING"));


func _normalize_status_state(state: StringName) -> StringName:
	if VALID_STATUS_STATES.has(state):
		return state;
	return STATUS_LOADING;


func _collect_tips_from_array(raw_tips: Array) -> Array[String]:
	var tips: Array[String] = [];
	for raw_tip: Variant in raw_tips:
		var tip_text: String = String(raw_tip).strip_edges();
		if not tip_text.is_empty():
			tips.append(tip_text);
	return tips;


func _collect_tips_from_provider(provider: Variant, data: Dictionary) -> Array[String]:
	var tips: Array[String] = [];
	if provider is Callable:
		var callable_provider: Callable = provider as Callable;
		if callable_provider.is_valid():
			var result: Variant = callable_provider.call(data);
			if result is Array:
				tips = _collect_tips_from_array(result as Array);
	return tips;
