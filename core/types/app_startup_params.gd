extends RefCounted;
class_name AppStartupParams;


enum LaunchMode {
	MAIN_MENU,
	START_SESSION,
}


var launch_mode: int = LaunchMode.MAIN_MENU;
var main_menu_scene_id: StringName = &"";
var session_start_params: RefCounted = null;
