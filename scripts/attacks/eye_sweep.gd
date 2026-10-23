extends "res://scripts/attacks/radial_burst.gd"
## 눈알 쓸기 (크라켄, 패리 불가 = 보라): 외눈이 빛을 모았다가 광선 한 줄기를 쏘아 경기장을 한 바퀴 쓴다.
## 광선이 한 바퀴를 다 돈 뒤 동심원 하나가 이어 퍼진다 (보라 둘이 겹치지 않게, v0.124). 다가오는 광선·고리를 돌진으로 뚫는다 (퍼펙트 회피 = 완전 동조 기회)
## 예고·판정·흡수는 결계 폭풍(radial_burst.gd)과 같다

const Rings := preload("res://scripts/attacks/rings.gd")
const SWEEP := 6.0                   # 한 바퀴 도는 시간

var ring_sent := false


func _init(o: Vector2) -> void:
	super(o, 1)
	kind = "eye_beam"
	active = SWEEP
	spin = TAU / SWEEP * (1.0 if randf() < 0.5 else -1.0)


func step(dt: float, ppos: Vector2) -> void:
	boss.eye_look = end_at(_angle(0))                # 광학부가 광선 쪽을 바라본다 → 광선이 동공 중심에서 나온다
	boss.eye_look_t = boss.t
	if phase == "fire":
		boss.emit_glow_set(-4, 1.0)                  # 쏘는 동안 동공이 크게 벌어져 있다
		if not ring_sent and t >= active:            # 다 돌았다: 광선이 꺼지며 동심원 하나
			ring_sent = true
			var r = Rings.new(origin)
			r.wind = 0.3
			boss.start_side(r)
	super(dt, ppos)


func _wind_glow(k: float) -> void:
	boss.emit_glow_set(-4, k)


func _inner() -> float:
	return boss.EYE_LOOK
