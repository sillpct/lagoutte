class_name SequenceTrigger
extends Area3D

@export var sequence_id: StringName = &"afflux_window"
@export var trigger_id: String = ""
@export var triggered_flag: String = ""
@export var scripted_sequence_manager: ScriptedSequenceManager

func interact(_player: Node3D) -> bool:
	var flag := get_triggered_flag()
	if flag.is_empty():
		push_warning("SequenceTrigger : impossible de déclencher une séquence sans trigger_id ni triggered_flag.")
		return false
	if GameState.has_flag(flag):
		return false
	if scripted_sequence_manager == null:
		push_warning("SequenceTrigger : aucun ScriptedSequenceManager assigné.")
		return false

	if not scripted_sequence_manager.start_named_sequence(sequence_id):
		return false

	GameState.set_flag(flag, true)
	return true

func get_triggered_flag() -> String:
	if not triggered_flag.is_empty():
		return triggered_flag
	if trigger_id.is_empty():
		return ""
	return "sequence_triggered_%s" % trigger_id
