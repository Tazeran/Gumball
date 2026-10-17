#playable stack that recieves the 3 or remaining cards flipped off the stock stack
#flipping controlled by team_master.gd
extends DeckStack
class_name FlipStack

func interaction_available(player: Player) -> bool:
	if player.carried_cards.size() > 0: #player carrying a card
		return can_accept_card(player.carried_cards[0])
	else:
		return can_remove_card(get_top_card())
#
	#if player.carried_card != null: #player carrying a card
		#if locked and locked_by_card == player.carried_card:
			#return true
	#else:
		#if cards.is_empty() or team != card.team:
			#
	#
	#return false
	#if player.team != team:
		#return false
	#if player.carried_card != null: #player carrying a card
		#if locked && locked_by_card != player.carried_card:
			#return false
	#else: 
	#return !cards.is_empty()

func can_remove_card(card: Node3D) -> bool:
	if card == null:
		return false
	if team != card.team:
		return false
	return !locked

func can_accept_card(card: Node3D) -> bool:
	if locked and locked_by_card == card:
		return true
	return false

func add_card(card: Node3D):
	card.set_face_up(true)
	super.add_card(card)
