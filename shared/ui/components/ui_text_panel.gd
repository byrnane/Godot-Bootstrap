@tool
extends PanelContainer;
class_name UiTextPanel;

## Objective, level badge and tooltip share this small text-view contract.
@export var caption_key: String = "":
	set(value):
		caption_key = value;
		_refresh();
@export_multiline var text: String = "":
	set(value):
		text = value;
		_refresh();

func _ready() -> void:
	_refresh();

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh();

func _refresh() -> void:
	if not is_node_ready():
		return;
	%Caption.visible = not caption_key.is_empty();
	%Caption.text = tr(caption_key);
	%Text.text = tr(text);

