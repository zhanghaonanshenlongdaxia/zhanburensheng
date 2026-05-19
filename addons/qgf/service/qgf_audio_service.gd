class_name QGFAudioService
extends RefCounted

var root: Node
var buses: Dictionary = {
	&"sfx": "Master",
	&"music": "Master"
}
var _music_player: AudioStreamPlayer

func setup(audio_root: Node, bus_map: Dictionary = {}) -> void:
	root = audio_root
	for key in bus_map:
		buses[key] = bus_map[key]
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "QGFMusicPlayer"
	_music_player.bus = str(buses.get(&"music", "Master"))
	if root != null:
		root.call_deferred("add_child", _music_player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0, bus_key: StringName = &"sfx") -> AudioStreamPlayer:
	if root == null or stream == null:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = str(buses.get(bus_key, "Master"))
	player.finished.connect(player.queue_free)
	if root != null:
		root.call_deferred("add_child", player)
	player.play()
	return player

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _music_player == null or stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
