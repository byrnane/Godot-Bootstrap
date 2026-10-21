@tool
extends TextureRect;

func _ready() -> void:
	texture = get_theme_icon(&"spinner", &"UiIcons");
	resized.connect(func() -> void: pivot_offset = size / 2.0);
	pivot_offset = size / 2.0;
	set_process(not Engine.is_editor_hint());

func _process(delta: float) -> void:
	rotation += delta * TAU * 0.7;

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
		texture = get_theme_icon(&"spinner", &"UiIcons");

