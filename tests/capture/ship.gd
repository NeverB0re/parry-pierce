extends SceneTree
# 에셋 적용 확인용 캡처 (창 모드, 자동 종료)
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


func _place(pos: Vector2, aim: Vector2) -> void:
	var p = main.player
	p.reset(pos, false)
	p.invuln = 99.0
	p.aim = aim
	p.facing = aim.angle()
	main.cam.position = pos
	main.cam.reset_smoothing()


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out + "/" + name + ".png")


func _process(_d: float) -> bool:
	n += 1
	var p = main.player
	var b = main.boss
	if n == 2:
		b.next_t = 99.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match n:
		5:
			_place(Vector2(-300, -1600), Vector2.UP)
		40:
			_shot("s1_idle")
		45:
			main.touch_ui.stick = Vector2(1, -0.3).normalized()
			_place(Vector2(-300, -1600), Vector2(1, -0.3).normalized())
		70:
			_shot("s2_bank")
		75:
			main.touch_ui.stick = Vector2.RIGHT
			_place(Vector2(-300, -1600), Vector2.RIGHT)
			p.dash_t = 0.2
			p.dash_kind = "charge"
			p.vel = Vector2(3000, 0)
		85:
			_shot("s3_charge")
		90:
			main.touch_ui.stick = Vector2(0, -1)
			_place(Vector2(-300, -1600), Vector2.UP)
			var c: Vector2 = p.position + Vector2(60, -40)
			main.fx.sprite(c, 2, 420.0, 0.5)
			main.fx.sprite(c, 1, 260.0, 0.45, false, Color.WHITE, 0.05)
		96:
			_shot("s4_parry_fx")
		100:
			_place(Vector2(-300, -1600), Vector2.UP)
			main.fx.sprite(p.position, 3, 380.0, 0.4, true)
		108:
			_shot("s5_evade_fx")
		115:
			b.damage_part(0, 99)
		122:
			_place(b.part_pos(0) + Vector2(0, 160), Vector2.UP)
		128:
			_shot("s6_partbreak")
	if n >= 130:
		quit()
	return false
