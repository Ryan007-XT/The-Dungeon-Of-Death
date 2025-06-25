extends CharacterBody2D

# Constants
const SPEED = 150.0
const AIR_SPEED_MULTIPLIER = 0.9
const INITIAL_JUMP_VELOCITY = -200.0
const MAX_JUMP_HOLD_TIME = 0.5
const EXTRA_JUMP_FORCE = -400.0
const GRAVITY = 1000.0
const COMBO_RESET_TIME = 0.5

# Node references
@onready var anim_player = $"../AnimationPlayer"
@onready var sprite = $AnimatedSprite2D
@onready var sfx_run = $Dirt_run_SFX
@onready var sfx_jump = $Dirt_jump_SFX
@onready var sfx_land = $Dirt_land_SFX
@onready var sfx_attack_1 = $Attack_SFX_1
@onready var sfx_attack_2 = $Attack_SFX_2
@onready var hitboxes = {
	"Attack-1": $AreaAttack_1,
	"Attack-2": $AreaAttack_2,
	"Attack-3": $AreaAttack_3
}

# Hitbox flip system
var original_hitbox_positions = {}

# State variables
var is_jumping := false
var jump_hold_timer := 0.0
var was_on_floor := true

# Attack combo state
var attack_phase := 0
var combo_timer := 0.0
var is_attacking := false
var current_attack_name := ""
var can_chain_attack := false

# State machine
enum PlayerState { GROUND, AIR, CROUCH, ATTACK }
var current_state = PlayerState.GROUND

func _ready():
	anim_player.animation_finished.connect(_on_animation_finished)
	
	# Initialize hitbox positions and disable hitboxes
	for attack_name in hitboxes:
		var hitbox = hitboxes[attack_name]
		original_hitbox_positions[attack_name] = hitbox.position
		hitbox.monitoring = false
		hitbox.get_node("CollisionShape2D").disabled = true

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	update_timers(delta)
	handle_state_transitions()
	process_state_behavior(delta)
	handle_landing_detection()
	move_and_slide()
	update_hitbox_direction()  # Update hitbox position based on facing

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

func update_timers(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
	elif is_attacking:
		reset_combo()

func handle_state_transitions() -> void:
	if is_attacking:
		current_state = PlayerState.ATTACK
	elif is_on_floor() and Input.is_action_pressed("crouch"):
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
			process_attack_input()
		PlayerState.AIR:
			process_air_movement()
			process_jump_extension(delta)
			process_attack_input()
		PlayerState.CROUCH:
			process_crouch_behavior()
		PlayerState.ATTACK:
			velocity.x = 0

	update_animation_and_sfx()

func process_ground_movement() -> void:
	var direction = Input.get_axis("run-left", "run-right")
	if direction != 0:
		velocity.x = direction * SPEED
		if sprite.flip_h != (direction < 0):
			sprite.flip_h = direction < 0
			update_hitbox_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func process_air_movement() -> void:
	var direction = Input.get_axis("run-left", "run-right")
	if direction != 0:
		velocity.x = direction * SPEED * AIR_SPEED_MULTIPLIER
		if sprite.flip_h != (direction < 0):
			sprite.flip_h = direction < 0
			update_hitbox_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

# HITBOX FLIP SYSTEM =====================================================
func update_hitbox_direction():
	for attack_name in hitboxes:
		var hitbox = hitboxes[attack_name]
		var original_pos = original_hitbox_positions[attack_name]
		
		if sprite.flip_h:
			hitbox.position.x = -original_pos.x
			hitbox.scale.x = -1
		else:
			hitbox.position.x = original_pos.x
			hitbox.scale.x = 1
# END OF HITBOX FLIP SYSTEM ==============================================

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
	else:
		is_jumping = false

func process_crouch_behavior() -> void:
	velocity.x = 0
	if not Input.is_action_pressed("crouch"):
		current_state = PlayerState.GROUND

func process_attack_input() -> void:
	if Input.is_action_just_pressed("attack"):
		if is_attacking:
			can_chain_attack = true
		else:
			start_attack()

func start_attack() -> void:
	is_attacking = true
	combo_timer = COMBO_RESET_TIME

	if attack_phase < 3:
		attack_phase += 1
	else:
		attack_phase = 1

	current_attack_name = "Attack-%d" % attack_phase
	activate_hitbox(current_attack_name)
	anim_player.play(current_attack_name)

	# Play attack sound based on phase
	match attack_phase:
		1, 3:
			sfx_attack_1.play()
		2:
			sfx_attack_2.play()

func activate_hitbox(attack_true: String) -> void:
	for attack_false in hitboxes:
		hitboxes[attack_false].monitoring = false
		hitboxes[attack_false].get_node("CollisionShape2D").disabled = true
	
	if hitboxes.has(attack_true):
		hitboxes[attack_true].monitoring = true
		hitboxes[attack_true].get_node("CollisionShape2D").disabled = false

func reset_combo() -> void:
	is_attacking = false
	current_attack_name = ""
	combo_timer = 0.0
	can_chain_attack = false

	for hitbox in hitboxes.values():
		hitbox.monitoring = false
		hitbox.get_node("CollisionShape2D").disabled = true

func _on_animation_finished(anim_name):
	if anim_name.begins_with("Attack-"):
		if can_chain_attack:
			can_chain_attack = false
			start_attack()
		else:
			reset_combo()

func update_animation_and_sfx() -> void:
	if is_attacking:
		sfx_run.stop()
		return

	var direction = Input.get_axis("run-left", "run-right")

	match current_state:
		PlayerState.AIR:
			if anim_player.current_animation != "Jump":
				anim_player.play("Jump")
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
