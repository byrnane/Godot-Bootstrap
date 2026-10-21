extends RefCounted;
class_name UiDensity;

## Density follows the logical viewport, so copied games need no branch metadata.
static func is_compact(control: Control) -> bool:
	var viewport_size: Vector2 = control.get_viewport_rect().size;
	return viewport_size.x < 960.0 or viewport_size.y < 540.0;


static func apply(root: Control) -> bool:
	if not is_compact(root):
		return false;
	var source: Theme = root.theme;
	var parent: Node = root.get_parent();
	while source == null and parent != null:
		if parent is Control:
			source = parent.theme;
		parent = parent.get_parent();
	if source == null:
		source = load(ProjectSettings.get_setting("gui/theme/custom"));
	var compact_theme: Theme = source.duplicate(true);
	compact_theme.default_font_size = 16;
	compact_theme.set_constant("icon_max_width", "Button", 20);
	for type_name: StringName in compact_theme.get_type_list():
		for font_size_name: StringName in compact_theme.get_font_size_list(type_name):
			compact_theme.set_font_size(font_size_name, type_name, mini(compact_theme.get_font_size(font_size_name, type_name), 16));
		for style_name: StringName in compact_theme.get_stylebox_list(type_name):
			var style: StyleBox = compact_theme.get_stylebox(style_name, type_name);
			style.content_margin_left = minf(style.content_margin_left, 8.0);
			style.content_margin_right = minf(style.content_margin_right, 8.0);
			style.content_margin_top = minf(style.content_margin_top, 4.0);
			style.content_margin_bottom = minf(style.content_margin_bottom, 4.0);
	for role: String in ["UiHero", "UiDisplay"]:
		compact_theme.set_font_size("font_size", role, 32);
	compact_theme.set_font_size("font_size", "UiHeading", 24);
	compact_theme.set_font_size("font_size", "UiSection", 20);
	for role: String in ["UiSmall", "UiCaption"]:
		compact_theme.set_font_size("font_size", role, 12);
	root.theme = compact_theme;
	fit_controls(root);
	return true;


static func fit_controls(root: Control) -> void:
	var controls: Array[Node] = [root];
	controls.append_array(root.find_children("*", "Control", true, false));
	for node: Node in controls:
		var control: Control = node as Control;
		control.custom_minimum_size = Vector2(minf(control.custom_minimum_size.x, 560.0), minf(control.custom_minimum_size.y, 32.0));
		if control is Button:
			control.custom_minimum_size.y = 32;
			control.expand_icon = true;
		if control is MarginContainer:
			for side: String in ["left", "right", "top", "bottom"]:
				control.add_theme_constant_override("margin_" + side, mini(control.get_theme_constant("margin_" + side), 8));
		if control is BoxContainer:
			control.add_theme_constant_override("separation", mini(control.get_theme_constant("separation"), 8));
		if control is Label and control.autowrap_mode != TextServer.AUTOWRAP_OFF:
			control.custom_minimum_size.x = 0;


static func fill(control: Control, margin: float = 16.0) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);
	control.offset_left = margin;
	control.offset_top = margin;
	control.offset_right = -margin;
	control.offset_bottom = -margin;


static func place(control: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(preset);
	control.offset_left = rect.position.x;
	control.offset_top = rect.position.y;
	control.offset_right = rect.end.x;
	control.offset_bottom = rect.end.y;
