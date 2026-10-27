extends Node2D
class_name ForestPlatformer

signal checkpoint_reached(snapshot: Dictionary)
signal stage_finished
signal defeated
signal changed

const WIDTH: float = 3200.0
const FLOOR_Y: float = 580.0
var stage: int = 0
var health: int = 3
var score: int = 0
var checkpoint: int = 0
var collected: Array[int] = []
var player: CharacterBody2D
var camera: Camera2D
var actor: Sprite2D
var moving_platform: AnimatableBody2D
var finished: bool = false
var _invulnerable: float = 0.0
var _clock: float = 0.0
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _moving_origin: Vector2
var _platform_rects: Array[Rect2] = []
var _hazards: Array[Rect2] = []
var _sparks: Array[Vector2] = []

func configure(entry: Dictionary) -> void:
	stage = int(entry.stage)
	score = int(entry.score)
	checkpoint = int(entry.checkpoint)
	collected.assign(entry.collected)

func _ready() -> void:
	var ground: Array[Rect2] = [Rect2(0, FLOOR_Y, 850, 160), Rect2(1000, FLOOR_Y, 900, 160), Rect2(2080, FLOOR_Y, 1120, 160)]
	if stage == 1:
		ground = [Rect2(0, FLOOR_Y, 850, 160), Rect2(1080, FLOOR_Y, 720, 160), Rect2(2120, FLOOR_Y, 1080, 160)]
	elif stage == 2:
		ground = [Rect2(0, FLOOR_Y, 820, 160), Rect2(1040, FLOOR_Y, 720, 160), Rect2(2140, FLOOR_Y, 1060, 160)]
	for rect: Rect2 in ground:
		_add_platform(rect)
	for rect: Rect2 in [Rect2(330, 455, 200, 44), Rect2(650, 370, 180, 44), Rect2(1260, 455, 200, 44), Rect2(1590, 380, 210, 44), Rect2(2310, 450, 200, 44)]:
		_add_platform(rect)
	if stage >= 1:
		moving_platform = AnimatableBody2D.new()
		moving_platform.sync_to_physics = false
		_moving_origin = Vector2(1980, 500 if stage == 2 else 455)
		moving_platform.position = _moving_origin
		var platform_width: float = 220.0 if stage == 2 else 150.0
		_collision(moving_platform, Vector2(platform_width, 28))
		add_child(moving_platform)
		var art: Sprite2D = ForestArt.sprite("platform", Vector2(platform_width, 40))
		moving_platform.add_child(art)
	_hazards = [Rect2(1130, 548, 90, 32)]
	if stage == 2:
		_hazards.append(Rect2(2580, 548, 140, 32))
	_sparks = [Vector2(735, 315), Vector2(1680, 325), Vector2(2410, 395)]
	player = CharacterBody2D.new()
	player.name = "Keeper"
	player.collision_layer = 2
	player.collision_mask = 1
	_collision(player, Vector2(30, 54))
	player.position = Vector2(1490, 545) if checkpoint == 1 else Vector2(140, 545)
	add_child(player)
	actor = ForestArt.sprite("keeper_side", Vector2(64, 78))
	actor.position.y = -10
	player.add_child(actor)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	changed.emit()

func _collision(body: CollisionObject2D, size: Vector2) -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)

func _add_platform(rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(rect.get_center().x, rect.position.y + 14)
	_collision(body, Vector2(rect.size.x, 28))
	add_child(body)
	_platform_rects.append(rect)

func _physics_process(delta: float) -> void:
	if finished or not ForestData.input_available():
		return
	_clock += delta
	_invulnerable = maxf(0, _invulnerable - delta)
	_jump_buffer = maxf(0, _jump_buffer - delta)
	_coyote = 0.12 if player.is_on_floor() else maxf(0, _coyote - delta)
	if Input.is_action_just_pressed("keeper_jump"):
		_jump_buffer = 0.12
	if _jump_buffer > 0 and _coyote > 0:
		player.velocity.y = -650
		_jump_buffer = 0
		_coyote = 0
	if Input.is_action_just_released("keeper_jump") and player.velocity.y < -240:
		player.velocity.y = -240
	player.velocity.x = Input.get_axis("keeper_left", "keeper_right") * 310
	player.velocity.y = minf(player.velocity.y + 1500 * delta, 950)
	if moving_platform != null:
		moving_platform.position = _moving_origin + Vector2(sin(_clock * 1.1) * (90 if stage == 2 else 130), 0)
	player.move_and_slide()
	player.position.x = clampf(player.position.x, 25, WIDTH - 25)
	if absf(player.velocity.x) > 1:
		actor.flip_h = player.velocity.x < 0
	actor.position.y = -10 + sin(_clock * 14) * 2 if player.is_on_floor() and absf(player.velocity.x) > 1 else -10
	actor.modulate.a = 0.4 if _invulnerable > 0 and sin(_clock * 30) > 0 else 1.0
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	camera.global_position = Vector2(clampf(player.position.x + 100, view_size.x / 2, maxf(view_size.x / 2, WIDTH - view_size.x / 2)), FLOOR_Y - view_size.y * 0.38)
	if player.position.y > 850:
		take_damage(true)
	for hazard: Rect2 in _hazards:
		if hazard.intersects(Rect2(player.position - Vector2(14, 26), Vector2(28, 52))):
			take_damage()
	for index: int in range(_sparks.size()):
		if not collected.has(index) and player.position.distance_to(_sparks[index]) < 45:
			collected.append(index)
			score += 10
			AudioManager.play_sfx(preload("res://assets/sfx/score.ogg"))
			changed.emit()
	if checkpoint == 0 and player.position.x > 1460 and player.position.y < 600:
		checkpoint = 1
		health = 3
		checkpoint_reached.emit(snapshot())
		changed.emit()
	if player.position.x > WIDTH - 150:
		finished = true
		stage_finished.emit()
	queue_redraw()

func take_damage(respawn: bool = false) -> void:
	if finished or (_invulnerable > 0 and not respawn):
		return
	health -= 1
	_invulnerable = 1.0
	AudioManager.play_sfx(preload("res://assets/sfx/damage.ogg"))
	if health <= 0:
		finished = true
		defeated.emit()
	elif respawn:
		player.position = Vector2(1490, 530) if checkpoint == 1 else Vector2(140, 530)
		player.velocity = Vector2.ZERO
	else:
		player.velocity = Vector2(-180 if player.velocity.x > 0 else 180, -280)
	changed.emit()

func snapshot() -> Dictionary:
	return {"stage": stage, "checkpoint": checkpoint, "score": score, "collected": collected.duplicate(), "completed": false, "started": true}

func _draw() -> void:
	for rect: Rect2 in _platform_rects:
		draw_rect(rect, Color("213c35"))
		var count: int = ceili(rect.size.x / 180)
		for tile: int in range(count):
			ForestArt.draw_asset(self, "platform", Rect2(rect.position + Vector2(tile * 180, 0), Vector2(minf(180, rect.size.x - tile * 180), 72)))
	for hazard: Rect2 in _hazards:
		for index: int in range(int(hazard.size.x / 15)):
			var point: Vector2 = hazard.position + Vector2(index * 15, 0)
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, 32), point + Vector2(7, 0), point + Vector2(15, 32)]), Color("b878a4"))
	for index: int in range(_sparks.size()):
		if not collected.has(index):
			var center: Vector2 = _sparks[index] + Vector2(0, sin(_clock * 2 + index) * 5)
			draw_circle(center, 16, Color(1, 0.72, 0.25, 0.15))
			draw_circle(center, 6, Color("ffe5a0"))
	ForestArt.draw_asset(self, "checkpoint_lantern", Rect2(1460, 470, 60, 110))
	ForestArt.draw_asset(self, "stone_gate", Rect2(WIDTH - 190, 400, 150, 180))
