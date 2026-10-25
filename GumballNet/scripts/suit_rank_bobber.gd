extends Node3D

@export var suit: String = "Spades"
@export var rank: String = "A"

const pale_red = Color(0.8, 0.2, 0.2, 0.8)
#const dark_gray = Color(0.2, 0.2, 0.2, 0.8)
const dark_gray = Color(0.2, 0.2, 0.5, 0.8)

const LAYER_2 = 1 << 1  # Layer 2 to avoid decals
var position_offset: Vector3 = Vector3.ZERO
var base_position: Vector3 = Vector3.ZERO


var card_meshes_scene = preload("res://BlenderAsset/PlayingCardRanks.blend")
var card_meshes_instance: Node = null

static var suit_cache: Dictionary = {}
static var rank_cache: Dictionary = {}
var current_visuals: Array = []

func _ready() -> void:
	card_meshes_instance = card_meshes_scene.instantiate()
	cache_meshes()
	set_card(suit, rank)
	base_position = position

func cache_meshes():
	if suit_cache.size() == 0:
		for s in ["Hearts", "Diamonds", "Clubs", "Spades"]:
			var node = card_meshes_instance.get_node_or_null("Suit_" + s)
			if node:
				suit_cache[s] = node.duplicate(true)

	if rank_cache.size() == 0:
		for r in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
			var node = card_meshes_instance.get_node_or_null("Rank_" + r)
			if node:
				rank_cache[r] = node.duplicate(true)

func clear_visuals():
	for node in current_visuals:
		if node and node.is_inside_tree():
			remove_child(node)
			node.queue_free()
	current_visuals.clear()

func set_card(new_suit: String, new_rank: String) -> void:
	clear_visuals()

	suit = new_suit
	rank = new_rank

	if suit == "" or rank == "":
		visible = false
		return
	visible = true

	var suit_source = suit_cache.get(suit)
	var suit_mesh = null
	if suit_source:
		suit_mesh = suit_source.duplicate(true)

	var rank_source = rank_cache.get(rank)
	var rank_mesh = null
	if rank_source:
		rank_mesh = rank_source.duplicate(true)

	if not suit_mesh:
		print("Missing mesh for suit: ", suit)
		return
	if not rank_mesh:
		print("Missing mesh for rank: ", rank)
		return

	suit_mesh.transform.origin = Vector3(0, 0, 0)
	rank_mesh.transform.origin = Vector3(0, 0.8, 0)

	#if suit_mesh is MeshInstance3D:
	suit_mesh.layers = LAYER_2
	#if rank_mesh is MeshInstance3D:
	rank_mesh.layers = LAYER_2

	var color = pale_red if (suit == "Diamonds" or suit == "Hearts") else dark_gray

	var suit_material = StandardMaterial3D.new()
	suit_material.albedo_color = color
	#suit_material.metallic = 0.2
	#suit_material.roughness = 0.3
	#suit_material.emission = color * 0.2
	suit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	suit_material.flags_transparent = true
	
	var rank_material = StandardMaterial3D.new()
	rank_material.albedo_color = color
	rank_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rank_material.flags_transparent = true

	suit_mesh.set_surface_override_material(0, suit_material)
	rank_mesh.set_surface_override_material(0, rank_material)

	add_child(suit_mesh)
	add_child(rank_mesh)
	current_visuals.append(suit_mesh)
	current_visuals.append(rank_mesh)

func _process(delta: float) -> void:
	rotate_y(delta * 1.5)
	var bob = sin(Time.get_ticks_msec() / 400.0) * 0.1
	position.x = base_position.x + position_offset.x
	position.y = base_position.y + position_offset.y + bob
	position.z = base_position.z + position_offset.z
