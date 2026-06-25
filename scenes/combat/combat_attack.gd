class_name CombatAttack
extends Node

const ATTACK_RANGE := 1
const ATTACK_PA_COST := 1
const NORMAL_CELL_COLOR := Color(0.22, 0.28, 0.32)
const ATTACK_CELL_COLOR := Color(0.85, 0.12, 0.10)
const CURSOR_CELL_COLOR := Color(1.0, 0.85, 0.15)
const TEST_TARGET_CELL := Vector2i(6, 5)

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var combat_movement: CombatMovement
@export var active_unit: Node3D
@export var test_target: Node3D

var _attack_mode_active := false
var _attack_cells: Array[Vector2i] = []
var _event_bus = null

func _ready() -> void:
	if grid == null or combat_manager == null or combat_movement == null or active_unit == null:
		push_warning("CombatAttack a besoin d'une grille, d'un manager, du mouvement et d'une unité active.")
		return

	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null and not _event_bus.turn_started.is_connected(_on_turn_started):
		_event_bus.turn_started.connect(_on_turn_started)

	if test_target != null and not grid.place_unit(test_target, TEST_TARGET_CELL.x, TEST_TARGET_CELL.y):
		push_warning("Impossible de placer le mannequin sur la case de test (6, 5).")
	elif test_target != null:
		combat_movement._refresh_reachable_cells()

func _unhandled_input(event: InputEvent) -> void:
	if grid == null or combat_manager == null or combat_movement == null or active_unit == null:
		return

	if event.is_action_pressed("toggle_attack_mode"):
		set_attack_mode_active(not _attack_mode_active)
		get_viewport().set_input_as_handled()
		return

	if not _attack_mode_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			try_attack_selected_cell()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept"):
		try_attack_selected_cell()
		get_viewport().set_input_as_handled()

func is_attack_mode_active() -> bool:
	return _attack_mode_active

func set_attack_mode_active(is_active: bool) -> void:
	_attack_mode_active = is_active
	if _attack_mode_active:
		_refresh_attack_cells()
		print("Mode attaque : actif")
	else:
		print("Mode attaque : inactif")
		combat_movement._refresh_reachable_cells()

func try_attack_selected_cell() -> void:
	if combat_manager.get_current_unit() != active_unit:
		print("Attaque refusée : ce n'est pas le tour de cette unité.")
		return

	var target_cell := combat_movement.cursor_cell
	if not _attack_cells.has(target_cell):
		print("Attaque refusée : case hors portée.")
		return

	var target := grid.get_occupant(target_cell.x, target_cell.y)
	if target == null or target == active_unit:
		print("Attaque refusée : aucune cible valide sur cette case.")
		return
	if not (target.get("pv") is Stat):
		print("Attaque refusée : la cible n'a pas de PV.")
		return

	if not combat_manager.spend_pa(active_unit, ATTACK_PA_COST):
		print("Attaque refusée : PA insuffisants.")
		return

	var damage := get_attack_damage()
	var target_pv := target.get("pv") as Stat
	target_pv.reduce(damage)
	print(
		active_unit.name, " attaque ", target.name,
		" — dégâts: ", damage,
		", PV cible: ", target_pv.current_value, "/", target_pv.max_value,
		", PA restants: ", combat_manager.get_pa_current(active_unit)
	)
	_refresh_attack_cells()

func get_attack_damage() -> int:
	var incarnation := active_unit.get("incarnation") as IncarnationData
	if incarnation == null:
		return 0
	return incarnation.force

func refresh_attack_display() -> void:
	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			grid.set_cell_color(col, row, NORMAL_CELL_COLOR)

	for cell in _attack_cells:
		grid.set_cell_color(cell.x, cell.y, ATTACK_CELL_COLOR)

	grid.set_cell_color(combat_movement.cursor_cell.x, combat_movement.cursor_cell.y, CURSOR_CELL_COLOR)

func _refresh_attack_cells() -> void:
	_attack_cells = get_attack_cells()
	print("Cases d'attaque : ", _attack_cells)
	refresh_attack_display()

func get_attack_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if combat_manager.get_current_unit() != active_unit:
		return result

	var origin := grid.world_to_cell(active_unit.global_position)
	for row in range(grid.grid_height):
		for col in range(grid.grid_width):
			var cell := Vector2i(col, row)
			if _get_manhattan_distance(origin, cell) <= ATTACK_RANGE and cell != origin:
				result.append(cell)
	return result

func _on_turn_started(unit: Node) -> void:
	if unit != active_unit or not _attack_mode_active:
		return
	_refresh_attack_cells()

func _get_manhattan_distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	return abs(to_cell.x - from_cell.x) + abs(to_cell.y - from_cell.y)
