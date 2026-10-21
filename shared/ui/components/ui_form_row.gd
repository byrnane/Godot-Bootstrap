@tool
extends BoxContainer;
class_name UiFormRow;


@export var stacked: bool = false:
	set(value):
		stacked = value;
		_apply_layout();
@export var compact: bool = false:
	set(value):
		compact = value;
		_apply_layout();

@export var title_key: String = "":
	set(value):
		title_key = value;
		_refresh();

@export_multiline var description_key: String = "":
	set(value):
		description_key = value;
		_refresh();


@onready var title_label: Label = %TitleLabel;
@onready var description_label: Label = %DescriptionLabel;


func _ready() -> void:
	_apply_layout();
	_refresh();


func _apply_layout() -> void:
	if not is_node_ready():
		return;
	vertical = stacked;
	%Content.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_SHRINK_END;
	title_label.theme_type_variation = &"UiSmall" if compact else &"UiLabel";
	for control: Node in %Content.get_children():
		if control is SpinBox:
			(control as SpinBox).get_line_edit().theme_type_variation = &"UiNumberEdit" if compact else &"";


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh();


func _refresh() -> void:
	if not is_node_ready():
		return;

	tooltip_text = tr(title_key) if not title_key.is_empty() else "";
	title_label.text = tr(title_key) if not title_key.is_empty() else "";
	description_label.visible = not description_key.is_empty();
	description_label.text = tr(description_key) if not description_key.is_empty() else "";
