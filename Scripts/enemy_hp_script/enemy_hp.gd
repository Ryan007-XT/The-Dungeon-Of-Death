extends Control

@onready var health_bar = $HealthBar
@onready var damage_bar = $DamageBar
@onready var timer = $Timer

var current_hp := 100
var max_hp := 100
var damage_delay := 0.5
var damage_speed := 60  # seberapa cepat damage bar menyusul

func _ready():
	health_bar.max_value = max_hp
	damage_bar.max_value = max_hp
	update_health(current_hp)

func update_health(new_hp: int):
	current_hp = clamp(new_hp, 0, max_hp)
	health_bar.value = current_hp
	timer.start(damage_delay)  # mulai jeda sebelum damage bar menyusul

func _on_timer_timeout() -> void:
	set_process(true)

func _process(delta):
	if damage_bar.value > health_bar.value:
		damage_bar.value -= damage_speed * delta
		damage_bar.value = max(damage_bar.value, health_bar.value)
	else:
		set_process(false)
