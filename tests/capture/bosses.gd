extends SceneTree
# 보스 비교 캡처 (창 모드, 자동 종료): 스테이지마다 대기 모습을 같은 줌으로 찍는다. 인자: -- --notutorial --out=<dir> [--zoom=0.42]
# 진행 저장·플레이 기록은 끈다
var main
var n := 0
var out := ""
var zoom := 0.42
var stage := 0
var local := 0
const CAM := [Vector2(0, -1750), Vector2(0, -1600), Vector2(0, -1600), Vector2(0, -1600)]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		if a.begins_with("--zoom="):
			zoom = a.trim_prefix("--zoom=").to_float()
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
	if n < 4:
		return false
	if stage >= main.Stages.LIST.size():
		quit()
		return false
	if local == 0:
		main.start_stage(stage)
		main.boss.next_t = 999.0
		main.player.reset(Vector2(350, -900), false)
	local += 1
	main.player.invuln = 999.0
	main.player.vel = Vector2.ZERO
	main.player.position = Vector2(350, -900)
	main.cam.position = CAM[mini(stage, CAM.size() - 1)]
	main.cam.zoom = Vector2(zoom, zoom)
	main.hud.clear_banner()
	if local == 40:
		root.get_texture().get_image().save_png("%s/boss_%d_%s.png" % [out, stage, main.Stages.LIST[stage]["id"]])
		stage += 1
		local = 0
	return false
