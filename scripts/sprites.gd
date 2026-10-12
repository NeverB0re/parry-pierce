extends RefCounted
## art/ 폴더의 도트 스프라이트 로더 (Ravenmore "Space Rage", 출처는 art/CREDITS.md). 처음 쓸 때 읽고 캐시한다.

const BASE := "res://art/SpaceRage/SpaceRage/"
const SHIP_FRAMES := ["l2", "l1", "m", "r1", "r2"]       # 왼쪽으로 많이 기울임 → 가운데 → 오른쪽으로 많이 기울임
const EXPLOSION_FRAMES := {1: 11, 2: 9, 3: 9}            # 폭발 1(주황 불꽃) / 2(주황 링) / 3(청록 링)

static var _cache := {}


static func _load(rel: String) -> Texture2D:
	var t = _cache.get(rel)
	if t == null:
		t = load(BASE + rel)
		_cache[rel] = t
	return t


## 기체: color "b"(청) / "r"(적), bank -1..1 (좌우 기울임)
static func ship(color: String, bank: float) -> Texture2D:
	var i := clampi(int(round(bank * 2.0)) + 2, 0, 4)
	return _load("Player/player_%s_%s.png" % [color, SHIP_FRAMES[i]])


## 노즐 화염 1~5
static func exhaust(frame: int) -> Texture2D:
	return _load("FX/exhaust_%02d.png" % clampi(frame, 1, 5))


## 폭발 애니메이션 프레임 (kind 1~3, 0부터)
static func explosion(kind: int, frame: int) -> Texture2D:
	var n: int = EXPLOSION_FRAMES[kind]
	return _load("Explosions/explosion_%d_%02d.png" % [kind, clampi(frame, 0, n - 1) + 1])


static func explosion_frames(kind: int) -> int:
	return EXPLOSION_FRAMES[kind]
