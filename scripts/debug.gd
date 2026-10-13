extends CanvasLayer
## 개발용 디버그: F1 오버레이(상태·수치·프레임), F2 무적, F3 적 공격 정지, F4 코어 페이즈로 건너뛰기,
## F5 게임 속도 0.5배, F6 튜토리얼 기록 초기화. 플레이어에게 보여 주는 화면이 아니라 시험용이다.

var main: Node
var show := false
var god := false
var freeze := false
var slow := false
var font: SystemFont
var label: Label
var _phys_us := 0.0


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Malgun Gothic", "monospace"])
	label = Label.new()
	label.position = Vector2(12, 170)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	add_child(label)


## main.gd 가 물리 처리에 걸린 시간(µs)을 알려 준다
func record_physics(us: int) -> void:
	_phys_us = lerpf(_phys_us, float(us), 0.1)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_F1:
			show = not show
			label.visible = show
		KEY_F2:
			god = not god
		KEY_F3:
			freeze = not freeze
		KEY_F4:
			_skip_to_core()
		KEY_F5:
			slow = not slow
			Engine.time_scale = 0.5 if slow else 1.0
		KEY_F6:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tutorial.cfg"))
			main.tutorial.seen = {}
		_:
			return
	get_viewport().set_input_as_handled()


func _skip_to_core() -> void:
	var b = main.boss
	if b.phase == 1:
		for i in 4:
			b.damage_part(i, 999)


func _process(_dt: float) -> void:
	if not show:
		return
	var p = main.player
	var b = main.boss
	var lines := PackedStringArray()
	lines.append("[디버그] FPS %d · 물리 %.0f µs · 탄 %d · 입자 %d" % [Engine.get_frames_per_second(), _phys_us, b.shots.size(), main.fx.parts.size()])
	lines.append("F2 무적 %s · F3 공격 정지 %s · F4 코어로 · F5 속도 0.5x %s · F6 튜토리얼 초기화" % [_on(god), _on(freeze), _on(slow)])
	lines.append("페이즈 %d · 외부 시스템 %s · 장갑 %d/%d · 코어 %d · 공격 %s" % [b.phase, str(b.part_hp), b.core.armor_hp, b.ARMOR_HP, b.core.core_hp, b.attack_kind()])
	lines.append("실드 셀 %d · 돌진 쿨 %.2f · 차지 쿨 %.2f · 차지 %.2f · 무적 %.2f · 제어 불능 %.2f" % [main.lives, p.dash_cd, p.charge_cd, p.charge_t if p.charging else 0.0, maxf(p.invuln, p.shield_t), p.stun])
	lines.append("동조 %s %.2fs · 패리 %s · 시간 %.1fs" % ["완전" if p.buff_strong else ("일반" if p.buffed else "-"), p.buff_t, "열림" if p.parry_active else "-", main.run_time])
	label.text = "\n".join(lines)


static func _on(v: bool) -> String:
	return "ON" if v else "off"
