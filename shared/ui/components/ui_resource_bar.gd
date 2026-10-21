@tool
extends VBoxContainer;
class_name UiResourceBar;

## Passive resource view. The caller owns gameplay values and regeneration.
@export_enum("health", "mana", "stamina") var kind: String = "health":
	set(new_kind):
		kind = new_kind;
		_refresh();
@export var title_key: String = "UI_RESOURCE_HEALTH":
	set(new_title):
		title_key = new_title;
		_refresh();
@export var current: float = 80.0:
	set(new_value):
		current = new_value;
		_refresh();
@export var maximum: float = 100.0:
	set(new_maximum):
		maximum = maxf(new_maximum, 0.0);
		_refresh();

func _ready() -> void:
	_refresh();

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED:
		_refresh();

func set_amount(amount: float, capacity: float) -> void:
	maximum = capacity;
	current = amount;

func _refresh() -> void:
	if not is_node_ready():
		return;
	%Title.text = tr(title_key);
	%Icon.texture = get_theme_icon(StringName(kind), &"UiResourceBar");
	%Icon.self_modulate = get_theme_color(StringName(kind), &"UiTokens");
	%Value.text = "%d / %d" % [clampf(current, 0.0, maximum), maximum];
	%Bar.max_value = maxf(maximum, 1.0);
	%Bar.value = clampf(current, 0.0, maximum);
	%Bar.theme_type_variation = StringName("Ui%sBar" % kind.capitalize());

