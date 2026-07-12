extends CharacterBody2D

@export var max_health: int = 30
var health: int

@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play("idle")

func take_damage(amount: int) -> void:
	if health <= 0: return # Already dead
	
	health -= amount
	print("Skeleton took %d damage! Health remaining: %d" % [amount, health])
	
	spawn_hit_effect()
	
	if health <= 0:
		die()
	else:
		anim_player.play("take_hit")

func spawn_hit_effect() -> void:
	var p = CPUParticles2D.new()
	p.amount = 20
	p.lifetime = 0.25
	p.explosiveness = 0.9
	p.spread = 180
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80
	p.initial_velocity_max = 150
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(1, 0, 0) # Red
	get_parent().add_child(p)
	p.global_position = global_position
	get_tree().create_timer(0.3).timeout.connect(p.queue_free)

func die() -> void:
	print("Skeleton died!")
	anim_player.play("death")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "take_hit" and health > 0:
		anim_player.play("idle")
	elif anim_name == "death":
		queue_free()
