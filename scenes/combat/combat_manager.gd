class_name CombatManager
extends Node

@export var grid: CombatGrid
@export var units: Array[Node3D] = []

var current_unit_index := 0
var _resources_by_unit: Dictionary = {}
var _event_bus = null

func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if grid == null:
		push_warning("CombatManager a besoin d'une grille pour retirer proprement les unités mortes.")
	if units.is_empty():
		push_warning("CombatManager n'a aucune unité à gérer.")
		return

	current_unit_index = 0
	start_turn(get_current_unit())

func _unhandled_input(event: InputEvent) -> void:
	if get_current_unit() == null:
		return
	if event.is_action_pressed("end_turn"):
		end_turn()
		get_viewport().set_input_as_handled()

func start_turn(unit: Node3D) -> void:
	if unit == null:
		return

	var incarnation := unit.get("incarnation") as IncarnationData
	if incarnation == null:
		push_warning("Impossible de démarrer le tour : l'unité n'a pas d'incarnation.")
		return

	_resources_by_unit[unit] = {
		"pm_max": incarnation.points_mouvement,
		"pm_current": incarnation.points_mouvement,
		"pa_max": incarnation.points_action,
		"pa_current": incarnation.points_action,
	}

	print(
		"Tour de ", unit.name,
		" — PM: ", get_pm_current(unit), "/", get_pm_max(unit),
		", PA: ", get_pa_current(unit), "/", get_pa_max(unit)
	)
	if _event_bus != null:
		_event_bus.turn_started.emit(unit)

func end_turn() -> void:
	if units.is_empty():
		return

	var unit := get_current_unit()
	if unit == null:
		return
	if _event_bus != null:
		_event_bus.turn_ended.emit(unit)
	print("Fin du tour de ", unit.name)

	current_unit_index = wrapi(current_unit_index + 1, 0, units.size())
	start_turn(get_current_unit())

func get_current_unit() -> Node3D:
	if units.is_empty() or current_unit_index < 0 or current_unit_index >= units.size():
		return null
	return units[current_unit_index]

func get_pm_current(unit: Node3D) -> int:
	return _get_unit_resource(unit, "pm_current")

func get_pm_max(unit: Node3D) -> int:
	return _get_unit_resource(unit, "pm_max")

func spend_pm(unit: Node3D, amount: int) -> bool:
	if amount < 0 or get_pm_current(unit) < amount:
		return false

	_resources_by_unit[unit]["pm_current"] = get_pm_current(unit) - amount
	return true

func get_pa_current(unit: Node3D) -> int:
	return _get_unit_resource(unit, "pa_current")

func get_pa_max(unit: Node3D) -> int:
	return _get_unit_resource(unit, "pa_max")

func spend_pa(unit: Node3D, amount: int) -> bool:
	if amount < 0 or get_pa_current(unit) < amount:
		return false

	_resources_by_unit[unit]["pa_current"] = get_pa_current(unit) - amount
	return true

func remove_unit(unit: Node3D) -> void:
	if unit == null:
		return

	var removed_index := units.find(unit)
	if removed_index == -1:
		return

	if grid != null:
		var cell := grid.world_to_cell(unit.global_position)
		if grid.get_occupant(cell.x, cell.y) == unit:
			grid.clear_cell(cell.x, cell.y)

	units.remove_at(removed_index)
	_resources_by_unit.erase(unit)

	if removed_index < current_unit_index:
		current_unit_index -= 1
	if not units.is_empty():
		current_unit_index = clampi(current_unit_index, 0, units.size() - 1)
	else:
		current_unit_index = 0

	print(unit.name, " quitte le combat.")
	unit.queue_free()

func _get_unit_resource(unit: Node3D, resource_name: String) -> int:
	if not _resources_by_unit.has(unit):
		return 0
	return int(_resources_by_unit[unit].get(resource_name, 0))
