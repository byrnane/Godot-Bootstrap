extends RefCounted;
class_name UiFocus;


static func capture(viewport: Viewport) -> Control:
	if viewport == null:
		return null;
	return viewport.gui_get_focus_owner() as Control;


static func restore(control: Variant) -> bool:
	if not (control is Control):
		return false;
	var focus_target: Control = control as Control;
	if not is_instance_valid(control):
		return false;
	if not focus_target.is_inside_tree():
		return false;
	if not focus_target.visible:
		return false;
	if focus_target.focus_mode == Control.FOCUS_NONE:
		return false;

	focus_target.grab_focus();
	return true;


static func grab_path(owner: Node, focus_path: NodePath) -> bool:
	if owner == null or focus_path.is_empty():
		return false;
	return restore(owner.get_node_or_null(focus_path) as Control);


static func find_first_focusable(node: Node) -> Control:
	if node == null:
		return null;
	if node is Control:
		var control: Control = node as Control;
		if control.visible and control.focus_mode != Control.FOCUS_NONE:
			return control;

	for child: Node in node.get_children():
		var focusable: Control = find_first_focusable(child);
		if focusable != null:
			return focusable;

	return null;
