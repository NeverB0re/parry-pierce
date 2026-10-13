extends "res://scripts/attacks/attack.gd"
## 촉수 공격 공통 (크라켄). 촉수 하나(또는 둘)를 붙잡고 척추(boss.spines[i], 마디 boss.N 개)를 직접 움직인다.
## 근접공격 = 회피 불가. 판정은 척추의 hit_from 번째 마디부터 끝까지 (뿌리 쪽은 몸 = 배경).
## 차지 강습·리버스 드라이브로 요격하면 그 촉수의 구동부에 피해(페이즈 1) + 촉수가 움츠러들고(recoil) 잠시 멈춘다(stagger, 구동부가 크게 빛남).
## 그냥 패리하면 피해만 막고 튕겨난다 (판정 id 가 "arm" 이라 main.gd 가 팔과 같이 처리한다).
## 붙잡은 촉수는 모듈이 끝나면 크라켄이 알아서 놓아 주고(boss.busy 정리), 제자리로 천천히 돌아간다.
## 하위 모듈이 채울 것: _act(dt, ppos), _harmful(), _clashable(), _push(tent, ppos), draw()

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const RECOIL := 0.5
const STAGGER := 1.0
const KNOCK := 680.0                  # 요격당하면 촉수 끝이 부딪힌 방향으로 이만큼 날아간다 (과장되게, 끝으로 갈수록 크게)

var tents: Array[int] = []           # 붙잡은 촉수 번호
var hit_from := 4                     # 판정이 시작되는 척추 마디
var delay := 0.0                      # 시작 전 대기 (두 번째 촉수는 시차를 두고 예고한다)
var fixed_half := -1.0                # 판정 반폭을 예고 범위에 맞춰 고정 (-1 = 촉수 굵기를 따른다)
var _recoil_from: Array = []          # 움츠러들기 시작한 척추들
var _recoil_to: Array = []


func _grab(ts: Array[int], first_phase: String) -> void:
	tents = ts
	part = ts[0]
	phase = first_phase


## 시작할 때(start_attack / start_side 직후) 촉수를 붙잡는다
func claim() -> void:
	for i in tents:
		boss.busy[i] = self


func uses(i: int) -> bool:
	return tents.has(i)


func step(dt: float, ppos: Vector2) -> void:
	if delay > 0.0:
		delay -= dt
		t = 0.0
		return
	match phase:
		"recoil":
			var k := minf(1.0, t / RECOIL)
			var e := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)   # 튕겨 나가 살짝 넘쳤다가 멈춘다
			for j in tents.size():
				var a: PackedVector2Array = _recoil_from[j]
				var b: PackedVector2Array = _recoil_to[j]
				var sp := PackedVector2Array()
				for q in a.size():
					sp.append(a[q].lerp(b[q], e))
				boss.spines[tents[j]] = sp
			if k >= 1.0:
				set_phase("stagger")
		"stagger":                                   # 멈춰 떨린다 (점점 잦아든다)
			var amp := 9.0 * (1.0 - t / STAGGER)
			for j in tents.size():
				var b: PackedVector2Array = _recoil_to[j]
				var sp := PackedVector2Array()
				for q in b.size():
					sp.append(b[q] + Vector2(sin(boss.t * 55.0 + q), cos(boss.t * 47.0 + q)) * amp * float(q) / b.size())
				boss.spines[tents[j]] = sp
			if t >= STAGGER:
				set_phase("end")
		"end":
			boss.finish_attack()
		_:
			_act(dt, ppos)


func is_staggered(i: int) -> bool:
	return tents.has(i) and (phase == "recoil" or phase == "stagger")


# ── 판정 ───────────────────────────────────────────────
func _hb(i: int, ppos: Vector2) -> Dictionary:
	var segs: Array = boss.tent_segs(i, hit_from, fixed_half)
	var best: Vector2 = boss.spines[i][hit_from]
	var best_d := INF
	for sg in segs:
		var q: Vector2 = boss.seg_closest(ppos, sg[0], sg[1])
		var d := q.distance_to(ppos) - float(sg[2])
		if d < best_d:
			best_d = d
			best = q
	return {"id": "arm", "segs": segs, "pos": best, "src": self, "tent": i, "gap": best_d}


func hitboxes(ppos: Vector2, out: Array[Dictionary]) -> void:
	if delay > 0.0 or not _harmful():
		return
	for i in tents:
		var hb := _hb(i, ppos)
		hb["push"] = _push(i, ppos)
		hb["melee"] = true                     # 근접공격 = 회피 불가
		out.append(hb)


## 요격 판정: 붙잡은 촉수 중 플레이어에게 가장 가까운 것. 페이즈 1에서 구동부가 살아 있으면 그 구동부에 피해
func clash_box(ppos: Vector2) -> Dictionary:
	if delay > 0.0 or not _clashable():
		return {}
	var best := {}
	for i in tents:
		var hb := _hb(i, ppos)
		if best.is_empty() or float(hb["gap"]) < float(best["gap"]):
			best = hb
	if boss.phase == 1 and boss.part_alive(int(best["tent"])):
		best["part"] = int(best["tent"])
	return best


## 요격당함: 붙잡은 촉수가 모두 부딪힌 방향(hb.dir, main 이 채운다)으로 크게 튕겨 나갔다가 멈춰 떤다 (조이기·압착이라면 둘 다 풀린다).
## 맞은 촉수가 가장 크게, 같이 붙잡힌 촉수는 절반만
func on_parried(hb: Dictionary) -> void:
	if phase == "recoil" or phase == "stagger" or phase == "end":
		return
	var dir: Vector2 = hb.get("dir", Vector2.UP)
	if dir.length() < 0.1:
		dir = Vector2.UP
	boss.hit_dir = dir
	boss.hit_dir_t = boss.t
	_recoil_from.clear()
	_recoil_to.clear()
	for i in tents:
		var sp: PackedVector2Array = boss.spines[i]
		var hit_k := 1.0 if int(hb.get("tent", i)) == i else 0.5
		var to := PackedVector2Array()
		for q in sp.size():
			var f := float(q) / (sp.size() - 1)
			to.append(sp[q] + dir * KNOCK * hit_k * pow(f, 1.3) + Vector2(0, -140.0 * f))
		_recoil_from.append(sp.duplicate())
		_recoil_to.append(to)
	set_phase("recoil")


## 요격할 수 있는 동안: 촉수에서 플레이어에게 가장 가까운 지점을 어시스트 우선 표적으로
func assist_targets(from: Vector2, out: Array[Dictionary]) -> void:
	if delay > 0.0 or not _clashable():
		return
	for i in tents:
		out.append({"pos": _hb(i, from)["pos"], "r": 40.0, "intercept": true})


## 리버스 드라이브가 끝나면 경직을 풀고 바로 놓아 준다 (모듈이 끝나는 건 다음 프레임 step 에서)
func release_stagger() -> void:
	if phase == "recoil" or phase == "stagger":
		set_phase("end")


# ── 하위 모듈 ──────────────────────────────────────────
func _act(_dt: float, _ppos: Vector2) -> void:
	pass


func _harmful() -> bool:
	return false


func _clashable() -> bool:
	return false


func _push(_i: int, _ppos: Vector2) -> Vector2:
	return Vector2.UP


## 척추 a → b 로 k 만큼 (마디별 보간)
static func blend(a: PackedVector2Array, b: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a.size():
		out.append(a[q].lerp(b[q], k))
	return out
