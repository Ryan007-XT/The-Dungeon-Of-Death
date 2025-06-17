extends CharacterBody2D

const SPEED = 180.0
const AIR_SPEED_MULTIPLIER = 0.9  # 70% dari kecepatan saat lompat
const JUMP_VELOCITY = -250.0
const GRAVITY = 1000.0

@onready var anim = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Tambahkan gravitasi
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Lompat
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Ambil arah input
	var direction := Input.get_axis("run-left", "run-right")

	if direction != 0:
		var current_speed = SPEED
		if not is_on_floor():
			current_speed *= AIR_SPEED_MULTIPLIER  # Kurangi kecepatan saat di udara

		velocity.x = direction * current_speed
		anim.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Animasi prioritas
	if not is_on_floor():
		if anim.animation != "Jump":
			anim.play("Jump")
	elif direction != 0:
		if anim.animation != "Run":
			anim.play("Run")
	else:
		if anim.animation != "Idle":
			anim.play("Idle")

	move_and_slide()
