extends SceneTree
const Economy=preload("res://scripts/block_city/economy_lab_model.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func fund(m, action: Callable) -> void:
	for attempt in 80:
		if action.call(): return
		if m.error!="cash" or m.forecast().net<=0:
			check(false,"Cannot recover while funding: "+m.error); return
		m.advance()
	check(false,"Funding stalled")
func connect_floor(m, level: int) -> void:
	for kind in Economy.NETWORKS: fund(m,func(): return m.connect_pipe(level-1,level,kind))
func scenario(style: String) -> Dictionary:
	var m=Economy.new()
	if style=="creative": m.reset("creative")
	var phases := []
	for level in 3:
		if level>0: fund(m,func(): return m.add_floor())
		if style in ["gardener","wandering"]:
			var spot := Vector2i(2,2) if level%2==1 else Vector2i.ZERO
			if spot!=m.bath_slot(level): check(m.move_bath(level,spot),"Offset bathroom before fitting rooms")
		connect_floor(m,level)
		var slots := []
		for z in [0,2]:
			for x in 3:
				if Vector2i(x,z)!=m.bath_slot(level): slots.append(Vector2i(x,z))
		var homes := 3 if style=="gardener" else 4
		for index in slots.size():
			var kind := "home" if index<homes else "garden"
			fund(m,func(): return m.build(level,slots[index],kind))
		if level==1: fund(m,func(): return m.buy_upgrade("capacity"))
		m.advance()
		check(m.cash>=0,"Style stays solvent: "+style)
		check(m.forecast().net>0,"Every occupied phase has a positive operating margin: "+style)
		phases.append({"floors":level+1,"month":m.month,"residents":m.residents(),"cash":m.cash,"surplus":m.forecast().net})
	var report := m.forecast()
	var finish: int = m.month
	for i in 12: m.advance()
	check(m.residents()<=int(m.config.district_demand),"No population beyond available demand")
	return {"style":style,"phases":phases,"residents":m.residents(),"build_months":finish,"capital":m.asset_value(),"pipe_length":snappedf(m.pipe_total(),0.1),"income":report.income,"upkeep":report.upkeep,"surplus":report.net,"cash_after_12_more_months":m.cash}
func run() -> void:
	var m=Economy.new()
	check(m.residents()==0 and m.cash==150,"Grant is paid once on a fresh plot")
	check(m.build(0,Vector2i(1,0)),"Place first home")
	var unserved := m.snapshot()
	m.advance()
	check(m.residents()==0 and m.cash==unserved.cash,"Unconnected home earns nothing and cannot bankrupt an empty town")
	check(m.connect_pipe(-1,0,"water"),"Connect street water")
	m.advance(); check(m.residents()==0,"Water without sewage is not a serviced home")
	check(m.connect_pipe(-1,0,"sewer"),"Connect street sewer")
	var before := m.snapshot()
	m.advance(); check(m.residents()==2 and m.last_income==8,"Both services allow move-in and rent")
	check(m.undo() and m.snapshot()==before,"Undo reverses residents, month, income and cash together")
	m.advance()
	check(m.add_floor(),"Add supported floor shell")
	check(not m.connect_pipe(1,0,"sewer") and not m.connect_pipe(0,0,"water"),"Reject uphill/backward and cyclic service connections")
	check(m.connect_pipe(0,1,"sewer") and m.connect_pipe(0,1,"water"),"Link upper floor to lower wet stack")
	check(m.build(1,Vector2i(1,0)),"Build upper home")
	m.advance(); check(m.residents()==4,"Shared stack serves both floors")
	var full := m.snapshot()
	check(m.disconnect_pipe(0,"sewer"),"Disconnect street drain")
	check(m.allocations().is_empty(),"Broken shared trunk disables all downstream drainage")
	m.advance(); check(m.residents()==4 and m.last_income==0,"First outage month keeps residents, stops rent")
	m.advance(); check(m.residents()==0,"Prolonged outage moves people out without death or fines")
	m.restore(full)
	var money: float = m.cash
	var length := m.pipe_total()
	check(m.move_bath(1,Vector2i(2,2)),"Offset wet room remains legal")
	check(m.pipe_total()>length and m.cash<money,"Offset routes cost extra pipe and bends")
	check(m.move_bath(1,Vector2i.ZERO) and is_equal_approx(m.cash,money),"Move-away/move-back cannot mint money")
	for floor in m.floors.size():
		var points: Array[Vector3]=m.route(floor)
		for i in range(1,points.size()): check(points[i].y<=points[i-1].y,"Drain always descends")
	var saved := m.snapshot()
	m.cash=0
	var poor := m.snapshot()
	check(not m.build(1,Vector2i(2,0)) and m.snapshot()==poor,"Unfunded edits roll back atomically")
	m.restore(saved)
	check(not m.connect_pipe(-1,0,"water"),"Duplicate connection cannot charge twice")
	var stable := m.snapshot()
	check(not m.move_bath(0,Vector2i(1,0)) and m.snapshot()==stable,"Cannot move a bathroom onto an occupied home")
	check(not m.build(0,Vector2i(1,1)),"Keep corridor and stair circulation clear")
	var original := m.snapshot()
	check(m.build(0,Vector2i(2,2),"garden"),"Garden is a money sink")
	check(m.remove(0,Vector2i(2,2)),"Renovation refund")
	check(is_equal_approx(m.cash,original.cash),"Build/salvage loops cannot mint money")
	check(m.cash>=0 and is_equal_approx(m.cash,float(m.config.starting_cash)+m.earned-m.expenses-m.spent),"Ledger conserves every unit of money")
	# Test the economy's accounting invariants under messy, reversible play.
	for seed in 32:
		var trial=Economy.new()
		trial.config.starting_cash=5000.0; trial.reset()
		var rng:=RandomNumberGenerator.new(); rng.seed=seed
		for step in 80:
			var level:=rng.randi_range(0,trial.floors.size()-1)
			var slot:=Vector2i(rng.randi_range(0,2),rng.randi_range(0,1)*2)
			match rng.randi_range(0,8):
				0: trial.build(level,slot,"home")
				1: trial.build(level,slot,"garden")
				2: trial.remove(level,slot)
				3: trial.move_bath(level,slot)
				4: trial.connect_pipe(level-1,level,"water" if step%2 else "sewer")
				5: trial.disconnect_pipe(level,"water" if step%2 else "sewer")
				6: trial.add_floor()
				7: trial.advance()
				8: trial.undo()
			check(trial.cash>=0 and is_equal_approx(trial.cash,float(trial.config.starting_cash)+trial.earned-trial.expenses-trial.spent),"Random-play money ledger is conserved")
			check(is_equal_approx(trial.spent,trial.asset_value()),"Refunds equal actual assets; layouts cannot mint money")
			check(trial.forecast().net>=0,"Messy pipe layouts do not trigger a service-debt spiral")
			for floor in trial.floors.size():
				var route: Array[Vector3]=trial.route(floor)
				for i in range(1,route.size()): check(route[i].y<=route[i-1].y,"Every generated sewage segment descends")
	var sparse=Economy.new(); sparse.config.starting_cash=1000.0; sparse.reset()
	for level in 3:
		if level>0: sparse.add_floor()
		sparse.move_bath(level,Vector2i(2,2) if level%2 else Vector2i.ZERO)
		connect_floor(sparse,level)
	sparse.buy_upgrade("lift"); sparse.build(2,Vector2i(1,0)); sparse.advance()
	check(sparse.forecast().net>0,"A lone upper-floor household can afford the longest stack and elevator")
	var recovery=Economy.new()
	recovery.add_floor(); recovery.add_floor(); recovery.buy_upgrade("lift"); recovery.buy_upgrade("capacity")
	check(recovery.cash<51,"Reproduce a budget trapped in premature infrastructure")
	var trapped: Dictionary=recovery.snapshot()
	check(recovery.remove_floor(),"Top floor can be refunded to recover a working budget")
	check(recovery.build(0,Vector2i(1,0)) and recovery.connect_pipe(-1,0,"water") and recovery.connect_pipe(-1,0,"sewer"),"Refunded infrastructure pays for a complete serviced home")
	recovery.advance(); check(recovery.forecast().net>0,"Recovery restarts positive income without a bailout currency")
	recovery.restore(trapped)
	check(recovery.remove_upgrade("lift") and recovery.remove_upgrade("capacity"),"Both permanent upgrades are recoverable capital")
	check(is_equal_approx(recovery.spent,recovery.asset_value()),"Upgrade refunds conserve assets and money")
	var reports := []
	for style in ["aligned","wandering","gardener","creative"]: reports.append(scenario(style))
	check(reports[1].capital>reports[0].capital and reports[1].upkeep>reports[0].upkeep,"Offsets have a measurable, bounded cost")
	check(reports[2].surplus>0 and reports[2].residents==18,"Garden-heavy layout is financially viable without maximizing density")
	check(reports[0].residents==24,"Efficient layout can serve maximum district demand")
	var file := FileAccess.open("res://artifacts/block_city/economy-balance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t")); file.close()
	print(JSON.stringify(reports))
	print("Economy lab: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
