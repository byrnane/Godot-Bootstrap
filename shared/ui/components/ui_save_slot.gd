@tool
extends Button;
class_name UiSaveSlot;

## A selectable view only. File IO and save actions belong to SaveManager/caller.
@export var title: String = "":
	set(value):
		title = value;
		_refresh();
@export var detail: String = "":
	set(value):
		detail = value;
		_refresh();
@export var preview: Texture2D:
	set(value):
		preview = value;
		_refresh();

func _ready() -> void:
	if preload("res://shared/ui/theme/ui_density.gd").is_compact(self) and not Engine.is_editor_hint():
		preload("res://shared/ui/theme/ui_density.gd").fit_controls(self);
		custom_minimum_size = Vector2(0, 64);
		%Preview.custom_minimum_size = Vector2(64, 36);
	_refresh();

func _refresh() -> void:
	if not is_node_ready():
		return;
	%Title.text = title;
	%Detail.text = detail;
	%Preview.texture = preview;
	tooltip_text = title + "\n" + detail;

