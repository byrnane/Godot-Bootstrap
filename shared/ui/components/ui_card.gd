extends PanelContainer
class_name UiCard


@export var elevated: bool = false:
	set(value):
		elevated = value;
		_apply_panel_style();

@export_range(0, 48, 1) var inner_padding: int = 18:
	set(value):
		inner_padding = maxi(value, 0);
		_apply_padding();


@onready var content_margin: MarginContainer = %ContentMargin;


func _ready() -> void:
	_apply_panel_style();
	_apply_padding();


func _apply_panel_style() -> void:
	if not is_node_ready():
		return;

	var style_name: StringName = &"embedded_border" if elevated else &"panel";
	var type_name: StringName = &"Window" if elevated else &"PanelContainer";
	var style_box: StyleBox = get_theme_stylebox(style_name, type_name);
	if style_box == null:
		return;

	add_theme_stylebox_override("panel", style_box.duplicate(true));


func _apply_padding() -> void:
	if not is_node_ready():
		return;

	content_margin.add_theme_constant_override("margin_left", inner_padding);
	content_margin.add_theme_constant_override("margin_top", inner_padding);
	content_margin.add_theme_constant_override("margin_right", inner_padding);
	content_margin.add_theme_constant_override("margin_bottom", inner_padding);
