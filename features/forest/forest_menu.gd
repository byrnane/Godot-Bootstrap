extends Control
class_name ForestMenu

signal session_start_requested(params: SessionStartParams)
signal new_game_requested
signal continue_requested
signal settings_requested
signal save_slots_requested
signal quit_requested

var _progress_labels: Dictionary = {}
var _play_buttons: Dictionary = {}
var _restart_buttons: Dictionary = {}
var _continue_button: Button
var _fullscreen_button: Button
var _profile: Dictionary = {}

func _ready() -> void:
	theme = ForestArt.ui_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background: TextureRect = TextureRect.new()
	background.texture = ForestArt.texture("forest_panorama")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025, 0.065, 0.07, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var particles: CPUParticles2D = ForestArt.fireflies(self, get_viewport_rect().size)
	get_viewport().size_changed.connect(func() -> void:
		particles.position = get_viewport_rect().size / 2
		particles.emission_rect_extents = get_viewport_rect().size / 2
	)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var margin: MarginContainer = ForestArt.margin(6)
	center.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 616
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)
	var heading: VBoxContainer = VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(ForestArt.label("UI_FOREST_TITLE", &"UiDisplay"))
	heading.add_child(ForestArt.label("UI_FOREST_TAGLINE", &"UiBody"))
	_continue_button = ForestArt.button("UI_CONTINUE", _continue_last, true)
	_continue_button.custom_minimum_size.x = 112
	_continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_continue_button)
	var cards: HBoxContainer = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 4)
	column.add_child(cards)
	for mode: String in ForestData.MODES:
		cards.add_child(_make_card(mode))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	for item: Array in [["UI_SETTINGS", func() -> void: settings_requested.emit()], ["UI_SAVE_SLOTS", func() -> void: save_slots_requested.emit()]]:
		var button: Button = ForestArt.button(item[0], item[1])
		button.icon = ForestArt.texture("ui_settings" if item[0] == "UI_SETTINGS" else "ui_save")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	if OS.has_feature("web"):
		_fullscreen_button = ForestArt.button("UI_FOREST_FULLSCREEN", _toggle_fullscreen)
		_fullscreen_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fullscreen_button.toggle_mode = true
		actions.add_child(_fullscreen_button)
	else:
		var quit: Button = ForestArt.button("UI_QUIT", func() -> void: quit_requested.emit())
		quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(quit)
	var note: Label = ForestArt.label("UI_FOREST_SAVE_NOTE", &"UiSmall")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	AudioManager.bind_ui_sounds(self)
	_refresh()
	set_process(_fullscreen_button != null)

func _process(_delta: float) -> void:
	# Browser Escape and the settings dialog can change fullscreen independently.
	_fullscreen_button.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_fullscreen() -> void:
	var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _make_card(mode: String) -> PanelContainer:
	var panel: PanelContainer = ForestArt.panel()
	panel.custom_minimum_size.x = 200
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin: MarginContainer = ForestArt.margin(6)
	panel.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var artwork: TextureRect = TextureRect.new()
	artwork.texture = ForestArt.texture("keeper_side" if mode == "platformer" else ("shadow" if mode == "shooter" else "stone_gate"))
	artwork.custom_minimum_size = Vector2(0, 40)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(artwork)
	content.add_child(ForestArt.label(ForestData.TITLES[mode], &"UiSection"))
	var description: Label = ForestArt.label("UI_FOREST_DESC_" + mode.to_upper(), &"UiBody")
	description.custom_minimum_size.y = 44
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	var progress: Label = ForestArt.label("", &"UiLabel")
	content.add_child(progress)
	_progress_labels[mode] = progress
	var play: Button = ForestArt.button("UI_FOREST_PLAY", func() -> void: _start(mode), true)
	content.add_child(play)
	_play_buttons[mode] = play
	var restart: Button = ForestArt.button("UI_FOREST_RESTART_MODE", func() -> void: _confirm_restart(mode))
	restart.theme_type_variation = &"UiButtonGhost"
	restart.custom_minimum_size.y = 22
	content.add_child(restart)
	_restart_buttons[mode] = restart
	return panel

func on_enter(_payload: SceneTransitionPayload = null) -> void:
	_refresh()
	focus_default_control()

func focus_default_control() -> void:
	if not InputManager.ui_navigation_active:
		return
	if not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_play_buttons.platformer.grab_focus()

func _refresh() -> void:
	if not is_node_ready():
		return
	_profile = ForestData.menu_profile()
	var any_started: bool = false
	for mode: String in ForestData.MODES:
		var entry: Dictionary = _profile.progress[mode]
		any_started = any_started or entry.started
		_progress_labels[mode].text = tr("UI_FOREST_COMPLETE") if entry.completed else (tr("UI_FOREST_STAGE") % (int(entry.stage) + 1) if entry.started else tr("UI_FOREST_NOT_STARTED"))
		_play_buttons[mode].text = tr("UI_FOREST_PLAY_AGAIN" if entry.completed else ("UI_CONTINUE" if entry.started else "UI_FOREST_PLAY"))
		_restart_buttons[mode].disabled = not entry.started
	_continue_button.disabled = not any_started

func _start(mode: String) -> void:
	if bool(_profile.progress[mode].completed):
		_confirm_restart(mode)
	else:
		session_start_requested.emit(ForestData.start_params(mode))

func _continue_last() -> void:
	session_start_requested.emit(ForestData.start_params(_profile.mode_id))

func _confirm_restart(mode: String) -> void:
	UiFeedback.confirm(tr("UI_FOREST_CONFIRM_RESTART") % tr(ForestData.TITLES[mode]), func() -> void: session_start_requested.emit(ForestData.start_params(mode, true)), Callable(), {"title": tr("UI_FOREST_RESTART_MODE"), "confirm_text": tr("UI_FOREST_RESTART_MODE")})

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
