extends RefCounted
class_name ForestArt

static var _textures: Dictionary = {}
static var _theme: Theme

static func texture(asset: String) -> Texture2D:
	if _textures.has(asset):
		return _textures[asset]
	var path: String = "res://assets/pixel_forest/%s.png" % asset
	if not ResourceLoader.exists(path):
		return null
	_textures[asset] = load(path)
	return _textures[asset]

static func ui_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = load("res://shared/ui/theme/neutral_theme.tres").duplicate(true)
	_theme.default_font_size = 12
	for type_name: StringName in _theme.get_type_list():
		for font_name: StringName in _theme.get_font_size_list(type_name):
			_theme.set_font_size(font_name, type_name, 12)
	for role: String in ["UiDisplay", "UiHeading"]:
		_theme.set_font_size("font_size", role, 20)
	_theme.set_font_size("font_size", "UiSection", 14)
	for role: String in ["UiSmall", "UiCaption", "UiLabel"]:
		_theme.set_font_size("font_size", role, 11)
	_theme.set_constant("icon_max_width", "Button", 12)
	_theme.set_constant("h_separation", "Button", 4)
	for role: String in ["Button", "UiButtonPrimary", "UiButtonSecondary", "UiButtonGhost"]:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var asset: String = "ui_button_" + state
			if role == "UiButtonPrimary" and state == "normal":
				asset = "ui_button_primary"
			_theme.set_stylebox(state, role, _skin(asset))
		_theme.set_color("font_color", role, Color("fff0b0"))
		_theme.set_color("font_focus_color", role, Color("fff0b0"))
		_theme.set_color("font_hover_color", role, Color("fff0b0"))
		_theme.set_color("font_pressed_color", role, Color("f5ce78"))
		_theme.set_color("font_disabled_color", role, Color("689468"))
	_theme.set_stylebox("panel", "UiSurface", _skin("ui_panel"))
	_theme.set_color("font_color", "Label", Color("fff0b0"))
	return _theme

static func _skin(asset: String) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture(asset)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 4)
		style.set_content_margin(side, 4)
	return style

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
	node.custom_minimum_size.y = 26
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

static func draw_tiled(canvas: CanvasItem, asset: String, rect: Rect2, pixel_scale: float = 2.0) -> void:
	var image: Texture2D = texture(asset)
	if image == null:
		return
	var tile_size: Vector2 = image.get_size() * pixel_scale
	for y: int in range(ceili(rect.size.y / tile_size.y)):
		for x: int in range(ceili(rect.size.x / tile_size.x)):
			var origin: Vector2 = rect.position + Vector2(x, y) * tile_size
			var size: Vector2 = (rect.end - origin).min(tile_size)
			canvas.draw_texture_rect_region(image, Rect2(origin, size), Rect2(Vector2.ZERO, size / pixel_scale))

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
