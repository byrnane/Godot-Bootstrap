extends Control;
class_name LevelStubB;

@export var label_text: String = "";
@export var accent_color: Color = Color(0.26, 0.62, 0.36, 1.0);

@onready var title_label: Label = %TitleLabel;
@onready var accent_rect: ColorRect = %AccentRect;

func _ready() -> void:
	_refresh_view();

func _refresh_view() -> void:
	if not label_text.is_empty():
		title_label.text = label_text;
	accent_rect.color = accent_color;