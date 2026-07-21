class_name CombatAttack
extends Node

const ATTACK_PA_COST := 1
const MELEE_RANGE := 0.6

@export var grid: CombatGrid
@export var combat_manager: CombatManager
@export var combat_movement: CombatMovement
@export var active_unit: Node3D
@export var world_mouse_query: WorldMouseQuery

func _ready() -> void:
	if grid == null or combat_manager == null or combat_movement == null or active_unit == null or world_mouse_query == null:
		push_warning("CombatAttack a besoin d'une grille, d'un manager, du mouvement, d'une unité active et du service WorldMouseQuery.")
		return

func _unhandled_input(event: InputEvent) -> void:
	if grid == null or combat_manager == null or combat_movement == null or active_unit == null or world_mouse_query == null:
		return
	if not combat_manager.is_combat_active():
		return
	if combat_manager.is_action_locked():
		return

	if event.is_action_pressed("toggle_attack_mode"):
		combat_movement.toggle_attack_mode()
		get_viewport().set_input_as_handled()
		return

	if not is_attack_mode_active():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			try_player_attack_from_mouse(event.position)
			get_viewport().set_input_as_handled()
			return

func is_attack_mode_active() -> bool:
	return combat_movement != null and combat_movement.is_attack_mode_active()

func try_player_attack_from_mouse(_mouse_position: Vector2) -> void:
	if not combat_manager.is_combat_active():
		return

	var clicked_world_position := world_mouse_query.get_ground_point()
	if clicked_world_position == WorldMouseQuery.INVALID_WORLD_POSITION:
		return

	var target := _get_hovered_valid_target()
	var attack_started := false
	if target == null:
		if not CombatRules.is_within_world_range(active_unit.global_position, clicked_world_position, CombatAttack.get_standard_effective_melee_range()):
			print("Attaque refusée : hors de portée.")
			return
		attack_started = try_attack_empty(active_unit)
	else:
		attack_started = try_attack(active_unit, target)

	if attack_started:
		combat_movement.set_neutral_mode()

func try_attack(attacker: Node3D, target: Node3D) -> bool:
	if combat_manager.combat_over:
		return false
	if target == null or not is_instance_valid(target):
		print("Attaque refusée : cible invalide.")
		return false
	if target == attacker:
		print("Attaque refusée : cible invalide.")
		return false
	if not is_target_in_range(attacker, target):
		print("Attaque refusée : hors de portée.")
		return false
	if not (target.get("pv") is Stat):
		print("Attaque refusée : cible sans PV.")
		return false
	if not _spend_attack_pa(attacker):
		return false

	var damage := get_attack_damage(attacker)
	var target_pv := target.get("pv") as Stat
	target_pv.reduce(damage)
	combat_manager.notify_unit_resources_changed(target)
	print(
		attacker.name, " attaque ", target.name,
		" — dégâts: ", damage,
		", PV cible: ", target_pv.current_value, "/", target_pv.max_value,
		", PA restants: ", combat_manager.get_pa_current(attacker)
	)
	if target_pv.is_empty():
		combat_manager.remove_unit(target)

	return true

func try_attack_empty(attacker: Node3D) -> bool:
	if combat_manager.combat_over:
		return false
	if not _spend_attack_pa(attacker):
		return false

	print(
		attacker.name, " frappe dans le vide",
		" — PA restants: ", combat_manager.get_pa_current(attacker)
	)
	return true

func is_target_in_range(attacker: Node3D, target: Node3D) -> bool:
	if attacker == null or target == null or not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	var effective_range := get_effective_melee_range(attacker, target)
	return CombatRules.is_within_world_range(attacker.global_position, target.global_position, effective_range)

func get_effective_melee_range(attacker: Node3D, target: Node3D) -> float:
	return (
		MELEE_RANGE
		+ grid.get_unit_occupation_radius(attacker)
		+ grid.get_unit_occupation_radius(target)
	)

static func get_standard_effective_melee_range() -> float:
	return MELEE_RANGE + CombatGrid.DEFAULT_OCCUPATION_RADIUS * 2.0

func _spend_attack_pa(attacker: Node3D) -> bool:
	if combat_manager.get_current_unit() != attacker:
		print("Attaque refusée : ce n'est pas le tour de cette unité.")
		return false
	if not combat_manager.spend_pa(attacker, ATTACK_PA_COST):
		print("Attaque refusée : PA insuffisants.")
		return false
	return true

func _get_hovered_valid_target() -> Node3D:
	var target := world_mouse_query.get_hovered_unit()
	if target == null or not is_instance_valid(target):
		return null
	if target == active_unit:
		return null
	if not (target.get("pv") is Stat):
		return null
	return target

func get_attack_damage(attacker: Node3D) -> int:
	var incarnation := attacker.get("incarnation") as IncarnationData
	if incarnation == null:
		return 0
	return incarnation.force
