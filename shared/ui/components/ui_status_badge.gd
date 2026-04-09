extends PanelContainer;
class_name UiStatusBadge;


const VARIANT_STYLES: Dictionary = {
	&"info": {
		"background": Color(0.176, 0.282, 0.455, 0.82),
		"border": Color(0.576, 0.725, 0.933, 0.56),
		"font": Color(0.93, 0.97, 1.0, 1.0),
		"label_key": "UI_FEEDBACK_VARIANT_INFO",
	},
	&"success": {
		"background": Color(0.122, 0.325, 0.239, 0.84),
		"border": Color(0.494, 0.835, 0.651, 0.54),
		"font": Color(0.92, 0.99, 0.95, 1.0),
		"label_key": "UI_FEEDBACK_VARIANT_SUCCESS",
	},
	&"warning": {
		"background": Color(0.412, 0.255, 0.094, 0.84),
		"border": Color(0.934, 0.714, 0.345, 0.54),
		"font": Color(1.0, 0.961, 0.894, 1.0),
		"label_key": "UI_FEEDBACK_VARIANT_WARNING",
	},
	&"error": {
		"background": Color(0.404, 0.153, 0.192, 0.84),
		"border": Color(0.929, 0.482, 0.565, 0.56),
		"font": Color(1.0, 0.93, 0.95, 1.0),
		"label_key": "UI_FEEDBACK_VARIANT_ERROR",
	},
};


@export_enum("info", "success", "warning", "error") var variant: String = "info":
	set(value):
		variant = value if VARIANT_STYLES.has(StringName(value)) else "info";
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


func set_badge_text(text: String, translate_text: bool = false) -> void:
	_custom_text = text;
	_use_translation = translate_text;
	_refresh();


func _refresh() -> void:
	if not is_node_ready():
		return;

	var style_data: Dictionary = VARIANT_STYLES.get(StringName(variant), VARIANT_STYLES[&"info"]);
	var panel_style: StyleBoxFlat = StyleBoxFlat.new();
	panel_style.content_margin_left = 10.0;
	panel_style.content_margin_top = 6.0;
	panel_style.content_margin_right = 10.0;
	panel_style.content_margin_bottom = 6.0;
	panel_style.bg_color = style_data.get("background", Color(0.18, 0.28, 0.45, 0.82));
	panel_style.border_width_left = 1;
	panel_style.border_width_top = 1;
	panel_style.border_width_right = 1;
	panel_style.border_width_bottom = 1;
	panel_style.border_color = style_data.get("border", Color(0.58, 0.73, 0.93, 0.56));
	panel_style.corner_radius_top_left = 999;
	panel_style.corner_radius_top_right = 999;
	panel_style.corner_radius_bottom_right = 999;
	panel_style.corner_radius_bottom_left = 999;
	add_theme_stylebox_override("panel", panel_style);

	text_label.add_theme_color_override("font_color", style_data.get("font", Color(0.93, 0.97, 1.0, 1.0)));
	if not _custom_text.is_empty():
		text_label.text = tr(_custom_text) if _use_translation else _custom_text;
		return;

	var label_key: String = text_key if not text_key.is_empty() else String(style_data.get("label_key", "UI_FEEDBACK_VARIANT_INFO"));
	text_label.text = tr(label_key);
