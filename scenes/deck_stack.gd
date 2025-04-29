extends Node3D

@onready var pickup_area = $Area3D
@export var stack_position_offset: Vector3 = Vector3(0, 0.02, 0)  # Vertical gap between cards
var cards: Array = []
var vertical_spacing: float = 0.015

func _ready():
	add_to_group("interactables")
	add_to_group("decks")

func add_card(card: Node3D):
	cards.append(card)
	card.global_position = global_position + (stack_position_offset * cards.size())
	card.global_rotation = Vector3.ZERO  # Optional: straighten rotation if needed
	
	card.mount_target = self
	var offset_y = vertical_spacing * (cards.size() - 1)  # -1 because we just added the new one
	card.mount_offset = Transform3D(Basis(), Vector3(0, offset_y, 0))
	card.change_state(card.CardState.ON_STACK)

func interact(player):
	print("deck stack interact: ", self, player)

	if player.is_holding_card():
		print("Dropping card onto stack:", player.carried_card)
		player.drop_card_onto_stack(self)

	else:
		var top_card = remove_top_card()
		print("Picking up top card:", top_card)
		if top_card:
			player.pick_up_card(top_card)

func get_top_card() -> Node3D:
	if cards.is_empty():
		return null
	return cards[-1]

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
