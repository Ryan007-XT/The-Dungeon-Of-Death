extends CharacterBody2D

const SPEED = 180.0
const AIR_SPEED_MULTIPLIER = 0.9
const INITIAL_JUMP_VELOCITY = -200.0
const MAX_JUMP_HOLD_TIME = 0.5  # Lama maksimum tahan lompat
const EXTRA_JUMP_FORCE = -400.0  # Tambahan gaya loncat saat ditahan
const GRAVITY = 1000.0
const SLIDE_DURATION = 0.5
const SLIDE_SPEED = 220
const SLIDE_COOLDOWN = 1.2

@onready var anim_player = $"../AnimationPlayer"
@onready var sprite = $AnimatedSprite2D

var slide_timer := 0.0
var slide_cooldown_timer := 0.0
var is_sliding := false
var is_crouching := false

# Untuk long jump
var is_jumping := false
var jump_hold_timer := 0.0

func _physics_process(delta: float) -> void:
	# =============== GRAVITASI ===============
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# =============== UPDATE SLIDE COOLDOWN ===============
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer -= delta

	# =============== JUMP PRESS ===============
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_sliding:
		velocity.y = INITIAL_JUMP_VELOCITY
		is_jumping = true
		jump_hold_timer = 0.0
		anim_player.play("Jump")

	# =============== LONG JUMP HOLD ===============
	if is_jumping and Input.is_action_pressed("jump"):
		jump_hold_timer += delta
		if jump_hold_timer < MAX_JUMP_HOLD_TIME:
			velocity.y += EXTRA_JUMP_FORCE * delta
	else:
		is_jumping = false

	# =============== SLIDE ===============
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding and not is_crouching and slide_cooldown_timer <= 0.0:
		is_sliding = true
		slide_timer = SLIDE_DURATION
		slide_cooldown_timer = SLIDE_COOLDOWN
		anim_player.play("Slide")

	if is_sliding:
		slide_timer -= delta
		velocity.x = -SLIDE_SPEED if sprite.flip_h else SLIDE_SPEED
		if slide_timer <= 0.0:
			is_sliding = false

	# =============== CROUCH ===============
	if Input.is_action_pressed("crouch") and is_on_floor() and not is_sliding:
		if not is_crouching:
			velocity.x = 0
		is_crouching = true
		anim_player.play("Crouch-idle")
	else:
		is_crouching = false

	# =============== MOVEMENT ===============
	var direction := Input.get_axis("run-left", "run-right")

	if not is_sliding and not is_crouching:
		if direction != 0:
			var current_speed = SPEED
			if not is_on_floor():
				current_speed *= AIR_SPEED_MULTIPLIER
			velocity.x = direction * current_speed
			sprite.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	# =============== ANIMASI ===============
	if not is_sliding and not is_crouching:
		if not is_on_floor():
			if anim_player.current_animation != "Jump":
				anim_player.play("Jump")
		elif direction != 0:
			if anim_player.current_animation != "Run":
				anim_player.play("Run")
		else:
			if anim_player.current_animation != "Idle":
				anim_player.play("Idle")

	move_and_slide()
