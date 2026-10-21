@tool
extends VBoxContainer;
class_name UiVolumeRow;

@export var title_key: String = "":
	set(value):
		title_key = value;
		_refresh();
@export_range(0.0, 1.0, 0.01) var value: float = 1.0:
	set(new_value):
		value = clampf(new_value, 0.0, 1.0);
		_refresh();

@onready var slider: HSlider = %Slider;

func _ready() -> void:
	slider.value_changed.connect(func(new_value: float) -> void: value = new_value);
	_refresh();

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh();

func _refresh() -> void:
	if not is_node_ready():
		return;
	%Title.text = tr(title_key);
	slider.set_value_no_signal(value);
	%Value.text = "%d%%" % roundi(value * 100.0);

