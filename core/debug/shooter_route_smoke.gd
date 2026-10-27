extends "res://core/debug/phase0_smoke_runner.gd"

## Twin-stick route: movement, aiming, shots and real projectile hits only.
func _check_game_flow() -> void:
	AppContext.settings.autosave_enabled = false
	await _expect_transition(Callable(AppFlow, "start_session").bind(ForestData.start_params("shooter", true)), Scenes.GAMEPLAY, AppState.Value.IN_GAME, "shooter route")
	var game: ForestGame = SceneRouter.current_scene_root
	var pad: InputEventJoypadMotion = InputEventJoypadMotion.new()
	pad.axis = JOY_AXIS_RIGHT_X
	pad.axis_value = 0.8
	Input.parse_input_event(pad)
	var waypoints: Array[Vector2] = [Vector2(-430,-190), Vector2(430,-190), Vector2(430,190), Vector2(-430,190)]
	for stage: int in range(3):
		var level: ForestShooter = game.world
		var waypoint: int = 0
		Input.action_press("keeper_fire")
		for frame: int in range(1600):
			await get_tree().physics_frame
			if level.finished:
				break
			if level.player.position.distance_to(waypoints[waypoint]) < 35:
				waypoint = (waypoint + 1) % waypoints.size()
			var movement: Vector2 = level.player.position.direction_to(waypoints[waypoint])
			_set_vector("keeper_", movement)
			var closest: Vector2 = Vector2.ZERO
			var distance: float = INF
			for enemy: Dictionary in level.enemies:
				var target: Vector2 = enemy.node.position - level.player.position
				if target.length_squared() < distance:
					distance = target.length_squared()
					closest = target.normalized()
			_set_vector("keeper_aim_", closest)
			if frame % 300 == 0:
				print("SHOOTER stage=", stage + 1, " enemies=", level.enemies.size(), " health=", level.health)
		for action: String in ["keeper_left", "keeper_right", "keeper_up", "keeper_down", "keeper_aim_left", "keeper_aim_right", "keeper_aim_up", "keeper_aim_down", "keeper_fire"]:
			Input.action_release(action)
		_check(level.finished and level.health > 0, "twin-stick route did not survive wave %d; remaining %d" % [stage+1, level.enemies.size()])
		if not level.finished or level.health <= 0:
			break
		print("SHOOTER PASS stage=", stage+1, " score=", level.score, " health=", level.health)
		if stage < 2:
			game._on_result_primary()
	_check(SessionContext.game_data.progress.shooter.completed, "real shots did not complete shooter")

func _set_vector(prefix: String, vector: Vector2) -> void:
	for pair: Array in [["left",maxf(0,-vector.x)],["right",maxf(0,vector.x)],["up",maxf(0,-vector.y)],["down",maxf(0,vector.y)]]:
		var action: String = prefix + pair[0]
		if pair[1] > 0:
			Input.action_press(action, pair[1])
		else:
			Input.action_release(action)
