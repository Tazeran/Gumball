extends RigidBody3D
class_name PCard
static var texture_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static var edge_material_cache := {}

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
@export var mesh : MeshInstance3D

# Editable properties
@export var card_front_shader_material: ShaderMaterial
@export var edge_color : Color = Color.BLACK
@export var suit : String = "hearts"
@export var rank : String = "K"
var rank_value: int = 13  # Set in set_card
var color: String = "red"  # "red" or "black"
var team: String = "N"  # Assigned during dealing
var my_back_key: String = "default_back"  # set by set_card()
var source_deckstack: DeckStack = null

const RANKS := {
	"A": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7,
	"8": 8, "9": 9, "10": 10, "J": 11, "Q": 12, "K": 13
}
const RED_SUITS := ["Hearts", "Diamonds"]
const BLACK_SUITS := ["Spades", "Clubs"]

var attached_cards: Array[PCard] = []

@onready var pickup_area = $Area3D

var low_speed_timer = 0.0
var flattening = false
var has_flattened = false

# Runtime state
var state: CardState = CardState.FREE_FLOATING
var mount_target: Node3D = null
var mount_offset: Transform3D = Transform3D.IDENTITY
var carrier_player: Node3D = null
var carrier_target: Node3D = null

# Base paths
const TEXTURE_PATH = "res://models/cards/textures/"
const FRONT_TEXTURE_FORMAT = "%s_%s.png" # example: "card_hearts_A.png"

# Bobbing behavior (only when floating freely)
var bob_timer := 0.0
var bob_height := 0.2
var bob_speed := 1.0
var base_position: Vector3


func get_attached_group() -> Array[PCard]:
	var group = [self]
	for card in attached_cards:
		group += card.get_attached_group()
	return group


func get_rank_value() -> int:
	return rank_value

func get_color() -> String:
	return color

const TEAM_COLORS := {
	"A": Color(0.4, 0.6, 1.0),  # Soft blue
	"B": Color(1.0, 0.5, 0.5)   # Soft red
}
func set_team(teamStr: String):
	team = teamStr
	set_edge_color(TEAM_COLORS.get(team, Color.GRAY))


var is_face_up: bool = true
func set_face_up(face_up: bool = true):
	is_face_up = face_up

	# Flip over the X axis (local pitch) without affecting Y rotation
	#var current_rot = rotation
	#if face_up:
		#current_rot.x = 0.0
	#else:
		#current_rot.x = PI
	#rotation = current_rot

	# Swap material based on face
	var front_key := "%s_%s" % [suit, rank]
	if face_up:
		mesh.set_surface_override_material(front_material_index, material_cache[front_key])
	else:
		mesh.set_surface_override_material(back_material_index, material_cache[my_back_key])


func _ready():
	self.set_freeze_mode(FreezeMode.FREEZE_MODE_KINEMATIC)
	#print("ready pickup_area", pickup_area)
	if pickup_area == null:
		push_error("pickup_area not found!")
		print("asdf asdf asd f asready")
	base_position = global_position
	add_to_group("interactables")
	add_to_group("cards")
	if mesh == null:
		push_error("CardMesh not found!")
	#else:
		#set_edge_color(edge_color)
		#set_card(suit, rank)

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
		#print("Card fully flattened!")

func get_marker_position(player: Player):
	return global_position

func interaction_available(player: Player) -> bool:
	if team != player.team:
		return false
	if state != CardState.FREE_FLOATING:
		return false
	return player.carried_card == null


func change_state(new_state: int) -> void:
	#if state == new_state:
		#return  # No need to change to same state
	state = new_state
	match state:
		CardState.ON_STACK:
			#print("pickup_area", self, pickup_area)
			if pickup_area:
				pickup_area.monitorable = false
			physics_off()

		CardState.FREE_FLOATING:
			if pickup_area:
				pickup_area.monitorable = true
			physics_on()

		CardState.CARRIED_BY_PLAYER:
			if pickup_area:
				pickup_area.monitorable = false
			physics_off()

func _physics_process(delta):
	if global_transform.origin.y < -20:
		global_position = base_position  #TODO change this to return to team/source_deckstack
		self.linear_velocity = Vector3.ZERO
		self.angular_velocity = Vector3.ZERO

	match state:
		CardState.FREE_FLOATING:
			#_handle_free_float(delta)
			if !flattening and !has_flattened:
				# Check if card is nearly stopped
				#print(self.linear_velocity.length(), "   ", self.angular_velocity.length())
				if self.linear_velocity.length() < 0.36 and self.angular_velocity.length() < 1.79:
					low_speed_timer += delta
					if low_speed_timer > 0.5:  # been slow for half a second
						#print("Starting flattening!")
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
			if mount_target and is_instance_valid(mount_target):
				if mount_target.has_method("get_card_transform"):
					# Ask the stack for the transform based on its current index
					var stack_index = mount_target.cards.find(self)
					if stack_index != -1:
						global_transform = mount_target.get_card_transform(stack_index)
				else:
					global_transform = mount_target.global_transform * mount_offset



func _handle_free_float(delta):
	bob_timer += delta * bob_speed
	var offset_y = (sin(bob_timer) * 0.5 + 0.5) * bob_height
	#global_position = base_position + Vector3(0, offset_y, 0)

func set_card(new_suit: String, new_rank: String, back_key: String = "default") -> void:
	suit = new_suit
	rank = new_rank
	my_back_key = back_key

	rank_value = RANKS.get(rank, 0)
	color = "red" if RED_SUITS.has(suit) else "black"

	var front_key := "%s_%s" % [suit, rank]
	var front_texture_path := TEXTURE_PATH + FRONT_TEXTURE_FORMAT % ["card_" + suit, rank]
	var back_texture_path := TEXTURE_PATH + "%s.png" % back_key

	# --- Texture caching ---
	if !texture_cache.has(front_key):
		texture_cache[front_key] = load(front_texture_path)
	if !texture_cache.has(back_key):
		texture_cache[back_key] = load(back_texture_path)

	var front_texture = texture_cache[front_key]
	var back_texture = texture_cache[back_key]

	# --- Material caching ---
	if !material_cache.has(front_key):
		var mat = card_front_shader_material.duplicate()
		mat.set_shader_parameter("albedo_texture", front_texture)
		mat.set_shader_parameter("uv_offset", Vector2((11.0 + margin) / 64.0, (2.0 + margin) / 64.0))
		mat.set_shader_parameter("uv_scale", Vector2((42.0 - margin * 2) / 64.0, (60.0 - margin * 2) / 64.0))
		material_cache[front_key] = mat

	if !material_cache.has(back_key):
		var back_mat = card_front_shader_material.duplicate()
		back_mat.set_shader_parameter("albedo_texture", back_texture)
		back_mat.set_shader_parameter("uv_offset", Vector2((11.0 + margin) / 64.0, (2.0 + margin) / 64.0))
		back_mat.set_shader_parameter("uv_scale", Vector2((42.0 - margin * 2) / 64.0, (60.0 - margin * 2) / 64.0))
		material_cache[back_key] = back_mat

	# --- Assign materials ---
	mesh.set_surface_override_material(front_material_index, material_cache[front_key])
	mesh.set_surface_override_material(back_material_index, material_cache[back_key])



func set_edge_color(color: Color) -> void:
	edge_color = color
	# Use color as the cache key (to_hex or direct Color object)
	var key = color.to_html(false)  # e.g., "#FF0000"
	if not edge_material_cache.has(key):
		var base_mat = mesh.mesh.surface_get_material(edge_material_index)
		if base_mat:
			var mat = base_mat.duplicate()
			mat.albedo_color = color
			edge_material_cache[key] = mat
	else:
		# Material already cached for this color
		pass

	# Apply material from cache
	mesh.set_surface_override_material(edge_material_index, edge_material_cache[key])

func interact(player):
	if state == CardState.FREE_FLOATING:
		if player.team != team:
			print("Cannot interact with card from another team.")
			return
		player.pick_up_card(self)

func pick_up(player: Node3D, target_mount: Node3D = null):
	print("card/pick_up: ", target_mount)
	carrier_player = player
	mount_target = null
	has_flattened = false
	carrier_target = target_mount if target_mount != null else player
	change_state(CardState.CARRIED_BY_PLAYER)
	physics_off()

func drop_to_ground():
	# Determine starting position
	if carrier_player and is_instance_valid(carrier_player):
		global_position = carrier_player.global_position + Vector3(0, 0.5, 0)
	# Otherwise keep current position or assume it's already positioned by caller

	rotation_degrees.x += 60

	has_flattened = false
	carrier_player = null
	carrier_target = null
	mount_target = null
	change_state(CardState.FREE_FLOATING)
	physics_on()

	self.linear_velocity = Vector3(0, -2.5, 0)  # Small down speed
	self.angular_velocity = Vector3(-2.5, 0, 0)
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
	change_state(CardState.ON_STACK)
