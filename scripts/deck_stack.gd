class_name DeckStack
extends Node3D

@onready var pickup_area = $Area3D
var stack_position_offset: Vector3 = Vector3(0, 0.014, 0)  # Vertical gap between cards
var cards: Array = []
#var groundPosition = null;
@export var top_face_down := false  # toggle per stack
@export var allow_dig := false  # can pick below top?
@export var face_up_on_add := true  # default behavior
@export var team = ""
var team_only = true
var ground_offset: Vector3 = Vector3.ZERO  # initialized in _ready or lazily

var locked := false
var locked_by_card: Node3D = null
@onready var lock_visual: Node3D = null  # Assigned during _ready

func _ready():
	#groundPosition = get_ground_position()
	ground_offset = to_local(get_ground_position())
	add_to_group("interactables")
	add_to_group("decks")
	
	lock_visual = preload("res://scenes/lock.tscn").instantiate()
	lock_visual.visible = false
	add_child(lock_visual)
	lock_visual.global_position = global_position + Vector3(0, 0.1, 0)

func lock_stack(card: Node3D):
	card.source_deckstack = self
	locked = true
	locked_by_card = card
	lock_visual.visible = true

func unlock_stack():
	locked = false
	locked_by_card = null
	lock_visual.visible = false

func is_locked() -> bool:
	return locked

func get_marker_position(player: Player) -> Vector3:
	return global_position

func interaction_available(player: Player) -> bool:
	if team_only && player.team != team:
		return false
	if player.carried_card != null:
		if locked:
			return locked_by_card == player.carried_card
		else:
			return true
	else:
		return !cards.is_empty()

func add_card(card: Node3D):
	#print("add_card ", self)

	#if !can_accept_card(card):
		#return

	if locked and locked_by_card == card:
		unlock_stack()

	card.source_deckstack = self

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
	#card.mount_offset = self.to_local(card.global_transform)
	card.change_state(card.CardState.ON_STACK)

	if face_up_on_add:
		card.set_face_up(true)

func can_accept_card(card: Node3D) -> bool:
	if locked && card.source_stack != self:
		return false
	# Base stack accepts anything — override in subclasses
	return true

func can_remove_card(card: Node3D) -> bool:
	if card == null:
		return false
	if locked || cards.is_empty():
		return false
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
		if !can_remove_card(peek_top_card):
			return
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

func remove_top_card(lock_the_stack: bool =  true) -> Node3D:
	if cards.is_empty() or locked:
		return null
	var card = cards.pop_back()
	if lock_the_stack:
		lock_stack(card)
	return card

func get_card_count() -> int:
	return cards.size()

#take the global_pos of our parent add that to local_ground_offset to get our new global_pos transform
#!!!! I don't like this down-raycasting solution to account for decalworldedit stuff
#probably some other solution with specific positioning, and use the mesh to show where stack will be, but delete it at gamestart
func get_card_transform(index: int) -> Transform3D:
	if ground_offset == Vector3.ZERO:
		var ground_world = get_ground_position()
		ground_offset = get_parent().to_local(ground_world)

	var parent_pos: Vector3
	var base_pos: Vector3
	if get_parent() == get_tree().current_scene:
		parent_pos = global_position
		base_pos = parent_pos + ground_offset
	else:
		parent_pos = get_parent().global_position
		base_pos = parent_pos + ground_offset + Vector3.UP * 0.55

	var up = global_transform.basis.y.normalized()
	var offset = up * stack_position_offset.y * float(index)
	var pos = base_pos + offset

	var basis = global_transform.basis.orthonormalized()
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
