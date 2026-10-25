extends Node3D

const front_material_index := 0
const back_material_index := 1
const edge_material_index := 2
const margin = 1.5 # 1 / 64.0  # ~0.5px into the texture, tweak as needed

@export var card_front_shader_material: ShaderMaterial
@export var edgeColor : Color = Color.WHITE
@export var suit : String = "hearts"
@export var rank : String = "K"

# Base paths
const TEXTURE_PATH = "res://models/Cards/Textures/"
const FRONT_TEXTURE_FORMAT = "%s_%s.png" # example: "card_hearts_A.png"
const BACK_TEXTURE_NAME = "card_back.png"

# Node reference
@onready var mesh = $Cube  # Adjust this path if your mesh is named differently

func _ready():
	if mesh == null:
		push_error("CardMesh not found!")
	else:
		# Set default textures (optional)
		set_edge_color(edgeColor)
		set_card(suit, rank)

func set_card(new_suit: String, new_rank: String) -> void:
	suit = new_suit
	rank = new_rank

	var texture_rank := str(int(rank)) if rank.is_valid_int() else rank
	var front_texture_path = TEXTURE_PATH + FRONT_TEXTURE_FORMAT % [ "card_" + suit.to_lower(), texture_rank ]
	var back_texture_path = TEXTURE_PATH + BACK_TEXTURE_NAME

	var front_texture = load(front_texture_path)
	var back_texture = load(back_texture_path)

	if front_texture and back_texture:
		var front_material = card_front_shader_material.duplicate()
		front_material.set_shader_parameter("albedo_texture", front_texture)
		front_material.set_shader_parameter(
			"uv_offset",
			Vector2(
				(11.0 + margin) / 64.0,
				(2.0 + margin) / 64.0
			)
		)
		front_material.set_shader_parameter(
			"uv_scale",
			Vector2(
				(42.0 - (margin * 2)) / 64.0,
				(60.0 - (margin * 2)) / 64.0
			)
		)

		mesh.set_surface_override_material(front_material_index, front_material)
		front_material.set_shader_parameter("albedo_texture", front_texture)

		var back_material = card_front_shader_material.duplicate()
		back_material.set_shader_parameter("albedo_texture", back_texture)
		back_material.set_shader_parameter(
			"uv_offset",
			Vector2(
				(11.0 + margin) / 64.0,
				(2.0 + margin) / 64.0
			)
		)
		back_material.set_shader_parameter(
			"uv_scale",
			Vector2(
				(42.0 - (margin * 2)) / 64.0,
				(60.0 - (margin * 2)) / 64.0
			)
		)
		mesh.set_surface_override_material(back_material_index, back_material)
		back_material.set_shader_parameter("albedo_texture", back_texture)
		
	else:
		push_error("Card textures not found for %s %s" % [suit, rank])


func set_edge_color(color: Color) -> void:
	edgeColor = color
	var edge_material = mesh.get_surface_override_material(edge_material_index)
	if edge_material == null:
		edge_material = mesh.mesh.surface_get_material(edge_material_index).duplicate()
		mesh.set_surface_override_material(edge_material_index, edge_material)
		
	if edge_material:
		edge_material.albedo_color = edgeColor
