extends RefCounted;
class_name UiFocus;


static func capture(viewport: Viewport) -> Control:
	if viewport == null:
		return null;
	return viewport.gui_get_focus_owner() as Control;


static func restore(control: Variant) -> bool:
	if not is_instance_valid(control) or not (control is Control):
		return false;
	var focus_target: Control = control as Control;
	if not focus_target.is_inside_tree():
		return false;
	if not focus_target.is_visible_in_tree():
		return false;
	if focus_target.get_focus_mode_with_override() == Control.FOCUS_NONE:
		return false;
	if focus_target is BaseButton and (focus_target as BaseButton).disabled:
		return false;

	focus_target.grab_focus();
	return true;


static func release_navigation_focus(viewport: Viewport, pointer_press: InputEventMouseButton = null) -> void:
	var owner: Control = capture(viewport);
	if owner == null:
		return;
	if owner is LineEdit or owner is TextEdit:
		# Keep editing while moving the pointer or clicking inside this field.
		# An actual click outside it gives up the caret, including on empty space.
		if pointer_press == null:
			return;
		var local_position: Vector2 = owner.get_global_transform_with_canvas().affine_inverse() * pointer_press.position;
		if Rect2(Vector2.ZERO, owner.size).has_point(local_position):
			return;
	owner.release_focus();


static func grab_path(owner: Node, focus_path: NodePath) -> bool:
	if owner == null or focus_path.is_empty():
		return false;
	return restore(owner.get_node_or_null(focus_path) as Control);


static func find_first_focusable(node: Node) -> Control:
	if node == null:
		return null;
	if node is Control:
		var control: Control = node as Control;
		if control.is_visible_in_tree() and control.get_focus_mode_with_override() != Control.FOCUS_NONE and not (control is BaseButton and (control as BaseButton).disabled):
			return control;

	for child: Node in node.get_children():
		var focusable: Control = find_first_focusable(child);
		if focusable != null:
			return focusable;

	return null;


static func apply_vertical_focus_cycle(buttons: Array[Button]) -> void:
	if buttons.size() <= 1:
		return;

	for button_index: int in range(buttons.size()):
		var current_button: Button = buttons[button_index];
		var previous_button: Button = buttons[(button_index - 1 + buttons.size()) % buttons.size()];
		var next_button: Button = buttons[(button_index + 1) % buttons.size()];
		current_button.focus_neighbor_top = current_button.get_path_to(previous_button);
		current_button.focus_neighbor_bottom = current_button.get_path_to(next_button);
