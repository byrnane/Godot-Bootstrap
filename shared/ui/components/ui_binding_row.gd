@tool
extends HBoxContainer;
class_name UiBindingRow;

signal binding_requested(slot: int);

@export var title_key: String = "":
	set(value):
		title_key = value;
		_refresh_title();

func _ready() -> void:
	%Primary.pressed.connect(func() -> void: binding_requested.emit(0));
	%Secondary.pressed.connect(func() -> void: binding_requested.emit(1));
	_refresh_title();

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_title();

func get_binding_buttons() -> Array[Button]:
	return [%Primary, %Secondary];

func _refresh_title() -> void:
	if is_node_ready():
		%Title.text = tr(title_key);

