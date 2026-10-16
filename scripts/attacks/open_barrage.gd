extends "res://scripts/attacks/attack.gd"
## 열림 탄막 (결계 위성): 결계가 열리면 위성이 자기 보호 탄막을 쏟아낸다 — 금색 주탄 나선(연속 패리 → 리버스 드라이브) + 사이사이 잔탄.
## 겨누지 않는다: 코어에서 ARMS 줄기가 돌며 나가고, 줄기 하나에 들어가 있으면 주탄이 GAP 마다 하나씩 닿는다 (연속 패리의 리듬).
## 결계가 닫히면 위성이 이 공격을 끊는다 (satellite._close)

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.45                   # 결계가 갈라진 뒤 첫 발까지
const ARMS := 6
const GAP := 0.45                    # 줄기마다 주탄 간격
const SPIN := 0.55                   # 나선 회전 (rad/s)
const MAIN_SPEED := 300.0
const SMALL_SPEED := 240.0
const LIFE := 6.0

var origin := Vector2.ZERO
var arms := ARMS
var spin := SPIN
var done := 0


func _init(o: Vector2, hard := false) -> void:
	kind = "open"
	origin = o
	if hard:
		arms = ARMS + 2
	spin = SPIN * (1.0 if randf() < 0.5 else -1.0)


func step(_dt: float, _ppos: Vector2) -> void:
	while t >= WIND + done * GAP:
		var m: float = boss.bolt_mult()
		var rot := spin * (WIND + done * GAP)
		for k in arms:
			var a := rot + k * TAU / arms
			var d := Vector2.from_angle(a)
			boss.shots.spawn(origin + d * boss.BARRIER_R * 0.5, d * MAIN_SPEED * m, LIFE)
			if done % 2 == 1:                         # 줄기 사이에 잔탄 (빠져나갈 길은 줄기와 줄기 사이)
				var d2 := Vector2.from_angle(a + PI / arms)
				boss.shots.spawn(origin + d2 * boss.BARRIER_R * 0.5, d2 * SMALL_SPEED * m, LIFE, 0.0, 0.0, Projectiles.Kind.SMALL)
		boss.emit(Ev.BOLT, origin)
		done += 1
