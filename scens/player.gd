extends CharacterBody2D

@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0

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
var drag_start: Vector2 = Vector2.ZERO
@export var min_drag_distance: float = 30.0

var knockback: Vector2 = Vector2.ZERO

func apply_knockback(force: Vector2) -> void:
	knockback = force

func _ready() -> void:
	health = max_health
	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play("idle")

func _process(_delta: float) -> void:
	if is_dragging:
		swipe_trail.global_position = get_global_mouse_position()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_run"):
		is_running = !is_running
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start = get_global_mouse_position()
			swipe_trail.global_position = drag_start
			swipe_trail.emitting = true
		else:
			if is_dragging:
				is_dragging = false
				swipe_trail.emitting = false
				var drag_end = get_global_mouse_position()
				var drag_vector = drag_end - drag_start
				
				if drag_vector.length() >= min_drag_distance and not is_attacking:
					is_attacking = true
					
					# Determine horizontal or vertical slash
					if abs(drag_vector.x) > abs(drag_vector.y):
						anim_player.play("attack_h")
						sprite.flip_h = drag_vector.x < 0
					else:
						anim_player.play("attack_v")
						
					# Check enemies intersecting the drag line
					var enemies = get_tree().get_nodes_in_group("enemies")
					for enemy in enemies:
						var dist_to_player = global_position.distance_to(enemy.global_position)
						if dist_to_player <= attack_range:
							# Check if drag line passes through enemy
							var closest = Geometry2D.get_closest_point_to_segment(enemy.global_position, drag_start, drag_end)
							if closest.distance_to(enemy.global_position) < 30.0:
								if enemy.has_method("take_damage"):
									var hit_success = enemy.take_damage(attack_damage, drag_vector)
									if hit_success:
										if enemy.has_method("apply_knockback"):
											var kb_dir = (enemy.global_position - global_position).normalized()
											enemy.apply_knockback(kb_dir * 150.0)
									else:
										# Player is knocked back because attack was blocked
										var kb_dir = (global_position - enemy.global_position).normalized()
										apply_knockback(kb_dir * 250.0)

func _physics_process(delta: float) -> void:
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
