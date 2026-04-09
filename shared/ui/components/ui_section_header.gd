extends VBoxContainer;
class_name UiSectionHeader;


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
	_refresh();


func _refresh() -> void:
	if not is_node_ready():
		return;

	title_label.text = tr(title_key) if not title_key.is_empty() else "";
	description_label.visible = not description_key.is_empty();
	description_label.text = tr(description_key) if not description_key.is_empty() else "";
