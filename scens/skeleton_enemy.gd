extends CharacterBody2D

@export var max_health: int = 30
var health: int

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var arrow_top: Sprite2D = $ArrowTop
@onready var arrow_left: Sprite2D = $ArrowLeft
@onready var arrow_right: Sprite2D = $ArrowRight
@onready var block_timer: Timer = $BlockTimer

var block_state: String = "none" # "none", "top", "left", "right"
var arrow_tex_normal = preload("res://sprites/arrow.png")
var arrow_tex_active = preload("res://sprites/arrowactive.png")

var knockback: Vector2 = Vector2.ZERO

func apply_knockback(force: Vector2) -> void:
	knockback = force

func _physics_process(delta: float) -> void:
	if knockback.length() > 5.0:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, 15.0 * delta)
		move_and_slide()

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	anim_player.animation_finished.connect(_on_animation_finished)
	block_timer.timeout.connect(_on_block_timeout)
	anim_player.play("idle")
	start_block_cycle()

func start_block_cycle() -> void:
	if health <= 0: return
	var dirs = ["top", "left", "right"]
	block_state = dirs[randi() % dirs.size()]
	update_arrows()
	block_timer.start(2.0)

func _on_block_timeout() -> void:
	if health <= 0: return
	block_state = "none"
	update_arrows()
	get_tree().create_timer(randf_range(1.0, 3.0)).timeout.connect(start_block_cycle)

func update_arrows() -> void:
	arrow_top.texture = arrow_tex_active if block_state == "top" else arrow_tex_normal
	arrow_left.texture = arrow_tex_active if block_state == "left" else arrow_tex_normal
	arrow_right.texture = arrow_tex_active if block_state == "right" else arrow_tex_normal

func take_damage(amount: int, drag_vector: Vector2 = Vector2.ZERO) -> bool:
	if health <= 0: return false # Already dead
	
	var blocked = false
	if block_state != "none" and drag_vector != Vector2.ZERO:
		if abs(drag_vector.x) > abs(drag_vector.y): # Horizontal slash
			if drag_vector.x > 0 and block_state == "left":
				blocked = true
			elif drag_vector.x < 0 and block_state == "right":
				blocked = true
		else: # Vertical slash
			if block_state == "top":
				blocked = true
				
	if blocked:
		print("Skeleton BLOCKED the attack from " + block_state + "!")
		anim_player.play("block")
		return false
	
	health -= amount
	print("Skeleton took %d damage! Health remaining: %d" % [amount, health])
	spawn_hit_effect()
	
	# Break guard if hit
	if block_state != "none":
		block_timer.stop()
		block_state = "none"
		update_arrows()
		get_tree().create_timer(randf_range(1.0, 3.0)).timeout.connect(start_block_cycle)
	
	if health <= 0:
		die()
	else:
		anim_player.play("take_hit")
		
	return true

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
	arrow_top.hide()
	arrow_left.hide()
	arrow_right.hide()
	anim_player.play("death")

func _on_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "take_hit" or anim_name == "block") and health > 0:
		anim_player.play("idle")
	elif anim_name == "death":
		queue_free()
