@tool
extends BoxContainer;
class_name UiActionBar;


@export_enum("start", "center", "end") var content_alignment: String = "end":
	set(value):
		content_alignment = value;
		_apply_alignment();


func _ready() -> void:
	add_theme_constant_override("separation", 12);
	if preload("res://shared/ui/theme/ui_density.gd").is_compact(self):
		var actions: Array[Node] = get_children();
		var flow: HFlowContainer = HFlowContainer.new();
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		flow.alignment = FlowContainer.ALIGNMENT_END;
		flow.add_theme_constant_override("h_separation", 8);
		flow.add_theme_constant_override("v_separation", 8);
		add_child(flow);
		for action: Node in actions:
			action.reparent(flow);
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
