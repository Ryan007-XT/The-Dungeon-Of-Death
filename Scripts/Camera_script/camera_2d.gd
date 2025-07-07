extends Camera2D

var shake_strength := 0
var shake_decay := 1

func start_shake(strength: float):
	shake_strength = strength

func _process(delta):
	if shake_strength > 0:
		var offset_x = randf_range(-shake_strength, shake_strength)
		var offset_y = randf_range(-shake_strength, shake_strength)
		offset = Vector2(offset_x, offset_y)
		shake_strength = max(shake_strength - shake_decay * delta, 0)
	else:
		offset = Vector2.ZERO
