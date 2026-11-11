extends RefCounted
## The same rigid stock positions drive visible cargo and passage clearance.
const Timber=preload("res://scripts/settlement/timber_kit.gd")
const RESOURCES=["food","grain","plank","stone","block","pottery","flour","clay","brick","ore","imbrex"]
static func log_pose(kind: String,index: int) -> Transform3D:
	var pose:=Transform3D.IDENTITY
	pose.origin=Vector3(0,0.18+floori(index/4.0)*Timber.LOG_DIAMETER,-0.42+(index%4)*(Timber.LOG_DIAMETER+0.04))
	if kind=="log_shed":
		pose.basis=Basis(Vector3.UP,PI/2)
		pose.origin=Vector3((index%3-1)*Timber.LOG_DIAMETER,0.10+floori(index/6.0)*Timber.LOG_DIAMETER,(-1 if index%6<3 else 1)*(Timber.LOG_LENGTH+0.002)*0.5)
	if kind=="house":
		pose.basis=Basis(Vector3.UP,PI/2)
		pose.origin=Vector3(-0.65+(index%2)*Timber.LOG_DIAMETER,0.04+floori(index/2.0)*Timber.LOG_DIAMETER,-0.15)
	return pose
static func cargo_pose(kind: String,resource: String,slot: int) -> Transform3D:
	var pose:=Transform3D(Basis.from_scale(Vector3.ONE*0.7),Vector3((slot%3-1)*0.42,0.15+floori(slot/6.0)*0.28,(floori(slot/3.0)%2-0.5)*0.48))
	if kind=="stone_storage": pose.origin=Vector3((slot%4-1.5)*0.57,0.18+floori(slot/16.0)*0.35,(floori(slot/4.0)%4-1.5)*0.57)
	if kind=="hay_barn": pose.origin=Vector3(0,0.15+floori(slot/3.0)*0.25,(slot%3-1)*0.55)
	if kind in ["goods_rack","small_warehouse"]:
		pose.basis=Basis.from_scale(Vector3.ONE*0.42)
		pose.origin=Vector3(-0.20+(slot%2)*0.40,0.14+floori(slot/4.0)*0.34,-0.20+(floori(slot/2.0)%2)*0.38)
	if resource=="plank":
		pose.basis=Basis(Vector3.UP,PI/2)
		pose.origin=Vector3((slot%3-1)*0.25,0.14+floori(slot/3.0)*0.20,0)
	if kind=="house": pose.origin=Vector3(0.45,0.08+floori(slot/2.0)*0.22,-0.35+(slot%2)*0.60)
	return pose
