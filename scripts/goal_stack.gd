extends DeckStack
class_name GoalStack #Priscilla Pounce Pile (13)

#TODO remember card?
#var remember_card: Node3D

func can_accept_card(card: Node3D) -> bool:
	#Only if it was the card you took
	return true  # Allow cycling cards to be returned

func can_remove_card(card: Node3D) -> bool:
	# if there is no remember card, you can take one off
	return true

func add_card(card: Node3D):
	card.set_face_up(false)
	super.add_card(card)
