## 화면 글꼴: 도트 게임에 맞는 갈무리11 (Galmuri11, SIL OFL 1.1, assets/fonts). 데스크톱·웹 모두 같은 글꼴을 함께 넣어 쓴다.
## 도트가 번지지 않게 안티에일리어싱·힌팅을 끈다. 크기는 12 의 배수(12·24·36…)일 때 가장 또렷하다
const PIXEL := "res://assets/fonts/Galmuri11.ttf"
const PIXEL_BOLD := "res://assets/fonts/Galmuri11-Bold.ttf"


static func make() -> Font:
	return _crisp(PIXEL)


## 제목·큰 글씨용 굵은 도트 글꼴
static func bold() -> Font:
	return _crisp(PIXEL_BOLD)


static func _crisp(path: String) -> Font:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f
