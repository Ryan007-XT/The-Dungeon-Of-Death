extends CharacterBody2D

# Constants
const SPEED = 150.0
const AIR_SPEED_MULTIPLIER = 0.9
const INITIAL_JUMP_VELOCITY = -200.0
const MAX_JUMP_HOLD_TIME = 0.5
const EXTRA_JUMP_FORCE = -400.0
const GRAVITY = 1000.0
const SLIDE_DURATION = 0.5
const SLIDE_SPEED = 220
const SLIDE_COOLDOWN = 1.2

# Node references
@onready var anim_player = $"../AnimationPlayer"
@onready var sprite = $AnimatedSprite2D
@onready var sfx_run = $Dirt_run_SFX
@onready var sfx_jump = $Dirt_jump_SFX
@onready var sfx_land = $Dirt_land_SFX

# State variables
var slide_timer := 0.0
var slide_cooldown_timer := 0.0
var is_sliding := false
var is_jumping := false
var jump_hold_timer := 0.0
var was_on_floor := true

# State machine approach
enum PlayerState { GROUND, AIR, SLIDE, CROUCH }
var current_state = PlayerState.GROUND

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	update_timers(delta)
	handle_state_transitions()
	process_state_behavior(delta)
	handle_landing_detection()
	move_and_slide()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func update_timers(delta: float) -> void:
	slide_cooldown_timer = max(0.0, slide_cooldown_timer - delta)
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false

func handle_state_transitions() -> void:
	# Prioritaskan slide
	if is_sliding:
		current_state = PlayerState.SLIDE
	# Kemudian cek crouch hanya jika di ground dan tombol crouch ditekan
	elif is_on_floor() and Input.is_action_pressed("crouch") and not is_sliding:
		current_state = PlayerState.CROUCH
	elif is_on_floor():
		current_state = PlayerState.GROUND
	else:
		current_state = PlayerState.AIR

func process_state_behavior(delta: float) -> void:
	match current_state:
		PlayerState.GROUND:
			process_ground_movement()
			process_jump()
			process_slide_initiation()
		PlayerState.AIR:
			process_air_movement()
			process_jump_extension(delta)
		PlayerState.SLIDE:
			process_slide_movement()
		PlayerState.CROUCH:
			process_crouch_behavior()

	update_animation_and_sfx()

func process_ground_movement() -> void:
	var direction = Input.get_axis("run-left", "run-right")
	if direction != 0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func process_air_movement() -> void:
	var direction = Input.get_axis("run-left", "run-right")
	if direction != 0:
		velocity.x = direction * SPEED * AIR_SPEED_MULTIPLIER
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func process_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		start_jump()

func start_jump() -> void:
	velocity.y = INITIAL_JUMP_VELOCITY
	is_jumping = true
	jump_hold_timer = 0.0
	anim_player.play("Jump")
	sfx_jump.play()

func process_jump_extension(delta: float) -> void:
	if is_jumping and Input.is_action_pressed("jump") and not is_on_ceiling():
		jump_hold_timer += delta
		if jump_hold_timer < MAX_JUMP_HOLD_TIME:
			velocity.y += EXTRA_JUMP_FORCE * delta
		else:
			is_jumping = false

func process_slide_initiation() -> void:
	if Input.is_action_just_pressed("slide") and slide_cooldown_timer <= 0.0:
		start_slide()

func start_slide() -> void:
	is_sliding = true
	slide_timer = SLIDE_DURATION
	slide_cooldown_timer = SLIDE_COOLDOWN
	anim_player.play("Slide")

func process_slide_movement() -> void:
	velocity.x = -SLIDE_SPEED if sprite.flip_h else SLIDE_SPEED

func process_crouch_behavior() -> void:
	# Di state crouch, player tidak bisa bergerak
	velocity.x = 0
	
	# Kembali ke ground state jika tombol crouch dilepas
	if not Input.is_action_pressed("crouch"):
		current_state = PlayerState.GROUND

func update_animation_and_sfx() -> void:
	var direction = Input.get_axis("run-left", "run-right")
	
	match current_state:
		PlayerState.AIR:
			if anim_player.current_animation != "Jump":
				anim_player.play("Jump")
			sfx_run.stop()
		
		PlayerState.SLIDE:
			if anim_player.current_animation != "Slide":
				anim_player.play("Slide")
			sfx_run.stop()
		
		PlayerState.CROUCH:
			if anim_player.current_animation != "Crouch-idle":
				anim_player.play("Crouch-idle")
			sfx_run.stop()
		
		PlayerState.GROUND:
			if direction != 0:
				if anim_player.current_animation != "Run":
					anim_player.play("Run")
				if not sfx_run.playing:
					sfx_run.play()
			else:
				if anim_player.current_animation != "Idle":
					anim_player.play("Idle")
				sfx_run.stop()

func handle_landing_detection() -> void:
	if not was_on_floor and is_on_floor():
		sfx_land.play()
	was_on_floor = is_on_floor()
