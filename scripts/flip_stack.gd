extends DeckStack
class_name FlipStack

func can_accept_card(card: Node3D) -> bool:
	return true  # CycleStack handles legality, pile is just a display

#No need to ovveride, same as base class
#func can_remove_card(card: Node3D) -> bool:
#	return true  # Players can pull top card from here

func add_card(card: Node3D):
	card.set_face_up(true)
	super.add_card(card)
