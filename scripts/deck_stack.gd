class_name DeckStack
extends Node3D

@onready var pickup_area = $Area3D
var stack_position_offset: Vector3 = Vector3(0, 0.014, 0)  # Vertical gap between cards
var cards: Array = []
var groundPosition = null;
@export var top_face_down := false  # toggle per stack
@export var allow_dig := false  # can pick below top?
@export var face_up_on_add := true  # default behavior
@export var team = "N"
var team_only := true

func _ready():
	groundPosition = get_ground_position()
	add_to_group("interactables")
	add_to_group("decks")

func add_card(card: Node3D):
	#print("add_card ", self)
	if !can_accept_card(card):
		return

	cards.append(card)
	card.physics_off()
	#var card_transform = get_card_transform(cards.size() - 1)
	#card.global_position = card_transform.origin
	#card.global_rotation = card_transform.basis.get_euler()
	#card.global_transform = get_card_transform(cards.size() - 1)

	var t := get_card_transform(cards.size() - 1)
	#t.basis = Basis().rotated(Vector3.UP, deg_to_rad(30 * cards.size()))
	card.global_transform = t
	#print("Card transform set to:", card.global_transform)
	
	#card.global_position = get_card_position(cards.size() - 1)
	#card.global_rotation = Vector3.ZERO

	card.mount_target = self
	card.mount_offset = Transform3D(Basis(), Vector3.ZERO)
	card.change_state(card.CardState.ON_STACK)

	if face_up_on_add:
		card.set_face_up(true)

func can_accept_card(card: Node3D) -> bool:
	# Base stack accepts anything — override in subclasses
	return true

func interact(player):
	print("deck stack interact: ", self, player)

	if player.is_holding_card():
		if !can_accept_card(player.carried_card):
			return
		if team_only && team != player.carried_card.team:
			return
		print("Dropping card onto stack:", player.carried_card)
		player.drop_card_onto_stack(self)

	else:
		var peek_top_card = get_top_card()
		if team_only && player.team != team:
			return
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
#
#func get_card_position(index: int) -> Vector3:
	#print("normal card pos")
	#if groundPosition == null:
		#groundPosition = get_ground_position()
	#return groundPosition + (stack_position_offset * float(index))
#
func get_card_transform(index: int) -> Transform3D:
	if groundPosition == null:
		groundPosition = get_ground_position()

	var up := global_transform.basis.y.normalized()
	var offset := up * stack_position_offset.y * float(index)
	var pos : Vector3 = groundPosition + offset

	var basis := global_transform.basis.orthonormalized()
	return Transform3D(basis, pos)



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


func scatter_all_cards():
	for card in cards:
		if not is_instance_valid(card):
			continue

		var direction = Vector3(randf() * 2.0 - 1.0, 0, randf() * 2.0 - 1.0).normalized()
		var drop_position = global_position + Vector3.UP * 30 + direction * randf_range(1.5, 3.5)
		
		card.global_position = drop_position
		card.drop_to_ground()

	cards.clear()
