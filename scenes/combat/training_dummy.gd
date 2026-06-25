class_name TrainingDummy
extends Node3D

var pv: Stat

func _init() -> void:
	pv = Stat.new()
	pv.max_value = 50
	pv.reset_to_full()

func _ready() -> void:
	print("Mannequin — PV : ", pv.current_value, " / ", pv.max_value)
