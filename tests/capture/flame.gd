extends SceneTree
# 화염·보호막 확인용: 여러 방향의 기체를 한 장면에 차례로 캡처 (창 모드, 자동 종료)
var main
var n := 0
var out := ""


class FakeStick:
	var stick := Vector2(0, -1)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.touch_ui = FakeStick.new()


var name_buff := 0


func _pose(dir: Vector2, vel: Vector2, shield := false) -> void:
	var p = main.player
	p.reset(Vector2(-300, -1500), false)
	p.invuln = 99.0
	main.touch_ui.stick = dir
	p.aim = dir.normalized()
	p.facing = dir.angle()
	p.vel = vel
	p.shield_t = 5.0 if shield else 0.0
	p.buffed = (name_buff == 1 or name_buff == 2)
	p.buff_strong = name_buff == 2
	main.cam.position = p.position
	main.cam.reset_smoothing()


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out + "/" + name + ".png")


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.boss.next_t = 99.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var steps := [
		[5, Vector2(0, -1), Vector2.ZERO, false, "f1_up"],
		[25, Vector2(1, 0), Vector2.ZERO, false, "f2_right"],
		[45, Vector2(1, 1), Vector2.ZERO, false, "f3_diag"],
		[65, Vector2(0, -1), Vector2(0, 520), false, "f4_retro"],
		[85, Vector2(0, -1), Vector2.ZERO, true, "f5_shield"],
		[105, Vector2(0, -1), Vector2.ZERO, false, "f6_buff"],
		[125, Vector2(0, -1), Vector2.ZERO, false, "f7_strong"],
	]
	for s in steps:
		var f: int = s[0]
		if n == f:
			name_buff = 1 if s[4] == "f6_buff" else (2 if s[4] == "f7_strong" else 0)
			_pose(s[1], s[2], s[3])
		if n == f + 15:
			_shot(s[4])
		# 관성 유지: 매 프레임 속도를 다시 설정하지 않아도 되도록 짧은 구간만 본다
	if n >= 150:
		quit()
	return false
