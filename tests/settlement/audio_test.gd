extends SceneTree
const Scene = preload("res://scenes/settlement/Terraces.tscn")
const Model = preload("res://scripts/settlement/world_model.gd")
const Labour = preload("res://scripts/applied_labour.gd")
var failures: Array[String] = []
var checks := 0
var events: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func count(kind: String) -> int:
	return events.count(kind)
func run() -> void:
	var game = Scene.instantiate()
	game.launch_to_menu = false
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var sound = game.soundscape
	check(sound.voices.all(func(voice): return voice.bus == sound.BUS), "All spatial effects use the sound effects bus")
	for player in [sound.wind, sound.drops, sound.rain, sound.bell]:
		check(player.bus == sound.BUS, "Ambience and bells use the sound effects bus")
	var model = game.model
	var update := func(delta: float = 0.1, enabled: bool = true): sound.update(model, game.rig.camera, game.rig.focus, delta, enabled)
	sound.sound_played.connect(func(kind, _variation): events.append(kind))
	for kind: String in sound.COUNTS:
		check(sound.samples[kind].size() >= 3, kind + " has several real sample variations")
		var hashes := {}
		for sample: AudioStreamWAV in sound.samples[kind]:
			check(sample.get_length() > 0.1 and sample.data.size() > 100, kind + " decodes as an audible-length audio stream")
			hashes[hash(sample.data)] = true
			if kind in ["rain", "wind", "drops"]:
				check(sample.loop_end > sample.mix_rate * 4, kind + " loop uses decoded frames, not compressed byte length")
		check(hashes.size() == sound.COUNTS[kind], kind + " variants contain distinct waveforms")
		var previous := -1
		for index in 25:
			var selected: int = sound.choose_variant(kind)
			check(selected != previous and selected >= 0 and selected < sound.COUNTS[kind], kind + " variation cannot repeat immediately")
			previous = selected
	var snapshot: String = JSON.stringify(model.snapshot())
	update.call()
	update.call()
	check(JSON.stringify(model.snapshot()) == snapshot, "Audio does not mutate simulation or saved state")
	check(events.is_empty(), "Stationary citizens, dry weather and initial load are silent")
	model.workers[0].distance += 0.7
	update.call(0.25)
	check(count("step") == 1, "Actual travel triggers a quiet footstep")
	update.call(0.25)
	check(count("step") == 1, "Idle frames do not generate footsteps")
	model.workers[0].distance += 0.7
	update.call(0.01)
	model.workers[0].distance += 0.7
	update.call(0.01)
	check(count("step") == 2, "Fast simulation does not machine-gun footsteps")
	model.workers[2].distance += 0.4
	update.call(0.25)
	check(count("step") == 3, "Children also have appropriately spaced footsteps")
	var labour := Labour.new(3)
	labour.apply(0, 0.2)
	model.workers[0].job = {"kind": "fell", "phase": "collect", "labour": labour}
	model.workers[0].route = []
	update.call(0.3)
	check(count("chop") == 1, "Working on a tree triggers a wood impact")
	update.call(0.3)
	check(count("chop") == 1, "Stalled labour does not trigger phantom chopping")
	labour.apply(0, 0.9)
	update.call(0.3)
	check(count("chop") == 2, "Further chopping produces another impact")
	model.workers[0].job.phase = "store"
	update.call(0.3)
	check(count("chop") == 2, "Carrying timber does not play chopping")
	model.weather.raining = true
	update.call(0.1)
	check(sound.drops_gain > 0 and sound.rain_gain == 0, "Rain begins with individual droplets")
	for frame in 35:
		update.call(0.1)
	check(sound.rain_gain > 0.95 and sound.drops_gain < 0.4, "Droplets recede beneath a gentle white-noise rain bed")
	check(count("rain") == 1 and count("drops") == 1, "Rain loops continuously without restarting each frame")
	model.weather.raining = false
	update.call(0.25)
	check(not sound.rain.playing and not sound.drops.playing, "Rain audio ends when saved weather stops raining")
	model.time = 200
	sound.wind_wait = 0
	update.call()
	check(count("wind") == 0, "Daytime wind does not begin at night")
	model.time = 360
	update.call()
	check(count("wind") == 1 and sound.wind_gain > 0, "A scheduled quiet gust starts in daylight")
	model.weather.raining = true
	update.call(0.25)
	check(not sound.wind.playing, "Wind yields to rain ambience")
	model.weather.raining = false
	model.time = 449.9
	update.call()
	var bells_before := count("bell")
	model.time = 450.1
	update.call()
	update.call()
	check(count("bell") == bells_before + 1, "Crossing noon rings once, including a fast-frame crossing")
	model.time = 810.1
	update.call()
	check(count("bell") == bells_before + 2, "Following day has its own noon bell")
	update.call(0.1, false)
	check(not sound.bell.playing and not sound.wind.playing and not sound.rain.playing, "Menus and structure editor silence ambience and bell")
	check(sound.voices.all(func(voice): return not voice.playing), "Menus stop all citizen sounds")
	model.time = 1170.1
	update.call(0.1, false)
	update.call()
	check(count("bell") == bells_before + 2, "Resuming does not replay missed noon bells")
	var loaded = Model.new()
	loaded.setup()
	loaded.time = 1530.1
	sound.update(loaded, game.rig.camera, game.rig.focus, 0.1, true)
	check(count("bell") == bells_before + 2, "Loading another settlement after noon does not ring retroactively")
	check(sound.workers.size() == loaded.workers.size(), "Changing settlements rebuilds disposable audio caches")
	# Verify the real audio graph, not only dispatch: spatial playback must reach Master.
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	for voice in sound.voices:
		voice.stop()
	sound._spatial("chop", loaded.workers[0].position, sound.CHOP_DB, game.rig.camera)
	await create_timer(0.4).timeout
	var peak := captured_peak(capture)
	check(peak > 0.00001 and peak < 0.15, "Spatial sound reaches the real mixer at a quiet, unclipped level")
	sound.reset(loaded)
	await create_timer(0.12).timeout
	for kind in ["wind", "drops", "rain", "bell"]:
		var player: AudioStreamPlayer = sound.get(kind)
		sound._start(player, kind)
		player.volume_db = -25
		if kind != "bell":
			# Cross the seam and sample after it: compressed ambient loops must stay audible.
			player.seek(player.stream.get_length() - 0.05)
			await create_timer(0.12).timeout
		capture.clear_buffer()
		await create_timer(0.15).timeout
		peak = captured_peak(capture)
		check(peak > 0.000001 and peak < 0.15, kind + " plays through the real mixer, including ambient loop boundaries")
		player.stop()
		await create_timer(0.08).timeout
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	sound.reset(loaded)
	# Let the audio thread release stopped playback before shutting the test tree down.
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d sample variation, movement, work, weather, noon and mixer checks" % checks)
		quit()
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func captured_peak(capture: AudioEffectCapture) -> float:
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame: Vector2 in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak
