extends CharacterBody2D

@export var default_facing_left := false

var speed = 40
var gravity = 1000

var player = null
var player_chase = false
var is_attacking = false
var attack_cooldown = false
var player_in_hitbox = false

var max_hp := 100
var current_hp := 100
var is_dead = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_area = $HitboxArea
@onready var attack_timer = $Timer
@onready var raycast = $RayCast2D
@onready var walk_sfx = $Walk_SFX
@onready var attack_sfx = $Attack_SFX
@onready var hp_bar = $EnemyHP/HealthBar
@onready var dmg_bar = $EnemyHP/DamageBar
@onready var hp_timer = $EnemyHP/Timer
@onready var detection_area = $DetectionArea
@onready var collision_shape = $CollisionShape2D

var original_hitbox_transform: Transform2D
var flash_duration := 0.3

func _ready() -> void:
	add_to_group("enemies")
	$EnemyHP.visible = false

	speed += randf_range(-10, 10)

	attack_timer.wait_time = 1.0
	attack_timer.one_shot = true

	original_hitbox_transform = hitbox_area.transform

	walk_sfx.pitch_scale = randf_range(0.7, 1.0)

	animated_sprite.flip_h = default_facing_left
	adjust_hitbox_transform()

	hp_bar.max_value = max_hp
	dmg_bar.max_value = max_hp
	hp_bar.value = current_hp
	dmg_bar.value = current_hp

func _physics_process(delta):
	if is_dead:
		return

	velocity.y += gravity * delta
	adjust_hitbox_transform()

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

	move_and_slide()

func _process(delta):
	if is_dead:
		return

	if dmg_bar.value > hp_bar.value:
		dmg_bar.value -= 30 * delta
		dmg_bar.value = max(dmg_bar.value, hp_bar.value)

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
		walk_sfx.pitch_scale = randf_range(0.7, 1.0)
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

# ==================== EFEK HIT ====================

func apply_damage(amount: int):
	if is_dead:
		return

	current_hp = clamp(current_hp - amount, 0, max_hp)
	hp_bar.value = current_hp
	hp_timer.start(0.5)
	$EnemyHP.visible = true

	flash_white()

	if $Hit_SFX:
		$Hit_SFX.pitch_scale = randf_range(0.8, 0.9) # ✅ Variasi pitch biar tidak membosankan
		$Hit_SFX.play()

	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("start_shake"):
		camera.start_shake(1.5)

	if current_hp <= 0:
		die()

func flash_white():
	animated_sprite.self_modulate = Color(10, 10, 10)
	var tween := create_tween()
	tween.tween_property(animated_sprite, "self_modulate", Color(1, 1, 1), 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

# ==================== KEMATIAN ====================

func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	player_chase = false
	is_attacking = false
	player_in_hitbox = false

	if walk_sfx.playing:
		walk_sfx.stop()

	if $Death_SFX:
		$Death_SFX.play()

	detection_area.set_deferred("monitoring", false)
	detection_area.set_deferred("monitorable", false)
	hitbox_area.set_deferred("monitoring", false)
	hitbox_area.set_deferred("monitorable", false)
	collision_shape.set_deferred("disabled", true)

	animated_sprite.play("Death")
	$EnemyHP.visible = false

	attack_timer.stop()
	hp_timer.stop()

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "Death":
		await get_tree().create_timer(0.5).timeout

		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.5) \
			 .set_trans(Tween.TRANS_SINE) \
			 .set_ease(Tween.EASE_OUT)

		await tween.finished
		queue_free()

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
