extends Node

@warning_ignore("unused_signal")
signal game_started

@warning_ignore("unused_signal")
signal game_paused(is_paused: bool)

@warning_ignore("unused_signal")
signal interaction_requested(target: Node)

@warning_ignore("unused_signal")
signal combat_started

@warning_ignore("unused_signal")
signal combat_ended(victory: bool)

@warning_ignore("unused_signal")
signal turn_started(unit: Node)

@warning_ignore("unused_signal")
signal turn_ended(unit: Node)

@warning_ignore("unused_signal")
signal incarnation_changed(incarnation_id: String)

@warning_ignore("unused_signal")
signal clue_discovered(clue_id: String)

@warning_ignore("unused_signal")
signal reputation_changed(faction_id: String, new_value: int)

@warning_ignore("unused_signal")
signal xp_gained(amount: int)
