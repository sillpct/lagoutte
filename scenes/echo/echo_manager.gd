class_name EchoManager
extends Node

@export var combat_manager: CombatManager
@export var echo_ui: Node

func collect_echo(echo_object: Node, _player: Node3D, _revealed_by_lucidite: bool = false) -> bool:
	if echo_object == null or not is_instance_valid(echo_object):
		return false
	if combat_manager != null and combat_manager.is_combat_active():
		return false

	var flag: String = echo_object.get_collected_flag()
	if flag.is_empty():
		push_warning("EchoManager : impossible de recueillir un Écho sans echo_id ni collected_flag.")
		return false
	if GameState.has_flag(flag):
		return false

	GameState.set_flag(flag, true)
	if echo_ui != null:
		echo_ui.show_echo(echo_object.echo_text)
	return true
