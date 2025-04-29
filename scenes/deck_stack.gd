extends Node3D

@onready var pickup_area = $Area3D
@export var stack_position_offset: Vector3 = Vector3(0, 0.02, 0)  # Vertical gap between cards
var cards: Array = []


func add_card(card: Node3D):
	cards.append(card)
	card.global_position = global_position + (stack_position_offset * cards.size())
	card.global_rotation = Vector3.ZERO  # Optional: straighten rotation if needed

func remove_top_card() -> Node3D:
	if cards.is_empty():
		return null
	var card = cards.pop_back()
	return card

func get_card_count() -> int:
	return cards.size()

func get_ground_position(max_distance: float = 10.0) -> Vector3:
	var start = global_position
	var end = start - Vector3.UP * max_distance
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = start
	query.to = end
	query.collision_mask = 1  # Assuming Terrain is Layer 1. Change if needed.

	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	else:
		# No ground detected below, fallback to own position
		return global_position
