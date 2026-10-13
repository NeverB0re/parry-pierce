extends Node
## 에셋 없이 효과음을 합성한다(AudioStreamWAV, 16bit mono).

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["parry"] = _build(0.45, func(t: float) -> float:
		return (sin(TAU * 1250.0 * t) * 0.5 + sin(TAU * 1870.0 * t) * 0.35 + sin(TAU * 2630.0 * t) * 0.25) * exp(-t * 9.0) * 0.55 \
			+ randf_range(-1, 1) * exp(-t * 60.0) * 0.6)
	streams["perfect"] = _build(0.8, func(t: float) -> float:
		return (sin(TAU * 1250.0 * t) * 0.45 + sin(TAU * 1870.0 * t) * 0.3 + sin(TAU * 3300.0 * t) * 0.25) * exp(-t * 6.0) * 0.5 \
			+ sin(TAU * (75.0 - 30.0 * t) * t) * exp(-t * 5.0) * 0.8 + randf_range(-1, 1) * exp(-t * 40.0) * 0.7)
	streams["deflect"] = _build(0.22, func(t: float) -> float:     # 근접공격 패리: 피해 없이 튕겨냄 → 맑은 울림 없는 둔탁한 금속음
		return (sin(TAU * 340.0 * t) * 0.5 + sin(TAU * 515.0 * t) * 0.35) * exp(-t * 26.0) * 0.7 			+ randf_range(-1, 1) * exp(-t * 45.0) * 0.45)
	streams["armor"] = _build(0.3, func(t: float) -> float:
		return sin(TAU * 130.0 * t) * exp(-t * 18.0) * 0.8 + randf_range(-1, 1) * exp(-t * 35.0) * 0.5 \
			+ sin(TAU * 900.0 * t) * exp(-t * 25.0) * 0.2)
	streams["break"] = _build(0.5, func(t: float) -> float:
		return randf_range(-1, 1) * exp(-t * 9.0) * 0.6 + sin(TAU * (220.0 - 150.0 * t) * t) * exp(-t * 8.0) * 0.6)
	streams["stomp"] = _build(0.9, func(t: float) -> float:
		return sin(TAU * (50.0 - 15.0 * t) * t) * exp(-t * 4.0) + randf_range(-1, 1) * exp(-t * 12.0) * 0.35)
	streams["hurt"] = _build(0.35, func(t: float) -> float:
		var ph := TAU * 420.0 * t * exp(-t * 3.0)
		return (fmod(ph, TAU) / PI - 1.0) * exp(-t * 7.0) * 0.4 + randf_range(-1, 1) * exp(-t * 30.0) * 0.3)
	streams["dash"] = _build(0.18, func(t: float) -> float:
		return randf_range(-1, 1) * sin(PI * t / 0.18) * 0.3)
	streams["bolt"] = _build(0.25, func(t: float) -> float:
		return sin(TAU * 660.0 * t + 3.0 * sin(TAU * 30.0 * t)) * exp(-t * 10.0) * 0.3)
	streams["land"] = _build(0.3, func(t: float) -> float:
		return sin(TAU * 80.0 * t) * exp(-t * 10.0) * 0.6 + randf_range(-1, 1) * exp(-t * 30.0) * 0.3)
	streams["win"] = _build(2.5, func(t: float) -> float:
		return (sin(TAU * 220.0 * t) + sin(TAU * 277.2 * t) + sin(TAU * 329.6 * t) + sin(TAU * 440.0 * t)) * exp(-t * 1.2) * 0.18 \
			+ sin(TAU * (60.0 - 20.0 * t) * t) * exp(-t * 3.0) * 0.7)


func play(name: String, db := 0.0, pitch_jitter := 0.06) -> void:
	if not streams.has(name):
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func _build(dur: float, gen: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := clampf(gen.call(float(i) / RATE), -1.0, 1.0)
		# 끝부분 클릭 방지 페이드
		s *= minf(1.0, float(n - i) / (RATE * 0.01))
		data.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
