class_name ScriptedSequenceManager
extends Node

signal sequence_started
signal sequence_finished

@export var unit_path_mover: UnitPathMover
@export var test_sequence_duration := 2.0

var _sequence_active := false
var _sequence_id := 0

func is_sequence_active() -> bool:
	return _sequence_active

func start_sequence() -> bool:
	if _sequence_active:
		return false

	_sequence_active = true
	_sequence_id += 1
	if unit_path_mover != null:
		unit_path_mover.cancel_current_move()
	sequence_started.emit()
	return true

func finish_sequence() -> void:
	if not _sequence_active:
		return

	_sequence_active = false
	_sequence_id += 1
	sequence_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_test_sequence"):
		start_test_sequence()
		get_viewport().set_input_as_handled()
		return

	if _sequence_active and event.is_action_pressed("ui_cancel"):
		finish_sequence()
		get_viewport().set_input_as_handled()
		return

func start_test_sequence() -> void:
	if not start_sequence():
		return

	var started_sequence_id := _sequence_id
	await get_tree().create_timer(test_sequence_duration).timeout
	if _sequence_active and _sequence_id == started_sequence_id:
		finish_sequence()
