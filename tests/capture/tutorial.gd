extends SceneTree
# 튜토리얼 팝업 캡처 (창 모드, 자동 종료). 인자: -- --notutorial --out=<dir>
var main
var n := 0
var out := ""
# [프레임(60fps 기준 시작 후), 페이지, 애니메이션 시각]
var plan := [
	["dodge", 1.6], ["dodge", 4.0],
	["parry", 2.0], ["parry", 3.4], ["parry", 4.6],
	["charge", 0.8], ["charge", 2.6], ["charge", 5.2], ["charge", 6.2],
	["unparry", 1.0], ["unparry", 3.2],
	["barrage", 2.0], ["barrage", 5.6],
	["press", 1.6], ["press", 4.9],
	["dodge", 0.5],
]
var idx := 0
var cur := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	n += 1
	if n < 5:
		return false
	var tut = main.tutorial
	if idx >= plan.size():
		quit()
		return false
	var step: Array = plan[idx]
	if cur != step[0]:
		tut.replay(step[0])
		cur = step[0]
	var st = tut.stage
	if st.t >= step[1]:
		root.get_texture().get_image().save_png("%s/t_%s_%d.png" % [out, step[0], idx])
		idx += 1
		if idx < plan.size() and plan[idx][0] == cur:
			pass                      # 같은 페이지의 다음 시각은 이어서 진행
		elif idx < plan.size():
			cur = ""                  # 다른 페이지: 다시 열어 t 를 0 으로
	return false
