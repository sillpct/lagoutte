class_name SectRenegade
extends Node3D

@export var incarnation: IncarnationData

var pv: Stat

func _ready() -> void:
	pv = Stat.new()
	pv.max_value = incarnation.pv_max
	pv.reset_to_full()
	print("Renégat de secte — PV : ", pv.current_value, " / ", pv.max_value)
