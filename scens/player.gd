extends CharacterBody2D

@export var walk_speed: float = 120.0
@export var run_speed: float = 176.0

@onready var sprite: Sprite2D = $Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var swipe_trail: CPUParticles2D = $SwipeTrail

@export var max_health: int = 100
var health: int

@export var attack_range: float = 40.0
@export var attack_damage: int = 10

# State variables
var is_running: bool = false
var is_attacking: bool = false

var is_dragging: bool = false
var is_blocking: bool = false
var drag_start: Vector2 = Vector2.ZERO
@export var min_drag_distance: float = 30.0

var is_taking_hit: bool = false
var is_dead: bool = false
var knockback: Vector2 = Vector2.ZERO
var last_block_press_time: float = -1.0

func apply_knockback(force: Vector2) -> void:
	knockback = force
	
func take_damage(amount: int) -> void:
	if is_dead: return
	
	# Reset states so player doesn't get permanently stuck if an animation is interrupted!
	is_attacking = false
	is_dragging = false
	swipe_trail.emitting = false
	
	health -= amount
	print("Player took %d damage! Health: %d" % [amount, health])
	if health <= 0:
		is_dead = true
		print("Player died!")
		anim_player.play("death")
	else:
		is_taking_hit = true
		anim_player.play("take_hit")

func _ready() -> void:
	add_to_group("player")
	health = max_health
	
	# Dynamically create take_hit animation
	var anim_hit = Animation.new()
	anim_hit.length = 0.3
	var track_idx = anim_hit.add_track(Animation.TYPE_VALUE)
	anim_hit.track_set_path(track_idx, "Sprite:texture")
	anim_hit.track_insert_key(track_idx, 0.0, preload("res://sprites/player_hit.png"))
	track_idx = anim_hit.add_track(Animation.TYPE_VALUE)
	anim_hit.track_set_path(track_idx, "Sprite:hframes")
	anim_hit.track_insert_key(track_idx, 0.0, 1)
	track_idx = anim_hit.add_track(Animation.TYPE_VALUE)
	anim_hit.track_set_path(track_idx, "Sprite:frame")
	anim_hit.track_insert_key(track_idx, 0.0, 0)
	anim_player.get_animation_library("").add_animation("take_hit", anim_hit)
	
	# Dynamically create death animation
	var anim_death = Animation.new()
	anim_death.length = 1.0
	track_idx = anim_death.add_track(Animation.TYPE_VALUE)
	anim_death.track_set_path(track_idx, "Sprite:texture")
	anim_death.track_insert_key(track_idx, 0.0, preload("res://sprites/player_death.png"))
	track_idx = anim_death.add_track(Animation.TYPE_VALUE)
	anim_death.track_set_path(track_idx, "Sprite:hframes")
	anim_death.track_insert_key(track_idx, 0.0, 10)
	track_idx = anim_death.add_track(Animation.TYPE_VALUE)
	anim_death.track_set_path(track_idx, "Sprite:frame")
	for i in range(10):
		anim_death.track_insert_key(track_idx, i * 0.1, i)
	anim_player.get_animation_library("").add_animation("death", anim_death)
	
	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play("idle")

func _process(_delta: float) -> void:
	if is_dragging:
		swipe_trail.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if is_dead or is_taking_hit: return
	
	if event.is_action_pressed("toggle_run"):
		is_running = !is_running
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_blocking = true
				last_block_press_time = Time.get_ticks_msec() / 1000.0
			else:
				is_blocking = false
				
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start = get_global_mouse_position()
				swipe_trail.global_position = drag_start
				swipe_trail.emitting = true
			elif is_dragging:
				is_dragging = false
				swipe_trail.emitting = false
				var drag_end = get_global_mouse_position()
				var drag_vector = drag_end - drag_start
				
				if drag_vector.length() >= min_drag_distance and not is_attacking:
					is_attacking = true
					
					# Make player face the side where the attack was drawn
					var drag_center = (drag_start + drag_end) / 2.0
					sprite.flip_h = drag_center.x < global_position.x
					
					# Determine horizontal or vertical slash
					if abs(drag_vector.x) > abs(drag_vector.y):
						anim_player.play("attack_h")
					else:
						anim_player.play("attack_v")
						
					var enemies = get_tree().get_nodes_in_group("enemies")
					var closest_enemy = null
					var min_dist = 40.0 # Maximum hit radius
					
					for enemy in enemies:
						var enemy_pos = enemy.global_position + Vector2(0, -30) # Account for sprite offset
						
						# Find exactly how close this enemy is to the swipe line
						var point_on_segment = Geometry2D.get_closest_point_to_segment(enemy_pos, drag_start, drag_end)
						var dist = enemy_pos.distance_to(point_on_segment)
						
						# Keep track of the absolute closest enemy
						if dist < min_dist:
							min_dist = dist
							closest_enemy = enemy
							
					# ONLY apply damage to the single closest enemy!
					if closest_enemy != null:
						var hit_success = closest_enemy.take_damage(attack_damage, drag_vector)
						if hit_success:
							if closest_enemy.has_method("apply_knockback"):
								var kb_dir = (closest_enemy.global_position - global_position).normalized()
								closest_enemy.apply_knockback(kb_dir * 350.0)
						else:
							# Player is knocked back because attack was blocked
							var kb_dir = (global_position - closest_enemy.global_position).normalized()
							apply_knockback(kb_dir * 250.0)

func _physics_process(delta: float) -> void:
	if is_dead: return
	
	if is_taking_hit:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, 10.0 * delta)
		move_and_slide()
		return
		
	if is_attacking:
		velocity = knockback
		knockback = knockback.lerp(Vector2.ZERO, 10.0 * delta)
		move_and_slide()
		return

	# Handle movement speed based on run toggle
	var speed = run_speed if is_running else walk_speed

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Isometric perspective trick: Squash vertical movement speed by half
	# This makes moving up/down visually match the 2:1 ratio of the isometric tiles!
	velocity = direction * speed
	velocity.y *= 0.5
	
	# Add knockback
	velocity += knockback
	knockback = knockback.lerp(Vector2.ZERO, 10.0 * delta)
	
	move_and_slide()

	# Flip sprite depending on horizontal movement input
	if direction.x < 0:
		sprite.flip_h = true
	elif direction.x > 0:
		sprite.flip_h = false

	# Play appropriate animation
	if direction != Vector2.ZERO:
		if is_running:
			anim_player.play("run")
		else:
			anim_player.play("walk")
	else:
		anim_player.play("idle")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack_h" or anim_name == "attack_v":
		is_attacking = false
	elif anim_name == "take_hit":
		is_taking_hit = false
