extends Control

func _ready():
	$VBoxContainer/Button.pressed.connect(_on_start_pressed)
	$VBoxContainer/Button2.pressed.connect(_on_exit_pressed)
	$AnimatedSprite2D.play("default")

func _on_start_pressed():
	get_tree().change_scene_to_file("res://Scene/debug.tscn")

func _on_exit_pressed():
	get_tree().quit()
