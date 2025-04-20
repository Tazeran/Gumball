extends CharacterBody3D

signal coin_collected

@export_subgroup("Components")
@export var view: Node3D

@export_subgroup("Properties")
@export var player_id := 1
@export var movement_speed := 250
@export var jump_strength := 7

var movement_velocity: Vector3
var rotation_direction: float
var gravity := 0.0

var previously_floored := false
var jump_single := true
var jump_double := true
var coins := 0

@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer

# Called every physics frame
func _physics_process(delta):
	handle_controls(delta)
	handle_gravity(delta)
	handle_effects(delta)

	# Movement
	var applied_velocity: Vector3 = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	velocity = applied_velocity
	move_and_slide()
	
	# Check collisions and push RigidBody3Ds (e.g., marbles)
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var body = collision.get_collider()

		if body is RigidBody3D:
			var push_force = velocity.normalized() * 3.0  # Tune the multiplier
			body.apply_impulse(Vector3.ZERO, push_force)


	# Rotation
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()

	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)

	# Respawn if fallen
	if position.y < -10:
		get_tree().reload_current_scene()

	# Animation scaling on landing
	model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)

	if is_on_floor() and gravity > 2 and !previously_floored:
		model.scale = Vector3(1.25, 0.75, 1.25)
		Audio.play("res://sounds/land.ogg")

	previously_floored = is_on_floor()

# Handle walking animation and effects
func handle_effects(delta):
	particles_trail.emitting = false
	sound_footsteps.stream_paused = true

	if is_on_floor():
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		var speed_factor = horizontal_velocity.length() / movement_speed / delta

		if speed_factor > 0.05:
			if animation.current_animation != "walk":
				animation.play("walk", 0.1)

			if speed_factor > 0.3:
				sound_footsteps.stream_paused = false
				sound_footsteps.pitch_scale = speed_factor

			if speed_factor > 0.75:
				particles_trail.emitting = true
		elif animation.current_animation != "idle":
			animation.play("idle", 0.1)
	elif animation.current_animation != "jump":
		animation.play("jump", 0.1)

# Handle input for movement and jumping
func handle_controls(delta):
	var input := Vector3.ZERO

	var left = "move_left_p" + str(player_id)
	var right = "move_right_p" + str(player_id)
	var forward = "move_forward_p" + str(player_id)
	var back = "move_back_p" + str(player_id)
	var jump = "jump_p" + str(player_id)

	input.x = Input.get_action_strength(right) - Input.get_action_strength(left)
	input.z = Input.get_action_strength(back) - Input.get_action_strength(forward)

	input = input.rotated(Vector3.UP, view.rotation.y)

	if input.length() > 1:
		input = input.normalized()

	movement_velocity = input * movement_speed * delta

	if Input.is_action_just_pressed(jump):
		if jump_single or jump_double:
			jump_action()

# Gravity and jumping logic
func handle_gravity(delta):
	gravity += 25 * delta

	if gravity > 0 and is_on_floor():
		jump_single = true
		gravity = 0

func jump_action():
	Audio.play("res://sounds/jump.ogg")

	gravity = -jump_strength
	model.scale = Vector3(0.5, 1.5, 0.5)

	if jump_single:
		jump_single = false
		jump_double = true
	else:
		jump_double = false

# Coin collection
func collect_coin():
	coins += 1
	coin_collected.emit(coins)
