extends CharacterBody2D
class_name SkeletonEnemy

static var active_attackers: int = 0
const MAX_CONCURRENT_ATTACKS: int = 1

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
				# Calculate separation from other skeletons
				var separation = Vector2.ZERO
				var friends = get_tree().get_nodes_in_group("enemies")
				for friend in friends:
					if friend != self:
						var dist_to_friend = global_position.distance_to(friend.global_position)
						if dist_to_friend > 0.1 and dist_to_friend < 45.0:
							separation += (global_position - friend.global_position).normalized() * (45.0 - dist_to_friend)
				
				var direction = (player.global_position - global_position).normalized()
				
				# If close horizontally, strictly move vertically to align
				if dist_x <= attack_range:
					direction.x = 0
					direction.y = sign(player.global_position.y - global_position.y)
					direction = direction.normalized()
					
				# Apply separation force
				if separation != Vector2.ZERO:
					direction = (direction * 1.5 + separation.normalized()).normalized()
					
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
				if active_attackers < MAX_CONCURRENT_ATTACKS:
					initiate_attack()
		else:
			if anim_player.has_animation("walk") and anim_player.current_animation == "walk":
				anim_player.play("idle")

func _ready() -> void:
	# Randomize speed slightly so multiple skeletons don't perfectly sync
	move_speed += randf_range(-15.0, 15.0)
	
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
	active_attackers += 1
	is_attacking = true
	
	var dirs = ["top", "left", "right"]
	pending_attack_dir = dirs[randi() % dirs.size()]
	
	# The arrow instantly turns RED to indicate the defense window
	arrow_top.texture = arrow_tex_attack if pending_attack_dir == "top" else arrow_tex_normal
	arrow_left.texture = arrow_tex_attack if pending_attack_dir == "left" else arrow_tex_normal
	arrow_right.texture = arrow_tex_attack if pending_attack_dir == "right" else arrow_tex_normal
	
	arrow_top.visible = (pending_attack_dir == "top")
	arrow_left.visible = (pending_attack_dir == "left")
	arrow_right.visible = (pending_attack_dir == "right")
	
	# Play the attack animation and pause it at the raised sword (frame 3 / 0.3s)
	anim_player.speed_scale = 1.0
	anim_player.play("attack")
	anim_player.seek(0.3, true)
	anim_player.pause()
	
	# The defense window lasts for 0.8 seconds
	get_tree().create_timer(0.8).timeout.connect(_on_defense_window_ended)

func _on_defense_window_ended() -> void:
	if health <= 0 or is_stunned:
		_end_attack(1.0)
		return
		
	# The red arrow changes back (hides) to indicate the window is closed
	arrow_top.hide()
	arrow_left.hide()
	arrow_right.hide()
	
	# The skeleton continues the attack animation!
	anim_player.play()
	
	# Sword physically strikes down 0.1s after resuming from frame 3
	get_tree().create_timer(0.1).timeout.connect(_execute_attack)

func _end_attack(cooldown: float = 1.0) -> void:
	if is_attacking:
		is_attacking = false
		active_attackers -= 1
		attack_cooldown = cooldown
		update_arrows()

func _execute_attack() -> void:
	if health <= 0 or is_stunned:
		_end_attack(1.0)
		return
		
	var players = get_tree().get_nodes_in_group("player")
	if players.size() == 0: return
	var player = players[0]
	
	var time_since_block = (Time.get_ticks_msec() / 1000.0) - player.last_block_press_time
	
	# If the player is currently blocking, OR they pressed block anytime during the 0.8s red arrow window
	if player.is_blocking or time_since_block <= 1.0:
		print("PERFECT PARRY!")
		var kb_dir = (global_position - player.global_position).normalized()
		apply_knockback(kb_dir * 450.0) # Massive knockback to skeleton
		
		var p = CPUParticles2D.new()
		p.amount = 25
		p.lifetime = 0.4
		p.explosiveness = 0.95
		p.spread = 180
		p.initial_velocity_min = 150
		p.initial_velocity_max = 280
		p.scale_amount_min = 2.5
		p.scale_amount_max = 6.0
		p.color = Color(0.1, 0.9, 1.0) # Cyan parry spark
		get_parent().add_child(p)
		p.global_position = global_position + (player.global_position - global_position)/2
		get_tree().create_timer(0.4).timeout.connect(p.queue_free)
		
		_end_attack(1.5)
	else:
		# Player takes the hit directly!
		if player.has_method("apply_knockback"):
			var kb_dir = (player.global_position - global_position).normalized()
			player.apply_knockback(kb_dir * 350.0) # Increased player knockback on hit!
		
		if player.has_method("take_damage"):
			player.take_damage(10)
		
		_end_attack(2.0)

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
	
	# Always reset animation speed when hit to cancel slow-mo windup
	anim_player.speed_scale = 1.0
	_end_attack(1.0)
	
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
	anim_player.speed_scale = 1.0
	_end_attack(0.0)
	arrow_top.hide()
	arrow_left.hide()
	arrow_right.hide()
	anim_player.play("death")

func _on_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "take_hit" or anim_name == "block" or anim_name == "attack") and health > 0:
		anim_player.play("idle")
	elif anim_name == "death":
		var parent = get_parent()
		if parent:
			var scene = load("res://scens/skeleton_enemy.tscn")
			var spawn_timer = Timer.new()
			spawn_timer.wait_time = 5.0
			spawn_timer.one_shot = true
			spawn_timer.autostart = true
			parent.add_child(spawn_timer)
			spawn_timer.timeout.connect(func():
				if is_instance_valid(parent):
					var skeleton = scene.instantiate()
					skeleton.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
					parent.add_child(skeleton)
				spawn_timer.queue_free()
			)
		queue_free()
