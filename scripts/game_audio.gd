extends Node

const MUSIC_PATH := "res://assets/sounds/music.mp3"
const MUSIC_VOLUME_DB := -12.0

var music_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	var stream := load(MUSIC_PATH)
	if stream != null:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		music_player.stream = stream
	music_player.volume_db = MUSIC_VOLUME_DB
	music_player.bus = "Master"
	add_child(music_player)
	music_player.play()
