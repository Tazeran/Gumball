extends CharacterBody3D

signal coin_collected(coins: int)

@export_subgroup("Components")
@export var view: Node3D

@export_subgroup("Properties")
@export var player_id := 1
@export var movement_speed := 250
@export var jump_strength := 7
@export var hud: Node

var movement_velocity: Vector3
var rotation_direction: float
var gravity := 0.0
var previously_floored := false
var jump_single := true
var jump_double := true
var coins := 0
var spawn_position: Vector3

var is_crouching = false
var double_jump_stamina_cost = 4
var crouch_jump_strength = 12  # More powerful than normal jump
var crouch_jump_stamina_cost = 30
var stamina_max :float = 64
var stamina :float = 64;
var stamina_regen_rate :float = 3  # Stamina per second

# Ground Pound variables
var is_ground_pounding = false
var ground_pound_started = false
var ground_pound_gravity_multiplier = 4.0

@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer

func _ready():
	spawn_position = global_transform.origin
	if hud:
		connect("coin_collected", Callable(hud, "_on_coin_collected"))
	print("Player ", name, " has HUD: ", hud.name, " (ref: ", hud, ")")

func _physics_process(delta):
	handle_controls(delta)
	handle_gravity(delta)
	handle_effects(delta)
	
	# Regenerate stamina slowly
	stamina += stamina_regen_rate * delta
	stamina = clamp(stamina, 0, stamina_max)
	hud.set_stamina_percent(stamina / stamina_max)

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
			var push_force = velocity.normalized() * 3.0
			body.apply_impulse(Vector3.ZERO, push_force)

	# Rotation
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()
	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)

	# Respawn if fallen
	if position.y < -10:
		global_transform.origin = spawn_position

	# Animation scaling on landing
	model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)

	if is_on_floor() and gravity > 2 and !previously_floored:
		model.scale = Vector3(1.25, 0.75, 1.25)
		Audio.play("res://sounds/land.ogg")

	previously_floored = is_on_floor()

func handle_controls(delta):
	var input := Vector3.ZERO

	var left = "move_left_p" + str(player_id)
	var right = "move_right_p" + str(player_id)
	var forward = "move_forward_p" + str(player_id)
	var back = "move_back_p" + str(player_id)
	var jump = "jump_p" + str(player_id)
	var ground_pound = "right_bumper_p" + str(player_id)
	var crouch = "crouch_p" + str(player_id)  # You'll need to define this in Input Map!

	input.x = Input.get_action_strength(right) - Input.get_action_strength(left)
	input.z = Input.get_action_strength(back) - Input.get_action_strength(forward)
	input = input.rotated(Vector3.UP, view.rotation.y)

	if input.length() > 1:
		input = input.normalized()

	movement_velocity = input * movement_speed * delta

	# Crouching
	is_crouching = Input.is_action_pressed(crouch)

	# Jumping
	if Input.is_action_just_pressed(jump):
		if jump_single or jump_double:
			jump_action()

	# Ground Pound
	if !is_on_floor() and !is_ground_pounding and Input.is_action_just_pressed(ground_pound):
		start_ground_pound()


func handle_gravity(delta):
	if is_ground_pounding:
		gravity += 25 * ground_pound_gravity_multiplier * delta
	else:
		gravity += 25 * delta

	if gravity > 0 and is_on_floor():
		if is_ground_pounding:
			land_ground_pound()
		jump_single = true
		gravity = 0

func jump_action():
	Audio.play("res://sounds/jump.ogg")

	if is_crouching and stamina >= crouch_jump_stamina_cost:
		# Do a crouch super jump
		stamina -= crouch_jump_stamina_cost
		gravity = -crouch_jump_strength
		model.scale = Vector3(0.4, 1.6, 0.4)  # Bigger squash/stretch
	else:
		# Normal jump
		gravity = -jump_strength
		model.scale = Vector3(0.5, 1.5, 0.5)

	if jump_single:
		jump_single = false
		jump_double = true
	else:
		# Player is using the double jump
		if stamina >= double_jump_stamina_cost:
			stamina -= double_jump_stamina_cost
			jump_double = false  # Consumes the double jump
		else:
			# Not enough stamina, cancel the double jump
			return



func start_ground_pound():
	is_ground_pounding = true
	ground_pound_started = true
	gravity = 0
	#animation.play("ground_pound_spin")  # Make sure you have this animation!

func land_ground_pound():
	is_ground_pounding = false
	Audio.play("res://sounds/land.ogg")
	model.scale = Vector3(1.5, 0.5, 1.5)

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
	elif animation.current_animation != "jump" and !is_ground_pounding:
		animation.play("jump", 0.1)

func collect_coin():
	coins += 1
	coin_collected.emit(coins)
