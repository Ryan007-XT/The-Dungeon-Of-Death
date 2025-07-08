extends Camera2D

var shake_strength := 0.0
var shake_decay := 20.0  # Lebih cepat habis untuk hit ringan
var shake_frequency := 60.0  # Seberapa cepat vibrasi per detik
var time_passed := 0.0

func start_shake(strength: float):
	shake_strength = strength
	time_passed = 0.0

func _process(delta):
	if shake_strength > 0:
		time_passed += delta
		var offset_x = sin(time_passed * shake_frequency) * shake_strength
		var offset_y = cos(time_passed * shake_frequency) * shake_strength * 0.5
		offset = Vector2(offset_x, offset_y)
		shake_strength = max(shake_strength - shake_decay * delta, 0)
	else:
		offset = Vector2.ZERO
