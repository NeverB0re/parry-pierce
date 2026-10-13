extends CanvasLayer
## 정비 화면 (스테이지 사이): 부산물 포인트로 노드 트리 3개를 찍고, 동력 코어를 하나 장착한 뒤 FTL 도약.
## 노드는 되돌릴 수 없으므로 두 번 눌러야 확정된다. 코어는 언제든 바꿀 수 있다.

signal jump_requested

const Upgrades := preload("res://scripts/upgrades.gd")
const Stages := preload("res://scripts/stages.gd")
const C_TAKEN := Color(1.0, 0.85, 0.45)
const C_OPEN := Color(0.75, 0.95, 1.0)
const C_LOCKED := Color(0.5, 0.52, 0.58)

var profile                          # main.gd 가 연결 (profile.gd)
var ui_scale := 1.0
var font: SystemFont
var pending := ""                    # 한 번 누른 노드 (한 번 더 누르면 확정)
var sub: Label
var info: Label
var node_buttons := {}               # 노드 id → Button
var core_buttons := {}               # 코어 id → Button
var jump_button: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(36 * ui_scale))
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", int(14 * ui_scale))
	margin.add_child(root)

	root.add_child(_label("정비 — 기체 개조", 34, Color(1.0, 0.95, 0.88)))
	sub = _label("", 18, Color(0.75, 0.8, 0.88))
	root.add_child(sub)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", int(18 * ui_scale))
	root.add_child(cols)
	for tree in Upgrades.TREES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", int(8 * ui_scale))
		col.add_child(_label(tree["name"], 22, Color(1.0, 0.8, 0.55)))
		for id in tree["nodes"]:
			var nid: String = id
			var b := _button(col, "", func() -> void: _on_node(nid))
			b.mouse_entered.connect(func() -> void: _show_info(nid))
			node_buttons[nid] = b
		cols.add_child(col)
	var cc := VBoxContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.add_theme_constant_override("separation", int(8 * ui_scale))
	cc.add_child(_label("동력 코어 (하나만 장착)", 22, Color(1.0, 0.8, 0.55)))
	for id in Upgrades.CORES:
		var cid: String = id
		var b := _button(cc, "", func() -> void: _on_core(cid))
		b.mouse_entered.connect(func() -> void: _show_core_info(cid))
		core_buttons[cid] = b
	cols.add_child(cc)

	info = _label("", 18, Color(0.88, 0.9, 0.95))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(0, 70 * ui_scale)
	root.add_child(info)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	jump_button = _button(bottom, "FTL 도약 ▶", jump)
	jump_button.custom_minimum_size = Vector2(300, 60) * ui_scale


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(size * ui_scale))
	l.add_theme_color_override("font_color", col)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 62) * ui_scale
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", int(17 * ui_scale))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func open() -> void:
	pending = ""
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	_show_summary()


func close() -> void:
	visible = false


func jump() -> void:
	if not visible:
		return
	close()
	jump_requested.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		jump()
	get_viewport().set_input_as_handled()            # 정비 중엔 다른 키(ESC 메뉴 등)를 막는다. 나가는 길은 FTL 도약


func refresh() -> void:
	var st: Dictionary = Stages.LIST[profile.stage]
	sub.text = "부산물 포인트 %d 남음   ·   다음 도약: %s — 콜로서스 「%s」" % [profile.points_left(), st["coord"], st["name"]]
	for id in node_buttons:
		var b: Button = node_buttons[id]
		var n: Dictionary = Upgrades.NODES[id]
		var head: String = "%s  %s" % [id, n["name"]]
		if profile.nodes.has(id):
			b.text = head + "\n✓ 개조 완료"
			b.add_theme_color_override("font_color", C_TAKEN)
			b.add_theme_color_override("font_hover_color", C_TAKEN)
		elif not Upgrades.requirements_met(id, profile.nodes):
			b.text = head + "\n선행: " + ", ".join(n["req"])
			b.add_theme_color_override("font_color", C_LOCKED)
			b.add_theme_color_override("font_hover_color", C_LOCKED)
		elif profile.points_left() <= 0:
			b.text = head + "\n포인트 부족"
			b.add_theme_color_override("font_color", C_LOCKED)
			b.add_theme_color_override("font_hover_color", C_LOCKED)
		elif pending == id:
			b.text = head + "\n한 번 더 눌러 확정 (되돌릴 수 없음)"
			b.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35))
			b.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.35))
		else:
			b.text = head + "\n개조 가능"
			b.add_theme_color_override("font_color", C_OPEN)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
	for id in core_buttons:
		var b: Button = core_buttons[id]
		var c: Dictionary = Upgrades.CORES[id]
		if not profile.cores.has(id):
			b.text = "??? (미확보)"
			b.disabled = true
		else:
			b.disabled = false
			b.text = c["name"] + ("\n장착 중 — 눌러서 해제" if profile.equipped == id else "\n눌러서 장착")
			b.add_theme_color_override("font_color", C_TAKEN if profile.equipped == id else C_OPEN)


func _on_node(id: String) -> void:
	if not Upgrades.can_take(id, profile.nodes, profile.points_left()):
		pending = ""
		_show_info(id)
		refresh()
		return
	if pending != id:
		pending = id
	else:
		pending = ""
		profile.take_node(id)
	_show_info(id)
	refresh()


func _on_core(id: String) -> void:
	profile.equip(id)
	refresh()
	_show_core_info(id)


func _show_info(id: String) -> void:
	var n: Dictionary = Upgrades.NODES[id]
	var req: String = "" if n["req"].is_empty() else "   (선행: %s)" % ", ".join(n["req"])
	info.text = "%s %s — %s%s" % [id, n["name"], n["desc"], req]


func _show_core_info(id: String) -> void:
	var c: Dictionary = Upgrades.CORES[id]
	if not profile.cores.has(id):
		info.text = "아직 확보하지 못한 코어입니다."
		return
	info.text = "%s (%s 스타일) — %s" % [c["name"], c["style"], c["desc"]]


## 현재 적용 중인 개조 요약
func _show_summary() -> void:
	var parts := PackedStringArray()
	for id in profile.nodes:
		parts.append("%s %s" % [id, Upgrades.NODES[id]["name"]])
	var core: String = Upgrades.CORES[profile.equipped]["name"] if Upgrades.CORES.has(profile.equipped) else "없음"
	info.text = "적용 중인 개조: %s   ·   장착 코어: %s" % ["없음" if parts.is_empty() else ", ".join(parts), core]
