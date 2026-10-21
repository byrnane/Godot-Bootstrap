@tool
extends HBoxContainer;
class_name UiCounter;

@export var icon_role: StringName = &"":
	set(new_role):
		icon_role = new_role;
		_refresh();
@export var icon: Texture2D:
	set(new_icon):
		icon = new_icon;
		_refresh();
@export var value: String = "0":
	set(new_value):
		value = new_value;
		_refresh();

func _ready() -> void:
	_refresh();

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh();

func _refresh() -> void:
	if not is_node_ready():
		return;
	var resolved_icon: Texture2D = icon;
	if not icon_role.is_empty():
		resolved_icon = get_theme_icon(icon_role, &"UiIcons") if has_theme_icon(icon_role, &"UiIcons") else null;
	%Icon.texture = resolved_icon;
	%Icon.visible = resolved_icon != null;
	%Value.text = value;

