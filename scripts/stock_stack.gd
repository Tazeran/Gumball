extends DeckStack
class_name StockStack

func can_accept_card(card: Node3D) -> bool:
	return true  # Allow cycling cards to be returned

func can_remove_card(card: Node3D) -> bool:
	return false  # Never allow removal from here

func add_card(card: Node3D):
	#card.set_face_up(false)
	super.add_card(card)

func interaction_available(player: Player) -> bool:
	return false
	#if player.carried_card != null:
		#return true
	#else:
		#return !cards.is_empty()

func get_card_transform(index: int) -> Transform3D:
	var transform := super.get_card_transform(index)
	transform.basis = Basis(Vector3.BACK, PI) * transform.basis
	return transform
