class_name EchoZone
extends Area3D

@export var echo_id: String = ""
@export_multiline var echo_text: String = ""
@export var collected_flag: String = ""

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func get_collected_flag() -> String:
	if not collected_flag.is_empty():
		return collected_flag
	if echo_id.is_empty():
		return ""
	return "echo_collected_%s" % echo_id

func is_collected() -> bool:
	var flag := get_collected_flag()
	return not flag.is_empty() and GameState.has_flag(flag)

func _on_body_entered(body: Node3D) -> void:
	if body == null or not body.is_in_group("player"):
		return

	var manager := _get_echo_manager()
	if manager == null:
		push_warning("EchoZone : aucun EchoManager trouvé dans la scène.")
		return

	manager.call("collect_echo", self, body)

func _get_echo_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("echo_manager")
