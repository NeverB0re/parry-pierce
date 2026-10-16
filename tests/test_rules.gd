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
	_meta_test()
	_fortress_test()
	_v034_test()
	_v035_test()
	_v036_test()
	_v037_test()
	_v038_test()
	_v039_test()
	_v042_test()
	_v044_test()
	_v047_test()
	_i18n_test()
	_zone_test()
	_title_test()
	_telemetry_test()
	_satellite_test()
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


## 오른팔(1) 휘두르기를 원하는 단계·각도로 바로 세운다
func _swing(ph: String, tt: float, th0: float, th1: float) -> void:
	var b = main.boss
	var sw = b.Swing.new(1, 3, b.fists[1])
	b.start_attack(sw)
	sw.phase = ph
	sw.t = tt
	sw.th0 = th0
	sw.th1 = th1
	sw.th = th0
	b.fists[1] = sw.fist_at(1.0)


func _ph() -> String:
	var a = main.boss.atk
	return "" if a == null else a.phase


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

	_check("numbers (cd %.2f, dmg %d/%d/%d/%d, part %d, core %d)" % [p.stats.dash_cooldown, p.DASH_DAMAGE, p.stats.charge_damage, p.stats.power_damage, p.stats.clash_damage, b.PART_HP, b.core.CORE_HP],
		absf(p.stats.dash_cooldown - 0.9) < 0.001 and p.DASH_DAMAGE == 1 and p.stats.charge_damage == 3 and p.stats.power_damage == 8 and p.stats.power_damage_perfect == 16 and p.stats.clash_damage == 8 and b.PART_HP == 30 and b.ARMOR_HP == 160 and b.core.CORE_HP == 1)

	# ── 돌진: 짧게 = 돌진, 쿨다운 ──
	_air(Vector2(-900, -1500))
	main._dash_input(true)
	_step(2)
	main._dash_input(false)
	_check("tap -> dash", p.dash_kind == "dash" and p.dash_t > 0.0 and absf(p.dash_cd - p.stats.dash_cooldown) < 0.05)
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
	# 짧게 누르는 연속 돌진: 카메라 줌이 거의 변하지 않는다
	_air(Vector2(-900, -1500))
	main.cam.zoom = Vector2(main.CAM_ZOOM, main.CAM_ZOOM)
	var zmin := 9.0
	var zmax := 0.0
	for k in 6:
		main._dash_input(true)
		_step(6)
		main._dash_input(false)
		_step(40)
		zmin = minf(zmin, main.cam.zoom.x)
		zmax = maxf(zmax, main.cam.zoom.x)
	_check("tap dashes don't pump the camera zoom (%.3f..%.3f)" % [zmin, zmax], zmax - zmin < 0.01)

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
	# 차지 쿨다운: 차지 강습 뒤에는 다음 차지가 바로 완료되지 않는다
	_air(Vector2(-900, -1500))
	_dash_dir("charge", Vector2.RIGHT)
	_check("charge sets charge cooldown (%.2f)" % p.charge_cd, absf(p.charge_cd - p.stats.charge_cooldown) < 0.01 and p.stats.charge_cooldown >= 1.0)
	_step(int(0.75 / DT))
	main._dash_input(true)
	_step(int(0.62 / DT))
	_check("charge not complete during charge cooldown (cd %.2f, t %.2f)" % [p.charge_cd, p.charge_t], not p.is_charged())
	main._dash_input(false)
	_check("early release during charge cooldown -> normal dash", p.dash_kind == "dash")
	_air(Vector2(-900, -1500))
	_dash_dir("charge", Vector2.RIGHT)
	_step(int(0.75 / DT))
	main._dash_input(true)
	_check("no charge hover while charge cooldown runs (t %.2f)" % p.charge_t, p.charge_t == 0.0 and not p.is_hovering_charge())
	_step(int((p.charge_cd + 0.1) / DT))
	_check("charge starts only after charge cooldown (t %.2f)" % p.charge_t, not p.is_charged() and p.charge_t > 0.0)
	_step(int(p.charge_need() / DT))
	_check("then completes after a full charge time", p.is_charged())
	main._dash_input(false)
	_check("then fires a charge assault", p.dash_kind == "charge")

	# ── 타격 + 솟구침 (v0.6 방식) ──
	var pp: Vector2 = b.part_pos(0)
	_air(pp + Vector2(-140, 0))
	_dash_dir("dash", Vector2.RIGHT)
	var cd_before: float = p.dash_cd
	_step(6)
	_check("dash hit part: 1 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == b.PART_HP - 1)
	_check("rises a little after a side hit (vy %.0f, up=%.0f)" % [p.vel.y, p.stats.bounce_up], p.vel.y < -p.stats.bounce_up * 0.3 and p.vel.y > -p.stats.bounce_up * 0.9)
	_check("knocked back the way it came (vx %.0f)" % p.vel.x, p.vel.x < -500.0)
	_check("cooldown not reset on hit (cd %.2f)" % p.dash_cd, p.dash_cd > 0.4 and p.dash_cd <= cd_before)
	_check("bounce height reduced vs v0.6 (1050 -> %.0f)" % p.stats.bounce_up, p.stats.bounce_up < 1050.0 and p.stats.bounce_up >= 800.0)
	_air(pp + Vector2(0, 140))
	_dash_dir("dash", Vector2.UP)
	_step(6)
	_check("hit from below knocks the ship back down, away from the target (vy %.0f)" % p.vel.y, p.vel.y > 300.0)
	_air(pp + Vector2(0, -140))
	_dash_dir("dash", Vector2.DOWN)
	_step(6)
	_check("hit from above bounces up no harder than other directions (|v| %.0f, up=%.0f)" % [p.vel.length(), p.stats.bounce_up], p.vel.y < -300.0 and p.vel.length() <= p.stats.bounce_up * 1.1)
	_air(pp + Vector2(-140, 0))
	main.touch_ui.stick = Vector2(1, 0)
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("mouse still on the target does not pull the bounce back in (vx %.0f)" % p.vel.x, p.vel.x < -500.0)
	main.touch_ui.stick = Vector2.ZERO
	_air(pp + Vector2(-140, 0))
	main.touch_ui.stick = Vector2(-1, 0)
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("steering away with the mouse adds to the bounce (vx %.0f)" % p.vel.x, p.vel.x < -900.0)
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
	_check("charge hit: 3 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == b.PART_HP - 3)
	_air(pp + Vector2(-160, 0))
	p.buffed = true
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	_check("buffed charge: x2 = 6 (hp %d)" % b.part_hp[0], b.part_hp[0] == b.PART_HP - 6 and not p.buffed)
	_air(pp + Vector2(-200, 0))
	p.aim_phase = true
	p.aim_perfect = false
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_step(6)
	_check("normal parry drive: 8 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == b.PART_HP - 8)
	_check("normal parry drive: short invulnerability after the hit (shield %.2f)" % p.shield_t, p.shield_t > 0.0 and p.shield_t <= p.NORMAL_DRIVE_SHIELD + 0.001)
	_air(pp + Vector2(-200, 0))
	p.aim_phase = true
	p.aim_perfect = true
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_step(6)
	_check("PERFECT parry drive: 16 dmg + strike shield (hp %d, shield %.2f)" % [b.part_hp[0], p.shield_t], b.part_hp[0] == b.PART_HP - 16 and p.shield_t > 0.0)
	_check("part damage stage 1 at 60%% (stage %d)" % b.part_stage[0], b.part_stage[0] >= 1)
	_air(pp + Vector2(-600, 0))                           # 반사탄 피해: 잔탄 0.5 · 주탄 1 · 유도탄 3 (소수점은 모아서)
	var rhit: Dictionary = b.strike_hit(b.part_pos(0), 20.0)
	for k in 3:
		b.emit(b.Ev.REFLECT_HIT, b.part_pos(0), {"hit": rhit, "dmg": b.shots.REFLECT_DMG[b.shots.Kind.SMALL]})
	main._drain_boss_events()
	_check("reflected small bullets deal 0.5 each, carried over (hp %d, carry %.1f)" % [b.part_hp[0], main.reflect_carry], b.part_hp[0] == b.PART_HP - 1 and absf(main.reflect_carry - 0.5) < 0.01 and b.shots.REFLECT_DMG == [1.0, 1.0, 0.5, 3.0])

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
	_check("no contact with core shell either (lives %d)" % main.lives, main.lives == main.player.stats.shield_cells and p.stun <= 0.0)

	# ── 퍼펙트 회피 ──
	_air(Vector2(-700, -1500))
	_dash_dir("dash", Vector2.RIGHT)
	b.shots.spawn(p.position + Vector2(20, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("perfect evade: buff, cd reset to dash end", p.buffed and p.dash_cd <= p.dash_t + 0.001 and main.slowmo > 0.0)
	_check("buffed charge needs half time", is_equal_approx(p.charge_need(), p.stats.charge_time * 0.5))
	_air(Vector2(-700, -1500))
	_dash_dir("dash", Vector2.RIGHT)
	_step(int(0.15 / DT))
	b.shots.clear()
	b.shots.spawn(p.position, Vector2.ZERO, 5.0)
	main.slowmo = 0.0
	_step(1)
	_check("late graze: no reward, no slowmo", not p.buffed and main.slowmo <= 0.0)

	# ── 패리 불가(레이저) 퍼펙트 회피 = 강한 버프 4배 ──
	_air(Vector2(-300, -1500))
	_dash_dir("dash", Vector2.RIGHT)
	var bm = b.Beam.new(b.HEAD_POS)
	b.start_attack(bm)
	bm.phase = "sweep"
	bm.t = bm.SWEEP * 0.5
	bm.th = 1.57
	bm.th_prev = 1.6
	var rel: Vector2 = Vector2.from_angle(1.565) * 400.0
	p.position = b.HEAD_POS + rel
	p.dash_t = 0.2
	main.slowmo = 0.0
	_step(1)
	_check("beam perfect dodge: strong buff (buffed %s, strong %s, slowmo %.2f)" % [p.buffed, p.buff_strong, main.slowmo], p.buffed and p.buff_strong and main.slowmo >= 0.45)
	b.atk = null
	var hp_core: int = b.core.core_hp
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
	b.shots.clear()
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("bolt parry -> aim phase", p.aim_phase)
	p.parry_release()

	# ── 팔: 받아치기 / 그냥 패리 ──
	_air(Vector2(-700, -1500))
	b.shots.clear()
	_swing("swing", 0.0, 1.0, 1.0)
	var mid: Vector2 = b.SHOULDERS[1].lerp(b.fists[1], 0.8)
	var side: Vector2 = (b.fists[1] - b.SHOULDERS[1]).orthogonal().normalized()
	_air(mid + side * 220.0)
	_swing("swing", 0.0, 1.0, 1.0)
	var hp3: int = b.part_hp[3]
	_dash_dir("charge", -side)
	_step(4)
	_check("clash: joint takes 8 (hp %d -> %d)" % [hp3, b.part_hp[3]], b.part_hp[3] == hp3 - 8)
	_check("clash: arm recoils", _ph() == "recoil")
	_check("clash: player rises, no life lost", p.dash_t <= 0.0 and p.vel.y < -800.0 and main.lives == main.player.stats.shield_cells)

	# ── 사전 저지: 위치 고정 후 멈춰 있을 때(set/warn)는 차지 돌진으로 끊을 수 있고, 들어올리는 중(prep)은 아니다 ──
	for ph in ["set", "warn"]:
		_air(mid + side * 220.0)
		_swing(ph, 0.2, 1.0, 2.0)
		hp3 = b.part_hp[3]
		_dash_dir("charge", -side)
		_step(4)
		_check("pre-swing interrupt in %s: joint -8, attack cut (hp %d->%d, phase %s)" % [ph, hp3, b.part_hp[3], _ph()], b.part_hp[3] == hp3 - 8 and _ph() == "recoil")
	_air(mid + side * 220.0)
	_swing("prep", 0.2, 1.0, 2.0)
	hp3 = b.part_hp[3]
	_dash_dir("charge", -side)
	_step(4)
	_check("no interrupt while arm is still lifting (prep)", b.part_hp[3] == hp3 and _ph() == "prep")
	_air(mid + side * 220.0)
	_swing("warn", 0.2, 1.0, 2.0)
	hp3 = b.part_hp[3]
	_dash_dir("dash", -side)
	_step(4)
	_check("normal dash does not interrupt", b.part_hp[3] == hp3 and _ph() == "warn")

	_air(mid + side * 100.0)
	_swing("swing", 0.0, 1.0, 1.0)
	hp3 = b.part_hp[3]
	p.parry_press()
	p.vel = -side * 400.0
	_step(4)
	_check("arm parry: no aim, no damage, pushed (|v| %.0f)" % p.vel.length(), not p.aim_phase and b.part_hp[3] == hp3 and main.lives == main.player.stats.shield_cells and p.vel.length() > 600.0)
	_check("arm parry: arm keeps swinging", _ph() == "swing")
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
	b.atk = null
	var alive0: int = b.core.plates.size() - b.core.plates.filter(func(pl): return pl["gone"]).size()
	_check("irregular plates built (%d plates)" % b.core.plates.size(), b.core.plates.size() >= 6)
	b.damage_core(32)
	_check("armor 20%%: stage 1, armor_hp %d" % b.core.armor_hp, b.core.stage == 1 and b.core.armor_hp == 128 and not b.core.broken)
	b.damage_core(64)
	var gone_mid: int = b.core.plates.filter(func(pl): return pl["gone"]).size()
	_check("armor 60%%: plates falling one by one (gone %d / %d), shards %d" % [gone_mid, b.core.plates.size(), b.shards.size()], gone_mid >= 1 and gone_mid < b.core.plates.size() and b.shards.size() == gone_mid)
	var died: bool = b.damage_core(9999)
	_check("overkill breaks armor but NOT the core (armor %d, broken %s, died %s, core_hp %d)" % [b.core.armor_hp, b.core.broken, died, b.core.core_hp], b.core.armor_hp == 0 and b.core.broken and not died and b.core.core_hp == b.core.CORE_HP and b.core.plates.all(func(pl): return pl["gone"]))
	var again: bool = b.damage_core(50)
	_check("core guard right after armor break (no kill within guard)", not again and b.core.core_hp == b.core.CORE_HP)
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
	_check("no attack while standing on platform (atk %s)" % b.attack_kind(), b.atk == null and b.shots.is_empty())
	p.on_platform = false
	p.position = Vector2(300, -1200)
	p.vel = Vector2.ZERO
	p.invuln = 99.0
	_step(150)
	_check("attacks start after launch (atk %s)" % b.attack_kind(), b.atk != null or not b.shots.is_empty() or b.next_t > 0.0 and b.next_t < 3.0)


## 동조(퍼펙트 회피 버프): 4초 지속, 다시 얻으면 갱신, 끝날 무렵 시전한 차지 강습은 끝날 때까지 유지,
## 슬로우 중엔 느리게 줄어든다. 요격에는 강한 버프(4배)가 걸리지 않는다
func _sync_test() -> void:
	var b = main.boss
	var p = main.player
	_air(Vector2(-700, -1500))
	b.shots.clear()
	_dash_dir("dash", Vector2.RIGHT)
	b.shots.spawn(p.position + Vector2(20, 0), Vector2.ZERO, 5.0)
	_step(1)
	b.shots.clear()
	_check("sync starts at %.1fs" % p.buff_t, p.buffed and absf(p.buff_t - p.stats.sync_time) < 0.1)
	main.slowmo = 0.0
	main.hitstop = 0.0
	_step(int(2.0 / DT))
	_check("sync ticking (%.2fs left)" % p.buff_t, p.buffed and p.buff_t < p.stats.sync_time - 1.5)
	p.evade_window = 0.1
	p.evade_rewarded = false
	p.dash_kind = "dash"
	p.dash_t = 0.2
	p.try_evade_reward()
	_check("regaining sync refreshes to full (%.2fs)" % p.buff_t, absf(p.buff_t - p.stats.sync_time) < 0.01)
	main.slowmo = 0.0
	main.hitstop = 0.0
	_step(int((p.stats.sync_time + 0.3) / DT))
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
	t.pattern("pound", 3.0)
	t.pattern("pound", 9.5)
	t.md_path = "user://telemetry_test/log.md"                # 텔레메트리 빌드: 실행 파일 옆 md 요약 (여기서는 테스트 폴더)
	t.finish("dead", 42.0, 0, {"phase": 1, "stage": "kraken"})
	var ok := FileAccess.file_exists(t.last_path)
	var data = JSON.parse_string(FileAccess.get_file_as_string(t.last_path)) if ok else null
	_check("telemetry file written (%s)" % t.last_path, ok and data is Dictionary and data["result"] == "dead" and int(data["counts"]["parry_perfect"]) == 1 and int(data["damage"]["charge"]) == 3 and int(data["hurt"]["beam"]) == 1)
	t.begin()
	t.add("parry")
	t.finish("win", 80.0, 2, {"phase": 3, "stage": "kraken"})
	var md := FileAccess.get_file_as_string(t.md_path)
	_check("telemetry md log: two runs appended, readable summary (%d chars)" % md.length(), md.count("\n## ") == 2 and md.contains("kraken · dead · 0분 42초") and md.contains("보스 패턴: pound ×2") and md.contains("패턴 순서: 0:03 pound, 0:09 pound") and md.contains("피격: beam ×1"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(t.md_path))
	for fn in DirAccess.get_files_at("user://telemetry_test"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry_test/" + fn))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry_test"))
	t.md_path = ""
	t.enabled = false
	t.dir = t.DIR


## 메타 구조: 얻은 코어는 모두 영구 적용, 저장(구버전 저장 이전 포함), 승리 → 월드 맵 → FTL 도약 → 코어가 반영된 출격,
## 월드 맵에서 깬 스테이지 다시 고르기 (안 깬 곳·아직 없는 곳은 못 고름)
func _meta_test() -> void:
	var Up = main.Upgrades
	var base = main.Player.BASE_STATS
	var st = Up.build(base, ["counter", "reflect"])
	_check("all owned cores apply at once (counter %s, reflect %s)" % [st.counter, st.reflect], st.counter and st.reflect)
	_check("base stats untouched", not base.counter and not base.reflect)
	_check("no cores = base", not Up.build(base, []).counter)
	_check("skill tree is gone", not ("NODES" in Up) and not ("nodes" in main.Profile.new()))

	var pr = main.Profile.new()
	pr.path = "user://profile_test.cfg"
	pr.reset()
	var got: Dictionary = pr.record_clear(0)
	_check("first clear: gets the core", got["first"] and got["core"] == "counter" and pr.cores.size() == 1 and pr.cores[0] == "counter")
	var again: Dictionary = pr.record_clear(0)
	_check("re-clear gives nothing (no farming)", not again["first"] and again["core"] == "" and pr.cores.size() == 1)
	var pr2 = main.Profile.new()
	pr2.path = pr.path
	pr2.load_from_disk()
	_check("profile saved and loaded (cores %s, stage %d)" % [pr2.cores, pr2.stage], pr2.cores == pr.cores and pr2.cleared == pr.cleared and pr2.stage == 1)
	_check("one equip slot; the first core is equipped on pickup (%s)" % [pr.equipped], pr.slots() == 1 and pr.equipped == ["counter"] and pr2.equipped == ["counter"])
	pr.record_clear(1)
	_check("a new core is owned but not equipped while the slot is full (%s / %s)" % [pr.cores, pr.equipped], pr.cores.has("reflect") and pr.equipped == ["counter"])
	pr.toggle_equip("reflect")
	_check("equipping another core swaps it in (%s)" % [pr.equipped], pr.equipped == ["reflect"])
	var eq_st = Up.build(base, pr.equipped)
	_check("only the equipped core works (counter %s, reflect %s)" % [eq_st.counter, eq_st.reflect], eq_st.reflect and not eq_st.counter)
	pr.toggle_equip("reflect")
	pr.save()
	var pr4 = main.Profile.new()
	pr4.path = pr.path
	pr4.load_from_disk()
	_check("unequipping everything is kept after reload (%s)" % [pr4.equipped], pr.equipped.is_empty() and pr4.equipped.is_empty())
	_check("cannot equip a core you do not own", not pr.toggle_equip("assault"))
	# 구버전 저장: 노드·장착 코어·기동 코어 → 무시하고, 처리한 콜로서스의 코어는 모두 가진다
	var cf := ConfigFile.new()
	cf.set_value("run", "stage", 1)
	cf.set_value("run", "cleared", ["observer", "fortress"])
	cf.set_value("upgrade", "nodes", ["P1", "U1"])
	cf.set_value("upgrade", "cores", ["mobility", "pulse"])
	cf.set_value("upgrade", "equipped", "mobility")
	cf.save(pr.path)
	var pr3 = main.Profile.new()
	pr3.path = pr.path
	pr3.load_from_disk()
	_check("old save migrates: dropped cores replaced by the stage's core (cores %s)" % [pr3.cores], pr3.cores.has("counter") and pr3.cores.has("reflect") and pr3.cores.size() == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pr.path))

	# 승리 → 월드 맵 → FTL 도약
	var old = main.profile
	var mp = main.Profile.new()
	mp.persist = false
	main.profile = mp
	main.world.profile = mp
	main.start_stage(0)
	var p = main.player
	_check("no core yet", not p.stats.counter)
	_check("before any clear only stage 1 is open", mp.can_play(0) and not mp.can_play(1))
	main._core_destroyed(main.boss.core.center)
	_check("win records clear and core (state %d, cores %s)" % [main.state, mp.cores], main.state == main.State.WON and mp.cleared.has("observer") and mp.cores.has("counter"))
	main.open_world()
	_check("world map opens and pauses, ship on the next stage (%d)" % mp.stage, main.world.visible and paused and mp.stage == 1)
	main.world.jump()
	_check("FTL starts", main.ftl.is_playing() and not main.world.visible)
	main.ftl.skip()
	_check("arrived: next stage with the core on (stage %d, counter %s)" % [main.stage_idx, p.stats.counter],
		not paused and main.state == main.State.PLAY and main.stage_idx == 1 and p.stats.counter and main.lives == p.stats.shield_cells)

	# 월드 맵에서 이전 스테이지 다시 고르기
	main.open_world()
	_check("can't pick a stage that doesn't exist yet or isn't unlocked", not main.world.select(2) and not main.world.select(8) and not main.world.select(9) and mp.stage == 1)
	_check("pick a cleared stage again", main.world.select(0) and mp.stage == 0)
	main.world.jump()
	main.ftl.skip()
	_check("replaying stage 1 (stage %d, observer %s)" % [main.stage_idx, main.boss.get_script().resource_path.get_file()], main.stage_idx == 0 and main.boss.get_script().resource_path.ends_with("observer.gd") and p.stats.counter)
	main._core_destroyed(main.boss.core.center)
	_check("re-clear: nothing new, next is stage 2 again", mp.cores.size() == 1 and mp.stage == 1)
	main.open_world()
	main.world.jump()
	main.ftl.skip()

	main.profile = old
	main.world.profile = old
	main.start_stage(0)


## 탄막 요새: 잔탄 흡수 / 주탄 패리 / 유도탄 / 반사 코어 / 공격 4종 / 처치
func _fortress_test() -> void:
	main.start_stage(1)
	var b = main.boss
	var p = main.player
	var K = b.shots.Kind
	_check("stage 2 is the barrage fortress (%s, parts %d)" % [b.get_script().resource_path.get_file(), b.part_count()], b.get_script().resource_path.ends_with("fortress.gd") and b.part_count() == 4 and b.phase == 1)
	b.next_t = 99.0
	p.stats.counter = false                            # 앞선 승리로 얻은 반격 코어가 탄을 되돌리지 않게
	p.reset(Vector2(-700, -1500), false)
	p.invuln = 0.0
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0, 0.0, 0.0, K.SMALL)
	_step(1)
	_check("small bullet parried = absorbed, no aim, parry stays open", b.shots.is_empty() and not p.aim_phase and p.parry_active and main.lives == p.stats.shield_cells)
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0, 0.0, 0.0, K.SMALL)
	_step(1)
	_check("absorbs several in one parry window", b.shots.is_empty() and not p.aim_phase)
	b.shots.spawn(p.position + Vector2(30, 0), Vector2.ZERO, 5.0, 0.0, 0.0, K.HOMING)
	_step(1)
	_check("homing (main) parry -> reverse drive aim", p.aim_phase)
	p.parry_release()
	p.reset(Vector2(-700, -1500), false)
	p.invuln = 99.0
	b.shots.clear()
	b.shots.spawn(p.position + Vector2(500, -300), Vector2(0, -230), 7.0, 0.0, 0.0, K.HOMING)
	_step(120)
	var to_p: Vector2 = (p.position - b.shots.pos[0]).normalized()
	_check("homing turns toward the player (dot %.2f)" % b.shots.vel[0].normalized().dot(to_p), b.shots.vel[0].normalized().dot(to_p) > 0.5)
	b.shots.clear()

	# 반사 코어
	p.reset(Vector2(-300, -1300), false)
	p.invuln = 99.0
	p.stats.reflect = true
	p.dash_kind = "power"                              # 반사는 PERFECT 리버스 드라이브로 돌진하는 동안만
	p.perfect_dash = true
	p.dash_t = 0.3
	var tgt: Vector2 = b.target_pos(p.position)
	var ti := -1
	for i in 4:
		if b.part_pos(i) == tgt:
			ti = i
	var hp0: int = b.part_hp[ti]
	b.shots.spawn(p.position + Vector2(30, 0), Vector2(-200, 0), 5.0)
	_step(1)
	_check("reflect core turns nearby bullet into player shot", b.shots.size() == 1 and b.shots.mine[0] == 1)
	_step(90)
	_check("reflected shot damages the target part (%d -> %d)" % [hp0, b.part_hp[ti]], b.part_hp[ti] == hp0 - 1 and b.shots.is_empty())
	p.stats.reflect = false

	# 공격 4종이 오류 없이 돌고 끝난다
	for kd in ["spiral", "fan", "homing", "mines"]:
		main.start_stage(1)
		b = main.boss
		p.reset(Vector2(300, -1500), false)
		p.invuln = 999.0
		var a
		match kd:
			"spiral": a = b.Spiral.new(0, b.BARREL_TIPS[0])
			"fan": a = b.Fan.new(0, b.BARREL_TIPS[0], p.position)
			"homing": a = b.Homing.new()
			"mines": a = b.Mines.new(Vector2(300, -400))
		b.start_attack(a)
		var most := 0
		var smalls := 0
		var done := false
		for k in 360:
			p.invuln = 999.0
			main._physics_process(DT)
			most = maxi(most, b.shots.size())
			for j in b.shots.size():
				if b.shots.kind[j] == K.SMALL:
					smalls += 1
			if b.atk == null:
				done = true
				break
		_check("%s fires (max %d bullets, small seen %s) and finishes" % [kd, most, smalls > 0], done and most > 0 and (kd == "homing" or smalls > 0))

	# 처치: 반사 코어 획득
	main.start_stage(1)
	b = main.boss
	var old = main.profile
	var mp = main.Profile.new()
	mp.persist = false
	main.profile = mp
	b.next_t = 99.0
	for i in 4:
		b.damage_part(i, 99)
	_step(int((b.OPEN_TIME + 1.0) / DT))
	_check("fortress core phase", b.phase == 3)
	b.damage_core(999)
	_step(30)
	b.damage_core(1)
	main._core_destroyed(b.core.center)
	_check("fortress clear gives reflect core", mp.cores.has("reflect") and mp.cleared.has("fortress"))
	main.profile = old
	main.start_stage(0)


## v0.34: 직격 튕김 무적은 통제 회복까지, 패리 성공 시 쿨다운 초기화, 파동 코어, 근접공격 회피 불가, 프레스, 동심원 파동
func _v034_test() -> void:
	main.start_stage(0)
	var b = main.boss
	var p = main.player
	var pp: Vector2 = b.part_pos(0)
	_air(pp + Vector2(-140, 0))
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("plain dash strike: bounce without invulnerability, only a small-bullet guard (shield %.2f, guard %.2f)" % [p.shield_t, p.small_guard], p.shield_t <= 0.0 and p.small_guard > 0.0 and p.bouncing)
	_air(Vector2(-700, -1500))                           # 일반 돌진은 처음 DASH_INVULN 동안만 무적 (끝 무렵 탄 속에선 맞는다)
	_dash_dir("dash", Vector2.RIGHT)
	_step(3)
	var early_immune: bool = p.is_immune()
	_step(int(p.DASH_INVULN / DT))
	_check("plain dash: invulnerable only at the start (early %s, late %s, dash left %.2f)" % [early_immune, p.is_immune(), p.dash_t], early_immune and p.dash_t > 0.0 and not p.is_immune())
	_air(Vector2(-700, -1500))                           # 회피 무적으로 통과한 탄은 그 뒤로 맞지 않는다
	p.invuln = 0.0
	main.debug.god = false
	_dash_dir("dash", Vector2.RIGHT)
	_step(1)
	b.shots.clear()
	b.shots.spawn(p.position, Vector2.ZERO, 5.0)
	main._check_attacks()
	_check("bullet touched during dash invulnerability is marked dodged", b.shots.dodged[0] == 1)
	p.dash_t = 0.0
	p.dash_kind = ""
	p.invuln = 0.0
	p.shield_t = 0.0
	p.small_guard = 0.0
	var lv_d: int = main.lives
	b.shots.pos[0] = p.position
	main._check_attacks()
	_check("the dodged bullet no longer hits afterwards (lives %d -> %d)" % [lv_d, main.lives], main.lives == lv_d)
	b.shots.clear()
	var dring = load("res://scripts/attacks/rings.gd").new(p.position)   # 고리는 닿은 고리만 회피 처리, 다음 고리는 그대로
	dring.boss = b
	dring.count = 2
	dring.t = dring.wind + 0.0001
	dring.mark_dodged(p.position, p.RADIUS)
	_check("only the touched ring is marked dodged and it no longer hits (%s)" % str(dring.dodged_rings), dring.dodged_rings == [0] and dring._ring_at(p.position, p.RADIUS) == -1)
	_air(pp + Vector2(-140, 0))
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	_check("charge strike bounce: like a plain dash, no shield (%.2f, guard %.2f)" % [p.shield_t, p.small_guard], p.shield_t <= 0.0 and p.small_guard > 0.0 and p.bouncing)
	_air(pp + Vector2(-200, 0))
	p.aim_phase = true
	p.aim_perfect = true
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_step(6)
	_check("PERFECT drive bounce gives a shield (%.2f)" % p.shield_t, p.shield_t > 0.0 and p.bouncing)
	var frames := 0
	while p.shield_t > 0.0 and frames < 120:
		_step(1)
		frames += 1
	_check("PERFECT strike shield lasts about STRONG_SHIELD (%.2fs, %.2f)" % [frames * DT, p.STRONG_SHIELD], frames * DT <= p.STRONG_SHIELD + 0.35 and frames * DT >= p.STRONG_SHIELD - 0.05)   # (PERFECT 타격 히트스톱 0.3초 포함)

	# 잔탄 흡수 → 판정이 끝나도 쿨다운 없음
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(-700, -1500), false)
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	_step(int(0.3 / DT))
	_check("parry window that absorbed something ends with no cooldown (cd %.2f)" % p.parry_cd, not p.parry_active and p.parry_cd <= 0.0)
	p.parry_release()
	p.parry_press()
	_step(int(0.3 / DT))
	p.parry_release()
	_check("empty parry still has its cooldown (cd %.2f)" % p.parry_cd, p.parry_cd > 0.0)

	# 반격 코어: 패리한 탄(잔탄 흡수 포함)은 사라지지 않고 표적으로 빠르게 되돌아간다
	p.reset(Vector2(-300, -1300), false)
	p.invuln = 99.0
	p.stats.counter = true
	var tgt: Vector2 = b.target_pos(p.position)
	var ti := -1
	for i in 4:
		if b.part_pos(i) == tgt:
			ti = i
	var hp0: int = b.part_hp[ti]
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	b.shots.spawn(p.position + Vector2(-500, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	_step(1)
	_check("counter core: absorbed small comes back as a player shot (shots %d, mine %d)" % [b.shots.size(), b.shots.mine[0] if b.shots.size() > 0 else -1],
		b.shots.size() == 2 and b.shots.mine[0] == 1 and b.shots.vel[0].length() > 1000.0 and b.shots.mine[1] == 0)
	p.parry_release()
	_step(90)
	_check("returned shot damages the target (%d -> %d)" % [hp0, b.part_hp[ti]], b.part_hp[ti] == hp0 - 1)
	b.shots.clear()
	p.reset(Vector2(-300, -1300), false)
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("counter core: parried main bullet also returns (reverse drive still opens)", p.aim_phase and b.shots.size() == 1 and b.shots.mine[0] == 1)
	p.launch_parry_dash()
	p.parry_release()
	_step(30)
	p.stats.counter = false
	b.shots.clear()
	_check("pulse core is gone", not ("pulse" in p.stats) and not ("pulse_t" in p))

	# 프레스: 정지선 위에 있으면 피해 + 아래로 밀림, 일반 돌진으로 못 피함
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(300, -1600), false)
	var pr = b.Press.new()
	b.start_attack(pr)
	var lives0: int = main.lives
	var hit := false
	for k in int((pr.WARN + pr.DROP + 0.3) / DT):
		if pr.phase == "drop" and not hit and p.dash_t <= 0.0 and p.dash_cd <= 0.0:
			_dash_dir("dash", Vector2.UP)
		_step(1)
		if main.lives < lives0:
			hit = true
	_check("press: dash i-frames don't help, pushed below the plate (lives %d->%d, y %.0f)" % [lives0, main.lives, p.position.y], main.lives == lives0 - 1 and p.position.y > pr.STOP_Y and main.state == main.State.PLAY)
	# 패리하면 아래로 내리꽂힌다
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(300, -1200), false)
	pr = b.Press.new()
	b.start_attack(pr)
	var pinned := false
	for k in int((pr.WARN + pr.DROP + 1.5) / DT):
		if not pinned and p.stun <= 0.0:              # 맞을 때까지 그 자리에 떠 있는다
			p.position = Vector2(300, -1200)
			p.vel = Vector2.ZERO
		if pr.phase == "drop" and pr.bottom > p.position.y - 300.0 and not p.parry_active and not pinned:
			p.parry_press()
		_step(1)
		if p.vel.y > 1500.0 and p.stun > 0.0:
			pinned = true
		if main.state != main.State.PLAY:
			break
	_check("parrying the press pins you down into the lava (state %d, pinned %s, lives %d)" % [main.state, pinned, main.lives], pinned and main.state == main.State.RESPAWN)
	p.parry_release()

	# 근접(팔): 일반 돌진으로 통과 못 함
	main.start_stage(0)
	b = main.boss
	_air(Vector2(-700, -1500))
	_swing("swing", 0.0, 1.0, 1.0)
	var mid: Vector2 = b.SHOULDERS[1].lerp(b.fists[1], 0.8)
	var side: Vector2 = (b.fists[1] - b.SHOULDERS[1]).orthogonal().normalized()
	p.position = mid + side * 120.0
	_swing("swing", 0.0, 1.0, 1.0)
	lives0 = main.lives
	_dash_dir("dash", -side)
	_step(4)
	_check("arm swing is not dodgeable by dash i-frames (lives %d->%d)" % [lives0, main.lives], main.lives == lives0 - 1)

	# 동심원 파동: 패리 불가, 돌진으로 통과
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	var rg = b.Rings.new(b.REACTOR_POS)
	b.start_attack(rg)
	rg.t = rg.WIND + 1.0
	var at: Vector2 = b.REACTOR_POS + Vector2(rg.SPEED * 1.0, 0)
	_check("rings hit at their radius, not between", b.beam_hit(at, 12.0) != Vector2.ZERO and b.beam_hit(at + Vector2(150, 0), 12.0) == Vector2.ZERO)
	p.reset(at, false)
	p.parry_press()
	lives0 = main.lives
	main._check_attacks()
	_check("rings can't be parried (lives %d->%d)" % [lives0, main.lives], main.lives == lives0 - 1)
	p.parry_release()
	main.start_stage(0)


## v0.35: 프레스 요격·다 내려온 뒤 무해, 동심원 한 줄기, 차지 강습·리버스 드라이브 적중 시 돌진 쿨다운 반환,
## 요새가 쉬지 않고 몰아침(화면이 비지 않음), 코어 페이즈 반응로 폭주
func _v035_test() -> void:
	var p = main.player
	# 차지 강습·리버스 드라이브 적중 → 돌진 쿨다운 반환 (일반 돌진은 그대로)
	main.start_stage(0)
	var b = main.boss
	var pp: Vector2 = b.part_pos(0)
	_air(pp + Vector2(-160, 0))
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	_check("charge hit refunds dash cooldown (cd %.2f, bouncing %s)" % [p.dash_cd, p.bouncing], p.dash_cd <= 0.0 and p.bouncing)
	main._dash_input(true)
	main._dash_input(false)
	_check("can dash right away while bouncing", p.dash_kind == "dash" and p.dash_t > 0.0)
	_air(pp + Vector2(-200, 0))
	p.aim_phase = true
	p.aim_perfect = false
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_step(6)
	_check("reverse drive hit refunds dash cooldown (cd %.2f)" % p.dash_cd, p.dash_cd <= 0.0 and p.bouncing)
	_air(pp + Vector2(-140, 0))
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("normal dash hit keeps its cooldown (cd %.2f)" % p.dash_cd, p.dash_cd > 0.4)

	# 프레스: 차지 강습으로 요격 → 도로 올라간다, 피해 없음
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(300, -1300), false)
	var pr = b.Press.new()
	b.start_attack(pr)
	_step(int((pr.WARN + pr.DROP * 0.6) / DT))
	var lives0: int = main.lives
	p.position = Vector2(300, pr.bottom + 150.0)
	p.vel = Vector2.ZERO
	_dash_dir("charge", Vector2.UP)
	_step(4)
	_check("charge assault intercepts the press (phase %s, lives %d->%d)" % [pr.phase, lives0, main.lives], pr.phase == "jam" and main.lives == lives0 and p.bouncing)
	_check("intercepted press gives way to the next attack", b.atk == null and b.is_lingering("press"))
	_step(int((pr.JAM + 0.5) / DT))
	_check("press goes back up and ends", not b.is_lingering("press") and pr.bottom <= pr.START + 1.0)
	# 다 내려온 뒤(멈춤·올라감)에는 판에 닿아도 피해 없음
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(300, -400), false)
	pr = b.Press.new()
	b.start_attack(pr)
	for k in int((pr.WARN + pr.DROP + 0.5) / DT):          # 정지선 아래에 떠서 기다린다
		if pr.phase == "hold":
			break
		p.position = Vector2(300, -400)
		p.vel = Vector2.ZERO
		p.invuln = 99.0
		_step(1)
	_check("press holding (phase %s)" % pr.phase, pr.phase == "hold")
	lives0 = main.lives
	p.invuln = 0.0
	p.position = Vector2(300, pr.STOP_Y + 30.0)
	_dash_dir("dash", Vector2.UP)
	_step(10)
	_check("touching the press after it landed: blocked, no damage (lives %d->%d, y %.0f)" % [lives0, main.lives, p.position.y], main.lives == lives0 and p.position.y > pr.STOP_Y)
	_step(int(pr.HOLD / DT))
	_check("rising press gives way to the next attack (phase %s)" % pr.phase, pr.phase == "rise" and b.atk == null and b.is_lingering("press"))
	p.invuln = 0.0
	p.position = Vector2(300, pr.bottom + 20.0)
	_dash_dir("dash", Vector2.UP)
	_step(6)
	_check("rising press does no damage", main.lives == lives0)

	# 동심원 파동: 한 줄기, 내보낸 뒤 자리를 내주고 판정은 남는다
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	var rg = b.Rings.new(b.REACTOR_POS)
	b.start_attack(rg)
	_check("rings: a single ring", rg.COUNT == 1)
	p.reset(Vector2(-1000, -400), false)
	p.invuln = 999.0
	_step(int((rg.WIND + 0.2) / DT))
	_check("ring launched -> next attack can start, ring keeps going", b.atk == null and b.is_lingering("rings"))
	var r_now: float = rg._radius(0)
	_check("lingering ring still hits", b.beam_hit(b.REACTOR_POS + Vector2(r_now, 0), 12.0) != Vector2.ZERO)

	# 요새는 쉬지 않고 몰아친다: 30초 동안 탄도 공격도 없는 시간이 길게 이어지지 않는다 (페이즈 1·코어 페이즈)
	for ph in [1, 3]:
		main.start_stage(1)
		b = main.boss
		if ph == 3:
			for i in 4:
				b.damage_part(i, 99)
			_step(int((b.OPEN_TIME + 0.2) / DT))
		p.reset(Vector2(-500, -1500), false)
		var quiet := 0.0
		var longest := 0.0
		var kinds := {}
		var began := false                                 # 첫 공격(시작 대기·개방 연출 뒤)부터 잰다
		for k in int(30.0 / DT):
			p.position = Vector2(-500 + 400.0 * sin(k * 0.01), -1500)
			p.vel = Vector2.ZERO
			p.invuln = 999.0
			main.lives = 9
			main._physics_process(DT)
			if b.atk != null:
				kinds[b.atk.kind] = true
			var busy: bool = b.shots.size() > 0 or b.attack_kind() == "press" or b.is_lingering("rings")
			began = began or b.shots.size() > 0
			if not began:
				continue
			quiet = 0.0 if busy else quiet + DT
			longest = maxf(longest, quiet)
		_check("phase %d: field never sits empty for long (longest quiet %.2fs, attacks %s)" % [ph, longest, kinds.keys()], longest < 1.6 and b.phase == ph)
		if ph == 3:
			_check("core phase uses the reactor overload", kinds.has("overload"))

	# 반응로 폭주: 잔탄 고리 + 주탄, 끝난다
	main.start_stage(1)
	b = main.boss
	for i in 4:
		b.damage_part(i, 99)
	_step(int((b.OPEN_TIME + 1.2) / DT))
	b.next_t = 99.0
	b.atk = null
	b.lingering.clear()
	b.shots.clear()
	var ov = b.Overload.new(b.REACTOR_POS)
	b.start_attack(ov)
	p.reset(Vector2(-1000, -400), false)
	var most := 0
	var mains := 0
	var done := false
	for k in 360:
		p.invuln = 999.0
		main._physics_process(DT)
		most = maxi(most, b.shots.size())
		if b.atk == null:
			done = true
			break
	for j in b.shots.size():
		if b.shots.kind[j] != b.shots.Kind.SMALL:
			mains += 1
	_check("overload: dense rings with main shots, then ends (max %d, mains %d)" % [most, mains], done and most >= ov.RINGS * ov.COUNT * 0.8 and mains >= 2)
	# 코어 페이즈엔 기존 탄막도 강해진다
	_check("hard spiral has 2 arms, hard fan 4 waves, hard mines 5", b.Spiral.new(-1, b.SPIRE_TOP, Vector2.ZERO, true).arms == 2 and b.Fan.new(-1, b.SPIRE_TOP, Vector2.ZERO, true).wave_n == 4 and b.Mines.new(Vector2.ZERO, true).mines.size() == 5)
	main.start_stage(0)


## v0.36: 리버스 드라이브로도 근접 요격, 프레스 에임 보조 임시 표적
func _v036_test() -> void:
	var p = main.player
	# 리버스 드라이브로 팔 요격: 리버스 드라이브 피해, 팔이 밀려나 멈춘다 (드라이브가 끝나도 경직 유지)
	main.start_stage(0)
	var b = main.boss
	_air(Vector2(-700, -1500))
	_swing("swing", 0.0, 1.0, 1.0)
	var mid: Vector2 = b.SHOULDERS[1].lerp(b.fists[1], 0.8)
	var side: Vector2 = (b.fists[1] - b.SHOULDERS[1]).orthogonal().normalized()
	_air(mid + side * 220.0)
	_swing("warn", 0.2, 1.0, 2.0)
	var hp3: int = b.part_hp[3]
	p.aim_phase = true
	p.aim_perfect = false
	p.aim = -side
	p.launch_parry_dash()
	_step(4)
	_check("reverse drive intercepts the arm (hp %d -> %d, phase %s)" % [hp3, b.part_hp[3], _ph()], b.part_hp[3] == hp3 - p.stats.power_damage and _ph() == "recoil")
	_check("after reverse drive intercept: bounce, dash ready, world speed back", p.bouncing and p.dash_cd <= 0.0 and p.dash_kind == "" and main.world_scale() == 1.0)
	# 리버스 드라이브로 프레스 요격
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(300, -1300), false)
	var pr = b.Press.new()
	b.start_attack(pr)
	_step(int((pr.WARN + pr.DROP * 0.6) / DT))
	var lives0: int = main.lives
	p.position = Vector2(300, pr.bottom + 200.0)
	p.vel = Vector2.ZERO
	p.aim_phase = true
	p.aim = Vector2.UP
	p.launch_parry_dash()
	_step(4)
	_check("reverse drive intercepts the press (phase %s)" % pr.phase, pr.phase == "jam" and main.lives == lives0)
	# 프레스 준비 중: 에임 보조 임시 표적
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	pr = b.Press.new()
	b.start_attack(pr)
	_step(10)
	var tg: Array = b.assist_targets(Vector2(400, -2500))
	var found := false
	for t in tg:
		if absf(t["pos"].x - 400.0) < 1.0 and absf(t["pos"].y - (pr.bottom - 30.0)) < 1.0:
			found = true
	_check("press warn adds a temporary aim-assist target above the player (%d targets)" % tg.size(), found and tg.size() == 5)
	p.reset(Vector2(450, -2500), false)
	p.aim = Vector2.from_angle(-PI * 0.5 + 0.25)
	var a2: Vector2 = p._assisted(p.aim, p.CHARGE_SPEED * p.CHARGE_DASH_TIME, 0.0)
	_check("assist pulls the charge aim straight up into the press (x %.2f)" % a2.x, absf(a2.x) < 0.05 and a2.y < -0.99)
	b.atk = null
	b.lingering.clear()
	_check("no press, no temporary target", b.assist_targets(Vector2(400, -2500)).size() == 4)
	main.start_stage(0)


## v0.37: 잔탄 피격 = 과열 게이지, 돌진 직후 잔탄 무적, 퍼펙트 회피 무적 갱신, 반사는 돌진하는 동안만,
## 회전 탄막은 부채꼴 안에서만·다른 패턴이 쉴 때만, 유도탄 상향, 관측자의 잔탄
func _v037_test() -> void:
	var p = main.player
	main.start_stage(1)
	var b = main.boss
	var K = b.shots.Kind
	b.next_t = 99.0
	# 과열 게이지: 잔탄은 셀을 바로 깨지 않고 제어 불능도 없다. 동조는 유지
	p.reset(Vector2(-700, -1500), false)
	p.buffed = true
	p.buff_t = 3.0
	var lives0: int = main.lives
	for n in 3:
		p.position = Vector2(-700, -1500)
		p.vel = Vector2.ZERO
		p.invuln = 0.0
		b.shots.spawn(p.position + Vector2(5, 0), Vector2.ZERO, 5.0, 0.0, 0.0, K.SMALL)
		_step(1)
		if n == 0:
			_check("small bullet: gauge +1, no cell lost, no stun, sync kept, brief invuln (heat %d, lives %d, stun %.2f, invuln %.2f)" % [main.heat, main.lives, p.stun, p.invuln],
				main.heat == 1 and main.lives == lives0 and p.stun <= 0.0 and p.invuln > 0.0 and p.buffed and b.shots.is_empty())
	_check("3 small hits break one cell, gauge resets, still no stun (heat %d, lives %d)" % [main.heat, main.lives], main.heat == 0 and main.lives == lives0 - 1 and p.stun <= 0.0)
	p.position = Vector2(-700, -1500)
	p.vel = Vector2.ZERO
	p.invuln = 0.0
	main.hitstop = 0.0
	b.shots.spawn(p.position + Vector2(5, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("main bolt still hurts fully (lives %d, stun %.2f)" % [main.lives, p.stun], main.lives == lives0 - 2 and p.stun > 0.0)
	# 식는다
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(-700, -1500), false)
	main.heat = 2
	main.heat_t = main.HEAT_COOL
	for k in int((main.HEAT_COOL + 0.3) / DT):
		p.position = Vector2(-700, -1500)
		p.vel = Vector2.ZERO
		p.invuln = 999.0
		_step(1)
	_check("gauge cools one notch after %.0fs (heat %d)" % [main.HEAT_COOL, main.heat], main.heat == 1)
	# 일반 돌진 직후 0.25초는 잔탄 무적, 그 뒤엔 맞는다
	p.reset(Vector2(-700, -1500), false)
	p.invuln = 0.0
	_dash_dir("dash", Vector2.RIGHT)
	_step(int(0.3 / DT))
	_check("small guard after a normal dash (%.2f)" % p.small_guard, p.small_guard > 0.0 and p.dash_t <= 0.0)
	var h0: int = main.heat
	main.hitstop = 0.0
	b.shots.spawn(p.position + Vector2(3, 0), Vector2.ZERO, 5.0, 0.0, 0.0, K.SMALL)
	_step(1)
	_check("small bullet ignored during the guard (heat %d)" % main.heat, main.heat == h0 and b.shots.size() == 1)
	_step(int(0.3 / DT))
	p.position = b.shots.pos[0]
	p.vel = Vector2.ZERO
	_step(1)
	_check("hits once the guard is over (heat %d)" % main.heat, main.heat == h0 + 1)
	b.shots.clear()

	# 퍼펙트 회피한 돌진 중 다른 탄에 닿으면 추가 무적이 처음 길이로 되돌아온다
	p.reset(Vector2(-700, -1500), false)
	b.shots.clear()
	_dash_dir("dash", Vector2.RIGHT)
	b.shots.spawn(p.position + Vector2(20, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("perfect evade granted (invuln %.2f)" % p.invuln, p.evade_rewarded and p.invuln > 0.75)
	_step(8)
	var low: float = p.invuln
	b.shots.spawn(p.position + Vector2(30, 0), Vector2.ZERO, 5.0)       # 이번 프레임에 기체가 앞으로 나아가며 닿는다
	var lv: int = main.lives
	_step(1)
	_check("touching another bullet mid-dash resets the invuln (%.2f -> %.2f), no damage" % [low, p.invuln], p.invuln > low + 0.1 and p.invuln > 0.75 and main.lives == lv and p.dash_t > 0.0)
	b.shots.clear()

	# 반사 코어: 리버스 드라이브로 돌진하는 동안만 (적중해 튕겨나면 끝)
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.stats.reflect = true
	p.reset(b.part_pos(0) + Vector2(-200, 0), false)
	p.aim_phase = true
	p.aim = Vector2.RIGHT
	_check("reflect is off before the dash", not p.is_reflecting())
	p.aim_perfect = false
	p.launch_parry_dash()
	_check("no reflect during a normal parry drive", not p.is_reflecting())
	p.reset(b.part_pos(0) + Vector2(-200, 0), false)
	p.aim_phase = true
	p.aim_perfect = true
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_check("reflect is on during the PERFECT reverse drive", p.is_reflecting())
	_step(6)
	_check("hit -> bouncing: reflect ends right away (bouncing %s)" % p.bouncing, p.bouncing and not p.is_reflecting())
	b.shots.spawn(p.position + Vector2(30, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("bullet near the bouncing ship is not returned", b.shots.size() == 1 and b.shots.mine[0] == 0)
	p.stats.reflect = false
	b.shots.clear()

	# 회전 탄막: 부채꼴 안에서만, 줄기 하나, 옛날보다 훨씬 성김
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(500, -1500), false)
	var sp = b.Spiral.new(-1, b.SPIRE_TOP, p.position)
	b.start_attack(sp)
	var maxdev := 0.0
	for k in 330:
		p.position = Vector2(500, -1500)
		p.vel = Vector2.ZERO
		p.invuln = 999.0
		main._physics_process(DT)
		for j in b.shots.size():
			if b.shots.kind[j] == K.SMALL:
				maxdev = maxf(maxdev, absf(wrapf(b.shots.vel[j].angle() - sp.center, -PI, PI)))
		if b.atk == null:
			break
	var toward: float = (p.position - b.SPIRE_TOP).angle()
	_check("spiral: aimed at the player, sweeps only inside its fan (dev %.2f <= %.2f)" % [maxdev, sp.SWEEP], absf(wrapf(sp.center - toward, -PI, PI)) < 0.05 and maxdev <= sp.SWEEP + 0.02 and maxdev > sp.SWEEP * 0.8)
	_check("spiral: sparse (%d small bullets, was ~64)" % sp.smalls, sp.smalls >= 20 and sp.smalls <= 30 and sp.arms == 1)
	# 다른 패턴이 쉬는 동안에만 혼자
	var calm_seen := false
	var busy_seen := false
	var dummy = b.Rings.new(b.REACTOR_POS)
	for k in 150:
		b.atk = null
		b.last = ""
		b.since_special = 0
		b.shots.clear()
		b.lingering.clear()
		b._choose(Vector2(-500, -1500))
		if b.atk != null and b.atk.kind == "spiral":
			calm_seen = true
		b.atk = null
		b.last = ""
		b.since_special = 0
		b.lingering = [dummy]
		b._choose(Vector2(-500, -1500))
		if b.atk != null and b.atk.kind == "spiral":
			busy_seen = true
	b.lingering.clear()
	_check("spiral is used only when nothing else is going on (calm %s, with another pattern %s)" % [calm_seen, busy_seen], calm_seen and not busy_seen)
	# 많은 탄이 떠 있어도 안 쓴다 / 쓰는 순간엔 유도탄을 같이 쏘지 않는다
	var many_seen := false
	var homing_with_spiral := false
	for k in 150:
		b.atk = null
		b.last = ""
		b.since_special = 0
		b.shots.clear()
		b.lingering.clear()
		b._choose(Vector2(-500, -1500))
		if b.atk != null and b.atk.kind == "spiral" and b.is_lingering("homing"):
			homing_with_spiral = true
		b.atk = null
		b.last = ""
		b.since_special = 0
		b.lingering.clear()
		for j in 12:
			b.shots.spawn(Vector2(300, -1500), Vector2.ZERO, 5.0)
		b._choose(Vector2(-500, -1500))
		if b.atk != null and b.atk.kind == "spiral":
			many_seen = true
	b.shots.clear()
	b.lingering.clear()
	b.atk = null
	_check("spiral skipped while many bullets are out; never started with homing (many %s, homing+spiral %s)" % [many_seen, homing_with_spiral], not many_seen and not homing_with_spiral)

	# 유도탄: 더 빠르고 더 잘 쫓는다
	b.last = ""
	var hm = b.Homing.new()
	b.start_attack(hm)
	for k in int(1.2 / DT):
		main._physics_process(DT)
		if b.shots.size() > 0:
			break
	_check("homing is faster (%.0f px/s) and turns harder (%.1f rad/s)" % [b.shots.vel[0].length() if b.shots.size() > 0 else 0.0, b.shots.HOMING_TURN],
		b.shots.size() > 0 and b.shots.vel[0].length() >= 265.0 and b.shots.HOMING_TURN >= 2.0)
	b.shots.clear()
	b.atk = null

	# 관측자: 주탄 일부를 잔탄으로
	main.start_stage(0)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(-700, -1500), false)
	var vo = b.Volley.new(-1, b.HEAD_POS, p.position)
	b.start_attack(vo)
	for k in int(2.0 / DT):
		p.invuln = 999.0
		main._physics_process(DT)
		if b.shots.size() > 0:
			break
	var vs := 0
	for j in b.shots.size():
		if b.shots.kind[j] == K.SMALL:
			vs += 1
	_check("observer volley: 3 main + 2 small per wave (%d small of %d)" % [vs, b.shots.size()], b.shots.size() == 5 and vs == 2)
	b.shots.clear()
	b.atk = null
	b.start_attack(b.Burst.new(-1, b.HEAD_POS))
	for k in int(2.0 / DT):
		p.invuln = 999.0
		main._physics_process(DT)
		if b.shots.size() > 0:
			break
	vs = 0
	for j in b.shots.size():
		if b.shots.kind[j] == K.SMALL:
			vs += 1
	_check("observer burst: 12 main + 6 small (%d small of %d)" % [vs, b.shots.size()], b.shots.size() == 18 and vs == 6)
	main.start_stage(0)


## v0.38: 프레스 정지선이 위로, 돌진패리(퍼펙트 회피 직후 구간의 패리 = PERFECT), 외부 시스템 체력 30
func _v038_test() -> void:
	var p = main.player
	main.start_stage(1)
	var b = main.boss
	var K = b.shots.Kind
	b.next_t = 99.0
	_check("fortress parts have 30 hp", b.PART_HP == 30 and b.part_hp[0] == 30)
	# 프레스 정지선: 예전 정지선(-650)과 새 정지선(-900) 사이는 이제 판 아래(안전)가 아니라 안전 구역이 더 넓다
	var pr = b.Press.new()
	_check("press stops higher (STOP_Y %.0f)" % pr.STOP_Y, pr.STOP_Y == -900.0)
	b.start_attack(pr)
	p.reset(Vector2(300, -780), false)                 # 새 정지선 아래: 예전엔 정지선 위라 맞았을 높이
	p.invuln = 0.0
	var lives0: int = main.lives
	for k in int((pr.WARN + pr.DROP + 0.6) / DT):
		p.position = Vector2(300, -780)
		p.vel = Vector2.ZERO
		main._physics_process(DT)
	_check("standing below the new stop line is safe (lives %d->%d, phase %s)" % [lives0, main.lives, pr.phase], main.lives == lives0 and pr.phase == "hold")
	b.atk = null
	b.lingering.clear()

	# 돌진패리: PERFECT 는 타이밍대로 (돌진해도 늦게 누른 패리는 일반), 대신 드라이브 뒤 돌진·차지 쿨다운이 바로 돌아온다
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	_step(6)                                            # 패리를 누른 지 0.1초 (PERFECT 판정 0.07초는 지났고, 패리 유지 0.14초 안)
	_dash_dir("dash", Vector2.RIGHT)
	_check("dash-parry state while dashing", p.is_dash_parry() and p.parry_active and p.parry_t > p.PERFECT_WINDOW)
	b.shots.spawn(p.position + Vector2(40, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("late parry while dashing is NOT perfect (dash-parry no longer upgrades it) (aim %s, perfect %s, boost %s)" % [p.aim_phase, p.aim_perfect, p.aim_boost], p.aim_phase and not p.aim_perfect and p.aim_boost)
	var normal_reach: float = p.PARRY_DASH_SPEED * p.NORMAL_DRIVE_TIME
	_check("normal reverse drive has limited range (reach %.0f)" % p.parry_dash_reach(), p.parry_dash_reach() < 1100.0)
	p.dash_cd = 0.5
	p.charge_cd = 0.8
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_check("dash-parry drive: dash and charge cooldowns come back at once (dash %.2f, charge %.2f)" % [p.dash_cd, p.charge_cd], p.power_boost and p.dash_kind == "power" and p.dash_cd <= 0.0 and p.charge_cd <= 0.0)
	var x0: float = p.position.x
	_step(int(0.9 / DT))
	_check("normal drive stops near its range (%.0f px)" % (p.position.x - x0), p.position.x - x0 < normal_reach * 1.6)
	_check("boost ends with the dash", not p.power_boost)
	p.parry_release()
	p.aim_phase = false
	p.reset(Vector2(-700, -1500), false)               # PERFECT 패리 드라이브는 사거리 무제한
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	b.shots.spawn(p.position + Vector2(40, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("parry right on time is PERFECT and its drive range is unlimited (perfect %s, reach %.0f)" % [p.aim_perfect, p.parry_dash_reach()], p.aim_phase and p.aim_perfect and p.parry_dash_reach() >= p.UNLIMITED_REACH)
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	x0 = p.position.x
	var far_x := x0
	var after_v := 0.0                                  # 드라이브가 끝난 뒤 남은 속도 (빠른 드라이브가 끝나고 튕겨 날아가지 않게)
	for k in int(0.9 / DT):
		_step(1)
		far_x = maxf(far_x, p.position.x)
		if p.dash_kind == "":
			after_v = maxf(after_v, p.vel.length())
	_check("and goes farther (%.0f px)" % (far_x - x0), far_x - x0 > normal_reach * 1.15 or far_x >= p.WALL_R - 20.0)
	_check("PERFECT drive leaves no runaway speed after it ends (%.0f)" % after_v, after_v < 2000.0)
	p.parry_release()
	p.aim_phase = false
	# 돌진하지 않으면 같은 늦은 패리는 보통 판정
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	_step(6)
	_check("not dashing: no dash-parry", not p.is_dash_parry())
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("same late parry without a dash is normal (not perfect, no boost)", p.aim_phase and not p.aim_perfect and not p.aim_boost)
	p.parry_release()
	p.aim_phase = false
	# 차지 강습·리버스 드라이브 중에는 해당 없음 (일반 돌진만)
	p.reset(Vector2(-700, -1500), false)
	_dash_dir("charge", Vector2.RIGHT)
	_check("charge assault counts as a dash for dash-parry", p.is_dash_parry())
	p.dash_kind = "power"
	p.dash_t = 0.2
	_check("reverse drive does not", not p.is_dash_parry())
	p.dash_t = 0.0
	p.dash_kind = ""
	# 차지 강습 중 패리: 돌진패리 (늦게 누른 패리는 PERFECT 아님)
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	_step(6)
	_dash_dir("charge", Vector2.RIGHT)
	b.shots.spawn(p.position + Vector2(40, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("parry during a charge assault is a dash-parry, timing decides PERFECT (aim %s, perfect %s, boost %s)" % [p.aim_phase, p.aim_perfect, p.aim_boost], p.aim_phase and not p.aim_perfect and p.aim_boost)
	p.parry_release()
	p.aim_phase = false
	# 돌진이 끝난 직후 잠깐은 인정, 곧 끝난다. 맞으면 사라진다
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	_dash_dir("dash", Vector2.RIGHT)
	_step(int(0.3 / DT))
	_check("just after the dash: still counts (%.2f)" % p.dash_parry_t, p.dash_t <= 0.0 and p.is_dash_parry())
	_step(int(0.2 / DT))
	_check("grace ends shortly after (%.2f)" % p.dash_parry_t, not p.is_dash_parry())
	p.reset(Vector2(-700, -1500), false)
	_dash_dir("dash", Vector2.RIGHT)
	_step(int(0.3 / DT))
	p.on_hurt(Vector2.RIGHT)
	_check("being hit ends it", not p.is_dash_parry())
	main.start_stage(0)


## v0.39: 근접공격 예고 통일 (melee_warning), 돌진패리 사거리
func _v039_test() -> void:
	main.start_stage(0)
	var b = main.boss
	_air(Vector2(-700, -1500))
	for ph in ["prep", "set", "warn"]:
		_swing(ph, 0.2, 1.0, 2.0)
		_check("arm %s phase is a melee warning" % ph, b.melee_warning())
	for ph in ["swing", "recoil", "return"]:
		_swing(ph, 0.2, 1.0, 2.0)
		_check("arm %s phase is not" % ph, not b.melee_warning())
	b.atk = null
	_check("no attack, no melee warning", not b.melee_warning())
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	var pr = b.Press.new()
	b.start_attack(pr)
	_check("press warn is a melee warning", b.melee_warning())
	pr.set_phase("drop")
	_check("press drop is too", b.melee_warning())
	pr.set_phase("hold")
	_check("press hold is not", not b.melee_warning())
	b.atk = null
	b.start_attack(b.Fan.new(0, b.BARREL_TIPS[0], Vector2(0, -1500)))
	_check("bullet attacks are not melee warnings", not b.melee_warning())
	b.atk = null
	main.start_stage(0)


## v0.42: 과열 정도(heat_level)는 맞을수록 오르고 식어 가면서 연속으로 줄어든다 (HUD 셀의 금·기체 달아오름 용)
func _v042_test() -> void:
	main.heat = 0
	_check("no heat: level 0", main.heat_level() == 0.0)
	main.heat = 1
	main.heat_t = main.HEAT_COOL
	_check("one hit: 0.5 (%.2f)" % main.heat_level(), absf(main.heat_level() - 0.5) < 0.01)
	main.heat = 2
	main.heat_t = main.HEAT_COOL
	_check("two hits: 1.0 (%.2f)" % main.heat_level(), absf(main.heat_level() - 1.0) < 0.01)
	main.heat_t = 0.0
	_check("fully cooled second notch = one hit's level (%.2f)" % main.heat_level(), absf(main.heat_level() - 0.5) < 0.01)
	main.heat = 1
	main.heat_t = 0.0
	_check("about to be cold: 0 (%.2f)" % main.heat_level(), main.heat_level() < 0.01)
	main.heat = 0

	# 다른 공격(주탄·융해 지대)으로 셀을 잃으면 쌓인 과열은 사라진다
	main.start_stage(1)
	var b = main.boss
	var p = main.player
	b.next_t = 99.0
	p.reset(Vector2(-700, -1500), false)
	p.invuln = 0.0
	main.heat = 2
	main.heat_t = main.HEAT_COOL
	b.shots.spawn(p.position + Vector2(5, 0), Vector2.ZERO, 5.0)
	var lv: int = main.lives
	_step(1)
	_check("cell lost to a main bolt clears the heat (lives %d->%d, heat %d)" % [lv, main.lives, main.heat], main.lives == lv - 1 and main.heat == 0)
	main.start_stage(1)
	main.heat = 2
	main.heat_t = main.HEAT_COOL
	lv = main.lives
	main.on_lava(Vector2(0, 0))
	_check("cell lost to lava clears the heat (lives %d->%d, heat %d)" % [lv, main.lives, main.heat], main.lives == lv - 1 and main.heat == 0)
	main.start_stage(0)


## v0.44: 적중 직후 잠깐 시작한 일반 돌진은 표적과 충돌하지 않는다, 차지 자동 발사 0.9초, 차지 쿨다운 1.7초
func _v044_test() -> void:
	main.start_stage(0)
	var b = main.boss
	var p = main.player
	_check("charge auto-fire 0.9s, charge cooldown 1.2s", p.CHARGE_AUTO == 0.9 and absf(p.stats.charge_cooldown - 1.2) < 0.001)
	var pp: Vector2 = b.part_pos(0)
	_air(pp + Vector2(-160, 0))
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	var hp1: int = b.part_hp[0]
	_check("charge hit: cooldown refunded, pass-through window open (hp %d, cd %.2f, pass %.2f)" % [hp1, p.dash_cd, p.strike_pass_t], hp1 == b.PART_HP - 3 and p.dash_cd <= 0.0 and p.strike_pass_t > 0.0)
	main.hitstop = 0.0
	p.position = pp + Vector2(-30, 0)                  # 아직 표적 안쪽 (부위 반지름 안)
	p.vel = Vector2.ZERO
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("dash right after the hit slips out of the target circle (hp %d, pass %s, still dashing %s)" % [b.part_hp[0], p.dash_pass, p.dash_t > 0.0], b.part_hp[0] == hp1 and p.dash_kind == "dash" and p.dash_t > 0.0)
	_step(int(0.6 / DT))
	_check("window closes (%.2f)" % p.strike_pass_t, p.strike_pass_t <= 0.0)
	p.position = pp + Vector2(-90, 0)
	p.vel = Vector2.ZERO
	p.dash_cd = 0.0
	_dash_dir("dash", Vector2.RIGHT)
	_step(6)
	_check("later dashes hit as usual (hp %d)" % b.part_hp[0], b.part_hp[0] == hp1 - 1)
	# 원 안쪽에서만 통과: 맞힌 직후라도 원 밖에서 뒤돌아 돌진하면 다시 맞는다
	_air(pp + Vector2(-160, 0))
	_dash_dir("charge", Vector2.RIGHT)
	_step(6)
	hp1 = b.part_hp[0]
	main.hitstop = 0.0
	p.position = pp + Vector2(150, 0)                   # 원(부위 반지름 + 기체) 바깥
	p.vel = Vector2.ZERO
	_dash_dir("dash", Vector2.LEFT)
	_check("pass window is open but only inside the circle (pass %s)" % p.dash_pass, p.dash_pass and p.strike_pass_t > 0.0)
	_step(6)
	_check("turning around right after a hit: the dash hits again (hp %d -> %d)" % [hp1, b.part_hp[0]], b.part_hp[0] == hp1 - 1 and not p.dash_pass)
	# 패리는 차지를 멈추지 않는다
	main.start_stage(1)
	b = main.boss
	b.next_t = 99.0
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	p.stats.counter = false
	main._dash_input(true)
	_step(int(0.3 / DT))
	main._parry_input(true)
	_check("pressing parry does not cancel the charge (charging %s, t %.2f)" % [p.charging, p.charge_t], p.charging and p.charge_t > 0.1)
	main._parry_input(false)
	_step(int(0.5 / DT))
	_check("charge completes after the parry (charged %s)" % p.is_charged(), p.is_charged())
	# 패리에 성공하면 차지는 끊긴다: 리버스 드라이브 뒤에 차지 강습이 따로 나가지 않는다
	main.hitstop = 0.0
	main._parry_input(true)
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("parry success ends the charge (aim %s, charging %s)" % [p.aim_phase, p.charging], p.aim_phase and not p.charging and p.pending_kind == "")
	main._parry_input(false)                            # 떼면 패리 돌진 발사
	_step(int(0.5 / DT))
	main._dash_input(false)
	var fired := false
	for k in int(2.0 / DT):
		_step(1)
		if p.dash_kind == "charge":
			fired = true
	_check("no charge assault follows the reverse drive (fired %s)" % fired, not fired)
	main.start_stage(0)


## v0.50: 크라켄 표적은 방어막에 싸인 외눈(코어) 하나. 돌진·차지는 막히고 리버스 드라이브만 뚫는다, 방어막 동안 코어 하한,
## 촉수를 다 끊으면 방어막이 깨진다, 연타 3종, 첫 타 예고 여유, 빠른 차지, 차지 완료 슬로우
func _kraken_shield_test() -> void:
	main.start_stage(2)
	var b = main.boss
	var p = main.player
	b.next_t = 99.0
	_check("kraken: tentacles are not strike targets", b.strike_hit(b.part_pos(0), 20.0).is_empty())
	var sh: Dictionary = b.strike_hit(b.CORE_POS + Vector2(0, b.SHIELD_R + 10.0), 20.0)
	_check("kraken: the shield around the core is the only target", sh.get("kind", "") == "shield")
	_check("kraken: assist sees only the core (no tentacle targets)", b.assist_targets(Vector2(0, -1500)).size() == 1)
	for kind in ["tips", "ring", "snipe", "ink"]:      # 탄막 4종: 발사점이 사방에 있고, 끝까지 돌아 탄을 쏜다
		b.reset()
		b.next_t = 99.0
		b._ppos = Vector2(300, -700)
		b.start_attack(b.Barrage.new(kind, b.emitters(), b._ppos) if kind in ["tips", "ring", "snipe"] else b._fire(kind, b._ppos, false))
		var spawned := 0
		for k in 600:
			b.step(DT, b._ppos)
			spawned = maxi(spawned, b.shots.size())
			if b.atk == null:
				break
		_check("kraken barrage %s finishes and fires (%d shots)" % [kind, spawned], b.atk == null and spawned >= (1 if kind == "snipe" else 4))
	b.reset()
	b.next_t = 99.0
	b._start("ring", [0, 1, 2, 3, 4, 5] as Array[int], Vector2(300, -700), false)   # 탄막에는 저격 유도탄이 섞여 날아온다
	_check("kraken barrage brings homing missiles along", b.atk != null and b.atk.kind == "ring" and b.is_lingering("snipe"))
	_check("kraken melee waits while homing missiles are still coming", not b._shots_clear(Vector2(300, -700)))
	b.reset()
	for k in b.CROWD_CAP + 5:                                # 화면에 탄이 많으면 다음 공격을 미룬다
		b.shots.spawn(Vector2(300, -900), Vector2(0, 0), 10.0)
	b._choose(Vector2(300, -700))
	_check("kraken holds the next attack while the screen is crowded", b.atk == null and b.lingering.is_empty())
	b.reset()
	b.next_t = 99.0
	_check("kraken emitters: siphon + tentacle tips + legs", b.emitters().size() == 9)
	var fixed_a: Array = []                                 # 고정 탄막: 플레이어가 어디 있든 같은 방향으로 쏜다
	for pp in [Vector2(-150, -300), Vector2(120, -500), Vector2(-1000, -1200)]:   # 같은 구역(바로 아래) 두 곳 + 왼쪽
		b.reset()
		b.next_t = 99.0
		b.start_attack(b._fire("ink", pp, false))
		for k in 80:
			b.step(DT, pp)
		fixed_a.append(b.shots.vel[0].angle() if b.shots.size() > 0 else 99.0)
	_check("ink fires in fixed directions: same within a sector, another sector picks another (%s)" % str(fixed_a), absf(fixed_a[0] - fixed_a[1]) < 0.001 and absf(fixed_a[0] - fixed_a[2]) > 0.3)
	var lsw = b.Lash.new(4, true)                           # 고정 휩쓸기: 바깥 수평 → 아래
	lsw.boss = b
	lsw.aim_at(Vector2(900, -300))
	_check("fixed sweep: left-low tentacle sweeps from outer horizontal to straight down (%.2f -> %.2f)" % [lsw.th0, lsw.th1], lsw.th0 > PI and lsw.th1 < PI * 0.5)
	main.debug.god = true
	p.reset(b.CORE_POS + Vector2(0, b.SHIELD_R + 200.0), false)
	var a0: int = b.core.armor_hp
	_dash_dir("charge", Vector2.UP)
	var bounced := false
	for k in 30:
		main.hitstop = 0
		main._physics_process(DT)
		if p.vel.y > 0.0 and b.shield_flash > 0.0:
			bounced = true
	_check("charge into the shield: blocked, no core damage, bounced out (core %d)" % b.core.armor_hp, b.core.armor_hp == a0 and bounced)
	main.on_strike(sh, 12, p.position, Vector2.UP, "power", false, false)
	_check("reverse drive pierces the shield (core %d -> %d)" % [a0, b.core.armor_hp], b.core.armor_hp == a0 - 12)
	for k in 30:
		b.damage(sh, 16)
	_check("shield breaks when the core is worn down to the floor (%d, phase %d)" % [b.core.armor_hp, b.phase], b.core.armor_hp == b.SHIELD_FLOOR and not b.core.broken and b.phase == 2)
	main.debug.god = false
	main.reset_run()
	b.next_t = 99.0
	var c1: int = b.core.armor_hp
	b.damage_part(0, 8)
	_check("one intercept cuts a tentacle and hurts the core (+bonus) (%d -> %d)" % [c1, b.core.armor_hp], not b.part_alive(0) and b.core.armor_hp == c1 - 8 - b.CUT_BONUS and b.phase == 1)
	for k in int((b.REGROW_DELAY + b.REGROW + 0.3) / DT):
		b.next_t = 99.0
		b.step(DT, Vector2(0, -700))
	_check("a cut tentacle slowly regrows (grown %.2f)" % b.grown[0], b.part_alive(0) and b.tent_ready(0))
	var n0: int = b.shards.size()
	for i in 6:
		b.damage_part(i, 1)
	_check("all six cut at once -> shield shatters (phase %d, shards +%d)" % [b.phase, b.shards.size() - n0], b.phase == 2 and b.shards.size() - n0 >= 10)

	# 첫 타 여유: 단독 내려치기는 판정까지 LEAD_K 배, 연타의 두 번째부터는 원래 박자
	main.reset_run()
	b.next_t = 99.0
	var h = b.Hammer.new(1)
	b.start_attack(h)
	h.claim()
	var t_first := _frames_to_strike(h, Vector2(300, -1300))
	main.reset_run()
	b.next_t = 99.0
	h = b.Hammer.new(1)
	h.lead = false
	b.start_attack(h)
	h.claim()
	var t_plain := _frames_to_strike(h, Vector2(300, -1300))
	_check("first hit telegraphs longer (%d vs %d frames)" % [t_first, t_plain], absf(float(t_first) / t_plain - h.LEAD_K) < 0.08)

	# 연타 3종: 서로 다른 촉수가 처음부터 함께 올라오고, 또렷한 예고는 한 번에 하나, 순서대로 친다
	for kind in ["pound"]:                                  # 연속 내려치기 (내려치기·소용돌이·행진을 하나로)
		main.reset_run()
		b.next_t = 99.0
		var ready: Array[int] = [0, 1, 2, 3, 4, 5]
		var c = b._pound(ready, Vector2(300, -1300))
		b.start_attack(c)
		var bright := 0
		var raised := 0
		for k in 900:
			main.hitstop = 0
			p.position = Vector2(300, -1300)
			p.vel = Vector2.ZERO
			p.invuln = 99.0
			main._physics_process(DT)
			if k == 2:
				for a in c.kids:
					if b.busy[a.tents[0]] == a:
						raised += 1
			var n := 0
			for a in b.lingering:
				if a.melee_warning() and not a.queued():
					n += 1
			bright = maxi(bright, n)
			if b.atk == null:
				break
		var want_n: int = b.COMBO_HITS
		var ordered: bool = c.kids.size() == want_n
		for j in range(1, c.kids.size()):
			if c.kids[j].fired_t <= c.kids[j - 1].fired_t:
				ordered = false
		_check("%s combo: %d tentacles raised together, one bright warning at a time (%d), strikes in order, ends" % [kind, raised, bright], b.atk == null and raised == want_n and bright == 1 and ordered)

	# 차지 완료 순간 짧은 슬로우
	main.reset_run()
	p.reset(Vector2(0, -1300), false)
	main.slowmo = 0.0
	p.press_dash()
	for k in int(p.charge_need() / DT) + 3:
		main.hitstop = 0
		main._physics_process(DT)
		if main.slowmo > 0.0:
			break
	_check("charge complete -> brief slow-mo (%.2f)" % main.slowmo, main.slowmo > 0.0 and main.slowmo <= main.CHARGED_SLOW)
	p.release_dash()
	main.reset_run()


## 내려치기가 판정을 낼 때까지 프레임 수 (플레이어는 무적으로 고정)
func _frames_to_strike(h, at: Vector2) -> int:
	for k in 600:
		main.hitstop = 0
		main.player.position = at
		main.player.vel = Vector2.ZERO
		main.player.invuln = 99.0
		main._physics_process(DT)
		if h.phase == "strike":
			return k
	return -1


## v0.47: 크라켄(촉수 요격·구동부·조이기·방전 그물·소용돌이), 강습 코어, 코어가 열리는 중에도 맞음 + 코어 안에 박히지 않음
func _v047_test() -> void:
	main.start_stage(2)
	var b = main.boss
	var p = main.player
	_check("stage 3 is the kraken (%s, parts %d, hp %d)" % [b.get_script().resource_path.get_file(), b.part_count(), b.part_hp[0]],
		b.get_script().resource_path.ends_with("kraken.gd") and b.part_count() == 6 and b.part_hp[0] == 16 and b.phase == 1)
	b.next_t = 99.0

	# 몸통 내려치기: 들어 올려 멈춘 동안(set) 차지 강습으로 요격 → 그 촉수 구동부 -8, 부딪힌 방향으로 크게 튕겨 나감
	p.reset(Vector2(300, -1300), false)
	var s = b.Hammer.new(1)
	b.start_attack(s)
	s.claim()
	for k in 200:
		main.hitstop = 0
		p.position = Vector2(300, -1300)
		p.vel = Vector2.ZERO
		p.invuln = 1.0
		main._physics_process(DT)
		if s.phase == "set":
			break
	_check("hammer raises a horizontal bar above the player (cx %.0f, top %.0f, stop %.0f)" % [s.cx, s.y_top, s.y_stop],
		s.phase == "set" and absf(s.cx - 300.0) < 1.0 and absf(s.y_top - (-1820.0)) < 1.0 and absf(s.y_stop - (-920.0)) < 1.0)
	_check("hammer: no hitbox while raised, but interceptable", b.hitboxes(p.position).filter(func(h): return h["id"] == "arm").is_empty() and not b.clash_box(p.position).is_empty())
	var bar_mid: Vector2 = b.spines[1][8]
	var tip0: Vector2 = b.spines[1][b.N - 1]
	p.invuln = 0.0
	p.reset(bar_mid + Vector2(0, 150), false)
	var hp1: int = b.part_hp[1]
	var core1: int = b.core.armor_hp
	p.aim = Vector2.UP
	var lock_up: bool = p._intercept_on_path(790.0)
	p.aim = Vector2.DOWN
	_check("intercept lock: a charge aimed at an interceptable tentacle locks onto it (up %s, down %s)" % [lock_up, p._intercept_on_path(790.0)], lock_up and not p._intercept_on_path(790.0))
	_dash_dir("charge", Vector2.UP)
	for k in 6:
		main.hitstop = 0
		main._physics_process(DT)
	_check("hammer intercept: the tentacle is smashed at once (hp %d -> %d, %d pieces)" % [hp1, b.part_hp[1], b.debris.size()], b.part_hp[1] == 0 and b.atk == null and b.debris.size() == 3)
	_check("intercept also hurts the shielded core (+cut bonus), with a zap to it (core %d -> %d, zaps %d)" % [core1, b.core.armor_hp, b.zaps.size()], b.core.armor_hp == core1 - 8 - b.CUT_BONUS and b.zaps.size() == 1)
	_check("intercept gives a quick charge (need %.2f)" % p.charge_need(), p.quick_t > 0.0 and absf(p.charge_need() - p.stats.charge_time * 0.5) < 0.001)

	# 내려치기 판정: 막대가 지나가는 곳은 맞고(근접 = 회피 불가), 막대 끝 밖은 안전
	main.reset_run()
	b.next_t = 99.0
	p.reset(Vector2(-200, -1200), false)
	s = b.Hammer.new(4)
	b.start_attack(s)
	s.claim()
	var hit_in := false
	var hit_out := false
	for k in 300:
		main.hitstop = 0
		p.position = Vector2(-200, -1200)
		p.vel = Vector2.ZERO
		p.invuln = 1.0
		main._physics_process(DT)
		if s.phase == "strike":
			for h in b.hitboxes(Vector2(-200, -1200)):
				if h["id"] == "arm" and h["melee"] and b.overlaps(h, Vector2(-200, -1200), 12.0):
					hit_in = true
			for h in b.hitboxes(Vector2(s.cx + s.HALF_LEN + 80.0, -1200)):
				if h["id"] == "arm" and b.overlaps(h, Vector2(s.cx + s.HALF_LEN + 80.0, -1200), 12.0):
					hit_out = true
		if b.atk == null:
			break
	_check("hammer bar sweeps down through the player (melee)", hit_in)
	_check("hammer: beyond the bar's end is safe", not hit_out)

	# 그냥 패리: 튕겨나기만 하고 구동부 피해 없음 (회색 튕김 피드백)
	main.reset_run()
	b.next_t = 99.0
	p.reset(Vector2(-200, -1200), false)
	s = b.Hammer.new(4)
	b.start_attack(s)
	s.claim()
	for k in 300:
		main.hitstop = 0
		p.position = Vector2(-200, -1200)
		p.vel = Vector2.ZERO
		p.invuln = 1.0
		main._physics_process(DT)
		if s.phase == "strike" and s.y_bar > -1290.0:
			break
	var hp4: int = b.part_hp[4]
	p.invuln = 0.0
	p.position = Vector2(-200, -1200)
	p.vel = Vector2.ZERO
	p.parry_press()
	for k in 8:
		main.hitstop = 0
		main._physics_process(DT)
		if p.vel.length() > 600.0:
			break
	p.parry_release()
	_check("hammer parry: pushed away, no damage, no life lost (hp %d, |v| %.0f)" % [b.part_hp[4], p.vel.length()], b.part_hp[4] == hp4 and main.lives == p.stats.shield_cells and p.vel.length() > 600.0)

	# 추적 감아치기: 따라다니다 멈춰 부채꼴로 감아친다
	main.reset_run()
	b.next_t = 99.0
	p.reset(Vector2(100, -1300), false)
	var ch = b.Chase.new(3)
	b.start_attack(ch)
	ch.claim()
	var whipped := false
	var follow_hurt := false
	for k in 400:
		main.hitstop = 0
		p.position = Vector2(400 + sin(k * 0.03) * 200.0, -1200)
		p.vel = Vector2.ZERO
		p.invuln = 99.0
		main._physics_process(DT)
		var hs: Array = b.hitboxes(p.position).filter(func(h): return h["id"] == "arm")
		if ch.phase == "follow" and not hs.is_empty():
			follow_hurt = true
		if ch.phase == "whip":
			whipped = true
		if b.atk == null:
			break
	_check("chase follows without a hitbox, then whips and ends", whipped and not follow_hurt and b.atk == null)

	# 어시스트: 요격할 수 있는 촉수가 조준 범위 안이면 구동부보다 먼저 잡는다
	main.reset_run()
	b.next_t = 99.0
	p.reset(Vector2(300, -1300), false)
	s = b.Hammer.new(1)
	b.start_attack(s)
	s.claim()
	for k in 200:
		main.hitstop = 0
		p.position = Vector2(300, -1300)
		p.vel = Vector2.ZERO
		p.invuln = 1.0
		main._physics_process(DT)
		if s.phase == "warn":
			break
	var its: Array = b.assist_targets(p.position).filter(func(a): return a.get("intercept", false))
	_check("an interceptable tentacle gives an intercept assist target", its.size() == 1)
	var to_bar: Vector2 = (its[0]["pos"] - p.position).normalized()
	var aimed: Vector2 = p._assisted(to_bar.rotated(0.15), 790.0, 0.0)
	_check("assist prefers the intercept target (off by %.2f rad)" % absf(aimed.angle_to(its[0]["pos"] - p.position)), absf(aimed.angle_to(its[0]["pos"] - p.position)) < 0.05)

	# 촉수가 끊기면 뿌리째 떨어져 나가고(토막이 빠르게 날아감), 그 촉수를 쓰던 보조 공격도 끊긴다
	main.reset_run()
	b.next_t = 99.0
	var side = b.Hammer.new(5, false, 0.5)
	b.start_side(side)
	side.claim()
	_check("second hammer is a side attack holding its tentacle", b.lingering.has(side) and b.busy[5] == side)
	b.damage_part(5, 99)
	_check("breaking a tentacle cuts its side attack", not b.lingering.has(side))
	_check("broken tentacle detaches: 3 fast pieces, only the root left (grown %.1f, speed %.0f)" % [b.grown[5], b.debris[0]["vel"].length() if b.debris.size() > 0 else 0.0],
		b.grown[5] == 0.0 and b.debris.size() == 3 and b.debris[0]["vel"].length() > 900.0 and b.spines[5][b.N - 1].distance_to(b.ROOTS[5]) < 1.0)
	main.hitstop = 0
	main._physics_process(DT)
	_check("broken tentacle is not ready", not b.tent_ready(5) and b.busy[5] == null)

	# 표적 표시: 평소엔 가운데 점만, 차지·조준 중에만 강조 (모든 콜로서스 공통 — 그리기 오류 없이 도는지만)
	b.focus_glow = 0.0
	b.queue_redraw()
	main.hitstop = 0
	main._physics_process(DT)

	# 휩쓸기: 겨눈 플레이어 위를 쓸고 지나간다
	main.reset_run()
	b.next_t = 99.0
	var lash = b.Lash.new(1)
	b.start_attack(lash)
	lash.claim()
	var pp := Vector2(900, -700)
	var swept := false
	for k in 400:
		main.hitstop = 0
		p.position = pp
		p.vel = Vector2.ZERO
		p.invuln = 99.0
		main._physics_process(DT)
		for h in b.hitboxes(pp):
			if h["id"] == "arm" and b.overlaps(h, pp, 12.0):
				swept = true
		if b.atk == null:
			break
	_check("sweep passes over the player it aimed at", swept)

	# 조이기: 고리가 만들어지면 판정, 위에 틈, 한쪽을 요격하면 둘 다 풀린다
	main.reset_run()
	b.next_t = 99.0
	var con = b.Constrict.new(0, 1)
	b.start_attack(con)
	con.claim()
	for k in 200:
		main.hitstop = 0
		p.position = Vector2(0, -1300)
		p.vel = Vector2.ZERO
		p.invuln = 99.0
		main._physics_process(DT)
		if con.phase == "set":
			break
	var c0: Vector2 = con.center
	var ring_hb: Array = b.hitboxes(c0).filter(func(h): return h["id"] == "arm")
	_check("constrict: ring of two arcs around the player (centre untouched)", ring_hb.size() == 2 and not b.overlaps(ring_hb[0], c0, 12.0) and not b.overlaps(ring_hb[1], c0, 12.0))
	var on_ring: Vector2 = c0 + Vector2(-con.r, 0)
	var ring_hb2: Array = b.hitboxes(on_ring).filter(func(h): return h["id"] == "arm")
	_check("constrict: touching the ring hurts", ring_hb2.size() == 2 and (b.overlaps(ring_hb2[0], on_ring, 12.0) or b.overlaps(ring_hb2[1], on_ring, 12.0)))
	var top_gap: Vector2 = c0 + Vector2(0, -con.r)
	var ring_hb3: Array = b.hitboxes(top_gap).filter(func(h): return h["id"] == "arm")
	_check("constrict: no gap, the top is closed too", b.overlaps(ring_hb3[0], top_gap, 12.0) or b.overlaps(ring_hb3[1], top_gap, 12.0))
	var hb0: Dictionary = b.clash_box(on_ring)
	var hp0: int = b.part_hp[0]
	p.dash_kind = "charge"
	p.dash_t = 0.1
	p.vel = Vector2.LEFT * 3000.0
	main._clash(hb0, on_ring)
	_check("constrict intercept: that tentacle is cut at once, ring released (hp %d->%d)" % [hp0, b.part_hp[0]], b.part_hp[0] == 0 and b.atk == null)

	# 방전 그물: 패리 불가, 세로 띠가 좌→우 / 우→좌로 경기장을 훑는다 (아래→위는 없다)
	for to_right in [true, false]:
		main.reset_run()
		b.next_t = 99.0
		var net = b.Net.new(to_right)
		b.start_attack(net)
		var crossed := false
		var px := -200.0 if to_right else 200.0
		for k in 600:
			main.hitstop = 0
			p.position = Vector2(px, -1500)
			p.vel = Vector2.ZERO
			p.invuln = 99.0
			main._physics_process(DT)
			if b.beam_hit(Vector2(px, -1500), 12.0) != Vector2.ZERO:
				crossed = true
			if b.atk == null:
				break
		_check("net sweeps %s: the band crosses the player and ends (bg_hold cleared)" % ("left->right" if to_right else "right->left"), crossed and b.atk == null and b.bg_hold.is_empty())
	main.reset_run()
	b.next_t = 99.0
	var net2 = b.Net.new(true)
	b.start_attack(net2)
	main.hitstop = 0
	main._physics_process(DT)
	var wp: Array = b.unparry_points(Vector2(300, -1500))
	_check("net warning point is on the band at the player's height (%s)" % str(wp), wp.size() == 1 and absf(wp[0].y + 1500.0) < 1.0 and wp[0].x < -1000.0)
	net2.x = 800.0
	net2.x_prev = 790.0
	_check("net: no warning once the band has passed the player", b.unparry_points(Vector2(300, -1500)).is_empty())
	net2.x_prev = net2.x
	net2.set_phase("sweep")
	_check("net hit width equals the drawn band (inside hurts, 80px outside is safe)", b.beam_hit(Vector2(800.0 + net2.HALF - 5.0, -1500), 0.0) != Vector2.ZERO and b.beam_hit(Vector2(800.0 + net2.HALF + 80.0, -1500), 0.0) == Vector2.ZERO)
	b.atk = null
	b.bg_hold = []

	# 코어 페이즈: 촉수 둘이 재기동, 소용돌이는 동시에 예고하는 촉수가 최대 2개
	main.reset_run()
	b.next_t = 99.0
	for i in 6:
		b.damage_part(i, 99)
	_check("all drive units -> mantle opens", b.phase == 2)
	for k in int((b.REGROW_DELAY + b.REGROW + 0.3) / DT):
		b.next_t = 99.0
		b.step(DT, Vector2(0, -700))
	_check("kraken core phase, cut tentacles regrown (phase %d, busy %s)" % [b.phase, str(b.busy)], b.phase == 3 and b.tent_ready(2) and b.tent_ready(3))
	b.next_t = 99.0
	b.atk = null
	var rr: Array[int] = [2, 3]
	var vx = b._pound(rr, Vector2(300, -1200))
	b.start_attack(vx)
	var most := 0
	for k in 600:
		main.hitstop = 0
		p.position = Vector2(sin(k * 0.05) * 500.0, -1200)
		p.vel = Vector2.ZERO
		p.invuln = 99.0
		main._physics_process(DT)
		var warn := 0
		for a in b.lingering:
			if a.melee_warning():
				warn += 1
		most = maxi(most, warn)
		if b.atk == null:
			break
	_check("vortex finishes with at most 2 tentacles telegraphing at once (max %d)" % most, b.atk == null and most >= 1 and most <= 2)
	_check("core phase: the core is the target", not b.strike_hit(b.CORE_POS, 10.0).is_empty() and b.strike_hit(b.CORE_POS, 10.0)["kind"] == "core")
	var ca: int = b.core.armor_hp
	_check("core phase: intercepting a tentacle cuts it and hurts the core (%d)" % ca, not b.intercept_core(2, 8) and b.core.armor_hp == ca - 8 - b.CUT_BONUS and not b.part_alive(2))

	var eye = b.Rings.new(b.CORE_POS)                      # 코어 단계: 눈알 동심원 (패리 불가)
	eye.count = 3
	b.start_attack(eye)
	var ringed := false
	for k in 300:
		b.step(DT, Vector2(0, -900))
		if b.beam_hit(Vector2(0, -900), 12.0) != Vector2.ZERO:
			ringed = true
	_check("eye rings reach the player (unparryable)", ringed)
	b.lingering.clear()
	b.atk = null

	_kraken_shield_test()
	b = main.boss
	p = main.player

	# 기본 시스템: 요격에 성공하면 차지 쿨다운이 바로 초기화된다 (코어 없이도). 강습 코어는 연쇄 요격 피해 +2 씩 (최대 +6)
	p.reset(Vector2(300, -1000), false)
	p.stats.assault = false
	p.charge_cd = 1.5
	p.on_intercept()
	_check("base: intercept clears the charge cooldown without any core", p.charge_cd == 0.0 and p.chain == 0)
	p.dash_kind = "charge"
	_check("base: intercept damage is the plain 8 without the core", p.intercept_damage() == 8)
	p.stats.assault = true
	p.dash_kind = "charge"
	var dm := []
	for k in 5:
		dm.append(p.intercept_damage())
		p.on_intercept()
	_check("assault core: chain +2 per intercept, capped at +6 (%s)" % str(dm), dm == [8, 10, 12, 14, 14])
	p.chain_t = 0.01
	p.step(0.05)
	_check("assault core: chain breaks after the time runs out", p.chain == 0)
	p.on_intercept()
	p.on_hurt(Vector2.RIGHT)
	_check("assault core: being hit breaks the chain", p.chain == 0)
	p.stats.assault = false

	# 리버스 드라이브 성공 = 잔탄 긁힘(과열) 한 칸 치료
	main.reset_run()
	b.next_t = 99.0
	main.heat = 2
	main.heat_t = 1.0
	main._cure_heat(Vector2(0, -1500))
	_check("reverse drive cures one graze (heat %d, timer %.1f)" % [main.heat, main.heat_t], main.heat == 1 and main.heat_t == main.HEAT_COOL)
	main._cure_heat(Vector2(0, -1500))
	main._cure_heat(Vector2(0, -1500))
	_check("cure never goes below 0", main.heat == 0)
	main.heat = 2
	b.phase = 1
	p.reset(Vector2(0, -1500), false)
	var hit_p := {"kind": "part", "idx": 0, "n": Vector2.UP}
	main.on_strike(hit_p, 1, p.position, Vector2.UP, "dash", false, false)
	_check("a normal dash hit does not cure", main.heat == 2)
	main.on_strike(hit_p, 12, p.position, Vector2.UP, "power", false, false)
	_check("a reverse drive hit cures one graze (heat %d)" % main.heat, main.heat == 1)
	main.on_strike(hit_p, 3, p.position, Vector2.UP, "charge", false, false)
	_check("a charge assault hit does not cure", main.heat == 1)
	main.heat = 0

	# 처치: 강습 코어 획득
	var old = main.profile
	var mp = main.Profile.new()
	mp.persist = false
	main.profile = mp
	main._core_destroyed(b.core.center)
	_check("kraken clear gives the assault core", mp.cores.has("assault") and mp.cleared.has("kraken"))
	main.profile = old

	# 코어가 열리는 중(페이즈 2)에도 돌진이 맞고, 아래에서 맞혀도 코어 안으로 솟구치지 않는다
	main.start_stage(1)
	b = main.boss
	p = main.player
	b.next_t = 99.0
	for i in 4:
		b.damage_part(i, 99)
	_check("fortress opening (phase 2)", b.phase == 2)
	main.debug.god = true
	p.reset(Vector2(0, -1050), false)
	var a0: int = b.core.armor_hp
	_dash_dir("dash", Vector2.UP)
	for k in 40:
		main.hitstop = 0
		main._physics_process(DT)
	main.debug.god = false
	_check("dash hits the core while it is opening (armor %d -> %d)" % [a0, b.core.armor_hp], b.core.armor_hp == a0 - 1)
	_check("hit from below rebounds outward, not into the core (y %.0f)" % p.position.y, not Geometry2D.is_point_in_polygon(p.position, b.core.shell_poly) and p.position.y > -1380.0)

	# 잔탄 체력 링: 평소엔 안 보이고, 잔탄 하나에 2칸, 5초 뒤 3칸으로 돌아오고 잠시 뒤 사라진다
	main.reset_run()
	b.next_t = 99.0
	p.reset(Vector2(300, -1500), false)
	_step(2)
	_check("heat ring hidden at first", p.heat_vis <= 0.0 and p.heat_cells == 3)
	p.invuln = 0.0
	p.small_guard = 0.0
	b.shots.spawn(p.position, Vector2.ZERO, 5.0, 1.0, 0.0, b.shots.Kind.SMALL)
	main.hitstop = 0
	main._physics_process(DT)
	main._physics_process(DT)
	_check("one small hit: ring shows 2 of 3 (heat %d, cells %d)" % [main.heat, p.heat_cells], main.heat == 1 and p.heat_cells == 2 and p.heat_vis > 0.0)
	for k in int((main.HEAT_COOL + 0.2) / DT):
		p.position = Vector2(300, -1500)
		p.vel = Vector2.ZERO
		main.hitstop = 0
		main._physics_process(DT)
	_check("cooled after 5 s: ring back to 3 and still shown", main.heat == 0 and p.heat_cells == 3 and p.heat_vis > 0.0)
	for k in int((p.HEAT_RING_HOLD + p.HEAT_RING_FADE + 0.2) / DT):
		p.position = Vector2(300, -1500)
		p.vel = Vector2.ZERO
		main.hitstop = 0
		main._physics_process(DT)
	_check("then the ring disappears", p.heat_vis <= 0.0)
	main.start_stage(0)


## 번역: 소스에서 Loc.t("...") 로 감싼 한글 문자열은 모두 영어 표에 있어야 한다 (누락이 영어 화면에 한글로 남지 않게)
func _i18n_test() -> void:
	var Loc = load("res://scripts/loc.gd")
	var rx := RegEx.new()
	rx.compile("Loc\\.t\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	var han := RegEx.new()
	han.compile("[\uac00-\ud7a3]")
	var missing := []
	var total := 0
	var dir := DirAccess.open("res://scripts")
	for f in dir.get_files():
		if not f.ends_with(".gd") or f == "loc.gd":                      # loc.gd 의 머리 주석에 사용 예가 있다
			continue
		var text := FileAccess.get_file_as_string("res://scripts/" + f)
		for m in rx.search_all(text):
			var key: String = m.get_string(1).c_unescape()
			if han.search(key) == null:
				continue
			total += 1
			if not Loc.EN.has(key):
				missing.append(f + ": " + key.substr(0, 30))
	_check("every translated Korean string has an English entry (%d checked, missing %s)" % [total, str(missing)], missing.is_empty() and total > 100)
	Loc.lang = "en"
	_check("English lookup works and falls back to the source text", Loc.t("종료") == "Quit" and Loc.t("표에 없는 문장") == "표에 없는 문장")
	var bad := []
	for k in Loc.EN:
		var kp: int = k.count("%s") + k.count("%d") + k.count("%.1f")
		var ep: int = String(Loc.EN[k]).count("%s") + String(Loc.EN[k]).count("%d") + String(Loc.EN[k]).count("%.1f")
		if kp != ep:
			bad.append(k.substr(0, 20))
	_check("translations keep the same number of format placeholders (%s)" % str(bad), bad.is_empty())
	Loc.lang = "ko"


## 메인 화면: 열기·언어 전환·새 게임 확인·이어하기 비활성·항로도 뒤로가기
func _title_test() -> void:
	var Loc = load("res://scripts/loc.gd")
	var TitleMenu = load("res://scripts/title_menu.gd")
	main.start_stage(0)
	var t = TitleMenu.new()
	main.add_child(t)
	var pr = main.Profile.new()
	pr.persist = false
	t.profile = pr
	t.open()
	_check("title opens", t.visible)
	var started := [0]
	var cont := [0]
	t.start_requested.connect(func() -> void: started[0] += 1)
	t.continue_requested.connect(func() -> void: cont[0] += 1)
	var texts := []
	for b in t.root.find_children("*", "Button", true, false):
		texts.append(b.text)
	_check("fresh title: Start / Continue / How to Play / Quit (%s)" % str(texts), texts.size() == 4 and texts[0] == "시작")
	var cb: Button = t.root.find_children("*", "Button", true, false)[1]
	_check("Continue is disabled without progress", cb.disabled)
	t.can_resume = true                                       # ESC 메뉴에서 왔을 때: 이어하기(멈춘 판으로) + 스테이지 선택이 따로
	t._build()
	var rt := []
	for bb in t.root.find_children("*", "Button", true, false):
		rt.append(bb.text)
	_check("from the pause menu: Continue (resume) and Stage Select are separate (%s)" % str(rt), rt.size() == 5 and rt[1] == "이어하기" and rt[2] == "스테이지 선택 (항로도)")
	t.can_resume = false
	t._build()
	t._on_flag("en")
	var en_texts := []
	for b in t.root.find_children("*", "Button", true, false):
		en_texts.append(b.text)
	_check("flag switches the language and rebuilds (%s)" % str(en_texts), Loc.lang == "en" and en_texts[0] == "Start" and en_texts[3] == "Quit")
	var flags: Array = t.root.find_children("*", "Control", true, false).filter(func(c): return c.get_script() != null and c.get("lang") != null)
	_check("two flag buttons, English one selected", flags.size() == 2 and flags[0].lang == "en" and flags[0].selected and not flags[1].selected)
	t._on_new()
	_check("Start begins a new game at once when there is no progress", started[0] == 1)
	pr.cleared.append("observer")
	t.open()
	var cb2: Button = t.root.find_children("*", "Button", true, false)[1]
	_check("Continue is enabled with progress", not cb2.disabled)
	t._on_new()
	_check("with progress New Game asks to confirm first (started %d, confirm %s)" % [started[0], t._confirm_new], started[0] == 1 and t._confirm_new)
	t._on_new()
	_check("second press starts the new game", started[0] == 2)
	t.open()
	t._on_flag("ko")
	_check("flag back to Korean", Loc.lang == "ko")
	t.free()

	# 항로도의 "뒤로": 타이틀에서 연 경우에만 보이고, 누르면 타이틀이 열린다
	main.world.profile = main.profile
	main.open_world(true)
	_check("route map opened from the title shows Back", main.world.visible and main.world.back_button.visible)
	main.world.back()
	_check("Back closes the map and reopens the title, unpaused", not main.world.visible and main.title.visible and not main.get_tree().paused)
	main.title.close()
	main.open_world(false)
	_check("route map opened otherwise has no Back", main.world.visible and not main.world.back_button.visible)
	main.world.close()
	main.get_tree().paused = false
	main.start_stage(0)


## 패턴 고르기 원칙: 구역 가중치, 근접은 날아오는 탄이 걷힌 뒤에만
func _zone_test() -> void:
	main.start_stage(2)
	var k = main.boss
	_check("kraken: floor sweep is likely when low, rare when high (%.2f vs %.2f)" % [k._zone_w("sweep", Vector2(0, -300)), k._zone_w("sweep", Vector2(0, -2300))],
		k._zone_w("sweep", Vector2(0, -300)) > 1.0 and k._zone_w("sweep", Vector2(0, -2300)) < 0.1)
	_check("kraken: siphon barrages are rare when the player is above the body", k._zone_w("ink", Vector2(0, -2400)) < 0.3 and k._zone_w("ink", Vector2(0, -600)) >= 1.0)
	main.start_stage(0)
	var o = main.boss
	var pp: Vector2 = o.SHOULDERS[1] + Vector2(300, 500)
	o.shots.clear()
	o.shots.spawn(pp + Vector2(-400, 0), Vector2(300, 0), 5.0)       # 플레이어에게 다가오는 탄
	var swung := 0
	for i in 40:
		o.atk = null
		o.last = ""
		o._choose(pp)
		if o.atk != null and o.atk.kind == "swing":
			swung += 1
	_check("observer: no arm swing while a bullet is coming (%d)" % swung, swung == 0)
	o.shots.clear()
	swung = 0
	seed(5)                                                          # 무작위 뽑기: 시드를 고정해 가끔 실패하지 않게
	for i in 40:
		o.atk = null
		o.last = ""
		o._choose(pp)
		if o.atk != null and o.atk.kind == "swing":
			swung += 1
	_check("observer: arm swing is common in arm reach when clear (%d/40)" % swung, swung >= 10)
	o.atk = null
	main.reset_run()


## 결계 위성 (4스테이지): 결계는 완전 동조 차지·PERFECT 리버스 드라이브만 열고, 열리면 금색 탄막, OPEN_TIME 뒤 닫힌다. 보라 공격은 퍼펙트 회피로 완전 동조
func _satellite_test() -> void:
	main.start_stage(3)
	var b = main.boss
	var p = main.player
	main.debug.god = true
	b.next_t = 99.0
	_check("satellite: stage 4 is the barrier satellite on the orbit stage", main.Stages.LIST[3]["id"] == "satellite" and main.bg.orbit and main.lava.orbit)
	var sh: Dictionary = b.strike_hit(b.CORE_POS + Vector2(0, b.BARRIER_R + 10.0), 20.0)
	_check("satellite: closed barrier is the target (shield)", sh.get("kind", "") == "shield")
	_check("satellite: dash, charge and a normal drive bounce off the barrier",
		b.blocks_strike(sh, "dash", false, false) and b.blocks_strike(sh, "charge", false, false) and b.blocks_strike(sh, "power", false, false))
	var hp0: int = b.core.armor_hp
	b.damage(sh, 5)                                           # 반사탄처럼 blocks_strike 를 거치지 않은 결계 적중
	_check("satellite: reflected shots do not open the barrier", not b.barrier_open and b.core.armor_hp == hp0)
	_check("satellite: a fully synced charge gets through the barrier", not b.blocks_strike(sh, "charge", false, true))
	b.start_attack(b.RadialBurst.new(b.CORE_POS, 8))
	b.damage(sh, 12)
	_check("satellite: a crack staggers it (running attack cut, short rest)", b.atk == null and b.next_t >= b.STAGGER - 0.01)
	_check("satellite: the first two strikes only crack it (cracks %d, open %s, hp %d)" % [b.cracks, b.barrier_open, b.core.armor_hp], b.cracks == 1 and not b.barrier_open and b.core.armor_hp == hp0)
	b.blocks_strike(sh, "power", true, false)
	b.damage(sh, 16)
	b.blocks_strike(sh, "charge", false, true)
	b.damage(sh, 12)
	_check("satellite: the third strike opens it and damages the core (hp %d -> %d)" % [hp0, b.core.armor_hp], b.barrier_open and b.core.armor_hp == hp0 - 12 and b.atk != null and b.atk.kind == "open")
	var mains := 0
	for k in int(2.0 / DT):
		b.step(DT, Vector2(300, -1300))
	for k in b.shots.size():
		if b.shots.kind[k] == b.Projectiles.Kind.BOLT and b.shots.mine[k] == 0:
			mains += 1
	_check("satellite: open barrier pours out gold main bolts to parry (%d)" % mains, mains >= 12)
	_check("satellite: open = the core is the target", b.strike_hit(b.CORE_POS, 10.0).get("kind", "") == "core")
	for k in int(b.OPEN_TIME / DT):
		b.step(DT, Vector2(300, -1300))
	_check("satellite: the barrier closes after OPEN_TIME, cracks reset", not b.barrier_open and b.cracks == 0)
	_check("satellite: right after closing the barrier is sealed (leftover gold bolts cannot reopen it)", b.blocks_strike(sh, "power", true, false) and b.blocks_strike(sh, "charge", false, true))
	for k in int((b.SEAL_GUARD + 0.1) / DT):
		b.step(DT, Vector2(300, -1300))
	_check("satellite: after the seal, a PERFECT reverse drive cracks it too", not b.blocks_strike(sh, "power", true, false))
	b.pending_open = false
	b.reset()                                                 # 아래에서 완전 동조 차지로 결계를 때리면: 긴 무적 + 아래로 충분히 떨어져 나온다
	b.next_t = 99.0
	p.reset(b.CORE_POS + Vector2(0, b.BARRIER_R + 140.0), false)
	p.buffed = true
	p.buff_strong = true
	p.buff_t = 9.0
	_dash_dir("charge", Vector2.UP)
	var hit_at := Vector2.INF
	for k in 30:
		main._physics_process(DT)
		if p.dash_kind == "" and p.shield_t > 0.0:
			hit_at = p.position
			break
	var sh0: float = p.shield_t
	var guard := 0
	while main.hitstop > 0.0 and guard < 60:               # 타격 히트스톱(멈춤) 동안은 움직이지 않는다
		main._physics_process(DT)
		guard += 1
	for k in int(0.5 / DT):
		main._physics_process(DT)
	_check("full-sync hit on the barrier from below: long invulnerability (%.2f) and clear of it 0.5s after the hit-stop (%.0f px)" % [sh0, p.position.distance_to(hit_at) if hit_at.is_finite() else -1.0],
		hit_at.is_finite() and sh0 >= p.STRONG_SHIELD - 0.05 and p.position.distance_to(hit_at) > 260.0 and p.position.y > hit_at.y)
	main.debug.god = true
	# 보라 공격: 궤도 광선 · 결계면 · 노드 분사가 돌고, 광선·벽은 패리 불가 판정
	b.reset()
	b.shots.clear()
	var seen := {}
	var beam_hit := false
	var pp := Vector2(200, -900)
	for k in int(80.0 / DT):
		b.step(DT, pp)
		for a in b.active_attacks():
			seen[a.kind] = true
		if b.beam_hit(pp, 12.0) != Vector2.ZERO:
			beam_hit = true
	_check("satellite: closed patterns cycle with small side attacks (%s)" % str(seen.keys()), seen.has("burst") and seen.has("lattice") and seen.has("orbit") and seen.has("wall") and seen.has("spray") and not seen.has("open"))
	var bz = b.RadialBurst.new(b.CORE_POS, 10)
	bz.boss = b
	bz.phase = "fire"
	var on_beam: Vector2 = b.CORE_POS + Vector2.from_angle(bz._angle(0)) * 800.0
	var between: Vector2 = b.CORE_POS + Vector2.from_angle(bz._angle(0) + PI / 10.0) * 800.0
	_check("barrier storm: only the thin beam core hurts, the space between beams is safe", bz.beam_hit(on_beam, 12.0) != Vector2.ZERO and bz.beam_hit(between, 12.0) == Vector2.ZERO)
	bz.mark_dodged(on_beam, 12.0)
	_check("barrier storm: a dodged beam no longer hits, others still do", bz.beam_hit(on_beam, 12.0) == Vector2.ZERO and bz.dodged_beams == [0])
	_check("satellite: purple attacks reach the player", beam_hit)
	var lt = b.Lattice.new()
	lt.boss = b
	var cnt := func(at_t: float) -> int:
		lt.t = at_t
		var n := 0
		for i in lt.lines.size():
			if lt.t >= lt._on_at(i):
				n += 1
		return n
	var c1: int = cnt.call(lt.WARN + 0.01)
	var c4: int = cnt.call(lt.WARN + lt.STEP_T * 3 + 0.01)
	_check("lattice: lines stay lit and keep adding up (first %d -> last %d), the first step is vertical only" % [c1, c4], c1 > 0 and c4 > c1 * 2 and lt.lines[0]["vert"])
	lt.t = lt.WARN + 0.1
	var lx: float = lt.lines[0]["at"]
	_check("lattice: a lit line still hurts later in the pattern", lt.beam_hit(Vector2(lx, -900), 12.0) != Vector2.ZERO)
	lt.mark_dodged(Vector2(lx, -900), 12.0)
	_check("lattice: an absorbed line disappears (only that line)", lt.beam_hit(Vector2(lx, -900), 12.0) == Vector2.ZERO and lt.absorbed.size() == 1)
	# 보라 공격: 일반 무적 회피는 통과만 (흡수 안 됨), 퍼펙트 회피(완전 동조)만 흡수
	b.reset()
	b.shots.clear()
	var wl = b.BarrierWall.new(Vector2(500, -900))
	b.start_attack(wl)
	wl.phase = "move"
	wl.x = -300.0
	wl.x_prev = -300.0
	p.reset(Vector2(-300, -900), false)
	_dash_dir("dash", Vector2.RIGHT)
	p.evade_window = 0.0                                      # 퍼펙트 회피 판정 시간은 지났다 (무적만)
	p.dash_age = 0.05
	main._check_attacks()
	_check("purple: a plain invulnerable dash just passes, the wall is not absorbed", not wl.dodged and not p.buff_strong)
	p.reset(Vector2(-300, -900), false)
	_dash_dir("dash", Vector2.RIGHT)
	main._check_attacks()
	_check("purple: a perfect evade gives full sync and absorbs the wall (it vanishes)", wl.dodged and p.buffed and p.buff_strong)
	b.atk = null
	# 완전 동조 차지: PERFECT 드라이브처럼 빠르고 사거리는 같다 / 반작용은 공격 세기 순
	p.reset(Vector2(-700, -1500), false)
	p.buffed = true
	p.buff_strong = true
	_dash_dir("charge", Vector2.RIGHT)
	_check("full-sync charge follows PERFECT drive rules: near-instant (speed %.0f), unlimited reach" % p.vel.length(), p.sync_charge and p.vel.length() >= p.PARRY_DASH_SPEED_PERFECT - 1.0 and p._unlimited() and p.charge_reach() >= p.UNLIMITED_REACH)
	# 역추진: 돌진 뒤 남은 관성은 반대쪽 조준으로 빨리 멈추지만, 평소 비행 속도 아래로는 줄이지 않는다
	var drift := func(aim_back: bool) -> float:
		p.reset(Vector2(-700, -1500), false)
		p.vel = Vector2(1100, 0)
		main.touch_ui.stick = Vector2(-1, 0) if aim_back else Vector2.ZERO
		for k in 20:
			main._physics_process(DT)
		main.touch_ui.stick = Vector2.ZERO
		return p.vel.x
	p.reset(Vector2(-700, -1500), false)                    # 적중 직후 튕겨 나올 때: 마우스가 표적(반대쪽)을 가리켜도 BOUNCE_FREE 까지는 브레이크 없음
	p.bounce_off(Vector2.RIGHT, "charge")
	var vx0: float = p.vel.x
	main.touch_ui.stick = Vector2(1, 0)
	for k in 6:
		main._physics_process(DT)
	main.touch_ui.stick = Vector2.ZERO
	_check("bounce after a hit is not braked right away (vx %.0f -> %.0f, %.0f px)" % [vx0, p.vel.x, p.position.distance_to(p.bounce_from)], p.vel.x < vx0 * 0.6 and p.position.distance_to(p.bounce_from) < p.BOUNCE_FREE)
	var v_brake: float = drift.call(true)
	var v_free: float = drift.call(false)
	_check("reverse thrust brakes leftover dash speed quickly (%.0f vs %.0f)" % [v_brake, v_free], v_brake < v_free - 250.0 and v_brake >= p.BRAKE_FROM - 600.0)
	main.start_stage(0)                                       # 완전 동조 차지 적중: 차지 쿨다운 즉시 회복 + 잔탄 긁힘 한 칸 치료
	var ob = main.boss
	ob.next_t = 99.0
	var tpp: Vector2 = ob.part_pos(0)
	p = main.player
	p.reset(tpp + Vector2(-160, 0), false)
	p.invuln = 99.0
	main.heat = 2
	p.buffed = true
	p.buff_strong = true
	_dash_dir("charge", Vector2.RIGHT)
	p.charge_cd = 1.0
	for k in 10:
		main._physics_process(DT)
		if p.last_hit_strong:
			break
	_check("full-sync charge hit refunds the charge cooldown and cures one heat (cd %.2f, heat %d)" % [p.charge_cd, main.heat], p.last_hit_strong and p.charge_cd <= 0.0 and main.heat == 1)
	main.heat = 0
	main.start_stage(3)
	b = main.boss
	p = main.player
	p.reset(Vector2(-700, -1500), false)
	_check("recoil grows with the strike: dash < charge < normal drive < PERFECT / full sync",
		p._recoil("dash", false) < p._recoil("charge", false) and p._recoil("charge", false) < p._recoil("power", false) and p._recoil("power", false) < p._recoil("charge", true))
	var w = b.BarrierWall.new(Vector2(500, -900))
	w.boss = b
	_check("barrier wall starts on the far side from the player", w.x0 < 0.0 and w.x1 > 0.0)
	main.debug.god = false
	main.start_stage(0)
