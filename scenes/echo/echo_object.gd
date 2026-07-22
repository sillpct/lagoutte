class_name EchoObject
extends Area3D

@export var echo_id: String = ""
@export var lucidite_required: int = 0
@export_multiline var echo_text: String = ""
@export var collected_flag: String = ""

func interact(player: Node3D) -> void:
	var manager: Node = _get_echo_manager()
	if manager == null:
		push_warning("EchoObject : aucun EchoManager trouvé dans la scène.")
		return

	var revealed_by_lucidite := can_be_revealed_by(player)
	manager.collect_echo(self, player, revealed_by_lucidite)

func get_collected_flag() -> String:
	if not collected_flag.is_empty():
		return collected_flag
	if echo_id.is_empty():
		return ""
	return "echo_collected_%s" % echo_id

func is_collected() -> bool:
	var flag := get_collected_flag()
	return not flag.is_empty() and GameState.has_flag(flag)

func can_be_revealed_by(player: Node3D) -> bool:
	return _get_player_lucidite(player) >= lucidite_required

func _get_player_lucidite(player: Node3D) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var incarnation := player.get("incarnation") as IncarnationData
	if incarnation == null:
		return 0
	return incarnation.lucidite

func _get_echo_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("echo_manager")
