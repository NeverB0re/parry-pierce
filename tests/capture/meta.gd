extends SceneTree
# 승리 배너 → 월드 맵(항로도) → 이전 스테이지 고르기 → FTL 도약 캡처 (창 모드, 자동 종료). 인자: -- --notutorial --out=<dir>
# 진행 저장·플레이 기록은 끈다 (사용자 저장 파일을 건드리지 않음)
var main
var n := 0
var out := ""
var shots := {8: "win", 40: "world", 80: "world_replay"}
var ftl_shots := [0.5, 1.0, 1.2, 1.6]
var ftl_idx := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/meta_%s.png" % [out, name])


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.tele.enabled = false
		var pr = main.Profile.new()
		pr.persist = false
		main.profile = pr
		main.world.profile = pr
		main.start_stage(0)
		main.player.invuln = 99.0
		main._core_destroyed(main.boss.core.center)
	if n == 30:
		main.open_world()
	if n == 44:
		main.world.select(0)
	if shots.has(n):
		_shot(shots[n])
	if n == 90:
		main.world.jump()
	if n > 90 and main.ftl.is_playing() and ftl_idx < ftl_shots.size() and main.ftl.t >= ftl_shots[ftl_idx]:
		_shot("ftl_%d" % ftl_idx)
		ftl_idx += 1
	if n > 90 and not main.ftl.is_playing():
		ftl_idx += 1
		if ftl_idx >= 10:
			_shot("arrived")
			quit()
	return false
