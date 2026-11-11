extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,1000)
 var demo=preload("res://scripts/settlement/modular_house_prototype.gd").new(); root.add_child(demo)
 demo.animate=false; demo.time_mode=1
 assert(demo.buttons.upgrade.visible and demo.buttons.upgrade.disabled)
 var report := {"layouts":[],"prototype_utilities":{"stove":1,"exhaust":1,"lantern":2,"socket":1,"grid_terminal":1,"material_supply":1},"decorative_props":0}
 for seed_ in [0,1,2,4]:
  demo.variant=seed_; demo.exemplars=demo.View.Exemplars.record(seed_); demo.rebuild()
  for frame in 12: await process_frame
  assert(not demo.state.blocked)
  var counts: Dictionary=demo.View.Exemplars.inventory(demo.structure)
  counts.merge({"seed":seed_,"rooms":demo.records.size(),"terrace_m2":demo.Rules.terrace_tiles(demo.records).size(),"room_lamps":demo.records.size(),"exemplar_save_bytes":JSON.stringify(demo.exemplars).to_utf8_buffer().size()})
  report.layouts.append(counts)
  root.get_texture().get_image().save_png("res://artifacts/settlement/modular-layout-%d.png" % seed_)
 demo.section=1; demo.rebuild()
 for room in demo.structure.get_children():
  if str(room.name).begins_with("Room"): assert(room.find_children("*","OmniLight3D",true,false).is_empty())
 for frame in 12: await process_frame
 root.get_texture().get_image().save_png("res://artifacts/settlement/modular-dollhouse.png")
 demo.section=0; demo.rebuild()
 demo._activate_service("supply"); demo._activate_service("supply"); demo._action("upgrade")
 assert(demo.services.tier==1 and not demo.state.blocked)
 for frame in 12: await process_frame
 root.get_texture().get_image().save_png("res://artifacts/settlement/modular-layout-metal.png")
 demo.time_mode=2; demo.rebuild()
 for frame in 12: await process_frame
 root.get_texture().get_image().save_png("res://artifacts/settlement/modular-layout-night.png")
 demo.services.advance(100); demo._lighting(0)
 assert(demo.services.brightness()==0)
 demo._activate_service("socket"); assert(demo.services.brightness()==1)
 demo.rig.zoom=55; demo.rig.update_camera()
 for frame in 12: await process_frame
 report.far=demo.View.Exemplars.inventory(demo.structure)
 root.get_texture().get_image().save_png("res://artifacts/settlement/modular-layout-distant.png")
 var output:=FileAccess.open("res://artifacts/settlement/modular-object-inventory.json",FileAccess.WRITE); output.store_string(JSON.stringify(report,"\t")); output.close()
 print("PASS: generated layouts, stock inventory, light connection, upgrade and distance detail")
 quit()
