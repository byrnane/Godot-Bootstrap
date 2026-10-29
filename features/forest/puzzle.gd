extends Node2D
class_name ForestPuzzle

signal checkpoint_reached(snapshot: Dictionary)
signal stage_finished
signal defeated
signal changed

const CELL: float = 72.0
const ROOMS: Array = [
	["#########", "#.......#", "#.@.$.oG#", "#.......#", "#########"],
	["###########", "#.........#", "#.@.$..o..#", "#...#.....#", "#...$..o.G#", "#.........#", "###########"],
	["#############", "#...........#", "#.@.$....o..#", "#...#..#....#", "#...$....o.G#", "#...#.......#", "#...........#", "#############"],
]
var stage: int = 0
var score: int = 0
var moves: int = 0
var player_cell: Vector2i
var crates: Array[Vector2i] = []
var plates: Array[Vector2i] = []
var walls: Array[Vector2i] = []
var gate_cell: Vector2i
var finished: bool = false
var camera: Camera2D
var _repeat: float = 0.0
var _facing: Vector2 = Vector2.DOWN

func configure(entry: Dictionary) -> void:
	stage = int(entry.stage)
	score = int(entry.score)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	load_room()
	camera = Camera2D.new()
	add_child(camera)
	fit_camera()
	get_viewport().size_changed.connect(fit_camera)
	changed.emit()

func load_room() -> void:
	crates.clear()
	plates.clear()
	walls.clear()
	moves = 0
	finished = false
	var room: Array = ROOMS[stage]
	for y: int in range(room.size()):
		for x: int in range(room[y].length()):
			var cell: Vector2i = Vector2i(x, y)
			match room[y][x]:
				"#": walls.append(cell)
				"$": crates.append(cell)
				"o": plates.append(cell)
				"@": player_cell = cell
				"G": gate_cell = cell
	queue_redraw()

func fit_camera() -> void:
	var room_size: Vector2 = Vector2(ROOMS[stage][0].length(), ROOMS[stage].size()) * CELL
	var available: Vector2 = (get_viewport_rect().size - Vector2(24, 112)).max(Vector2.ONE)
	camera.zoom = Vector2.ONE * minf(available.x / room_size.x, available.y / room_size.y)
	camera.position = room_size / 2 - Vector2(0, 4 / camera.zoom.y)

func _physics_process(delta: float) -> void:
	if finished or not ForestData.input_available():
		return
	_repeat -= delta
	var direction: Vector2i = Vector2i.ZERO
	var vector: Vector2 = Input.get_vector("keeper_left", "keeper_right", "keeper_up", "keeper_down")
	if absf(vector.x) > absf(vector.y) and absf(vector.x) > 0.5:
		direction.x = 1 if vector.x > 0 else -1
	elif absf(vector.y) > 0.5:
		direction.y = 1 if vector.y > 0 else -1
	var just_pressed: bool = false
	for action: String in ["keeper_left", "keeper_right", "keeper_up", "keeper_down"]:
		just_pressed = just_pressed or Input.is_action_just_pressed(action)
	if direction != Vector2i.ZERO and (_repeat <= 0 or just_pressed):
		try_move(direction)
		_repeat = 0.16

func try_move(direction: Vector2i) -> bool:
	if finished or absi(direction.x) + absi(direction.y) != 1:
		return false
	var target: Vector2i = player_cell + direction
	if walls.has(target) or (target == gate_cell and not gate_open()):
		return false
	var index: int = crates.find(target)
	if index >= 0:
		var destination: Vector2i = target + direction
		if walls.has(destination) or crates.has(destination) or destination == gate_cell:
			return false
		crates[index] = destination
		AudioManager.play_sfx(preload("res://assets/sfx/btn_click.ogg"))
	player_cell = target
	_facing = Vector2(direction)
	moves += 1
	changed.emit()
	queue_redraw()
	if target == gate_cell and gate_open():
		finished = true
		score += maxi(10, 100 - moves)
		stage_finished.emit()
	return true

func gate_open() -> bool:
	for cell: Vector2i in plates:
		if not crates.has(cell):
			return false
	return true

func occupied_plates() -> int:
	var count: int = 0
	for cell: Vector2i in plates:
		if crates.has(cell):
			count += 1
	return count

func _draw() -> void:
	var room: Array = ROOMS[stage]
	ForestArt.draw_tiled(self, "forest_floor", Rect2(Vector2.ZERO, Vector2(room[0].length(), room.size()) * CELL))
	for cell: Vector2i in walls:
		var rect: Rect2 = Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL)
		draw_rect(rect, Color("18282f"))
		ForestArt.draw_asset(self, "wall", Rect2(rect.position + Vector2(4, 4), Vector2(64, 64)))
	for cell: Vector2i in plates:
		var center: Vector2 = (Vector2(cell) + Vector2.ONE / 2) * CELL
		ForestArt.draw_asset(self, "pressure_plate_active" if crates.has(cell) else "pressure_plate", Rect2(center - Vector2(32, 32), Vector2(64, 64)))
	for cell: Vector2i in crates:
		ForestArt.draw_asset(self, "crate", Rect2(Vector2(cell) * CELL + Vector2(4, -4), Vector2(64, 80)))
	ForestArt.draw_asset(self, "stone_gate", Rect2(Vector2(gate_cell) * CELL + Vector2(-12, -56), Vector2(96, 128)), Color.WHITE if gate_open() else Color("66807b"))
	var image: Texture2D = ForestArt.texture("keeper_top")
	if image != null:
		var center: Vector2 = (Vector2(player_cell) + Vector2.ONE / 2) * CELL
		draw_set_transform(center, _facing.angle() - PI / 2)
		draw_texture_rect(image, Rect2(-Vector2(32, 40), Vector2(64, 80)), false)
		draw_set_transform(Vector2.ZERO)
