extends "res://core/debug/phase0_smoke_runner.gd"

## Finish all levels with physics and action input; no position shortcuts.
func _check_game_flow() -> void:
	AppContext.settings.autosave_enabled = false
	await _expect_transition(Callable(AppFlow, "start_new_game"), Scenes.GAMEPLAY, AppState.Value.IN_GAME, "platformer route")
	var game: ForestGame = SceneRouter.current_scene_root
	for stage: int in range(3):
		var level: ForestPlatformer = game.world
		var jump_frames: int = 0
		Input.action_press("keeper_right")
		for frame: int in range(1500):
			await get_tree().physics_frame
			if level.finished:
				break
			if jump_frames > 0:
				jump_frames -= 1
				if jump_frames == 0:
					Input.action_release("keeper_jump")
			if level.player.is_on_floor() and jump_frames == 0:
				var near_edge: bool = false
				for collision_index: int in range(level.player.get_slide_collision_count()):
					var collision: KinematicCollision2D = level.player.get_slide_collision(collision_index)
					if collision.get_normal().y > -0.5:
						continue
					var body: Node2D = collision.get_collider()
					var shapes: Array[Node] = body.find_children("*", "CollisionShape2D", true, false)
					if not shapes.is_empty():
						var rectangle: RectangleShape2D = shapes[0].shape
						var edge: float = body.position.x + rectangle.size.x / 2
						near_edge = edge - level.player.position.x < 36
				var hazard_ahead: bool = false
				for hazard: Rect2 in level._hazards:
					if level.player.position.y > 490 and hazard.position.x - level.player.position.x < 85 and hazard.end.x > level.player.position.x:
						hazard_ahead = true
				if near_edge or hazard_ahead:
					Input.action_press("keeper_jump")
					jump_frames = 48
			if frame % 300 == 0:
				print("ROUTE stage=", stage + 1, " frame=", frame, " position=", level.player.position, " health=", level.health)
		Input.action_release("keeper_right")
		Input.action_release("keeper_jump")
		_check(level.finished and level.health > 0, "platformer route did not reach gate in stage %d at %s" % [stage + 1, level.player.position])
		if not level.finished or level.health <= 0:
			break
		print("ROUTE PASS stage=", stage + 1, " health=", level.health, " wisps=", level.collected.size())
		if stage < 2:
			game._on_result_primary()
	_check(SessionContext.game_data.progress.platformer.completed, "physical route did not complete platformer")
