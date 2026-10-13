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
		absf(p.stats.dash_cooldown - 1.35) < 0.001 and p.DASH_DAMAGE == 1 and p.stats.charge_damage == 3 and p.stats.power_damage == 12 and p.stats.power_damage_perfect == 16 and p.stats.clash_damage == 8 and b.PART_HP == 24 and b.ARMOR_HP == 160 and b.core.CORE_HP == 1)

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
	_check("dash hit part: 1 dmg (hp %d)" % b.part_hp[0], b.part_hp[0] == 23)
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
	var st = Up.build(base, ["pulse", "reflect"])
	_check("all owned cores apply at once (pulse %s, reflect %s)" % [st.pulse, st.reflect], st.pulse and st.reflect)
	_check("base stats untouched", not base.pulse and not base.reflect)
	_check("no cores = base", not Up.build(base, []).pulse)
	_check("skill tree is gone", not ("NODES" in Up) and not ("nodes" in main.Profile.new()))

	var pr = main.Profile.new()
	pr.path = "user://profile_test.cfg"
	pr.reset()
	var got: Dictionary = pr.record_clear(0)
	_check("first clear: gets the core", got["first"] and got["core"] == "pulse" and pr.cores.size() == 1 and pr.cores[0] == "pulse")
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
	cf.set_value("upgrade", "cores", ["mobility"])
	cf.set_value("upgrade", "equipped", "mobility")
	cf.save(pr.path)
	var pr3 = main.Profile.new()
	pr3.path = pr.path
	pr3.load_from_disk()
	_check("old save migrates (cores %s)" % [pr3.cores], pr3.cores.has("pulse") and pr3.cores.has("reflect") and pr3.cores.size() == 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pr.path))

	# 승리 → 월드 맵 → FTL 도약
	var old = main.profile
	var mp = main.Profile.new()
	mp.persist = false
	main.profile = mp
	main.world.profile = mp
	main.start_stage(0)
	var p = main.player
	_check("no core yet: no pulse", not p.stats.pulse)
	_check("before any clear only stage 1 is open", mp.can_play(0) and not mp.can_play(1))
	main._core_destroyed(main.boss.core.center)
	_check("win records clear and core (state %d, cores %s)" % [main.state, mp.cores], main.state == main.State.WON and mp.cleared.has("observer") and mp.cores.has("pulse"))
	main.open_world()
	_check("world map opens and pauses, ship on the next stage (%d)" % mp.stage, main.world.visible and paused and mp.stage == 1)
	main.world.jump()
	_check("FTL starts", main.ftl.is_playing() and not main.world.visible)
	main.ftl.skip()
	_check("arrived: next stage with the core on (stage %d, pulse %s)" % [main.stage_idx, p.stats.pulse],
		not paused and main.state == main.State.PLAY and main.stage_idx == 1 and p.stats.pulse and main.lives == p.stats.shield_cells)

	# 월드 맵에서 이전 스테이지 다시 고르기
	main.open_world()
	_check("can't pick a stage that doesn't exist yet or isn't unlocked", not main.world.select(2) and not main.world.select(8) and not main.world.select(9) and mp.stage == 1)
	_check("pick a cleared stage again", main.world.select(0) and mp.stage == 0)
	main.world.jump()
	main.ftl.skip()
	_check("replaying stage 1 (stage %d, observer %s)" % [main.stage_idx, main.boss.get_script().resource_path.get_file()], main.stage_idx == 0 and main.boss.get_script().resource_path.ends_with("observer.gd") and p.stats.pulse)
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
	p.stats.pulse = false                              # 앞선 승리로 얻은 파동 코어가 탄을 지우지 않게
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
	p.reflect_t = 0.3
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
	_check("bounce shield ends when control returns (%.2fs, before dash cooldown %.2f)" % [frames * DT, p.stats.dash_cooldown], frames * DT < p.stats.dash_cooldown - 0.28 and not p.bouncing)

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

	# 파동 코어: 기체 중심에서 퍼져 기체를 따라다닌다
	p.reset(Vector2(-700, -1500), false)
	p.stats.pulse = true
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	b.shots.spawn(p.position + Vector2(-110, 40), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	b.shots.spawn(p.position + Vector2(400, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	_step(8)
	_check("pulse core: parry clears nearby bullets only (left %d)" % b.shots.size(), b.shots.size() == 1)
	_step(int(p.PULSE_TIME / DT) + 2)
	_check("pulse ends after %.2fs" % p.PULSE_TIME, p.pulse_t <= 0.0 and p.pulse_radius() == 0.0)
	p.parry_release()
	b.shots.clear()
	# 돌진 중 잔탄을 패리하면 경로의 잔탄도 지우며 나아간다 (파동이 기체를 따라간다)
	p.reset(Vector2(-900, -1500), false)
	_step(int(0.6 / DT))
	_dash_dir("dash", Vector2.RIGHT)
	p.parry_press()
	b.shots.spawn(p.position + Vector2(25, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	b.shots.spawn(p.position + Vector2(330, 0), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	b.shots.spawn(p.position + Vector2(0, -420), Vector2.ZERO, 5.0, 0.0, 0.0, b.shots.Kind.SMALL)
	_step(1)
	_check("bullet ahead on the path is out of reach at first (left %d)" % b.shots.size(), b.shots.size() == 2)
	_step(8)
	_check("pulse follows the ship and clears the path ahead (left %d)" % b.shots.size(), b.shots.size() == 1)
	p.stats.pulse = false
	p.parry_release()
	b.shots.clear()

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
	_check("hard spiral has 3 arms, hard fan 4 waves, hard mines 5", b.Spiral.new(-1, b.SPIRE_TOP, true).arms == 3 and b.Fan.new(-1, b.SPIRE_TOP, Vector2.ZERO, true).wave_n == 4 and b.Mines.new(Vector2.ZERO, true).mines.size() == 5)
	main.start_stage(0)
