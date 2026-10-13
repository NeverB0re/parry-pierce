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
		absf(p.stats.dash_cooldown - 1.15) < 0.001 and p.DASH_DAMAGE == 1 and p.stats.charge_damage == 3 and p.stats.power_damage == 12 and p.stats.power_damage_perfect == 16 and p.stats.clash_damage == 8 and b.PART_HP == 30 and b.ARMOR_HP == 160 and b.core.CORE_HP == 1)

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
	_check("rises after hit (vy %.0f, up=%.0f)" % [p.vel.y, p.stats.bounce_up], p.vel.y < -p.stats.bounce_up * 0.9 and p.vel.y > -p.stats.bounce_up * 1.4)
	_check("pushed to opposite side of approach (vx %.0f)" % p.vel.x, p.vel.x < 0.0 and p.vel.x > -400.0)
	_check("cooldown not reset on hit (cd %.2f)" % p.dash_cd, p.dash_cd > 0.4 and p.dash_cd <= cd_before)
	_check("bounce height reduced vs v0.6 (1050 -> %.0f)" % p.stats.bounce_up, p.stats.bounce_up < 1050.0 and p.stats.bounce_up >= 800.0)
	_air(pp + Vector2(0, 140))
	_dash_dir("dash", Vector2.UP)
	_step(6)
	_check("hit from below also rises (vy %.0f)" % p.vel.y, p.vel.y < -p.stats.bounce_up * 0.9)
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
	_check("parry dash: 12 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == b.PART_HP - 12)
	_check("part damage stage 1 at 60%% (stage %d)" % b.part_stage[0], b.part_stage[0] == 1)

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
	t.finish("dead", 42.0, 0, {"phase": 1})
	var ok := FileAccess.file_exists(t.last_path)
	var data = JSON.parse_string(FileAccess.get_file_as_string(t.last_path)) if ok else null
	_check("telemetry file written (%s)" % t.last_path, ok and data is Dictionary and data["result"] == "dead" and int(data["counts"]["parry_perfect"]) == 1 and int(data["damage"]["charge"]) == 3 and int(data["hurt"]["beam"]) == 1)
	if ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(t.last_path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://telemetry_test"))
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
	p.dash_kind = "power"                              # 반사는 리버스 드라이브로 돌진하는 동안만
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
	_check("strike bounce gives a shield (%.2f)" % p.shield_t, p.shield_t > 0.0 and p.bouncing)
	var frames := 0
	while p.shield_t > 0.0 and frames < 120:
		_step(1)
		frames += 1
	_check("bounce shield ends when control returns (%.2fs, before dash cooldown %.2f)" % [frames * DT, p.stats.dash_cooldown], frames * DT < p.stats.dash_cooldown - 0.28 and frames * DT >= 0.7 and not p.bouncing)

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
	p.launch_parry_dash()
	_check("reflect is on during the reverse drive", p.is_reflecting())
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
		b.since_homing = 0
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
		b.since_homing = 99
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

	# 돌진패리: 돌진하는 동안(과 끝난 직후 잠깐)의 패리 성공은 눌렀던 타이밍과 상관없이 PERFECT
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	_step(10)                                           # 패리를 누른 지 0.17초 (PERFECT 판정 0.07초는 지났다)
	_dash_dir("dash", Vector2.RIGHT)
	_check("dash-parry state while dashing", p.is_dash_parry() and p.parry_active and p.parry_t > p.PERFECT_WINDOW)
	b.shots.spawn(p.position + Vector2(40, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("parry while dashing is PERFECT even though pressed long ago (aim %s, perfect %s, left %.2f)" % [p.aim_phase, p.aim_perfect, p.aim_left], p.aim_phase and p.aim_perfect)
	var normal_reach: float = p.PARRY_DASH_SPEED_PERFECT * p.PARRY_DASH_TIME
	_check("dash-parry extends the reverse drive range (reach %.0f vs %.0f)" % [p.parry_dash_reach(), normal_reach], p.aim_boost and absf(p.parry_dash_reach() - normal_reach * p.DASH_PARRY_RANGE) < 1.0)
	p.aim = Vector2.RIGHT
	p.launch_parry_dash()
	_check("boosted reverse drive lasts longer (dash %.2fs, boost %s)" % [p.dash_t, p.power_boost], p.power_boost and absf(p.dash_t - p.PARRY_DASH_TIME * p.DASH_PARRY_RANGE) < 0.001)
	var x0: float = p.position.x
	_step(int(0.9 / DT))                                # (퍼펙트 패리 히트스톱 0.2초 포함)
	_check("and goes farther (%.0f px)" % (p.position.x - x0), p.position.x - x0 > normal_reach * 1.15 or p.position.x >= p.WALL_R - 20.0)
	_check("boost ends with the dash", not p.power_boost)
	p.parry_release()
	p.aim_phase = false
	# 돌진하지 않으면 같은 늦은 패리는 보통 판정
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	_step(10)
	_check("not dashing: no dash-parry", not p.is_dash_parry())
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("same late parry without a dash is normal (no extra range)", p.aim_phase and not p.aim_perfect and not p.aim_boost and absf(p.parry_dash_reach() - p.PARRY_DASH_SPEED * p.PARRY_DASH_TIME) < 1.0)
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
	# 차지 강습 중 패리: 오래전에 누른 패리도 PERFECT + 사거리 증가
	p.reset(Vector2(-700, -1500), false)
	main.hitstop = 0.0
	main.slowmo = 0.0
	b.shots.clear()
	p.parry_press()
	_step(10)
	_dash_dir("charge", Vector2.RIGHT)
	b.shots.spawn(p.position + Vector2(40, 0), Vector2.ZERO, 5.0)
	_step(1)
	_check("parry during a charge assault is a PERFECT dash-parry (aim %s, perfect %s, boost %s)" % [p.aim_phase, p.aim_perfect, p.aim_boost], p.aim_phase and p.aim_perfect and p.aim_boost)
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
