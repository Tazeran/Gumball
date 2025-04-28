extends Node3D

const front_material_index := 0
const back_material_index := 1
const edge_material_index := 2
const margin = 1.5

# Enum for card behavior state
enum CardState {
	FREE_FLOATING,
	CARRIED_BY_PLAYER,
	ON_STACK
}

signal player_entered_area(player)
signal player_exited_area(player)
# Nodes
@onready var mesh = $Cube

# Editable properties
@export var card_front_shader_material: ShaderMaterial
@export var edge_color : Color = Color.WHITE
@export var suit : String = "hearts"
@export var rank : String = "K"

var low_speed_timer = 0.0
var flattening = false
var has_flattened = false

# Runtime state
var state: CardState = CardState.FREE_FLOATING
var mount_target: Node3D = null
var mount_offset: Transform3D = Transform3D.IDENTITY
var carrier_player: Node3D = null
var locked: bool = false

var carrier_target: Node3D = null  # NEW


# Base paths
const TEXTURE_PATH = "res://models/cards/textures/"
const FRONT_TEXTURE_FORMAT = "%s_%s.png" # example: "card_hearts_A.png"
const BACK_TEXTURE_NAME = "card_back.png"


# Bobbing behavior (only when floating freely)
var bob_timer := 0.0
var bob_height := 0.2
var bob_speed := 1.0
var base_position: Vector3

func _ready():
	base_position = global_position
	add_to_group("cards")
	if mesh == null:
		push_error("CardMesh not found!")
	else:
		set_edge_color(edge_color)
		set_card(suit, rank)

var flatten_speed = 3.0  # How fast to rotate to flat

func start_flattening():
	flattening = true
	self.freeze = true
	self.linear_velocity = Vector3.ZERO
	self.angular_velocity = Vector3.ZERO
	self.gravity_scale = 0.0

func update_flattening(delta):
	# Slowly rotate the card back to zero tilt
	var target_rotation = Vector3(0, rotation.y, 0)  # Keep facing same Y
	rotation.x = lerp_angle(rotation.x, target_rotation.x, delta * flatten_speed)
	rotation.z = lerp_angle(rotation.z, target_rotation.z, delta * flatten_speed)

	# If very close to upright, snap it
	if abs(rotation.x) < deg_to_rad(1) and abs(rotation.z) < deg_to_rad(1):
		rotation.x = 0
		rotation.z = 0
		flattening = false
		has_flattened = true
		print("Card fully flattened!")

func _physics_process(delta):
	if global_transform.origin.y < -20:
		global_position = base_position
		self.linear_velocity = Vector3.ZERO
		self.angular_velocity = Vector3.ZERO

	match state:
		CardState.FREE_FLOATING:
			#_handle_free_float(delta)
			if !flattening and !has_flattened:
				# Check if card is nearly stopped
				print(self.linear_velocity.length(), "   ", self.angular_velocity.length())
				if self.linear_velocity.length() < 0.36 and self.angular_velocity.length() < 1.79:
					low_speed_timer += delta
					if low_speed_timer > 0.5:  # been slow for half a second
						print("Starting flattening!")
						start_flattening()
				else:
					low_speed_timer = 0.0

			if flattening:
				update_flattening(delta)
		
		CardState.CARRIED_BY_PLAYER:
			if carrier_target:
				var offset = Transform3D()

				var basis = Basis()
				basis = basis.rotated(Vector3(1, 0, 0), deg_to_rad(90))
				basis = basis.rotated(Vector3(0, 1, 0), deg_to_rad(180))
				offset.basis = basis

				offset.origin = Vector3(0, 0, 0)  # Adjust height above antenna tip

				global_transform = carrier_target.global_transform * offset
			elif carrier_player:
				var offset = Transform3D()
				var basis = Basis()
				#basis = basis.rotated(Vector3(1, 0, 0), deg_to_rad(90))
				#basis = basis.rotated(Vector3(0, 1, 0), deg_to_rad(180))
				offset.basis = basis
				#offset.origin = Vector3(0, 0.16, -0.37)
				offset.origin = Vector3(0, 1, 0.5)
				global_transform = carrier_player.global_transform * offset
		
		CardState.ON_STACK:
			if mount_target:
				global_transform = mount_target.global_transform * mount_offset

func _handle_free_float(delta):
	bob_timer += delta * bob_speed
	var offset_y = (sin(bob_timer) * 0.5 + 0.5) * bob_height
	#global_position = base_position + Vector3(0, offset_y, 0)

# -- Card Visual Setup
func set_card(new_suit: String, new_rank: String) -> void:
	suit = new_suit
	rank = new_rank

	var front_texture_path = TEXTURE_PATH + FRONT_TEXTURE_FORMAT % [ "card_" + suit, rank ]
	var back_texture_path = TEXTURE_PATH + BACK_TEXTURE_NAME

	var front_texture = load(front_texture_path)
	var back_texture = load(back_texture_path)

	if front_texture and back_texture:
		var front_material = card_front_shader_material.duplicate()
		front_material.set_shader_parameter("albedo_texture", front_texture)
		front_material.set_shader_parameter(
			"uv_offset",
			Vector2((11.0 + margin) / 64.0, (2.0 + margin) / 64.0)
		)
		front_material.set_shader_parameter(
			"uv_scale",
			Vector2((42.0 - (margin * 2)) / 64.0, (60.0 - (margin * 2)) / 64.0)
		)
		mesh.set_surface_override_material(front_material_index, front_material)

		var back_material = card_front_shader_material.duplicate()
		back_material.set_shader_parameter("albedo_texture", back_texture)
		back_material.set_shader_parameter(
			"uv_offset",
			Vector2((11.0 + margin) / 64.0, (2.0 + margin) / 64.0)
		)
		back_material.set_shader_parameter(
			"uv_scale",
			Vector2((42.0 - (margin * 2)) / 64.0, (60.0 - (margin * 2)) / 64.0)
		)
		mesh.set_surface_override_material(back_material_index, back_material)
	else:
		push_error("Card textures not found for %s %s" % [suit, rank])

func set_edge_color(color: Color) -> void:
	edge_color = color
	var edge_material = mesh.get_surface_override_material(edge_material_index)
	if edge_material == null:
		edge_material = mesh.mesh.surface_get_material(edge_material_index).duplicate()
		mesh.set_surface_override_material(edge_material_index, edge_material)
	if edge_material:
		edge_material.albedo_color = edge_color

# -- Attachments / Mounting Logic
#func pick_up(player: Node3D):
	#carrier_player = player
	#mount_target = null
	#state = CardState.CARRIED_BY_PLAYER
	#locked = false

func pick_up(player: Node3D, target_mount: Node3D = null):
	print("card/pick_up: ", target_mount)
	carrier_player = player
	mount_target = null
	has_flattened = false
	carrier_target = target_mount if target_mount != null else player
	state = CardState.CARRIED_BY_PLAYER
	locked = false
	physics_off()

func drop_to_ground():
	# Snap card to character position immediately
	global_position = carrier_player.global_position + Vector3(0, 0.5, 0)
	rotation_degrees.x += 60
	
	has_flattened = false
	carrier_player = null
	carrier_target = null
	mount_target = null
	state = CardState.FREE_FLOATING
	locked = false
	physics_on()
	self.linear_velocity = Vector3(0, -2.5, 0)  # Small down speed
	#self.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-1, 1), randf_range(-2, 2))

func physics_on():
	self.freeze = false
	self.sleeping = false
	self.linear_velocity = Vector3.ZERO
	self.angular_velocity = Vector3.ZERO
	self.gravity_scale = 1.0

func physics_off():
	self.freeze = true
	self.sleeping = true
	self.linear_velocity = Vector3.ZERO
	self.angular_velocity = Vector3.ZERO
	self.gravity_scale = 0.0
	
func mount_to(target: Node3D, offset: Transform3D = Transform3D.IDENTITY):
	carrier_player = null
	mount_target = target
	mount_offset = offset
	state = CardState.ON_STACK
	locked = false
