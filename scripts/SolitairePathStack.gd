# SolitairePathStack.gd
class_name SolitairePathStack
extends DeckStack

@onready var visualizer := $DecalPath
@export var max_cards: int = 13

func set_area_to_end():
	pickup_area.global_transform = visualizer.get_card_transform(cards.size() - 1)

func add_card(card: Node3D) -> void:
	super.add_card(card)
	set_area_to_end()

func remove_top_card() -> Node3D:
	var card := super.remove_top_card()
	set_area_to_end()
	return card

func can_accept_card(card: Node3D) -> bool:
	if cards.size() >= max_cards:
		return false

	if cards.is_empty():
		return card.team == team

	var top = get_top_card()
	var colors_different = card.get_color() != top.get_color()
	var ranks_correct = card.get_rank_value() == top.get_rank_value() - 1
	print(card.get_rank_value(), card.get_color(), " ", top.get_rank_value() , top.get_color())
	#return true
	return colors_different and ranks_correct

func get_card_transform(index: int) -> Transform3D:
	return visualizer.get_card_transform(index)

#func get_card_position(index: int) -> Vector3:
	#print("solitaire card pos")
	#return visualizer.get_card_transform(index).origin
#
#func get_card_rotation(index: int) -> Basis:
	#return visualizer.get_card_transform(index).basis
