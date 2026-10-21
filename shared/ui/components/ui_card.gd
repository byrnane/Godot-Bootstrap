@tool
extends PanelContainer;
class_name UiCard;


@export var elevated: bool = false:
	set(value):
		elevated = value;
		_apply_panel_style();

@export_range(0, 48, 1) var inner_padding: int = 24:
	set(value):
		inner_padding = maxi(value, 0);
		_apply_padding();


@onready var content_margin: MarginContainer = %ContentMargin;


func _ready() -> void:
	if theme_type_variation.is_empty():
		_apply_panel_style();
	_apply_padding();


func _apply_panel_style() -> void:
	theme_type_variation = &"UiRaised" if elevated else &"UiSurface";


func _apply_padding() -> void:
	if not is_node_ready():
		return;

	content_margin.add_theme_constant_override("margin_left", inner_padding);
	content_margin.add_theme_constant_override("margin_top", inner_padding);
	content_margin.add_theme_constant_override("margin_right", inner_padding);
	content_margin.add_theme_constant_override("margin_bottom", inner_padding);
