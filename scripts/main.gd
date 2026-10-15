extends Node2D
## 프로토타입 메인: 루프, 입력, 패리/피격 판정, 카메라, 피드백(히트스톱/흔들림/플래시/사운드).
## 메타 구조: 스테이지(콜로서스 하나) 클리어 → 그 동력 코어 획득(영구 강화) → 월드 맵(스테이지 선택) → FTL 도약. 진행은 profile 에 저장된다.

const Loc := preload("res://scripts/loc.gd")
const Player := preload("res://scripts/player.gd")
const Ev := preload("res://scripts/ev.gd")
const Projectiles := preload("res://scripts/projectiles.gd")
const Fx := preload("res://scripts/fx.gd")
const Ground := preload("res://scripts/ground.gd")
const Background := preload("res://scripts/background.gd")
const Hud := preload("res://scripts/hud.gd")
const Sfx := preload("res://scripts/sfx.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const TitleMenu := preload("res://scripts/title_menu.gd")
const Tutorial := preload("res://scripts/tutorial.gd")
const Telemetry := preload("res://scripts/telemetry.gd")
const Debug := preload("res://scripts/debug.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Quality := preload("res://scripts/quality.gd")
const Profile := preload("res://scripts/profile.gd")
const Stages := preload("res://scripts/stages.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const WorldMap := preload("res://scripts/world_map.gd")
const Ftl := preload("res://scripts/ftl.gd")

const SPAWN := Vector2(650, -52)   # 시작 발판 위 (Player.PLAT_CENTER - 반지름)
const CAM_ZOOM := 0.6              # 기본 줌아웃 (넓게 보여서 탄막 사이 빈틈이 보이게)
const MOBILE_AREA := 1.2             # 모바일 시야 면적 = PC 화면의 이 배수 (폰 화면 비율에 맞춰 줌을 계산)
const AIM_ZOOM := 0.85             # 방향 지정 중엔 물러나 표적을 넓게 본다
const CHARGE_ZOOM := 0.85            # 차징 중에만 물러난다
const AIM_SLOW := 0.08             # 방향 지정 중 월드 시간 배율
const DASH_SLOW := 0.5             # 패리 돌진 중 월드 시간 배율 (적중·종료 즉시 원래 속도). 플레이어는 항상 실시간
const RESPAWN_DELAY := 1.3         # 용암에 빠진 뒤 재출격까지
const RESPAWN_INVULN := 1.5
const PLAT_SINK_TIME := 1.0        # 발사 후 발판이 가라앉는 시간
const PLAT_RISE_TIME := 0.6
const HEAT_MAX := 3                # 잔탄에 이만큼 맞으면 실드 셀 1개가 깨진다 (과열 게이지)
const HEAT_COOL := 5.0             # 이 시간 동안 잔탄에 안 맞으면 게이지가 한 칸 식는다
const GRAZE_INVULN := 0.35         # 잔탄에 맞은 직후 무적
const GRAZE_BREAK_INVULN := 0.8    # 게이지가 차서 셀이 깨진 직후 무적

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
var title                             # 메인 화면 (시작 / 이어하기 / 조작법 / 언어)
var tutorial                          # 튜토리얼 팝업
var tele                              # 플레이 기록 (user://telemetry)
var debug                             # 개발용 디버그 (F1~F8)
var profile                           # 진행 저장 (user://profile.cfg)
var world                             # 월드 맵 (항로도: 스테이지 선택·코어)
var ftl                               # FTL 도약 연출
var stage_idx := 0                    # 지금 싸우는 스테이지 (Stages.LIST)

var state := State.PLAY
var hitstop := 0.0
const CHARGED_SLOW := 0.12        # 차지 완료 순간 짧은 슬로우
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
var heat := 0                      # 과열 게이지 (잔탄 피격 횟수)
var heat_t := 0.0                  # 다음에 한 칸 식을 때까지


func _ready() -> void:
	randomize()
	Loc.init()                                    # 저장된 언어 (없으면 OS 언어)
	get_window().title = "Parry Pierce"           # 프로젝트 이름은 그대로 둔다 (저장 폴더 이름이 이 이름을 따르므로 바꾸면 기존 진행이 사라진다)
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
	world = WorldMap.new()
	world.profile = profile
	world.ui_scale = menu.ui_scale
	add_child(world)
	world.jump_requested.connect(_on_jump)
	menu.world_requested.connect(open_world)
	ftl = Ftl.new()
	add_child(ftl)
	ftl.arrived.connect(_on_arrived)
	tutorial = Tutorial.new()
	tutorial.touch = touch_mode
	tutorial.enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--notutorial")
	add_child(tutorial)
	menu.tutorial = tutorial
	title = TitleMenu.new()
	title.profile = profile
	title.tutorial = tutorial
	title.ui_scale = menu.ui_scale
	add_child(title)
	menu.title = title
	menu.title_requested.connect(_open_title)
	title.start_requested.connect(_on_title_start)
	title.continue_requested.connect(_on_title_continue)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	title.visibility_changed.connect(func() -> void: hud.visible = not title.visible)
	world.back_requested.connect(_open_title)
	tele = Telemetry.new()
	tele.enabled = DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--telemetry")   # 플레이어에게는 기록을 남기지 않는다 (개발용 옵션)
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
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() != "headless" and not args.has("--notitle") and not args.has("--notutorial"):
		_open_title()
	else:
		tutorial.request(["dodge", "parry", "dashparry"])        # 처음 실행: 회피 → 패리 → 돌진패리 순서로 한 장씩


func reset_run() -> void:
	if tele != null:
		tele.finish("restart", run_time, lives, _tele_extra())
		tele.begin()
	boss.reset()
	fx.clear()
	state = State.PLAY
	run_time = 0.0
	win_t = 0.0
	heat = 0
	heat_t = 0.0
	lives = player.stats.shield_cells
	hitstop = 0.0
	slowmo = 0.0
	_raise_platform(true)
	player.reset(spawn, spawn_on_platform)
	hud.clear_banner()
	cam.position = player.position + Vector2(0, -80)
	cam.reset_smoothing()


## 얻은 동력 코어를 모두 플레이어 수치에 반영 (영구 강화)
func _apply_loadout() -> void:
	player.stats = Upgrades.build(Player.BASE_STATS, profile.cores)


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


## 월드 맵 (승리 후, ESC 메뉴, 타이틀의 이어하기에서): 스테이지를 골라 도약한다. 깬 스테이지는 다시 싸울 수 있다
func open_world(from_title := false) -> void:
	if ftl.is_playing():
		return
	hud.clear_banner()
	hud.queue_redraw()
	world.allow_back = from_title                # 타이틀에서 왔을 때만 "뒤로"로 돌아간다
	world.open()


## 메인 화면. 진행 중이던 판은 처음 상태(발판 위, 보스 대기)로 돌려 두고 뒤에서 흔들리게 둔다
func _open_title() -> void:
	if ftl.is_playing():
		return
	world.close()
	get_tree().paused = false
	reset_run()
	title.open()


func _on_title_start() -> void:
	profile.reset()
	profile.save()
	_on_jump()


func _on_title_continue() -> void:
	open_world(true)


func _on_jump() -> void:
	title.close()
	var st: Dictionary = Stages.LIST[profile.stage]
	sfx.play("dash", 6.0, 0.0)
	sfx.play("perfect", 0.0, 0.0)
	ftl.play(Loc.t("%s — 콜로서스 「%s」") % [Loc.t(st["coord"]), Loc.t(st["name"])], func() -> void: start_stage(profile.stage))


func _on_arrived() -> void:
	if touch_ui == null:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	tutorial.request(["dodge", "parry", "dashparry"])      # 처음 도착: 회피 → 패리 → 돌진패리 순서로 한 장씩 (본 장은 다시 안 뜬다)


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
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_F11 or (e.keycode == KEY_ENTER and e.alt_pressed)):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if title != null and title.visible:
		return                                    # 메인 화면이 열려 있는 동안은 게임 입력을 받지 않는다
	if e is InputEventMouseButton:
		if touch_ui != null and e.device == InputEvent.DEVICE_ID_EMULATION:
			return                            # 터치가 만든 가짜 마우스 클릭은 무시 (터치 UI가 따로 처리)
		if state == State.WON:
			if e.button_index == MOUSE_BUTTON_LEFT and e.pressed and win_t > 1.0:
				open_world()                  # 승리 후 클릭: 월드 맵 → FTL 도약
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
			open_world()


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
	boss.focus_reach = player.parry_dash_reach() \
		if player.aim_phase else Player.CHARGE_SPEED * Player.CHARGE_DASH_TIME
	boss.hold_attacks = player.on_platform or debug.freeze   # 시작·부활 직후 날아오르기 전에는 공격이 시작되지 않는다 (F3: 디버그 정지)
	boss.step(dt, player.position)
	_tutorial_triggers()
	_drain_boss_events()
	player.step(delta)
	_heat_cool(dt)
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
	elif kd == "hammer" or kd == "clap" or kd == "chase" or kd == "sweep" or kd == "constrict" or kd == "vortex" or kd == "march" or kd == "flurry":
		tutorial.request(["charge", "tentacle"])
	elif kd == "net":
		tutorial.request(["unparry"])
	elif kd == "beam":
		tutorial.request(["unparry"])
	elif kd == "spiral" or kd == "fan" or kd == "homing" or kd == "mines":
		tutorial.request(["barrage"])
	elif kd == "rings":
		tutorial.request(["unparry"])
	if boss.shots.kind.has(Projectiles.Kind.SMALL):    # 잔탄이 처음 나오면 (관측자도 섞어 쏜다)
		tutorial.request(["barrage"])


func _tele_extra() -> Dictionary:
	return {"stage": Stages.LIST[stage_idx]["id"], "cores": Array(profile.cores),
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
	if beam_push != Vector2.ZERO and player.can_refresh_evade():
		player.refresh_evade_invuln()
	if beam_push != Vector2.ZERO and not player.is_immune():
		hurt_player(beam_push, boss.attack_kind())
		return
	var reach: float = player.parry_reach()
	for hb in boss.hitboxes(p):
		var melee: bool = hb.get("melee", false)        # 근접공격 = 회피 불가 (일반 돌진 무적으로 통과 못 함, 퍼펙트 회피도 없음)
		if hb["id"] == "press":
			if _press(hb):
				return
			continue
		if not melee and player.can_evade_reward() and boss.overlaps(hb, p, graze):
			player.try_evade_reward()                   # 돌진 직후 공격이 스침 = 퍼펙트 회피
		if not melee and player.can_refresh_evade() and boss.overlaps(hb, p, Player.RADIUS):
			player.refresh_evade_invuln()               # 퍼펙트 회피한 돌진 중 다른 탄에 닿을 때마다 추가 무적을 처음 길이로
		if not boss.overlaps(hb, p, reach):
			continue
		if player.parry_active:
			if hb.get("small", false):              # 잔탄: 패리하면 흡수되어 사라지기만 한다 (조준 없음, 패리 판정은 그대로, 쿨다운 없음)
				_parried_bullet(hb)
				player.on_absorb()
				_absorb_feedback(hb["pos"])
				return
			var dash_parry: bool = player.is_dash_parry()          # 돌진패리: 돌진하는 동안의 패리는 타이밍과 상관없이 PERFECT
			var perfect: bool = dash_parry or player.parry_t <= Player.PERFECT_WINDOW
			if hb["id"] == "arm":                       # 팔은 그냥 패리하면 피해 없이 튕겨나기만 (받아치기는 차지 돌진)
				var hp_pos: Vector2 = hb["pos"]
				var away: Vector2 = p - hp_pos
				if away.length() < 0.1:
					away = -Vector2(hb["push"])
				player.on_parry_push(away)
				_parry_push_feedback(p.lerp(hp_pos, 0.3), away)
				return
			var dp_dir: Vector2 = player.vel.normalized() if player.vel.length() > 10.0 else player.aim
			player.on_parry_success(perfect, dash_parry)
			_parried_bullet(hb)
			_parry_feedback(p, perfect, hb)
			if dash_parry:
				_dash_parry_feedback(p, dp_dir)
			return
		var small: bool = hb.get("small", false)
		if small and player.small_guard > 0.0:         # 일반 돌진이 끝난 직후 잠깐: 잔탄은 맞지 않는다
			continue
		var immune: bool = player.is_immune_melee() if melee else player.is_immune()
		if not immune and boss.overlaps(hb, p, Player.RADIUS):
			if small:                                  # 잔탄: 실드 셀이 바로 깨지지 않고 과열 게이지만 오른다 (제어 불능 없음)
				_graze(hb)
				return
			var cause: String = hb["id"]
			if cause == "bolt" and hb["lava"]:
				cause = "lava_glob"
			hurt_player(hb["push"], cause)
			boss.on_hit_player(hb)
			return


## 요격(받아치기 / 사전 저지): 차지 강습이나 리버스 드라이브가 근접공격에 부딪힘 (player.gd 가 이동 중에 호출). 팔이 위치를 잡고 멈춰 있을 때(set·warn)도,
## 휘두르는 중에도 가능. 그 팔 관절에 즉시 피해 + 공격이 끊기고 팔이 밀려나 멈춘다
func try_clash(p: Vector2) -> bool:
	var hb: Dictionary = boss.clash_box(p)
	if not hb.is_empty() and boss.overlaps(hb, p, Player.RADIUS):
		_clash(hb, p)
		return true
	return false


## 리버스 드라이브 성공: 쌓인 잔탄 긁힘(과열) 한 칸을 치료한다. 5초 식는 시계도 다시 시작
func _cure_heat(at: Vector2) -> void:
	if heat <= 0:
		return
	heat -= 1
	heat_t = HEAT_COOL
	tele.add("heat_cure")
	sfx.play("bolt", -2.0, 0.0)
	fx.ring(at, Color(1.0, 0.75, 0.35), 90.0, 0.35, 4.0, true)
	fx.burst(at, 8, Color(1.0, 0.8, 0.45), 380.0, 0.3, 2.5)


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
	var kind: String = player.dash_kind
	var dmg: int = player.intercept_damage() if (hb.has("part") or hb.has("core")) else 0
	player.pass_target = {}                      # 요격은 표적 원과 무관하다
	player.bounce_off(dir, kind)                 # 먼저 튕긴다 (리버스 드라이브가 끝나며 풀어 주는 경직이 이번 요격의 경직을 풀지 않게)
	hb["dir"] = dir                              # 촉수는 부딪힌 방향으로 크게 튕겨 나간다
	boss.on_parried(hb)                          # 팔: 휩쓸던 반대쪽으로 밀려나 잠시 멈춘다 (관절 노출) / 프레스: 걸려서 도로 올라간다
	var at := p.lerp(contact, 0.4)
	if hb.has("part"):                           # 부위에 달린 공격(팔·촉수)이면 그 부위에 피해. 프레스는 끊기만 한다
		tele.hit("intercept_power" if kind == "power" else "intercept", dmg)
		boss.damage_part(int(hb["part"]), dmg)
	elif hb.has("core"):                         # 크라켄 코어 페이즈: 다시 자란 촉수 요격 → 코어에 바로 피해
		tele.hit("intercept_power" if kind == "power" else "intercept", dmg)
		if boss.intercept_core(int(hb["tent"]), dmg):
			_core_destroyed(at)
			return
	else:
		tele.add("intercept_" + str(hb["id"]))
	player.on_intercept()                        # 기본 시스템: 차지 쿨다운 초기화 (연속 요격). 강습 코어는 연쇄 단계도 올린다
	if kind == "power":
		_cure_heat(at)                           # 리버스 드라이브 성공: 긁힘 한 칸 치료
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
	if hb.has("tent"):                           # 촉수 요격: 더 과장되게 (부딪힌 방향으로 쏟아지는 강철 불꽃 + 큰 흔들림)
		shake = maxf(shake, 32.0)
		hitstop = maxf(hitstop, 0.24)
		fx.burst(at, 40, Color(0.8, 0.84, 0.9), 1900.0, 0.55, 4.0, 900.0, dir, 0.55)
		fx.burst(at, 26, Color(1.0, 0.75, 0.35), 1500.0, 0.45, 3.5, 0.0, dir, 0.8)
		fx.rays_burst(at, 10, Color(1.0, 0.9, 0.6), 700.0, 0.35, 9.0)
		sfx.play("stomp", 2.0)
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
		heat = 0                                   # 셀이 다른 이유로 깨지면 쌓인 과열은 다음 셀로 넘어가지 않는다
		if lives <= 0:
			player.frozen = true
			fx.burst(p, 40, Color(0.9, 0.2, 0.15), 900.0, 0.8, 5.0)
			_die()


## 돌진패리 전용 이펙트: 청록 충격파 + 진행 방향으로 쏟아지는 불꽃. 이어지는 리버스 드라이브는 사거리가 늘고 청록 꼬리를 단다
func _dash_parry_feedback(p: Vector2, dir: Vector2) -> void:
	tele.add("dash_parry")
	var mint := Color(0.5, 1.0, 0.88)
	hud.flash(0.18, Color(0.6, 1.0, 0.9))
	hud.warp(0.4)
	shake = maxf(shake, 20.0)
	sfx.play("perfect", 2.0)
	sfx.play("dash", 0.0, 0.0)
	fx.ring(p, mint, 240.0, 0.4, 7.0, true)
	fx.ring(p, Color(1, 1, 1), 130.0, 0.25, 4.0)
	fx.burst(p, 36, mint, 1700.0, 0.45, 3.5, 0.0, dir, 0.35)
	fx.rays_burst(p, 10, Color(0.8, 1.0, 0.95), 600.0, 0.4, 6.0)


## 잔탄 피격: 실드 셀이 바로 깨지지 않고 과열 게이지가 한 칸 오른다. 제어 불능도, 동조·차지 취소도 없다.
## 게이지가 가득 차면(HEAT_MAX) 셀 1개가 깨지고 비워진다. HEAT_COOL 초 동안 안 맞으면 한 칸 식는다
func _graze(hb: Dictionary) -> void:
	boss.on_hit_player(hb)
	if debug.god:
		return
	tele.hurt_by("small")
	var p: Vector2 = player.position
	heat += 1
	heat_t = HEAT_COOL
	if heat < HEAT_MAX:
		player.invuln = maxf(player.invuln, GRAZE_INVULN)
		shake = maxf(shake, 5.0)
		sfx.play("hurt", -10.0)
		hud.flash(0.08, Color(1.0, 0.55, 0.15))
		fx.burst(p, 8, Color(1.0, 0.6, 0.2), 420.0, 0.25, 2.5)
		return
	heat = 0
	lives -= 1
	player.on_heat_break()
	player.invuln = maxf(player.invuln, GRAZE_BREAK_INVULN)
	hitstop = maxf(hitstop, 0.06)
	shake = maxf(shake, 12.0)
	sfx.play("hurt")
	hud.flash(0.22, Color(0.9, 0.15, 0.1))
	fx.burst(p, 18, Color(1.0, 0.45, 0.15), 600.0)
	if lives <= 0:
		player.frozen = true
		fx.burst(p, 40, Color(0.9, 0.2, 0.15), 900.0, 0.8, 5.0)
		_die()


## 과열 정도 0~1 (HUD 실드 셀의 금·기체의 달아오름). 한 번 맞으면 0.5, 두 번이면 1.0 이고 식어 가면서 연속으로 줄어든다
func heat_level() -> float:
	if heat <= 0:
		return 0.0
	var f := float(heat - 1) + clampf(heat_t / HEAT_COOL, 0.0, 1.0)
	return clampf(f / float(HEAT_MAX - 1), 0.0, 1.0)


func _heat_cool(dt: float) -> void:
	if heat <= 0 or state != State.PLAY:
		return
	heat_t -= dt
	if heat_t <= 0.0:
		heat -= 1
		heat_t = HEAT_COOL


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


## 프레스(천장 근접공격): 판 아래로 밀어낸다. 패리하면 막기는 하지만 아래로 내리꽂힌다(융해 지대로).
## 회피 불가라 일반 돌진 중이어도 내려오는 판에 닿으면 피해. 다 내려온 뒤(멈춤·올라감)는 판에 막히기만 하고 피해가 없다. 처리했으면 true
func _press(hb: Dictionary) -> bool:
	var p: Vector2 = player.position
	var bottom: float = Rect2(hb["rect"]).end.y
	if hb.get("harmless", false):
		if p.y - Player.RADIUS >= bottom:
			return false
		player.position.y = bottom + Player.RADIUS + 1.0
		player.vel.y = maxf(player.vel.y, 0.0)
		return false
	if player.parry_active and p.y - player.parry_reach() < bottom:
		tele.add("parry_press")
		player.on_press_pin()
		_parry_push_feedback(Vector2(p.x, bottom), Vector2.DOWN)
		shake = maxf(shake, 18.0)
		return true
	if p.y - Player.RADIUS >= bottom:
		return false
	player.position.y = bottom + Player.RADIUS + 1.0          # 판 아래로 밀어낸다 (판보다 위에 있을 수 없다)
	if not player.is_immune_melee():
		hurt_player(Vector2.DOWN, "press")
		player.vel.y = 0.0                                      # 맞은 충격으로 융해 지대까지 날아가지는 않게
	else:
		player.vel.y = maxf(player.vel.y, 0.0)
	return true


## 패리한 탄: 보통은 사라진다. 반격 코어가 있으면 사라지지 않고 플레이어 탄이 되어 표적으로 빠르게 되돌아간다
func _parried_bullet(hb: Dictionary) -> void:
	if not player.stats.counter or hb["id"] != "bolt":
		boss.on_parried(hb)
		return
	boss.shots.reflect_one(int(hb["idx"]), boss.target_pos(player.position))
	tele.add("counter")
	fx.ring(hb["pos"], Color(0.75, 1.0, 1.0), 60.0, 0.15, 3.0)


## 잔탄 흡수: 아주 작은 연출 (탄막 속에서 연달아 일어난다)
func _absorb_feedback(at: Vector2) -> void:
	tele.add("parry_absorb")
	sfx.play("parry", -12.0)
	fx.burst(at, 5, Color(1.0, 0.7, 0.3), 260.0, 0.18, 2.0)


## 반사 코어: 리버스 드라이브로 돌진하는 동안만 기체 둘레의 탄을 표적으로 되돌린다
func _reflect() -> void:
	if state != State.PLAY or not player.is_reflecting():
		return
	var n: int = boss.shots.reflect_near(player.position, Player.REFLECT_RADIUS, boss.target_pos(player.position))
	if n > 0:
		tele.add("reflect", n)
		sfx.play("parry", -6.0)
		fx.ring(player.position, Color(0.75, 1.0, 1.0), 110.0, 0.2, 4.0)


## 근접공격(팔·촉수·프레스)을 그냥 패리: 막아 내 튕겨났지만 피해는 주지 못했다 → 글자 없이 "튕겨냄"으로 읽히게.
## 둔탁한 금속음(맑게 울리는 패리음 대신) + 표면을 따라 미끄러지는 회색 강철 불꽃 + 플레이어 쪽 방패 호 + 안으로 오그라드는 회색 링.
## 피해 표시(주황 폭발 스프라이트·적의 번쩍임)는 없다. away = 접점에서 플레이어 쪽
func _parry_push_feedback(at: Vector2, away := Vector2.UP) -> void:
	tele.add("parry_push")
	_buzz(30)
	hitstop = maxf(hitstop, 0.06)
	shake = maxf(shake, 8.0)
	sfx.play("deflect", 2.0)
	sfx.play("parry", -14.0)
	var d := away.normalized() if away.length() > 0.1 else Vector2.UP
	var steel := Color(0.7, 0.75, 0.82)
	fx.arc(at, Color(0.85, 0.95, 1.0), 64.0, d.angle(), 2.0, 0.32, 7.0)
	fx.burst(at, 12, steel, 760.0, 0.3, 2.5, 700.0, d.orthogonal(), 0.3)
	fx.burst(at, 12, steel, 760.0, 0.3, 2.5, 700.0, -d.orthogonal(), 0.3)
	fx.ring(at, Color(0.55, 0.6, 0.68, 0.9), 90.0, 0.3, 3.0, true)


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
			Ev.PRESS:                           # 프레스가 정지선에 닿음
				shake = maxf(shake, 26.0)
				sfx.play("stomp", 6.0)
				sfx.play("break", 0.0)
				fx.burst(Vector2(player.position.x, pos.y), 30, Color(0.7, 0.68, 0.64), 900.0, 0.6, 5.0, 1200.0, Vector2.DOWN, PI * 0.4)
			Ev.RING:                            # 동심원 파동 하나가 퍼지기 시작
				shake = maxf(shake, 8.0)
				sfx.play("dash", 2.0, 0.0)
				hud.flash(0.06, Color(0.6, 0.1, 0.4))
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
## 차지 완료: 짧은 슬로우 + 링 (조준 슬로우 중에는 조준이 우선)
func on_charged(pos: Vector2) -> void:
	sfx.play("bolt", -2.0, 0.0)
	shake = maxf(shake, 4.0)
	slowmo = maxf(slowmo, CHARGED_SLOW)
	hud.warp(0.12)
	fx.ring(pos, Color(1.0, 0.6, 0.3), 90.0, 0.25, 4.0)
	fx.ring(pos, Color(1.0, 0.85, 0.55), 50.0, 0.2, 3.0, true)


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
	heat = 0
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
	if hit["kind"] == "shield" and kind != "power":   # 크라켄 방어막: 돌진·차지 강습은 피해 없이 튕겨 나온다 (리버스 드라이브만 뚫는다)
		tele.add("shield_block")
		boss.shield_flash = 1.0
		boss.shield_hit_n = hit["n"]
		_parry_push_feedback(contact, -dir)
		return
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
			_cure_heat(contact)
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
	if got["core"] != "":
		reward = Loc.t(" · 획득: %s (영구 강화)") % Loc.t(Upgrades.CORES[got["core"]]["name"])
	hud.banner(Loc.t("코어 에너지 확보"), Loc.t("%.1f초 · 남은 실드 셀 %d%s · 클릭: 월드 맵 → FTL 도약 · R: 다시") % [run_time, lives, reward])


func _die() -> void:
	tele.finish("dead", run_time, lives, _tele_extra())
	state = State.DEAD
	dead_t = 2.5
	hud.banner(Loc.t("기체 손실"), Loc.t("잠시 후 재시작 (R: 즉시)"))
