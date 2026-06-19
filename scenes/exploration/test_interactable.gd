extends Area3D

@export var speaker_name := "Ancienne Pierre"

@export var dialogue_lines: Array[String] = [

	"Cette pierre semble ancienne.",
	"Sa surface est couverte de symboles.",
	"Tu ressens une étrange énergie."

]

@export var choices := [

	{
		"text": "Toucher la pierre",
		"effect": "touch_stone"
	},
	{
		"text": "S'éloigner",
		"effect": "leave_stone"
	},
	{
		"text": "Reposer la main sur la pierre",
		"effect": "touch_stone",
		"require": ["ancient_stone_touched"]
	}

]
