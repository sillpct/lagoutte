class_name EchoManager
extends Node

@export var combat_manager: CombatManager
@export var echo_ui: Node
@export var unit_path_mover: UnitPathMover
@export var silence_duration := 2.0

var _cooldown_until_msec := 0
var _pending_echoes: Array[Dictionary] = []
var _retry_scheduled := false

func collect_echo(echo_object: Node, _player: Node3D, _revealed_by_lucidite: bool = false) -> bool:
	if echo_object == null or not is_instance_valid(echo_object):
		return false
	if combat_manager != null and combat_manager.is_combat_active():
		return false

	var flag: String = str(echo_object.call("get_collected_flag"))
	if flag.is_empty():
		push_warning("EchoManager : impossible de recueillir un Écho sans echo_id ni collected_flag.")
		return false
	if GameState.has_flag(flag):
		return false

	if _is_in_cooldown():
		_queue_pending_echo(echo_object, _player)
		_schedule_pending_retry()
		return true

	_trigger_echo(echo_object, flag)
	return true

func _trigger_echo(echo_object: Node, flag: String) -> void:
	if unit_path_mover != null:
		unit_path_mover.cancel_current_move()
	GameState.set_flag(flag, true)
	if echo_ui != null:
		echo_ui.show_echo(str(echo_object.get("echo_text")))
	_cooldown_until_msec = Time.get_ticks_msec() + int(silence_duration * 1000.0)

func _is_in_cooldown() -> bool:
	return Time.get_ticks_msec() < _cooldown_until_msec

func _queue_pending_echo(echo_object: Node, player: Node3D) -> void:
	for pending_echo in _pending_echoes:
		if pending_echo.get("echo_object") == echo_object:
			return
	_pending_echoes.append({
		"echo_object": echo_object,
		"player": player,
	})

func _schedule_pending_retry(delay_override: float = -1.0) -> void:
	if _retry_scheduled:
		return
	_retry_scheduled = true

	var delay := delay_override
	if delay < 0.0:
		var remaining_msec: int = maxi(0, _cooldown_until_msec - Time.get_ticks_msec())
		delay = maxf(0.05, float(remaining_msec) / 1000.0)

	await get_tree().create_timer(delay).timeout
	_retry_scheduled = false
	_process_pending_echoes()

func _process_pending_echoes() -> void:
	if _pending_echoes.is_empty():
		return
	if combat_manager != null and combat_manager.is_combat_active():
		_schedule_pending_retry(0.5)
		return
	if _is_in_cooldown():
		_schedule_pending_retry()
		return

	while not _pending_echoes.is_empty():
		var pending_echo: Dictionary = _pending_echoes.pop_front()
		var echo_object := pending_echo.get("echo_object") as Node
		if echo_object == null or not is_instance_valid(echo_object):
			continue
		var flag: String = str(echo_object.call("get_collected_flag"))
		if flag.is_empty() or GameState.has_flag(flag):
			continue

		_trigger_echo(echo_object, flag)
		if not _pending_echoes.is_empty():
			_schedule_pending_retry()
		return
