extends DeckStack
class_name GoalStack
#Priscilla Pounce Pile (13)
const max_stack_cards = 13;

func can_accept_card(card: Node3D) -> bool:
	#never add to this deck, unless we're returning the locked
	if locked and locked_by_card == card:
		return true
	return false

func can_remove_card(card: Node3D) -> bool:
	if cards.is_empty() || locked:
		return false
	return true

func interaction_available(player: Player) -> bool:
	if team_only && player.team != team:
		return false
	if player.carried_card != null: #player carrying a card
		if cards.size() >= max_stack_cards:
			return false
		if locked:
			return locked_by_card == player.carried_card
		return true
	else: #player not carrying a card
		return !cards.is_empty()

func add_card(card: Node3D):
	card.set_face_up(false)
	super.add_card(card)
