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
		"set_flag": "ancient_stone_touched"
	},
	{
		"text": "S'éloigner",
		"set_flag": "ancient_stone_ignored"
	},
	{
		"text": "Reposer la main sur la pierre",
		"set_flag": "ancient_stone_touched",
		"require": ["ancient_stone_touched"]
	},
	{
		"text": "Poser la main là où ça brûle",
		"damage": 30
	}

]
