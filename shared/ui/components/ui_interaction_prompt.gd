@tool
extends PanelContainer;
class_name UiInteractionPrompt;

@export var key_text: String = "E":
	set(value):
		key_text = value;
		_refresh();
@export var text: String = "":
	set(value):
		text = value;
		_refresh();

func _ready() -> void:
	_refresh();

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh();

func _refresh() -> void:
	if is_node_ready():
		%Key.text = key_text;
		%Text.text = tr(text);
