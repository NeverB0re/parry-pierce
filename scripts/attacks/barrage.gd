extends "res://scripts/attacks/attack.gd"
## 크라켄 탄막 (사방에서 쏜다): 촉수 끝·배경 다리·분사구가 모두 발사점이다.
##  tips = 촉수 끝 일제 사격 — 몇 곳이 차례로 플레이어를 겨눠 부채꼴을 쏜다 (2바퀴)
##  ring = 분사구에서 동심 고리 — 한 줄 걸러 반 칸씩 어긋난다 (고리 사이로 빠져나간다)
##  cross = 양쪽 가장자리에서 서로 엇갈리게 휘두르는 탄 줄기
## 탄은 모두 패리할 수 있다 (주탄 = 리버스 드라이브).
## boss 에 필요한 것: emitters() → [[번호, 위치], ...], emitter_pos(번호) (못 쓰면 Vector2.INF), set_glow(c, v), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.8
const SMALL_SPEED := 290.0
const MAIN_SPEED := 350.0
const C_WARN := Color(1.0, 0.3, 0.25)

# tips
const TIPS_MAX := 4
const TIPS_GAP := 0.32               # 발사점 사이 간격
const TIPS_ROUNDS := 2
const TIPS_SPREAD := 0.26
const TIPS_N := 5
# ring
const RING_N := 20
const RING_COUNT := 4
const RING_GAP := 0.7
const RING_SPEED := 240.0
# cross
const CROSS_TIME := 2.6
const CROSS_RATE := 0.13
const CROSS_SWEEP := 0.55

var mode := "tips"
var hard := false
var ids: Array[int] = []             # tips: 쏘는 발사점 번호 순서 / cross: [왼쪽, 오른쪽]
var done := 0                        # 쏜 횟수 (tips: 발사점 × 바퀴, ring: 고리 수, cross: 줄기 탄 수)
var base := 0.0                      # cross: 줄기 중심 각 (왼쪽 기준, 오른쪽은 반대편)
var spin := 1.0
var lanes: Array = []                # 예고선 그리기용 [from, to]


func _init(m: String, em: Array, ppos: Vector2, hard_ := false) -> void:
	kind = m
	mode = m
	hard = hard_
	spin = 1.0 if randf() < 0.5 else -1.0
	match m:
		"tips":
			var tips := em.filter(func(e): return int(e[0]) >= 0)
			tips.shuffle()
			var n := mini(TIPS_MAX + (1 if hard else 0), tips.size())
			for k in n:
				ids.append(int(tips[k][0]))
		"cross":
			var l = null
			var r = null
			for e in em:
				if int(e[0]) < 0:
					continue
				var p: Vector2 = e[1]
				if p.x < 0.0 and (l == null or p.x < (l[1] as Vector2).x):
					l = e
				if p.x > 0.0 and (r == null or p.x > (r[1] as Vector2).x):
					r = e
			if l != null:
				ids.append(int(l[0]))
			if r != null:
				ids.append(int(r[0]))
			base = 0.0
	if ids.is_empty() and m != "ring":
		kind = "ring"
		mode = "ring"


func step(_dt: float, ppos: Vector2) -> void:
	match mode:
		"tips":
			_tips(ppos)
		"cross":
			_cross(ppos)
		_:
			_ring(ppos)


func _fire_fan(id: int, ppos: Vector2) -> void:
	var o: Vector2 = boss.emitter_pos(id)
	if o == Vector2.INF:
		return
	var m: float = boss.bolt_mult()
	var a := (ppos - o).angle()
	var half := TIPS_N / 2
	for k in TIPS_N:
		var ang := a + (k - half) * TIPS_SPREAD
		if k == half:
			boss.shots.spawn(o, Vector2.from_angle(ang) * MAIN_SPEED * m, 9.0)
		else:
			boss.shots.spawn(o, Vector2.from_angle(ang) * SMALL_SPEED * m, 9.0, 0.0, 0.0, Projectiles.Kind.SMALL)
	boss.emit(Ev.BOLT, o)
	boss.set_glow(id, 1.0)


func _tips(ppos: Vector2) -> void:
	var total := ids.size() * TIPS_ROUNDS
	lanes.clear()
	for k in ids.size():                                  # 예고: 발사점이 순서대로 달아오른다
		var at := WIND + k * TIPS_GAP
		var o: Vector2 = boss.emitter_pos(ids[k])
		if o == Vector2.INF:
			continue
		if done < ids.size():
			boss.set_glow(ids[k], clampf((t - (at - 0.5)) / 0.5, 0.0, 1.0))
		if done <= k:
			lanes.append([o, o + (ppos - o).normalized() * 700.0])
	while done < total:
		var k := done % ids.size()
		var round_ := done / ids.size()
		var at := WIND + k * TIPS_GAP + round_ * (ids.size() * TIPS_GAP + 0.5)
		if t < at:
			break
		_fire_fan(ids[k], ppos)
		done += 1
	if done >= total:
		boss.finish_attack()


func _ring(_ppos: Vector2) -> void:
	var o: Vector2 = boss.emitter_pos(-1)
	boss.set_glow(-1, minf(1.0, t / WIND))
	var m: float = boss.bolt_mult()
	while done < RING_COUNT and t >= WIND + done * RING_GAP:
		var off := (0.5 if done % 2 == 1 else 0.0) * TAU / RING_N + spin * 0.12 * done
		for k in RING_N:
			var a := off + k * TAU / RING_N
			var v := Vector2.from_angle(a) * RING_SPEED * m
			if k % 5 == 0:
				boss.shots.spawn(o, v * 1.15, 10.0)
			else:
				boss.shots.spawn(o, v, 10.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		boss.emit(Ev.BOLT, o)
		done += 1
	if done >= RING_COUNT:
		boss.finish_attack()


func _cross(ppos: Vector2) -> void:
	for id in ids:
		boss.set_glow(id, clampf(t / WIND, 0.0, 1.0))
	if t < WIND:
		var o0: Vector2 = boss.emitter_pos(ids[0])
		if o0 != Vector2.INF:
			base = (ppos - o0).angle() if ppos.x > o0.x else 0.0
		return
	var ft := t - WIND
	var m: float = boss.bolt_mult()
	while done * CROSS_RATE <= ft and done * CROSS_RATE < CROSS_TIME:
		var ph := sin(TAU * done * CROSS_RATE / CROSS_TIME) * spin
		for s in ids.size():
			var o: Vector2 = boss.emitter_pos(ids[s])
			if o == Vector2.INF:
				continue
			var toward := 0.0 if o.x < 0.0 else PI
			var sg := 1.0 if s == 0 else -1.0
			var tilt := clampf((ppos.y - o.y) / 1400.0, -0.35, 0.35)
			var a := toward + (tilt if o.x < 0.0 else -tilt) + sg * CROSS_SWEEP * ph
			var v := Vector2.from_angle(a) * SMALL_SPEED * m
			if done % 4 == 0:
				boss.shots.spawn(o, v * 1.15, 10.0)
			else:
				boss.shots.spawn(o, v, 10.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		if done % 4 == 0:
			boss.emit(Ev.BOLT, boss.emitter_pos(ids[0]))
		done += 1
	for id in ids:
		boss.set_glow(id, 1.0)
	if ft >= CROSS_TIME:
		boss.finish_attack()


func draw() -> void:
	var c: CanvasItem = boss
	if mode == "tips":
		for ln in lanes:
			c.draw_line(ln[0], ln[1], Color(C_WARN, 0.28), 2.0)
	elif mode == "ring" and t < WIND + 0.2:
		var o: Vector2 = boss.emitter_pos(-1)
		var k := clampf(t / WIND, 0.0, 1.0)
		c.draw_arc(o, 120.0 + 80.0 * k, 0.0, TAU, 32, Color(C_WARN, 0.15 + 0.35 * k), 2.0)
