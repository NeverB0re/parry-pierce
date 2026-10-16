extends "res://scripts/attacks/attack.gd"
## 크라켄 탄막 (사방에서 쏜다): 촉수 끝·배경 다리·분사구가 모두 발사점이다.
## 원칙: 탄막은 플레이어를 겨누지 않고 정해진 공간을 채운다 (빠져나갈 길을 미리 정해 두고 쏜다). 겨누는 것은 snipe 하나뿐.
##  tips  = 촉수 끝 물결 — 발사점이 왼쪽 → 오른쪽(다음 바퀴는 반대) 차례로 경기장 가운데 쪽으로 넓은 부채를 쏜다. 바퀴마다 반 칸 어긋난다
##  ring  = 분사구에서 동심 고리 — 한 줄 걸러 반 칸씩 어긋난다 (고리 사이로 빠져나간다)
##  cross = 양쪽 가장자리에서 수평으로 엇갈리게 휘두르는 탄 줄기 (가운데에서 X 자로 엇갈린다)
##  snipe = 저격 (시그니처, 유일하게 겨눈다) — 치켜든 두 촉수가 번갈아 조준선을 띄우고 빠른 유도탄을 한 발씩 쏜다.
##          한 발씩이고 주탄(유도탄)이라 패리 → 리버스 드라이브의 기회 (되돌리면 피해가 크다)
## 탄은 모두 패리할 수 있다 (주탄 = 리버스 드라이브).
## light = 작은 탄막 두 개를 겹쳐 쏠 때의 작은 판. 스테이지(boss.level)가 뒤일수록 탄 수가 조금씩 는다.
## boss 에 필요한 것: emitters() → [[번호, 위치], ...], emitter_pos(번호) (못 쓰면 Vector2.INF), set_glow(c, v), bolt_mult()

const Projectiles := preload("res://scripts/projectiles.gd")
const WIND := 0.8
const SMALL_SPEED := 290.0
const MAIN_SPEED := 350.0
const C_WARN := Color(1.0, 0.3, 0.25)
const C_AIM := Color(1.0, 0.88, 0.35)   # 저격 조준선 (주탄 = 금색, 패리할 수 있다)

# tips
const TIPS_GAP := 0.2                # 발사점 사이 간격
const TIPS_ROUNDS := 2
const TIPS_N := 7                    # 부채 하나의 탄 수 (+ 스테이지 순번), 가운데 = 주탄
const TIPS_SPREAD := PI * 0.8        # 부채 폭: 발사점에서 경기장 가운데(ARENA_C) 쪽을 가운데로
const ARENA_C := Vector2(0, -1000)   # 고정 겨눔점 (플레이어가 아니라 경기장 가운데)
# ring
const RING_N := 16                   # + 스테이지 순번 × 2
const RING_COUNT := 3                # + 1 (2스테이지부터)
const RING_GAP := 0.7
const RING_SPEED := 240.0
# cross
const CROSS_TIME := 2.6
const CROSS_RATE := 0.13
const CROSS_SWEEP := 0.55
# snipe
const SNIPE_SHOTS := 2               # + 1 (3스테이지부터)
const SNIPE_CHARGE := 0.8            # 조준선이 보이는 시간
const SNIPE_LOCK := 0.2              # 마지막 이만큼은 조준이 멈춘다 (피할 틈)
const SNIPE_GAP := 1.1
const SNIPE_SPEED := 460.0           # 유도탄 (보통 유도탄 270 보다 빠르다)
const SNIPE_LIFE := 5.0

var mode := "tips"
var hard := false
var light := false
var em: Array = []
var set_up := false
var tips_rounds := TIPS_ROUNDS
var tips_n := TIPS_N
var ring_n := RING_N
var ring_count := RING_COUNT
var cross_time := CROSS_TIME
var snipe_n := SNIPE_SHOTS
var ids: Array[int] = []             # tips: 왼쪽 → 오른쪽 발사점 / cross: [왼쪽, 오른쪽] / snipe: 번갈아 쏠 두 발사점
var done := 0                        # 쏜 횟수
var spin := 1.0
var aims: Dictionary = {}            # snipe: 발 번호 → 조준 각 (조준 중인 것만)


func _init(m: String, emitters_: Array, _ppos: Vector2, hard_ := false, light_ := false) -> void:
	kind = m
	mode = m
	hard = hard_
	light = light_
	em = emitters_
	spin = 1.0 if randf() < 0.5 else -1.0


## 첫 step 에서 (boss 가 채워진 뒤) 스테이지·light 에 맞춰 양을 정하고 발사점을 고른다
func _setup() -> void:
	set_up = true
	var lv: int = boss.level
	ring_n = RING_N + 2 * lv + (2 if hard else 0)
	ring_count = RING_COUNT + (1 if lv >= 1 else 0)
	tips_n = TIPS_N + lv + (2 if hard else 0)
	snipe_n = SNIPE_SHOTS + (1 if lv >= 2 else 0) + (1 if hard else 0)
	if light:
		tips_rounds = 1
		ring_count = 2
		cross_time = 1.4
		snipe_n = 1
	match mode:
		"tips":
			var tips := em.filter(func(e): return int(e[0]) >= 0)
			tips.sort_custom(func(a, b): return (a[1] as Vector2).x < (b[1] as Vector2).x)
			for e in tips:
				ids.append(int(e[0]))
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
		"snipe":
			for pair in [[0, 1], [6, 7]]:                # 치켜든 두 촉수, 없으면 배경 다리
				for id in pair:
					if boss.emitter_pos(id) != Vector2.INF:
						ids.append(id)
				if not ids.is_empty():
					break
	if ids.is_empty() and mode != "ring":
		kind = "ring"
		mode = "ring"


func step(_dt: float, ppos: Vector2) -> void:
	if not set_up:
		_setup()
	match mode:
		"tips":
			_tips()
		"cross":
			_cross()
		"snipe":
			_snipe(ppos)
		_:
			_ring()


## 물결: 바퀴마다 방향을 바꿔 차례로 아래쪽 반원 부채
func _tips() -> void:
	var total := ids.size() * tips_rounds
	var m: float = boss.bolt_mult()
	for j in ids.size():                                  # 예고: 다음에 쏠 발사점이 달아오른다
		var at := _tip_at(done + j) if done + j < total else INF
		if at < INF:
			boss.set_glow(_tip_id(done + j), clampf((t - (at - 0.5)) / 0.5, 0.0, 1.0))
	while done < total and t >= _tip_at(done):
		var id := _tip_id(done)
		var o: Vector2 = boss.emitter_pos(id)
		if o != Vector2.INF:
			var round_ := done / ids.size()
			var step_a := TIPS_SPREAD / (tips_n - 1)
			var off := step_a * 0.5 if round_ % 2 == 1 else 0.0
			var half := tips_n / 2
			var base := (ARENA_C - o).angle() - TIPS_SPREAD * 0.5
			for k in tips_n:
				var a := base + off + k * step_a
				if k == half:
					boss.shots.spawn(o, Vector2.from_angle(a) * MAIN_SPEED * m, 10.0)
				else:
					boss.shots.spawn(o, Vector2.from_angle(a) * SMALL_SPEED * m, 10.0, 0.0, 0.0, Projectiles.Kind.SMALL)
			boss.emit(Ev.BOLT, o)
			boss.set_glow(id, 1.0)
		done += 1
	if done >= total:
		boss.finish_attack()


func _tip_at(n: int) -> float:
	var round_ := n / ids.size()
	return WIND + n * TIPS_GAP + round_ * 0.5


func _tip_id(n: int) -> int:
	var k := n % ids.size()
	if (n / ids.size()) % 2 == 1:                          # 다음 바퀴는 오른쪽 → 왼쪽
		k = ids.size() - 1 - k
	return ids[k]


func _ring() -> void:
	var o: Vector2 = boss.emitter_pos(-1)
	boss.set_glow(-1, minf(1.0, t / WIND))
	var m: float = boss.bolt_mult()
	while done < ring_count and t >= WIND + done * RING_GAP:
		var off := (0.5 if done % 2 == 1 else 0.0) * TAU / ring_n + spin * 0.12 * done
		for k in ring_n:
			var a := off + k * TAU / ring_n
			var v := Vector2.from_angle(a) * RING_SPEED * m
			if k % 5 == 0:
				boss.shots.spawn(o, v * 1.15, 10.0)
			else:
				boss.shots.spawn(o, v, 10.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		boss.emit(Ev.BOLT, o)
		done += 1
	if done >= ring_count:
		boss.finish_attack()


## 양쪽 가장자리에서 수평 기준으로 위아래로 휘두르는 줄기 (서로 반대 위상 → 가운데에서 X 자)
func _cross() -> void:
	for id in ids:
		boss.set_glow(id, clampf(t / WIND, 0.0, 1.0))
	if t < WIND:
		return
	var ft := t - WIND
	var m: float = boss.bolt_mult()
	while done * CROSS_RATE <= ft and done * CROSS_RATE < cross_time:
		var ph := sin(TAU * done * CROSS_RATE / cross_time) * spin
		for s in ids.size():
			var o: Vector2 = boss.emitter_pos(ids[s])
			if o == Vector2.INF:
				continue
			var toward := 0.0 if o.x < 0.0 else PI
			var sg := 1.0 if s == 0 else -1.0
			var v := Vector2.from_angle(toward + sg * CROSS_SWEEP * ph) * SMALL_SPEED * m
			if done % 4 == 0:
				boss.shots.spawn(o, v * 1.15, 10.0)
			else:
				boss.shots.spawn(o, v, 10.0, 0.0, 0.0, Projectiles.Kind.SMALL)
		if done % 4 == 0:
			boss.emit(Ev.BOLT, boss.emitter_pos(ids[0]))
		done += 1
	for id in ids:
		boss.set_glow(id, 1.0)
	if ft >= cross_time:
		boss.finish_attack()


## 저격: 발 n 은 WIND + n × GAP 에 쏜다. 그 SNIPE_CHARGE 전부터 조준선이 플레이어를 따라가다가 SNIPE_LOCK 전에 멈춘다
func _snipe(ppos: Vector2) -> void:
	var m: float = boss.bolt_mult()
	for n in range(done, snipe_n):
		var at := WIND + n * SNIPE_GAP
		if t < at - SNIPE_CHARGE:
			break
		var id: int = ids[n % ids.size()]
		var o: Vector2 = boss.emitter_pos(id)
		if o == Vector2.INF:
			aims.erase(n)
			continue
		boss.set_glow(id, clampf((t - (at - SNIPE_CHARGE)) / SNIPE_CHARGE, 0.0, 1.0))
		if t < at - SNIPE_LOCK or not aims.has(n):
			aims[n] = (ppos - o).angle()
	while done < snipe_n and t >= WIND + done * SNIPE_GAP:
		var id: int = ids[done % ids.size()]
		var o: Vector2 = boss.emitter_pos(id)
		if o != Vector2.INF and aims.has(done):
			var a: float = aims[done]
			boss.shots.spawn(o, Vector2.from_angle(a) * SNIPE_SPEED * m, SNIPE_LIFE, 0.0, 0.0, Projectiles.Kind.HOMING)
			boss.emit(Ev.BOLT, o)
			boss.set_glow(id, 1.0)
		aims.erase(done)
		done += 1
	if done >= snipe_n:
		boss.finish_attack()


func draw() -> void:
	var c: CanvasItem = boss
	if mode == "snipe":                                    # 조준선: 가늘게 떠서 점점 진해지고, 멈추면(조준 고정) 밝게
		for n in aims:
			var id: int = ids[int(n) % ids.size()]
			var o: Vector2 = boss.emitter_pos(id)
			if o == Vector2.INF:
				continue
			var at := WIND + int(n) * SNIPE_GAP
			var k := clampf((t - (at - SNIPE_CHARGE)) / SNIPE_CHARGE, 0.0, 1.0)
			var locked := t >= at - SNIPE_LOCK
			var d := Vector2.from_angle(float(aims[n]))
			c.draw_line(o, o + d * 2600.0, Color(C_AIM, (0.6 if locked else 0.15 + 0.3 * k)), 5.0 if locked else 3.0)
			c.draw_circle(o, 10.0 + 14.0 * k, Color(C_AIM, 0.25 + 0.4 * k))
	elif mode == "ring" and t < WIND + 0.2:
		var o: Vector2 = boss.emitter_pos(-1)
		var k := clampf(t / WIND, 0.0, 1.0)
		c.draw_arc(o, 120.0 + 80.0 * k, 0.0, TAU, 32, Color(C_WARN, 0.15 + 0.35 * k), 2.0)
