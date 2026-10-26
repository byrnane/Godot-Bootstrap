extends RefCounted;


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = [];
	var menu_path: String = Scenes.get_scene_path(Scenes.LEVEL_STUB_A);
	var game_path: String = Scenes.get_scene_path(Scenes.LEVEL_STUB_B);
	var original_menu: PackedScene = load(menu_path) as PackedScene;
	var original_game: PackedScene = load(game_path) as PackedScene;
	var original_start_id: StringName = GameConfig.start_scene_id;
	var original_gameplay_id: StringName = GameConfig.gameplay_scene_id;
	# Only the isolated process cache changes; registry and scene files stay intact.
	var menu_fixture: PackedScene = _fixture();
	var game_fixture: PackedScene = _fixture();
	menu_fixture.take_over_path(menu_path);
	game_fixture.take_over_path(game_path);
	GameConfig.start_scene_id = Scenes.LEVEL_STUB_A;
	GameConfig.gameplay_scene_id = Scenes.LEVEL_STUB_B;
	AppFlow.set("_started", false);
	AppFlow.startup();
	if await _expect_scene(host, Scenes.LEVEL_STUB_A, "configured menu", failures):
		SceneRouter.current_scene_root.emit_signal("settings_requested");
		await host.get_tree().process_frame;
		_check(UiShell.has_open_modals(), "configured menu did not open settings", failures);
		UiShell.close_all_modals();
		await host.get_tree().create_timer(0.3).timeout;
		SceneRouter.current_scene_root.emit_signal("new_game_requested");
		if await _expect_scene(host, Scenes.LEVEL_STUB_B, "configured gameplay", failures):
			await _check_gameplay_intents(host, failures);
			SceneRouter.current_scene_root.emit_signal("back_to_menu_requested");
			await _expect_scene(host, Scenes.LEVEL_STUB_A, "configured return menu", failures);
	# Explicit startup/session overrides must also keep their roles when config differs.
	GameConfig.start_scene_id = original_start_id;
	GameConfig.gameplay_scene_id = original_gameplay_id;
	var startup: AppStartupParams = AppStartupParams.new();
	startup.main_menu_scene_id = Scenes.LEVEL_STUB_A;
	AppFlow.set("_started", false);
	AppFlow.startup(startup);
	if await _expect_scene(host, Scenes.LEVEL_STUB_A, "startup menu override", failures):
		var session: SessionStartParams = SessionStartParams.new();
		session.gameplay_scene_id = Scenes.LEVEL_STUB_B;
		SceneRouter.current_scene_root.emit_signal("session_start_requested", session);
		if await _expect_scene(host, Scenes.LEVEL_STUB_B, "session gameplay override", failures):
			await _check_gameplay_intents(host, failures);
			AppFlow.restart_session();
			if await _expect_scene(host, Scenes.LEVEL_STUB_B, "restart overridden gameplay", failures):
				await _check_gameplay_intents(host, failures);
			_check(AppFlow.load_session_from_slot(SaveManager.descriptor_for_quick()), "overridden session load rejected", failures);
			await _expect_scene(host, Scenes.LEVEL_STUB_B, "load overridden gameplay", failures);
			SceneRouter.current_scene_root.emit_signal("back_to_menu_requested");
			await _expect_scene(host, Scenes.LEVEL_STUB_A, "return to startup menu override", failures);
	# Restore resources before returning to the normal scene tree and later suites.
	original_menu.take_over_path(menu_path);
	original_game.take_over_path(game_path);
	AppFlow.set("_started", false);
	AppFlow.startup();
	await _expect_scene(host, original_start_id, "restore standard menu", failures);
	var session: SessionStartParams = SessionStartParams.new();
	session.gameplay_scene_id = original_gameplay_id;
	AppFlow.start_session(session);
	await _expect_scene(host, original_gameplay_id, "restore standard gameplay role", failures);
	AppFlow.return_to_main_menu();
	await _expect_scene(host, original_start_id, "finish scene override checks", failures);
	return failures;


static func _fixture() -> PackedScene:
	var root: Node = Node.new();
	root.set_script(preload("res://core/debug/flow_scene_fixture.gd"));
	var scene: PackedScene = PackedScene.new();
	scene.pack(root);
	root.free();
	return scene;


static func _check_gameplay_intents(host: Node, failures: Array[String]) -> void:
	var root: Node = SceneRouter.current_scene_root;
	root.emit_signal("pause_requested");
	_check(AppContext.state == AppState.Value.PAUSED and host.get_tree().paused, "alternative gameplay did not pause", failures);
	root.emit_signal("resume_requested");
	_check(AppContext.state == AppState.Value.IN_GAME and not host.get_tree().paused, "alternative gameplay did not resume", failures);
	UiShell.close_all_modals();
	await host.get_tree().create_timer(0.3).timeout;
	SaveManager.delete_save_descriptor(SaveManager.descriptor_for_quick());
	root.emit_signal("save_requested");
	_check(SaveManager.has_save_descriptor(SaveManager.descriptor_for_quick()), "alternative gameplay did not quick-save", failures);
	_check(bool(AutosaveManager.get("_session_active")), "alternative gameplay disabled autosave", failures);


static func _expect_scene(host: Node, scene_id: StringName, label: String, failures: Array[String]) -> bool:
	var deadline: int = Time.get_ticks_msec() + 4000;
	while Time.get_ticks_msec() < deadline:
		if SceneRouter.current_scene_id == scene_id and not SceneRouter.is_loading() and not TransitionManager.is_active():
			return true;
		await host.get_tree().process_frame;
	_check(false, "%s did not reach '%s'" % [label, scene_id], failures);
	return false;


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message);
