@tool
extends PanelContainer;
class_name UiStatusBadge;


@export_enum("info", "success", "warning", "error") var variant: String = "info":
	set(value):
		variant = value if value in ["info", "success", "warning", "error"] else "info";
		_refresh();

@export var text_key: String = "":
	set(value):
		text_key = value;
		_use_translation = true;
		_refresh();


@onready var text_label: Label = %TextLabel;


var _custom_text: String = "";
var _use_translation: bool = true;


func _ready() -> void:
	_refresh();


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh();


func set_badge_text(text: String, translate_text: bool = false) -> void:
	_custom_text = text;
	_use_translation = translate_text;
	_refresh();


func _refresh() -> void:
	if not is_node_ready():
		return;

	theme_type_variation = StringName("UiStatus" + variant.capitalize());
	text_label.theme_type_variation = StringName("UiStatus" + variant.capitalize() + "Text");
	if not _custom_text.is_empty():
		text_label.text = tr(_custom_text) if _use_translation else _custom_text;
		return;

	var label_key: String = text_key if not text_key.is_empty() else "UI_FEEDBACK_VARIANT_" + variant.to_upper();
	text_label.text = tr(label_key);
