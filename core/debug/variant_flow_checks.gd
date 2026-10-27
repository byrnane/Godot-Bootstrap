extends RefCounted

static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	AppContext.settings.autosave_enabled = false
	await host._expect_transition(Callable(AppFlow, "start_new_game"), Scenes.GAMEPLAY, AppState.Value.IN_GAME, "forest: first game")
	var game: ForestGame = SceneRouter.current_scene_root
	_check(game.world is ForestPlatformer, "platformer did not mount", failures)
	for frame: int in range(20):
		await host.get_tree().physics_frame
	var start_y: float = game.world.player.position.y
	Input.action_press("keeper_jump")
	for frame: int in range(8):
		await host.get_tree().physics_frame
	Input.action_release("keeper_jump")
	_check(game.world.player.position.y < start_y - 20, "real jump input did not move the character", failures)
	game.world.player.position = Vector2(1510, 540)
	for frame: int in range(3):
		await host.get_tree().physics_frame
	_check(SessionContext.game_data.progress.platformer.checkpoint == 1, "lantern did not update checkpoint", failures)
	game.world.take_damage()
	game.world.take_damage()
	_check(game.world.health == 2, "damage invulnerability failed", failures)
	_check(SaveManager.save_current_session_to_quick(), "checkpoint quick save failed", failures)
	var saved: SaveData = SaveManager.load_game_from_descriptor(SaveManager.descriptor_for_quick())
	_check(saved != null and saved.player_health == 3 and saved.game_data.progress.platformer.checkpoint == 1, "save stored live damage instead of checkpoint", failures)
	await _menu(host)
	await _start(host, "shooter")
	game = SceneRouter.current_scene_root
	_check(SessionContext.game_data.progress.platformer.checkpoint == 1, "switch discarded unsaved platformer checkpoint", failures)
	for wave: int in range(3):
		var shooter: ForestShooter = game.world
		_check(shooter.enemies.size() == ForestShooter.WAVE_COUNTS[wave], "wrong wave population", failures)
		if wave == 0:
			shooter.enemies[0].node.position = Vector2(0, 110)
			shooter.fire(Vector2.DOWN)
			for frame: int in range(18):
				await host.get_tree().physics_frame
			_check(shooter.enemies.size() == 5, "projectile did not hit shadow", failures)
		while not shooter.enemies.is_empty():
			shooter.defeat_enemy(0)
		for frame: int in range(2):
			await host.get_tree().physics_frame
		_check(shooter.finished, "empty wave did not finish", failures)
		if wave < 2:
			game._on_result_primary()
	_check(SessionContext.game_data.progress.shooter.completed, "shooter finale was not recorded", failures)
	await _menu(host)
	await _start(host, "puzzle")
	game = SceneRouter.current_scene_root
	var solutions: Array[String] = ["RRRDRRU", "RRRRLLLDDRRRDRRRU", "RRRRRRLLLLLDDRRRRRDRRRU"]
	for stage: int in range(3):
		var puzzle: ForestPuzzle = game.world
		_check(not puzzle.gate_open(), "puzzle gate starts open", failures)
		var original: Vector2i = puzzle.player_cell
		puzzle.player_cell = Vector2i(1, 1)
		_check(not puzzle.try_move(Vector2i.LEFT), "player walked through a wall", failures)
		puzzle.player_cell = original
		for step: String in solutions[stage]:
			var direction: Vector2i = {"R": Vector2i.RIGHT, "L": Vector2i.LEFT, "D": Vector2i.DOWN, "U": Vector2i.UP}[step]
			_check(puzzle.try_move(direction), "known solution blocked in room %d" % stage, failures)
		_check(puzzle.finished and puzzle.gate_open(), "room did not complete after solution", failures)
		if stage < 2:
			game._on_result_primary()
	_check(SessionContext.game_data.progress.puzzle.completed, "puzzle finale was not recorded", failures)
	await _menu(host)
	await _start(host, "platformer", true)
	game = SceneRouter.current_scene_root
	_check(SessionContext.game_data.progress.shooter.completed and SessionContext.game_data.progress.puzzle.completed, "restart wiped adjacent modes", failures)
	_check(SessionContext.game_data.progress.platformer.checkpoint == 0, "restart kept old platformer checkpoint", failures)
	for stage: int in range(3):
		_check(game.world.stage == stage, "platformer stage did not advance", failures)
		game.world.player.position = Vector2(3120, 530)
		for frame: int in range(2):
			await host.get_tree().physics_frame
		_check(game.world.finished, "platformer gate did not finish stage", failures)
		if stage < 2:
			game._on_result_primary()
	_check(SessionContext.game_data.progress.platformer.completed, "platformer finale was not recorded", failures)
	# A manual snapshot restores all modes, including earlier progress of other games.
	var descriptor: Dictionary = SaveManager.save_current_session_to_new_manual_slot()
	_check(not descriptor.is_empty(), "manual profile snapshot failed", failures)
	game.restart_mode()
	_check(not SessionContext.game_data.progress.platformer.completed, "mode restart had no effect", failures)
	await host._expect_transition(Callable(AppFlow, "load_session_from_slot").bind(descriptor), Scenes.GAMEPLAY, AppState.Value.IN_GAME, "forest: load profile snapshot")
	_check(SessionContext.game_data.progress.platformer.completed and SessionContext.game_data.progress.shooter.completed and SessionContext.game_data.progress.puzzle.completed, "manual load did not restore entire profile", failures)
	_check(ForestData.normalized({}, Scenes.LEVEL_STUB_B).progress.platformer.stage == 1, "legacy B migration lost stage", failures)
	var legacy: SaveData = SaveData.from_variant({"version": 2, "session_exists": true, "current_level_id": "level_stub_b", "score": 42})
	var legacy_profile: Dictionary = ForestData.profile_from_save(legacy)
	_check(legacy_profile.progress.platformer.started and legacy_profile.progress.platformer.score == 42, "legacy continue lost score or became unavailable", failures)
	var malformed: Dictionary = ForestData.normalized({"revision": [], "progress": {"platformer": {"stage": [], "score": {}, "completed": []}}})
	_check(malformed.revision == 0 and malformed.progress.platformer.stage == 0, "malformed profile did not recover safely", failures)
	# Real joypad and keyboard events must change both movement and hint device.
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.8
	Input.parse_input_event(motion)
	await host.get_tree().process_frame
	_check(InputManager.last_device == &"gamepad" and Input.get_action_strength("keeper_right") > 0.5, "gamepad move mapping failed", failures)
	motion.axis_value = 0.0
	Input.parse_input_event(motion)
	var keyboard: InputEventKey = InputEventKey.new()
	keyboard.physical_keycode = KEY_D
	keyboard.pressed = true
	Input.parse_input_event(keyboard)
	await host.get_tree().process_frame
	_check(InputManager.last_device == &"keyboard", "keyboard did not restore device hints", failures)
	keyboard.pressed = false
	Input.parse_input_event(keyboard)
	for pair: Array in [[KEY_LEFT, "keeper_left"], [KEY_RIGHT, "keeper_right"], [KEY_UP, "keeper_up"], [KEY_DOWN, "keeper_down"]]:
		var arrow: InputEventKey = InputEventKey.new()
		arrow.physical_keycode = pair[0]
		arrow.pressed = true
		Input.parse_input_event(arrow)
		await host.get_tree().process_frame
		_check(Input.is_action_pressed(pair[1]), "arrow mapping failed: " + pair[1], failures)
		arrow.pressed = false
		Input.parse_input_event(arrow)
	# Rebinding while paused must update hints without a new gameplay event.
	AppFlow.request_pause()
	var hud: ForestHud = UiShell.get_current_hud()
	for binding: Array in [[&"keeper_jump", KEY_F5], [&"keeper_retry", KEY_F6], [&"ui_pause", KEY_F7], [&"ui_cancel", KEY_F8]]:
		var old_hint: String = hud._hint.text
		var replacement: InputEventKey = InputEventKey.new()
		replacement.keycode = binding[1]
		replacement.physical_keycode = binding[1]
		InputManager.start_rebind(binding[0])
		InputManager._apply_rebind(binding[0], replacement)
		_check(hud._hint.text != old_hint and hud._hint.text.contains(InputManager.get_action_binding_text(binding[0])), "rebound hint stayed stale: " + String(binding[0]), failures)
	InputManager.reset_to_defaults()
	var pause_space: InputEventKey = InputEventKey.new()
	pause_space.keycode = KEY_SPACE
	pause_space.physical_keycode = KEY_SPACE
	InputManager.start_rebind(&"ui_pause")
	InputManager._apply_rebind(&"ui_pause", pause_space)
	_check(not InputManager._action_has_matching_event(&"keeper_jump", pause_space), "system pause shares gameplay jump after rebind", failures)
	var jump_pad: InputEventJoypadButton = InputEventJoypadButton.new()
	jump_pad.button_index = JOY_BUTTON_A
	_check(InputMap.action_has_event(&"keeper_jump", jump_pad), "keyboard conflict removed fixed gamepad jump", failures)
	InputManager.reset_to_defaults()
	var jump_pause_key: InputEventKey = InputEventKey.new()
	jump_pause_key.keycode = KEY_F10
	jump_pause_key.physical_keycode = KEY_F10
	InputManager.start_rebind(&"keeper_jump")
	InputManager._apply_rebind(&"keeper_jump", jump_pause_key)
	_check(not InputManager._action_has_matching_event(&"ui_pause", jump_pause_key), "gameplay jump shares system pause after rebind", failures)
	InputManager.reset_to_defaults()
	InputManager.start_rebind(&"ui_accept")
	InputManager._apply_rebind(&"ui_accept", pause_space)
	_check(InputManager._action_has_matching_event(&"keeper_jump", pause_space), "menu navigation erased contextual gameplay binding", failures)
	InputManager.reset_to_defaults()
	AppFlow.request_resume()
	await _menu(host)
	await _start(host, "shooter", true)
	game = SceneRouter.current_scene_root
	var aim: InputEventJoypadMotion = InputEventJoypadMotion.new()
	aim.axis = JOY_AXIS_RIGHT_X
	aim.axis_value = 0.9
	Input.parse_input_event(aim)
	var trigger: InputEventJoypadMotion = InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	for frame: int in range(4):
		await host.get_tree().physics_frame
	_check(not game.world.bullets.is_empty() and game.world.bullets[0].velocity.x > 0, "right stick and RT did not aim and fire", failures)
	aim.axis_value = 0
	trigger.axis_value = 0
	Input.parse_input_event(aim)
	Input.parse_input_event(trigger)
	game.world.take_damage()
	var retry: InputEventJoypadButton = InputEventJoypadButton.new()
	retry.button_index = JOY_BUTTON_Y
	retry.pressed = true
	Input.parse_input_event(retry)
	for frame: int in range(3):
		await host.get_tree().physics_frame
	if game.world.health != 3:
		print("RETRY DEBUG action=", Input.is_action_pressed("keeper_retry"), " state=", AppContext.state, " modal=", UiShell.has_open_modals(), " rebind=", InputManager.is_rebinding(), " focus=", host.get_viewport().gui_get_focus_owner())
	_check(game.world.health == 3, "gamepad Y did not restart the checkpoint", failures)
	retry.pressed = false
	Input.parse_input_event(retry.duplicate())
	# The saved preference must override either variant's project-owned default.
	var saved_fullscreen: bool = not UserSettings.new().fullscreen
	AppContext.settings.fullscreen = saved_fullscreen
	_check(SettingsManager.save_settings(), "fullscreen preference did not save", failures)
	SettingsManager.load_settings()
	_check(AppContext.settings.fullscreen == saved_fullscreen, "saved fullscreen preference was ignored", failures)
	await _menu(host)
	return failures

static func _menu(host: Node) -> void:
	await host._expect_transition(Callable(AppFlow, "return_to_main_menu"), Scenes.MAIN_MENU, AppState.Value.MAIN_MENU, "forest: menu")

static func _start(host: Node, mode: String, restart: bool = false) -> void:
	await host._expect_transition(Callable(AppFlow, "start_session").bind(ForestData.start_params(mode, restart)), Scenes.GAMEPLAY, AppState.Value.IN_GAME, "forest: " + mode)

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("forest: " + message)
