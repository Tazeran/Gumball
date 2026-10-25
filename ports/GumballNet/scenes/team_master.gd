extends Node3D
class_name TeamMaster

@export var card_scene: PackedScene  # Your Card.tscn
@export var team_name: String

@export var goalStack: GoalStack
@export var solitaireStack1: SolitairePathStack
@export var solitaireStack2: SolitairePathStack
@export var solitaireStack3: SolitairePathStack
@export var solitaireStack4: SolitairePathStack
@export var stockStack: StockStack
@export var flipStack: FlipStack
@export var cycleInteractable: HoldInteractable
@export var reshuffleInteractable: HoldInteractable

const reshuffle_coin_cost = 20
const MAX_CYCLE_CARDS = 3
var deck: Deck

func _ready():
	cycleInteractable.interaction_available_delegate = Callable(self, "_cycle_interaction_available")
	reshuffleInteractable.interaction_available_delegate = Callable(self, "_reshuffle_interaction_available")

	#cycleInteractable.interaction_available_delegate = self
	#reshuffleInteractable.interaction_available_delegate = self
	cycleInteractable.hold_completed.connect(_on_cycle_triggered)
	reshuffleInteractable.hold_completed.connect(_on_reshuffle_triggered)

func spawn_card(card_data, stack: DeckStack) -> void:
	var card = card_scene.instantiate()
	card.network_id = "%s:%s:%s" % [team_name, card_data.suit, card_data.rank]
	card.name = "Card_%s_%s_%s" % [team_name, card_data.suit, card_data.rank]
	add_child(card)
	card.set_team(team_name)
	card.set_card(card_data.suit, card_data.rank, Master.team_backs[team_name])
	stack.add_card(card)

func deal_hand():
	# TODO: cleanup old cards if replaying, make it's own function
	goalStack.team = team_name
	stockStack.team = team_name
	flipStack.team = team_name
	cycleInteractable.team = team_name
	solitaireStack1.team = team_name
	solitaireStack2.team = team_name
	solitaireStack3.team = team_name
	solitaireStack4.team = team_name

	deck = Deck.new()
	deck.create_full_deck()
	deck.shuffle()
	print("Team ", team_name," deck cards:", deck.cards_remaining())

	# Deal 1 card to 4 solitaire paths
	spawn_card(deck.draw_card(), solitaireStack1)
	spawn_card(deck.draw_card(), solitaireStack2)
	spawn_card(deck.draw_card(), solitaireStack3)
	spawn_card(deck.draw_card(), solitaireStack4)

	for i in range(13): # Deal 13 to goal stack
		spawn_card(deck.draw_card(), goalStack)
	for i in range(35): # Deal 35 to cycle stack
		spawn_card(deck.draw_card(), stockStack)

	#stockStack.scatter_all_cards()
	#goalStack.scatter_all_cards()


func verify_full_deck() -> bool:
	var found_cards := {}
	print("verify_full_deck_for_team: ", team_name)
	for card in get_tree().get_nodes_in_group("cards"):
		if card.team == team_name:
			var key = "%s_%s" % [card.suit, card.rank]
			found_cards[key] = true

	for suit in Deck.SUITS:
		for rank in Deck.RANKS:
			var key = "%s_%s" % [suit, rank]
			if not found_cards.has(key):
				print("Missing card for team %s: %s" % [team_name, key])
				return false

	return true

func _reshuffle_interaction_available(player: Player, source: Node = null) -> bool:
	return player.coins >= reshuffle_coin_cost

#func _on_reshuffle_triggered():
	#print("_on_reshuffle_triggered")
	#flipStack
	#stockStack
	#goalStack


	#store number of current cards on each those stack (including if one is presently carried in a players hand locking that stack)
	#pull/teleport them all those cards away and any ones carried by players of that team
	#then shuffle and redeal that stored number to each location, though flip stack will place it's all onto stock

func _clear_stack(stack: DeckStack) -> Array:
	var pulled: Array = []
	while not stack.cards.is_empty():
		var card = stack.remove_top_card(false)
		pulled.append(card)
	return pulled

func _on_reshuffle_triggered(_player: Node):
	print("_on_reshuffle_triggered")
	_player.coins = _player.coins - reshuffle_coin_cost

	var collected_cards: Array = []
	var flip_count := flipStack.cards.size()
	var stock_count := stockStack.cards.size()
	var goal_count := goalStack.cards.size()
	print("counts ", flip_count, " ", stock_count, " ", goal_count, " ", collected_cards.size())
	# 1. Collect and clear cards from stacks
	collected_cards += _clear_stack(flipStack)
	collected_cards += _clear_stack(stockStack)
	collected_cards += _clear_stack(goalStack)

	# 2. Collect and clear from team players
	#for player in get_tree().get_nodes_in_group("players"):
		#if player.team != team_name:
			#continue
#
		#var card = player.carried_card
		#if card == null:
			#continue
#
		#var is_locking_flip = flipStack.locked_by_card == card
		#var is_locking_goal = goalStack.locked_by_card == card
#
		#if is_locking_flip or is_locking_goal:
			#player.drop_card()
			#collected_cards.append(card)
#
			#if is_locking_flip:
				#flip_count += 1
				#flipStack.unlock_stack()
			#if is_locking_goal:
				#goal_count += 1
				#goalStack.unlock_stack()

	# 3. Shuffle the collected cards
	collected_cards.shuffle()

	# 4. Redeal
	for i in range(goal_count):
		if collected_cards.is_empty():
			break
		var card = collected_cards.pop_back()
		goalStack.add_card(card)

	for i in range(stock_count + flip_count):
		if collected_cards.is_empty():
			break
		var card = collected_cards.pop_back()
		stockStack.add_card(card)


func _cycle_interaction_available(player: Player, source: Node = null) -> bool:
	if flipStack.locked || player.carried_cards.size() > 0 || (stockStack.cards.is_empty() && flipStack.cards.is_empty()): #&& flipStack.locked_by_card != player.carried_card
		return false
	return true

func _on_cycle_triggered(player: Player):
	if !_cycle_interaction_available(player):
		return
	# Step 1: If deck is empty, flip pile back into deck (face down)
	if stockStack.cards.is_empty():
		while not flipStack.cards.is_empty():
			var card = flipStack.remove_top_card(false)
			card.set_face_up(false)
			stockStack.add_card(card)
		Audio.playRandom(Audio.CardShoves)
		return

	# Step 2: Flip up to 3 cards from deck to pile
	var flips = min(MAX_CYCLE_CARDS, stockStack.get_card_count())
	for i in range(flips):
		var card = stockStack.remove_top_card(false)
		card.set_face_up(true)
		flipStack.add_card(card)
	
	Audio.playRandom(Audio.CardSlides)
