extends Control

signal pause_requested
signal restart_requested
signal menu_requested

var resources: UiResources
var objective: Control
var ammo: Label
var interaction_label: Label
var instructions: Label
var center: Label
var overlay: PanelContainer
var result_title: Label
var result_copy: Label
var restart_button: Button
var menu_button: Button
var pause_button: Button
var last_outcome: String = ""
var data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resources = preload("res://shared/ui/components/ui_resources.tscn").instantiate()
	add_child(resources)
	resources.position = Vector2(24, 24)
	resources.custom_minimum_size = Vector2(280, 0)
	objective = preload("res://shared/ui/components/ui_objective.tscn").instantiate()
	add_child(objective)
	place(objective, Control.PRESET_BOTTOM_LEFT, Rect2(24, -128, 350, 92))
	objective.custom_minimum_size = Vector2(350, 92)
	ammo = _label(self, 30)
	place(ammo, Control.PRESET_BOTTOM_RIGHT, Rect2(-330, -100, 300, 60))
	ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	instructions = _label(self, 18)
	place(instructions, Control.PRESET_TOP_RIGHT, Rect2(-620, 24, 520, 80))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	center = _label(self, 28)
	center.text = "+"
	place(center, Control.PRESET_CENTER, Rect2(-14, -22, 28, 44))
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label = _label(self, 24)
	place(interaction_label, Control.PRESET_CENTER_BOTTOM, Rect2(-420, -180, 840, 50))
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = tr("UI_PAUSE_TITLE")
	add_child(pause_button)
	place(pause_button, Control.PRESET_TOP_RIGHT, Rect2(-76, 24, 52, 48))
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	overlay = PanelContainer.new()
	add_child(overlay)
	place(overlay, Control.PRESET_CENTER, Rect2(-270, -175, 540, 350))
	overlay.custom_minimum_size = Vector2(540, 350)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	overlay.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	result_title = _label(column, 30)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_copy = _label(column, 20)
	result_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restart_button = Button.new()
	restart_button.custom_minimum_size.y = 48
	column.add_child(restart_button)
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button = Button.new()
	menu_button.custom_minimum_size.y = 48
	column.add_child(menu_button)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	overlay.visible = false
	AudioManager.bind_ui_sounds(self)

func place(control: Control, preset: int, rect: Rect2) -> void:
	control.set_anchors_and_offsets_preset(preset)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _label(parent_node: Node, font_size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.025, 0.02, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent_node.add_child(label)
	return label

func apply_view_model(value: Dictionary) -> void:
	data = value
	if resources == null:
		return
	resources.apply_resources({"health": data.get("health", 100), "max_health": 100})
	resources.reset_size()
	objective.text = tr("P3_OBJECTIVE").format({"count": data.get("remaining", 5)}) if int(data.get("remaining", 5)) > 0 else tr("P3_OBJECTIVE_EXIT")
	ammo.text = tr("P3_RELOADING") if data.get("reloading", false) else "%02d / %02d" % [data.get("magazine", 8), data.get("reserve", 24)]
	instructions.text = tr("P3_HINTS").format({"view": InputManager.get_action_binding_text(&"proto_view"), "reload": InputManager.get_action_binding_text(&"proto_reload"), "pause": InputManager.get_action_binding_text(&"ui_pause")})
	interaction_label.text = ""
	if not str(data.get("interaction", "")).is_empty():
		interaction_label.text = "[%s] %s" % [InputManager.get_action_binding_text(&"proto_interact"), tr(data.interaction)]
	elif not data.get("captured", true):
		interaction_label.text = tr("P3_CLICK_TO_PLAY")
	var outcome: String = str(data.get("outcome", ""))
	overlay.visible = not outcome.is_empty()
	center.visible = outcome.is_empty()
	if overlay.visible:
		result_title.text = tr("P3_WON" if outcome == "won" else "P3_DEAD")
		result_copy.text = tr("P3_RESULT_COPY")
		restart_button.text = tr("P3_RESTART")
		menu_button.text = tr("P3_MENU")
		if outcome != last_outcome:
			restart_button.grab_focus()
	last_outcome = outcome
