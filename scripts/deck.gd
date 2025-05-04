# Deck.gd
class_name Deck

const SUITS = ["hearts", "diamonds", "clubs", "spades"]
const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var cards: Array = []  # Array of CardData

func create_full_deck():
	cards.clear()
	for suit in SUITS:
		for rank in RANKS:
			var card_data = CardData.new()
			card_data.suit = suit
			card_data.rank = rank
			cards.append(card_data)

func shuffle():
	cards.shuffle()

func draw_card() -> CardData:
	if cards.is_empty():
		return null
	return cards.pop_back()

func is_empty() -> bool:
	return cards.is_empty()

func cards_remaining() -> int:
	return cards.size()
