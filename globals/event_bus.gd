extends Node

signal game_started

signal game_paused(is_paused: bool)

signal interaction_requested(target: Node)

signal combat_started

signal combat_ended(victory: bool)

signal turn_started(unit: Node)

signal turn_ended(unit: Node)

signal incarnation_changed(incarnation_id: String)

signal clue_discovered(clue_id: String)

signal reputation_changed(faction_id: String, new_value: int)

signal xp_gained(amount: int)
