extends "res://scripts/attacks/attack.gd"
## 코어 포대 (탄막 요새의 시그니처, 겨누는 사격): 가운데 포방패가 열리고 장갑에 싸인 에너지 코어가 드러나 힘을 모은 뒤,
## 잔탄 고리(호위탄)에 싸인 대구경 포탄(크고 느린 금색 주탄)을 만들어 쏜다. 쏜 뒤에도 코어는 드러나 있다 —
## 포탄이 날아가는 동안, 플레이어가 받아 내 조준하는 동안, 그리고 조금 더. 그동안 포대가 표적으로 드러난다(강조).
## 드러난 포가 맞으면 휘청이며 멈췄다가(stagger) 들어가고 포방패가 닫힌다. 맞지 않아도 시간이 지나면 들어간다.
## 단독 패턴 (v0.77): 다른 공격과 겹치지 않는다. 대신 쏘는 순간 코어가 사방으로 잔탄을 흩뿌리고(플레이어 쪽 부채꼴만 비움),
## 포탄이 나는 동안 몇 번 더 뿜는다 — 화면은 압도적이지만 실제로 플레이어를 노리는 건 주탄(포탄)뿐이다.
## boss 에 필요한 것: gun_open(0~1), gun_aim(라디안), gun_recoil, gun_exposed, gun_center(), gun_muzzle(), emit, shots

const Projectiles := preload("res://scripts/projectiles.gd")
const OPEN := 0.7                    # 포방패가 열리고 코어가 드러난다
const AIM := 1.1                     # 에너지를 모은다 (코어가 달아오르고 빛 알갱이가 빨려 든다)
const SHELL_SPEED := 250.0           # 느리게 다가오되 플레이어를 쫓는다 (projectiles SHELL_HOME) — 압도적이고 위협적으로
const SHELL_LIFE := 11.0
const ESCORT := 20                   # 호위탄 수 (빽빽하게: 고리 사이로 빠져나갈 틈이 없다 — 돌진으로 뚫고 들어가야 한다)
const ESCORT_R := 120.0              # 호위탄 고리 반지름 (포탄 둘레를 돌며 따라간다)
const LINGER := 0.4                  # 포탄이 사라지고 조준도 끝난 뒤 더 머무는 시간 (리버스 드라이브가 날아가 닿을 만큼)
const MAX_OUT := 12.0                # 그래도 이만큼 지나면 들어간다
const STAGGER := 0.9                 # 맞으면 휘청이며 멈춘다
const SCATTER := 26                  # 쏘는 순간 사방으로 흩뿌리는 잔탄 수 (플레이어 쪽 부채꼴 제외)
const SCATTER_AFTER := 14            # 포탄이 나는 동안 뿜는 잔탄 수
const SCATTER_EVERY := 1.0
const SCATTER_TIMES := 2             # 쏜 뒤 더 뿜는 횟수
const SCATTER_GAP := 0.75            # 비워 두는 부채꼴 반각 (플레이어·포탄 쪽)
const SCATTER_SPEED := Vector2(150.0, 300.0)
const SCATTER_LIFE := 6.0

var fired_t := -1.0
var calm_t := 0.0                    # 포탄도 조준도 없이 지난 시간
var scatters := 0


func _init() -> void:
	kind = "big_gun"
	phase = "open"


func step(dt: float, ppos: Vector2) -> void:
	match phase:
		"open":
			boss.gun_open = minf(1.0, t / OPEN)
			_track(ppos, dt)
			if t >= OPEN:
				set_phase("aim")
				boss.gun_exposed = true
				_scatter(SCATTER_AFTER, (ppos - boss.gun_center()).angle())   # 열리며 한 번 뿜는다 (모으는 동안 비지 않게)
		"aim":
			_track(ppos, dt)
			boss.gun_heat = minf(1.0, t / AIM)
			if t >= AIM:
				_fire()
				_scatter(SCATTER, boss.gun_aim)
				set_phase("out")
		"out":
			boss.gun_heat = move_toward(boss.gun_heat, 0.0, dt * 2.0)
			if scatters < SCATTER_TIMES and t >= SCATTER_EVERY * (scatters + 1) and _shell_alive():
				scatters += 1
				_scatter(SCATTER_AFTER, (ppos - boss.gun_center()).angle())
			var busy: bool = _shell_alive() or boss.focus_glow > 0.0
			calm_t = 0.0 if busy else calm_t + dt
			if calm_t >= LINGER or t >= MAX_OUT:
				_close()
		"stagger":
			if t >= STAGGER:
				_close()


## 겨누기: 플레이어 쪽으로 천천히 돈다 (코어가 몸 가운데에 있어 어느 쪽이든 겨눈다)
func _track(ppos: Vector2, dt: float) -> void:
	var want: float = (ppos - boss.gun_center()).angle()
	boss.gun_aim = lerp_angle(boss.gun_aim, want, 1.0 - exp(-4.0 * dt))


func _fire() -> void:
	var m: Vector2 = boss.gun_muzzle()
	var v: Vector2 = Vector2.from_angle(boss.gun_aim) * SHELL_SPEED * boss.bolt_mult()
	var g := Projectiles.new_group()
	boss.shots.spawn(m, v, SHELL_LIFE, Projectiles.WARMUP, 0.0, Projectiles.Kind.SHELL, g)
	for k in ESCORT:
		var a := k * TAU / ESCORT
		boss.shots.spawn(m + Vector2.from_angle(a) * ESCORT_R, v, SHELL_LIFE, Projectiles.WARMUP, 0.0, Projectiles.Kind.SMALL, g, a, ESCORT_R)
	boss.gun_recoil = 1.0
	boss.emit(Ev.STOMP, m)
	boss.emit(Ev.BOLT, m)


## 흩뿌리는 잔탄: 코어에서 사방으로, 비울 방향(skip, 플레이어·포탄 쪽) 부채꼴만 빼고 속도와 각도를 조금씩 흐트러뜨린다
func _scatter(n: int, skip: float) -> void:
	var c: Vector2 = boss.gun_center()
	var span := TAU - SCATTER_GAP * 2.0
	for k in n:
		var a := skip + SCATTER_GAP + span * (k + randf_range(0.2, 0.8)) / n
		var v: Vector2 = Vector2.from_angle(a) * randf_range(SCATTER_SPEED.x, SCATTER_SPEED.y) * boss.bolt_mult()
		boss.shots.spawn(c + Vector2.from_angle(a) * 150.0, v, SCATTER_LIFE, Projectiles.WARMUP, 0.0, Projectiles.Kind.SMALL)


func _shell_alive() -> bool:
	var sh = boss.shots
	for i in sh.size():
		if sh.kind[i] == Projectiles.Kind.SHELL and sh.mine[i] == 0:
			return true
	return false


## 드러난 포가 맞았다 (fortress.damage_part): 휘청이며 멈췄다가 들어간다
func hit() -> void:
	if phase == "out" or phase == "aim" or phase == "open":
		set_phase("stagger")


## 들어간다: 포방패가 닫히는 그림은 요새가 마저 그린다 (이 패턴은 바로 끝나 다음 공격이 이어진다)
func _close() -> void:
	boss.gun_exposed = false
	set_phase("end")
	boss.finish_attack()


func melee_warning() -> bool:
	return false
