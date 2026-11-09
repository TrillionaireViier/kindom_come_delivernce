class_name SoundManager
extends Node

static var _sounds: Dictionary = {}
static var _audio_players: Array[AudioStreamPlayer] = []
static var _player_pool_size: int = 8
static var _next_player_idx: int = 0

static func init_audio(parent_node: Node) -> void:
	if _sounds.size() > 0:
		return
	
	_sounds["sword_swing"] = _generate_sweep(400.0, 120.0, 0.18, 0.45, true)
	_sounds["sword_clash"] = _generate_clash(850.0, 1420.0, 0.32, 0.7)
	_sounds["perfect_parry"] = _generate_chime(1200.0, 2400.0, 0.55, 0.8)
	_sounds["armor_hit"] = _generate_thud(110.0, 0.25, 0.8)
	_sounds["lockpick_click"] = _generate_click(1600.0, 0.04, 0.5)
	_sounds["lockpick_break"] = _generate_snap(500.0, 1800.0, 0.15, 0.75)
	_sounds["grindstone"] = _generate_noise_burst(0.25, 0.4)
	_sounds["victory"] = _generate_chime(780.0, 1560.0, 0.9, 0.7)
	_sounds["drink"] = _generate_glug(280.0, 0.22, 0.6)
	
	# Create pool of players
	for i in range(_player_pool_size):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		parent_node.add_child(player)
		_audio_players.append(player)

static func play(sound_name: String, pitch_scale: float = 1.0) -> void:
	if not _sounds.has(sound_name) or _audio_players.is_empty():
		return
	
	var player = _audio_players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % _audio_players.size()
	
	player.stream = _sounds[sound_name]
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.play()

static func _create_wav(bytes: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

static func _generate_sweep(start_f: float, end_f: float, duration: float, volume: float, add_noise: bool) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	var phase := 0.0
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var freq := lerpf(start_f, end_f, t * t)
		phase += (freq * TAU) / float(rate)
		
		var sample := sin(phase)
		if add_noise:
			sample = sample * 0.7 + (randf() * 2.0 - 1.0) * 0.3
		
		# Envelope: quick attack, smooth decay
		var env := sin(t * PI) if t < 0.3 else pow(1.0 - (t - 0.3) / 0.7, 1.5)
		var val := int(clampf(sample * env * volume, -1.0, 1.0) * 32000.0)
		
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_clash(f1: float, f2: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var decay := exp(-t * 12.0)
		var metallic := sin(f1 * TAU * float(i) / float(rate)) * 0.4 \
			+ sin(f2 * TAU * float(i) / float(rate)) * 0.4 \
			+ (randf() * 2.0 - 1.0) * 0.2 * exp(-t * 25.0)
		
		var val := int(clampf(metallic * decay * volume, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_chime(f1: float, f2: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var decay := exp(-t * 5.0)
		var sound := sin(f1 * TAU * float(i) / float(rate)) * 0.6 \
			+ sin(f2 * TAU * float(i) / float(rate)) * 0.4
		
		var val := int(clampf(sound * decay * volume, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_thud(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var decay := exp(-t * 15.0)
		var f := freq * (1.0 - t * 0.5)
		var sound := sin(f * TAU * float(i) / float(rate)) * 0.8 + (randf() * 2.0 - 1.0) * 0.2 * exp(-t * 20.0)
		
		var val := int(clampf(sound * decay * volume, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_click(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var decay := exp(-t * 40.0)
		var sound := sin(freq * TAU * float(i) / float(rate))
		var val := int(clampf(sound * decay * volume, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_snap(f1: float, f2: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var decay := exp(-t * 25.0)
		var sound := (randf() * 2.0 - 1.0) * 0.5 + sin(f1 * TAU * float(i) / float(rate)) * 0.5
		var val := int(clampf(sound * decay * volume, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_noise_burst(duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var env := sin(t * PI)
		var sound := (randf() * 2.0 - 1.0) * env * volume
		var val := int(clampf(sound, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)

static func _generate_glug(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var samples_count := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples_count * 2)
	
	for i in range(samples_count):
		var t := float(i) / float(samples_count)
		var f := freq + sin(t * TAU * 4.0) * 40.0
		var sound := sin(f * TAU * float(i) / float(rate)) * sin(t * PI)
		var val := int(clampf(sound * volume, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = val & 0xFF
		bytes[i * 2 + 1] = (val >> 8) & 0xFF
	
	return _create_wav(bytes, rate)
