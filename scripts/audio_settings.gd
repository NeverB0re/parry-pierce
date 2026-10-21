extends RefCounted
## 음량 설정: 전체 · 음악 · 효과음 (0~1). 버스 Music·SFX (default_bus_layout.tres) 는 Master 로 보낸다. user://settings.cfg 의 [audio] 에 저장된다.
## 슬라이더 값은 귀에 들리는 크기에 맞춰 제곱해서 쓴다 (0.5 = -12dB ≈ 체감 절반).
## 처음 실행은 전체 0.7 (-6dB): 100% 에서 실제 플레이 소리를 재면 약 -14 LUFS(음악 스트리밍 수준, 겹치면 0dBFS 까지 닿음) →
## 0.7 이면 약 -20 LUFS (PC 게임에서 흔한 -18~-23 사이). Master 끝에 리미터를 걸어 효과음이 겹쳐도 깨지지 않게 한다 (v0.119 측정)

const Loc := preload("res://scripts/loc.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const PATH := "user://settings.cfg"
const BUSES := ["Master", "Music", "SFX"]
const NAMES := {"Master": "전체 음량", "Music": "음악", "SFX": "효과음"}
const DEFAULT := {"Master": 0.7, "Music": 1.0, "SFX": 1.0}

static var vol := DEFAULT.duplicate()
static var persist := true           # 헤드리스(테스트)에서는 읽고 쓰지 않는다


## 시작할 때 한 번: 저장된 음량을 적용한다. 버스 Music·SFX 는 default_bus_layout.tres 에 있다
## (실행 중에 add_bus 로 만들면 웹판(샘플 재생 방식)에서 그 버스로 가는 소리가 전부 무음이 된다, v0.120)
static func init() -> void:
	var has_limiter := false
	for k in AudioServer.get_bus_effect_count(0):
		has_limiter = has_limiter or AudioServer.get_bus_effect(0, k) is AudioEffectHardLimiter
	if not has_limiter and not OS.has_feature("web"):     # 웹 샘플 재생은 버스 효과를 쓰지 않는다
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)
	persist = DisplayServer.get_name() != "headless"
	if persist:
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			for b in BUSES:
				vol[b] = clampf(float(cf.get_value("audio", b, DEFAULT[b])), 0.0, 1.0)
	for b in BUSES:
		_apply(b)


static func set_volume(b: String, v: float) -> void:
	vol[b] = clampf(v, 0.0, 1.0)
	_apply(b)


static func save() -> void:
	if not persist:
		return
	var cf := ConfigFile.new()
	cf.load(PATH)                                  # 언어 등 다른 설정은 그대로 둔다
	for b in BUSES:
		cf.set_value("audio", b, vol[b])
	cf.save(PATH)


static func _apply(b: String) -> void:
	var i := AudioServer.get_bus_index(b)
	if i < 0:
		return
	var v: float = vol[b]
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))


## 옵션 메뉴의 "소리" 소제목
static func section_label(font: Font, ui_scale: float) -> Label:
	var l := Label.new()
	l.text = Loc.t("소리")
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", int(18 * ui_scale))
	l.add_theme_color_override("font_color", UiStyle.C_DIM)
	return l


## 메뉴용: 이름 · 슬라이더 · 퍼센트 줄 셋을 parent 에 넣는다 (손을 떼면 저장)
static func build_rows(parent: Control, font: Font, ui_scale: float) -> void:
	for b in BUSES:
		var bus: String = b
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(14 * ui_scale))
		var name := Label.new()
		name.text = Loc.t(NAMES[bus])
		name.custom_minimum_size = Vector2(130, 0) * ui_scale
		name.add_theme_font_override("font", font)
		name.add_theme_font_size_override("font_size", int(20 * ui_scale))
		name.add_theme_color_override("font_color", UiStyle.C_TEXT)
		var pct := Label.new()
		pct.custom_minimum_size = Vector2(64, 0) * ui_scale
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct.add_theme_font_override("font", font)
		pct.add_theme_font_size_override("font_size", int(20 * ui_scale))
		pct.add_theme_color_override("font_color", UiStyle.C_GOLD)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = vol[bus]
		s.custom_minimum_size = Vector2(220, 32) * ui_scale
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pct.text = "%d%%" % roundi(s.value * 100.0)
		s.value_changed.connect(func(v: float) -> void:
			set_volume(bus, v)
			pct.text = "%d%%" % roundi(v * 100.0))
		s.drag_ended.connect(func(_changed: bool) -> void: save())
		row.add_child(name)
		row.add_child(s)
		row.add_child(pct)
		parent.add_child(row)
