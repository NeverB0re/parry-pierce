extends RefCounted
## 스테이지 목록: FTL 도약 한 번 = 한 스테이지 = 콜로서스 하나. 순서는 docs/PLAN_colossi.md 4장.
## 지금은 관측자 하나뿐이라, 마지막 스테이지를 깨면 같은 스테이지로 다시 도약한다.

const LIST := [
	{"id": "observer", "name": "관측자", "script": "res://scripts/colossi/observer.gd", "core": "mobility",
		"coord": "퇴각 항로 1구간"},
]
