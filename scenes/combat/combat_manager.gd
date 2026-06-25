class_name CombatManager
extends Node

@export var units: Array[Node3D] = []

var current_unit_index := 0
var _resources_by_unit: Dictionary = {}
var _event_bus = null

func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if units.is_empty():
		push_warning("CombatManager n'a aucune unité à gérer.")
		return

	current_unit_index = 0
	start_turn(get_current_unit())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn"):
		end_turn()
		get_viewport().set_input_as_handled()

func start_turn(unit: Node3D) -> void:
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

	if _event_bus != null:
		_event_bus.turn_started.emit(unit)
	print(
		"Tour de ", unit.name,
		" — PM: ", get_pm_current(unit), "/", get_pm_max(unit),
		", PA: ", get_pa_current(unit), "/", get_pa_max(unit)
	)

func end_turn() -> void:
	if units.is_empty():
		return

	var unit := get_current_unit()
	if _event_bus != null:
		_event_bus.turn_ended.emit(unit)
	print("Fin du tour de ", unit.name)

	current_unit_index = wrapi(current_unit_index + 1, 0, units.size())
	start_turn(get_current_unit())

func get_current_unit() -> Node3D:
	if units.is_empty():
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

func _get_unit_resource(unit: Node3D, resource_name: String) -> int:
	if not _resources_by_unit.has(unit):
		return 0
	return int(_resources_by_unit[unit].get(resource_name, 0))
