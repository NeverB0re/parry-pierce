extends SceneTree
# 반응로 캡처 (창 모드, 자동 종료): 냉각 미로 → 양분 + 줄넘기 → 압착 경고·박힘 → 드라이브 조준 → 과열 셋 → 노심 융해.
# 인자: -- --notutorial --out=<dir> [--en]. 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
# [이름, 장면, 찍을 프레임, 플레이어 자리]
var plan := [
	["maze_snake", "m:snake", 420, Vector2(0, -900)],
	["maze_zigzag", "m:zigzag", 420, Vector2(0, -900)],
	["maze_steps", "m:steps", 420, Vector2(0, -900)],
	["maze_rooms", "m:rooms", 420, Vector2(0, -900)],
	["maze_fork", "m:fork", 420, Vector2(0, -900)],
	["maze_braid", "m:braid", 420, Vector2(0, -900)],
	["divide", "divide", 200, Vector2(-500, -1350)],
	["clamp_warn", "clamp", 60, Vector2(0, -1450)],
	["clamp_held", "clamp", 160, Vector2(0, -1450)],
	["drive_aim", "aim", 20, Vector2(200, -1550)],
	["heat3", "heat3", 120, Vector2(0, -1450)],
	["meltdown", "melt", 40, Vector2(0, -1450)],
]
var idx := 0
var local := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.tele.enabled = false
		var pr = main.Profile.new()
		pr.persist = false
		main.profile = pr
		main.world.profile = pr
		main.title.close()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if OS.get_cmdline_user_args().has("--en"):
			var Loc = load("res://scripts/loc.gd")
			Loc.persist = false
			Loc.lang = "en"
	if n < 4:
		return false
	if idx >= plan.size():
		quit()
		return false
	var pl: Array = plan[idx]
	var b = main.boss
	var p = main.player
	var sc: String = pl[1]
	if local == 0:
		main.start_stage(5)
		b = main.boss
		main.debug.god = true
		b.next_t = 999.0
		p.reset(pl[3], false)
		p.on_platform = false
		if sc.begins_with("m:"):
			b.start_attack(b.Maze.new(sc.substr(2), true))
		match sc:
			"divide":
				b.start_attack(b.Divide.new())
			"clamp":
				b.start_attack(b.Maze.new("rooms", true))
				b.start_side(b.Clamp.new())
			"aim":
				b.start_attack(b.Maze.new("snake", true))
				for k in 200:
					b.step(1.0 / 60.0, pl[3])
				p.aim_phase = true
				p.aim_left = 99.0
			"heat3", "melt":
				for i in (3 if sc == "heat3" else 4):
					b.pending_drive = true
					b.damage({"kind": "shield", "x": [-900.0, 0.0, 450.0, 900.0][i]}, 12)
				b.next_t = 999.0
				b.atk = null
				b.start_attack(b.Maze.new("snake", true))
				if sc == "melt":
					b.pending_drive = true
					if b.damage({"kind": "shield", "x": -450.0}, 12):
						b.die()
	local += 1
	p.invuln = 999.0
	p.vel = Vector2.ZERO
	p.position = pl[3]
	if sc == "aim":
		p.aim_phase = true
		p.aim_left = 99.0
	main.hud.clear_banner()
	if local == int(pl[2]):
		root.get_texture().get_image().save_png("%s/reactor_%s.png" % [out, pl[0]])
		idx += 1
		local = 0
	return false
