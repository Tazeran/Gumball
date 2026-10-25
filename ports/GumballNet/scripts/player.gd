extends CharacterBody3D
class_name Player
signal coin_collected(coins: int)

@export_subgroup("Components")
@export_subgroup("Properties")
@export var player_id := 1
@export var movement_speed := 250
@export var jump_strength := 7
@export var team: String

var hud: Node
var sub_viewport: SubViewportContainer
var view_camera: Node3D #assigned by game_master.gd
var marker: Node3D #assigned by game_master.gd

# --- Card Carry System
var carried_cards: Array[Node3D] = []
var nearby_card: Node3D = null  # Closest interactable card
var card_hold_offset: Vector3 = Vector3(0, 1.0, 0)
var interaction_radius: float = 2.0

@onready var pickup_area = $PickupArea
var nearby_interactables: Array[Node3D] = []
var hold_target: Node = null
var hold_timer: float = 0.0

@onready var mesh_parts: Array[MeshInstance3D] = get_meshes_in_children($Character/character/root)
#@onready var shared_mat: StandardMaterial3D = $Character/character/root/torso.mesh.surface_get_material(0) as StandardMaterial3D

# Cached input action names
var input_left: String
var input_right: String
var input_forward: String
var input_back: String
var input_jump: String
var input_ground_pound: String
var input_interact: String
var input_crouch: String
var accepts_local_input := true
var local_controller_device := -1
var input_profile_id := 1


var movement_velocity: Vector3
var rotation_direction: float
var gravity := 0.0
var previously_floored := false
var jump_single := true
var jump_double := true

var _coins := 100
var coins:
	get: return _coins
	set(value):
		_coins = value
		if hud:
			hud.update_coins(_coins)

var spawn_position: Vector3

var is_crouching = false
var double_jump_stamina_cost = 4
var ground_pound_stamina_cost = 8
var crouch_jump_strength = 12  # More powerful than normal jump
var crouch_jump_stamina_cost = 30
var stamina_max :float = 64
var stamina :float = 64
var stamina_regen_rate :float = 3  # Stamina per second

var health: int = 5
var health_max: int = 8

# Ground Pound variables
var is_ground_pounding = false
var ground_pound_started = false
var ground_pound_gravity_multiplier = 4.0
@export var ground_pound_impact_radius := 2.25
@export var ground_pound_min_impact_speed := 10.0
var ground_pound_impact_speed := 0.0

@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer

func is_holding_card():
	return carried_cards.size() > 0

func _ready():
	#update_interaction_marker()
	# Online clients only read input for their assigned player. The command-line
	# controller device selects which existing per-device input map that player uses.
	input_profile_id = player_id
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session:
		var local_slots: Array = Array(network_session.get("LocalPlayerSlots"))
		var dedicated := bool(network_session.get("IsDedicatedServer"))
		if dedicated:
			accepts_local_input = false
		elif not local_slots.is_empty():
			var local_index := local_slots.find(player_id)
			accepts_local_input = local_index >= 0
			if accepts_local_input:
				var controller_devices: Array = Array(network_session.get("LocalControllerDevices"))
				local_controller_device = int(controller_devices[local_index])
				input_profile_id = local_controller_device + 1

	input_left = "move_left_p" + str(input_profile_id)
	input_right = "move_right_p" + str(input_profile_id)
	input_forward = "move_forward_p" + str(input_profile_id)
	input_back = "move_back_p" + str(input_profile_id)
	input_jump = "jump_p" + str(input_profile_id)
	input_ground_pound = "right_bumper_p" + str(input_profile_id)
	input_interact = "interact_p" + str(input_profile_id)
	input_crouch = "crouch_p" + str(input_profile_id)

	if not accepts_local_input:
		set_physics_process(false)

	var playerTexture = null
	if player_id % 2 == 1:
		playerTexture = load("res://models/Textures/colormapStarter.png")
	else:
		playerTexture = load("res://models/MarbleRun/Textures/colormap.png")

	print("player ", player_id, playerTexture)

	for mesh in mesh_parts:
		var material = mesh.material_override
		if material == null:
			material = StandardMaterial3D.new()
		else:
			material = material.duplicate() # Create a unique copy
		mesh.material_override = material
		material.albedo_texture = playerTexture

	spawn_position = global_transform.origin
	pickup_area.area_entered.connect(_on_pickup_area_body_entered)
	pickup_area.area_exited.connect(_on_pickup_area_body_exited)

func setup(): #called by master
	if hud:
		hud.update_coins(coins)
		hud.set_health(health, health_max)

func _on_pickup_area_body_entered(area):
	#print("_on_pickup_area_body_entered", area)
	if area.is_in_group("interactables"):
		nearby_interactables.append(area)
	elif area.get_parent().is_in_group("interactables"):
		nearby_interactables.append(area.get_parent())
	#update_interaction_marker()

func _on_pickup_area_body_exited(area):
	#print("_on_pickup_area_body_exited", area)
	if area.is_in_group("interactables"):
		nearby_interactables.erase(area)
	elif area.get_parent().is_in_group("interactables"):
		nearby_interactables.erase(area.get_parent())
	#update_interaction_marker()

#delete????
#func update_interaction_marker():
	#var closest = get_closest_interactable()
	#marker.visible = false
	#if closest:
		##var pos = get_marker_position();
		#if closest.interaction_available(self):
			#marker.global_transform.origin = closest.get_marker_position(self)
			##marker.global_transform.origin = closest.global_transform.origin
			#marker.visible = true

func handle_interactables(delta):
	var closest = get_closest_interactable()
	
	marker.visible = false
	
	if closest != null:
		if closest is HoldInteractable || closest is SolitairePathStack:
			hud.interact.visible = true
			hud.interact_prompt.text = closest.prompt_text
		if closest.interaction_available(self):
			marker.global_transform.origin = closest.get_marker_position(self)
			marker.visible = true
		#find out if it has a prompt and what type
		#display prompt
	else:
		hud.interact.visible = false
		#disable all prompt
	
	if hold_target != null:
		if Input.is_action_pressed(input_interact):
			hold_timer += delta
			if hold_timer >= hold_target.hold_time_required:
				hold_target.finish_hold(self)
				hold_timer = 0.0
				hold_target = null
				hud.set_aring_percent(0.0)
			else:
				hud.set_aring_percent(clamp(hold_timer / hold_target.hold_time_required, 0.0, 1.0))

		else:
			# Released early
			print("Released early")
			if hold_timer < 0.20: #fire a tap on interactible
				print("Released VERY early")
				try_tap_interact(closest)
				#hold_target.fire_tap(self)
			hold_timer = 0.0
			hold_target = null
			hud.set_aring_percent(0.0)

	elif carried_cards.size() == 0 and closest:
		if closest.has_method("finish_hold"):
			if Input.is_action_just_pressed(input_interact):
				if closest.interaction_available(self):
					hold_target = closest
					hold_timer = 0.0
			#if Input.is_action_pressed(input_interact):
				#closest.start_holding(player_id, self)
				#hold_target = closest
			#elif Input.is_action_just_released(input_interact):
				#closest.stop_holding(player_id)
				#hud.set_aring_percent(0)
				#hold_target = null
	
	if closest and Input.is_action_just_pressed(input_interact):
		if closest.has_method("finish_hold"):
			if carried_cards.size() > 0:
				try_tap_interact(closest)
		else:
			try_tap_interact(closest)

func try_tap_interact(closest):
	print(nearby_interactables)
	print(input_interact, " closest: ", closest, "  ", carried_cards)

	if carried_cards.size() == 0:
		# Not holding a card — try interacting normally
		print("carried_cards.size == 0: ", carried_cards)
		if closest and closest.has_method("interact"):
			closest.interact(self)
	else:
		print("Holding a card ")
		# Holding a card — try to drop onto something valid
		if closest:
			if closest.is_in_group("deck_stacks"):
				print("drop_card_onto_stack")
				drop_card_onto_stack(closest)
			elif closest.is_in_group("cards"):
				print("pass-drop")
				drop_card()
				pass  # Already holding a card — maybe deny
			elif closest.has_method("interact"):
				print("interact")
				closest.interact(self)
		else:
			print("drop_card ")
			# No valid target — drop to world
			drop_card()


#!!!! Could also have some kind of event for anything close to returns it's like HUD info, or more generic than that
#I want sort order by distance
#then work through closest to furthest
#then each interaction slot type get's filled in if its still open
func get_closest_interactable() -> Node3D:
	var closest = null
	var closest_dist = INF
	
	for interactable in nearby_interactables:
		if interactable and interactable.interaction_available(self):
			if carried_cards.size() > 0 and interactable == carried_cards[0]:
				continue
			var dist = global_position.distance_to(interactable.global_position)
			if dist < closest_dist:
				closest = interactable
				closest_dist = dist

	return closest


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
		respawn()

	# Animation scaling on landing
	model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)

	if is_on_floor() and gravity > 2 and !previously_floored:
		model.scale = Vector3(1.25, 0.75, 1.25)
		Audio.play("res://sounds/land.ogg")

	previously_floored = is_on_floor()
	handle_interactables(delta)


func handle_controls(delta):
	if not accepts_local_input:
		movement_velocity = Vector3.ZERO
		is_crouching = false
		return

	var input := Vector3.ZERO

	input.x = Input.get_action_strength(input_right) - Input.get_action_strength(input_left)
	input.z = Input.get_action_strength(input_back) - Input.get_action_strength(input_forward)
	input = input.rotated(Vector3.UP, view_camera.rotation.y)

	if input.length() > 1:
		input = input.normalized()

	movement_velocity = input * movement_speed * delta

	# Crouching
	is_crouching = Input.is_action_pressed(input_crouch)

	# Jumping
	if Input.is_action_just_pressed(input_jump):
		if jump_single or jump_double:
			jump_action()

	# Ground Pound
	if !is_on_floor() and !is_ground_pounding and Input.is_action_just_pressed(input_ground_pound):
		start_ground_pound()

func handle_gravity(delta):
	if is_ground_pounding:
		gravity += 25 * ground_pound_gravity_multiplier * delta
		ground_pound_impact_speed = maxf(ground_pound_impact_speed, gravity)
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
	if stamina >= ground_pound_stamina_cost:
		is_ground_pounding = true
		ground_pound_started = true
		gravity = 0
		ground_pound_impact_speed = 0.0
		stamina -= ground_pound_stamina_cost
		#animation.play("ground_pound_spin")  # if you want an animation
	else:
		# Not enough stamina to ground pound
		print("Not enough stamina to ground pound")

func land_ground_pound():
	var impact_speed := ground_pound_impact_speed
	is_ground_pounding = false
	ground_pound_started = false
	ground_pound_impact_speed = 0.0
	Audio.play("res://sounds/land.ogg")
	model.scale = Vector3(1.5, 0.5, 1.5)
	if impact_speed < ground_pound_min_impact_speed:
		return

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("receive_ground_pound"):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		var horizontal_distance := Vector2(offset.x, offset.z).length()
		# Only hit enemies at the landing level, never enemies above or on another floor.
		if horizontal_distance <= ground_pound_impact_radius and absf(offset.y) <= 1.6:
			enemy.receive_ground_pound(self, impact_speed)

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

func collect_stamina():
	stamina = clamp(stamina + 100, 0, stamina_max);

func collect_coin():
	coins += 1

func collect_heart():
	health = min(health + 2, health_max)
	if hud:
		hud.set_health(health, health_max)


#func find_nearby_card() -> Node3D:
	#var cards = get_tree().get_nodes_in_group("cards")  # We'll add "cards" group to cards
	#var closest_card = null
	#var closest_distance = interaction_radius
#
	#for card in cards:
		#if card and card.state == card.CardState.FREE_FLOATING and not card.locked:
			#var dist = global_position.distance_to(card.global_position)
			#if dist < closest_distance:
				#closest_distance = dist
				#closest_card = card
	#return closest_card


func pick_up_card(card: Node3D):
	if card.team != team:
		print("Cannot pick up card from another team.")
		return
	carried_cards.append(card)
	#card.pick_up(self)  # Calls the Card.gd function
	card.pick_up(self, $Character/character/root/torso/antenna) # Pass the Antenna as mount point
	#update_interaction_marker()
	#Audio.play("res://sounds/card-place-2.ogg")
	Audio.playRandom(Audio.CardPlaces)
	print("Picked up", card.rank, "of", card.suit)

func drop_card():
	if carried_cards.size() == 1:
		carried_cards[0].drop_to_ground()
		carried_cards.pop_front()
		#Audio.play("res://sounds/card-place-3.ogg")
		Audio.playRandom(Audio.CardPlaces)
		#update_interaction_marker()
	#elif carried_cards.size() > 1:
		#do not drop them? Or drop special multicards?

func drop_card_onto_stack(stack):
	if carried_cards.is_empty():
		return

	Audio.playRandom(Audio.CardShoves)

	for card in carried_cards:
		if card.source_deckstack != null:
			card.source_deckstack.unlock_stack()

		card.carrier_player = null
		card.carrier_target = null
		stack.add_card(card)

	carried_cards.clear()

func respawn():
	if health <= 0:
		health = 4
	global_transform.origin = spawn_position

var invincible = false
var invincibility_duration := 0.6
func take_damage(amount: int, source_pos: Vector3):
	print("tage_damage ", amount, source_pos)
	if invincible:
		return

	Audio.play("res://sounds/fall.ogg")

	health = max(0, health - amount)
	if health <= 0:
		respawn()
	if hud:
		hud.set_health(health, health_max)

	# Flash white and apply knockback
	flash_white()
	apply_knockback(source_pos)

	# Begin invincibility
	invincible = true
	await get_tree().create_timer(invincibility_duration).timeout
	invincible = false

func apply_knockback(source_pos: Vector3):
	var direction = (global_position - source_pos).normalized()
	direction.y = 0  # Flatten to horizontal
	velocity += direction * 20.0  # Knockback away from source
	velocity.y = 6.0  # Add upward launch directly



func get_meshes_in_children(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		if child is Node:
			result += get_meshes_in_children(child)
	return result

#maybe: turn into shader
func flash_white():
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color.from_rgba8(200, 200, 200, 200)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_texture = null
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	for mesh in mesh_parts:
		mesh.material_overlay = flash_mat
	await get_tree().create_timer(0.05).timeout
	for mesh in mesh_parts:
		mesh.material_overlay = null
	await get_tree().create_timer(0.05).timeout
	
	for mesh in mesh_parts:
		mesh.material_overlay = flash_mat
	await get_tree().create_timer(0.05).timeout
	for mesh in mesh_parts:
		mesh.material_overlay = null
	await get_tree().create_timer(0.05).timeout
	
	for mesh in mesh_parts:
		mesh.material_overlay = flash_mat
	await get_tree().create_timer(0.05).timeout
	for mesh in mesh_parts:
		mesh.material_overlay = null
	await get_tree().create_timer(0.05).timeout
