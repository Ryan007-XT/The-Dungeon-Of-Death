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

func _ready() -> void:
	attack_timer.wait_time = 1.0
	attack_timer.one_shot = true

func _physics_process(delta):
	velocity.y += gravity * delta
	
	# Flip hitbox berdasarkan arah sprite
	if animated_sprite.flip_h:
		hitbox_area.scale.x = -abs(hitbox_area.scale.x)
	else:
		hitbox_area.scale.x = abs(hitbox_area.scale.x)
	
	# Logika utama dengan prioritas menyelesaikan serangan
	if is_attacking:
		# Biarkan serangan berjalan sampai selesai
		pass
	elif player_in_hitbox and player != null:
		# Player dalam hitbox - mulai serangan
		start_attack()
	elif player_chase and player != null:
		# Mengejar player
		chase_player()
	else:
		# Idle state
		idle_state()
	
	move_and_slide()

func start_attack():
	is_attacking = true
	velocity.x = 0
	animated_sprite.play("Attack")
	attack_cooldown = true
	attack_timer.start()
	print("Attack started!")

func chase_player():
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * speed
	
	if animated_sprite.animation != "Run":
		animated_sprite.play("Run")
	
	# Flip sprite berdasarkan arah gerakan
	animated_sprite.flip_h = velocity.x < 0

func idle_state():
	velocity.x = 0
	if animated_sprite.animation != "Idle" and !is_attacking:
		animated_sprite.play("Idle")

# [DETECTION AREA HANDLERS]
func _on_detection_area_body_entered(body: Node2D) -> void:
	player = body
	player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	player = null
	player_chase = false

# [HITBOX AREA HANDLERS]
func _on_hitbox_area_body_entered(body: Node2D) -> void:
	if body == player:
		player_in_hitbox = true

func _on_hitbox_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_hitbox = false
		# HAPUS LOGIKA YANG MENGINTERUPSI SERANGAN
		# Serangan akan tetap berjalan sampai selesai

# [TIMER HANDLER]
func _on_timer_timeout() -> void:
	is_attacking = false
	attack_cooldown = false
	print("Attack finished!")
	
	# Jika player masih di hitbox, langsung serang lagi
	if player_in_hitbox and player != null:
		start_attack()
