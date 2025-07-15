extends CharacterBody2D

@export var default_facing_left := false
@export var stun_duration := 0.3

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
var is_stunned := false
var knockback_velocity := Vector2.ZERO
var knockback_decay := 0.85

@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_area = $HitBoxArea
@onready var hitbox = $HitBox
@onready var attack_timer = $Timer
@onready var raycast = $RayCast2D
@onready var walk_sfx = $Walk_SFX
@onready var attack_sfx = $Attack_SFX
@onready var hp_bar = $EnemyHP/HealthBar
@onready var dmg_bar = $EnemyHP/DamageBar
@onready var hp_timer = $EnemyHP/Timer
@onready var detection_area = $DetectionArea
@onready var collision_shape = $CollisionShape2D

var original_hitbox_area_transform: Transform2D
var original_hitbox_transform: Transform2D

func _ready() -> void:
	add_to_group("enemies")
	$EnemyHP.visible = false

	speed += randf_range(-10, 10)

	attack_timer.wait_time = 1.0
	attack_timer.one_shot = true

	original_hitbox_area_transform = hitbox_area.transform
	original_hitbox_transform = hitbox.transform

	walk_sfx.pitch_scale = randf_range(0.7, 1.0)

	animated_sprite.flip_h = default_facing_left
	adjust_hitbox_area_transform()
	adjust_hitbox_transform()

	hp_bar.max_value = max_hp
	dmg_bar.max_value = max_hp
	hp_bar.value = current_hp
	dmg_bar.value = current_hp

func _physics_process(delta):
	if is_dead:
		return

	if knockback_velocity != Vector2.ZERO:
		velocity = knockback_velocity
		knockback_velocity *= knockback_decay
		move_and_slide()
		if knockback_velocity.length() < 5:
			knockback_velocity = Vector2.ZERO
		return

	velocity.y += gravity * delta
	adjust_hitbox_area_transform()
	adjust_hitbox_transform()

	if is_stunned:
		move_and_slide()
		return

	if is_attacking and animated_sprite.animation == "Attack":
		var frame = animated_sprite.frame
		if frame == 4 or frame == 8:
			if not attack_sfx.playing:
				attack_sfx.pitch_scale = randf_range(2.9, 3.2)
				attack_sfx.play()
	else:
		hitbox.monitoring = false
		hitbox.get_node("CollisionShape2D").disabled = true

	if is_attacking:
		var frame = animated_sprite.frame
		var shape = hitbox.get_node("CollisionShape2D")
		if frame == 4 or frame == 8:
			if shape.disabled:
				hitbox.monitoring = true
				shape.disabled = false
		else:
			if not shape.disabled:
				hitbox.monitoring = false
				shape.disabled = true
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

func adjust_hitbox_area_transform():
	if animated_sprite.flip_h:
		hitbox_area.transform = Transform2D.FLIP_X * original_hitbox_area_transform
	else:
		hitbox_area.transform = original_hitbox_area_transform

func adjust_hitbox_transform():
	if animated_sprite.flip_h:
		hitbox.transform = Transform2D.FLIP_X * original_hitbox_transform
	else:
		hitbox.transform = original_hitbox_transform

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
	if animated_sprite.animation != "Idle" and !is_attacking and !is_stunned:
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

func apply_knockback(source_position: Vector2, force: float = 50):
	var dir = (global_position - source_position).normalized()
	knockback_velocity = dir * force

	is_stunned = true
	animated_sprite.play("Hit")

	await get_tree().create_timer(stun_duration).timeout
	is_stunned = false

	if is_dead:
		return
	if player_in_hitbox and player != null:
		start_attack()
	elif player_chase and player != null:
		animated_sprite.play("Run")
	else:
		animated_sprite.play("Idle")

func apply_damage(amount: int, source_position: Vector2):
	if is_dead:
		return

	current_hp = clamp(current_hp - amount, 0, max_hp)
	hp_bar.value = current_hp
	hp_timer.start(0.5)
	$EnemyHP.visible = true

	apply_knockback(source_position)

	if $Hit_SFX:
		$Hit_SFX.pitch_scale = randf_range(1, 2)
		$Hit_SFX.play()

	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("start_shake"):
		camera.start_shake(1.5)

	if current_hp <= 0:
		die()

func die():
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	player_chase = false
	is_attacking = false
	player_in_hitbox = false
	is_stunned = false

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
	elif animated_sprite.animation == "Hit" and not is_dead:
		animated_sprite.play("Idle")

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
		
func _on_hit_box_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hurtbox"):
		var player_node = area.get_parent()
		if player_node.has_method("apply_damage_to_player"):
			player_node.apply_damage_to_player(0.5)
