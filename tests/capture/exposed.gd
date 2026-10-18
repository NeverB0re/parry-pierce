extends SceneTree
# 껍질이 다 벗겨진 코어 캡처 (창 모드, 자동 종료): 관측자·탄막 요새의 "한 대면 터지는" 노출 코어. 인자: -- --notutorial --out=<dir>
# 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
var stage := 0
var local := 0
const STAGES := [0, 1]


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
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if n < 4:
		return false
	if stage >= STAGES.size():
		quit()
		return false
	var b = main.boss
	if local == 0:
		main.start_stage(STAGES[stage])
		b = main.boss
		for i in b.part_count():
			b.damage_part(i, 999)
		b.phase = 3
		b.open_t = 99.0
		b.core.damage(9999)
		b.core.guard = 0.0
	local += 1
	b.next_t = 999.0
	main.player.invuln = 999.0
	main.player.vel = Vector2.ZERO
	main.player.position = b.core.center + Vector2(-500, 300)
	main.cam.position = b.core.center
	main.cam.zoom = Vector2(0.75, 0.75)
	main.hud.clear_banner()
	if local == 150:
		root.get_texture().get_image().save_png("%s/exposed_%d.png" % [out, STAGES[stage]])
		stage += 1
		local = 0
	return false
