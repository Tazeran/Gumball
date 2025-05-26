# SolitairePathStack.gd
class_name SolitairePathStack
extends DeckStack

@onready var visualizer := $DecalPath
@export var max_cards: int = 13

func set_area_to_end():
	pickup_area.global_transform = visualizer.get_card_transform(cards.size() - 1)

func get_marker_position(player: Player) -> Vector3:
	if player.carried_card == null:
		return visualizer.get_card_transform(cards.size()-1).origin
	else:
		return visualizer.get_card_transform(cards.size()).origin

func interaction_available(player: Player) -> bool:
	if player.team != team:
		return false
	if locked && player.carried_card != locked_by_card:
		return false

	if player.carried_card != null:
		return can_accept_card(player.carried_card)
	return !cards.is_empty()

func can_accept_card(card: Node3D) -> bool:
	if cards.size() >= max_cards || card.team != team || (locked && card != locked_by_card):
		return false
	if cards.is_empty():
		return true

	var top = get_top_card()
	var colors_different = card.get_color() != top.get_color()
	var ranks_correct = card.get_rank_value() == top.get_rank_value() - 1
	print(card.get_rank_value(), card.get_color(), " ", top.get_rank_value() , top.get_color())
	#return true
	return colors_different and ranks_correct

func add_card(card: Node3D) -> void:
	super.add_card(card)
	set_area_to_end()

func remove_top_card(lock_the_stack: bool =  true) -> Node3D:
	var card := super.remove_top_card(lock_the_stack)
	set_area_to_end() #todo, move the lock?
	return card

func get_card_transform(index: int) -> Transform3D:
	return visualizer.get_card_transform(index)

#func get_card_position(index: int) -> Vector3:
	#print("solitaire card pos")
	#return visualizer.get_card_transform(index).origin
#
#func get_card_rotation(index: int) -> Basis:
	#return visualizer.get_card_transform(index).basis
