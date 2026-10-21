extends BoxContainer;
class_name UiTabStrip;

signal tab_changed(tab_id: StringName, index: int);


const UI_FOCUS_UTIL = preload("res://shared/ui/navigation/ui_focus.gd");


@export var sidebar: bool = false;
@export var tab_ids: Array[StringName] = [];
@export var tab_title_keys: PackedStringArray = [];
@export_range(0, 16, 1) var current_tab: int = 0;


@onready var tabs_container: BoxContainer = %TabsContainer;
@onready var pages_container: Control = %PagesContainer;


var _tab_buttons: Array[Button] = [];


func _ready() -> void:
	vertical = not sidebar;
	tabs_container.vertical = sidebar;
	tabs_container.custom_minimum_size.x = 216 if sidebar else 0;
	tabs_container.size_flags_horizontal = Control.SIZE_FILL if sidebar else Control.SIZE_EXPAND_FILL;
	tabs_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN;
	add_theme_constant_override("separation", 80 if sidebar else 12);
	_rebuild_tabs();
	_apply_current_tab(false);


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh_titles();


func refresh_titles() -> void:
	for button_index: int in range(_tab_buttons.size()):
		_tab_buttons[button_index].text = _get_tab_title(button_index);


func set_current_tab(index: int, focus_page: bool = false) -> void:
	current_tab = clampi(index, 0, max(get_tab_count() - 1, 0));
	_apply_current_tab(focus_page);


func get_tab_count() -> int:
	return pages_container.get_child_count();


func get_current_tab_id() -> StringName:
	if current_tab < tab_ids.size():
		return tab_ids[current_tab];

	var page: Node = _get_page(current_tab);
	return StringName(String(page.name)) if page != null else &"";


func _unhandled_input(event: InputEvent) -> void:
	if get_tab_count() <= 1:
		return;

	var focus_owner: Control = get_viewport().gui_get_focus_owner();
	if focus_owner == null or not (focus_owner is Button):
		return;
	if _tab_buttons.find(focus_owner as Button) < 0:
		return;

	if event.is_action_pressed(&"ui_up" if sidebar else &"ui_left"):
		set_current_tab((current_tab - 1 + get_tab_count()) % get_tab_count());
		_focus_tab_button(current_tab);
		get_viewport().set_input_as_handled();
		return;

	if event.is_action_pressed(&"ui_down" if sidebar else &"ui_right"):
		set_current_tab((current_tab + 1) % get_tab_count());
		_focus_tab_button(current_tab);
		get_viewport().set_input_as_handled();


func _rebuild_tabs() -> void:
	for child: Node in tabs_container.get_children():
		tabs_container.remove_child(child);
		child.queue_free();

	_tab_buttons.clear();

	for tab_index: int in range(get_tab_count()):
		var tab_button: Button = Button.new();
		tab_button.toggle_mode = true;
		tab_button.alignment = HORIZONTAL_ALIGNMENT_LEFT if sidebar else HORIZONTAL_ALIGNMENT_CENTER;
		tab_button.focus_mode = Control.FOCUS_ALL;
		tab_button.text = _get_tab_title(tab_index);
		tab_button.pressed.connect(_on_tab_button_pressed.bind(tab_index));
		tabs_container.add_child(tab_button);
		_tab_buttons.append(tab_button);

	_apply_focus_neighbors();


func _apply_current_tab(focus_page: bool) -> void:
	for page_index: int in range(get_tab_count()):
		var page: Control = _get_page(page_index);
		if page == null:
			continue;
		page.visible = page_index == current_tab;

	for button_index: int in range(_tab_buttons.size()):
		var tab_button: Button = _tab_buttons[button_index];
		tab_button.button_pressed = button_index == current_tab;
		_apply_tab_button_style(tab_button, button_index == current_tab);

	tab_changed.emit(get_current_tab_id(), current_tab);
	if focus_page:
		_focus_current_page();


func _get_tab_title(tab_index: int) -> String:
	if tab_index < tab_title_keys.size():
		return tr(tab_title_keys[tab_index]);

	var page: Node = _get_page(tab_index);
	return String(page.name) if page != null else "";


func _get_page(tab_index: int) -> Control:
	if tab_index < 0 or tab_index >= get_tab_count():
		return null;
	return pages_container.get_child(tab_index) as Control;


func _focus_current_page() -> void:
	var page: Control = _get_page(current_tab);
	if page == null:
		return;

	var focus_target: Control = UI_FOCUS_UTIL.find_first_focusable(page);
	if focus_target != null:
		focus_target.grab_focus();


func _focus_tab_button(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= _tab_buttons.size():
		return;
	_tab_buttons[tab_index].grab_focus();


func _apply_focus_neighbors() -> void:
	for button_index: int in range(_tab_buttons.size()):
		var left_button: Button = _tab_buttons[(button_index - 1 + _tab_buttons.size()) % _tab_buttons.size()];
		var right_button: Button = _tab_buttons[(button_index + 1) % _tab_buttons.size()];
		_tab_buttons[button_index].focus_neighbor_left = _tab_buttons[button_index].get_path_to(left_button);
		_tab_buttons[button_index].focus_neighbor_right = _tab_buttons[button_index].get_path_to(right_button);


func _apply_tab_button_style(button: Button, _is_selected: bool) -> void:
	button.theme_type_variation = &"UiNavigationItem" if sidebar else &"UiTabItem";


func _on_tab_button_pressed(tab_index: int) -> void:
	set_current_tab(tab_index, true);
