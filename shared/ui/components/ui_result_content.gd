@tool
extends VBoxContainer;
class_name UiResultContent;

signal primary_requested;
signal secondary_requested;

## Reusable results content. A game supplies outcome/metrics and handles intents.
func configure(title: String, message: String, metrics: Dictionary,
		primary_text: String, secondary_text: String) -> void:
	%Title.text = title;
	%Message.text = message;
	for child: Node in %Metrics.get_children():
		%Metrics.remove_child(child);
		child.queue_free();
	for label: Variant in metrics:
		var column: VBoxContainer = VBoxContainer.new();
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		var caption: Label = Label.new();
		caption.theme_type_variation = &"UiSmall";
		caption.text = str(label);
		var value_label: Label = Label.new();
		value_label.theme_type_variation = &"UiSection";
		value_label.text = str(metrics[label]);
		column.add_child(caption);
		column.add_child(value_label);
		%Metrics.add_child(column);
	%Primary.text = primary_text;
	%Secondary.text = secondary_text;

func _ready() -> void:
	%Primary.pressed.connect(func() -> void: primary_requested.emit());
	%Secondary.pressed.connect(func() -> void: secondary_requested.emit());

