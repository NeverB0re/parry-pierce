## 화면 UI 공통 모양 (메인 화면·일시정지·항로도·튜토리얼): 도트 게임에 맞춘 각진 판.
## 판 = 짙은 남색 + 2px 강철 테두리 + 아래오른쪽으로 떨어지는 딱딱한 그림자 (둥근 모서리 없음).
## 버튼 = 같은 판, 올리거나 고르면 금빛 테두리·금빛 글씨 (금 = 지금 고를 수 있는 것). 글씨는 갈무리11 (UiFont).
const UiFont := preload("res://scripts/ui_font.gd")
const C_BG := Color(0.035, 0.045, 0.07, 0.92)
const C_BG_HOVER := Color(0.07, 0.08, 0.12, 0.96)
const C_BG_PRESS := Color(0.16, 0.12, 0.05, 0.98)
const C_EDGE := Color(0.34, 0.4, 0.52)
const C_GOLD := Color(1.0, 0.8, 0.38)
const C_TEXT := Color(0.88, 0.91, 0.96)
const C_DIM := Color(0.45, 0.48, 0.55)
const C_TITLE := Color(1.0, 0.86, 0.55)


static func _box(bg: Color, edge: Color, shadow := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(shadow, shadow)
	if shadow > 0:
		sb.shadow_size = 1
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = false
	return sb


## 큰 판 (일시정지·조작법 목록·튜토리얼 창)
static func panel(margin := 22) -> StyleBoxFlat:
	var sb := _box(Color(0.03, 0.04, 0.065, 0.95), C_EDGE, 6)
	sb.set_content_margin_all(margin)
	return sb


## 버튼 모양을 입힌다
static func button(b: Button, font: Font, size: int) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _box(C_BG, C_EDGE))
	b.add_theme_stylebox_override("hover", _box(C_BG_HOVER, C_GOLD))
	b.add_theme_stylebox_override("pressed", _box(C_BG_PRESS, C_GOLD, 2))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), C_GOLD, 0))
	b.add_theme_stylebox_override("disabled", _box(Color(0.03, 0.035, 0.05, 0.6), Color(C_EDGE, 0.4), 0))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_GOLD)
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.93, 0.7))
	b.add_theme_color_override("font_focus_color", C_GOLD)
	b.add_theme_color_override("font_hover_pressed_color", C_GOLD)
	b.add_theme_color_override("font_disabled_color", C_DIM)


## 제목 글씨: 굵은 도트 글꼴 + 금빛 + 진한 외곽선
static func title(l: Label, size: int, col := C_TITLE) -> void:
	l.add_theme_font_override("font", UiFont.bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
