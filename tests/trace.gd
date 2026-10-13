extends SceneTree
# 동작 동일성 검사용 궤적 기록: 시드를 고정하고 정해진 입력으로 몇 천 프레임을 돌리며 상태를 글로 남긴다.
# 리팩터 전후 결과 파일이 같으면 동작이 바뀌지 않은 것이다.
# 사용: godot --headless --path . -s tests/trace.gd -- --out=<파일>
var main
var n := 0
var out := "user://trace.txt"
var lines := PackedStringArray()
const FRAMES := 4200


class FakeStick:
	var stick := Vector2.ZERO


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	n += 1
	if n == 2:
		main.set_physics_process(false)          # 엔진의 실시간 물리 틱이 끼어들지 않게 (프레임마다 직접 한 번만 돈다)
		main.touch_ui = FakeStick.new()
		main.reset_run()
		seed(7)
		main.player.reset(Vector2(200, -1500), false)
	if n < 2:
		return false
	var p = main.player
	var b = main.boss
	main.lives = 99
	var k := n - 2
	main.touch_ui.stick = Vector2.from_angle(k * 0.013) * (0.4 + 0.6 * absf(sin(k * 0.007)))
	if p.position.y > -1250.0 and main.state == main.State.PLAY:
		p.vel.y = -700.0                        # 용암에 빠지지 않게 끌어올림 (같은 규칙으로 계속 싸우도록)
	if k % 47 == 0:
		main._dash_input(true)
	if k % 47 == 3:
		main._dash_input(false)
	if k % 131 == 60:
		main._dash_input(true)
	if k % 131 == 100:
		main._dash_input(false)
	if k % 89 == 20:
		main._parry_input(true)
	if k % 89 == 30:
		main._parry_input(false)
	if k == 1500:
		for i in 4:
			b.damage_part(i, 99)
	if k % 97 == 50 and main.state == main.State.PLAY and p.dash_t <= 0.0 and not p.aim_phase:   # 표적 쪽으로 옮겨 직접 친다 (피해·손상 단계·장갑 판 검사)
		var tgt: Vector2 = b.HEART_POS
		if b.phase == 1:
			for i in 4:
				if b.part_hp[(k / 97 + i) % 4] > 0:
					tgt = b.part_pos((k / 97 + i) % 4)
					break
		p.position = tgt + Vector2(-170, 30)
		p.aim = Vector2(1, -0.15).normalized()
		p.dash_cd = 0.0
		p._dash("charge" if k % 2 == 0 else "dash")
	main._physics_process(1.0 / 60.0)
	if k % 5 == 0:
		lines.append(_state(k))
	if k >= FRAMES:
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines))
		f.close()
		print("trace ok frames=", k, " lines=", lines.size())
		quit()
	return false


func _r(v: Vector2) -> String:
	return "%.2f,%.2f" % [v.x, v.y]


func _state(k: int) -> String:
	var p = main.player
	var b = main.boss
	var bsum := Vector2.ZERO
	var nb := 0
	for q in _bolt_positions(b):
		bsum += q
		nb += 1
	var s := "%d st%d L%d P[%s v%s %s d%.3f c%.3f buf%s] " % [k, main.state, main.lives, _r(p.position), _r(p.vel), p.dash_kind, p.dash_t, p.dash_cd, p.buffed]
	s += "B[ph%d hp%s ar%s cs%d %s next%.3f fists%s/%s feet%s/%s] " % [b.phase, str(b.part_hp), _armor(b), _core_stage(b), _atk(b), b.next_t, _r(b.fists[0]), _r(b.fists[1]), _r(b.feet[0]), _r(b.feet[1])]
	s += "bolts%d sum%s" % [nb, _r(bsum)]
	return s


## 구조가 바뀌어도 같은 값을 읽도록 (리팩터 전후 양쪽에서 동작)
func _bolt_positions(b) -> Array:
	if "shots" in b:
		return Array(b.shots.pos)
	return b.bolts.map(func(x): return x["pos"])


func _armor(b) -> String:
	if "core" in b and b.core != null and not (b.core is Vector2):
		return "%d/%d" % [b.core.armor_hp, b.core.core_hp]
	return "%d/%d" % [b.armor_hp, b.core_hp]


func _core_stage(b) -> int:
	if "core" in b and b.core != null and not (b.core is Vector2):
		return b.core.stage
	return b.core_stage


func _atk(b) -> String:
	if b.atk == null:
		return "-"
	if b.atk is Dictionary:
		if b.atk.is_empty():
			return "-"
		return "%s:%s:%.3f" % [b.atk["kind"], b.atk.get("phase", ""), b.atk["t"]]
	return "%s:%s:%.3f" % [b.atk.kind, b.atk.phase, b.atk.t]
