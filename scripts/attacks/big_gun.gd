extends "res://scripts/attacks/attack.gd"
## 대구경 포 (탄막 요새의 시그니처, 겨누는 사격): 가운데 포방패가 열리고 안에서 큰 포가 밀려 나와 플레이어를 겨눈 뒤,
## 잔탄 고리(호위탄)에 싸인 대구경 포탄(크고 느린 금색 주탄)을 쏜다. 쏜 뒤에도 포는 밖에 남아 있다 —
## 포탄이 날아가는 동안, 플레이어가 받아 내 조준하는 동안, 그리고 조금 더. 그동안 포대가 표적으로 드러난다(강조).
## 드러난 포가 맞으면 휘청이며 멈췄다가(stagger) 들어가고 포방패가 닫힌다. 맞지 않아도 시간이 지나면 들어간다.
## boss 에 필요한 것: gun_open(0~1), gun_aim(라디안), gun_recoil, gun_exposed, gun_center(), gun_muzzle(), emit, shots

const Projectiles := preload("res://scripts/projectiles.gd")
const OPEN := 0.7                    # 포방패가 열리고 포가 나온다
const AIM := 0.9                     # 겨눈다 (포구가 달아오른다)
const SHELL_SPEED := 210.0           # 느리게 다가오되 플레이어를 쫓는다 (projectiles SHELL_HOME) — 압도적이고 위협적으로
const SHELL_LIFE := 11.0
const ESCORT := 20                   # 호위탄 수 (빽빽하게: 고리 사이로 빠져나갈 틈이 없다 — 돌진으로 뚫고 들어가야 한다)
const ESCORT_R := 120.0              # 호위탄 고리 반지름 (포탄 둘레를 돌며 따라간다)
const LINGER := 0.4                  # 포탄이 사라지고 조준도 끝난 뒤 더 머무는 시간 (리버스 드라이브가 날아가 닿을 만큼)
const MAX_OUT := 12.0                # 그래도 이만큼 지나면 들어간다
const STAGGER := 0.9                 # 맞으면 휘청이며 멈춘다

var fired_t := -1.0
var calm_t := 0.0                    # 포탄도 조준도 없이 지난 시간


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
		"aim":
			_track(ppos, dt)
			boss.gun_heat = minf(1.0, t / AIM)
			if t >= AIM:
				_fire()
				set_phase("out")
		"out":
			boss.gun_heat = move_toward(boss.gun_heat, 0.0, dt * 2.0)
			var busy: bool = _shell_alive() or boss.focus_glow > 0.0
			calm_t = 0.0 if busy else calm_t + dt
			if calm_t >= LINGER or t >= MAX_OUT:
				_close()
		"stagger":
			if t >= STAGGER:
				_close()


## 겨누기: 포신이 플레이어 쪽으로 천천히 돈다 (아래쪽 반원 안에서)
func _track(ppos: Vector2, dt: float) -> void:
	var want: float = (ppos - boss.gun_center()).angle()        # -PI ~ PI, 아래 = 양수
	if want < 0.0:                                        # 위쪽은 겨누지 않는다 (가까운 옆으로)
		want = 0.15 if want > -PI * 0.5 else PI - 0.15
	want = clampf(want, 0.15, PI - 0.15)
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
