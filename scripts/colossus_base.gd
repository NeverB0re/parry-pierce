extends Node2D
## 모든 콜로서스의 공통 틀. 몸은 배경이라 판정이 없고, 판정은 두 종류뿐이다:
##  1) 공격 판정 — 지금 진행 중인 공격 모듈(atk)과 탄(shots)이 만든다
##  2) 표적 — 외부 시스템(부위)과 장갑+동력 코어(core). 돌진 중에만 충돌한다
## 공통 진행: 페이즈 1 외부 시스템 파괴 → 페이즈 2 개방 연출 → 페이즈 3 동력 코어.
## 공통으로 맡는 것: 공격 일정(쉬는 시간 → 고르기 → 모듈 진행 → 끝), 외부 시스템 체력·손상 단계·약점 표시,
## 탄, 장갑 파편, 이벤트, 죽음. 콜로서스마다 다른 것(모양·표적 위치·공격 고르기·그림)은 아래 "콜로서스마다 채울 것"을 덮어쓴다.
## 외부 시스템 번호는 짝수 = 왼쪽, 홀수 = 오른쪽 (파편이 튀는 방향).

const Ev := preload("res://scripts/ev.gd")
const Projectiles := preload("res://scripts/projectiles.gd")

const C_HEART := Color(1.0, 0.42, 0.22)          # 약점(외부 시스템·코어)의 빛
const C_PLATE_EDGE := Color(0.62, 0.3, 0.14)     # 상시 표적 → 달궈진 가장자리
const C_CAVITY := Color(0.10, 0.03, 0.04)

var phase := 1
var t := 0.0
var dead := false
var death_t := 0.0
var open_t := 0.0
var open_time := 1.6                 # 가슴(코어)이 열리는 연출 시간
var atk = null                       # 진행 중인 공격 모듈 (attacks/attack.gd) 또는 null
var lingering: Array = []            # 자리를 내준 공격 모듈들: 판정·그림은 남아 끝날 때까지 돌고, 그동안 다음 공격이 시작된다
var _stepping_linger = null          # 지금 진행 중인 lingering 모듈 (그 모듈이 finish_attack 을 부르면 목록에서만 빠진다)
var next_t := 2.5                    # 다음 공격까지 남은 시간
var attack_gap := Vector2(1.0, 1.8)  # 공격 사이 쉬는 시간 (범위)
var hold_attacks := false            # true 인 동안(플레이어가 발판 위) 새 공격을 시작하지 않는다
var bolt_speedup := 0.1              # 외부 시스템 하나 부술 때마다 탄 속도 +10%
var bolt_speedup_core := 0.15        # 최종 페이즈 추가 가속
var level := 0                       # 스테이지 순번 (0부터). 뒤 스테이지일수록 같은 패턴도 조금씩 어려워진다
const LEVEL_SPEEDUP := 0.06          # 스테이지 하나마다 탄 속도 +6%
var core_assist_r := 200.0           # 에임 어시스트가 보는 코어 반지름
var part_hp: Array[int] = []
var part_flash: Array[float] = []
var part_stage: Array[int] = []      # 외부 시스템 손상 단계 0~3 (남은 체력 75/50/25%)
var shots := Projectiles.new()       # 탄
var core = null                      # 장갑 + 동력 코어 (armored_core.gd)
var shards: Array[Dictionary] = []   # 떨어져 나가는 장갑 조각
var events: Array[Dictionary] = []   # main.gd 가 매 프레임 꺼내 처리 (흔들림/사운드)
var strike_glow := false             # 플레이어가 공격 돌진 중 = 타격점이 드러난다
var focus_glow := 0.0                # 방향 지정·차지 중: 노릴 수 있는 표적 강조 (0~1)
var focus_from := Vector2.ZERO       # 강조 기준 위치(플레이어)
var aim_from := Vector2.ZERO         # 플레이어 위치와 조준 방향 (main 이 매 프레임): 겨눈 쪽 표적의 테두리가 조금 더 밝다
var aim_dir := Vector2.UP
var look_at := Vector2(0, -1200)       # 플레이어 위치 (그림 전용: 대기 모션이 바라본다. 판정에는 쓰지 않는다)
# 체력 게이지: 코어를 두른 링 (모든 보스 공통, _draw 에서 _draw_gauge 를 부른다)
const GAUGE_W := 10.0
const GAUGE_HOLD := 0.45                     # 깎인 몫(흰 꼬리)이 머무는 시간
const GAUGE_SHOW := 2.2                      # 맞은 뒤 게이지가 보이는 시간 (평소에는 숨는다)
const GAUGE_FADE := 0.6                      # 그중 마지막 이만큼 서서히 사라진다
var gauge_vis := 0.0                         # 게이지가 보일 남은 시간
var gauge_lag := -1.0                        # 흰 꼬리: 방금 깎인 만큼 잠깐 남았다가 따라 내려온다 (-1 = 아직 모름)
var gauge_hit := 0.0                         # 방금 깎임 (번쩍·두꺼워짐)
var gauge_seen := -1.0
var gauge_hold := 0.0
var focus_reach := 0.0               # 이 거리 안의 표적은 더 밝게


func reset() -> void:
	phase = 1
	open_t = 0.0
	dead = false
	death_t = 0.0
	atk = null
	lingering.clear()
	next_t = 2.5
	part_hp.clear()
	part_flash.clear()
	part_stage.clear()
	for i in part_count():
		part_hp.append(part_max_hp(i))
		part_flash.append(0.0)
		part_stage.append(0)
	shots.clear()
	shards.clear()
	events.clear()
	if core != null:
		core.reset()
	gauge_lag = -1.0
	gauge_seen = -1.0
	gauge_hit = 0.0
	gauge_hold = 0.0
	gauge_vis = 0.0
	queue_redraw()


func emit(type: int, pos: Vector2, extra := {}) -> void:
	var ev := {"type": type, "pos": pos}
	ev.merge(extra)
	events.append(ev)


# ── 패턴 고르기 공통 도구 ──────────────────────────────
# 원칙: 탄막은 플레이어를 겨누지 않고 정해진 방향·공간을 채운다 (방향은 정해진 선택지 중 플레이어 쪽).
#       근접은 날아오는 탄이 걷힌 뒤에만. 패턴은 플레이어가 있는 구역에 맞는 것이 자주 나온다 (zone 가중치).
const DIRS_DOWN := [PI * 0.5, PI * 0.5 - 0.7, PI * 0.5 + 0.7, 0.15, PI - 0.15]   # 아래 · 오른아래 · 왼아래 · 오른쪽 · 왼쪽
const CLEAR_R := 900.0               # 근접은 플레이어 이 거리 안으로 다가오는 탄이 없을 때만


## 정해진 방향(dirs) 중 from → to 에 가장 가까운 것
static func nearest_dir(from: Vector2, to: Vector2, dirs: Array) -> float:
	var want := (to - from).angle()
	var best: float = dirs[0]
	for d in dirs:
		if absf(angle_difference(float(d), want)) < absf(angle_difference(best, want)):
			best = d
	return best


## 플레이어 가까이(CLEAR_R) 다가오는 적 탄이 없고, 패리 불가 고리도 퍼지고 있지 않은가 (근접을 시작해도 되는가)
func shots_clear(ppos: Vector2) -> bool:
	if is_lingering("rings"):
		return false
	for k in shots.size():
		if shots.mine[k] == 1:
			continue
		var d: Vector2 = ppos - shots.pos[k]
		if d.length() < CLEAR_R and d.dot(shots.vel[k]) > 0.0:
			return false
	return true


## 플레이어 둘레 r 안에 있는 적 탄 수 (화면이 탄으로 꽉 찼는지)
func shots_near(ppos: Vector2, r: float) -> int:
	var n := 0
	for k in shots.size():
		if shots.mine[k] != 1 and ppos.distance_to(shots.pos[k]) < r:
			n += 1
	return n


## 가중치 뽑기 {종류: 가중치}. avoid(직전 패턴)는 가중치를 크게 줄인다
static func weighted_pick(w: Dictionary, avoid := "") -> String:
	var total := 0.0
	for k in w:
		total += float(w[k]) * (0.15 if k == avoid else 1.0)
	var r := randf() * total
	for k in w:
		r -= float(w[k]) * (0.15 if k == avoid else 1.0)
		if r <= 0.0:
			return k
	return w.keys()[0]


## 지금 공격 종류 ("" = 쉬는 중). 튜토리얼·HUD·디버그가 읽는다
func attack_kind() -> String:
	return "" if atk == null else atk.kind


func start_attack(a) -> void:
	a.boss = self
	atk = a


## 공격이 끝나면 쉬는 시간을 정한다. (자리를 내준 모듈이 끝나면 목록에서 빠지기만 한다)
func finish_attack() -> void:
	if _stepping_linger != null:
		lingering.erase(_stepping_linger)
		return
	atk = null
	_on_attack_finished()
	next_t = randf_range(attack_gap.x, attack_gap.y)


## 지금 공격이 판정은 남긴 채 자리를 내준다 (퍼져 나가는 고리, 올라가는 프레스 등). 쉬는 시간 뒤 다음 공격이 시작된다
func detach_attack() -> void:
	if atk == null:
		return
	lingering.append(atk)
	finish_attack()


## 다른 공격과 겹쳐 도는 보조 공격을 시작한다 (자리를 차지하지 않는다. 끝나면 스스로 빠진다)
func start_side(a) -> void:
	a.boss = self
	lingering.append(a)


## 자리를 내준 공격 중 kind 가 남아 있는가
func is_lingering(kind: String) -> bool:
	for a in lingering:
		if a.kind == kind:
			return true
	return false


## 진행 중·자리를 내준 공격 모듈 모두 (판정·그리기용)
func active_attacks() -> Array:
	var out := lingering.duplicate()
	if atk != null:
		out.append(atk)
	return out


# ── 진행 ───────────────────────────────────────────────
func step(dt: float, ppos: Vector2) -> void:
	t += dt
	look_at = look_at.lerp(ppos, 1.0 - exp(-2.0 * dt))
	if core != null:
		core.step(dt)
	_step_shards(dt)
	_step_gauge(dt)
	for i in part_flash.size():
		part_flash[i] = maxf(0.0, part_flash[i] - dt * 4.0)
	_step_effects(dt)
	if dead:
		death_t += dt
		queue_redraw()
		return
	if phase == 2:
		open_t += dt
		if open_t >= open_time:
			phase = 3
			emit(Ev.CORE_READY, core.center)
	_step_phase(dt)
	for p in shots.step(dt, ppos, target_pos(ppos)):
		emit(Ev.BOLT_POP, p)
	for h in shots.take_hits(self):              # 반사된 탄이 표적에 닿음 → main 이 피해를 준다
		emit(Ev.REFLECT_HIT, h["pos"], h)
	for a in lingering.duplicate():
		_stepping_linger = a
		a.t += dt
		a.step(dt, ppos)
	_stepping_linger = null
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


## 게이지 값 (남은 체력, 전체, 보호 몫이 끝나는 지점). 기본 = 외부 시스템 합 + 코어 장갑, 외부 시스템이 다 부서지면 코어가 열린다
func gauge_values() -> Vector3:
	if core == null:
		return Vector3.ZERO
	var hp := 0.0
	var full := 0.0
	for i in part_count():
		hp += maxf(0.0, float(part_hp[i])) if i < part_hp.size() else 0.0
		full += part_max_hp(i)
	return Vector3(hp + core.armor_hp, full + core.armor_max, core.armor_max)


## 게이지 링 반지름 (기본: 코어 껍질 바깥)
func gauge_radius() -> float:
	var r := 0.0
	for q in core.shell_poly:
		r = maxf(r, (q - core.center).length())
	return r + 70.0


func _step_gauge(dt: float) -> void:
	if core == null:
		return
	var hp := gauge_values().x
	if gauge_seen < 0.0:
		gauge_seen = hp
		gauge_lag = hp
	if hp < gauge_seen - 0.01:                   # 깎임: 게이지가 나타나 번쩍이고 흰 꼬리가 잠깐 머문다
		gauge_hit = 1.0
		gauge_hold = GAUGE_HOLD
		gauge_vis = GAUGE_SHOW
	gauge_vis = maxf(0.0, gauge_vis - dt)
	gauge_seen = hp
	gauge_hold -= dt
	if gauge_hold <= 0.0:
		gauge_lag = move_toward(gauge_lag, hp, dt * maxf(60.0, (gauge_lag - hp) * 3.0))
	gauge_lag = maxf(gauge_lag, hp)
	gauge_hit = maxf(0.0, gauge_hit - dt * 3.0)


## 체력 게이지: 코어를 두른 링. 맞을 때만 GAUGE_SHOW 동안 나타난다. 12시에서 시계 방향으로 남은 체력만큼 찬다.
## 보호 단계(페이즈 1)에는 보호 몫(외부 시스템·방어막)이 청록으로 먼저 깎이고, 코어가 열리는 지점에 흰 눈금, 그 아래가 붉은 코어 몫.
## 깎이면 번쩍이고 깎인 자리에 흰 꼬리가 잠깐 남는다
func _draw_gauge() -> void:
	if dead or core == null or gauge_vis <= 0.0:
		return
	var vis := minf(1.0, gauge_vis / GAUGE_FADE)                                # 맞을 때만 보이고 서서히 사라진다
	var g := gauge_values()
	var hp := g.x
	var full := maxf(1.0, g.y)
	var floor_f := g.z / full
	var hc: Vector2 = core.center
	var R := gauge_radius()
	var top := -PI * 0.5
	var w := GAUGE_W * (1.0 + 0.5 * gauge_hit)
	draw_arc(hc, R, 0.0, TAU, 96, Color(0.03, 0.04, 0.05, 0.75 * vis), w + 6.0)   # 바탕
	if gauge_lag > hp:                                                         # 방금 깎인 몫 (흰 꼬리)
		draw_arc(hc, R, top + TAU * hp / full, top + TAU * gauge_lag / full, 48, Color(1, 1, 1, 0.85 * vis), w)
	var red := Color(C_HEART, 0.95).lerp(Color.WHITE, gauge_hit * 0.6)
	var cyan := Color(0.45, 0.95, 1.0, 0.95).lerp(Color.WHITE, gauge_hit * 0.6)
	red.a *= vis
	cyan.a *= vis
	if phase == 1:
		draw_arc(hc, R, top, top + TAU * minf(hp / full, floor_f), 64, red, w)
		if hp / full > floor_f:
			draw_arc(hc, R, top + TAU * floor_f, top + TAU * hp / full, 64, cyan, w)
		var tick := Vector2.from_angle(top + TAU * floor_f)                   # 코어가 열리는 눈금
		draw_line(hc + tick * (R - w), hc + tick * (R + w), Color(1, 1, 1, 0.9 * vis), 3.0)
	elif hp > 0.0:
		draw_arc(hc, R, top, top + TAU * hp / full, 64, red, w)
	else:                                                                      # 다 깎임: 한 발 더 (깜빡임)
		draw_arc(hc, R, 0.0, TAU, 64, Color(1.0, 0.95, 0.7, (0.3 + 0.4 * float(int(t * 8.0) % 2)) * vis), 3.0)


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
	lingering.clear()
	shots.clear()


# ── 외부 시스템 ────────────────────────────────────────
func part_alive(i: int) -> bool:
	return part_hp[i] > 0


func parts_left() -> int:
	var n := 0
	for hp in part_hp:
		if hp > 0:
			n += 1
	return n


## 외부 시스템 피해. 손상 단계가 오르면 조각이 튀고, 부서지면 떨어져 나가며(그 부위를 쓰던 공격은 끊김),
## 다 부서지면 가슴(코어)이 열린다. 부서지면 true
func damage_part(i: int, dmg: int) -> bool:
	if not part_alive(i):
		return false
	part_flash[i] = 1.0
	if part_hp[i] - dmg > 0:
		part_hp[i] -= dmg
		var st := _part_stage_of(i)
		if st > part_stage[i]:
			part_stage[i] = st
			emit(Ev.PART_STAGE, part_pos(i), {"stage": st})
			if st == 3:
				_spawn_shard(part_pos(i), 26.0, Vector2((1.0 if i % 2 == 1 else -1.0) * 240.0, -320.0))
		return false
	var pos := part_pos(i)
	_on_part_broken(i)
	if atk != null and atk.part == i:          # 이 부위를 쓰던 공격은 끊긴다
		finish_attack()
	part_hp[i] = 0
	emit(Ev.PART_BREAK, pos)
	if parts_left() == 0:
		phase = 2
		open_t = 0.0
		atk = null
		lingering.clear()
		next_t = open_time + 1.0
		emit(Ev.CORE_OPEN, core.center)
	return true


func _part_stage_of(i: int) -> int:
	var f := float(part_hp[i]) / part_max_hp(i)
	if f <= 0.25:
		return 3
	if f <= 0.5:
		return 2
	if f <= 0.75:
		return 1
	return 0


func _spawn_shard(pos: Vector2, size: float, v: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(-size, -size * 0.6), Vector2(size * 0.8, -size * 0.8), Vector2(size, size * 0.5), Vector2(-size * 0.5, size)])
	shards.append({"pos": pos, "vel": v, "rot": 0.0, "rotv": randf_range(-5.0, 5.0), "pts": pts})


## 탄 속도 배율: 외부 시스템을 부술수록, 최종 페이즈일수록 빨라진다
func bolt_mult() -> float:
	return (1.0 + bolt_speedup * (part_count() - parts_left()) + (bolt_speedup_core if phase == 3 else 0.0)) * (1.0 + LEVEL_SPEEDUP * level)


## HUD 화살표가 가리킬 다음 표적 (반사된 탄도 이곳을 향한다)
func target_pos(from: Vector2) -> Vector2:
	if phase >= 2:
		return core.center
	var best: Vector2 = core.center
	var best_d := INF
	for i in part_count():
		if part_alive(i) and part_pos(i).distance_to(from) < best_d:
			best_d = part_pos(i).distance_to(from)
			best = part_pos(i)
	return best


# ── 플레이어 공격 판정 ─────────────────────────────────
## 원(p, r)이 닿은 표적. 페이즈 1은 외부 시스템, 페이즈 2(열리는 중)·3은 동력 코어(장갑). {kind, idx?, n}
## v0.47: 열리는 중에도 코어가 보이므로 맞는다 (전에는 돌진이 그대로 통과했다)
func strike_hit(p: Vector2, r: float) -> Dictionary:
	if dead:
		return {}
	if phase == 1:
		var best := {}
		var best_d := INF
		for i in part_count():
			if not part_alive(i):
				continue
			var d := p.distance_to(part_pos(i))
			if d < r + part_radius(i) and d < best_d:
				best_d = d
				var n := p - part_pos(i)
				best = {"kind": "part", "idx": i, "n": n.normalized() if n.length() > 0.1 else Vector2.UP}
		return best
	return core.hit(p, r)


## 에임 어시스트용 표적 목록 (중심, 반지름). 요격할 수 있는 공격(프레스 등)은 임시 표적을 더한다 (from = 플레이어 위치)
func assist_targets(from := Vector2.ZERO) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	if phase == 1:
		for i in part_count():
			if part_alive(i):
				out.append({"pos": part_pos(i), "r": part_radius(i)})
	else:
		out.append({"pos": core.center, "r": core_assist_r})
	for a in active_attacks():
		a.assist_targets(from, out)
	return out


# ── 적 공격 판정 ───────────────────────────────────────
## 플레이어(ppos) 근처의 활성 공격 판정들. push = 플레이어가 밀려나는 방향
func hitboxes(ppos: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if dead:
		return out
	for a in active_attacks():
		a.hitboxes(ppos, out)
	shots.hitboxes_near(ppos, 200.0, out)
	return out


## 차지 강습으로 요격할 수 있는 공격 판정 ({} = 없음). 여러 공격이 동시에 요격 가능하면(크라켄 촉수 둘) 플레이어에 닿은 것을 먼저
func clash_box(ppos: Vector2) -> Dictionary:
	if dead:
		return {}
	var first := {}
	for a in active_attacks():
		var hb: Dictionary = a.clash_box(ppos)
		if hb.is_empty():
			continue
		if overlaps(hb, ppos, 12.0):
			return hb
		if first.is_empty():
			first = hb
	return first


## 패리 불가 공격(레이저 등) 판정 → 밀려날 방향, 안 맞으면 ZERO
func beam_hit(p: Vector2, r: float) -> Vector2:
	if dead:
		return Vector2.ZERO
	for a in active_attacks():
		if a.dodged:
			continue
		var push: Vector2 = a.beam_hit(p, r)
		if push != Vector2.ZERO:
			return push
	return Vector2.ZERO


## 패리 불가 판정을 p 에서 퍼펙트 회피했다(완전 동조): 닿은 공격의 에너지를 빨아들여 사라진다 (여러 줄기 공격은 그 줄기만)
func mark_beam_dodged(p: Vector2, r: float) -> void:
	for a in active_attacks():
		if not a.dodged and a.beam_hit(p, r) != Vector2.ZERO:
			a.mark_dodged(p, r)


## 이 판정은 이미 회피 무적으로 통과한 것인가 (탄 하나 / 공격 모듈)
func hb_dodged(hb: Dictionary) -> bool:
	if hb.has("idx"):
		var i: int = hb["idx"]
		return i < shots.dodged.size() and shots.dodged[i] == 1
	var src = hb.get("src", null)
	return src != null and src.dodged


func mark_hb_dodged(hb: Dictionary) -> void:
	if hb.has("idx"):
		var i: int = hb["idx"]
		if i < shots.dodged.size():
			shots.dodged[i] = 1
	elif hb.get("src", null) != null:
		hb["src"].dodged = true


## 패리 / 요격당함: 탄은 사라지고, 공격 판정은 그 모듈(src, 없으면 지금 공격)이 처리한다 (팔은 밀려난다)
func on_parried(hb: Dictionary) -> void:
	if hb["id"] == "bolt":
		shots.remove(int(hb["idx"]))
		return
	var src = hb.get("src", atk)
	if src != null:
		src.on_parried(hb)


func on_hit_player(hb: Dictionary) -> void:
	if hb["id"] == "bolt":
		shots.remove(int(hb["idx"]))


## 패리 불가 공격이 다가오는 지점들 (HUD 가 화면 밖이면 가장자리에 보라 ⚠ + 화살표로 알린다)
func unparry_points(ppos: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if dead:
		return out
	for a in active_attacks():
		if a.dodged:
			continue
		var q: Vector2 = a.unparry_point(ppos)
		if q.is_finite():
			out.append(q)
	return out


## 지금 근접공격을 예고하는 중인가 (HUD 경고 띠)
func melee_warning() -> bool:
	if dead:
		return false
	for a in active_attacks():
		if a.melee_warning():
			return true
	return false


## 리버스 드라이브가 끝나면 패리로 밀려난 공격(팔)을 바로 풀어 준다
func release_stagger() -> void:
	for a in active_attacks():
		a.release_stagger()


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
## 부드러운 빛무리: 반지름을 줄여 가며 옅은 원을 겹쳐 가운데가 밝고 가장자리가 사라지게 (후광·열기)
func _soft_glow(c: Vector2, r: float, col: Color, peak: float) -> void:
	for k in 8:
		draw_circle(c, r * (1.0 - k * 0.11), Color(col, peak / 8.0))


## 껍질이 다 벗겨져 드러난 코어 (한 대면 터진다): 작고 하얗게 달아올라 떨리고, 표면이 갈라지고, 전기가 튀고,
## 경보처럼 고리가 거듭 퍼진다. 주변 근육·반응로는 콜로서스가 검게 그을려 그린다 (눈이 코어에만 가게)
func _draw_exposed_core(c: Vector2, r: float, col: Color) -> void:
	var jit := Vector2(sin(t * 53.0), cos(t * 47.0)) * 3.0
	var p := c + jit
	var beat := 0.5 + 0.5 * sin(t * 18.0)
	_soft_glow(p, r * 2.4, col, 0.45 + 0.2 * beat)
	for k in 2:                                                      # 경보 고리: 바깥으로 거듭 퍼진다
		var u := fmod(t * 1.6 + k * 0.5, 1.0)
		draw_arc(p, r * (1.2 + 2.6 * u), 0.0, TAU, 40, Color(1.0, 0.95, 0.75, 0.7 * (1.0 - u)), 4.0 * (1.0 - u) + 1.0)
	for k in 6:                                                      # 튀는 전기
		if int(t * 20.0 + k * 3.0) % 3 == 0:
			continue
		var a := k * TAU / 6.0 + sin(t * 3.0 + k) * 0.6
		var q := p
		var pts := PackedVector2Array([q])
		for s in 4:
			q += Vector2.from_angle(a + sin(t * 41.0 + k * 7.0 + s * 2.3) * 0.9) * r * 0.45
			pts.append(q)
		draw_polyline(pts, Color(1.0, 0.9, 0.6, 0.85), 2.5)
	var rr := r * (0.78 + 0.08 * beat)
	draw_circle(p, rr * 1.25, Color(col, 0.9))
	draw_circle(p, rr, Color(1.0, 0.93, 0.8))
	for k in 5:                                                      # 표면 균열 (안쪽 빛보다 어둡게)
		var a := k * TAU / 5.0 + 0.4
		draw_polyline(PackedVector2Array([p + Vector2.from_angle(a) * rr * 0.15, p + Vector2.from_angle(a + 0.35) * rr * 0.55, p + Vector2.from_angle(a + 0.1) * rr * 0.98]), Color(col.darkened(0.3), 0.9), 3.0)
	draw_circle(p + Vector2(-rr * 0.3, -rr * 0.3), rr * 0.25, Color(1, 1, 1))


## 방어막·결계({kind:"shield"})에 닿은 돌진이 튕겨 나오는가 (피해 없음). 기본(크라켄) = 리버스 드라이브와 완전 동조 차지만 뚫는다
func blocks_strike(hit: Dictionary, kind: String, _perfect: bool, strong: bool) -> bool:
	return hit.get("kind", "") == "shield" and kind != "power" and not (kind == "charge" and strong)


func damage(hit: Dictionary, dmg: int) -> bool:
	if hit["kind"] == "core":
		return damage_core(dmg)
	damage_part(int(hit["idx"]), dmg)
	return false


func damage_core(dmg: int) -> bool:
	return core.damage(dmg)


# ── 그리기 (공통 부분) ─────────────────────────────────
func _cap(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	draw_line(a, b, c, w)
	draw_circle(a, w * 0.5, c)
	draw_circle(b, w * 0.5, c)


func _draw_shards() -> void:
	for sd in shards:
		var pts: PackedVector2Array = sd["pts"]
		draw_set_transform(sd["pos"], float(sd["rot"]))
		draw_colored_polygon(pts, core.C_STEEL)
		var ol := pts.duplicate()
		ol.append(pts[0])
		draw_polyline(ol, core.C_STEEL_DARK, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0)


## 페이즈 1 표적: 평소엔 테두리 없이 가운데 약점 점 + 손상 단계(체력바 대신)만.
## 차지 중·패리 후 조준 중(focus_glow)에만 노릴 수 있는 표적을 빛과 테두리로 강조한다 (사거리 안이면 더 밝게). v0.48: 모든 콜로서스
func _draw_part_marks() -> void:
	if phase != 1 or dead:
		return
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	for i in part_count():
		if not part_alive(i):
			continue
		var p := part_pos(i)
		var r := part_radius(i)
		if focus_glow > 0.0:
			var in_reach := p.distance_to(focus_from) <= focus_reach
			draw_circle(p, r * 1.7, Color(C_HEART, focus_glow * (0.3 if in_reach else 0.12) * (0.6 + 0.4 * pulse)))
			draw_arc(p, r + 6.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.5, focus_glow * (0.9 if in_reach else 0.35)), 3.0)
			if in_reach:
				draw_arc(p, r * 1.7, 0.0, TAU, 32, Color(1.0, 0.85, 0.55, focus_glow * 0.8), 3.0)
			if _part_highlight(i):              # 요격으로 멈춘 팔 등: 크게 빛난다
				draw_circle(p, r * 1.3 + 8.0 * pulse, Color(1.0, 0.75, 0.4, 0.35 * focus_glow))
		var flick := 1.0
		if part_stage[i] >= 3:                  # 거의 부서짐: 약점 빛이 깜빡인다
			flick = 0.4 + 0.6 * float(int(t * 9.0 + i) % 3 != 0)
		_draw_part_outline(i, p, r, flick)
		var cc := Color(C_HEART, 0.85 * flick).lerp(Color.WHITE, part_flash[i])
		draw_circle(p, r * 0.14, cc)
		_draw_part_damage(i, p, r, pulse)


## 표적 테두리: 칠 수 있는 부위의 가장자리가 금빛으로 천천히 숨쉬듯 빛난다 (평소에도 어딜 칠지 보이게, 얇고 은은하게).
## 겨눈 쪽(조준 방향·거리 안)이면 조금 더 밝고 굵게. 손상 2단계부터 테두리가 끊기고, 3단계는 깜빡인다
func _draw_part_outline(i: int, p: Vector2, r: float, flick: float) -> void:
	var breathe := 0.5 + 0.5 * sin(t * 2.2 + i * 1.3)
	var to := p - aim_from
	var aimed := to.length() < 1600.0 and to.normalized().dot(aim_dir) > cos(0.22)
	var a := (0.55 + 0.25 * breathe + (0.2 if aimed else 0.0)) * flick
	var col := Color(1.0, 0.84, 0.45, minf(1.0, a)).lerp(Color.WHITE, part_flash[i])
	var w := 4.0 + (2.0 if aimed else 0.0)
	var pts := part_outline(i)
	var glow_c := Color(1.0, 0.7, 0.3, (0.12 + 0.1 * breathe + (0.12 if aimed else 0.0)) * flick)   # 바깥 번짐 (어두운 몸에서 잘 보이게)
	if pts.is_empty():
		draw_arc(p, r + 6.0, 0.0, TAU, 40, glow_c, w * 4.0)
	else:
		var gl := pts.duplicate()
		gl.append(pts[0])
		draw_polyline(gl, glow_c, w * 4.0)
	if pts.is_empty():
		var rr := r + 6.0
		if part_stage[i] >= 2:
			for k in 8:
				var a0 := k * TAU / 8.0 + i
				draw_arc(p, rr, a0, a0 + TAU / 8.0 * 0.62, 6, col, w)
		else:
			draw_arc(p, rr, 0.0, TAU, 40, col, w)
		return
	var closed := pts.duplicate()
	closed.append(pts[0])
	if part_stage[i] >= 2:                         # 끊긴 테두리: 변마다 가운데 일부만
		for k in pts.size():
			var a1: Vector2 = pts[k]
			var b1: Vector2 = pts[(k + 1) % pts.size()]
			draw_line(a1.lerp(b1, 0.12), a1.lerp(b1, 0.7), col, w)
	else:
		draw_polyline(closed, col, w)


## 외부 시스템 손상: 1 긁힘 → 2 빛나는 균열 + 불꽃 → 3 떨어져 나간 자리 + 연기
func _draw_part_damage(i: int, p: Vector2, r: float, pulse: float) -> void:
	var st: int = part_stage[i]
	if st <= 0:
		return
	var base := i * 1.7
	for k in 3:
		var a := base + k * 2.1
		var c0 := p + Vector2.from_angle(a) * r * 0.55
		draw_line(c0, c0 + Vector2.from_angle(a + 1.9) * r * 0.5, Color(0.75, 0.78, 0.84, 0.6), 2.5)
	if st >= 2:
		for k in 3:
			var a := base + 0.6 + k * 2.1
			var q0 := p + Vector2.from_angle(a) * r * 0.3
			var q1 := q0 + Vector2.from_angle(a + 0.4) * r * 0.4
			var q2 := q1 + Vector2.from_angle(a - 0.3) * r * 0.4
			draw_polyline(PackedVector2Array([q0, q1, q2]), Color(1.0, 0.55, 0.25, 0.6 + 0.35 * pulse), 3.0)
		if fmod(t * 3.0 + i * 0.37, 1.0) < 0.25:
			for k in 3:
				var sa := t * 11.0 + k * 2.0 + i
				draw_circle(p + Vector2.from_angle(sa) * r * (0.6 + 0.4 * fmod(t * 4.0 + k, 1.0)), 2.5, Color(1.0, 0.85, 0.5))
	if st >= 3:
		var nc := p + Vector2.from_angle(base + 2.5) * r * 0.85
		draw_circle(nc, r * 0.35, C_CAVITY)
		draw_circle(nc, r * 0.18, Color(C_HEART, 0.35 + 0.3 * pulse))
		for k in 4:
			var life := fmod(t * 0.6 + k * 0.25 + i * 0.13, 1.0)
			var sp := p + Vector2(sin(t + k * 1.7) * 14.0 + (k - 1.5) * 10.0, -r * 0.5 - life * 160.0)
			draw_circle(sp, 12.0 + life * 26.0, Color(0.32, 0.33, 0.36, 0.45 * (1.0 - life)))


# ── 콜로서스마다 채울 것 ───────────────────────────────
func part_count() -> int:
	return 0


func part_max_hp(_i: int) -> int:
	return 24


func part_pos(_i: int) -> Vector2:
	return Vector2.ZERO


## 표적 테두리 모양 (월드 좌표 꼭짓점). 비우면 part_radius 원
func part_outline(_i: int) -> PackedVector2Array:
	return PackedVector2Array()


func part_radius(_i: int) -> float:
	return 60.0


## 부위가 부서지는 순간 (떨어져 나가는 잔해 등)
func _on_part_broken(_i: int) -> void:
	pass


## 약점 표시를 크게 빛낼 부위인가 (예: 요격으로 멈춘 팔의 관절)
func _part_highlight(_i: int) -> bool:
	return false


## 쉬는 시간이 끝나면 다음 공격을 고른다 (start_attack 으로 시작)
func _choose(_ppos: Vector2) -> void:
	pass


## 공격이 끝났을 때 자세 정리 등
func _on_attack_finished() -> void:
	pass


## 매 프레임 (죽은 뒤에도) 도는 연출 값 감쇠·잔해 등
func _step_effects(_dt: float) -> void:
	pass


## 살아 있을 때만 도는 발광 감쇠 등 (개방 진행 다음)
func _step_phase(_dt: float) -> void:
	pass
