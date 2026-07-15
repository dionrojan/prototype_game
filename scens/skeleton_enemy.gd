extends CharacterBody2D

@export var max_health: int = 30
var health: int

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite
@onready var arrow_top: Sprite2D = $ArrowTop
@onready var arrow_left: Sprite2D = $ArrowLeft
@onready var arrow_right: Sprite2D = $ArrowRight
@onready var block_timer: Timer = $BlockTimer

var vulnerable_dir: String = "none" # "none", "top", "left", "right"
var arrow_tex_normal = preload("res://sprites/arrow.png")
var arrow_tex_active = preload("res://sprites/activearrow_2.png")
var arrow_tex_attack = preload("res://sprites/attackarrow.png")

var knockback: Vector2 = Vector2.ZERO
var is_stunned: bool = false
var is_attacking: bool = false
var attack_cooldown: float = 0.0
var pending_attack_dir: String = ""

func apply_knockback(force: Vector2) -> void:
	knockback = force

@export var move_speed: float = 60.0
@export var detection_range: float = 200.0
@export var attack_range: float = 40.0

func _physics_process(delta: float) -> void:
	if knockback.length() > 5.0:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, 15.0 * delta)
		move_and_slide()
		return
		
	if is_stunned:
		return
		
	if attack_cooldown > 0:
		attack_cooldown -= delta
		
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.global_position.x < global_position.x:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
			
		var dist_x = abs(global_position.x - player.global_position.x)
		var dist_y = abs(global_position.y - player.global_position.y)
		var total_dist = global_position.distance_to(player.global_position)
		
		if total_dist <= detection_range and (dist_x > attack_range or dist_y > 15.0):
			if not is_attacking:
				var direction = (player.global_position - global_position).normalized()
				
				# If close horizontally, strictly move vertically to align
				if dist_x <= attack_range:
					direction.x = 0
					direction.y = sign(player.global_position.y - global_position.y)
					direction = direction.normalized()
					
				velocity = direction * move_speed
				velocity.y *= 0.5
				move_and_slide()
				
				if anim_player.has_animation("walk") and anim_player.current_animation != "walk":
					if anim_player.current_animation == "idle":
						anim_player.play("walk")
		elif dist_x <= attack_range and dist_y <= 15.0:
			if anim_player.has_animation("walk") and anim_player.current_animation == "walk":
				anim_player.play("idle")
				
			if not is_attacking and health > 0 and attack_cooldown <= 0:
				initiate_attack()
		else:
			if anim_player.has_animation("walk") and anim_player.current_animation == "walk":
				anim_player.play("idle")

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	
	# Create attack animation dynamically
	var anim = Animation.new()
	anim.length = 0.8
	var track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "Sprite:texture")
	anim.track_insert_key(track_idx, 0.0, preload("res://sprites/skeleton_attack.png"))
	track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "Sprite:hframes")
	anim.track_insert_key(track_idx, 0.0, 8)
	track_idx = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "Sprite:frame")
	for i in range(8):
		anim.track_insert_key(track_idx, i * 0.1, i)
	anim_player.get_animation_library("").add_animation("attack", anim)
	
	anim_player.animation_finished.connect(_on_animation_finished)
	block_timer.timeout.connect(_on_block_timeout)
	anim_player.play("idle")
	start_block_cycle()

func initiate_attack() -> void:
	is_attacking = true
	anim_player.play("idle")
	
	var dirs = ["top", "left", "right"]
	pending_attack_dir = dirs[randi() % dirs.size()]
	
	arrow_top.texture = arrow_tex_attack if pending_attack_dir == "top" else arrow_tex_normal
	arrow_left.texture = arrow_tex_attack if pending_attack_dir == "left" else arrow_tex_normal
	arrow_right.texture = arrow_tex_attack if pending_attack_dir == "right" else arrow_tex_normal
	
	arrow_top.visible = (pending_attack_dir == "top")
	arrow_left.visible = (pending_attack_dir == "left")
	arrow_right.visible = (pending_attack_dir == "right")
	
	get_tree().create_timer(1.0).timeout.connect(_execute_attack)

func _execute_attack() -> void:
	if health <= 0 or is_stunned:
		is_attacking = false
		attack_cooldown = 1.0
		update_arrows()
		return
		
	anim_player.play("attack")
	
	# Wait 0.4s for the sword to actually swing down
	await get_tree().create_timer(0.4).timeout
	
	if health <= 0 or is_stunned:
		is_attacking = false
		attack_cooldown = 1.0
		update_arrows()
		return
		
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0: return
	var player = players[0]
	
	if player.is_blocking:
		print("Player BLOCKED the skeleton's attack!")
		var kb_dir = (global_position - player.global_position).normalized()
		apply_knockback(kb_dir * 350.0)
		
		var p = CPUParticles2D.new()
		p.amount = 20
		p.lifetime = 0.4
		p.explosiveness = 0.9
		p.spread = 180
		p.initial_velocity_min = 120
		p.initial_velocity_max = 220
		p.scale_amount_min = 2.0
		p.scale_amount_max = 5.0
		p.color = Color(0.2, 0.8, 1.0) # Cyan/Blue parry spark
		get_parent().add_child(p)
		p.global_position = global_position + (player.global_position - global_position)/2
		get_tree().create_timer(0.4).timeout.connect(p.queue_free)
		
		is_attacking = false
		attack_cooldown = 1.5
		update_arrows()
	else:
		if player.has_method("take_damage"):
			player.take_damage(10)
		is_attacking = false
		attack_cooldown = 2.0
		update_arrows()

var last_attack_dir: String = ""

func start_block_cycle() -> void:
	if health <= 0: return
	var dirs = ["top", "left", "right"]
	
	if last_attack_dir != "":
		for dir in ["top", "left", "right"]:
			if dir != last_attack_dir:
				dirs.append(dir)
				dirs.append(dir)
				dirs.append(dir)
		
	vulnerable_dir = dirs[randi() % dirs.size()]
	update_arrows()
	block_timer.start(2.0)

func _on_block_timeout() -> void:
	if health <= 0: return
	vulnerable_dir = "none"
	update_arrows()
	get_tree().create_timer(0.5).timeout.connect(start_block_cycle)

func update_arrows() -> void:
	if is_attacking: return
	
	arrow_top.show()
	arrow_left.show()
	arrow_right.show()
	
	if vulnerable_dir == "none":
		arrow_top.texture = arrow_tex_normal
		arrow_left.texture = arrow_tex_normal
		arrow_right.texture = arrow_tex_normal
	else:
		arrow_top.texture = arrow_tex_normal if vulnerable_dir == "top" else arrow_tex_active
		arrow_left.texture = arrow_tex_normal if vulnerable_dir == "left" else arrow_tex_active
		arrow_right.texture = arrow_tex_normal if vulnerable_dir == "right" else arrow_tex_active

func take_damage(amount: int, drag_vector: Vector2 = Vector2.ZERO) -> bool:
	if health <= 0: return false # Already dead
	
	var blocked = false
	var current_attack_dir = ""
	if drag_vector != Vector2.ZERO:
		if abs(drag_vector.x) > abs(drag_vector.y): # Horizontal slash
			current_attack_dir = "left" if drag_vector.x > 0 else "right"
		else: # Vertical slash
			current_attack_dir = "top"
			
		last_attack_dir = current_attack_dir
			
		if vulnerable_dir != "none" and current_attack_dir != vulnerable_dir:
			blocked = true
				
	if blocked:
		print("Skeleton BLOCKED the attack from " + current_attack_dir + "!")
		anim_player.play("block")
		return false
	
	health -= amount
	print("Skeleton took %d damage! Health remaining: %d" % [amount, health])
	spawn_hit_effect()
	
	is_stunned = true
	get_tree().create_timer(0.5).timeout.connect(func(): is_stunned = false)
	
	# Break guard if hit
	if vulnerable_dir != "none":
		block_timer.stop()
		vulnerable_dir = "none"
		update_arrows()
		get_tree().create_timer(0.5).timeout.connect(start_block_cycle)
	
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
	if (anim_name == "take_hit" or anim_name == "block" or anim_name == "attack") and health > 0:
		anim_player.play("idle")
	elif anim_name == "death":
		queue_free()
