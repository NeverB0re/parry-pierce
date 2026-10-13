extends Node2D
## 프로토타입 메인: 루프, 입력, 패리/피격 판정, 카메라, 피드백(히트스톱/흔들림/플래시/사운드).
## 메타 구조: 스테이지(콜로서스 하나) 클리어 → 정비(노드·코어) → FTL 도약 → 다음 스테이지. 진행은 profile 에 저장된다.

const Player := preload("res://scripts/player.gd")
const Ev := preload("res://scripts/ev.gd")
const Fx := preload("res://scripts/fx.gd")
const Ground := preload("res://scripts/ground.gd")
const Background := preload("res://scripts/background.gd")
const Hud := preload("res://scripts/hud.gd")
const Sfx := preload("res://scripts/sfx.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const Telemetry := preload("res://scripts/telemetry.gd")
const Debug := preload("res://scripts/debug.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Quality := preload("res://scripts/quality.gd")
const Profile := preload("res://scripts/profile.gd")
const Stages := preload("res://scripts/stages.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const Hangar := preload("res://scripts/hangar.gd")
const Ftl := preload("res://scripts/ftl.gd")

const SPAWN := Vector2(650, -52)   # 시작 발판 위 (Player.PLAT_CENTER - 반지름)
const CAM_ZOOM := 0.72             # 기본 줌아웃 (튕겨 올라가도 표적이 시야에 남도록)
const MOBILE_AREA := 1.2             # 모바일 시야 면적 = PC 화면의 이 배수 (폰 화면 비율에 맞춰 줌을 계산)
const AIM_ZOOM := 0.82             # 방향 지정 중엔 물러나 표적을 넓게 본다
const CHARGE_ZOOM := 0.85            # 차징 중에만 물러난다
const AIM_SLOW := 0.08             # 방향 지정 중 월드 시간 배율
const DASH_SLOW := 0.5             # 패리 돌진 중 월드 시간 배율 (적중·종료 즉시 원래 속도). 플레이어는 항상 실시간
const RESPAWN_DELAY := 1.3         # 용암에 빠진 뒤 재출격까지
const RESPAWN_INVULN := 1.5
const PLAT_SINK_TIME := 1.0        # 발사 후 발판이 가라앉는 시간
const PLAT_RISE_TIME := 0.6

enum State { PLAY, WON, DEAD, RESPAWN }

var player
var boss
var fx
var hud
var sfx
var bg
var cam: Camera2D
var touch_ui                          # 모바일 터치 조작 (없으면 마우스·키보드)
var menu
var tutorial                          # 튜토리얼 팝업
var tele                              # 플레이 기록 (user://telemetry)
var debug                             # 개발용 디버그 (F1~F8)
var profile                           # 진행 저장 (user://profile.cfg)
var hangar                            # 정비 화면
var ftl                               # FTL 도약 연출
var stage_idx := 0                    # 지금 싸우는 스테이지 (Stages.LIST)

var state := State.PLAY
var hitstop := 0.0
var slowmo := 0.0
var shake := 0.0
var run_time := 0.0
var lives := 0                     # 남은 실드 셀 (최대는 player.stats.shield_cells)
var dead_t := 0.0
var respawn_t := 0.0
var plat_on := true                # 발판 위에 설 수 있는가
var plat_sink := 0.0               # 0 = 떠 있음, 1 = 가라앉음
var plat_dir := 0.0                # +1 가라앉는 중, -1 떠오르는 중
var lava                           # 바닥(용암·발판) 노드
var spawn := SPAWN
var spawn_on_platform := true
var win_t := 0.0                   # 승리 후 흐른 시간 (바로 클릭해 정비로 넘어가는 실수 방지)
var evade_healed := false          # 실드 재충전(U4)을 이번 출격에 썼는가


func _ready() -> void:
	randomize()
	var touch_mode := OS.has_feature("mobile")
	Quality.low = touch_mode                      # 모바일: 연출 일부를 줄여 프레임을 지킨다
	if touch_mode:
		Engine.max_fps = 60
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)   # 가로 화면 고정
	for a in OS.get_cmdline_user_args():
		if a == "--touch":                        # 데스크톱에서 터치 UI 시험
			touch_mode = true
		elif a == "--lowfx":
			Quality.low = true
	if not touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED   # 플레이 중엔 창 밖으로 못 나감 (ESC 메뉴에서 해제)
	for a in OS.get_cmdline_user_args():      # 테스트용: -- --spawn=x,y
		if a.begins_with("--spawn="):
			var xy := a.trim_prefix("--spawn=").split(",")
			if xy.size() == 2:
				spawn = Vector2(xy[0].to_float(), xy[1].to_float())
				spawn_on_platform = false

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg = Background.new()
	bg_layer.add_child(bg)

	profile = Profile.new()
	profile.persist = DisplayServer.get_name() != "headless"
	profile.load_from_disk()
	stage_idx = profile.stage
	lava = Ground.new()
	add_child(lava)
	boss = load(Stages.LIST[stage_idx]["script"]).new()
	add_child(boss)
	player = Player.new()
	player.main = self
	player.boss = boss
	add_child(player)
	fx = Fx.new()
	add_child(fx)
	var fg := Ground.new()
	fg.front = true
	add_child(fg)

	cam = Camera2D.new()
	cam.zoom = Vector2(0.9, 0.9)
	cam.limit_left = -1300
	cam.limit_right = 1300
	cam.limit_top = -3250
	cam.limit_bottom = 90
	add_child(cam)
	cam.make_current()

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)

	sfx = Sfx.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS          # FTL 도약(일시정지 중)에도 소리
	add_child(sfx)
	menu = PauseMenu.new()
	menu.ui_scale = 1.7 if touch_mode else 1.0
	add_child(menu)
	menu.restart_requested.connect(reset_run)
	menu.hangar_requested.connect(open_hangar)
	hangar = Hangar.new()
	hangar.profile = profile
	hangar.ui_scale = menu.ui_scale
	add_child(hangar)
	hangar.jump_requested.connect(_on_jump)
	ftl = Ftl.new()
	add_child(ftl)
	ftl.arrived.connect(_on_arrived)
	tutorial = Tutorial.new()
	tutorial.touch = touch_mode
	tutorial.enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--notutorial")
	add_child(tutorial)
	menu.tutorial = tutorial
	tele = Telemetry.new()
	tele.enabled = DisplayServer.get_name() != "headless"
	debug = Debug.new()
	debug.main = self
	add_child(debug)
	if touch_mode:
		var touch_layer := CanvasLayer.new()
		touch_layer.layer = 20
		add_child(touch_layer)
		touch_ui = TouchControls.new()
		touch_ui.main = self
		touch_layer.add_child(touch_ui)
	_apply_loadout()
	reset_run()
	tutorial.request(["dodge", "parry"])        # 처음 실행: 회피 → 패리 순서로 한 장씩


func reset_run() -> void:
	if tele != null:
		tele.finish("restart", run_time, lives, _tele_extra())
		tele.begin()
	boss.reset()
	fx.clear()
	state = State.PLAY
	run_time = 0.0
	win_t = 0.0
	evade_healed = false
	lives = player.stats.shield_cells
	hitstop = 0.0
	slowmo = 0.0
	_raise_platform(true)
	player.reset(spawn, spawn_on_platform)
	hud.clear_banner()
	cam.position = player.position + Vector2(0, -80)
	cam.reset_smoothing()


## 찍은 노드와 장착 코어를 플레이어 수치에 반영 (기본 수치 → 노드 → 코어)
func _apply_loadout() -> void:
	player.stats = Upgrades.build(Player.BASE_STATS, profile.nodes, profile.equipped)


## 스테이지 시작: 콜로서스가 다르면 바꿔 끼우고, 개조를 반영해 처음부터
func start_stage(i: int) -> void:
	stage_idx = i
	var path: String = Stages.LIST[i]["script"]
	if boss.get_script().resource_path != path:
		var at: int = boss.get_index()
		remove_child(boss)
		boss.free()
		boss = load(path).new()
		add_child(boss)
		move_child(boss, at)
		player.boss = boss
	_apply_loadout()
	reset_run()
	hud.queue_redraw()                       # FTL 섬광 중(일시정지)에도 배너·실드 셀 표시를 새로


## 정비 화면 (승리 후, 또는 ESC 메뉴에서 — 이 경우 도약하면 지금 스테이지를 처음부터)
func open_hangar() -> void:
	if ftl.is_playing():
		return
	hud.clear_banner()
	hud.queue_redraw()
	hangar.open()


func _on_jump() -> void:
	var st: Dictionary = Stages.LIST[profile.stage]
	sfx.play("dash", 6.0, 0.0)
	sfx.play("perfect", 0.0, 0.0)
	ftl.play("%s — 콜로서스 「%s」" % [st["coord"], st["name"]], func() -> void: start_stage(profile.stage))


func _on_arrived() -> void:
	if touch_ui == null:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED


## 발판을 띄운다 (instant: 바로 / 아니면 용암에서 솟아오르는 연출)
func _raise_platform(instant: bool) -> void:
	plat_on = true
	plat_dir = -1.0
	plat_sink = 0.0 if instant else 1.0


## 조준 입력: 마우스(플레이어 기준 오프셋) 또는 터치 스틱. 길이가 AIM_DEADZONE 이하면 이전 방향을 유지한다
func aim_offset(from: Vector2) -> Vector2:
	if touch_ui != null:
		return touch_ui.stick * 160.0
	return player.get_global_mouse_position() - from


func touch_dash(pressed: bool) -> void:
	if state == State.PLAY:
		_dash_input(pressed)


func touch_parry(pressed: bool) -> void:
	if state == State.PLAY:
		_parry_input(pressed)


func touch_pause() -> void:
	if not get_tree().paused:
		menu.open()


func _buzz(ms: int) -> void:
	if touch_ui != null:
		Input.vibrate_handheld(ms)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if touch_ui != null and e.device == InputEvent.DEVICE_ID_EMULATION:
			return                            # 터치가 만든 가짜 마우스 클릭은 무시 (터치 UI가 따로 처리)
		if state == State.WON:
			if e.button_index == MOUSE_BUTTON_LEFT and e.pressed and win_t > 1.0:
				open_hangar()                  # 승리 후 클릭: 정비 → FTL 도약
			return
		if state != State.PLAY:
			return
		if e.button_index == MOUSE_BUTTON_LEFT:
			_dash_input(e.pressed)             # 발판 위면 발사. 짧게 떼면 돌진, 꾹 눌러 모으면 차지 돌진
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_parry_input(e.pressed)
	elif e is InputEventKey and not e.echo:
		if e.keycode == KEY_SPACE and state == State.PLAY:
			_parry_input(e.pressed)
		elif e.keycode == KEY_R and e.pressed:
			reset_run()
		elif (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER) and e.pressed and state == State.WON and win_t > 1.0:
			open_hangar()


## 돌진 버튼: 패리 후 방향 지정 중에 누르면 즉시 패리 돌진
func _dash_input(pressed: bool) -> void:
	if pressed:
		if player.aim_phase:
			player.launch_parry_dash()
		else:
			player.press_dash()
	else:
		player.release_dash()


## 패리는 누르고 있는 동안 판정 유지. 성공 후 방향 지정 중에는 버튼을 떼면 돌진.
func _parry_input(pressed: bool) -> void:
	if pressed:
		player.parry_press()
	else:
		player.parry_release()
		if player.aim_phase:
			player.launch_parry_dash()


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_physics_body(delta)
	debug.record_physics(Time.get_ticks_usec() - t0)


func _physics_body(delta: float) -> void:
	hud.step(delta)
	_update_camera(delta)
	if hitstop > 0.0:
		hitstop -= delta
		return
	if player.aim_phase:
		player.aim_left -= delta          # 방향 지정 시간은 실시간
		if player.aim_left <= 0.0:
			player.launch_parry_dash()
	# 슬로우는 월드에만: 방향 지정 중, 그리고 패리 돌진이 적중하거나 끝날 때까지
	var dt := delta * world_scale()
	if not player.aim_phase and slowmo > 0.0:
		slowmo -= delta
	if state == State.PLAY:
		run_time += dt
	elif state == State.WON:
		win_t += delta
	_update_platform(dt)
	boss.strike_glow = player.is_attacking()
	boss.focus_glow = 1.0 if (player.aim_phase or player.is_charged()) else 0.0
	boss.focus_from = player.position
	boss.focus_reach = (Player.PARRY_DASH_SPEED_PERFECT if player.aim_perfect else Player.PARRY_DASH_SPEED) * Player.PARRY_DASH_TIME \
		if player.aim_phase else Player.CHARGE_SPEED * Player.CHARGE_DASH_TIME
	boss.hold_attacks = player.on_platform or debug.freeze   # 시작·부활 직후 날아오르기 전에는 공격이 시작되지 않는다 (F3: 디버그 정지)
	boss.step(dt, player.position)
	_tutorial_triggers()
	_drain_boss_events()
	player.step(delta)
	_reflect()
	if state == State.PLAY:
		_check_attacks()
	elif state == State.RESPAWN:
		respawn_t -= delta
		if respawn_t <= 0.0:
			_respawn()
	elif state == State.DEAD:
		dead_t -= delta
		if dead_t <= 0.0:
			reset_run()
	fx.step(dt)


## 새 메커니즘이 처음 나오면 튜토리얼을 띄운다 (팔 휘두르기 준비 → 차지, 눈 레이저 준비 → 패리 불가)
func _tutorial_triggers() -> void:
	if not tutorial.enabled:
		return
	var kd: String = boss.attack_kind()
	if kd == "swing":
		tutorial.request(["charge"])
	elif kd == "beam":
		tutorial.request(["unparry"])
	elif kd == "spiral" or kd == "fan" or kd == "homing" or kd == "mines":
		tutorial.request(["barrage"])


func _tele_extra() -> Dictionary:
	return {"stage": Stages.LIST[stage_idx]["id"], "nodes": Array(profile.nodes), "core": profile.equipped,
		"phase": boss.phase, "part_hp": boss.part_hp.duplicate(), "armor_hp": boss.core.armor_hp}


func _exit_tree() -> void:
	if tele != null:
		tele.finish("quit", run_time, lives, _tele_extra())


## 지금 월드 시간 배율 (조준 슬로우 0.08 / 연출 슬로우 0.3 / 리버스 드라이브 0.5 / 평소 1).
## 플레이어는 실시간으로 움직이지만, 동조 버프처럼 "월드 시간"을 따르는 값은 이 배율로 줄어든다
func world_scale() -> float:
	if player.aim_phase:
		return AIM_SLOW
	if slowmo > 0.0:
		return 0.3
	if player.dash_kind == "power":
		return DASH_SLOW
	return 1.0


func _update_platform(dt: float) -> void:
	if plat_dir > 0.0:
		plat_sink = minf(1.0, plat_sink + dt / PLAT_SINK_TIME)
	elif plat_dir < 0.0:
		plat_sink = maxf(0.0, plat_sink - dt / PLAT_RISE_TIME)
	lava.plat_center = Player.PLAT_CENTER
	lava.plat_half = Player.PLAT_HALF
	lava.plat_sink = plat_sink
	lava.plat_crack = clampf(plat_sink * 3.0, 0.0, 1.0) if plat_dir > 0.0 else 0.0


## 모바일 줌 보정: 폰은 화면비가 가로로 넓어 시야가 PC보다 넓게 잡히므로, 총 시야 면적이 PC의 MOBILE_AREA 배가 되도록 맞춘다
func _mobile_view_k() -> float:
	if touch_ui == null:
		return 1.0
	var vp := get_viewport_rect().size
	return sqrt(vp.x * vp.y / (1280.0 * 720.0 * MOBILE_AREA))


func _update_camera(delta: float) -> void:
	var v: Vector2 = player.vel
	var target: Vector2 = player.position + Vector2(v.x * 0.05, -80.0 + clampf(v.y * 0.1, -100.0, 100.0))
	var mode := 1.0
	if player.aim_phase:                          # 줌아웃 + 조준 방향 보여주기는 조준·차지 중에만
		target += player.aim * 160.0
		mode = AIM_ZOOM
	else:
		var cv: float = player.charge_view()      # 차지는 절반 넘게 모였을 때부터 서서히 (짧게 누르는 돌진에선 카메라가 출렁이지 않게)
		target += player.aim * 160.0 * cv
		mode = lerpf(1.0, CHARGE_ZOOM, cv)
	cam.position = cam.position.lerp(target, 1.0 - exp(-6.0 * delta))
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	shake = move_toward(shake, 0.0, 60.0 * delta)
	var z := CAM_ZOOM * mode * _mobile_view_k()
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 1.0 - exp(-8.0 * delta))
	bg.cam = cam.get_screen_center_position()


func _check_attacks() -> void:
	var p: Vector2 = player.position
	var graze: float = Player.RADIUS + Player.PERFECT_EVADE_GRAZE
	if player.can_evade_reward() and boss.beam_hit(p, graze) != Vector2.ZERO:
		player.try_evade_reward(true)                   # 패리 불가 레이저를 돌진 직후 스침 = 강한 퍼펙트 회피 (4배)
	var beam_push: Vector2 = boss.beam_hit(p, Player.RADIUS)   # 패리 불가: 돌진 무적으로만 피한다
	if beam_push != Vector2.ZERO and not player.is_immune():
		hurt_player(beam_push, "beam")
		return
	var reach: float = player.parry_reach()
	for hb in boss.hitboxes(p):
		if player.can_evade_reward() and boss.overlaps(hb, p, graze):
			player.try_evade_reward()                   # 돌진 직후 공격이 스침 = 퍼펙트 회피
		if not boss.overlaps(hb, p, reach):
			continue
		if player.parry_active:
			if hb.get("small", false):              # 잔탄: 패리하면 흡수되어 사라지기만 한다 (조준 없음, 패리 판정은 그대로)
				boss.on_parried(hb)
				_absorb_feedback(hb["pos"])
				return
			var perfect: bool = player.parry_t <= Player.PERFECT_WINDOW
			if hb["id"] == "arm":                       # 팔은 그냥 패리하면 피해 없이 튕겨나기만 (받아치기는 차지 돌진)
				var hp_pos: Vector2 = hb["pos"]
				var away: Vector2 = p - hp_pos
				if away.length() < 0.1:
					away = -Vector2(hb["push"])
				player.on_parry_push(away)
				_parry_push_feedback(p.lerp(hp_pos, 0.3))
				return
			player.on_parry_success(perfect)
			boss.on_parried(hb)
			_parry_feedback(p, perfect, hb)
			return
		if not player.is_immune() and boss.overlaps(hb, p, Player.RADIUS):
			var cause: String = hb["id"]
			if cause == "bolt" and hb["lava"]:
				cause = "lava_glob"
			hurt_player(hb["push"], cause)
			boss.on_hit_player(hb)
			return


## 받아치기 / 사전 저지: 차지 돌진이 팔에 부딪힘 (player.gd 가 이동 중에 호출). 팔이 위치를 잡고 멈춰 있을 때(set·warn)도,
## 휘두르는 중에도 가능. 그 팔 관절에 즉시 피해 + 공격이 끊기고 팔이 밀려나 멈춘다
func try_clash(p: Vector2) -> bool:
	var hb: Dictionary = boss.clash_box(p)
	if not hb.is_empty() and boss.overlaps(hb, p, Player.RADIUS):
		_clash(hb, p)
		return true
	return false


## 퍼펙트 패리 급 임팩트 (적에게 가하는 일격에 쓴다)
func _perfect_impact(at: Vector2, dir: Vector2) -> void:
	_buzz(80)
	hitstop = maxf(hitstop, 0.2)
	shake = maxf(shake, 24.0)
	hud.flash(0.28, Color(1.0, 0.95, 0.85))
	fx.burst(at, 60, Color(1.0, 0.9, 0.6), 1500.0, 0.6, 4.5)
	fx.burst(at, 28, Color(1, 1, 1), 900.0, 0.4, 3.5)
	fx.rays_burst(at, 18, Color(1.0, 0.95, 0.8), 520.0, 0.45, 7.0)
	fx.rays_burst(at, 9, Color(1.0, 0.6, 0.3), 340.0, 0.35, 5.0)
	fx.ring(at, Color(1, 0.95, 0.8), 300.0, 0.5, 10.0)
	fx.ring(at, Color(1, 0.6, 0.3), 190.0, 0.4, 7.0)
	fx.ring(at, Color(0.7, 0.9, 1.0), 110.0, 0.3, 5.0)
	fx.sprite(at, 2, 440.0, 0.5)                 # 적이 입는 피해 표시
	fx.sprite(at, 1, 300.0, 0.45, false, Color.WHITE, 0.05)
	sfx.play("perfect", 4.0)
	sfx.play("parry", 0.0)


func _clash(hb: Dictionary, p: Vector2) -> void:
	var contact: Vector2 = hb["pos"]
	var dir: Vector2 = player.vel.normalized()
	var dmg: int = player.clash_damage()
	tele.hit("intercept", dmg)
	boss.on_parried(hb)                          # 휩쓸던 반대쪽으로 밀려나 잠시 멈춘다 (관절 노출)
	player.bounce_off(dir, "charge")
	var at := p.lerp(contact, 0.4)
	boss.damage_part(int(hb["part"]), dmg)
	_buzz(80)
	hitstop = maxf(hitstop, 0.2)
	shake = maxf(shake, 24.0)
	hud.flash(0.22, Color(1.0, 0.85, 0.55))
	sfx.play("perfect", 2.0)
	sfx.play("armor", 4.0)
	fx.burst(at, 50, Color(1.0, 0.8, 0.45), 1400.0, 0.6, 4.5)
	fx.burst(at, 24, Color(1.0, 0.55, 0.25), 900.0, 0.5, 3.5)
	fx.rays_burst(at, 16, Color(1.0, 0.9, 0.6), 500.0, 0.45, 7.0)
	fx.ring(at, Color(1.0, 0.9, 0.6), 300.0, 0.45, 10.0)
	fx.ring(at, Color(1.0, 0.55, 0.25), 180.0, 0.35, 7.0)
	fx.sprite(at, 2, 380.0, 0.45)
	fx.sprite(at, 1, 240.0, 0.4, false, Color.WHITE, 0.05)
	if player.last_hit_strong:                   # 4배 버프가 실린 받아치기: 퍼펙트 패리 급
		_perfect_impact(at, dir)


## 피격 = 목숨 −1 + 스턴. 잠시 조작을 잃고 추락 → 용암 위험
func hurt_player(push: Vector2, cause := "attack", damage := true) -> void:
	if debug.god:
		return
	tele.hurt_by(cause)
	var p: Vector2 = player.position
	player.on_hurt(push)
	hitstop = 0.07
	shake = 12.0
	hud.flash(0.25, Color(0.9, 0.1, 0.1))
	fx.burst(p, 14, Color(0.9, 0.15, 0.15), 500.0)
	sfx.play("hurt")
	if damage:
		lives -= 1
		if lives <= 0:
			player.frozen = true
			fx.burst(p, 40, Color(0.9, 0.2, 0.15), 900.0, 0.8, 5.0)
			_die()


func _parry_feedback(p: Vector2, perfect: bool, hb: Dictionary) -> void:
	tele.add("parry_perfect" if perfect else "parry")
	var hp_pos: Vector2 = hb["pos"]
	var contact := p.lerp(hp_pos, 0.25) if not hb.has("rect") else p
	_buzz(70 if perfect else 40)
	if perfect:
		hitstop = 0.2
		shake = 24.0
		hud.flash(0.28, Color(1.0, 0.95, 0.85))
		fx.burst(contact, 60, Color(1.0, 0.9, 0.6), 1500.0, 0.6, 4.5)
		fx.burst(contact, 28, Color(1, 1, 1), 900.0, 0.4, 3.5)
		fx.rays_burst(contact, 18, Color(1.0, 0.95, 0.8), 520.0, 0.45, 7.0)
		fx.rays_burst(contact, 9, Color(1.0, 0.6, 0.3), 340.0, 0.35, 5.0)
		fx.ring(contact, Color(1, 0.95, 0.8), 300.0, 0.5, 10.0)
		fx.ring(contact, Color(1, 0.6, 0.3), 190.0, 0.4, 7.0)
		fx.ring(contact, Color(0.7, 0.9, 1.0), 110.0, 0.3, 5.0)
		sfx.play("perfect", 4.0)
		sfx.play("parry", 0.0)
	else:
		hitstop = 0.12
		shake = 14.0
		hud.flash(0.15)
		fx.burst(contact, 34, Color(0.85, 0.92, 1.0), 1100.0, 0.5, 3.5)
		fx.rays_burst(contact, 12, Color(0.85, 0.92, 1.0), 380.0, 0.4, 6.0)
		fx.ring(contact, Color(0.85, 0.92, 1.0), 200.0, 0.4, 8.0)
		fx.ring(contact, Color(0.6, 0.75, 1.0), 120.0, 0.3, 5.0)
		sfx.play("parry", 2.0)


## 잔탄 흡수: 아주 작은 연출 (탄막 속에서 연달아 일어난다)
func _absorb_feedback(at: Vector2) -> void:
	tele.add("parry_absorb")
	sfx.play("parry", -12.0)
	fx.burst(at, 5, Color(1.0, 0.92, 0.6), 260.0, 0.18, 2.0)


## 반사 코어: 리버스 드라이브 중 기체 둘레의 탄을 표적으로 되돌린다
func _reflect() -> void:
	if state != State.PLAY or not player.is_reflecting():
		return
	var n: int = boss.shots.reflect_near(player.position, Player.REFLECT_RADIUS, boss.target_pos(player.position))
	if n > 0:
		tele.add("reflect", n)
		sfx.play("parry", -6.0)
		fx.ring(player.position, Color(0.75, 1.0, 1.0), 110.0, 0.2, 4.0)


## 팔을 그냥 패리: 피해는 막았지만 보상은 없다 → 짧고 가벼운 연출
func _parry_push_feedback(at: Vector2) -> void:
	tele.add("parry_push")
	_buzz(30)
	hitstop = maxf(hitstop, 0.06)
	shake = maxf(shake, 8.0)
	sfx.play("parry", -4.0)
	fx.burst(at, 14, Color(0.85, 0.92, 1.0), 600.0, 0.3, 2.5)
	fx.ring(at, Color(0.85, 0.92, 1.0), 110.0, 0.25, 4.0)


func _drain_boss_events() -> void:
	var evs: Array[Dictionary] = boss.events.duplicate()
	boss.events.clear()                      # 처리 중 새로 생긴 이벤트(반사 피해 → 부위 파괴 등)는 다음 프레임에
	for ev in evs:
		var pos: Vector2 = ev["pos"]
		match ev["type"]:
			Ev.STOMP:                            # 발 구르기 → 용암이 튄다
				shake = maxf(shake, 14.0)
				sfx.play("stomp", 2.0)
				fx.burst(pos, 30, Color(1.0, 0.45, 0.15, 0.9), 700.0, 0.7, 5.0, 1200.0, Vector2.UP, PI * 0.4)
				fx.ring(pos, Color(1.0, 0.5, 0.2, 0.6), 360.0, 0.35, 6.0)
			Ev.BEAM:                             # 패리 불가 레이저 발사
				shake = maxf(shake, 16.0)
				sfx.play("dash", 6.0, 0.0)
				sfx.play("break", -4.0, 0.0)
				hud.flash(0.12, Color(0.6, 0.1, 0.4))
			Ev.ERUPT:
				sfx.play("bolt", -6.0)
				shake = maxf(shake, 5.0)
			Ev.SWING:
				shake = maxf(shake, 10.0)
				sfx.play("dash", 4.0, 0.0)
				sfx.play("stomp", -4.0)
				fx.ring(pos, Color(0.9, 0.5, 0.4, 0.7), 260.0, 0.3, 6.0)
			Ev.BOLT:
				sfx.play("bolt", -4.0)
			Ev.BOLT_POP:
				fx.burst(pos, 8, Color(1.0, 0.78, 0.42), 300.0, 0.3)
			Ev.PART_BREAK:                       # 부위 파괴: 크게 터지고 떨어져 나간다
				tele.mark("part_break", run_time)
				hitstop = 0.16
				shake = 22.0
				sfx.play("break", 4.0)
				sfx.play("stomp", -2.0)
				fx.burst(pos, 50, Color(1.0, 0.6, 0.3), 1200.0, 0.8, 5.0, 900.0)
				fx.burst(pos, 24, Color(0.6, 0.62, 0.68), 700.0, 1.0, 6.0, 1400.0)
				fx.rays_burst(pos, 12, Color(1.0, 0.8, 0.5), 380.0, 0.4, 6.0)
				fx.ring(pos, Color(1.0, 0.8, 0.55), 240.0, 0.4, 8.0)
				fx.sprite(pos, 1, 420.0, 0.55)
				fx.sprite(pos, 2, 300.0, 0.5, false, Color.WHITE, 0.08)
				hud.flash(0.12, Color(1.0, 0.8, 0.6))
			Ev.PART_STAGE:                       # 부위 손상 단계 상승: 불꽃·파편이 튄다
				shake = maxf(shake, 10.0)
				sfx.play("break", -4.0)
				fx.burst(pos, 22, Color(1.0, 0.7, 0.35), 800.0, 0.5, 3.0)
				fx.burst(pos, 10, Color(0.55, 0.58, 0.64), 500.0, 0.8, 5.0, 1200.0)
			Ev.CORE_STAGE:                       # 코어 껍질이 한 단계 더 부서진다
				hitstop = maxf(hitstop, 0.12)
				shake = maxf(shake, 18.0)
				sfx.play("break", 2.0)
				sfx.play("stomp", -6.0)
				fx.burst(pos, 28, Color(0.6, 0.64, 0.72), 800.0, 0.9, 5.0, 1300.0)
				fx.burst(pos, 14, Color(1.0, 0.6, 0.3), 800.0, 0.45, 3.0)
				fx.ring(pos, Color(1.0, 0.65, 0.35), 200.0, 0.4, 6.0)
				hud.flash(0.1, Color(1.0, 0.75, 0.5))
			Ev.ARMOR_BREAK:                      # 껍질이 완전히 부서짐: 코어가 드러난다 (한 발 더 필요)
				tele.mark("armor_break", run_time)
				hitstop = maxf(hitstop, 0.25)
				shake = maxf(shake, 30.0)
				sfx.play("break", 6.0)
				sfx.play("stomp", 2.0)
				sfx.play("perfect", -2.0, 0.0)
				hud.flash(0.3, Color(1.0, 0.7, 0.5))
				fx.burst(pos, 70, Color(0.65, 0.68, 0.76), 1200.0, 1.0, 6.0, 1400.0)
				fx.burst(pos, 40, Color(1.0, 0.6, 0.3), 1300.0, 0.7, 4.0)
				fx.rays_burst(pos, 20, Color(1.0, 0.7, 0.4), 700.0, 0.6, 8.0)
				fx.ring(pos, Color(1.0, 0.75, 0.45), 520.0, 0.6, 10.0)
				fx.sprite(pos, 1, 520.0, 0.6)
				fx.sprite(pos, 2, 380.0, 0.55, false, Color.WHITE, 0.1)
			Ev.DEBRIS_LAND:
				shake = maxf(shake, 10.0)
				sfx.play("land", 2.0)
				fx.burst(pos, 20, Color(0.55, 0.57, 0.6, 0.8), 500.0, 0.6, 5.0, 900.0, Vector2.UP, PI * 0.45)
			Ev.CORE_OPEN:                        # 모든 부위 파괴 → 가슴이 열린다
				tele.mark("core_open", run_time)
				hitstop = 0.25
				shake = 26.0
				sfx.play("stomp", 4.0)
				sfx.play("win", -6.0, 0.0)
				fx.rays_burst(pos, 20, Color(1.0, 0.55, 0.3), 700.0, 0.8, 8.0)
				fx.ring(pos, Color(1.0, 0.6, 0.35), 500.0, 0.7, 10.0)
				hud.flash(0.2, Color(1.0, 0.6, 0.4))
			Ev.REFLECT_HIT:                     # 반사된 탄이 표적에 닿음
				if state != State.PLAY:
					continue
				var dmg: int = ev["dmg"]
				tele.hit("reflect", dmg)
				shake = maxf(shake, 6.0 + dmg * 2.0)
				sfx.play("armor", -4.0)
				fx.burst(pos, 10 + dmg * 4, Color(0.75, 1.0, 1.0), 600.0, 0.3, 2.5)
				fx.sprite(pos, 1, 90.0 + dmg * 40.0, 0.3)
				if boss.damage(ev["hit"], dmg):
					_core_destroyed(pos)
			Ev.MINE:                            # 기뢰 폭발
				shake = maxf(shake, 8.0)
				sfx.play("stomp", -4.0)
				fx.burst(pos, 22, Color(1.0, 0.55, 0.25, 0.9), 700.0, 0.5, 4.0, 900.0, Vector2.UP, PI * 0.45)
				fx.ring(pos, Color(1.0, 0.5, 0.25, 0.7), 140.0, 0.3, 5.0)
			Ev.CORE_READY:
				shake = maxf(shake, 12.0)
				sfx.play("perfect", 0.0, 0.0)
				fx.ring(pos, Color(1.0, 0.45, 0.25), 320.0, 0.5, 8.0)


# ── player.gd 에서 호출 ───────────────────────────────
## kind: "dash"(일반 돌진, 청백·가볍게) / "charge"(차지 돌진, 주황·묵직하게)
func on_dash(pos: Vector2, dir: Vector2, kind := "dash") -> void:
	if kind == "charge":
		sfx.play("dash", 2.0)
		shake = maxf(shake, 8.0)
		fx.burst(pos, 22, Color(1.0, 0.6, 0.3, 0.9), 700.0, 0.35, 3.0, 0.0, -dir, 0.5)
		fx.ring(pos, Color(1.0, 0.6, 0.3), 160.0, 0.3, 5.0)
	else:
		sfx.play("dash", -6.0)
		fx.burst(pos, 12, Color(0.6, 0.85, 1.0, 0.6), 420.0, 0.25, 2.0, 0.0, -dir, 0.5)


## 차지 완료
func on_charged(pos: Vector2) -> void:
	sfx.play("bolt", -2.0, 0.0)
	shake = maxf(shake, 4.0)
	fx.ring(pos, Color(1.0, 0.6, 0.3), 90.0, 0.25, 4.0)


## 스턴에서 회복: 다시 조종할 수 있다는 신호
func on_stun_recover(pos: Vector2) -> void:
	sfx.play("land", -2.0, 0.0)
	fx.ring(pos, Color(0.85, 0.95, 1.0), 70.0, 0.25, 4.0)


## 발판에서 첫 돌진 = 발사. 발판은 금이 가며 가라앉는다
func on_launch(pos: Vector2) -> void:
	plat_on = false
	plat_dir = 1.0
	shake = maxf(shake, 14.0)
	sfx.play("perfect", -4.0, 0.0)
	sfx.play("dash", 4.0, 0.0)
	fx.burst(pos + Vector2(0, 20), 40, Color(1.0, 0.6, 0.3), 900.0, 0.6, 4.0, 900.0, Vector2.DOWN, 0.9)
	fx.ring(pos, Color(0.85, 0.95, 1.0), 200.0, 0.35, 6.0)


## 용암에 빠짐: 목숨 하나를 잃고 시작 발판에서 재출격 (부순 부위는 그대로)
func on_lava(pos: Vector2) -> void:
	if state != State.PLAY:
		return
	if debug.god:                             # 디버그 무적: 빠지지 않고 튀어 오른다
		player.position.y = -60.0
		player.vel.y = -1400.0
		return
	tele.hurt_by("lava_fall")
	player.frozen = true
	player.visible = false
	lives -= 1
	shake = 20.0
	hitstop = 0.1
	sfx.play("stomp", 2.0)
	sfx.play("break", 0.0)
	fx.burst(Vector2(pos.x, -10), 50, Color(1.0, 0.45, 0.15), 900.0, 0.9, 5.0, 1400.0, Vector2.UP, 0.7)
	fx.ring(Vector2(pos.x, -10), Color(1.0, 0.5, 0.2), 160.0, 0.4, 6.0)
	hud.flash(0.3, Color(1.0, 0.3, 0.1))
	if lives <= 0:
		_die()
	else:
		state = State.RESPAWN
		respawn_t = RESPAWN_DELAY


func _respawn() -> void:
	state = State.PLAY
	_raise_platform(false)
	player.reset(SPAWN, true)
	player.invuln = RESPAWN_INVULN
	sfx.play("land", 0.0)


## 퍼펙트 회피: 일반은 과하지 않게(짧은 슬로우, 옅은 틴트, 얇은 링 하나).
## strong(패리 불가 공격을 피함)은 확실히 더 크게 — 긴 슬로우, 금빛·청록 이중 링, 입자
func on_perfect_evade(pos: Vector2, strong := false) -> void:
	tele.add("perfect_evade_strong" if strong else "perfect_evade")
	if player.stats.evade_heal and not evade_healed and lives < player.stats.shield_cells:   # 실드 재충전(U4): 출격당 1회
		evade_healed = true
		lives += 1
		tele.add("evade_heal")
		hud.flash(0.12, Color(0.5, 1.0, 0.88))
		sfx.play("win", -8.0, 0.0)
	var mint := Color(0.5, 1.0, 0.88)
	if not strong:
		slowmo = maxf(slowmo, 0.25)
		_buzz(40)
		hud.warp(0.25)
		sfx.play("bolt", -4.0, 0.0)
		fx.ring(pos, mint, 90.0, 0.3, 2.0, true)
		fx.burst(pos, 6, Color(0.6, 1.0, 0.9), 320.0, 0.3, 2.0, 0.0, Vector2.ZERO, PI)
		return
	slowmo = maxf(slowmo, 0.5)
	_buzz(90)
	hud.warp(0.5)
	shake = maxf(shake, 8.0)
	sfx.play("perfect", 0.0, 0.0)
	sfx.play("bolt", 0.0, 0.0)
	fx.ring(pos, mint, 240.0, 0.45, 5.0, true)
	fx.ring(pos, Color(1.0, 0.92, 0.55), 150.0, 0.4, 4.0, true)
	fx.ring(pos, Color(1.0, 0.95, 0.75), 80.0, 0.5, 3.0)
	fx.burst(pos, 16, Color(1.0, 0.92, 0.6), 600.0, 0.5, 2.5, 0.0, Vector2.ZERO, PI)


## 패리 돌진 종료(적중 또는 빗나감): 패리로 밀려난 팔은 바로 제자리로
func on_power_dash_end() -> void:
	boss.release_stagger()


func on_parry_launch(pos: Vector2, dir: Vector2) -> void:
	sfx.play("dash", 4.0, 0.0)
	shake = maxf(shake, 12.0)
	hud.flash(0.1, Color(0.8, 0.9, 1.0))
	fx.burst(pos, 30, Color(0.8, 0.92, 1.0), 1300.0, 0.4, 3.0, 0.0, -dir, 0.5)
	fx.ring(pos, Color(0.8, 0.92, 1.0), 160.0, 0.3, 6.0)


## 돌진 적중. kind: "dash"(피해 1, 가볍게) / "charge"(3, 주황) / "power"(패리 돌진 12·16, 크게)
func on_strike(hit: Dictionary, dmg: int, pos: Vector2, dir: Vector2, kind := "dash", buffed := false, strong := false) -> void:
	var contact := pos + dir * Player.RADIUS
	tele.hit(kind, dmg)
	if buffed:
		tele.add("sync_strong_hit" if strong else "sync_hit")
	if strong:                                 # 패리 불가 공격을 퍼펙트 회피한 4배 일격: 퍼펙트 패리에 준하는 임팩트
		_perfect_impact(contact, dir)
	elif buffed:                               # 퍼펙트 회피 버프가 실린 차지 일격
		shake = maxf(shake, 20.0)
		sfx.play("perfect", -2.0, 0.0)
		fx.ring(contact, Color(0.75, 0.96, 1.0), 240.0, 0.35, 8.0)
		fx.rays_burst(contact, 10, Color(0.8, 0.97, 1.0), 420.0, 0.35, 6.0)
		fx.burst(contact, 22, Color(0.8, 0.97, 1.0), 1100.0, 0.5, 3.5, 0.0, -dir, 1.0)
	if boss.damage(hit, dmg):                  # 동력 코어가 부서짐 = 승리
		_core_destroyed(contact)
		return
	match kind:
		"power":
			hitstop = maxf(hitstop, 0.18)
			shake = maxf(shake, 26.0)
			sfx.play("break", 4.0)
			sfx.play("perfect", 0.0)
			hud.flash(0.1, Color(1.0, 0.9, 0.7))
			fx.burst(contact, 44, Color(1.0, 0.8, 0.5), 1400.0, 0.9, 5.0, 1200.0, -dir, 1.4)
			fx.rays_burst(contact, 14, Color(1.0, 0.85, 0.6), 420.0, 0.4, 6.0)
			fx.ring(contact, Color(1, 0.9, 0.7), 260.0, 0.4, 9.0)
			fx.sprite(contact, 2, 360.0, 0.45)
			fx.sprite(contact, 1, 240.0, 0.4, false, Color.WHITE, 0.04)
		"charge":
			hitstop = maxf(hitstop, 0.1)
			shake = maxf(shake, 13.0)
			hud.flash(0.08, Color(1.0, 0.8, 0.55))
			sfx.play("armor", 3.0)
			fx.rays_burst(contact, 8, Color(1.0, 0.7, 0.35), 320.0, 0.3, 5.0)
			fx.ring(contact, Color(1.0, 0.65, 0.3), 150.0, 0.3, 7.0)
			fx.burst(contact, 18, Color(1.0, 0.7, 0.35), 900.0, 0.4, 3.0, 0.0, -dir, 1.1)
			fx.sprite(contact, 1, 200.0, 0.35)
		_:                                     # 일반 돌진: 피해가 들어가고 있다는 확실한 피드백 (파편·불꽃·작은 링·플래시)
			hitstop = maxf(hitstop, 0.07)
			shake = maxf(shake, 9.0)
			hud.flash(0.05, Color(0.85, 0.93, 1.0))
			sfx.play("armor", 0.0)
			fx.burst(contact, 14, Color(0.9, 0.95, 1.0), 800.0, 0.35, 3.0, 0.0, -dir, 1.1)
			fx.rays_burst(contact, 6, Color(0.85, 0.93, 1.0), 260.0, 0.25, 4.0)
			fx.ring(contact, Color(0.85, 0.92, 1.0), 100.0, 0.22, 4.0)
			fx.sprite(contact, 1, 110.0, 0.28)


## 코어 파괴 = 승리
func _core_destroyed(pos: Vector2) -> void:
	tele.mark("core", run_time)
	tele.finish("win", run_time, lives, _tele_extra())
	state = State.WON
	player.frozen = true
	player.vel = Vector2.ZERO
	boss.die()
	hitstop = 0.3
	slowmo = 1.5
	shake = 26.0
	hud.flash(0.5, Color(1.0, 0.85, 0.7))
	fx.burst(pos, 60, Color(1.0, 0.5, 0.25), 1400.0, 1.0, 5.0)
	fx.burst(pos, 30, Color(1, 1, 1), 900.0, 0.6, 3.0)
	fx.ring(pos, Color(1, 0.9, 0.7), 500.0, 0.8, 10.0)
	sfx.play("perfect", 4.0, 0.0)
	sfx.play("win", 0.0, 0.0)
	var got: Dictionary = profile.record_clear(stage_idx)
	var reward := ""
	if got["first"]:
		var items := PackedStringArray()
		if got["core"] != "":
			items.append(Upgrades.CORES[got["core"]]["name"])
		items.append("부산물 포인트 +%d" % got["point"])
		reward = " · 획득: " + ", ".join(items)
	hud.banner("코어 에너지 확보", "%.1f초 · 남은 실드 셀 %d%s · 클릭: 정비 → FTL 도약 · R: 다시" % [run_time, lives, reward])


func _die() -> void:
	tele.finish("dead", run_time, lives, _tele_extra())
	state = State.DEAD
	dead_t = 2.5
	hud.banner("기체 손실", "잠시 후 재시작 (R: 즉시)")
