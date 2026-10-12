extends SceneTree
# 코어 손상 단계 캡처 (창 모드, 자동 종료). 인자: -- --notutorial --out=<dir>
var main
var n := 0
var out := ""
var plan := [0, 32, 40, 40, 40, 9999]     # 각 단계에서 줄 피해 (누적)
var idx := 0
var wait := 0


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
		for i in 4:
			b.damage_part(i, 99)
		b.phase = 3
		b.next_t = 99.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if n > 3:
		p.invuln = 99.0
		p.position = b.HEART_POS + Vector2(-520, 180)
		p.vel = Vector2.ZERO
		main.cam.position = b.HEART_POS
		main.cam.zoom = Vector2(0.9, 0.9)
		b.next_t = 99.0
	if n > 10:
		wait += 1
		if wait == 1 and idx < plan.size():
			b.damage_core(plan[idx])
		if wait == 25:
			root.get_texture().get_image().save_png("%s/core_%d.png" % [out, idx])
			idx += 1
			wait = 0
	if idx >= plan.size():
		quit()
	return false
