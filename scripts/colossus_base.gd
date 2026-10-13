extends Node2D
## 모든 콜로서스의 공통 틀. 몸은 배경이라 판정이 없고, 판정은 두 종류뿐이다:
##  1) 공격 판정 — 지금 진행 중인 공격 모듈(atk)과 탄(shots)이 만든다
##  2) 표적 — 외부 시스템(부위)과 장갑+동력 코어(core). 돌진 중에만 충돌한다
## 공통으로 맡는 것: 공격 일정(쉬는 시간 → 고르기 → 모듈 진행 → 끝), 탄, 장갑 파편, 이벤트, 죽음.
## 콜로서스마다 다른 것(모양·표적·공격 고르기·그림)은 아래 "콜로서스마다 채울 것"을 덮어쓴다.

const Ev := preload("res://scripts/ev.gd")
const Projectiles := preload("res://scripts/projectiles.gd")

var phase := 1
var t := 0.0
var dead := false
var death_t := 0.0
var atk = null                       # 진행 중인 공격 모듈 (attacks/attack.gd) 또는 null
var next_t := 2.5                    # 다음 공격까지 남은 시간
var attack_gap := Vector2(1.0, 1.8)  # 공격 사이 쉬는 시간 (범위)
var hold_attacks := false            # true 인 동안(플레이어가 발판 위) 새 공격을 시작하지 않는다
var shots := Projectiles.new()       # 탄
var core = null                      # 장갑 + 동력 코어 (armored_core.gd)
var shards: Array[Dictionary] = []   # 떨어져 나가는 장갑 조각
var events: Array[Dictionary] = []   # main.gd 가 매 프레임 꺼내 처리 (흔들림/사운드)
var strike_glow := false             # 플레이어가 공격 돌진 중 = 타격점이 드러난다
var focus_glow := 0.0                # 방향 지정·차지 중: 노릴 수 있는 표적 강조 (0~1)
var focus_from := Vector2.ZERO       # 강조 기준 위치(플레이어)
var focus_reach := 0.0               # 이 거리 안의 표적은 더 밝게


func reset() -> void:
	phase = 1
	dead = false
	death_t = 0.0
	atk = null
	next_t = 2.5
	shots.clear()
	shards.clear()
	events.clear()
	if core != null:
		core.reset()
	queue_redraw()


func emit(type: int, pos: Vector2, extra := {}) -> void:
	var ev := {"type": type, "pos": pos}
	ev.merge(extra)
	events.append(ev)


## 지금 공격 종류 ("" = 쉬는 중). 튜토리얼·HUD·디버그가 읽는다
func attack_kind() -> String:
	return "" if atk == null else atk.kind


func start_attack(a) -> void:
	a.boss = self
	atk = a


## 공격이 끝나면 쉬는 시간을 정한다
func finish_attack() -> void:
	atk = null
	_on_attack_finished()
	next_t = randf_range(attack_gap.x, attack_gap.y)


# ── 진행 ───────────────────────────────────────────────
func step(dt: float, ppos: Vector2) -> void:
	t += dt
	if core != null:
		core.step(dt)
	_step_shards(dt)
	_step_effects(dt)
	if dead:
		death_t += dt
		queue_redraw()
		return
	_step_phase(dt)
	for p in shots.step(dt):
		emit(Ev.BOLT_POP, p)
	if atk == null:
		if hold_attacks:
			next_t = maxf(next_t, 1.2)         # 날아오른 뒤 잠시 여유를 준다
		next_t -= dt
		if next_t <= 0.0:
			_choose(ppos)
	else:
		atk.t += dt
		atk.step(dt, ppos)
	queue_redraw()


func _step_shards(dt: float) -> void:
	for sd in shards.duplicate():
		var v: Vector2 = sd["vel"]
		v.y += 1400.0 * dt
		sd["vel"] = v
		var sp: Vector2 = sd["pos"] + v * dt
		sd["pos"] = sp
		sd["rot"] = float(sd["rot"]) + float(sd["rotv"]) * dt
		if sp.y > 40.0:                        # 용암에 떨어져 사라진다
			shards.erase(sd)


func die() -> void:
	dead = true
	death_t = 0.0
	atk = null
	shots.clear()


# ── 적 공격 판정 ───────────────────────────────────────
## 플레이어(ppos) 근처의 활성 공격 판정들. push = 플레이어가 밀려나는 방향
func hitboxes(ppos: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	if atk != null:
		atk.hitboxes(ppos, out)
	shots.hitboxes_near(ppos, 200.0, out)
	return out


## 차지 강습으로 요격할 수 있는 공격 판정 ({} = 없음)
func clash_box(ppos: Vector2) -> Dictionary:
	if dead or atk == null:
		return {}
	return atk.clash_box(ppos)


## 패리 불가 공격(레이저 등) 판정 → 밀려날 방향, 안 맞으면 ZERO
func beam_hit(p: Vector2, r: float) -> Vector2:
	if dead or atk == null:
		return Vector2.ZERO
	return atk.beam_hit(p, r)


## 패리 / 요격당함: 탄은 사라지고, 공격 판정은 그 모듈이 처리한다 (팔은 밀려난다)
func on_parried(hb: Dictionary) -> void:
	if hb["id"] == "bolt":
		shots.remove(int(hb["idx"]))
	elif atk != null:
		atk.on_parried(hb)


func on_hit_player(hb: Dictionary) -> void:
	if hb["id"] == "bolt":
		shots.remove(int(hb["idx"]))


## 리버스 드라이브가 끝나면 패리로 밀려난 공격(팔)을 바로 풀어 준다
func release_stagger() -> void:
	if atk != null:
		atk.release_stagger()


func overlaps(hb: Dictionary, p: Vector2, r: float) -> bool:
	if hb.has("segs"):
		for sg in hb["segs"]:
			if seg_closest(p, sg[0], sg[1]).distance_to(p) < r + float(sg[2]):
				return true
		return false
	if hb.has("rect"):
		return not _rect_hit(p, r, hb["rect"]).is_empty()
	var hp: Vector2 = hb["pos"]
	return hp.distance_to(p) < r + float(hb["r"])


static func seg_closest(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	if ab.length_squared() < 0.0001:
		return a
	return a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)


static func _rect_hit(p: Vector2, r: float, rc: Rect2) -> Dictionary:
	var q := Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y))
	var d := p - q
	var l := d.length()
	if l > 0.0001:
		if l >= r:
			return {}
		return {"n": d / l, "depth": r - l}
	var m := minf(minf(p.x - rc.position.x, rc.end.x - p.x), minf(p.y - rc.position.y, rc.end.y - p.y))
	return {"n": Vector2.UP, "depth": m + r}


# ── 표적 피해 ──────────────────────────────────────────
## 돌진이 표적(strike_hit 결과)에 적중. 동력 코어가 부서지면 true (= 승리)
func damage(hit: Dictionary, dmg: int) -> bool:
	if hit["kind"] == "core":
		return damage_core(dmg)
	damage_part(int(hit["idx"]), dmg)
	return false


func damage_core(dmg: int) -> bool:
	return core.damage(dmg)


# ── 그리기 (공통 부분) ─────────────────────────────────
func _draw_shards() -> void:
	for sd in shards:
		var pts: PackedVector2Array = sd["pts"]
		draw_set_transform(sd["pos"], float(sd["rot"]))
		draw_colored_polygon(pts, core.C_STEEL)
		var ol := pts.duplicate()
		ol.append(pts[0])
		draw_polyline(ol, core.C_STEEL_DARK, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0)


# ── 콜로서스마다 채울 것 ───────────────────────────────
## 외부 시스템(부위) 피해. 부서지면 true
func damage_part(_i: int, _dmg: int) -> bool:
	return false


## 원(p, r)이 닿은 표적 {kind:"part", idx, n} / {kind:"core", n} / {}
func strike_hit(_p: Vector2, _r: float) -> Dictionary:
	return {}


## 에임 어시스트용 표적 목록 [{pos, r}]
func assist_targets() -> Array[Dictionary]:
	return []


## HUD 화살표가 가리킬 다음 표적
func target_pos(_from: Vector2) -> Vector2:
	return core.center


## 쉬는 시간이 끝나면 다음 공격을 고른다 (start_attack 으로 시작)
func _choose(_ppos: Vector2) -> void:
	pass


## 공격이 끝났을 때 자세 정리 등
func _on_attack_finished() -> void:
	pass


## 매 프레임 (죽은 뒤에도) 도는 연출 값 감쇠·파편 등
func _step_effects(_dt: float) -> void:
	pass


## 살아 있을 때만 도는 페이즈 진행·발광 감쇠 등
func _step_phase(_dt: float) -> void:
	pass
