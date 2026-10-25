extends RefCounted

static func run(runner: Node) -> Array[String]:
	var errors: Array[String] = []
	AppFlow.start_new_game()
	if not await runner._wait_until(func() -> bool: return SceneRouter.current_scene_id == Scenes.GAMEPLAY and not SceneRouter.is_loading() and not TransitionManager.is_active(), 8.0):
		return ["3d: gameplay did not load"]
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	var game: Variant = SceneRouter.current_scene_root
	var player: RetroPlayer = game.player
	check(errors, game.enemies.size() == 5, "five zombies should spawn")
	check(errors, game.pickups.size() == 5, "four pickups and the exit should spawn")
	var yaw: float = player.rotation.y
	player.set_camera_mode(true)
	check(errors, player.third_camera.current and not player.first_camera.current, "third-person camera should become current")
	player.set_camera_mode(false)
	check(errors, player.first_camera.current and is_equal_approx(player.rotation.y, yaw), "camera switching must preserve facing")
	await check_camera_collision(runner, player, errors)
	var spawn: Vector3 = player.position
	for wall_z: float in [4.115, -29.115]:
		player.position = Vector3(0, 0, wall_z)
		var wall_state: Dictionary = player.snapshot()
		player.position = spawn
		player.restore(wall_state)
		check(errors, is_equal_approx(player.position.z, wall_z), "restore must preserve reachable positions against end walls")
	player.position = spawn
	game.wants_capture = false
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(errors, not player.enabled and not game.enemies[0].enabled, "released controls must also stop enemy attacks")
	game.wants_capture = true
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	# Exercise real physics rays, collision layers, weapon timing, and zombie death.
	var enemy: RetroZombie = game.enemies[0]
	enemy.position = Vector3(0, 0.05, -1)
	player.position = Vector3(0, 0.05, 2.5)
	aim_at(player, enemy.global_position + Vector3.UP)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	check(errors, player.shoot(), "loaded pistol should fire")
	check(errors, not player.shoot(), "pistol cooldown should block a second immediate shot")
	check(errors, player.magazine == 7 and enemy.health == 66, "hit should consume one round and damage target")
	await runner.get_tree().create_timer(0.28).timeout
	aim_at(player, enemy.global_position + Vector3.UP)
	player.shoot()
	await runner.get_tree().create_timer(0.28).timeout
	aim_at(player, enemy.global_position + Vector3.UP)
	player.shoot()
	check(errors, enemy.health == 0 and enemy.collision_layer == 0, "third hit should kill and disable corpse collision")
	var alive: int = game.living_enemies()
	enemy.take_damage(34)
	check(errors, game.living_enemies() == alive, "corpse must not die twice")
	await runner.get_tree().create_timer(0.28).timeout
	var blocked_enemy: RetroZombie = game.enemies[1]
	blocked_enemy.position = Vector3(0, 0.05, 1.92)
	player.position = Vector3(0, 0.05, 2.5)
	aim_at(player, blocked_enemy.global_position + Vector3.UP)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	var contact_shot: bool = player.shoot()
	if blocked_enemy.health != 66:
		print("CONTACT_DIAGNOSTIC ", {"shot": contact_shot, "health": blocked_enemy.health, "enabled": player.enabled, "cooldown": player.shot_left, "player": player.position, "zombie": blocked_enemy.position, "pitch": player.pivot.rotation.x, "ammo": player.magazine})
	check(errors, blocked_enemy.health == 66, "point-blank shots must hit even when the muzzle enters the enemy capsule")
	await runner.get_tree().create_timer(0.28).timeout
	blocked_enemy.position = Vector3(3, 0.05, -7)
	player.position = Vector3(3, 0.05, -3)
	aim_at(player, blocked_enemy.global_position + Vector3.UP)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	var health_before: int = blocked_enemy.health
	player.shoot()
	check(errors, blocked_enemy.health == health_before, "wall should block bullets")
	await runner.get_tree().create_timer(0.28).timeout
	# A shoulder camera can see past thin cover while the barrel touches it.
	var cover: StaticBody3D = StaticBody3D.new()
	cover.collision_layer = 1
	var cover_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.4, 2.8, 0.1)
	cover_shape.shape = box
	cover.add_child(cover_shape)
	game.level_root.add_child(cover)
	cover.position = Vector3(0, 1.4, 1)
	player.position = Vector3(0, 0.05, 1.35)
	player.rotation.y = 0.0
	player.pivot.rotation.x = -0.12
	player.set_camera_mode(true)
	blocked_enemy.position = Vector3(0.5, 0.05, -1)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	health_before = blocked_enemy.health
	player.shoot()
	check(errors, blocked_enemy.health == health_before, "third-person camera must not shoot through cover touching the barrel")
	cover.queue_free()
	player.magazine = 0
	player.reserve = 5
	await runner.get_tree().create_timer(0.28).timeout
	check(errors, not player.shoot(), "empty magazine must not shoot")
	check(errors, player.reloading, "empty trigger should begin available reload")
	await runner.get_tree().create_timer(2.1).timeout
	check(errors, player.magazine == 5 and player.reserve == 0 and not player.reloading, "reload transfers only available ammunition")
	player.magazine = 0
	check(errors, not player.begin_reload(), "no reserve means no reload")
	var medkit: RetroPickup = find_pickup(game, "medkit_1")
	player.health = 100
	check(errors, not medkit.interact(player) and not medkit.consumed, "full health must leave medkit in the world")
	player.health = 80
	check(errors, medkit.interact(player) and player.health == 100, "medkit caps healing at max health")
	check(errors, not medkit.interact(player), "consumed medkit cannot be reused")
	var ammo: RetroPickup = find_pickup(game, "ammo_1")
	player.reserve = 64
	check(errors, not ammo.interact(player) and not ammo.consumed, "full reserve must leave ammo in the world")
	player.reserve = 60
	check(errors, ammo.interact(player) and player.reserve == 64, "ammo pickup must clamp reserve")
	# Check physical interaction reach through the actual aiming path.
	var medkit2: RetroPickup = find_pickup(game, "medkit_2")
	player.position = Vector3(3.4, 0.05, -17.0)
	aim_at(player, medkit2.global_position + Vector3.UP * 0.2)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	check(errors, game.find_interaction() == medkit2, "nearby visible item should be reachable")
	player.position = Vector3(3.4, 0.05, -14.8)
	aim_at(player, medkit2.global_position + Vector3.UP * 0.2)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	check(errors, game.find_interaction() == null, "interaction must not pass through the separating wall")
	# A save must contain the latest movement, camera, ammunition and world state.
	player.position = Vector3(0.7, 0.0, 1.0)
	player.magazine = 3
	player.reserve = 17
	game.enemies[1].alerted = true
	player.set_camera_mode(true)
	game._sync_state()
	check(errors, SaveManager.save_current_session(87), "prototype save should succeed")
	var saved: SaveData = SaveManager.load_game(87)
	check(errors, saved != null and saved.game_data.get("prototype_version") == 1, "saved prototype data should load")
	if saved != null:
		player.magazine = 0
		player.reserve = 12
		player.begin_reload()
		player.reload_left = 0.02
		var previous_id: int = game.get_instance_id()
		check(errors, AppFlow.load_session_from_slot(SaveManager.descriptor_for_manual(87)), "slot loading should start during reload")
		await runner._wait_until(func() -> bool: return SceneRouter.current_scene_id == Scenes.GAMEPLAY and not SceneRouter.is_loading() and not TransitionManager.is_active() and SceneRouter.current_scene_root.get_instance_id() != previous_id, 8.0)
		game = SceneRouter.current_scene_root
		player = game.player
		check(errors, player.position.distance_to(Vector3(0.7, 0, 1)) < 0.15 and player.magazine == 3 and player.reserve == 17 and player.third_person, "continue must restore player transform, ammunition and camera")
		check(errors, game.enemies[0].health == 0 and find_pickup(game, "medkit_1").consumed, "continue must preserve killed zombies and consumed items")
		check(errors, game.enemies[1].alerted, "continue must preserve an alerted zombie even when the player is out of sight")
	# Observe real navigation across the first doorway, then an actual melee hit.
	var chaser: RetroZombie = game.enemies[1]
	chaser.position = Vector3(0, 0.05, -6)
	chaser.alerted = true
	player.position = Vector3(0, 0.05, -3)
	player.health = 100
	var start_z: float = chaser.position.z
	await runner.get_tree().create_timer(1.5).timeout
	check(errors, chaser.position.z > start_z + 0.5, "navigation should move a zombie through a doorway")
	chaser.position = player.position - Vector3(0, 0, 1.0)
	await runner.get_tree().create_timer(0.85).timeout
	check(errors, player.health <= 80, "nearby zombie attack should damage player")
	player.take_damage(100)
	await runner.get_tree().process_frame
	check(errors, game.outcome == "dead", "zero health should enter defeat state")
	var old_instance_id: int = game.get_instance_id()
	AppFlow.restart_session()
	await runner._wait_until(func() -> bool: return SceneRouter.current_scene_id == Scenes.GAMEPLAY and not SceneRouter.is_loading() and not TransitionManager.is_active() and SceneRouter.current_scene_root.get_instance_id() != old_instance_id, 8.0)
	game = SceneRouter.current_scene_root
	player = game.player
	check(errors, player.health == 100 and game.living_enemies() == 5 and SessionContext.game_data.get("consumed", []).is_empty(), "restart should reset a completed run")
	# Victory is an interaction, not merely the last kill.
	for zombie: RetroZombie in game.enemies:
		zombie.take_damage(100)
	player.position = Vector3(0, 0.05, -27.6)
	aim_at(player, find_pickup(game, "exit").global_position + Vector3.UP * 0.8)
	await runner.get_tree().physics_frame
	await runner.get_tree().physics_frame
	check(errors, game.interact() and game.outcome == "won", "cleared exit interaction should win")
	AppFlow.return_to_main_menu()
	await runner._wait_until(func() -> bool: return SceneRouter.current_scene_id == Scenes.MAIN_MENU and not TransitionManager.is_active(), 8.0)
	# Old save content should remain a valid entrance to the new example.
	SessionContext.game_data = {"prototype_version": 1, "player": null, "enemies": [], "consumed": null}
	AppFlow.start_session(_resume_params())
	await runner._wait_until(func() -> bool: return SceneRouter.current_scene_id == Scenes.GAMEPLAY and not SceneRouter.is_loading() and not TransitionManager.is_active(), 8.0)
	check(errors, SceneRouter.current_scene_root.player.magazine == 8, "incomplete game_data should use safe defaults")
	AppFlow.return_to_main_menu()
	await runner._wait_until(func() -> bool: return SceneRouter.current_scene_id == Scenes.MAIN_MENU and not TransitionManager.is_active(), 8.0)
	return errors

static func _resume_params() -> SessionStartParams:
	var params: SessionStartParams = SessionStartParams.new()
	params.mode = SessionStartParams.Mode.RESUME_OR_CONTINUE_OR_NEW
	return params

static func check_camera_collision(runner: Node, player: RetroPlayer, errors: Array[String]) -> void:
	var original_position: Vector3 = player.position
	var probe: SphereShape3D = SphereShape3D.new()
	probe.radius = 0.12
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	# Side wall, corner, doorway jamb and a steep look near the ceiling/floor.
	for point: Vector3 in [Vector3(4.65, 0, 0), Vector3(4.65, 0, 4.05), Vector3(1.15, 0, -4.4), Vector3.ZERO]:
		for yaw_index: int in range(4):
			for pitch: float in [-1.2, 0.0, 1.2]:
				player.position = point
				player.rotation.y = yaw_index * PI * 0.5
				player.pivot.rotation.x = pitch
				player.set_camera_mode(true)
				await runner.get_tree().physics_frame
				await runner.get_tree().physics_frame
				var camera: Camera3D = player.active_camera()
				query.transform = Transform3D(Basis.IDENTITY, camera.global_position)
				var clear: bool = player.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
				clear = clear and player.ray(player.pivot.global_position, camera.global_position, 1).is_empty()
				clear = clear and camera.global_position.y < 3.15
				check(errors, clear, "camera must stay inside geometry at %s yaw=%d pitch=%.1f" % [point, yaw_index, pitch])
	player.position = original_position
	player.rotation.y = 0.0
	player.pivot.rotation.x = 0.0
	player.set_camera_mode(false)
	await runner.get_tree().physics_frame

static func find_pickup(game: Variant, id: String) -> RetroPickup:
	for pickup: RetroPickup in game.pickups:
		if pickup.stable_id == id:
			return pickup
	return null

static func aim_at(player: RetroPlayer, target: Vector3) -> void:
	player.set_camera_mode(false)
	var direction: Vector3 = target - player.first_camera.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	player.pivot.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())

static func check(errors: Array[String], condition: bool, message: String) -> void:
	if not condition:
		errors.append("3d: " + message)
