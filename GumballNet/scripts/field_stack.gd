# field_stack.gd
extends DeckStack
class_name FieldStack #Community Center Piles

#TODO signal gamemaster about points
#TODO flip deck at KING, turn into coin spawning fountain

var suitRankBobberScene = preload("res://scenes/suit_rank_bobber.tscn")
var suitRankBobber_instance: Node3D = null
signal card_added_to_goal(card: Node3D)

func _ready():
	team_only = false
	suitRankBobber_instance = suitRankBobberScene.instantiate()
	add_child(suitRankBobber_instance)
	suitRankBobber_instance.position_offset = Vector3(0, 0.2, 0)
	setHoverBob()
	super._ready()

func setHoverBob():
	print("setHoverBob")
	var top_card = get_top_card()
	print("top ", top_card)
	print("suitRankBobber_instance ", suitRankBobber_instance)
	if top_card != null:
		print("top2 ", top_card, top_card.suit, top_card.rank)
		suitRankBobber_instance.set_card(top_card.suit, top_card.rank)
	else:
		suitRankBobber_instance.set_card("", "")

func can_accept_card(card: Node3D) -> bool:
	if not card:
		return false

	print("asdf1 ", card.rank, cards.is_empty(), card.rank == "A")
	if cards.is_empty():
		return card.rank == "A"
	print("asdf2")
	var top_card = get_top_card()
	print("asdf3", top_card)
	var same_suit = card.suit == top_card.suit
	print("asdf4")
	var correct_rank = card.get_rank_value() == top_card.get_rank_value() + 1

	print("asdf5", same_suit, correct_rank)
	return same_suit and correct_rank

func can_remove_card(card: Node3D) -> bool:
	return false

func interaction_available(player: Player) -> bool:
	if player.carried_cards.size() > 0:
		return can_accept_card(player.carried_cards[0])
	else:
		return false

func add_card(card: Node3D):
	super.add_card(card)
	setHoverBob()

#func add_card(card: Node3D) -> void:
	#if not can_accept_card(card):
		#return
	#
	#cards.append(card)
	#card.physics_off()
	#
	#var t := get_card_transform(cards.size() - 1)
	#card.global_transform = t
#
	#card.mount_target = self
	#card.mount_offset = Transform3D(Basis(), Vector3.ZERO)
	#card.change_state(card.CardState.ON_STACK)
	#card.set_face_up(true)
#
	#emit_signal("card_added_to_goal", card)

#func remove_top_card() -> Node3D:
	## Prevent removing cards from goal stack
	#return null
