extends Node;

signal confirm_requested(request_id: int, payload: Dictionary);
signal alert_requested(request_id: int, payload: Dictionary);
signal toast_requested(payload: Dictionary);


var _next_request_id: int = 1;
var _request_callbacks: Dictionary = {};


func confirm(message: String, on_confirm: Callable = Callable(), on_cancel: Callable = Callable(), options: Dictionary = {}) -> int:
	var request_id: int = _allocate_request_id();
	_request_callbacks[request_id] = {
		"kind": "confirm",
		"on_confirm": on_confirm,
		"on_cancel": on_cancel,
	};
	confirm_requested.emit(request_id, _build_payload(message, options, {
		"variant": "warning",
		"title": tr("UI_FEEDBACK_CONFIRM_TITLE"),
		"confirm_text": tr("UI_FEEDBACK_CONFIRM_BUTTON"),
		"cancel_text": tr("UI_FEEDBACK_CANCEL_BUTTON"),
		"close_on_backdrop": true,
		"close_on_cancel": true,
	}));
	return request_id;


func alert(message: String, on_acknowledged: Callable = Callable(), options: Dictionary = {}) -> int:
	var request_id: int = _allocate_request_id();
	_request_callbacks[request_id] = {
		"kind": "alert",
		"on_acknowledged": on_acknowledged,
	};
	alert_requested.emit(request_id, _build_payload(message, options, {
		"variant": "info",
		"title": tr("UI_FEEDBACK_ALERT_TITLE"),
		"confirm_text": tr("UI_FEEDBACK_OK_BUTTON"),
		"cancel_text": "",
		"close_on_backdrop": true,
		"close_on_cancel": true,
	}));
	return request_id;


func toast(message: String, options: Dictionary = {}) -> void:
	toast_requested.emit(_build_payload(message, options, {
		"variant": "info",
		"title": "",
		"duration": 2.4,
	}));


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
