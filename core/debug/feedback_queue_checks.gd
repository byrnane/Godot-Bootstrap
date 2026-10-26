extends RefCounted;


static func run(runner: Node) -> Array[String]:
	var failures: Array[String] = [];
	var shell: Node = runner.get_tree().root.get_node("UiShell");
	var feedback: Node = runner.get_tree().root.get_node("UiFeedback");
	var modal: FeedbackModal = shell.get_node("ModalLayer/FeedbackModal");
	shell.close_all_modals();
	await _settle(runner);
	for action: String in ["confirm", "cancel", "alert", "alert_cancel"]:
		await _check_close_overlap(runner, feedback, modal, action, failures);
	await _check_cancel_all(runner, shell, feedback, modal, failures);
	await _check_close_before_open(runner, shell, feedback, modal, failures);
	return failures;


static func _check_close_overlap(runner: Node, feedback: Node, modal: FeedbackModal, action: String, failures: Array[String]) -> void:
	var events: Array[String] = [];
	var opened: Callable = func() -> void: events.append("opened:" + modal.message_label.text);
	var closed: Callable = func() -> void: events.append("closed:" + modal.message_label.text);
	modal.opened.connect(opened);
	modal.closed.connect(closed);
	if action.begins_with("alert"):
		feedback.alert("first", func() -> void: events.append("first:ack"));
	else:
		feedback.confirm("first", func() -> void: events.append("first:yes"), func() -> void: events.append("first:no"));
	await _settle(runner);
	if action == "cancel" or action == "alert_cancel":
		modal.request_close();
	else:
		modal.confirm_button.pressed.emit();
	# A second intent during the same close must neither change the result nor
	# start a second waiter on the modal's next closed signal.
	modal.confirm_button.pressed.emit();
	modal.request_close();
	if action.begins_with("alert"):
		feedback.confirm("second", func() -> void: events.append("second:yes"), func() -> void: events.append("second:no"));
	else:
		feedback.alert("second", func() -> void: events.append("second:ack"));
	await _settle(runner);
	var first_result: String = "first:ack" if action.begins_with("alert") else ("first:no" if action == "cancel" else "first:yes");
	_check(events == ["opened:first", "closed:first", first_result, "opened:second"],
		action + " reopened feedback before its previous close/callback finished: " + str(events), failures);
	_check(modal.visible and modal.message_label.text == "second", action + " lost the queued dialog", failures);
	modal.confirm_button.pressed.emit();
	modal.request_close();
	await _settle(runner);
	var second_result: String = "second:yes" if action.begins_with("alert") else "second:ack";
	_check(events == ["opened:first", "closed:first", first_result, "opened:second", "closed:second", second_result],
		action + " resolved a callback more than once or against another dialog: " + str(events), failures);
	_check(not modal.visible, action + " left feedback visible after its queue drained", failures);
	modal.opened.disconnect(opened);
	modal.closed.disconnect(closed);


static func _check_cancel_all(runner: Node, shell: Node, feedback: Node, modal: FeedbackModal, failures: Array[String]) -> void:
	var events: Array[String] = [];
	var closed: Callable = func() -> void: events.append("closed:" + modal.message_label.text);
	var opened: Callable = func() -> void: events.append("opened:" + modal.message_label.text);
	modal.closed.connect(closed);
	modal.opened.connect(opened);
	var active_id: int = feedback.confirm("active", func() -> void: events.append("active:yes"), func() -> void:
		events.append("active:no");
		feedback.alert("replacement", func() -> void: events.append("replacement:ack"));
	);
	await _settle(runner);
	var queued_id: int = feedback.confirm("queued", func() -> void: events.append("queued:yes"), func() -> void: events.append("queued:no"));
	var queued_alert_id: int = feedback.alert("queued alert", func() -> void: events.append("queued:ack"));
	modal.confirm_button.pressed.emit();
	shell.close_all_modals();
	# Repeated stale UI signals must not resolve the request already canceled by
	# close_all_modals, including while its callback queued a replacement.
	modal.confirmed.emit(active_id);
	modal.canceled.emit(active_id);
	_check(events == ["opened:active", "active:no", "queued:no", "queued:ack"],
		"cancel-all did not resolve the captured queue once: " + str(events), failures);
	await _settle(runner);
	_check(events == ["opened:active", "active:no", "queued:no", "queued:ack", "closed:active", "opened:replacement"],
		"cancel callback interrupted the in-flight close: " + str(events), failures);
	_check(modal.visible and modal.message_label.text == "replacement", "cancel-all lost callback-created feedback", failures);
	# Public resolution is idempotent even after canceled requests left the queue.
	feedback.resolve_confirm(active_id, true);
	feedback.resolve_confirm(queued_id, true);
	feedback.resolve_alert(queued_alert_id);
	modal.request_close();
	await _settle(runner);
	_check(events == ["opened:active", "active:no", "queued:no", "queued:ack", "closed:active", "opened:replacement", "closed:replacement", "replacement:ack"],
		"cancel-all retained callbacks or stalled replacement feedback: " + str(events), failures);
	modal.closed.disconnect(closed);
	modal.opened.disconnect(opened);


static func _check_close_before_open(runner: Node, shell: Node, feedback: Node, modal: FeedbackModal, failures: Array[String]) -> void:
	var events: Array[String] = [];
	var opened: Callable = func() -> void: events.append("opened:" + modal.message_label.text);
	modal.opened.connect(opened);
	feedback.alert("not opened", func() -> void:
		events.append("canceled:ack");
		feedback.confirm("replacement", func() -> void: events.append("replacement:yes"));
	);
	shell.close_all_modals();
	await _settle(runner);
	_check(events == ["canceled:ack", "opened:replacement"], "deferred open survived cancel-all: " + str(events), failures);
	_check(modal.visible and modal.message_label.text == "replacement", "immediate cancel-all stalled replacement feedback", failures);
	modal.confirm_button.pressed.emit();
	await _settle(runner);
	_check(events == ["canceled:ack", "opened:replacement", "replacement:yes"], "replacement confirmation did not finish once: " + str(events), failures);
	_check(not modal.visible, "immediate cancel-all left feedback visible", failures);
	modal.opened.disconnect(opened);


static func _settle(runner: Node) -> void:
	await runner.get_tree().create_timer(0.3).timeout;


static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("feedback: " + message);
