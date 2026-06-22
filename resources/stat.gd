class_name Stat
extends Resource

@export var max_value: int = 100
@export var current_value: int = 100

## Réduit la valeur (dégâts, dépense). Ne descend jamais sous 0.
func reduce(amount: int) -> void:
	current_value = max(0, current_value - amount)

## Augmente la valeur (soin, récupération). Ne dépasse jamais max_value.
func restore(amount: int) -> void:
	current_value = min(max_value, current_value + amount)

## Remet à plein (début de combat, repos...).
func reset_to_full() -> void:
	current_value = max_value

## Vrai si la ressource est épuisée.
func is_empty() -> bool:
	return current_value <= 0
