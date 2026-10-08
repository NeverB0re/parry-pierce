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

const SPAWN := Vector2(650, -9)
const CAM_ZOOM := 0.72             # 기본 줌아웃 (튕겨 올라가도 표적이 시야에 남도록)
const AIM_ZOOM := 0.82             # 방향 지정 중엔 물러나 표적을 넓게 본다
const CHARGE_ZOOM := 0.85            # 차징 중에만 물러난다
const AIM_SLOW := 0.08             # 방향 지정 중 월드 시간 배율
const FALL_MIN_HEIGHT := 350.0     # 이 높이 이상에서 바닥에 떨어지면 '추락'

enum State { PLAY, WON, DEAD }

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
var falls := 0
var dead_t := 0.0
var spawn := SPAWN


func _ready() -> void:
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED   # 플레이 중엔 창 밖으로 못 나감 (ESC 메뉴에서 해제)
	for a in OS.get_cmdline_user_args():      # 테스트용: -- --spawn=x,y
		if a.begins_with("--spawn="):
			var xy := a.trim_prefix("--spawn=").split(",")
			if xy.size() == 2:
				spawn = Vector2(xy[0].to_float(), xy[1].to_float())

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg = Background.new()
	bg_layer.add_child(bg)

	add_child(Ground.new())
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
	player.reset(spawn)
	fx.clear()
	state = State.PLAY
	run_time = 0.0
	falls = 0
	hitstop = 0.0
	slowmo = 0.0
	hud.clear_banner()
	cam.position = player.position + Vector2(0, -80)
	cam.reset_smoothing()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if state != State.PLAY:
			return
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if player.aim_phase:
					player.launch_parry_dash()
				else:
					player.charge_start()      # 누르고 있으면 차지, 떼면 돌진
			else:
				player.charge_release()
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
	var dt := delta
	if player.aim_phase:
		dt *= AIM_SLOW
	elif slowmo > 0.0:
		slowmo -= delta
		dt *= 0.3
	if state == State.PLAY:
		run_time += dt
	boss.strike_glow = player.dash_t > 0.0
	boss.step(dt, player.position)
	_drain_boss_events()
	player.step(dt)
	if state == State.PLAY:
		_check_attacks()
	elif state == State.DEAD:
		dead_t -= delta
		if dead_t <= 0.0:
			reset_run()
	fx.step(dt)


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


func hurt_player(push: Vector2) -> void:
	var p: Vector2 = player.position
	player.on_hurt(push)
	hitstop = 0.07
	shake = 12.0
	hud.flash(0.25, Color(0.9, 0.1, 0.1))
	fx.burst(p, 14, Color(0.9, 0.15, 0.15), 500.0)
	sfx.play("hurt")
	if player.hp <= 0:
		_die()


## 갑옷/심장에 돌진 중이 아닐 때 닿음 → 피해
func touch_hurt(hit: Dictionary, pos: Vector2) -> void:
	var push: Vector2 = pos - boss.hit_center(hit)
	if push.length() < 0.1:
		push = Vector2.UP
	hurt_player(push)


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
			"stomp":
				shake = maxf(shake, 14.0)
				sfx.play("stomp", 2.0)
				fx.burst(pos, 30, Color(0.55, 0.57, 0.6, 0.8), 600.0, 0.7, 5.0, 900.0, Vector2.UP, PI * 0.45)
				fx.ring(pos, Color(0.8, 0.8, 0.8, 0.6), 420.0, 0.35, 6.0)
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
func on_dash(pos: Vector2, dir: Vector2, level := 1) -> void:
	sfx.play("dash", -6.0 + 2.0 * level)
	fx.burst(pos, 8 + 6 * level, Color(0.9, 0.9, 0.95, 0.7), 300.0 + 150.0 * level, 0.25 + 0.05 * level, 2.0 + 0.5 * level, 0.0, -dir, 0.5)
	if level > 1:
		shake = maxf(shake, 5.0 * level)
		fx.ring(pos, Color(1.0, 0.6, 0.3), 100.0 + 40.0 * level, 0.3, 5.0)


func on_charge_tick(pos: Vector2, level: int) -> void:
	sfx.play("bolt", -2.0)
	shake = maxf(shake, 3.0 + level)
	fx.ring(pos, Color(1.0, 0.7, 0.35), 70.0 + 18.0 * level, 0.25, 4.0)


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
	hud.banner("심장 관통", "%.1f초 · 추락 %d회 · R: 다시" % [run_time, falls])


func on_landed(peak_y: float) -> void:
	sfx.play("land", -6.0)
	fx.burst(player.position + Vector2(0, 8), 10, Color(0.55, 0.57, 0.6, 0.7), 260.0, 0.4, 3.0, 600.0, Vector2.UP, PI * 0.4)
	if peak_y < -FALL_MIN_HEIGHT and state == State.PLAY:
		falls += 1
		shake = maxf(shake, 6.0)


func _die() -> void:
	state = State.DEAD
	dead_t = 2.2
	slowmo = 0.6
	hud.banner("부서졌다", "잠시 후 재시작 (R: 즉시)")
