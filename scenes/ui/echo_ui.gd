class_name EchoUI
extends CanvasLayer

@export var veil_fade_in_duration := 0.18
@export var veil_hold_duration := 0.55
@export var veil_fade_out_duration := 0.25
@export var text_fade_in_duration := 0.2
@export var text_hold_duration := 2.4
@export var text_fade_out_duration := 0.35

@onready var veil: ColorRect = $Root/Veil
@onready var text_label: Label = $Root/TextLabel

var _veil_tween: Tween
var _text_tween: Tween

func _ready() -> void:
	veil.hide()
	text_label.hide()

func show_echo(text: String) -> void:
	if _veil_tween != null:
		_veil_tween.kill()
	if _text_tween != null:
		_text_tween.kill()

	text_label.text = text
	veil.modulate.a = 0.0
	text_label.modulate.a = 0.0
	veil.show()
	text_label.show()

	_veil_tween = create_tween()
	_veil_tween.tween_property(veil, "modulate:a", 1.0, veil_fade_in_duration)
	_veil_tween.tween_interval(veil_hold_duration)
	_veil_tween.tween_property(veil, "modulate:a", 0.0, veil_fade_out_duration)
	_veil_tween.tween_callback(veil.hide)

	_text_tween = create_tween()
	_text_tween.tween_property(text_label, "modulate:a", 1.0, text_fade_in_duration)
	_text_tween.tween_interval(text_hold_duration)
	_text_tween.tween_property(text_label, "modulate:a", 0.0, text_fade_out_duration)
	_text_tween.tween_callback(text_label.hide)
