extends RefCounted
class_name ForestArt

static var _textures: Dictionary = {}

static func texture(asset: String) -> Texture2D:
	if _textures.has(asset):
		return _textures[asset]
	var path: String = "res://assets/forest/%s.png" % asset
	if not ResourceLoader.exists(path):
		return null
	var original: Texture2D = load(path)
	if asset not in ["forest_panorama", "forest_floor"]:
		_textures[asset] = load("res://assets/forest/" + asset + ".tres")
	else:
		_textures[asset] = original
	return _textures[asset]

static func sprite(asset: String, size: Vector2) -> Sprite2D:
	var node: Sprite2D = Sprite2D.new()
	node.texture = texture(asset)
	if node.texture != null:
		node.scale = size / node.texture.get_size()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return node

static func label(key: String, role: StringName = &"UiBody") -> Label:
	var node: Label = Label.new()
	node.text = key
	node.theme_type_variation = role
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(key: String, action: Callable, primary: bool = false) -> Button:
	var node: Button = Button.new()
	node.text = key
	node.custom_minimum_size.y = 50
	node.theme_type_variation = &"UiButtonPrimary" if primary else &"UiButtonSecondary"
	node.pressed.connect(action)
	return node

static func panel() -> PanelContainer:
	var panel_node: PanelContainer = PanelContainer.new()
	panel_node.theme_type_variation = &"UiSurface"
	return panel_node

static func margin(amount: int = 24) -> MarginContainer:
	var node: MarginContainer = MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		node.add_theme_constant_override("margin_" + side, amount)
	return node

static func draw_asset(canvas: CanvasItem, asset: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var image: Texture2D = texture(asset)
	if image != null:
		canvas.draw_texture_rect(image, rect, false, tint)

static func fireflies(parent: Node, viewport_size: Vector2) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.amount = 28
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = viewport_size / 2
	particles.position = viewport_size / 2
	particles.gravity = Vector2.ZERO
	particles.direction = Vector2.UP
	particles.spread = 80
	particles.initial_velocity_min = 5
	particles.initial_velocity_max = 14
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3
	particles.color = Color(1, 0.79, 0.36, 0.6)
	parent.add_child(particles)
	return particles
