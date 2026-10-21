extends Control
class_name ForestHud

signal pause_requested
signal retry_requested
signal primary_requested
signal menu_requested

var _title: Label
var _metrics: Label
var _objective: Label
var _hint: Label
var _result_layer: CenterContainer
var _result: UiResultContent
var _view: Dictionary = {}
var _result_state: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: MarginContainer = ForestArt.margin(24)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var panel: PanelContainer = ForestArt.panel()
	top.add_child(panel)
	var inset: MarginContainer = ForestArt.margin(18)
	panel.add_child(inset)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	inset.add_child(column)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	_title = ForestArt.label("", &"UiSection")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_metrics = ForestArt.label("", &"UiLabel")
	_metrics.autowrap_mode = TextServer.AUTOWRAP_OFF
	_metrics.custom_minimum_size.x = 180
	_metrics.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_metrics)
	var pause_button: Button = ForestArt.button("UI_GAMEPLAY_PAUSE", func() -> void: pause_requested.emit())
	pause_button.focus_mode = Control.FOCUS_NONE
	row.add_child(pause_button)
	_objective = ForestArt.label("", &"UiBody")
	column.add_child(_objective)
	var bottom: MarginContainer = ForestArt.margin(24)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	var hints_panel: PanelContainer = ForestArt.panel()
	bottom.add_child(hints_panel)
	var hints_margin: MarginContainer = ForestArt.margin(12)
	hints_panel.add_child(hints_margin)
	_hint = ForestArt.label("", &"UiLabel")
	hints_margin.add_child(_hint)
	_result_layer = CenterContainer.new()
	_result_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_layer)
	var result_panel: PanelContainer = ForestArt.panel()
	result_panel.custom_minimum_size = Vector2(620, 300)
	_result_layer.add_child(result_panel)
	var result_margin: MarginContainer = ForestArt.margin(32)
	result_panel.add_child(result_margin)
	_result = preload("res://shared/ui/components/ui_result_content.tscn").instantiate()
	result_margin.add_child(_result)
	_result.primary_requested.connect(func() -> void: primary_requested.emit())
	_result.secondary_requested.connect(func() -> void: menu_requested.emit())
	_result_layer.hide()

func apply_view_model(view: Dictionary) -> void:
	_view = view.duplicate(true)
	if not is_node_ready():
		return
	var mode: String = str(view.get("mode_id", "platformer"))
	_title.text = tr(ForestData.TITLES[mode]) + "  ·  " + tr("UI_FOREST_STAGE") % int(view.get("stage", 1))
	var hearts: String = "● ".repeat(int(view.get("health", 0)))
	_metrics.text = hearts + "   " + tr("UI_FOREST_SCORE") % int(view.get("score", 0))
	_objective.text = str(view.get("metric", "")) + "   ·   " + tr("UI_FOREST_GOAL_" + mode.to_upper())
	var pad: bool = InputManager.last_device == &"gamepad"
	var movement: String = "L / D-pad" if pad else InputManager.get_action_binding_text(&"keeper_left") + " / " + InputManager.get_action_binding_text(&"keeper_right")
	if not pad and mode != "platformer":
		movement = InputManager.get_action_binding_text(&"keeper_up") + " / " + InputManager.get_action_binding_text(&"keeper_left") + " / " + InputManager.get_action_binding_text(&"keeper_down") + " / " + InputManager.get_action_binding_text(&"keeper_right")
	var action: String = ""
	if mode == "platformer":
		action = ("A" if pad else InputManager.get_action_binding_text(&"keeper_jump")) + " — " + tr("UI_FOREST_JUMP")
	elif mode == "shooter":
		action = ("R-stick · RT" if pad else tr("UI_FOREST_MOUSE") + " · " + InputManager.get_action_binding_text(&"keeper_fire")) + " — " + tr("UI_FOREST_AIM_FIRE")
	var pause_keys: String = "Start" if pad else InputManager.get_action_binding_text(&"ui_cancel") + " / " + InputManager.get_action_binding_text(&"ui_pause")
	_hint.text = movement + " — " + tr("UI_FOREST_MOVE") + "    " + action + "    " + ("Y" if pad else InputManager.get_action_binding_text(&"keeper_retry")) + " — " + tr("UI_FOREST_RETRY") + "    " + pause_keys + " — " + tr("UI_GAMEPLAY_PAUSE")
	if _result_layer.visible:
		_render_result()

func show_result(victory: bool, complete: bool, score: int) -> void:
	_result_state = {"victory": victory, "complete": complete, "score": score}
	_render_result()
	_result_layer.show()
	_result.get_node("%Primary").grab_focus()

func _render_result() -> void:
	if _result_state.is_empty():
		return
	var victory: bool = _result_state.victory
	var complete: bool = _result_state.complete
	var primary: String = "UI_FOREST_NEXT" if victory and not complete else "UI_FOREST_RETRY"
	if victory and complete:
		primary = "UI_FOREST_PLAY_AGAIN"
	var hint_key: String = "UI_FOREST_RESULT_HINT" if victory else "UI_FOREST_DEFEAT_HINT"
	if victory and complete:
		hint_key = "UI_FOREST_COMPLETE_HINT"
	_result.configure(tr("UI_FOREST_COMPLETE" if complete and victory else ("UI_FOREST_VICTORY" if victory else "UI_FOREST_DEFEAT")), tr(hint_key), {tr("UI_FOREST_SCORE_LABEL"): _result_state.score}, tr(primary), tr("UI_BACK_TO_MENU"))

func hide_result() -> void:
	_result_state.clear()
	_result_layer.hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		apply_view_model(_view)
