extends SceneTree
const Net=preload("res://scripts/block_city/utility_network.gd")
const View=preload("res://scripts/block_city/utility_view.gd")
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func run() -> void:
	var center:=Net.node(Vector3i(1,0,1),Vector3i.UP,"floor")
	var links: Array=[]
	for at in [Vector3i(0,0,1),Vector3i(2,0,1),Vector3i(1,0,0)]:
		links.append_array(Net.links("pipe",[center,Net.node(at,Vector3i.UP,"floor")]))
	var network:=View.pipe_geometry(links)
	var at:=View.point(center,"pipe").snapped(Vector3.ONE*0.0001)
	check(network.nodes[at].size()==3,"Three joined paths form one real T fitting")
	var duplicate: Array=links.duplicate(true); duplicate.append_array(links)
	check(View.pipe_geometry(duplicate)==network,"Shared pipe geometry is drawn once, including retraced paths")
	var game=load("res://scripts/block_city/game.gd").new()
	game.auto_save=false; game.restore_last=false; root.add_child(game)
	var pipes:=Node3D.new(); game.add_child(pipes)
	View.draw(game,pipes,links)
	check(pipes.get_children().any(func(mesh):return mesh.get_meta("pipe_fitting","")=="tee"),"Pipe renderer displays round T junctions")
	check(pipes.get_children().filter(func(mesh):return mesh.get_meta("pipe_fitting","")=="cap").size()==3,"All three loose ends are capped")
	check(pipes.get_children().all(func(mesh):return not mesh.mesh is BoxMesh),"Pipe fittings no longer use square blocks")
	check(View.color("pipe")!=View.color("power"),"Empty metal pipes are visually distinct from electrical routes")
	check(game.utility_vent_notes.size()==7,"Vent sound contains Do Re Mi Fa Sol La Si")
	for note in game.utility_vent_notes:
		var energy:=0.0; var peak:=0
		for i in note.data.size()/2:
			var sample: int=note.data.decode_s16(i*2)
			energy+=float(sample)*sample; peak=maxi(peak,absi(sample))
		check(energy>100000 and peak<32767,"Metal sound is audible PCM without digital clipping")
		check(absi(note.data.decode_s16(note.data.size()-2))<100,"Sound tail fades without a hard click")
	game.utility_kind="vent"
	for i in 8:
		game.utility_note_time=-1000; game.play_utility_note()
		check(game.utility_audio.stream==game.utility_vent_notes[i%7],"Vent notes cycle back to Do after seven placements")
		await create_timer(0.06).timeout
	check(game.utility_notes[0].data!=game.utility_vent_notes[0].data,"Sheet-metal vent timbre differs from the softer pipe and wire tones")
	game.utility_audio.stop()
	await create_timer(0.1).timeout
	game.free()
	await create_timer(0.1).timeout
	print("Block City utility feedback: ",failures," failures")
	quit(1 if failures else 0)
