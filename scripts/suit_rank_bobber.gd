extends Node3D

@export var suit : String = "Diamonds"
@export var rank : String = "Q"

const pale_red = Color(0.8, 0.2, 0.2)
const dark_gray = Color(0.2, 0.2, 0.2)

var card_meshes_scene = preload("res://BlenderAsset/PlayingCardRanks.blend")

func _ready() -> void:
	var card_meshes_instance = card_meshes_scene.instantiate()
	
	var suit_node = card_meshes_instance.get_node("Suit_" + suit)
	var rank_node = card_meshes_instance.get_node("Rank_" + rank)
	
	if suit_node and rank_node:
		var suit_mesh = suit_node.duplicate()
		var rank_mesh = rank_node.duplicate()
		
		suit_mesh.transform.origin = Vector3(0, 0, 0)
		rank_mesh.transform.origin = Vector3(0, 1, 0)
		
		# Decide the color
		var color = pale_red if (suit == "Diamonds" or suit == "Hearts") else dark_gray
		
		# Create new materials
		var suit_material = StandardMaterial3D.new()
		suit_material.albedo_color = color
		suit_material.metallic = 0.2
		suit_material.roughness = 0.3
		suit_material.emission = color * 0.2

		var rank_material = StandardMaterial3D.new()
		rank_material.albedo_color = color
		
		# Assign the new materials
		suit_mesh.set_surface_override_material(0, suit_material)
		rank_mesh.set_surface_override_material(0, rank_material)
		
		add_child(suit_mesh)
		add_child(rank_mesh)
		
		# Start spinning / bobbing
		#if $AnimationPlayer:
			#$AnimationPlayer.play("SpinBob")

func _process(delta: float) -> void:
	rotate_y(delta * 0.5)  # Spin smoothly
	var bob = sin(Time.get_ticks_msec() / 500.0) * 0.2
	position.y = bob
