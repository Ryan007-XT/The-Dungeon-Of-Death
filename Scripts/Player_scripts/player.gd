extends CharacterBody2D

# === CONSTANTS ===
const SPEED = 150.0
const AIR_SPEED_MULTIPLIER = 1
const INITIAL_JUMP_VELOCITY = -230.0
const MAX_JUMP_HOLD_TIME = 0.5
const EXTRA_JUMP_FORCE = -450.0
const GRAVITY = 1000.0
const COMBO_RESET_TIME = 0.5
const DEFAULT_COLLISION_SIZE = Vector2(20, 47)
const DEFAULT_COLLISION_POSITION = Vector2(2, 8.5)
const CROUCH_COLLISION_SIZE = Vector2(20, 38)
const KNOCKBACK_FORCE = 250  # Added knockback force
const STUN_DURATION = 0.2     # Added stun duration

# === NODE REFERENCES ===
@onready var anim_player = $AnimationPlayer
@onready var sprite = $AnimatedSprite2D
@onready var collision_body = $CollisionShape2D
@onready var hurtbox_collision = $HurtBox/CollisionShape2D
@onready var hurtbox = $HurtBox
@onready var sfx_run = $Dirt_run_SFX
@onready var sfx_jump = $Dirt_jump_SFX
@onready var sfx_land = $Dirt_land_SFX
@onready var sfx_attack_1 = $Attack_SFX_1
@onready var sfx_attack_2 = $Attack_SFX_2
@onready var sfx_hurt = $Hurt_SFX       # Added hurt SFX
@onready var hitboxes = {
	"Attack-1": $HitBox_1,
	"Attack-2": $HitBox_2,
	"Attack-3": $HitBox_3,
	"Crouch-attack": $HitBox_crouch
}
@onready var heart_container = $HealthUI/HeartContainer

# === HEALTH SYSTEM ===
@export var heart_scene: PackedScene
var max_health: float = 10
var current_health: float = 10
var heart_sprites: Array[Sprite2D] = []
var is_dead: bool = false

# === STATE & COMBAT ===
var original_hitbox_positions = {}
var is_jumping := false
var jump_hold_timer := 0.0
var was_on_floor := true
var attack_phase := 0
var combo_timer := 0.0
var is_attacking := false
var current_attack_name := ""
var can_chain_attack := false
var is_hurt := false            # Added hurt state
var stun_timer := 0.0           # Added stun timer
var knockback_direction := Vector2.ZERO  # Added knockback direction

enum PlayerState { GROUND, AIR, CROUCH, ATTACK, HURT }  # Added HURT state
var current_state = PlayerState.GROUND

# === READY ===
func _ready():
	anim_player.animation_finished.connect(_on_animation_finished)
	hurtbox.area_entered.connect(_on_hurt_box_area_entered)  # Connect hurtbox signal

	for attack_name in hitboxes:
		var hitbox = hitboxes[attack_name]
		original_hitbox_positions[attack_name] = hitbox.position
		hitbox.monitoring = false
		hitbox.get_node("CollisionShape2D").disabled = true

	if collision_body:
		collision_body.position = DEFAULT_COLLISION_POSITION
		if collision_body.shape is RectangleShape2D:
			collision_body.shape.size = DEFAULT_COLLISION_SIZE

	if hurtbox_collision and hurtbox_collision.shape is RectangleShape2D:
		hurtbox_collision.shape.size = DEFAULT_COLLISION_SIZE
		hurtbox_collision.position = DEFAULT_COLLISION_POSITION

	spawn_hearts()
	update_hearts()

# === PHYSICS ===
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update stun timer
	if is_hurt:
		stun_timer -= delta
		if stun_timer <= 0:
			is_hurt = false
			current_state = PlayerState.GROUND if is_on_floor() else PlayerState.AIR

	apply_gravity(delta)
	update_timers(delta)
	handle_state_transitions()
	process_state_behavior(delta)
	handle_landing_detection()
	update_collision()
	move_and_slide()
	update_hitbox_direction()

# === GRAVITY ===
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

# === TIMERS ===
func update_timers(delta: float) -> void:
	if combo_timer > 0:
		combo_timer -= delta
	elif is_attacking:
		reset_combo()

# === STATE TRANSITIONS ===
func handle_state_transitions() -> void:
	if is_hurt:  # Hurt state has priority
		current_state = PlayerState.HURT
	elif is_attacking:
		current_state = PlayerState.ATTACK
	elif is_on_floor() and Input.is_action_pressed("crouch"):
		current_state = PlayerState.CROUCH
	elif is_on_floor():
		current_state = PlayerState.GROUND
	else:
		current_state = PlayerState.AIR

# === STATE BEHAVIOR ===
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
			process_attack_input()
		PlayerState.ATTACK:
			velocity.x = 0
		PlayerState.HURT:  # Added hurt state behavior
			process_hurt_state()

	update_animation_and_sfx()

# === HURT STATE HANDLING ===
func process_hurt_state():
	# Apply knockback
	velocity = knockback_direction * KNOCKBACK_FORCE
	# Prevent movement input during stun
	velocity.x = move_toward(velocity.x, 0, SPEED)

# === MOVEMENT ===
func process_ground_movement() -> void:
	if is_hurt: return  # Skip movement when hurt
	
	var direction = Input.get_axis("run-left", "run-right")
	if direction != 0:
		velocity.x = direction * SPEED
		if sprite.flip_h != (direction < 0):
			sprite.flip_h = direction < 0
			update_hitbox_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func process_air_movement() -> void:
	if is_hurt: return  # Skip movement when hurt
	
	var direction = Input.get_axis("run-left", "run-right")
	if direction != 0:
		velocity.x = direction * SPEED * AIR_SPEED_MULTIPLIER
		if sprite.flip_h != (direction < 0):
			sprite.flip_h = direction < 0
			update_hitbox_direction()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func update_hitbox_direction():
	for attack_name in hitboxes:
		var hitbox = hitboxes[attack_name]
		var original_pos = original_hitbox_positions[attack_name]
		hitbox.position.x = -original_pos.x if sprite.flip_h else original_pos.x
		hitbox.scale.x = -1 if sprite.flip_h else 1

# === JUMP ===
func process_jump() -> void:
	if is_hurt: return  # Prevent jumping when hurt
	if Input.is_action_just_pressed("jump"):
		start_jump()

func start_jump() -> void:
	velocity.y = INITIAL_JUMP_VELOCITY
	is_jumping = true
	jump_hold_timer = 0.0
	anim_player.play("Jump")
	sfx_jump.play()

func process_jump_extension(delta: float) -> void:
	if is_hurt: return  # Prevent jump extension when hurt
	if is_jumping and Input.is_action_pressed("jump") and not is_on_ceiling():
		jump_hold_timer += delta
		if jump_hold_timer < MAX_JUMP_HOLD_TIME:
			velocity.y += EXTRA_JUMP_FORCE * delta
		else:
			is_jumping = false
	else:
		is_jumping = false

# === CROUCH ===
func process_crouch_behavior() -> void:
	if is_hurt: return  # Prevent crouching when hurt
	
	velocity.x = 0
	if not Input.is_action_pressed("crouch") and can_stand_up():
		current_state = PlayerState.GROUND
	else:
		anim_player.play("Crouch-idle")

func can_stand_up() -> bool:
	var check_shape = RectangleShape2D.new()
	check_shape.size = DEFAULT_COLLISION_SIZE
	var check_position = global_position
	check_position.x += -DEFAULT_COLLISION_POSITION.x if sprite.flip_h else DEFAULT_COLLISION_POSITION.x
	check_position.y += DEFAULT_COLLISION_POSITION.y

	var space_state = get_world_2d().direct_space_state
	var params = PhysicsShapeQueryParameters2D.new()
	params.set_shape(check_shape)
	params.transform = Transform2D(0, check_position)
	params.collision_mask = collision_mask
	params.exclude = [self]

	return space_state.collide_shape(params, 1).is_empty()

# === COLLISION ===
func update_collision():
	if current_state == PlayerState.CROUCH or (current_state == PlayerState.ATTACK and current_attack_name == "Crouch-attack"):
		set_collision_crouch()
	else:
		set_collision_normal()

	if collision_body:
		collision_body.position.x = -DEFAULT_COLLISION_POSITION.x if sprite.flip_h else DEFAULT_COLLISION_POSITION.x
	if hurtbox_collision:
		hurtbox_collision.position.x = -DEFAULT_COLLISION_POSITION.x if sprite.flip_h else DEFAULT_COLLISION_POSITION.x

func set_collision_normal():
	if collision_body and collision_body.shape is RectangleShape2D:
		collision_body.shape.size = DEFAULT_COLLISION_SIZE
		collision_body.position.y = DEFAULT_COLLISION_POSITION.y
	if hurtbox_collision and hurtbox_collision.shape is RectangleShape2D:
		hurtbox_collision.shape.size = DEFAULT_COLLISION_SIZE
		hurtbox_collision.position.y = DEFAULT_COLLISION_POSITION.y

func set_collision_crouch():
	var height_diff = DEFAULT_COLLISION_SIZE.y - CROUCH_COLLISION_SIZE.y
	if collision_body and collision_body.shape is RectangleShape2D:
		collision_body.shape.size = CROUCH_COLLISION_SIZE
		collision_body.position.y = DEFAULT_COLLISION_POSITION.y + height_diff / 2.0
	if hurtbox_collision and hurtbox_collision.shape is RectangleShape2D:
		hurtbox_collision.shape.size = CROUCH_COLLISION_SIZE
		hurtbox_collision.position.y = DEFAULT_COLLISION_POSITION.y + height_diff / 2.0

# === ATTACK ===
func process_attack_input() -> void:
	if is_hurt: return  # Prevent attacking when hurt
	if Input.is_action_just_pressed("attack"):
		if is_attacking:
			can_chain_attack = true
		else:
			if current_state == PlayerState.CROUCH:
				start_crouch_attack()
			else:
				start_attack()

func start_attack() -> void:
	is_attacking = true
	combo_timer = COMBO_RESET_TIME
	attack_phase = attack_phase + 1 if attack_phase < 3 else 1
	current_attack_name = "Attack-%d" % attack_phase
	activate_hitbox(current_attack_name)
	anim_player.play(current_attack_name)

	match attack_phase:
		1, 3: sfx_attack_1.play()
		2: sfx_attack_2.play()

func start_crouch_attack() -> void:
	is_attacking = true
	combo_timer = COMBO_RESET_TIME
	current_attack_name = "Crouch-attack"
	activate_hitbox(current_attack_name)
	anim_player.play("Crouch-attack")
	sfx_attack_1.play()

func activate_hitbox(name: String) -> void:
	for n in hitboxes:
		hitboxes[n].monitoring = false
		hitboxes[n].get_node("CollisionShape2D").disabled = true
	if hitboxes.has(name):
		hitboxes[name].monitoring = true
		hitboxes[name].get_node("CollisionShape2D").disabled = false

func reset_combo() -> void:
	is_attacking = false
	current_attack_name = ""
	combo_timer = 0.0
	can_chain_attack = false
	for h in hitboxes.values():
		h.monitoring = false
		h.get_node("CollisionShape2D").disabled = true

func _on_animation_finished(anim_name):
	if anim_name == "Hurt":  # Handle hurt animation finish
		is_hurt = false
		current_state = PlayerState.GROUND if is_on_floor() else PlayerState.AIR
		return
		
	if anim_name.begins_with("Attack-") or anim_name == "Crouch-attack":
		if can_chain_attack:
			can_chain_attack = false
			start_attack()
		else:
			reset_combo()

# === HEALTH SYSTEM ===
func spawn_hearts():
	for child in heart_container.get_children():
		child.queue_free()
	heart_sprites.clear()

	var count = int(ceil(max_health))
	for i in count:
		var heart_panel = heart_scene.instantiate()
		heart_container.add_child(heart_panel)

		var heart_sprite = heart_panel.get_node("HeartSprite") as Sprite2D
		if heart_sprite:
			heart_sprites.append(heart_sprite)

func update_hearts():
	var health_left = current_health
	for heart_sprite in heart_sprites:
		if health_left >= 1.0:
			heart_sprite.frame = 0
			health_left -= 1.0
		elif health_left >= 0.5:
			heart_sprite.frame = 1
			health_left -= 0.5
		else:
			heart_sprite.frame = 2

# MODIFIED: Now takes damage source for knockback direction
func apply_damage_to_player(amount: float, source_position: Vector2):
	if is_dead or is_hurt:
		return

	current_health = max(current_health - amount, 0)
	update_hearts()

	if current_health <= 0:
		die()
	else:
		# Trigger hurt reaction
		trigger_hurt_reaction(source_position)

# FIXED: Handle hurt reaction with proper knockback direction
func trigger_hurt_reaction(source_position: Vector2):
	is_hurt = true
	current_state = PlayerState.HURT
	stun_timer = STUN_DURATION

	var horizontal_direction = 1 if source_position.x < global_position.x else -1

	# Atur proporsi knockback
	var horizontal_strength = 0.8    # makin besar makin jauh ke samping
	var vertical_strength = -0.1    # negatif = ke atas
	knockback_direction = Vector2(horizontal_direction * horizontal_strength, vertical_strength)

	anim_player.play("Hurt")
	sfx_hurt.play()

	if is_attacking:
		reset_combo()


func heal_player(amount: float):
	current_health = min(current_health + amount, max_health)
	update_hearts()

func add_max_heart(amount: float):
	max_health += amount
	current_health = min(current_health + amount, max_health)
	spawn_hearts()
	update_hearts()

func die():
	is_dead = true
	velocity = Vector2.ZERO
	anim_player.play("Death")
	anim_player.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)

func _on_death_animation_finished(anim_name: String) -> void:
	if anim_name == "Death":
		await get_tree().create_timer(0.5).timeout  # jeda opsional
		$DeathScene.play()  # mainkan video
		await $DeathScene.finished  # tunggu sampai video selesai
		get_tree().change_scene_to_file("res://Scene/menu.tscn")


# === ENEMY CALLBACKS ===
func _on_hit_box_1_area_entered(area: Area2D): 
	if area.is_in_group("enemies"): 
		area.get_parent().apply_damage(10, global_position)
		
func _on_hit_box_2_area_entered(area: Area2D): 
	if area.is_in_group("enemies"): 
		area.get_parent().apply_damage(15, global_position)
		
func _on_hit_box_3_area_entered(area: Area2D): 
	if area.is_in_group("enemies"): 
		area.get_parent().apply_damage(20, global_position)
		
func _on_hit_box_crouch_area_entered(area: Area2D): 
	if area.is_in_group("enemies"): 
		area.get_parent().apply_damage(12, global_position)

# NEW: Hurtbox damage handling
func _on_hurt_box_area_entered(area: Area2D):
	if area.is_in_group("enemy_attack"):
		# Get damage and source position from the attack area
		var damage_amount = area.damage
		var source_pos = area.global_position
		apply_damage_to_player(damage_amount, source_pos)

# === LANDING ===
func handle_landing_detection():
	if not was_on_floor and is_on_floor():
		sfx_land.play()
	was_on_floor = is_on_floor()

# === ANIMATION ===
func update_animation_and_sfx():
	if is_hurt:  # Skip other animations when hurt
		return
		
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
