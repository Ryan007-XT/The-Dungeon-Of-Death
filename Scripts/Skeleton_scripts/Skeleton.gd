extends Node2D

var speed = 40
var gravity = 1000

var player = null
var player_chase = false
var is_attacking = false
var attack_cooldown = false
var player_in_hitbox = false

@onready var character_body = $CharacterBody2D
@onready var animated_sprite = $CharacterBody2D/AnimatedSprite2D
@onready var hitbox_area = $CharacterBody2D/HitboxArea
@onready var attack_timer = $CharacterBody2D/Timer
@onready var raycast = $CharacterBody2D/RayCast2D
@onready var walk_sfx = $CharacterBody2D/Walk_SFX
@onready var attack_sfx = $CharacterBody2D/Attack_SFX

var original_hitbox_transform: Transform2D

func _ready() -> void:
	add_to_group("enemies")
	speed += randf_range(-10, 10)
	attack_timer.wait_time = 1.0
	attack_timer.one_shot = true
	original_hitbox_transform = hitbox_area.transform
	walk_sfx.pitch_scale = randf_range(0.7, 1.0)

func _physics_process(delta):
	# Terapkan gravitasi ke CharacterBody2D
	character_body.velocity.y += gravity * delta
	adjust_hitbox_transform()

	# Cek frame animasi untuk trigger SFX Attack
	if is_attacking and animated_sprite.animation == "Attack":
		var frame = animated_sprite.frame
		if frame == 4 or frame == 8:
			if not attack_sfx.playing:
				attack_sfx.pitch_scale = randf_range(2.9, 3.2)
				attack_sfx.play()

	if is_attacking:
		pass
	elif player_in_hitbox and player != null:
		start_attack()
	elif player_chase and player != null and is_player_visible():
		chase_player()
	else:
		idle_state()

	# Pindahkan CharacterBody2D
	character_body.move_and_slide()

func adjust_hitbox_transform():
	if animated_sprite.flip_h:
		hitbox_area.transform = Transform2D.FLIP_X * original_hitbox_transform
	else:
		hitbox_area.transform = original_hitbox_transform

func start_attack():
	is_attacking = true
	character_body.velocity.x = 0
	animated_sprite.play("Attack")
	attack_cooldown = true
	attack_timer.start()

	if walk_sfx.playing:
		walk_sfx.stop()

func chase_player():
	var direction = (player.global_position - character_body.global_position).normalized()
	character_body.velocity.x = direction.x * speed

	if animated_sprite.animation != "Run":
		animated_sprite.play("Run")

	animated_sprite.flip_h = character_body.velocity.x < 0

	if not walk_sfx.playing:
		walk_sfx.pitch_scale = randf_range(0.7, 1.0)
		walk_sfx.play()

func idle_state():
	character_body.velocity.x = 0
	if animated_sprite.animation != "Idle" and !is_attacking:
		animated_sprite.play("Idle")

	if walk_sfx.playing:
		walk_sfx.stop()

func is_player_visible() -> bool:
	if player == null:
		return false

	var direction = player.global_position - raycast.global_position
	raycast.target_position = direction
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		return collider == player
	else:
		return false

# Signal handlers
func _on_detection_area_body_entered(body: Node2D) -> void:
	player = body
	player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null
	player_chase = false

func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_hitbox = true

func _on_hitbox_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_hitbox = false

func _on_timer_timeout() -> void:
	is_attacking = false
	attack_cooldown = false

	if player_in_hitbox and player != null:
		start_attack()
