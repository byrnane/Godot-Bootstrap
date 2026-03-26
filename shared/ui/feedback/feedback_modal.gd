extends BaseModal;
class_name FeedbackModal;

signal confirmed(request_id: int);
signal canceled(request_id: int);


var _request_id: int = -1;
var _is_alert_mode: bool = false;


@onready var status_badge = %StatusBadge;
@onready var header = %Header;
@onready var message_label: Label = %MessageLabel;
@onready var confirm_button: Button = %ConfirmButton;
@onready var cancel_button: Button = %CancelButton;


func configure_confirm(request_id: int, payload: Dictionary) -> void:
	_request_id = request_id;
	_is_alert_mode = false;
	_apply_payload(payload, tr("UI_FEEDBACK_CONFIRM_TITLE"), "warning");
	confirm_button.text = String(payload.get("confirm_text", tr("UI_FEEDBACK_CONFIRM_BUTTON")));
	cancel_button.text = String(payload.get("cancel_text", tr("UI_FEEDBACK_CANCEL_BUTTON")));
	cancel_button.show();


func configure_alert(request_id: int, payload: Dictionary) -> void:
	_request_id = request_id;
	_is_alert_mode = true;
	_apply_payload(payload, tr("UI_FEEDBACK_ALERT_TITLE"), "info");
	confirm_button.text = String(payload.get("confirm_text", tr("UI_FEEDBACK_OK_BUTTON")));
	cancel_button.hide();


func request_close() -> void:
	if _request_id < 0:
		return;
	if _is_alert_mode:
		confirmed.emit(_request_id);
		return;
	canceled.emit(_request_id);


func _on_confirm_button_pressed() -> void:
	if _request_id < 0:
		return;
	confirmed.emit(_request_id);


func _on_cancel_button_pressed() -> void:
	if _request_id < 0:
		return;
	canceled.emit(_request_id);


func _apply_payload(payload: Dictionary, fallback_title: String, fallback_variant: String) -> void:
	close_on_backdrop = bool(payload.get("close_on_backdrop", true));
	close_on_cancel = bool(payload.get("close_on_cancel", true));
	status_badge.variant = StringName(payload.get("variant", fallback_variant));
	status_badge.set_badge_text("", false);
	header.title_key = "";
	header.description_key = "";
	header.title_label.text = String(payload.get("title", fallback_title));
	message_label.text = String(payload.get("message", ""));
