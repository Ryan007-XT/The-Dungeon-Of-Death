extends CharacterBody2D

var speed = 40
var gravity = 1000

var player = null
var player_chase = false
var is_attacking = false
var attack_cooldown = false
var player_in_hitbox = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_area = $HitboxArea
@onready var attack_timer = $Timer
@onready var raycast = $RayCast2D
@onready var walk_sfx = $Walk_SFX

var original_hitbox_transform: Transform2D

func _ready() -> void:
	# Masuk ke grup enemy (masih berguna kalau kamu ingin seleksi semua musuh nantinya)
	add_to_group("enemies")

	# Variasi kecepatan (range diperluas)
	speed += randf_range(-10, 10)

	attack_timer.wait_time = 1.0
	attack_timer.one_shot = true
	original_hitbox_transform = hitbox_area.transform

func _physics_process(delta):
	velocity.y += gravity * delta
	adjust_hitbox_transform()

	if is_attacking:
		pass
	elif player_in_hitbox and player != null:
		start_attack()
	elif player_chase and player != null and is_player_visible():
		chase_player()
	else:
		idle_state()

	move_and_slide()

func adjust_hitbox_transform():
	if animated_sprite.flip_h:
		hitbox_area.transform = Transform2D.FLIP_X * original_hitbox_transform
	else:
		hitbox_area.transform = original_hitbox_transform

func start_attack():
	is_attacking = true
	velocity.x = 0
	animated_sprite.play("Attack")
	attack_cooldown = true
	attack_timer.start()

	if walk_sfx.playing:
		walk_sfx.stop()

func chase_player():
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * speed

	if animated_sprite.animation != "Run":
		animated_sprite.play("Run")

	animated_sprite.flip_h = velocity.x < 0

	if not walk_sfx.playing:
		walk_sfx.play()

func idle_state():
	velocity.x = 0
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
