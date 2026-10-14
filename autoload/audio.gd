extends Node
## Autoload `Audio`: sound effects by name (`Audio.play(&"hit")`) and looping
## music (`Audio.play_music(&"battle")`). Sounds that fire a lot (hits, shots)
## are throttled with `max_per_second`. To add a sound: put the file in
## assets/audio/, list it in assets.json, and add it to SOUNDS or MUSIC.
## Volumes come from the settings screen (Game.music_volume, Game.sfx_volume).

const SOUNDS: Dictionary[StringName, String] = {
	&"build": "res://assets/audio/build.wav",
	&"upgrade": "res://assets/audio/upgrade.wav",
	&"sell": "res://assets/audio/sell.wav",
	&"arrow": "res://assets/audio/arrow.wav",
	&"cannon": "res://assets/audio/cannon.wav",
	&"frost": "res://assets/audio/frost.wav",
	&"sun": "res://assets/audio/sun.wav",
	&"hit": "res://assets/audio/hit.wav",
	&"enemy_die": "res://assets/audio/enemy_die.wav",
	&"leak": "res://assets/audio/leak.wav",
	&"wave_start": "res://assets/audio/wave_start.wav",
	&"wave_clear": "res://assets/audio/wave_clear.wav",
	&"win": "res://assets/audio/win.wav",
	&"lose": "res://assets/audio/lose.wav",
	&"click": "res://assets/audio/click.wav",
	&"coin": "res://assets/audio/coin.wav",
}
const MUSIC: Dictionary[StringName, String] = {
	&"title": "res://assets/audio/music_title.wav",
	&"battle": "res://assets/audio/music_battle.wav",
}
const VOICES := 16
const MUSIC_DB := -10.0

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name: StringName = &""
## When each throttled sound last played (ms), for `max_per_second`.
var _recent: Dictionary[StringName, Array] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep sounds going while paused
	for sound: StringName in SOUNDS:
		_streams[sound] = load(SOUNDS[sound])
	for i: int in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)


## Plays a sound from SOUNDS. `max_per_second` limits very frequent sounds.
func play(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0, max_per_second: int = 0) -> void:
	if not Game.sound_on or Game.sfx_volume <= 0.0:
		return
	if max_per_second > 0:
		var now := Time.get_ticks_msec()
		var times: Array = _recent.get(sound, [])
		times = times.filter(func(t: int) -> bool: return now - t < 1000)
		if times.size() >= max_per_second:
			_recent[sound] = times
			return
		times.append(now)
		_recent[sound] = times
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_error("Audio.play: unknown sound \"%s\" (add it to SOUNDS in autoload/audio.gd)" % sound)
		return
	var p := _free_player()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db + linear_to_db(Game.sfx_volume)
	p.play()


## Loops a track from MUSIC. Keeps playing if it's already on. &"" stops music.
func play_music(track: StringName) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	_music.stop()
	if track == &"":
		return
	if not MUSIC.has(track):
		push_error("Audio.play_music: unknown track \"%s\" (add it to MUSIC)" % track)
		return
	var stream: AudioStream = load(MUSIC[track])
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	apply_sound_setting()


## Applies Game.sound_on and the music volume (call after changing them).
func apply_sound_setting() -> void:
	_music.volume_db = MUSIC_DB + linear_to_db(maxf(Game.music_volume, 0.001))
	if not Game.sound_on:
		stop_all()
	elif Game.music_volume <= 0.0:
		_music.stop()
	elif _music.stream != null and not _music.playing:
		_music.play()


## Stops every sound and the music.
func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	_music.stop()


func _exit_tree() -> void:
	stop_all()
	for p: AudioStreamPlayer in _players:
		p.stream = null
	_music.stream = null


func _free_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			return p
	_next = (_next + 1) % _players.size()
	return _players[_next]
