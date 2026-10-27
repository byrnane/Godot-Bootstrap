extends Node2D
class_name ForestShooter

signal checkpoint_reached(snapshot: Dictionary)
signal stage_finished
signal defeated
signal changed

const ARENA: Rect2 = Rect2(-560, -290, 1120, 580)
const WAVE_COUNTS: Array[int] = [6, 10, 14]
var stage: int = 0
var health: int = 3
var score: int = 0
var player: CharacterBody2D
var camera: Camera2D
var actor: Sprite2D
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var finished: bool = false
var _aim: Vector2 = Vector2.DOWN
var _fire_cooldown: float = 0.0
var _invulnerable: float = 0.0
var _clock: float = 0.0

func configure(entry: Dictionary) -> void:
	stage = int(entry.stage)
	score = int(entry.score)

func _ready() -> void:
	player = CharacterBody2D.new()
	player.name = "Keeper"
	player.collision_layer = 2
	player.collision_mask = 0
	add_child(player)
	actor = ForestArt.sprite("keeper_top", Vector2(58, 70))
	player.add_child(actor)
	camera = Camera2D.new()
	add_child(camera)
	fit_camera()
	get_viewport().size_changed.connect(fit_camera)
	for index: int in range(WAVE_COUNTS[stage]):
		var angle: float = TAU * index / WAVE_COUNTS[stage]
		var body: Sprite2D = ForestArt.sprite("shadow", Vector2(55, 55))
		var ranged: bool = stage > 0 and index % 3 == 0
		body.modulate = Color("d8a1e3") if ranged else Color.WHITE
		body.position = Vector2(cos(angle) * 480, sin(angle) * 230)
		add_child(body)
		enemies.append({"node": body, "ranged": ranged, "timer": 1.2 + index * 0.11})
	changed.emit()
	queue_redraw()

func fit_camera() -> void:
	var available: Vector2 = get_viewport_rect().size - Vector2(80, 280)
	var factor: float = minf(available.x / ARENA.size.x, available.y / ARENA.size.y)
	camera.zoom = Vector2.ONE * maxf(0.35, factor)
	camera.position.y = -30 / camera.zoom.y

func _physics_process(delta: float) -> void:
	if finished or not ForestData.input_available():
		return
	_clock += delta
	_fire_cooldown = maxf(0, _fire_cooldown - delta)
	_invulnerable = maxf(0, _invulnerable - delta)
	player.velocity = Input.get_vector("keeper_left", "keeper_right", "keeper_up", "keeper_down") * 270
	player.move_and_slide()
	player.position = player.position.clamp(ARENA.position + Vector2(26, 26), ARENA.end - Vector2(26, 26))
	var stick: Vector2 = Input.get_vector("keeper_aim_left", "keeper_aim_right", "keeper_aim_up", "keeper_aim_down")
	if InputManager.get("last_device") == &"gamepad":
		if stick.length() > 0.2:
			_aim = stick.normalized()
	else:
		var direction: Vector2 = get_global_mouse_position() - player.position
		if direction.length() > 8:
			_aim = direction.normalized()
	actor.rotation = _aim.angle() - PI / 2
	actor.modulate.a = 0.4 if _invulnerable > 0 and sin(_clock * 30) > 0 else 1.0
	if Input.is_action_pressed("keeper_fire") and _fire_cooldown <= 0:
		fire(_aim)
	for index: int in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		var node: Sprite2D = enemy.node
		var direction: Vector2 = player.position - node.position
		if not enemy.ranged or direction.length() > 270:
			node.position += direction.normalized() * (80 + stage * 16) * delta
		enemy.timer -= delta
		if enemy.ranged and enemy.timer <= 0:
			bullets.append({"position": node.position, "velocity": direction.normalized() * 205, "enemy": true})
			enemy.timer = 2.0
		if direction.length() < 35:
			take_damage()
	for index: int in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[index]
		var previous: Vector2 = bullet.position
		bullet.position += bullet.velocity * delta
		var remove: bool = not ARENA.grow(70).has_point(bullet.position)
		if bullet.enemy:
			if _segment_distance(player.position, previous, bullet.position) < 25:
				take_damage()
				remove = true
		else:
			for enemy_index: int in range(enemies.size() - 1, -1, -1):
				if _segment_distance(enemies[enemy_index].node.position, previous, bullet.position) < 29:
					defeat_enemy(enemy_index)
					remove = true
					break
		if remove:
			bullets.remove_at(index)
	if enemies.is_empty() and not finished:
		finished = true
		stage_finished.emit()
	queue_redraw()

func fire(direction: Vector2) -> void:
	_fire_cooldown = 0.19
	bullets.append({"position": player.position + direction * 30, "velocity": direction * 720, "enemy": false})

func defeat_enemy(index: int) -> void:
	enemies[index].node.queue_free()
	enemies.remove_at(index)
	score += 10
	AudioManager.play_sfx(preload("res://assets/sfx/score.ogg"))
	changed.emit()

func take_damage() -> void:
	if _invulnerable > 0 or finished:
		return
	health -= 1
	_invulnerable = 1.0
	AudioManager.play_sfx(preload("res://assets/sfx/damage.ogg"))
	changed.emit()
	if health <= 0:
		finished = true
		defeated.emit()

static func _segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))

func _draw() -> void:
	ForestArt.draw_asset(self, "forest_floor", ARENA)
	draw_rect(ARENA, Color("608b76"), false, 8)
	for position: Vector2 in [Vector2(-530, -260), Vector2(530, -260), Vector2(-530, 260), Vector2(530, 260)]:
		ForestArt.draw_asset(self, "checkpoint_lantern", Rect2(position - Vector2(22, 50), Vector2(44, 70)))
	for bullet: Dictionary in bullets:
		var tint: Color = Color("c89ce5") if bullet.enemy else Color("ffe3a0")
		draw_circle(bullet.position, 11, Color(tint, 0.16))
		draw_circle(bullet.position, 5, tint)
	draw_line(player.position + _aim * 34, player.position + _aim * 49, Color("ffe3a0"), 3)
