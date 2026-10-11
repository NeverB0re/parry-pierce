extends Node2D
## 프로토타입 메인: 루프, 입력, 패리/피격 판정, 카메라, 피드백(히트스톱/흔들림/플래시/사운드).

const Player := preload("res://scripts/player.gd")
const Boss := preload("res://scripts/boss.gd")
const Fx := preload("res://scripts/fx.gd")
const Ground := preload("res://scripts/ground.gd")
const Background := preload("res://scripts/background.gd")
const Hud := preload("res://scripts/hud.gd")
const Sfx := preload("res://scripts/sfx.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")

const SPAWN := Vector2(650, -52)   # 시작 발판 위 (Player.PLAT_CENTER - 반지름)
const CAM_ZOOM := 0.72             # 기본 줌아웃 (튕겨 올라가도 표적이 시야에 남도록)
const AIM_ZOOM := 0.82             # 방향 지정 중엔 물러나 표적을 넓게 본다
const CHARGE_ZOOM := 0.85            # 차징 중에만 물러난다
const AIM_SLOW := 0.08             # 방향 지정 중 월드 시간 배율
const DASH_SLOW := 0.5             # 패리 돌진 중 월드 시간 배율 (적중·종료 즉시 원래 속도). 플레이어는 항상 실시간
const LIVES := 5                   # 피격 −1, 용암 −1
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

var state := State.PLAY
var hitstop := 0.0
var slowmo := 0.0
var shake := 0.0
var run_time := 0.0
var lives := LIVES
var dead_t := 0.0
var respawn_t := 0.0
var plat_on := true                # 발판 위에 설 수 있는가
var plat_sink := 0.0               # 0 = 떠 있음, 1 = 가라앉음
var plat_dir := 0.0                # +1 가라앉는 중, -1 떠오르는 중
var lava                           # 바닥(용암·발판) 노드
var spawn := SPAWN
var spawn_on_platform := true


func _ready() -> void:
	randomize()
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

	lava = Ground.new()
	add_child(lava)
	boss = Boss.new()
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
	cam.limit_top = -3150
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
	add_child(sfx)
	var menu := PauseMenu.new()
	add_child(menu)
	menu.restart_requested.connect(reset_run)
	reset_run()


func reset_run() -> void:
	boss.reset()
	fx.clear()
	state = State.PLAY
	run_time = 0.0
	lives = LIVES
	hitstop = 0.0
	slowmo = 0.0
	_raise_platform(true)
	player.reset(spawn, spawn_on_platform)
	hud.clear_banner()
	cam.position = player.position + Vector2(0, -80)
	cam.reset_smoothing()


## 발판을 띄운다 (instant: 바로 / 아니면 용암에서 솟아오르는 연출)
func _raise_platform(instant: bool) -> void:
	plat_on = true
	plat_dir = -1.0
	plat_sink = 0.0 if instant else 1.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if state != State.PLAY:
			return
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if player.aim_phase:
					player.launch_parry_dash()
				else:
					player.press_dash()        # 발판 위면 발사. 짧게 떼면 회피, 꾹 눌러 차지하면 공격
			else:
				player.release_dash()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			_parry_input(e.pressed)
	elif e is InputEventKey and not e.echo:
		if e.keycode == KEY_SPACE and state == State.PLAY:
			_parry_input(e.pressed)
		elif e.keycode == KEY_R and e.pressed:
			reset_run()


## 패리는 누르고 있는 동안 판정 유지. 성공 후 방향 지정 중에는 버튼을 떼면 돌진.
func _parry_input(pressed: bool) -> void:
	if pressed:
		player.parry_press()
	else:
		player.parry_release()
		if player.aim_phase:
			player.launch_parry_dash()


func _physics_process(delta: float) -> void:
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
	var dt := delta
	if player.aim_phase:
		dt *= AIM_SLOW
	elif slowmo > 0.0:
		slowmo -= delta
		dt *= 0.3
	elif player.dash_kind == "power":
		dt *= DASH_SLOW
	if state == State.PLAY:
		run_time += dt
	_update_platform(dt)
	boss.strike_glow = player.is_attacking()
	boss.focus_glow = 1.0 if (player.aim_phase or player.is_charged()) else 0.0
	boss.focus_from = player.position
	boss.focus_reach = (Player.PARRY_DASH_SPEED_PERFECT if player.aim_perfect else Player.PARRY_DASH_SPEED) * Player.PARRY_DASH_TIME \
		if player.aim_phase else Player.CHARGE_SPEED * Player.CHARGE_DASH_TIME
	boss.step(dt, player.position)
	_drain_boss_events()
	player.step(delta)
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


func _update_platform(dt: float) -> void:
	if plat_dir > 0.0:
		plat_sink = minf(1.0, plat_sink + dt / PLAT_SINK_TIME)
	elif plat_dir < 0.0:
		plat_sink = maxf(0.0, plat_sink - dt / PLAT_RISE_TIME)
	lava.plat_center = Player.PLAT_CENTER
	lava.plat_half = Player.PLAT_HALF
	lava.plat_sink = plat_sink
	lava.plat_crack = clampf(plat_sink * 3.0, 0.0, 1.0) if plat_dir > 0.0 else 0.0


func _update_camera(delta: float) -> void:
	var v: Vector2 = player.vel
	var target: Vector2 = player.position + Vector2(v.x * 0.05, -80.0 + clampf(v.y * 0.1, -100.0, 100.0))
	var mode := 1.0
	if player.aim_phase or player.charging:       # 줌아웃 + 조준 방향 보여주기는 이때만
		target += player.aim * 160.0
		mode = AIM_ZOOM if player.aim_phase else CHARGE_ZOOM
	cam.position = cam.position.lerp(target, 1.0 - exp(-6.0 * delta))
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	shake = move_toward(shake, 0.0, 60.0 * delta)
	var z := CAM_ZOOM * mode
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 1.0 - exp(-8.0 * delta))
	bg.cam = cam.get_screen_center_position()


func _check_attacks() -> void:
	var p: Vector2 = player.position
	var beam_push: Vector2 = boss.beam_hit(p, Player.RADIUS)   # 패리 불가: 회피 돌진(무적)으로만 피한다
	if beam_push != Vector2.ZERO and not player.is_immune():
		hurt_player(beam_push)
		return
	var reach: float = player.parry_reach()
	for hb in boss.hitboxes(p):
		if not boss.overlaps(hb, p, reach):
			continue
		if player.parry_active:
			var perfect: bool = player.parry_t <= Player.PERFECT_WINDOW
			player.on_parry_success(perfect)
			boss.on_parried(hb)
			_parry_feedback(p, perfect, hb)
			return
		if not player.is_immune() and boss.overlaps(hb, p, Player.RADIUS):
			hurt_player(hb["push"])
			boss.on_hit_player(hb)
			return


## 피격 = 목숨 −1 + 스턴. 잠시 조작을 잃고 추락 → 용암 위험
func hurt_player(push: Vector2, damage := true) -> void:
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


## 표적(부위·갑옷·심장)에 공격 돌진이 아닐 때 닿음 → 튕겨남·스턴만 (피해 없음)
func touch_hurt(hit: Dictionary, pos: Vector2) -> void:
	var push: Vector2 = pos - boss.hit_center(hit)
	if push.length() < 0.1:
		push = Vector2.UP
	hurt_player(push, false)


func _parry_feedback(p: Vector2, perfect: bool, hb: Dictionary) -> void:
	var hp_pos: Vector2 = hb["pos"]
	var contact := p.lerp(hp_pos, 0.25) if not hb.has("rect") else p
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


func _drain_boss_events() -> void:
	for ev in boss.events:
		var pos: Vector2 = ev["pos"]
		match ev["type"]:
			"stomp":                            # 발 구르기 → 용암이 튄다
				shake = maxf(shake, 14.0)
				sfx.play("stomp", 2.0)
				fx.burst(pos, 30, Color(1.0, 0.45, 0.15, 0.9), 700.0, 0.7, 5.0, 1200.0, Vector2.UP, PI * 0.4)
				fx.ring(pos, Color(1.0, 0.5, 0.2, 0.6), 360.0, 0.35, 6.0)
			"beam":                             # 패리 불가 레이저 발사
				shake = maxf(shake, 16.0)
				sfx.play("dash", 6.0, 0.0)
				sfx.play("break", -4.0, 0.0)
				hud.flash(0.12, Color(0.6, 0.1, 0.4))
			"erupt":
				sfx.play("bolt", -6.0)
				shake = maxf(shake, 5.0)
			"swing":
				shake = maxf(shake, 10.0)
				sfx.play("dash", 4.0, 0.0)
				sfx.play("stomp", -4.0)
				fx.ring(pos, Color(0.9, 0.5, 0.4, 0.7), 260.0, 0.3, 6.0)
			"bolt":
				sfx.play("bolt", -4.0)
			"bolt_pop":
				fx.burst(pos, 8, Color(1.0, 0.78, 0.42), 300.0, 0.3)
			"part_break":                       # 부위 파괴: 크게 터지고 떨어져 나간다
				hitstop = 0.16
				shake = 22.0
				sfx.play("break", 4.0)
				sfx.play("stomp", -2.0)
				fx.burst(pos, 50, Color(1.0, 0.6, 0.3), 1200.0, 0.8, 5.0, 900.0)
				fx.burst(pos, 24, Color(0.6, 0.62, 0.68), 700.0, 1.0, 6.0, 1400.0)
				fx.rays_burst(pos, 12, Color(1.0, 0.8, 0.5), 380.0, 0.4, 6.0)
				fx.ring(pos, Color(1.0, 0.8, 0.55), 240.0, 0.4, 8.0)
				hud.flash(0.12, Color(1.0, 0.8, 0.6))
			"debris_land":
				shake = maxf(shake, 10.0)
				sfx.play("land", 2.0)
				fx.burst(pos, 20, Color(0.55, 0.57, 0.6, 0.8), 500.0, 0.6, 5.0, 900.0, Vector2.UP, PI * 0.45)
			"core_open":                        # 모든 부위 파괴 → 가슴이 열린다
				hitstop = 0.25
				shake = 26.0
				sfx.play("stomp", 4.0)
				sfx.play("win", -6.0, 0.0)
				fx.rays_burst(pos, 20, Color(1.0, 0.55, 0.3), 700.0, 0.8, 8.0)
				fx.ring(pos, Color(1.0, 0.6, 0.35), 500.0, 0.7, 10.0)
				hud.flash(0.2, Color(1.0, 0.6, 0.4))
			"core_ready":
				shake = maxf(shake, 12.0)
				sfx.play("perfect", 0.0, 0.0)
				fx.ring(pos, Color(1.0, 0.45, 0.25), 320.0, 0.5, 8.0)
	boss.events.clear()


# ── player.gd 에서 호출 ───────────────────────────────
## kind: "evade"(회피, 청백·가볍게) / "charge"(공격, 주황·묵직하게)
func on_dash(pos: Vector2, dir: Vector2, kind := "evade") -> void:
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


## 패리 돌진 종료(적중 또는 빗나감): 패리로 밀려난 팔은 바로 제자리로
func on_power_dash_end() -> void:
	boss.release_stagger()


func on_parry_launch(pos: Vector2, dir: Vector2) -> void:
	sfx.play("dash", 4.0, 0.0)
	shake = maxf(shake, 12.0)
	hud.flash(0.1, Color(0.8, 0.9, 1.0))
	fx.burst(pos, 30, Color(0.8, 0.92, 1.0), 1300.0, 0.4, 3.0, 0.0, -dir, 0.5)
	fx.ring(pos, Color(0.8, 0.92, 1.0), 160.0, 0.3, 6.0)


func on_strike(hit: Dictionary, dmg: int, pos: Vector2, dir: Vector2, power := false) -> void:
	var contact := pos + dir * Player.RADIUS
	var idx: int = hit["idx"]
	if hit["kind"] == "part":                  # 페이즈 1: 포대/팔꿈치 부위 타격
		if not boss.damage_part(idx, dmg):
			hitstop = 0.09 if power else 0.06
			shake = 14.0 if power else 9.0
			sfx.play("armor", 2.0 if power else 0.0)
			fx.burst(contact, 18 if power else 12, Color(1.0, 0.85, 0.6), 700.0, 0.35, 3.0, 0.0, -dir, 1.0)
			fx.ring(contact, Color(1.0, 0.7, 0.4), 90.0, 0.22, 4.0)
		hud.flash(0.06, Color(1.0, 0.9, 0.7))
		return
	var broken: bool = boss.damage_plate(idx, dmg)
	if power:                                  # 패리 돌진: 주변 갑옷도 함께 금이 간다
		var c: int = idx % boss.GRID_N
		var r: int = idx / boss.GRID_N
		for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: int = c + off.x
			var nr: int = r + off.y
			if nc >= 0 and nc < boss.GRID_N and nr >= 0 and nr < boss.GRID_N:
				boss.damage_plate(nr * boss.GRID_N + nc, 1)
		hitstop = 0.18
		shake = 26.0
		sfx.play("break", 4.0)
		sfx.play("perfect", 0.0)
		fx.burst(contact, 44, Color(1.0, 0.8, 0.5), 1400.0, 0.9, 5.0, 1200.0, -dir, 1.4)
		fx.rays_burst(contact, 14, Color(1.0, 0.85, 0.6), 420.0, 0.4, 6.0)
		fx.ring(contact, Color(1, 0.9, 0.7), 260.0, 0.4, 9.0)
	elif broken:
		hitstop = 0.11
		shake = 16.0
		sfx.play("break", 1.0)
		fx.burst(contact, 26, Color(0.84, 0.8, 0.7), 800.0, 0.8, 5.0, 1200.0, -dir, 1.2)
		fx.ring(contact, Color(1, 0.9, 0.75), 130.0, 0.3, 6.0)
	else:
		hitstop = 0.07
		shake = 10.0
		sfx.play("armor")
		fx.burst(contact, 14, Color(1.0, 0.9, 0.7), 650.0, 0.3, 3.0, 0.0, -dir, 1.0)
		fx.ring(contact, Color(1.0, 0.9, 0.7), 80.0, 0.2, 4.0)
	hud.flash(0.08, Color(1.0, 0.9, 0.7))


func on_heart_pierced(pos: Vector2) -> void:
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
	hud.banner("심장 관통", "%.1f초 · 남은 목숨 %d · R: 다시" % [run_time, lives])


func _die() -> void:
	state = State.DEAD
	dead_t = 2.5
	hud.banner("부서졌다", "잠시 후 재시작 (R: 즉시)")
