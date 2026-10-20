extends Node
## 에셋 없이 효과음을 합성한다(AudioStreamWAV, 16bit mono). 체계: docs/SOUND.md
##   보상(쾌감) = 크고 선명하고 높은 소리 (맑은 금속음·차임·상승음)  — parry, perfect, hit_drive, hit_perfect, sync, crack, open, heal, charged
##   실패·막힘   = 둔탁하거나 튕겨 나는 소리 (낮은 퉁·텅, 울림 없음)   — deflect, hurt, graze
##   이동·회피   = 쉬익 하는 바람 소리 (걸러진 잡음이 쓸고 지나감)       — dash, dash_big
##   중립 타격   = 짧고 가벼운 타격 (보상보다 작게)                     — hit_light, hit_charge
##   적          = 낮거나 기계적인 소리 (플레이어 보상음과 겹치지 않게)  — bolt, beam, stomp, break, land
## 배경음악은 music.gd (따로)

const RATE := 22050

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	# ── 보상: 크고 선명하고 높게 ──
	streams["parry"] = _build(0.45, func(t: float) -> float:            # 패리 성공: 맑은 금속 차임
		return (sin(TAU * 1250.0 * t) * 0.5 + sin(TAU * 1870.0 * t) * 0.35 + sin(TAU * 2630.0 * t) * 0.25) * exp(-t * 9.0) * 0.55 \
			+ randf_range(-1, 1) * exp(-t * 60.0) * 0.6)
	streams["perfect"] = _build(0.8, func(t: float) -> float:           # PERFECT: 높은 차임 + 낮은 붐
		return (sin(TAU * 1250.0 * t) * 0.45 + sin(TAU * 1870.0 * t) * 0.3 + sin(TAU * 3300.0 * t) * 0.25) * exp(-t * 6.0) * 0.5 \
			+ sin(TAU * (75.0 - 30.0 * t) * t) * exp(-t * 5.0) * 0.8 + randf_range(-1, 1) * exp(-t * 40.0) * 0.7)
	streams["hit_drive"] = _build(0.42, func(t: float) -> float:        # 일반 패리 드라이브 적중: 밝게 쨍 (작지만 '맞았다')
		return (sin(TAU * 2200.0 * t) * 0.4 + sin(TAU * 3150.0 * t) * 0.25) * exp(-t * 16.0) \
			+ sin(TAU * 560.0 * t) * exp(-t * 11.0) * 0.45 + randf_range(-1, 1) * exp(-t * 70.0) * 0.5)
	streams["hit_perfect"] = _build(1.0, func(t: float) -> float:       # PERFECT·완전 동조 일격: 큰 붐 + 높은 쨍 + 잔향
		return sin(TAU * (95.0 - 45.0 * t) * t) * exp(-t * 3.5) * 0.9 \
			+ (sin(TAU * 2600.0 * t) * 0.35 + sin(TAU * 3900.0 * t) * 0.22 + sin(TAU * 1300.0 * t) * 0.25) * exp(-t * 4.5) \
			+ randf_range(-1, 1) * exp(-t * 22.0) * 0.55)
	streams["sync"] = _build(0.75, func(t: float) -> float:             # 완전 동조(청록): 빠르게 오르는 3화음 반짝임
		var s := 0.0
		for k in 3:
			var st := k * 0.045
			if t >= st:
				var f: float = [1568.0, 2093.0, 2637.0][k]
				s += sin(TAU * f * (t - st)) * exp(-(t - st) * 6.0) * 0.32
		return s + sin(TAU * 5274.0 * t) * exp(-t * 12.0) * 0.08)
	streams["crack"] = _build(0.55, func(t: float) -> float:            # 결계·장갑에 금: 유리가 갈라지는 밝은 파열 + 낮은 받침
		return randf_range(-1, 1) * exp(-t * 14.0) * 0.45 + sin(TAU * 3200.0 * t) * exp(-t * 10.0) * 0.28 \
			+ sin(TAU * 4700.0 * t) * exp(-t * 13.0) * 0.18 + sin(TAU * 160.0 * t) * exp(-t * 9.0) * 0.45)
	streams["open"] = _build(0.9, func(t: float) -> float:              # 열림·코어 노출: 위로 쓸어 올리는 밝은 상승음
		var ph := TAU * (300.0 * t + 700.0 * t * t)
		return (sin(ph) * 0.35 + sin(ph * 2.0) * 0.15) * sin(PI * clampf(t / 0.9, 0.0, 1.0)) + randf_range(-1, 1) * exp(-t * 30.0) * 0.3)
	streams["heal"] = _build(0.28, func(t: float) -> float:             # 긁힘 치료: 부드러운 높은 두 음
		return (sin(TAU * 1320.0 * t) + sin(TAU * 1760.0 * t) * 0.7) * exp(-t * 11.0) * 0.28)
	streams["charged"] = _build(0.22, func(t: float) -> float:          # 차지 완료: 올라가는 두 음 '띵-딩'
		var f := 880.0 if t < 0.06 else 1320.0
		return sin(TAU * f * t) * exp(-fmod(t, 0.06) * 10.0) * 0.32)
	# ── 실패·막힘: 둔탁하게 ──
	streams["deflect"] = _build(0.24, func(t: float) -> float:          # 막힘 (방어막에 튕김·근접 패리): 낮게 '텅', 울림 없음
		return sin(TAU * (190.0 - 70.0 * t) * t) * exp(-t * 18.0) * 0.7 + sin(TAU * 410.0 * t) * exp(-t * 30.0) * 0.25 \
			+ randf_range(-1, 1) * exp(-t * 55.0) * 0.25)
	streams["hurt"] = _build(0.35, func(t: float) -> float:
		var ph := TAU * 420.0 * t * exp(-t * 3.0)
		return (fmod(ph, TAU) / PI - 1.0) * exp(-t * 7.0) * 0.4 + randf_range(-1, 1) * exp(-t * 30.0) * 0.3)
	streams["graze"] = _build(0.2, func(t: float) -> float:             # 잔탄 긁힘: 치익 (작은 실패)
		return randf_range(-1, 1) * exp(-t * 16.0) * 0.3 * (0.6 + 0.4 * sin(TAU * 90.0 * t)) + sin(TAU * 260.0 * t) * exp(-t * 25.0) * 0.2)
	# ── 이동·회피: 쉬익 ──
	streams["dash"] = _whoosh(0.22, 900.0, 3200.0, 0.55)
	streams["dash_big"] = _whoosh(0.34, 500.0, 4200.0, 0.75)
	# ── 중립 타격 ──
	streams["hit_light"] = _build(0.14, func(t: float) -> float:         # 일반 돌진 적중·반사탄: 짧은 '틱'
		return sin(TAU * 1800.0 * t) * exp(-t * 40.0) * 0.3 + randf_range(-1, 1) * exp(-t * 80.0) * 0.3)
	streams["hit_charge"] = _build(0.32, func(t: float) -> float:        # 차지 강습 적중: 단단한 '쿵-챙'
		return sin(TAU * 300.0 * t) * exp(-t * 14.0) * 0.6 + sin(TAU * 1500.0 * t) * exp(-t * 16.0) * 0.32 \
			+ randf_range(-1, 1) * exp(-t * 40.0) * 0.4)
	# ── 적 ──
	streams["break"] = _build(0.5, func(t: float) -> float:
		return randf_range(-1, 1) * exp(-t * 9.0) * 0.6 + sin(TAU * (220.0 - 150.0 * t) * t) * exp(-t * 8.0) * 0.6)
	streams["stomp"] = _build(0.9, func(t: float) -> float:
		return sin(TAU * (50.0 - 15.0 * t) * t) * exp(-t * 4.0) + randf_range(-1, 1) * exp(-t * 12.0) * 0.35)
	streams["bolt"] = _build(0.25, func(t: float) -> float:
		return sin(TAU * 660.0 * t + 3.0 * sin(TAU * 30.0 * t)) * exp(-t * 10.0) * 0.3)
	streams["beam"] = _build(0.6, func(t: float) -> float:               # 패리 불가 발사: 낮게 웅웅거리는 전기음
		var saw := fmod(110.0 * t, 1.0) * 2.0 - 1.0
		return (saw * 0.35 + randf_range(-1, 1) * 0.15) * (0.7 + 0.3 * sin(TAU * 18.0 * t)) * minf(1.0, t * 30.0) * exp(-t * 3.5))
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
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		buf[i] = gen.call(float(i) / RATE)
	return _wav(buf)


## 쉬익: 잡음을 한 극 저역 통과 필터로 거르며 차단 주파수를 f0 → f1 로 올려 쓸고 지나가는 바람 소리
func _whoosh(dur: float, f0: float, f1: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / n
		var fc := lerpf(f0, f1, t * t)
		var a := 1.0 - exp(-TAU * fc / RATE)
		lp += (randf_range(-1, 1) - lp) * a
		lp2 += (lp - lp2) * a
		buf[i] = lp2 * sin(PI * t) * gain * 1.8
	return _wav(buf)


func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := clampf(buf[i], -1.0, 1.0)
		s *= minf(1.0, float(n - i) / (RATE * 0.01))    # 끝부분 클릭 방지 페이드
		data.encode_s16(i * 2, int(s * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
