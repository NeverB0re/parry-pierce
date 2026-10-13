extends "res://scripts/attacks/attack.gd"
## 촉수 공격 공통 (크라켄). 촉수 하나(또는 둘)를 붙잡고 척추(boss.spines[i], 마디 boss.N 개)를 직접 움직인다.
## 근접공격 = 회피 불가. 판정은 척추의 hit_from 번째 마디부터 끝까지 (뿌리 쪽은 몸 = 배경).
## 차지 강습·리버스 드라이브로 요격하면 그 촉수의 구동부에 피해(페이즈 1) + 촉수가 움츠러들고(recoil) 잠시 멈춘다(stagger, 구동부가 크게 빛남).
## 그냥 패리하면 피해만 막고 튕겨난다 (판정 id 가 "arm" 이라 main.gd 가 팔과 같이 처리한다).
## 붙잡은 촉수는 모듈이 끝나면 크라켄이 알아서 놓아 주고(boss.busy 정리), 제자리로 천천히 돌아간다.
## 하위 모듈이 채울 것: _act(dt, ppos), _harmful(), _clashable(), _push(tent, ppos), draw()

const MeleeWarn := preload("res://scripts/melee_warn.gd")
const RECOIL := 0.45
const STAGGER := 1.0

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
			var e := 1.0 - (1.0 - k) * (1.0 - k)
			for j in tents.size():
				var a: PackedVector2Array = _recoil_from[j]
				var b: PackedVector2Array = _recoil_to[j]
				var sp := PackedVector2Array()
				for q in a.size():
					sp.append(a[q].lerp(b[q], e))
				boss.spines[tents[j]] = sp
			if k >= 1.0:
				set_phase("stagger")
		"stagger":
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


## 요격당함: 붙잡은 촉수가 모두 뿌리 쪽으로 움츠러든다 (조이기라면 고리가 풀린다)
func on_parried(_hb: Dictionary) -> void:
	if phase == "recoil" or phase == "stagger" or phase == "end":
		return
	_recoil_from.clear()
	_recoil_to.clear()
	for i in tents:
		var sp: PackedVector2Array = boss.spines[i]
		var root: Vector2 = sp[0]
		var to := PackedVector2Array()
		for q in sp.size():
			var f := float(q) / (sp.size() - 1)
			to.append(root + (sp[q] - root) * 0.55 + Vector2(0, -160.0 * f))
		_recoil_from.append(sp.duplicate())
		_recoil_to.append(to)
	set_phase("recoil")


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
