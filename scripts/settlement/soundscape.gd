extends Node3D
## Disposable presentation: observes the saved simulation, never changes it.
const Settings = preload("res://scripts/gameplay_settings.gd")
const Citizens = preload("res://scripts/settlement/citizen_lifecycle.gd")
const ActionCatalog = preload("res://scripts/gameplay_action_catalog.gd")
const ROOT := "res://assets/audio/settlement/"
const COUNTS := {"step": 6, "chop": 5, "wind": 3, "drops": 3, "rain": 3, "bell": 3}
const STEP_DB := -24.0
const CHOP_DB := -20.0
const WIND_DB := -31.0
const DROPS_DB := -29.0
const RAIN_DB := -25.0
const BELL_DB := -21.0
const VOICES := 10
const BUS := &"SoundEffects"
signal sound_played(kind: String, variation: int)
var samples := {}
var last_variant := {}
var rng := RandomNumberGenerator.new()
var listener: AudioListener3D
var voices: Array[AudioStreamPlayer3D] = []
var wind: AudioStreamPlayer
var drops: AudioStreamPlayer
var rain: AudioStreamPlayer
var bell: AudioStreamPlayer
var workers := {}
var model_id := 0
var previous_time := -1.0
var active := false
var real_time := 0.0
var rain_age := 0.0
var was_raining := false
var wind_wait := 8.0
var wind_remaining := 0.0
var wind_gain := 0.0
var drops_gain := 0.0
var rain_gain := 0.0

func _ready() -> void:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	set_volume_percent(100.0)
	rng.randomize()
	for kind: String in COUNTS:
		var variants: Array[AudioStream] = []
		for index in COUNTS[kind]:
			var path := ROOT + "%s_%02d.wav" % [kind, index + 1]
			if kind in ["step", "chop"]:
				path = ActionCatalog.DEFINITIONS[ActionCatalog.MOVE if kind == "step" else ActionCatalog.CHOP_TREE].audio_streams[index]
			var stream := load(path) as AudioStreamWAV
			if kind in ["wind", "drops", "rain"]:
				stream = stream.duplicate()
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
			variants.append(stream)
		samples[kind] = variants
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	get_viewport().audio_listener_enable_3d = true
	for index in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = BUS
		voice.unit_size = 14.0
		voice.max_distance = 55.0
		voice.max_db = 0
		voice.panning_strength = 0.65
		add_child(voice)
		voices.append(voice)
	wind = _player()
	drops = _player()
	rain = _player()
	bell = _player()

func _player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = -80
	add_child(player)
	return player

func set_volume_percent(value: float) -> void:
	var gain := clampf(value, 0.0, 100.0) / 100.0
	var bus := AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_mute(bus, is_zero_approx(gain))
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(gain, 0.0001)))

func choose_variant(kind: String) -> int:
	# Independent random state and no immediate repeat, even between rain showers.
	var count: int = COUNTS[kind]
	var previous: int = last_variant.get(kind, -1)
	var index := rng.randi_range(0, count - 2 if previous >= 0 else count - 1)
	if previous >= 0 and index >= previous:
		index += 1
	last_variant[kind] = index
	return index

func _start(player: AudioStreamPlayer, kind: String) -> void:
	var variation := choose_variant(kind)
	player.stream = samples[kind][variation]
	player.pitch_scale = rng.randf_range(0.985, 1.015) if kind == "bell" else rng.randf_range(0.96, 1.04)
	if kind != "bell":
		player.volume_db = -80
	player.play()
	sound_played.emit(kind, variation)

func reset(model) -> void:
	for voice in voices:
		voice.stop()
	for player in [wind, drops, rain, bell]:
		player.stop()
	workers.clear()
	model_id = model.get_instance_id()
	previous_time = model.time
	rain_age = 0
	was_raining = false
	wind_remaining = 0
	wind_wait = rng.randf_range(6, 16)
	wind_gain = 0
	drops_gain = 0
	rain_gain = 0
	active = false

func update(model, camera: Camera3D, focus: Vector3, delta: float, enabled: bool) -> void:
	if model_id != model.get_instance_id() or model.time < previous_time:
		reset(model)
	if not enabled:
		if active:
			reset(model)
		previous_time = model.time
		return
	if not active:
		previous_time = model.time
		active = true
	# An orthographic camera sits far away. Listen from above its visible focus,
	# with the same orientation, so nearby citizens stay quiet but audible.
	listener.global_transform = Transform3D(camera.global_basis,
		focus + camera.global_basis.z * maxf(8.0, camera.size * 0.4))
	real_time += delta
	_update_citizens(model, camera)
	var day := Settings.SIMULATION_DAY_SECONDS
	# Phase zero is sunrise; noon is one quarter of the saved 360-second day.
	if floori((model.time - day * 0.25) / day) > floori((previous_time - day * 0.25) / day):
		bell.volume_db = BELL_DB
		_start(bell, "bell")
	previous_time = model.time
	_update_weather(bool(model.weather.raining), fposmod(model.time, day) < day * 0.5, delta)

func _update_citizens(model, camera: Camera3D) -> void:
	var live := {}
	for worker: Dictionary in model.workers:
		live[worker.id] = true
		var cache: Dictionary = workers.get(worker.id, {"distance": worker.distance, "stride": 0.0,
			"step_at": 0.0, "chop_at": 0.0, "labour": 0.0, "next_chop": 0.12})
		var moved: float = worker.distance - cache.distance
		cache.distance = worker.distance
		if moved > 0.0 and moved < 3.0:
			cache.stride += moved
			var stride := 0.6 if Citizens.is_adult(worker) else 0.39
			if cache.stride >= stride:
				cache.stride = fposmod(cache.stride, stride)
				if real_time >= cache.step_at:
					_spatial("step", worker.position, STEP_DB, camera)
					cache.step_at = real_time + 0.20
		elif moved < 0 or moved >= 3.0:
			cache.stride = 0.0
		var job: Dictionary = worker.job
		if job.get("kind") == "fell" and job.get("phase") == "collect" and worker.route_index >= worker.route.size():
			var applied: float = job.labour.applied_seconds
			if applied < cache.labour:
				cache.next_chop = 0.12
			if applied >= cache.next_chop:
				cache.next_chop = applied + 0.72
				if real_time >= cache.chop_at:
					_spatial("chop", worker.position, CHOP_DB, camera)
					cache.chop_at = real_time + 0.28
			cache.labour = applied
		else:
			cache.labour = 0.0
			cache.next_chop = 0.12
		workers[worker.id] = cache
	for id in workers.keys():
		if not live.has(id):
			workers.erase(id)

func _spatial(kind: String, point: Vector3, volume: float, camera: Camera3D) -> void:
	if camera.is_position_behind(point) or listener.global_position.distance_to(point) >= 55:
		return
	var screen := camera.unproject_position(point)
	if not Rect2(Vector2.ZERO, Vector2(camera.get_viewport().size)).grow(40).has_point(screen):
		return
	for voice in voices:
		if voice.playing:
			continue
		var variation := choose_variant(kind)
		voice.stream = samples[kind][variation]
		voice.global_position = point
		voice.volume_db = volume + rng.randf_range(-1.5, 0.5)
		voice.pitch_scale = rng.randf_range(0.93, 1.07)
		voice.play()
		sound_played.emit(kind, variation)
		return

func _update_weather(raining: bool, daylight: bool, delta: float) -> void:
	if raining:
		if not was_raining:
			rain_age = 0
			_start(drops, "drops")
			_start(rain, "rain")
		rain_age += delta
	else:
		rain_age = 0
	was_raining = raining
	# A few exposed drops first, then a soft broad rain bed over ~3 real seconds.
	var wash := smoothstep(0.65, 3.2, rain_age) if raining else 0.0
	drops_gain = move_toward(drops_gain, (1.0 - wash * 0.65) if raining else 0.0, delta * 5.0)
	rain_gain = move_toward(rain_gain, wash, delta * 5.0)
	_mix(drops, drops_gain, DROPS_DB)
	_mix(rain, rain_gain, RAIN_DB)
	if daylight and not raining:
		wind_wait -= delta
		if wind_wait <= 0 and wind_remaining <= 0:
			wind_remaining = rng.randf_range(8, 14)
			wind_wait = wind_remaining + rng.randf_range(18, 42)
			_start(wind, "wind")
	else:
		wind_remaining = 0
	wind_remaining = maxf(0, wind_remaining - delta)
	var wind_target := minf(1.0, wind_remaining / 2.5) if daylight and not raining else 0.0
	wind_gain = move_toward(wind_gain, wind_target, delta * (0.4 if wind_target > 0 else 5.0))
	_mix(wind, wind_gain, WIND_DB)

func _mix(player: AudioStreamPlayer, gain: float, volume: float) -> void:
	player.volume_db = volume + linear_to_db(maxf(0.0001, gain))
	if gain <= 0.0001 and player.playing and player != rain:
		player.stop()
	if player == rain and not was_raining and gain <= 0.0001:
		player.stop()
