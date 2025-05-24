extends Node

var num_players = 12
var bus = "master"

var available = []  # The available players.
var queue = []  # The queue of sounds to play.

var music_player: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

static var CardSlides := [
	"res://sounds/card-slide-1.ogg",
	"res://sounds/card-slide-2.ogg",
	"res://sounds/card-slide-3.ogg",
	"res://sounds/card-slide-4.ogg",
	"res://sounds/card-slide-5.ogg",
	"res://sounds/card-slide-6.ogg",
	"res://sounds/card-slide-7.ogg",
	"res://sounds/card-slide-8.ogg"
]
static var CardPlaces := [
	"res://sounds/card-place-1.ogg",
	"res://sounds/card-place-2.ogg",
	"res://sounds/card-place-3.ogg",
	"res://sounds/card-place-4.ogg"
]
static var CardShoves := [
	"res://sounds/card-shove-1.ogg",
	"res://sounds/card-shove-2.ogg",
	"res://sounds/card-shove-3.ogg",
	"res://sounds/card-shove-4.ogg"
]

func _ready():
	# SFX pool setup
	for i in num_players:
		var p = AudioStreamPlayer.new()
		add_child(p)
		available.append(p)
		p.volume_db = -10
		p.finished.connect(_on_stream_finished.bind(p))
		p.bus = bus

	# Music setup
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.bus = "music"  # Optional: create a dedicated music bus in the audio settings
	music_player.volume_db = -6



func _on_stream_finished(stream): available.append(stream)

func play(sound_path): queue.append(sound_path)
func playRandom(sound_path_list: Array):
	if sound_path_list.is_empty():
		push_error("Empty sound_path_list")
		return
	var index = rng.randi_range(0, sound_path_list.size() - 1)
	var sound_path = sound_path_list[index]
	queue.append(sound_path)

func play_music(path: String, loop := true):
	var stream = load(path)
	
	if stream is AudioStream:
		# Duplicate the stream so we can modify its loop flag safely
		stream = stream.duplicate()
		
		if stream is AudioStreamOggVorbis or stream is AudioStreamWAV:
			stream.loop = loop
	music_player.volume_db = -2  # slightly quieter
	music_player.stream = stream
	music_player.play()
	music_player.stream_paused = false


func stop_music():
	music_player.stop()

func pause_music():
	music_player.stream_paused = true

func resume_music():
	music_player.stream_paused = false


func _process(_delta):

	if not queue.is_empty() and not available.is_empty():
		
		available[0].stream = load(queue.pop_front())
		available[0].play()
		available[0].pitch_scale = randf_range(0.9, 1.1)
		
		available.pop_front()
