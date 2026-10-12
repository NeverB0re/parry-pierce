extends SceneTree
# 탄 그림 확인용 캡처 (창 모드, 자동 종료). 인자: -- --notutorial --out=<dir>
var main
var n := 0
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	n += 1
	var b = main.boss
	var p = main.player
	if n == 3:
		b.next_t = 999.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		p.reset(Vector2(-300, -1600), false)
		for k in 14:
			var bolt := {"pos": p.position + Vector2(-260 + k * 40, -120 + (k % 3) * 70), "vel": Vector2.from_angle(0.3 * k) * 200.0, "life": 99.0, "age": 1.0}
			if k % 4 == 0:
				bolt["lava"] = true
			b.bolts.append(bolt)
	if n > 3:
		p.invuln = 99.0
		p.position = Vector2(-300, -1600)
		p.vel = Vector2.ZERO
		main.cam.position = p.position
		b.next_t = 999.0
	if n == 30:
		root.get_texture().get_image().save_png(out + "/bolts.png")
		quit()
	return false
