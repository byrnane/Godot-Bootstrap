extends RefCounted;


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = [];
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1720, 720), Vector2i(1280, 960), Vector2i(640, 360)]:
		var viewport: SubViewport = SubViewport.new();
		viewport.size = size;
		host.add_child(viewport);
		var debug: DebugOverlay = load("res://shared/ui/debug/debug_overlay.tscn").instantiate();
		viewport.add_child(debug);
		debug.apply_snapshot({"scene_id": "very_long_registered_scene_name_for_debug_layout", "hud_name": "LongGameplayHudName", "modal_names": "SettingsModal, SaveSlotsModal, FeedbackModal"});
		debug.show_overlay();
		var hud: Control = load("res://features/gameplay/gameplay_hud.tscn").instantiate();
		viewport.add_child(hud);
		for frame: int in range(5):
			await host.get_tree().process_frame;
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size));
		var panel: Control = debug.get_node("MarginContainer");
		if not bounds.grow(1).encloses(panel.get_global_rect()):
			failures.append("geometry: debug panel outside %s: %s" % [size, panel.get_global_rect()]);
		var scroll: ScrollContainer = debug.get_node("MarginContainer/Panel/Scroll");
		if not bounds.grow(1).encloses(scroll.get_global_rect()):
			failures.append("geometry: debug scroll outside %s" % size);
		# Overflowing content must remain reachable instead of expanding the panel.
		if size.y == 360:
			scroll.scroll_vertical = 10000;
			await host.get_tree().process_frame;
			if scroll.scroll_vertical <= 0:
				failures.append("geometry: compact debug actions cannot be scrolled into view");
		var pause: Button = hud.get_node("%PauseButton");
		if not bounds.grow(1).encloses(pause.get_global_rect()):
			failures.append("geometry: pause button outside %s" % size);
		var normal: StyleBox = pause.get_theme_stylebox("normal");
		for state: String in ["hover", "pressed", "disabled"]:
			if pause.get_theme_stylebox(state).get_minimum_size() != normal.get_minimum_size():
				failures.append("geometry: icon button changes padding on " + state);
		viewport.queue_free();
		await host.get_tree().process_frame;
	return failures;
