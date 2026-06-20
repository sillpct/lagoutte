extends Node

var current_incarnation_id: String = ""

var discovered_clues: Array[String] = []

var faction_reputation: Dictionary = {}

var unlocked_progression: Dictionary = {}

var story_flags: Dictionary = {}

## Remise à zéro COMPLÈTE de la partie. Réservé à « Nouvelle Partie ».
## Le changement d'incarnation en jeu NE doit PAS appeler ceci :
## le monde doit conserver sa mémoire à travers les incarnations.
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

func check_condition(require: Array = [], forbid: Array = []) -> bool:

	for f in require:
		if not has_flag(f):
			return false
	for f in forbid:
		if has_flag(f):
			return false
	return true
