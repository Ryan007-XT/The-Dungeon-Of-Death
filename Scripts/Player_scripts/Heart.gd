extends Node2D

enum HEART_STATE { FULL, HALF, EMPTY }

@onready var sprite: Sprite2D = $Sprite2D

func set_state(state: HEART_STATE):
	sprite.frame = state
