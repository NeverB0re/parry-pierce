extends SceneTree
# 메인 화면 캡처 (창 모드, 자동 종료): 한국어 / 영어 / 진행이 있을 때 / 조작법 목록 / 영어 항로도 / 영어 튜토리얼 한 장.
# 인자: -- --notutorial --out=<dir>  (메인 화면은 --notitle/--notutorial 이면 안 열리므로 여기서 직접 연다)
# 언어·진행 저장은 끈다.
const Loc := preload("res://scripts/loc.gd")
var main
var n := 0
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/title_%s.png" % [out, name])


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.tele.enabled = false
		var pr = main.Profile.new()
		pr.persist = false
		main.profile = pr
		main.world.profile = pr
		main.title.profile = pr
		Loc.persist = false
		Loc.lang = "ko"
		main.title.open()
	if n == 20:
		_shot("ko")
	if n == 21:
		Loc.set_lang("en")
	if n == 40:
		_shot("en")
	if n == 41:
		main.profile.cleared.append("observer")
		main.title.open()
	if n == 60:
		_shot("en_progress")
	if n == 61:
		main.title._confirm_new = true
		main.title._build()
	if n == 80:
		_shot("en_confirm")
	if n == 81:
		main.title._help = true
		main.title._build()
	if n == 100:
		_shot("en_help")
	if n == 101:
		main.title.close()
		main.open_world(true)
	if n == 125:
		_shot("en_world")
		main.world.close()
		get_paused()
	if n == 126:
		main.tutorial.enabled = true
		main.tutorial.replay("tentacle")
	if n == 150:
		_shot("en_tutorial")
		Loc.set_lang("ko")
		main.tutorial.replay("charge")
	if n == 175:
		_shot("ko_tutorial")
		quit()
	return false


func get_paused() -> void:
	paused = false
