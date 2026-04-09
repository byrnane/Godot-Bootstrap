extends HBoxContainer;
class_name UiActionBar;


@export_enum("start", "center", "end") var content_alignment: String = "end":
	set(value):
		content_alignment = value;
		_apply_alignment();


func _ready() -> void:
	add_theme_constant_override("separation", 8);
	_apply_alignment();


func _apply_alignment() -> void:
	if not is_node_ready():
		return;

	match content_alignment:
		"start":
			alignment = BoxContainer.ALIGNMENT_BEGIN;
		"center":
			alignment = BoxContainer.ALIGNMENT_CENTER;
		_:
			alignment = BoxContainer.ALIGNMENT_END;
