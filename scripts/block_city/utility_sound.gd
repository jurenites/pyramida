extends RefCounted
## Deterministic offline synthesis: soft tonal tools and a flexing sheet-metal vent.
const SCALE := [261.63,293.66,329.63,349.23,392.0,440.0,493.88]
static func notes(metal := false) -> Array:
	var result: Array=[]
	for frequency in SCALE:
		var sample:=AudioStreamWAV.new()
		sample.format=AudioStreamWAV.FORMAT_16_BITS; sample.mix_rate=22050
		var count:=7056 if metal else 4410
		var bytes:=PackedByteArray(); bytes.resize(count*2)
		var random:=RandomNumberGenerator.new(); random.seed=int(frequency*100)
		for i in count:
			var t:=float(i)/22050.0
			var attack:=minf(1.0,t/0.003)
			var value:=sin(TAU*frequency*t)*exp(-24*t)
			if metal:
				# Inharmonic panel modes, a short buckling pitch drop and dry impact.
				var phase: float=TAU*frequency*(t+0.005*(1.0-exp(-55*t)))
				value=0.0
				var modes: Array=[1.0,1.47,2.13,3.81,5.43]
				for mode in modes.size():
					value+=sin(phase*modes[mode])*exp(-t*(12+mode*7))*0.36/(1+mode*0.45)
				value+=random.randf_range(-1,1)*exp(-90*t)*0.22
			var tail:=minf(1.0,float(count-i)/220.0)
			bytes.encode_s16(i*2,int(clampf(value*attack*tail,-0.95,0.95)*24000))
		sample.data=bytes; result.append(sample)
	return result
