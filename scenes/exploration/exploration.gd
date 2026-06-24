extends Node3D

@onready var combat_grid: CombatGrid = $CombatGrid
@onready var player: Node3D = $Player

func _ready() -> void:
	if not combat_grid.place_unit(player, 5, 5):
		push_warning("Impossible de placer le joueur sur la case de départ (5, 5).")
		return
	print(
		"Case (5, 5) — occupant : ", combat_grid.get_occupant(5, 5),
		" | libre : ", combat_grid.is_cell_free(5, 5)
	)
