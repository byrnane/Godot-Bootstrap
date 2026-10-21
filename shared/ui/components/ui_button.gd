@tool
extends Button;
class_name UiButton;

## Optional semantic icon; appearance/states remain native Theme variations.
@export var icon_role: StringName = &"":
	set(value):
		if not icon_role.is_empty() and value.is_empty():
			icon = null;
		icon_role = value;
		_refresh_icon();

func _ready() -> void:
	_refresh_icon();

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_icon();

func _refresh_icon() -> void:
	if is_inside_tree() and not icon_role.is_empty():
		icon = get_theme_icon(icon_role, &"UiIcons") if has_theme_icon(icon_role, &"UiIcons") else null;

