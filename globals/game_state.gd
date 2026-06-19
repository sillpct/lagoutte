extends Node

var current_incarnation_id: String = ""

var discovered_clues: Array[String] = []

var faction_reputation: Dictionary = {}

var unlocked_progression: Dictionary = {}

var story_flags: Dictionary = {}

func reset() -> void:

	current_incarnation_id = ""
	discovered_clues.clear()
	faction_reputation.clear()
	unlocked_progression.clear()
	story_flags.clear()

func set_flag(flag_name: String, value = true) -> void:

	story_flags[flag_name] = value
	print("FLAG SET : ", flag_name, " = ", value)

func has_flag(flag_name: String) -> bool:

	return story_flags.get(flag_name, false)
