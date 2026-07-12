extends CharacterBody2D

@export var walk_speed: float = 120.0
@export var run_speed: float = 220.0

@onready var sprite: Sprite2D = $Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# State variables
var is_running: bool = false
var is_attacking: bool = false

func _ready() -> void:
	anim_player.animation_finished.connect(_on_animation_finished)
	anim_player.play("idle")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_run"):
		is_running = !is_running
	
	if event.is_action_pressed("attack") and not is_attacking:
		is_attacking = true
		anim_player.play("attack")

func _physics_process(_delta: float) -> void:
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Handle movement speed based on run toggle
	var speed = run_speed if is_running else walk_speed

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Isometric perspective trick: Squash vertical movement speed by half
	# This makes moving up/down visually match the 2:1 ratio of the isometric tiles!
	velocity = direction * speed
	velocity.y *= 0.5
	
	move_and_slide()

	# Flip sprite depending on horizontal movement
	if velocity.x < 0:
		sprite.flip_h = true
	elif velocity.x > 0:
		sprite.flip_h = false

	# Play appropriate animation
	if velocity != Vector2.ZERO:
		if is_running:
			anim_player.play("run")
		else:
			anim_player.play("walk")
	else:
		anim_player.play("idle")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		is_attacking = false
