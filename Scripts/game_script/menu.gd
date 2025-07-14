extends Control

func _ready():
	$Button.pressed.connect(_on_start_pressed)
	$Button2.pressed.connect(_on_exit_pressed)

func _on_start_pressed():
	get_tree().change_scene_to_file("res://Scene/debug.tscn")

func _on_exit_pressed():
	get_tree().quit()
