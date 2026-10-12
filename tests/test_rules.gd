extends SceneTree
# dash-rework: 무제한 돌진(쿨다운) / 차지 / 반사 / 받아치기 / 팔 패리 / 접촉 피해 / 코어

var main
var fails := 0
var started := false
const DT := 1.0 / 60.0


class FakeStick:                 # 헤드리스에선 마우스가 (0,0)이라 조준이 덮어써진다 → 스틱 0 = 조준 유지
	var stick := Vector2.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	if started:
		return false
	started = true
	_run()
	_hold_test()
	_sync_test()
	_telemetry_test()
	print("FAILS ", fails)
	quit(fails)
	return false


func _step(n: int) -> void:
	for i in n:
		main._physics_process(DT)


func _air(pos: Vector2) -> void:
	main.reset_run()
	main.boss.next_t = 99.0
	main.player.reset(pos, false)
	main.player.aim = Vector2.RIGHT


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1


## 마우스가 (0,0)이라 매 프레임 조준이 덮어써지므로, 돌진은 직접 방향을 정해 쏜다
func _dash_dir(kind: String, d: Vector2) -> void:
	var p = main.player
	p.aim = d.normalized()
	p._dash(kind)


func _run() -> void:
	var b = main.boss
	var p = main.player
	main.touch_ui = FakeStick.new()

	_check("numbers (cd %.2f, dmg %d/%d/%d/%d, part %d, core %d)" % [p.DASH_COOLDOWN, p.DASH_DAMAGE, p.CHARGE_DAMAGE, p.POWER_DAMAGE, p.CLASH_DAMAGE, b.PART_HP, b.CORE_HP],
		p.DASH_COOLDOWN == 0.7 and p.DASH_DAMAGE == 1 and p.CHARGE_DAMAGE == 3 and p.POWER_DAMAGE == 12 and p.POWER_DAMAGE_PERFECT == 16 and p.CLASH_DAMAGE == 8 and b.PART_HP == 24 and b.ARMOR_HP == 160 and b.CORE_HP == 1)

	# ── 돌진: 짧게 = 돌진, 쿨다운 ──
	_air(Vector2(-900, -1500))
	main._dash_input(true)
	_step(2)
	main._dash_input(false)
	_check("tap -> dash", p.dash_kind == "dash" and p.dash_t > 0.0 and absf(p.dash_cd - p.DASH_COOLDOWN) < 0.05)
	_step(int(0.3 / DT))
	main._dash_input(true)
	main._dash_input(false)
	_check("tap during long cooldown ignored (cd %.2f)" % p.dash_cd, p.dash_t <= 0.0 and p.pending_kind == "")
	_step(int((p.dash_cd - 0.1) / DT))
	main._dash_input(true)
	main._dash_input(false)
	_check("tap near end of cooldown buffered", p.pending_kind == "dash")
	_step(8)
	_check("buffered dash fires when ready", p.dash_kind == "dash" and p.dash_t > 0.0)
	_check("unlimited: no gauge left in player", not ("gauge" in p))

	# 위쪽 관성은 남기지 않는다
	_air(Vector2(-900, -1500))
	_dash_dir("dash", Vector2.UP)
	_step(int(0.3 / DT))
	_check("up dash keeps momentum (vy %.0f)" % p.vel.y, p.dash_t <= 0.0 and p.vel.y < -300.0)

	# ── 차지 ──
	_air(Vector2(-900, -1500))
	main._dash_input(true)
	_step(int(0.7 / DT))
	_check("hold -> charged", p.is_charged())
	main._dash_input(false)
	_check("release charged -> charge dash", p.dash_kind == "charge")
	_air(Vector2(-900, -1500))
	main._dash_input(true)
	_step(int(0.3 / DT))
	main._dash_input(false)
	_check("partial charge release -> normal dash", p.dash_kind == "dash")
	# 쿨다운 중 다 모은 차지는 쿨다운이 끝나면 나간다
	_air(Vector2(-900, -1500))
	p.dash_cd = 0.6
	main._dash_input(true)
	p.dash_cd = 0.6
	_step(int(0.62 / DT))
	main._dash_input(false)
	_check("charged release during cooldown is kept (pending %s)" % p.pending_kind, p.pending_kind == "charge" or p.dash_kind == "charge")
	_step(int(0.2 / DT))
	_check("pending charge fires after cooldown", p.dash_kind == "charge" or p.charge_t > 0.0)

	# ── 타격 + 솟구침 (v0.6 방식) ──
	var pp: Vector2 = b.part_pos(0)
	_air(pp + Vector2(-140, 0))
	_dash_dir("dash", Vector2.RIGHT)
	var cd_before: float = p.dash_cd
	_step(6)
	_check("dash hit part: 1 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == 23)
	_check("rises after hit (vy %.0f, up=%.0f)" % [p.vel.y, p.BOUNCE_UP], p.vel.y < -p.BOUNCE_UP * 0.9 and p.vel.y > -p.BOUNCE_UP * 1.4)
	_check("pushed to opposite side of approach (vx %.0f)" % p.vel.x, p.vel.x < 0.0 and p.vel.x > -400.0)
	_check("cooldown not reset on hit (cd %.2f)" % p.dash_cd, p.dash_cd > 0.4 and p.dash_cd <= cd_before)
	_check("bounce height reduced vs v0.6 (1050 -> %.0f)" % p.BOUNCE_UP, p.BOUNCE_UP < 1050.0 and p.BOUNCE_UP >= 800.0)
	_air(pp + Vector2(0, 140))
	_dash_dir("dash", Vector2.UP)
	_step(6)
	_check("hit from below also rises (vy %.0f)" % p.vel.y, p.vel.y < -p.BOUNCE_UP * 0.9)
	_air(pp + Vector2(-140, 0))
	main.touch_ui.stick = Vector2(1, 0)
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("steer with mouse x (vx %.0f)" % p.vel.x, p.vel.x > 300.0)
	main.touch_ui.stick = Vector2(-1, 0)
	_air(pp + Vector2(-140, 0))
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("steer other way (vx %.0f)" % p.vel.x, p.vel.x < -800.0)
	main.touch_ui.stick = Vector2.ZERO
	_air(pp + Vector2(-140, 0))
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	var vy_dash: float = p.vel.y
	_air(pp + Vector2(-160, 0))
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	_check("charge rises higher than dash (%.0f vs %.0f)" % [p.vel.y, vy_dash], p.vel.y < vy_dash)

	_air(pp + Vector2(-160, 0))
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	_check("charge hit: 3 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == 21)
	_air(pp + Vector2(-160, 0))
	p.buffed = true
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	_check("buffed charge: x2 = 6 (hp %d)" % b.part_hp[0], b.part_hp[0] == 18 and not p.buffed)
	_air(pp + Vector2(-200, 0))
	p.aim_phase = true
	p.aim_perfect = false
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_step(6)
	_check("parry dash: 12 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == 12)
	_check("part damage stage 2 at 50%% (stage %d)" % b.part_stage[0], b.part_stage[0] == 2)

	# ── 접촉: 돌진 중이 아니면 표적을 통과한다 (충돌·피해·스턴 없음) ──
	_air(pp + Vector2(-90, 0))
	p.vel = Vector2(600, 0)
	var lives0: int = main.lives
	var hp_c: int = b.part_hp[0]
	_step(30)
	_check("no contact: passes through target (x %.0f, lives %d, stun %.2f)" % [p.position.x, main.lives, p.stun], p.position.x > pp.x + 40.0 and main.lives == lives0 and p.stun <= 0.0 and b.part_hp[0] == hp_c)
	_air(b.HEART_POS + Vector2(-380, 0))
	p.vel = Vector2(600, 0)
	_step(60)
	_check("no contact with core shell either (lives %d)" % main.lives, main.lives == main.LIVES and p.stun <= 0.0)

	# ── 퍼펙트 회피 ──
	_air(Vector2(-700, -1500))
	_dash_dir("dash", Vector2.RIGHT)
	b.bolts.append({"pos": p.position + Vector2(20, 0), "vel": Vector2.ZERO, "life": 5.0, "age": 0.0})
	_step(1)
	_check("perfect evade: buff, cd reset to dash end", p.buffed and p.dash_cd <= p.dash_t + 0.001 and main.slowmo > 0.0)
	_check("buffed charge needs half time", is_equal_approx(p.charge_need(), p.CHARGE_TIME * 0.5))
	_air(Vector2(-700, -1500))
	_dash_dir("dash", Vector2.RIGHT)
	_step(int(0.15 / DT))
	b.bolts.clear()
	b.bolts.append({"pos": p.position, "vel": Vector2.ZERO, "life": 5.0, "age": 0.0})
	main.slowmo = 0.0
	_step(1)
	_check("late graze: no reward, no slowmo", not p.buffed and main.slowmo <= 0.0)

	# ── 패리 불가(레이저) 퍼펙트 회피 = 강한 버프 4배 ──
	_air(Vector2(-300, -1500))
	_dash_dir("dash", Vector2.RIGHT)
	b.atk = {"kind": "beam", "phase": "sweep", "t": b.BEAM_SWEEP * 0.5, "th": 1.57, "th_prev": 1.6}
	var rel: Vector2 = Vector2.from_angle(1.565) * 400.0
	p.position = b.HEAD_POS + rel
	p.dash_t = 0.2
	main.slowmo = 0.0
	_step(1)
	_check("beam perfect dodge: strong buff (buffed %s, strong %s, slowmo %.2f)" % [p.buffed, p.buff_strong, main.slowmo], p.buffed and p.buff_strong and main.slowmo >= 0.45)
	b.atk = {}
	var hp_core: int = b.core_hp
	b.phase = 1
	var pp2: Vector2 = b.part_pos(0)
	_air(pp2 + Vector2(-160, 0))
	p.buffed = true
	p.buff_strong = true
	_dash_dir("charge", Vector2.RIGHT)
	var hp_a: int = b.part_hp[0]
	_step(6)
	_check("strong buffed charge: x4 = 12 (hp %d -> %d)" % [hp_a, b.part_hp[0]], b.part_hp[0] == hp_a - 12 and not p.buff_strong and not p.buffed)
	_check("strong hit gets perfect-parry level impact (hitstop %.2f shake %.0f)" % [main.hitstop, main.shake], main.hitstop >= 0.1 and main.shake >= 20.0)
	_air(pp2 + Vector2(-160, 0))
	p.buffed = true
	p.buff_strong = false
	_dash_dir("charge", Vector2.RIGHT)
	hp_a = b.part_hp[0]
	_step(6)
	_check("normal buffed charge still x2 = 6 (hp %d -> %d)" % [hp_a, b.part_hp[0]], b.part_hp[0] == hp_a - 6)
	_air(Vector2(-700, -1500))
	p.buffed = true
	p.buff_strong = true
	p.on_hurt(Vector2.RIGHT)
	_check("hit clears strong buff", not p.buffed and not p.buff_strong)

	# ── 탄 패리 → 조준 ──
	_air(Vector2(-700, -1500))
	b.bolts.clear()
	p.parry_press()
	b.bolts.append({"pos": p.position + Vector2(25, 0), "vel": Vector2.ZERO, "life": 5.0, "age": 0.0})
	_step(1)
	_check("bolt parry -> aim phase", p.aim_phase)
	p.parry_release()

	# ── 팔: 받아치기 / 그냥 패리 ──
	_air(Vector2(-700, -1500))
	b.bolts.clear()
	b.atk = {"kind": "swing", "phase": "swing", "t": 0.0, "arm": 1, "th0": 1.0, "th1": 1.0, "th": 1.0}
	b.fists[1] = b._arm_fist(1, 1.0)
	var mid: Vector2 = b.SHOULDERS[1].lerp(b.fists[1], 0.8)
	var side: Vector2 = (b.fists[1] - b.SHOULDERS[1]).orthogonal().normalized()
	_air(mid + side * 220.0)
	b.atk = {"kind": "swing", "phase": "swing", "t": 0.0, "arm": 1, "th0": 1.0, "th1": 1.0, "th": 1.0}
	b.fists[1] = b._arm_fist(1, 1.0)
	var hp3: int = b.part_hp[3]
	_dash_dir("charge", -side)
	_step(4)
	_check("clash: joint takes 8 (hp %d -> %d)" % [hp3, b.part_hp[3]], b.part_hp[3] == hp3 - 8)
	_check("clash: arm recoils", b.atk.get("phase", "") == "recoil")
	_check("clash: player rises, no life lost", p.dash_t <= 0.0 and p.vel.y < -800.0 and main.lives == main.LIVES)

	# ── 사전 저지: 위치 고정 후 멈춰 있을 때(set/warn)는 차지 돌진으로 끊을 수 있고, 들어올리는 중(prep)은 아니다 ──
	for ph in ["set", "warn"]:
		_air(mid + side * 220.0)
		b.atk = {"kind": "swing", "phase": ph, "t": 0.2, "arm": 1, "th0": 1.0, "th1": 2.0, "th": 1.0}
		b.fists[1] = b._arm_fist(1, 1.0)
		hp3 = b.part_hp[3]
		_dash_dir("charge", -side)
		_step(4)
		_check("pre-swing interrupt in %s: joint -8, attack cut (hp %d->%d, phase %s)" % [ph, hp3, b.part_hp[3], b.atk.get("phase", "")], b.part_hp[3] == hp3 - 8 and b.atk.get("phase", "") == "recoil")
	_air(mid + side * 220.0)
	b.atk = {"kind": "swing", "phase": "prep", "t": 0.2, "arm": 1, "th0": 1.0, "th1": 2.0, "th": 1.0, "from": b.fists[1]}
	b.fists[1] = b._arm_fist(1, 1.0)
	hp3 = b.part_hp[3]
	_dash_dir("charge", -side)
	_step(4)
	_check("no interrupt while arm is still lifting (prep)", b.part_hp[3] == hp3 and b.atk.get("phase", "") == "prep")
	_air(mid + side * 220.0)
	b.atk = {"kind": "swing", "phase": "warn", "t": 0.2, "arm": 1, "th0": 1.0, "th1": 2.0, "th": 1.0}
	b.fists[1] = b._arm_fist(1, 1.0)
	hp3 = b.part_hp[3]
	_dash_dir("dash", -side)
	_step(4)
	_check("normal dash does not interrupt", b.part_hp[3] == hp3 and b.atk.get("phase", "") == "warn")

	_air(mid + side * 100.0)
	b.atk = {"kind": "swing", "phase": "swing", "t": 0.0, "arm": 1, "th0": 1.0, "th1": 1.0, "th": 1.0}
	b.fists[1] = b._arm_fist(1, 1.0)
	hp3 = b.part_hp[3]
	p.parry_press()
	p.vel = -side * 400.0
	_step(4)
	_check("arm parry: no aim, no damage, pushed (|v| %.0f)" % p.vel.length(), not p.aim_phase and b.part_hp[3] == hp3 and main.lives == main.LIVES and p.vel.length() > 600.0)
	_check("arm parry: arm keeps swinging", b.atk.get("phase", "") == "swing")
	p.parry_release()

	# ── 코어: 껍질(체력 160)을 다 부수고 나서도 한 발을 더 맞혀야 부서진다 ──
	main.reset_run()
	b.next_t = 99.0
	for i in 4:
		b.damage_part(i, 99)
	_check("all parts -> chest opens", b.phase == 2)
	_step(int((b.OPEN_TIME + 1.0) / DT))
	_check("core phase", b.phase == 3)
	b.next_t = 99.0
	b.atk = {}
	var alive0: int = b.plates.size() - b.plates.filter(func(pl): return pl["gone"]).size()
	_check("irregular plates built (%d plates)" % b.plates.size(), b.plates.size() >= 6)
	b.damage_core(32)
	_check("armor 20%%: stage 1, armor_hp %d" % b.armor_hp, b.core_stage == 1 and b.armor_hp == 128 and not b.armor_broken)
	b.damage_core(64)
	var gone_mid: int = b.plates.filter(func(pl): return pl["gone"]).size()
	_check("armor 60%%: plates falling one by one (gone %d / %d), shards %d" % [gone_mid, b.plates.size(), b.shards.size()], gone_mid >= 1 and gone_mid < b.plates.size() and b.shards.size() == gone_mid)
	var died: bool = b.damage_core(9999)
	_check("overkill breaks armor but NOT the core (armor %d, broken %s, died %s, core_hp %d)" % [b.armor_hp, b.armor_broken, died, b.core_hp], b.armor_hp == 0 and b.armor_broken and not died and b.core_hp == b.CORE_HP and b.plates.all(func(pl): return pl["gone"]))
	var again: bool = b.damage_core(50)
	_check("core guard right after armor break (no kill within guard)", not again and b.core_hp == b.CORE_HP)
	_step(90)
	var hc: Vector2 = b.HEART_POS
	p.reset(hc + Vector2(-420, 0), false)
	p.aim = Vector2.RIGHT
	_dash_dir("dash", Vector2.RIGHT)
	main.hitstop = 0.0
	_step(14)
	_check("one more hit on the exposed core destroys it -> win", main.state == main.State.WON and b.dead)


## 발판 위에서는 공격이 시작되지 않고, 날아오른 뒤 시작된다
func _hold_test() -> void:
	var b = main.boss
	var p = main.player
	main.reset_run()
	b.next_t = 0.0
	p.reset(main.SPAWN, true)
	_step(120)
	_check("no attack while standing on platform (atk %s)" % str(b.atk.get("kind", "")), b.atk.is_empty() and b.bolts.is_empty())
	p.on_platform = false
	p.position = Vector2(300, -1200)
	p.vel = Vector2.ZERO
	p.invuln = 99.0
	_step(150)
	_check("attacks start after launch (atk %s)" % str(b.atk.get("kind", "")), not b.atk.is_empty() or not b.bolts.is_empty() or b.next_t > 0.0 and b.next_t < 3.0)


## 동조(퍼펙트 회피 버프): 4초 지속, 다시 얻으면 갱신, 끝날 무렵 시전한 차지 강습은 끝날 때까지 유지,
## 슬로우 중엔 느리게 줄어든다. 요격에는 강한 버프(4배)가 걸리지 않는다
func _sync_test() -> void:
	var b = main.boss
	var p = main.player
	_air(Vector2(-700, -1500))
	b.bolts.clear()
	_dash_dir("dash", Vector2.RIGHT)
	b.bolts.append({"pos": p.position + Vector2(20, 0), "vel": Vector2.ZERO, "life": 5.0, "age": 0.0})
	_step(1)
	b.bolts.clear()
	_check("sync starts at %.1fs" % p.buff_t, p.buffed and absf(p.buff_t - p.SYNC_TIME) < 0.1)
	main.slowmo = 0.0
	main.hitstop = 0.0
	_step(int(2.0 / DT))
	_check("sync ticking (%.2fs left)" % p.buff_t, p.buffed and p.buff_t < p.SYNC_TIME - 1.5)
	p.evade_window = 0.1
	p.evade_rewarded = false
	p.dash_kind = "dash"
	p.dash_t = 0.2
	p.try_evade_reward()
	_check("regaining sync refreshes to full (%.2fs)" % p.buff_t, absf(p.buff_t - p.SYNC_TIME) < 0.01)
	main.slowmo = 0.0
	main.hitstop = 0.0
	_step(int((p.SYNC_TIME + 0.3) / DT))
	_check("sync expires after 4s", not p.buffed)
	# 슬로우(조준) 중엔 느리게 줄어든다
	_air(Vector2(-700, -1500))
	p.buffed = true
	p.buff_t = 2.0
	p.aim_phase = true
	p.aim_left = 99.0
	_step(60)
	_check("sync decays slowly during aim slow-mo (%.2fs left after 1s)" % p.buff_t, p.buffed and p.buff_t > 1.85)
	p.aim_phase = false
	# 끝날 무렵 시전한 차지 강습은 끝날 때까지 유지
	_air(Vector2(-700, -1500))
	p.buffed = true
	p.buff_t = 0.03
	_dash_dir("charge", Vector2.RIGHT)
	_step(5)
	_check("charge assault launched at the end keeps sync until it ends", p.buffed and p.dash_t > 0.0)
	_step(30)
	_check("sync cleared after that charge ends (miss)", not p.buffed)
	# 요격: 강한 버프여도 2배만
	_air(Vector2(-700, -1500))
	p.buffed = true
	p.buff_strong = true
	p.buff_t = 3.0
	_check("intercept uses x2 even with strong sync (dmg %d)" % p.clash_damage(), not p.buffed and not p.last_hit_strong)


## 플레이 기록: 한 판의 행동이 JSON 으로 남는다 (테스트 전용 폴더에 쓰고 지운다)
func _telemetry_test() -> void:
	var t = main.tele
	t.enabled = true
	t.dir = "user://telemetry_test"
	main.reset_run()
	t.add("parry_perfect")
	t.hit("charge", 3)
	t.hurt_by("beam")
	t.mark("part_break", 12.5)
	t.finish("dead", 42.0, 0, {"phase": 1})
	var ok := FileAccess.file_exists(t.last_path)
	var data = JSON.parse_string(FileAccess.get_file_as_string(t.last_path)) if ok else null
	_check("telemetry file written (%s)" % t.last_path, ok and data is Dictionary and data["result"] == "dead" and int(data["counts"]["parry_perfect"]) == 1 and int(data["damage"]["charge"]) == 3 and int(data["hurt"]["beam"]) == 1)
	if ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(t.last_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry_test"))
	t.enabled = false
	t.dir = t.DIR
