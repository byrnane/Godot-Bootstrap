@tool
extends PanelContainer;
class_name UiResources;

## Missing resources are hidden, so games do not have to invent mana/stamina.
func apply_resources(values: Dictionary) -> void:
	for kind: String in ["health", "mana", "stamina"]:
		var bar: UiResourceBar = get_node("Margin/Bars/" + kind.capitalize() + "Bar") as UiResourceBar;
		bar.visible = values.has(kind);
		if bar.visible:
			bar.set_amount(float(values[kind]), float(values.get("max_" + kind, 100.0)));

