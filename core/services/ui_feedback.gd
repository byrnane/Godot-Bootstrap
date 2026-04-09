extends Node;

signal confirm_requested(request_id: int, payload: Dictionary);
signal alert_requested(request_id: int, payload: Dictionary);
signal toast_requested(payload: Dictionary);


const DEFAULT_TOAST_DURATION: float = 2.4;
const MIN_TOAST_DURATION: float = 0.5;
const MAX_TOAST_DURATION: float = 10.0;
const FEEDBACK_VARIANTS: PackedStringArray = ["info", "success", "warning", "error"];


var _next_request_id: int = 1;
var _request_callbacks: Dictionary = {};


func confirm(message: String, on_confirm: Callable = Callable(), on_cancel: Callable = Callable(), options: Dictionary = {}) -> int:
	var request_id: int = _allocate_request_id();
	_request_callbacks[request_id] = {
		"kind": "confirm",
		"on_confirm": on_confirm,
		"on_cancel": on_cancel,
	};
	var payload: Dictionary = _build_payload(message, options, {
		"variant": "warning",
		"title": tr("UI_FEEDBACK_CONFIRM_TITLE"),
		"confirm_text": tr("UI_FEEDBACK_CONFIRM_BUTTON"),
		"cancel_text": tr("UI_FEEDBACK_CANCEL_BUTTON"),
		"close_on_backdrop": true,
		"close_on_cancel": true,
	});
	confirm_requested.emit(request_id, _normalize_payload(payload, &"confirm"));
	return request_id;


func alert(message: String, on_acknowledged: Callable = Callable(), options: Dictionary = {}) -> int:
	var request_id: int = _allocate_request_id();
	_request_callbacks[request_id] = {
		"kind": "alert",
		"on_acknowledged": on_acknowledged,
	};
	var payload: Dictionary = _build_payload(message, options, {
		"variant": "info",
		"title": tr("UI_FEEDBACK_ALERT_TITLE"),
		"confirm_text": tr("UI_FEEDBACK_OK_BUTTON"),
		"cancel_text": "",
		"close_on_backdrop": true,
		"close_on_cancel": true,
	});
	alert_requested.emit(request_id, _normalize_payload(payload, &"alert"));
	return request_id;


func toast(message: String, options: Dictionary = {}) -> void:
	var payload: Dictionary = _build_payload(message, options, {
		"variant": "info",
		"title": "",
		"duration": DEFAULT_TOAST_DURATION,
	});
	toast_requested.emit(_normalize_payload(payload, &"toast"));


func resolve_confirm(request_id: int, accepted: bool) -> void:
	var request: Dictionary = _request_callbacks.get(request_id, {});
	if request.is_empty():
		return;

	_request_callbacks.erase(request_id);
	var callback_key: StringName = &"on_confirm" if accepted else &"on_cancel";
	var callback: Callable = request.get(callback_key, Callable());
	if callback.is_valid():
		callback.call();


func resolve_alert(request_id: int) -> void:
	var request: Dictionary = _request_callbacks.get(request_id, {});
	if request.is_empty():
		return;

	_request_callbacks.erase(request_id);
	var callback: Callable = request.get("on_acknowledged", Callable());
	if callback.is_valid():
		callback.call();


func _allocate_request_id() -> int:
	var request_id: int = _next_request_id;
	_next_request_id += 1;
	return request_id;


func _build_payload(message: String, options: Dictionary, defaults: Dictionary) -> Dictionary:
	var payload: Dictionary = defaults.duplicate(true);
	payload.merge(options, true);
	payload["message"] = message;
	return payload;


func _normalize_payload(payload: Dictionary, kind: StringName) -> Dictionary:
	var normalized_payload: Dictionary = payload.duplicate(true);
	normalized_payload["variant"] = _normalize_variant(normalized_payload.get("variant", "info"), "info");
	normalized_payload["title"] = _normalize_string(normalized_payload.get("title", ""));
	normalized_payload["message"] = _normalize_string(normalized_payload.get("message", ""));
	normalized_payload["confirm_text"] = _normalize_string(normalized_payload.get("confirm_text", ""));
	normalized_payload["cancel_text"] = _normalize_string(normalized_payload.get("cancel_text", ""));
	normalized_payload["close_on_backdrop"] = bool(normalized_payload.get("close_on_backdrop", true));
	normalized_payload["close_on_cancel"] = bool(normalized_payload.get("close_on_cancel", true));
	if kind == &"toast":
		normalized_payload["duration"] = _normalize_duration(normalized_payload.get("duration", DEFAULT_TOAST_DURATION));
	elif kind == &"confirm":
		if String(normalized_payload.get("confirm_text", "")).is_empty():
			normalized_payload["confirm_text"] = tr("UI_FEEDBACK_CONFIRM_BUTTON");
		if String(normalized_payload.get("cancel_text", "")).is_empty():
			normalized_payload["cancel_text"] = tr("UI_FEEDBACK_CANCEL_BUTTON");
	elif kind == &"alert":
		if String(normalized_payload.get("confirm_text", "")).is_empty():
			normalized_payload["confirm_text"] = tr("UI_FEEDBACK_OK_BUTTON");
		normalized_payload["cancel_text"] = "";
	return normalized_payload;


func _normalize_duration(value: Variant) -> float:
	var duration: float = DEFAULT_TOAST_DURATION;
	if value is float:
		duration = value;
	elif value is int:
		duration = float(value);
	elif value is String and (value as String).is_valid_float():
		duration = float(value);
	return clampf(duration, MIN_TOAST_DURATION, MAX_TOAST_DURATION);


func _normalize_variant(value: Variant, fallback: String) -> String:
	var variant: String = String(value).strip_edges().to_lower();
	if FEEDBACK_VARIANTS.has(variant):
		return variant;
	return fallback;


func _normalize_string(value: Variant) -> String:
	return String(value).strip_edges();
