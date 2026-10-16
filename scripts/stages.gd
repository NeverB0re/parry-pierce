extends RefCounted
## 스테이지 목록: FTL 도약 한 번 = 한 스테이지 = 콜로서스 하나. 순서는 docs/PLAN_colossi.md 4장.
## 마지막 스테이지를 깨면 같은 스테이지로 다시 도약한다 (다음 콜로서스가 생기면 이어진다).
## 월드 맵에는 MAP_STAGES 개의 은하(스테이지)와 마지막 목적지가 그려진다. LIST 에 없는 은하는 아직 만들지 않은 스테이지(회색).

const LIST := [
	{"id": "observer", "name": "관측자", "script": "res://scripts/colossi/observer.gd", "core": "counter",
		"coord": "퇴각 항로 1구간"},
	{"id": "fortress", "name": "탄막 요새", "script": "res://scripts/colossi/fortress.gd", "core": "reflect",
		"coord": "퇴각 항로 2구간"},
	{"id": "kraken", "name": "크라켄", "script": "res://scripts/colossi/kraken.gd", "core": "assault",
		"coord": "퇴각 항로 3구간"},
	{"id": "satellite", "name": "결계 위성", "script": "res://scripts/colossi/satellite.gd", "core": "sync",
		"coord": "퇴각 항로 4구간 — 궤도", "theme": "orbit"},
]

const MAP_STAGES := 9                # 월드 맵의 스테이지 수 (목적지는 그다음, 10번째)
const DESTINATION := "목적지"
